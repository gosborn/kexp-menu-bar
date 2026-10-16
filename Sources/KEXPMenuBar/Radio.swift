import AppKit
import AVFoundation
import MediaPlayer
import Observation

/// Owns the stream player, polls KEXP for what's on, and publishes it to
/// the system Now Playing widget / media keys.
@MainActor
@Observable
final class Radio {
    enum State { case stopped, loading, playing }

    static let streamURL = URL(string: "https://kexp.streamguys1.com/kexp160.aac")!

    private(set) var state: State = .stopped
    private(set) var play: Play?
    private(set) var show: Show?
    private(set) var artwork: NSImage?

    var volume: Float {
        didSet {
            player.volume = volume
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }

    @ObservationIgnored let equalizer = Equalizer()
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var wantsToPlay = false
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        volume = UserDefaults.standard.object(forKey: "volume") as? Float ?? 0.8
        player.volume = volume

        statusObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
            Task { @MainActor in self?.syncState() }
        }

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleReconnect(after: 3) }
        })
        observers.append(nc.addObserver(forName: AVPlayerItem.playbackStalledNotification, object: nil, queue: .main) { [weak self] _ in
            // AVPlayer often recovers from a stall itself; only reconnect if it hasn't.
            MainActor.assumeIsolated { self?.scheduleReconnect(after: 10) }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.wantsToPlay else { return }
                self.startStream()
            }
        })

        setUpRemoteCommands()
        startPolling()
    }

    // MARK: Playback

    func toggle() {
        wantsToPlay ? stop() : start()
    }

    func start() {
        wantsToPlay = true
        startStream()
    }

    func stop() {
        wantsToPlay = false
        retryTask?.cancel()
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        syncState()
    }

    /// Always load a fresh item so playback is live rather than resuming a stale buffer.
    private func startStream() {
        retryTask?.cancel()
        let item = AVPlayerItem(url: Self.streamURL)
        itemObservation = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in self?.scheduleReconnect(after: 3) }
        }
        player.replaceCurrentItem(with: item)
        player.play()
        syncState()
    }

    private func scheduleReconnect(after seconds: Double) {
        guard wantsToPlay else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled, self.wantsToPlay, self.state != .playing else { return }
            self.startStream()
        }
    }

    private func syncState() {
        if !wantsToPlay {
            state = .stopped
        } else {
            state = player.timeControlStatus == .playing ? .playing : .loading
        }
        equalizer.isPlaying = state == .playing
        updateNowPlayingInfo()
    }

    // MARK: Now playing

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    private func refresh() async {
        guard let latest = try? await KEXPAPI.currentPlay(), latest != play else { return }
        let artworkChanged = latest.artworkURL != play?.artworkURL || latest.isAirBreak
        play = latest

        if let showID = latest.show, showID != show?.id {
            show = try? await KEXPAPI.show(id: showID)
        }

        if artworkChanged {
            artwork = nil
            if !latest.isAirBreak, let url = latest.artworkURL,
               let (data, _) = try? await URLSession.shared.data(from: url) {
                artwork = NSImage(data: data)
            }
        }
        updateNowPlayingInfo()
    }

    var title: String {
        guard let play else { return "KEXP 90.3 FM" }
        return play.isAirBreak ? "Air break" : (play.song ?? "Unknown song")
    }

    var subtitle: String {
        guard let play, !play.isAirBreak else { return show?.summary ?? "" }
        return play.artist ?? ""
    }

    private func setUpRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.start() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }

    private func updateNowPlayingInfo() {
        let center = MPNowPlayingInfoCenter.default()
        guard wantsToPlay else {
            center.playbackState = .stopped
            center.nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle.isEmpty ? "KEXP" : subtitle,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let album = play?.album, play?.isAirBreak == false {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        center.nowPlayingInfo = info
        center.playbackState = state == .playing ? .playing : .paused
    }
}

import ServiceManagement
import SwiftUI

struct PlayerView: View {
    @Bindable var radio: Radio
    let likes: Likes
    @State private var showLikes = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 3) {
                    Text(radio.title)
                        .font(.headline)
                        .lineLimit(2)
                    if !radio.subtitle.isEmpty {
                        Text(radio.subtitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let album = radio.play?.album, radio.play?.isAirBreak == false {
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(action: radio.toggle) {
                    Image(systemName: radio.state == .stopped ? "play.fill" : "stop.fill")
                        .font(.title2)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.space, modifiers: [])

                let canLike = radio.play.map { !$0.isAirBreak && $0.song != nil } ?? false
                let liked = likes.isLiked(radio.play)
                Button { likes.toggle(radio.play) } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(liked ? .pink : .secondary)
                        .frame(width: 24, height: 28)
                }
                .buttonStyle(.borderless)
                .disabled(!canLike)
                .keyboardShortcut("l", modifiers: [])
                .help(liked ? "Unlike" : "Like this song")

                if radio.state == .loading {
                    ProgressView().controlSize(.small)
                }

                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $radio.volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }

            if let show = radio.show?.summary {
                Text(show)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            DisclosureGroup("Liked songs (\(likes.songs.count))", isExpanded: $showLikes) {
                likedList
            }

            @Bindable var equalizer = radio.equalizer
            Toggle("Animate menu bar icon", isOn: $equalizer.isEnabled)
                .toggleStyle(.checkbox)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            HStack {
                Button("Open kexp.org") {
                    NSWorkspace.shared.open(URL(string: "https://www.kexp.org/playlist/")!)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 320)
    }

    @ViewBuilder
    private var likedList: some View {
        if likes.songs.isEmpty {
            Text("Tap the heart to save the song that's playing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(likes.songs) { song in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(song.song).lineLimit(1)
                            Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Copy \"\(song.song) – \(song.artist)\"") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("\(song.song) – \(song.artist)", forType: .string)
                            }
                            Button("Remove", role: .destructive) { likes.remove(song) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 180)
        }
        Button("Show likes file in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([Likes.fileURL])
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .disabled(likes.songs.isEmpty)
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
            if let image = radio.artwork {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "radio").font(.title).foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

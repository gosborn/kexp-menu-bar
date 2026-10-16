import Foundation
import Observation

struct LikedSong: Codable, Identifiable, Equatable {
    var id: String { "\(artist)\u{1F}\(song)" }
    let song: String
    let artist: String
    let album: String?
    let artworkURL: URL?
    let likedAt: Date
}

/// Liked songs, persisted as JSON in ~/Library/Application Support/KEXP Menu Bar/likes.json.
@MainActor
@Observable
final class Likes {
    private(set) var songs: [LikedSong] = []

    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KEXP Menu Bar", directoryHint: .isDirectory)
        return dir.appending(path: "likes.json")
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? Self.decoder.decode([LikedSong].self, from: data) {
            songs = saved
        }
    }

    func isLiked(_ play: Play?) -> Bool {
        guard let key = Self.key(for: play) else { return false }
        return songs.contains { $0.id == key }
    }

    func toggle(_ play: Play?) {
        guard let play, let key = Self.key(for: play) else { return }
        if let index = songs.firstIndex(where: { $0.id == key }) {
            songs.remove(at: index)
        } else {
            songs.insert(LikedSong(song: play.song ?? "", artist: play.artist ?? "", album: play.album,
                                   artworkURL: play.artworkURL, likedAt: .now), at: 0)
        }
        save()
    }

    func remove(_ song: LikedSong) {
        songs.removeAll { $0.id == song.id }
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Self.encoder.encode(songs).write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("Failed to save likes: \(error)")
        }
    }

    private static func key(for play: Play?) -> String? {
        guard let play, !play.isAirBreak, let song = play.song, let artist = play.artist else { return nil }
        return "\(artist)\u{1F}\(song)"
    }
}

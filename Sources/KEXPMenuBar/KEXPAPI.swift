import Foundation

/// A single entry from KEXP's playlist: either a track or an air break.
struct Play: Decodable, Equatable {
    let id: Int
    let playType: String
    let song: String?
    let artist: String?
    let album: String?
    let imageUri: String?
    let show: Int?

    var isAirBreak: Bool { playType == "airbreak" }

    var artworkURL: URL? {
        guard let imageUri, !imageUri.isEmpty else { return nil }
        return URL(string: imageUri)
    }
}

struct Show: Decodable, Equatable {
    let id: Int
    let programName: String?
    let hostNames: [String]?

    var summary: String? {
        let hosts = (hostNames ?? []).joined(separator: " & ")
        switch (programName, hosts.isEmpty) {
        case let (name?, false): return "\(name) with \(hosts)"
        case let (name?, true): return name
        case (nil, false): return hosts
        default: return nil
        }
    }
}

enum KEXPAPI {
    private static let base = URL(string: "https://api.kexp.org/v2/")!

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private struct Page<T: Decodable>: Decodable { let results: [T] }

    static func currentPlay() async throws -> Play? {
        let url = base.appending(path: "plays/").appending(queryItems: [.init(name: "limit", value: "1")])
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(Page<Play>.self, from: data).results.first
    }

    static func show(id: Int) async throws -> Show {
        let (data, _) = try await URLSession.shared.data(from: base.appending(path: "shows/\(id)/"))
        return try decoder.decode(Show.self, from: data)
    }
}

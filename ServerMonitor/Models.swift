import Foundation
import SwiftUI

struct SavedServer: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var address: String
    var bedrock: Bool = false
}

struct ServerStatus: Decodable {
    struct Motd: Decodable { let clean: [String]? }
    struct Player: Decodable, Hashable { let name: String }
    struct Players: Decodable { let online: Int?; let max: Int?; let list: [Player]? }
    let online: Bool
    let ip: String?
    let port: Int?
    let version: String?
    let motd: Motd?
    let players: Players?
    let icon: String?

    var iconImage: UIImage? {
        guard let icon, let comma = icon.firstIndex(of: ",") else { return nil }
        guard let data = Data(base64Encoded: String(icon[icon.index(after: comma)...])) else { return nil }
        return UIImage(data: data)
    }
}

enum StatusAPI {
    static func fetch(_ server: SavedServer) async throws -> (ServerStatus, Int) {
        let base = server.bedrock ? "https://api.mcsrvstat.us/bedrock/3/" : "https://api.mcsrvstat.us/3/"
        let host = server.address.trimmingCharacters(in: .whitespaces)
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? server.address
        var req = URLRequest(url: URL(string: base + host)!)
        req.setValue("ServerMonitor-iOS/1.0 (MinePro641)", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let start = Date()
        let (data, _) = try await URLSession.shared.data(for: req)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        return (try JSONDecoder().decode(ServerStatus.self, from: data), ms)
    }
}

@MainActor
final class ServerStore: ObservableObject {
    @Published var servers: [SavedServer] = [] { didSet { save() } }
    @Published var statuses: [UUID: ServerStatus] = [:]
    @Published var latency: [UUID: Int] = [:]
    @Published var errors: [UUID: String] = [:]
    @Published var loading: Set<UUID> = []
    private let key = "savedServers"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([SavedServer].self, from: data) {
            servers = list
        } else {
            servers = [SavedServer(name: "Hypixel", address: "mc.hypixel.net")]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(servers) { UserDefaults.standard.set(data, forKey: key) }
    }

    func refresh(_ server: SavedServer) async {
        loading.insert(server.id)
        defer { loading.remove(server.id) }
        do {
            let (status, ms) = try await StatusAPI.fetch(server)
            statuses[server.id] = status
            latency[server.id] = ms
            errors[server.id] = nil
        } catch {
            errors[server.id] = "Keine Verbindung zur Status-API"
        }
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for s in servers { group.addTask { await self.refresh(s) } }
        }
    }
}

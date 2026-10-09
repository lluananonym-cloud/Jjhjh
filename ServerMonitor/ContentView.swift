import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ServerStore
    @State private var showAdd = false
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.servers) { server in
                    NavigationLink(value: server) { ServerRow(server: server) }
                }
                .onDelete { store.servers.remove(atOffsets: $0) }
                .onMove { store.servers.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("Server Monitor")
            .navigationDestination(for: SavedServer.self) { ServerDetail(server: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await store.refreshAll() }
            .overlay {
                if store.servers.isEmpty {
                    ContentUnavailableView("Keine Server", systemImage: "server.rack",
                        description: Text("Tippe auf + um einen Server hinzuzufügen."))
                }
            }
            .sheet(isPresented: $showAdd) { AddServerView() }
            .task { await store.refreshAll() }
            .onReceive(timer) { _ in Task { await store.refreshAll() } }
        }
        .tint(.green)
    }
}

struct ServerIcon: View {
    let image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).interpolation(.none).resizable() }
            else { Image(systemName: "cube.fill").resizable().scaledToFit().padding(10).foregroundStyle(.secondary) }
        }
        .frame(width: 48, height: 48)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ServerRow: View {
    @EnvironmentObject var store: ServerStore
    let server: SavedServer

    var body: some View {
        let status = store.statuses[server.id]
        HStack(spacing: 12) {
            ServerIcon(image: status?.iconImage)
            VStack(alignment: .leading, spacing: 3) {
                Text(server.name).font(.headline)
                Text(server.address).font(.caption).foregroundStyle(.secondary)
                if let p = status?.players, status?.online == true {
                    Text("\(p.online ?? 0) / \(p.max ?? 0) Spieler").font(.caption.monospacedDigit())
                }
            }
            Spacer()
            if store.loading.contains(server.id) && status == nil {
                ProgressView()
            } else {
                StatusBadge(online: status?.online, error: store.errors[server.id] != nil)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let online: Bool?
    let error: Bool
    var body: some View {
        let (text, color): (String, Color) = error ? ("Fehler", .orange)
            : online == true ? ("Online", .green) : online == false ? ("Offline", .red) : ("…", .gray)
        Text(text).font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.2)).foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct ServerDetail: View {
    @EnvironmentObject var store: ServerStore
    let server: SavedServer

    var body: some View {
        let status = store.statuses[server.id]
        List {
            Section {
                HStack(spacing: 16) {
                    ServerIcon(image: status?.iconImage).scaleEffect(1.3).padding(8)
                    VStack(alignment: .leading) {
                        Text(server.name).font(.title2.bold())
                        StatusBadge(online: status?.online, error: store.errors[server.id] != nil)
                    }
                }
            }
            if let err = store.errors[server.id] {
                Section { Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            if let lines = status?.motd?.clean, !lines.isEmpty {
                Section("MOTD") { Text(lines.joined(separator: "\n")).font(.system(.body, design: .monospaced)) }
            }
            Section("Info") {
                row("Adresse", server.address)
                row("Edition", server.bedrock ? "Bedrock" : "Java")
                if let ip = status?.ip { row("IP", "\(ip):\(status?.port ?? 0)") }
                if let v = status?.version { row("Version", v) }
                if let ms = store.latency[server.id] { row("Abfragezeit", "\(ms) ms") }
            }
            if let p = status?.players, status?.online == true {
                Section("Spieler (\(p.online ?? 0)/\(p.max ?? 0))") {
                    if let list = p.list, !list.isEmpty {
                        ForEach(list, id: \.self) { pl in
                            HStack {
                                AsyncImage(url: URL(string: "https://mc-heads.net/avatar/\(pl.name)/32")) { img in
                                    img.interpolation(.none).resizable()
                                } placeholder: { Color.gray.opacity(0.3) }
                                .frame(width: 24, height: 24).clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(pl.name)
                            }
                        }
                    } else {
                        Text("Spielerliste vom Server nicht freigegeben").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh(server) }
    }

    func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).multilineTextAlignment(.trailing) }
    }
}

struct AddServerView: View {
    @EnvironmentObject var store: ServerStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var bedrock = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Adresse (z. B. play.meinserver.de)", text: $address)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                Toggle("Bedrock-Server", isOn: $bedrock)
            }
            .navigationTitle("Server hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let s = SavedServer(name: name.isEmpty ? address : name, address: address, bedrock: bedrock)
                        store.servers.append(s)
                        Task { await store.refresh(s) }
                        dismiss()
                    }.disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

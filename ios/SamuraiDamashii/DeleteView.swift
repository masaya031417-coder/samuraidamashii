import SwiftUI

struct DeleteView: View {
    @StateObject private var gcal = GoogleCalendarService.shared
    @State private var events: [GCalEvent] = []
    @State private var isLoading = false
    @State private var isSigningIn = false
    @State private var pendingDelete: GCalEvent?
    @State private var errorMsg = ""

    var body: some View {
        NavigationView {
            Group {
                if !gcal.isSignedIn {
                    signInView
                } else if isLoading {
                    ProgressView("カレンダーを読み込み中…")
                } else if events.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .navigationTitle("シフト削除")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if gcal.isSignedIn {
                        Button { fetchEvents() } label: { Image(systemName: "arrow.clockwise") }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if gcal.isSignedIn {
                        Button("サインアウト") { gcal.signOut() }
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("この予定を削除しますか？", isPresented: .constant(pendingDelete != nil)) {
                Button("削除", role: .destructive) {
                    if let e = pendingDelete { deleteEvent(e) }
                    pendingDelete = nil
                }
                Button("キャンセル", role: .cancel) { pendingDelete = nil }
            } message: {
                if let e = pendingDelete { Text(eventSummary(e)) }
            }
            .alert(errorMsg, isPresented: .constant(!errorMsg.isEmpty)) {
                Button("OK") { errorMsg = "" }
            }
        }
        .onChange(of: gcal.isSignedIn) { signed in if signed { fetchEvents() } }
        .onAppear { if gcal.isSignedIn { fetchEvents() } }
    }

    // MARK: Sub-views

    private var signInView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.key")
                .font(.system(size: 60)).foregroundColor(.blue)
            Text("シフトを確認・削除するには\nGoogleサインインが必要です")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            Button(action: signIn) {
                if isSigningIn { ProgressView().padding(.horizontal) }
                else { Label("Googleでサインイン", systemImage: "person.badge.key") }
            }
            .buttonStyle(.borderedProminent).disabled(isSigningIn)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52)).foregroundColor(.secondary)
            Text("シフトイベントが見つかりません").foregroundColor(.secondary)
            Button("再読み込み", action: fetchEvents).buttonStyle(.bordered)
        }
    }

    private var eventList: some View {
        List {
            ForEach(events) { event in
                GCalEventRow(event: event) { pendingDelete = event }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Actions

    private func signIn() {
        isSigningIn = true
        Task {
            do { try await gcal.signIn() }
            catch { await MainActor.run { errorMsg = error.localizedDescription } }
            await MainActor.run { isSigningIn = false }
        }
    }

    private func fetchEvents() {
        isLoading = true
        Task {
            do {
                let fetched = try await GoogleCalendarService.shared.fetchShiftEvents()
                await MainActor.run { events = fetched }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func deleteEvent(_ event: GCalEvent) {
        Task {
            do {
                try await GoogleCalendarService.shared.deleteEvent(id: event.id)
                await MainActor.run { events.removeAll { $0.id == event.id } }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
        }
    }

    private func eventSummary(_ e: GCalEvent) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "M/d(E) HH:mm"
        let g = DateFormatter(); g.locale = Locale(identifier: "ja_JP"); g.dateFormat = "HH:mm"
        let loc = e.location.map { "  \($0)" } ?? ""
        return "\(f.string(from: e.startDate)) 〜 \(g.string(from: e.endDate))\(loc)"
    }
}

// MARK: - Row

struct GCalEventRow: View {
    let event: GCalEvent
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline)
                if let loc = event.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin")
                        .font(.caption).foregroundColor(.secondary)
                }
                Label(dateRangeString, systemImage: "clock")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash").foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var dateRangeString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "M/d(E) HH:mm"
        let g = DateFormatter(); g.locale = Locale(identifier: "ja_JP"); g.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) 〜 \(g.string(from: event.endDate))"
    }
}

import SwiftUI
import EventKit

struct DeleteView: View {
    @State private var events: [EKEvent] = []
    @State private var isLoading = false
    @State private var errorMsg = ""
    @State private var pendingDelete: EKEvent?

    private let store = EKEventStore()

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
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
                    Button { fetchEvents() } label: { Image(systemName: "arrow.clockwise") }
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
        .onAppear { fetchEvents() }
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
            ForEach(events, id: \.eventIdentifier) { event in
                ShiftEventRow(event: event) { pendingDelete = event }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Data

    private func fetchEvents() {
        isLoading = true
        Task {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = (try? await store.requestFullAccessToEvents()) ?? false
            } else {
                granted = await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
                }
            }

            await MainActor.run {
                defer { isLoading = false }
                guard granted else { errorMsg = "カレンダーへのアクセスが許可されていません"; return }

                let now   = Date()
                let start = Calendar.current.date(byAdding: .month, value: -3, to: now)!
                let end   = Calendar.current.date(byAdding: .month, value: 6,  to: now)!
                let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)

                events = store.events(matching: pred)
                    .filter { $0.title?.contains("シフト") == true }
                    .sorted { $0.startDate < $1.startDate }
            }
        }
    }

    private func deleteEvent(_ event: EKEvent) {
        do {
            try store.remove(event, span: .thisEvent)
            events.removeAll { $0.eventIdentifier == event.eventIdentifier }
        } catch {
            errorMsg = "削除失敗: \(error.localizedDescription)"
        }
    }

    private func eventSummary(_ e: EKEvent) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "M/d(E) HH:mm"
        let g = DateFormatter(); g.locale = Locale(identifier: "ja_JP"); g.dateFormat = "HH:mm"
        let loc = e.location.map { "  \($0)" } ?? ""
        return "\(f.string(from: e.startDate)) 〜 \(g.string(from: e.endDate))\(loc)"
    }
}

// MARK: - Row

struct ShiftEventRow: View {
    let event: EKEvent
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "シフト").font(.headline)
                if let loc = event.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin").font(.caption).foregroundColor(.secondary)
                }
                Label(dateRangeString, systemImage: "clock").font(.caption).foregroundColor(.secondary)
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

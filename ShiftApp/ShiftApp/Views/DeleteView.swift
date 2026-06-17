// DeleteView.swift - 登録済みシフトイベントを一覧表示して削除するビュー

import SwiftUI

struct DeleteView: View {
    @ObservedObject var calendarService: CalendarService

    @State private var events: [CalendarEvent] = []
    @State private var selected: Set<String> = []   // 削除対象のイベントID
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var showConfirm = false
    @State private var deletedCount: Int? = nil
    @State private var errorMessage: String? = nil
    @State private var isEditMode = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    // 取得中スピナー
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("シフトを取得中...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if !calendarService.isSignedIn {
                    // 未サインインのガイド
                    signInPrompt

                } else if events.isEmpty {
                    // イベントなし
                    ContentUnavailableView(
                        "シフトイベントが見つかりません",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("過去7日〜今後90日の範囲に「シフト」イベントはありません")
                    )

                } else {
                    // イベント一覧
                    eventList
                }
            }
            .navigationTitle("シフト削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 編集モード切り替え（イベントが1件以上あるとき）
                if !events.isEmpty && calendarService.isSignedIn {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditMode ? "完了" : "選択") {
                            isEditMode.toggle()
                            if !isEditMode { selected.removeAll() }
                        }
                    }
                }
            }
            // 削除確認アラート
            .confirmationDialog(
                "\(selected.count)件のシフトを削除しますか？",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) { performDelete() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は元に戻せません")
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
        .task { await loadEvents() }
    }

    // MARK: - Subviews

    private var eventList: some View {
        List {
            // 完了メッセージ
            if let count = deletedCount {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("🗑️ \(count)件のイベントを削除しました")
                            .fontWeight(.medium)
                    }
                }
            }

            Section("\(events.count)件のシフトイベント（過去7日〜今後90日）") {
                ForEach(events) { event in
                    eventRow(event)
                        // 選択モードでなければスワイプ削除を有効化
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !isEditMode {
                                Button(role: .destructive) {
                                    selected = [event.id]
                                    showConfirm = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }
        .refreshable { await loadEvents() }
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
            // 選択モード時はチェックボックス
            if isEditMode {
                Image(systemName: selected.contains(event.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(event.id) ? .red : .secondary)
                    .font(.title3)
                    .onTapGesture { toggleSelection(event.id) }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.date)
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.medium)
                    if !event.startTime.isEmpty {
                        Text("\(event.startTime)〜\(event.endTime)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                if !event.place.isEmpty {
                    Text(event.place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isEditMode && selected.contains(event.id) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode { toggleSelection(event.id) }
        }
    }

    private var signInPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Googleアカウントへのサインインが必要です")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("サインインする") { signIn() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isEditMode && !selected.isEmpty {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("すべて選択") {
                        selected = Set(events.map(\.id))
                    }
                    .font(.subheadline)
                    Spacer()
                    Button(role: .destructive) {
                        showConfirm = true
                    } label: {
                        Label("\(selected.count)件を削除", systemImage: "trash")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeleting)
                }
                .padding()
            }
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func loadEvents() async {
        guard calendarService.isSignedIn else { return }
        isLoading = true
        do {
            events = try await calendarService.fetchShiftEvents()
        } catch {
            errorMessage = "イベントの取得に失敗しました: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func performDelete() {
        isDeleting = true
        let targets = Array(selected)

        Task {
            var count = 0
            for id in targets {
                do {
                    try await calendarService.deleteEvent(id)
                    count += 1
                } catch {
                    errorMessage = "一部のイベントの削除に失敗しました: \(error.localizedDescription)"
                }
            }
            // 削除済みをリストから取り除く
            events.removeAll { targets.contains($0.id) }
            selected.removeAll()
            deletedCount = count
            isEditMode = false
            isDeleting = false
        }
    }

    private func signIn() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let vc = scene.windows.first?.rootViewController else { return }
        Task {
            do {
                try await calendarService.signIn(presenting: vc)
                await loadEvents()
            } catch {
                errorMessage = "サインインに失敗しました: \(error.localizedDescription)"
            }
        }
    }
}

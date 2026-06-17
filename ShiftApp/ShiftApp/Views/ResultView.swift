// ResultView.swift - 抽出されたシフト一覧の表示・カレンダー登録確認画面

import SwiftUI

struct ResultView: View {
    let shifts: [Shift]
    @ObservedObject var calendarService: CalendarService

    @Environment(\.dismiss) private var dismiss
    @State private var isRegistering = false
    @State private var registeredCount: Int? = nil
    @State private var errorMessage: String? = nil

    // 変則シフトと通常シフトに分ける
    private var regularShifts:   [Shift] { shifts.filter { !$0.isIrregular } }
    private var irregularShifts: [Shift] { shifts.filter {  $0.isIrregular } }

    var body: some View {
        NavigationStack {
            List {
                // 件数サマリー
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("✅ \(shifts.count)件のシフトを検出しました")
                            .font(.headline)
                    }
                }

                // 通常シフト一覧
                if !regularShifts.isEmpty {
                    Section("登録対象（\(regularShifts.count)件）") {
                        ForEach(regularShifts) { ShiftRow(shift: $0) }
                    }
                }

                // 変則シフト一覧
                if !irregularShifts.isEmpty {
                    Section {
                        ForEach(irregularShifts) { ShiftRow(shift: $0, isWarning: true) }
                    } header: {
                        Label("変則シフト（要手動確認）", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("変則シフト（G記号）は勤務時間が不規則なため自動登録されません。手動でカレンダーに追加してください。")
                            .foregroundStyle(.secondary)
                    }
                }

                // 登録完了メッセージ
                if let count = registeredCount {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundStyle(.green)
                            Text("🎉 \(count)件をGoogleカレンダーに登録しました！")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("検出結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            // 下部アクションボタン
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        // 登録完了後はボタンを非表示にする
        if registeredCount == nil {
            VStack(spacing: 10) {
                if !calendarService.isSignedIn {
                    // 未サインインの場合はサインインボタンを表示
                    Button { signIn() } label: {
                        Label("Googleでサインイン", systemImage: "person.crop.circle")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    Button { registerToCalendar() } label: {
                        Group {
                            if isRegistering {
                                ProgressView().tint(.white)
                            } else {
                                Label("📅 カレンダーに登録する", systemImage: "calendar.badge.plus")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(regularShifts.isEmpty ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(regularShifts.isEmpty || isRegistering)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func signIn() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let vc = scene.windows.first?.rootViewController else { return }
        Task {
            do {
                try await calendarService.signIn(presenting: vc)
            } catch {
                errorMessage = "サインインに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private func registerToCalendar() {
        isRegistering = true
        Task {
            do {
                registeredCount = try await calendarService.pushShifts(shifts)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRegistering = false
        }
    }
}

// MARK: - ShiftRow

/// シフト1件の行コンポーネント
struct ShiftRow: View {
    let shift: Shift
    var isWarning: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 日付列
            Text(shift.date)
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
                .frame(minWidth: 90, alignment: .leading)

            Divider()

            // 時間・場所列
            VStack(alignment: .leading, spacing: 2) {
                Text("\(shift.start) 〜 \(shift.end)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(isWarning ? .orange : .primary)
                if !shift.place.isEmpty {
                    Text(shift.place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !shift.note.isEmpty {
                    Text(shift.note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

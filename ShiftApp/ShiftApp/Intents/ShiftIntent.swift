// ShiftIntent.swift - Siriショートカット連携（App Intents / iOS 16+）
// 「シフトを登録」と話しかけるとアプリを開かずに登録できる

import AppIntents
import GoogleSignIn

// MARK: - App Intent

@available(iOS 16.0, *)
struct ParseShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "シフトを登録"
    static var description = IntentDescription(
        "勤務情報を話すとシフトを解析してGoogleカレンダーに自動登録します",
        categoryName: "シフト管理"
    )

    /// Siriから受け取る勤務情報テキスト
    @Parameter(title: "シフト情報", description: "例：6月21日 18時から23時 場所はグリーンアリーナ")
    var shiftText: String

    /// Siriに表示するサマリー文
    static var parameterSummary: some ParameterSummary {
        Summary("「\(\.$shiftText)」のシフトを登録")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Google サインイン未実施の場合は案内
        guard GIDSignIn.sharedInstance.currentUser != nil else {
            return .result(
                dialog: "まずアプリを開いてGoogleアカウントにサインインしてください"
            )
        }

        // バックエンドでシフト解析
        let api = APIService()
        let shifts: [Shift]
        do {
            shifts = try await api.parseText(shiftText)
        } catch {
            return .result(dialog: "シフトの解析に失敗しました: \(error.localizedDescription)")
        }

        guard !shifts.isEmpty else {
            return .result(dialog: "シフト情報が見つかりませんでした。もう一度話してください")
        }

        // Googleカレンダーに登録
        let calendar = CalendarService()
        let count = (try? await calendar.pushShifts(shifts)) ?? 0

        let irregularCount = shifts.filter { $0.isIrregular }.count
        var message = "\(count)件のシフトをGoogleカレンダーに登録しました"
        if irregularCount > 0 {
            message += "。\(irregularCount)件の変則シフトは手動で確認してください"
        }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - App Shortcuts（Siri候補フレーズの登録）

@available(iOS 16.0, *)
struct ShiftAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ParseShiftIntent(),
            phrases: [
                "シフトを登録",
                "\(.applicationName)でシフトを登録",
                "\(.applicationName)にシフトを追加",
                "勤務を\(.applicationName)に登録",
            ],
            shortTitle: "シフト登録",
            systemImageName: "calendar.badge.plus"
        )
    }
}

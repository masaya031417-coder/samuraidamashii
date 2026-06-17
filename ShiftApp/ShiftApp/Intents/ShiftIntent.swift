// ShiftIntent.swift - Siriショートカット連携（App Intents / iOS 16+）

import AppIntents
import GoogleSignIn

// MARK: - 「予定を入れて」でウィザードを開くインテント

@available(iOS 16.0, *)
struct OpenWizardIntent: AppIntent {
    static var title: LocalizedStringResource = "予定を入れる"
    static var description = IntentDescription(
        "シフトの予定入力ウィザードを開きます",
        categoryName: "シフト管理"
    )

    // アプリを前面に出す
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // アプリが起動したあとでウィザードタブへ切り替えるよう予約
        UserDefaults.standard.set(2, forKey: "pendingTab")
        return .result()
    }
}

// MARK: - テキスト入力からシフトを登録するインテント

@available(iOS 16.0, *)
struct ParseShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "シフトを登録"
    static var description = IntentDescription(
        "勤務情報を話すとシフトを解析してGoogleカレンダーに自動登録します",
        categoryName: "シフト管理"
    )

    @Parameter(title: "シフト情報", description: "例：6月21日 グリオンアリーナ 18時から23時")
    var shiftText: String

    static var parameterSummary: some ParameterSummary {
        Summary("「\(\.$shiftText)」のシフトを登録")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard GIDSignIn.sharedInstance.currentUser != nil else {
            return .result(dialog: "まずアプリを開いてGoogleアカウントにサインインしてください")
        }

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

        let calendar = CalendarService()
        let count = (try? await calendar.pushShifts(shifts)) ?? 0

        let irregularCount = shifts.filter { $0.isIrregular }.count
        var msg = "\(count)件のシフトをGoogleカレンダーに登録しました"
        if irregularCount > 0 { msg += "。\(irregularCount)件の変則シフトは手動で確認してください" }
        return .result(dialog: IntentDialog(stringLiteral: msg))
    }
}

// MARK: - Siri候補フレーズの登録

@available(iOS 16.0, *)
struct ShiftAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // 「予定を入れて」でウィザードを起動
        AppShortcut(
            intent: OpenWizardIntent(),
            phrases: [
                "予定を入れて",
                "\(.applicationName)に予定を入れて",
                "\(.applicationName)で予定を入力",
                "予定入れて",
            ],
            shortTitle: "予定を入れる",
            systemImageName: "calendar.badge.plus"
        )
        // テキストでシフトを直接登録
        AppShortcut(
            intent: ParseShiftIntent(),
            phrases: [
                "シフトを登録",
                "\(.applicationName)でシフトを登録",
            ],
            shortTitle: "シフト登録",
            systemImageName: "calendar.badge.checkmark"
        )
    }
}

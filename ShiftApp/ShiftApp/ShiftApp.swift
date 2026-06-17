// ShiftApp.swift - アプリエントリーポイント

import SwiftUI
import AppIntents

@main
struct ShiftApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Siri が App Shortcuts を認識できるよう起動時に登録する
        if #available(iOS 16.0, *) {
            ShiftAppShortcuts.updateAppShortcutParameters()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // アプリがフォアグラウンドに戻ったとき、
                // Siri「予定を入れて」で予約されたタブ遷移を処理する
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didBecomeActiveNotification
                    )
                ) { _ in
                    guard let tab = UserDefaults.standard.value(forKey: "pendingTab") as? Int else { return }
                    UserDefaults.standard.removeObject(forKey: "pendingTab")
                    // ウィザードタブへの遷移は openWizard() 経由にする
                    // → wizardVersion がインクリメントされ、TextInputView が再生成されて日付から始まる
                    if tab == 2 {
                        appState.openWizard()
                    } else {
                        appState.selectedTab = tab
                    }
                }
        }
    }
}

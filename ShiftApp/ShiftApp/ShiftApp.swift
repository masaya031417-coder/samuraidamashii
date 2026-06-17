// ShiftApp.swift - アプリエントリーポイント

import SwiftUI

@main
struct ShiftApp: App {
    @StateObject private var appState = AppState()

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
                    appState.selectedTab = tab
                    UserDefaults.standard.removeObject(forKey: "pendingTab")
                }
        }
    }
}

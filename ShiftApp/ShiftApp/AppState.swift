// AppState.swift - アプリ全体で共有するナビゲーション状態

import Foundation

class AppState: ObservableObject {
    @Published var selectedTab: Int = 0

    /// ウィザードタブ（入力タブ = index 2）へ切り替える
    func openWizard() {
        DispatchQueue.main.async { self.selectedTab = 2 }
    }
}

// AppState.swift - アプリ全体で共有するナビゲーション状態

import Foundation

class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
    // 毎回インクリメント → ContentView で .id() に渡すことで TextInputView を強制再生成
    @Published var wizardVersion: Int = 0

    /// ウィザードタブ（入力タブ = index 2）へ切り替える。毎回リセットされた状態で開く
    func openWizard() {
        DispatchQueue.main.async {
            self.wizardVersion += 1
            self.selectedTab = 2
        }
    }
}

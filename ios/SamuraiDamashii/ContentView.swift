import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            VoiceView()
                .tabItem { Label("音声", systemImage: "mic.fill") }
                .tag(0)

            FilePickerView()
                .tabItem { Label("ファイル", systemImage: "doc.fill") }
                .tag(1)

            TextInputView()
                .tabItem { Label("入力", systemImage: "keyboard") }
                .tag(2)

            DeleteView()
                .tabItem { Label("削除", systemImage: "trash.fill") }
                .tag(3)
        }
    }
}

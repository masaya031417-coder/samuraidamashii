// ContentView.swift - ボトムタブナビゲーション（登録・削除の4タブ）

import SwiftUI

struct ContentView: View {
    @StateObject private var calendarService = CalendarService()
    @State private var shifts: [Shift] = []
    @State private var showResult = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // タブ1: 音声入力
            NavigationStack {
                VoiceView(onResult: handleResult, isLoading: $isLoading)
                    .navigationTitle("音声で登録")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { signInStatusButton }
            }
            .tabItem { Label("音声", systemImage: "mic.fill") }
            .tag(0)

            // タブ2: ファイル選択
            NavigationStack {
                FilePickerView(onResult: handleResult, isLoading: $isLoading)
                    .navigationTitle("ファイルで登録")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { signInStatusButton }
            }
            .tabItem { Label("ファイル", systemImage: "doc.fill") }
            .tag(1)

            // タブ3: 会話型ステップ入力
            NavigationStack {
                TextInputView(onResult: handleResult, isLoading: $isLoading)
                    .navigationTitle("入力して登録")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { signInStatusButton }
            }
            .tabItem { Label("入力", systemImage: "bubble.left.and.text.bubble.right") }
            .tag(2)

            // タブ4: 削除
            DeleteView(calendarService: calendarService)
                .tabItem { Label("削除", systemImage: "trash") }
                .tag(3)
        }
        // 結果シート（登録確認）
        .sheet(isPresented: $showResult) {
            ResultView(shifts: shifts, calendarService: calendarService)
        }
        // ローディングオーバーレイ（読み取り中）
        .overlay {
            if isLoading { LoadingOverlay() }
        }
        // エラーアラート
        .alert("エラー", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            calendarService.restoreSignIn()
        }
    }

    // MARK: - Toolbar item

    /// ナビバー右端のGoogleサインイン状態アイコン
    private var signInStatusButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Image(systemName: calendarService.isSignedIn
                  ? "checkmark.circle.fill"
                  : "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(calendarService.isSignedIn ? .green : .orange)
        }
    }

    // MARK: - Callback

    private func handleResult(_ result: Result<[Shift], Error>) {
        isLoading = false
        switch result {
        case .success(let detected):
            shifts = detected
            showResult = true
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Loading overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("📄 読み取り中...")
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

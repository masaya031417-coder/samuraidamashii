// ContentView.swift - ボトムタブナビゲーション（AppState でタブを共有管理）

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var calendarService = CalendarService()
    @State private var shifts: [Shift] = []
    @State private var showResult = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // タブ0: 音声入力
            NavigationStack {
                VoiceView(onResult: handleResult, isLoading: $isLoading)
                    .navigationTitle("音声で登録")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { signInStatusButton }
            }
            .tabItem { Label("音声", systemImage: "mic.fill") }
            .tag(0)

            // タブ1: ファイル選択
            NavigationStack {
                FilePickerView(onResult: handleResult, isLoading: $isLoading)
                    .navigationTitle("ファイルで登録")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { signInStatusButton }
            }
            .tabItem { Label("ファイル", systemImage: "doc.fill") }
            .tag(1)

            // タブ2: 会話型ウィザード入力（「予定を入れて」で起動）
            NavigationStack {
                TextInputView(onResult: handleResult, isLoading: $isLoading)
                    .navigationTitle("入力して登録")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { signInStatusButton }
            }
            .tabItem { Label("入力", systemImage: "bubble.left.and.text.bubble.right") }
            .tag(2)

            // タブ3: 削除
            DeleteView(calendarService: calendarService)
                .tabItem { Label("削除", systemImage: "trash") }
                .tag(3)
        }
        .sheet(isPresented: $showResult) {
            ResultView(shifts: shifts, calendarService: calendarService)
        }
        .overlay {
            if isLoading { LoadingOverlay() }
        }
        .alert("エラー", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            calendarService.restoreSignIn()
        }
    }

    // MARK: - Toolbar

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

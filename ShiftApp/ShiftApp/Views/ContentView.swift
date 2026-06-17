// ContentView.swift - メイン画面（音声 / ファイル / テキスト の3モードを切り替え）

import SwiftUI

struct ContentView: View {
    @StateObject private var calendarService = CalendarService()
    @State private var shifts: [Shift] = []
    @State private var showResult = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                // 入力モード切り替えセグメントコントロール
                Picker("入力モード", selection: $selectedTab) {
                    Label("音声",     systemImage: "mic.fill").tag(0)
                    Label("ファイル", systemImage: "doc.fill").tag(1)
                    Label("テキスト", systemImage: "text.quote").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // 各入力ビュー（スワイプで切り替え可能）
                TabView(selection: $selectedTab) {
                    VoiceView(onResult: handleResult, isLoading: $isLoading)
                        .tag(0)
                    FilePickerView(onResult: handleResult, isLoading: $isLoading)
                        .tag(1)
                    TextInputView(onResult: handleResult, isLoading: $isLoading)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            // エラーアラート
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            // 結果シート
            .sheet(isPresented: $showResult) {
                ResultView(shifts: shifts, calendarService: calendarService)
            }
            // ローディングオーバーレイ
            .overlay {
                if isLoading { LoadingOverlay() }
            }
        }
        .onAppear {
            calendarService.restoreSignIn()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("シフト自動登録")
                    .font(.title2.bold())
                Text("PDF・画像・音声からカレンダーへ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Googleサインイン状態インジケーター
            Image(systemName: calendarService.isSignedIn
                  ? "checkmark.circle.fill"
                  : "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(calendarService.isSignedIn ? .green : .orange)
                .font(.title2)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Callbacks

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

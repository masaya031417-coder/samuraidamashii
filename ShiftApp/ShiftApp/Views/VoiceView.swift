// VoiceView.swift - 音声入力でシフト情報を読み取るビュー
// 「予定を入れて」を検出したら入力ウィザードへ自動切り替え

import SwiftUI

struct VoiceView: View {
    let onResult: (Result<[Shift], Error>) -> Void
    @Binding var isLoading: Bool

    @EnvironmentObject var appState: AppState
    @StateObject private var speech = SpeechService()
    @StateObject private var api    = APIService()
    @State private var hasPermission = false
    @State private var showPermissionAlert = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 録音状態アニメーション
            ZStack {
                Circle()
                    .fill(speech.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(speech.isRecording ? 1.12 : 1.0)
                    .animation(
                        speech.isRecording
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: speech.isRecording
                    )
                Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(speech.isRecording ? .red : .blue)
            }

            // リアルタイム認識テキスト
            Group {
                if !speech.transcribedText.isEmpty {
                    Text(speech.transcribedText)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(speech.isRecording
                         ? "話してください...\n（「予定を入れて」でステップ入力へ切り替わります）"
                         : "マイクを押して話してください\n「予定を入れて」でウィザード起動")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            // 録音ボタン
            Button { handleMicTap() } label: {
                Text(speech.isRecording ? "停止して解析" : "録音開始")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(speech.isRecording ? Color.red : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!hasPermission)
            .padding(.horizontal, 32)

            Spacer()
        }
        .task {
            hasPermission = await speech.requestPermissions()
            if !hasPermission { showPermissionAlert = true }
        }
        // 録音停止後の処理
        .onChange(of: speech.isRecording) { _, isRecording in
            guard !isRecording else { return }
            let text = speech.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            // 「予定を入れて」系のフレーズを検出 → ウィザードタブへ切り替え
            if isWizardTrigger(text) {
                speech.transcribedText = ""
                appState.openWizard()
                return
            }

            // 通常のシフトテキストとして解析
            submitText(text)
        }
        .onChange(of: speech.errorMessage) { _, msg in
            if let msg { onResult(.failure(SpeechError(message: msg))) }
        }
        .alert("マイクの許可が必要", isPresented: $showPermissionAlert) {
            Button("設定を開く") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("設定アプリからマイクと音声認識の使用を許可してください")
        }
    }

    // MARK: - Private

    /// 「予定を入れて」「予定いれて」などのトリガーフレーズを判定
    private func isWizardTrigger(_ text: String) -> Bool {
        let t = text
        return (t.contains("予定") || t.contains("よてい")) &&
               (t.contains("入れ") || t.contains("いれ") || t.contains("入力") || t.contains("追加"))
    }

    private func handleMicTap() {
        if speech.isRecording { speech.stopRecording() }
        else                  { speech.startRecording() }
    }

    private func submitText(_ text: String) {
        isLoading = true
        Task {
            do {
                let shifts = try await api.parseText(text)
                onResult(.success(shifts))
            } catch {
                onResult(.failure(error))
            }
        }
    }
}

private struct SpeechError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// VoiceView.swift - 音声入力でシフト情報を読み取るビュー

import SwiftUI

struct VoiceView: View {
    let onResult: (Result<[Shift], Error>) -> Void
    @Binding var isLoading: Bool

    @StateObject private var speech = SpeechService()
    @StateObject private var api    = APIService()
    @State private var hasPermission = false
    @State private var showPermissionAlert = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 録音状態を示すアニメーション付きマイクアイコン
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

            // リアルタイム認識テキスト表示
            Group {
                if !speech.transcribedText.isEmpty {
                    Text(speech.transcribedText)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(speech.isRecording ? "話してください..." : "マイクボタンを押して話してください\n例：「6月21日 18時から23時のシフト」")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            // 録音開始 / 停止して解析 ボタン
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
        // 起動時に権限確認
        .task {
            hasPermission = await speech.requestPermissions()
            if !hasPermission { showPermissionAlert = true }
        }
        // 録音停止→テキスト確定後に自動でAPI送信
        .onChange(of: speech.isRecording) { _, isRecording in
            if !isRecording, !speech.transcribedText.isEmpty {
                submitText(speech.transcribedText)
            }
        }
        // エラーメッセージ（SpeechService内）
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

    private func handleMicTap() {
        if speech.isRecording {
            speech.stopRecording()
        } else {
            speech.startRecording()
        }
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

/// SpeechServiceのエラーを Result に乗せるためのラッパー
private struct SpeechError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

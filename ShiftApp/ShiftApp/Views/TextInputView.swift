// TextInputView.swift - テキスト（メール文など）を直接入力してシフトを読み取るビュー

import SwiftUI

struct TextInputView: View {
    let onResult: (Result<[Shift], Error>) -> Void
    @Binding var isLoading: Bool

    @StateObject private var api = APIService()
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("採用メールやシフト情報を貼り付けてください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            // テキスト入力エリア（プレースホルダー付き）
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.body)
                    .padding(8)
                    .focused($isFocused)
                    .frame(maxHeight: .infinity)

                if inputText.isEmpty {
                    Text("例：勤務日時：2026/06/14(日) 08:00-20:00\n場所：GLION ARENA KOBE")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            // テキストクリアボタン（入力あり時のみ）
            if !inputText.isEmpty {
                Button("クリア") { inputText = "" }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 解析ボタン
            Button {
                isFocused = false
                isLoading = true
                Task {
                    do {
                        let shifts = try await api.parseText(inputText)
                        onResult(.success(shifts))
                    } catch {
                        onResult(.failure(error))
                    }
                }
            } label: {
                Label("シフトを解析", systemImage: "sparkles")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }
}

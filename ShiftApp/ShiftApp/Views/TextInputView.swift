// TextInputView.swift - 会話型ステップ入力ウィザード
// 「現在の質問は step から直接表示」「過去のQ&Aだけ履歴配列」でズレを排除

import SwiftUI

// MARK: - Step

private enum Step {
    case date      // 何日ですか？
    case place     // 場所はどこですか？
    case startTime // 何時からですか？
    case endTime   // 何時までですか？
    case confirm   // 確認
}

// MARK: - History item（確定した過去のQ&Aペア）

private struct HistoryItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - Main view

struct TextInputView: View {
    let onResult: (Result<[Shift], Error>) -> Void
    @Binding var isLoading: Bool

    @StateObject private var api = APIService()

    // 現在のステップ（これだけで「何を聞いているか」が決まる）
    @State private var step: Step = .date
    // 確定した過去のQ&Aペア
    @State private var history: [HistoryItem] = []
    @State private var currentInput = ""
    @FocusState private var focused: Bool

    // 収集した値
    @State private var storedDate      = ""
    @State private var storedPlace     = ""
    @State private var storedStartTime = ""
    @State private var storedEndTime   = ""

    // step から現在の質問テキストを導出（非同期不要・常にズレない）
    private var currentQuestion: String? {
        switch step {
        case .date:      return "📅 何日ですか？\n例：6月21日、2026/6/21"
        case .place:     return "📍 場所はどこですか？\n（ない場合はそのまま次へ）"
        case .startTime: return "🕐 何時からですか？\n例：18時、18:00"
        case .endTime:   return "🕕 何時までですか？\n例：23時、23:00"
        case .confirm:   return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── チャット表示エリア ──
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        // 過去のQ&Aを表示
                        ForEach(history) { item in
                            BubbleRow(isApp: true,  text: item.question)
                            BubbleRow(isApp: false, text: item.answer)
                        }

                        // 現在の質問（stepから直接描画・asyncAfter不要）
                        if let q = currentQuestion {
                            BubbleRow(isApp: true, text: q)
                                .id("currentQ")
                        }

                        // 確認カード
                        if step == .confirm {
                            confirmCard.id("confirm")
                        }

                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                }
                // step が進んだら末尾へスクロール
                .onChange(of: step) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider()

            // ── 入力バー（確認ステップでは非表示）──
            if step != .confirm {
                inputBar
            }
        }
    }

    // MARK: - 入力バー

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $currentInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { advance() }

            Button { advance() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(canAdvance ? .blue : .gray)
            }
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canAdvance: Bool {
        step == .place || !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholder: String {
        switch step {
        case .date:      return "例：6月21日"
        case .place:     return "例：グリオンアリーナ神戸（ない場合はそのまま次へ）"
        case .startTime: return "例：18時"
        case .endTime:   return "例：23時"
        case .confirm:   return ""
        }
    }

    // MARK: - 確認カード

    private var confirmCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 12) {
                Text("以下の内容でよろしいですか？")
                    .font(.subheadline.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Label(storedDate, systemImage: "calendar")
                    Label(storedPlace.isEmpty ? "場所なし" : storedPlace,
                          systemImage: "mappin.and.ellipse")
                    Label("\(storedStartTime) 〜 \(storedEndTime)", systemImage: "clock")
                }
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button { resetWizard() } label: {
                        Label("やり直す", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.primary)
                    }
                    Button { submitToAPI() } label: {
                        Label("登録する", systemImage: "calendar.badge.plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - ウィザードロジック

    /// 「次へ」ボタン。step と history だけを更新すれば画面は自動的に追従する
    private func advance() {
        let value = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)

        switch step {
        case .date:
            guard !value.isEmpty else { return }
            history.append(HistoryItem(
                question: "📅 何日ですか？\n例：6月21日、2026/6/21",
                answer: value
            ))
            storedDate = value
            currentInput = ""
            step = .place

        case .place:
            let display = value.isEmpty ? "（場所なし）" : value
            history.append(HistoryItem(
                question: "📍 場所はどこですか？\n（ない場合はそのまま次へ）",
                answer: display
            ))
            storedPlace = value
            currentInput = ""
            step = .startTime

        case .startTime:
            guard !value.isEmpty else { return }
            history.append(HistoryItem(
                question: "🕐 何時からですか？\n例：18時、18:00",
                answer: value
            ))
            storedStartTime = value
            currentInput = ""
            step = .endTime

        case .endTime:
            guard !value.isEmpty else { return }
            history.append(HistoryItem(
                question: "🕕 何時までですか？\n例：23時、23:00",
                answer: value
            ))
            storedEndTime = value
            currentInput = ""
            step = .confirm

        case .confirm:
            break
        }
    }

    /// 「やり直す」ボタン
    private func resetWizard() {
        step = .date
        history = []
        currentInput = ""
        storedDate = ""; storedPlace = ""; storedStartTime = ""; storedEndTime = ""
    }

    /// Claude API にテキストを送信
    private func submitToAPI() {
        var parts = ["日付：\(storedDate)"]
        if !storedPlace.isEmpty { parts.append("場所：\(storedPlace)") }
        parts.append("\(storedStartTime)から\(storedEndTime)まで")

        isLoading = true
        Task {
            do {
                let shifts = try await api.parseText(parts.joined(separator: " "))
                onResult(.success(shifts))
            } catch {
                onResult(.failure(error))
            }
        }
    }
}

// MARK: - 吹き出し行

private struct BubbleRow: View {
    let isApp: Bool
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isApp {
                Image(systemName: "calendar.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.blue.opacity(0.1), in: AppBubble())
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .leading)

                Spacer()
            } else {
                Spacer()

                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.blue, in: UserBubble())
                    .foregroundStyle(.white)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .trailing)
            }
        }
    }
}

// MARK: - 吹き出し形状

private struct AppBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 14; let t: CGFloat = 7
        p.addRoundedRect(in: CGRect(x: t, y: 0, width: rect.width - t, height: rect.height),
                         cornerSize: CGSize(width: r, height: r))
        p.move(to: CGPoint(x: t, y: rect.height - 18))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: t + 4, y: rect.height - 12))
        return p
    }
}

private struct UserBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 14; let t: CGFloat = 7
        p.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width - t, height: rect.height),
                         cornerSize: CGSize(width: r, height: r))
        p.move(to: CGPoint(x: rect.width - t, y: rect.height - 18))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width - t - 4, y: rect.height - 12))
        return p
    }
}

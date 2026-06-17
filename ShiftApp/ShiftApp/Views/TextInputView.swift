// TextInputView.swift - ステップ形式の会話型シフト入力ビュー
// 日付 → 場所 → 時間 の順に聞いて、最後に確認してから登録する

import SwiftUI

// MARK: - Step 定義

private enum Step {
    case date    // 日にちはいつですか？
    case place   // 場所はどこですか？
    case time    // 何時から何時ですか？
    case confirm // 確認
}

// MARK: - チャットメッセージモデル

private struct ChatMsg: Identifiable {
    let id = UUID()
    let isApp: Bool  // true = アプリの吹き出し、false = ユーザーの入力
    let text: String
}

// MARK: - メインビュー

struct TextInputView: View {
    let onResult: (Result<[Shift], Error>) -> Void
    @Binding var isLoading: Bool

    @StateObject private var api = APIService()
    @State private var step: Step = .date
    @State private var messages: [ChatMsg] = []
    @State private var currentInput = ""
    @FocusState private var focused: Bool

    // 各ステップで収集する値
    @State private var storedDate  = ""
    @State private var storedPlace = ""
    @State private var storedTime  = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── チャット履歴エリア ──
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(messages) { msg in
                            BubbleRow(msg: msg).id(msg.id)
                        }
                        // 確認カードは履歴の末尾に表示
                        if step == .confirm {
                            confirmCard.id("confirm")
                        }
                        // スクロール余白
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                }
                // 新しいメッセージが来たら末尾へスクロール
                .onChange(of: messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: step) { s in
                    if s == .confirm {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("confirm", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // ── テキスト入力バー（確認ステップでは非表示）──
            if step != .confirm {
                inputBar
            }
        }
        .onAppear { startWizard() }
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
                    // 場所ステップは空でも進める
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
        case .date:  return "例：6月21日"
        case .place: return "例：グリオンアリーナ神戸（ない場合はそのまま次へ）"
        case .time:  return "例：18時から23時"
        case .confirm: return ""
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

                // 入力内容サマリー
                VStack(alignment: .leading, spacing: 8) {
                    Label(storedDate,
                          systemImage: "calendar")
                    Label(storedPlace.isEmpty ? "場所なし" : storedPlace,
                          systemImage: "mappin.and.ellipse")
                    Label(storedTime,
                          systemImage: "clock")
                }
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                // アクションボタン
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { startWizard() }
                    } label: {
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

    /// 最初から始める
    private func startWizard() {
        messages = []
        currentInput = ""
        storedDate = ""; storedPlace = ""; storedTime = ""
        step = .date
        // 少し遅らせてから最初の質問を表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            say("📅 日にちはいつですか？\n例：6月21日、2026/6/21")
            focused = true
        }
    }

    /// 「次へ」を押したときの処理
    private func advance() {
        let value = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)

        switch step {
        case .date:
            guard !value.isEmpty else { return }
            storedDate = value
            reply(value)
            currentInput = ""
            step = .place
            later { say("📍 場所はどこですか？\n（ない場合はそのまま次へ）") }

        case .place:
            storedPlace = value
            reply(value.isEmpty ? "（場所なし）" : value)
            currentInput = ""
            step = .time
            later { say("🕐 何時から何時ですか？\n例：18時から23時、18:00〜23:00") }

        case .time:
            guard !value.isEmpty else { return }
            storedTime = value
            reply(value)
            currentInput = ""
            focused = false
            // 少し間を置いてから確認カードへ
            later { step = .confirm }

        case .confirm:
            break
        }
    }

    /// APIにテキストを送信して結果を受け取る
    private func submitToAPI() {
        // 「場所、時間の順番」で組み立てる
        var parts = ["勤務日時：\(storedDate)"]
        if !storedPlace.isEmpty { parts.append("場所：\(storedPlace)") }
        parts.append(storedTime)
        let text = parts.joined(separator: " ")

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

    // MARK: - ヘルパー

    /// アプリの吹き出しを追加
    private func say(_ text: String) {
        messages.append(ChatMsg(isApp: true, text: text))
    }

    /// ユーザーの返答を追加
    private func reply(_ text: String) {
        messages.append(ChatMsg(isApp: false, text: text))
    }

    /// 少し遅らせて実行（会話のテンポを作る）
    private func later(_ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: block)
    }
}

// MARK: - チャット吹き出し行

private struct BubbleRow: View {
    let msg: ChatMsg

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.isApp {
                // アプリ側（左揃え）
                Image(systemName: "calendar.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .alignmentGuide(.bottom) { d in d[.bottom] }

                Text(msg.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.blue.opacity(0.1),
                                in: AppBubble())
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .leading)

                Spacer()

            } else {
                // ユーザー側（右揃え）
                Spacer()

                Text(msg.text)
                    .font(.body)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.blue, in: UserBubble())
                    .foregroundStyle(.white)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .trailing)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: msg.isApp ? .leading : .trailing).combined(with: .opacity),
            removal:   .opacity
        ))
        .animation(.spring(duration: 0.3), value: msg.id)
    }
}

// MARK: - 吹き出し形状（左・右）

/// アプリ側：左下に小さなしっぽ
private struct AppBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 14
        let tail: CGFloat = 7
        p.addRoundedRect(
            in: CGRect(x: tail, y: 0, width: rect.width - tail, height: rect.height),
            cornerSize: CGSize(width: r, height: r)
        )
        // しっぽ
        p.move(to: CGPoint(x: tail, y: rect.height - 18))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: tail + 4, y: rect.height - 12))
        return p
    }
}

/// ユーザー側：右下に小さなしっぽ
private struct UserBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 14
        let tail: CGFloat = 7
        p.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width - tail, height: rect.height),
            cornerSize: CGSize(width: r, height: r)
        )
        // しっぽ
        p.move(to: CGPoint(x: rect.width - tail, y: rect.height - 18))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width - tail - 4, y: rect.height - 12))
        return p
    }
}

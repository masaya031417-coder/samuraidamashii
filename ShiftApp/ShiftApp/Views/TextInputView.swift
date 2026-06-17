// TextInputView.swift - 会話型ステップ入力ウィザード
// 「予定を入れて」で起動 → 何日 → 場所 → 何時から → 何時まで → 確認

import SwiftUI

// MARK: - Step

private enum Step {
    case date      // 何日ですか？
    case place     // 場所はどこですか？
    case startTime // 何時からですか？
    case endTime   // 何時までですか？
    case confirm   // 確認
}

// MARK: - Chat message

private struct ChatMsg: Identifiable {
    let id = UUID()
    let isApp: Bool
    let text: String
}

// MARK: - Main view

struct TextInputView: View {
    let onResult: (Result<[Shift], Error>) -> Void
    @Binding var isLoading: Bool

    @StateObject private var api = APIService()
    @State private var step: Step = .date
    @State private var messages: [ChatMsg] = []
    @State private var currentInput = ""
    @FocusState private var focused: Bool

    @State private var storedDate      = ""
    @State private var storedPlace     = ""
    @State private var storedStartTime = ""
    @State private var storedEndTime   = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── チャット履歴 ──
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(messages) { msg in
                            BubbleRow(msg: msg).id(msg.id)
                        }
                        if step == .confirm {
                            confirmCard.id("confirm")
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                }
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

            // ── 入力バー ──
            if step != .confirm {
                inputBar
            }
        }
        .onAppear { startWizard() }
        // タブが再選択されたときもウィザードをリセット（edge case 対応）
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
        // 場所だけ空でも進める
        step == .place || !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholder: String {
        switch step {
        case .date:      return "例：6月21日、2026/6/21"
        case .place:     return "例：グリオンアリーナ神戸（ない場合はそのまま次へ）"
        case .startTime: return "例：18時、18:00"
        case .endTime:   return "例：23時、23:00"
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

                // 入力サマリー
                VStack(alignment: .leading, spacing: 8) {
                    Label(storedDate,
                          systemImage: "calendar")
                    Label(storedPlace.isEmpty ? "場所なし" : storedPlace,
                          systemImage: "mappin.and.ellipse")
                    Label("\(storedStartTime) 〜 \(storedEndTime)",
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

    private func startWizard() {
        messages = []
        currentInput = ""
        storedDate = ""; storedPlace = ""; storedStartTime = ""; storedEndTime = ""
        step = .date
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            say("📅 何日ですか？\n例：6月21日、2026/6/21")
            focused = true
        }
    }

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
            step = .startTime
            later { say("🕐 何時からですか？\n例：18時、18:00") }

        case .startTime:
            guard !value.isEmpty else { return }
            storedStartTime = value
            reply(value)
            currentInput = ""
            step = .endTime
            later { say("🕕 何時までですか？\n例：23時、23:00") }

        case .endTime:
            guard !value.isEmpty else { return }
            storedEndTime = value
            reply(value)
            currentInput = ""
            focused = false
            later { step = .confirm }

        case .confirm:
            break
        }
    }

    private func submitToAPI() {
        // Claude に渡すテキスト：場所・時間の順に組み立てる
        var parts = ["日付：\(storedDate)"]
        if !storedPlace.isEmpty { parts.append("場所：\(storedPlace)") }
        parts.append("\(storedStartTime)から\(storedEndTime)まで")
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

    private func say(_ text: String) {
        messages.append(ChatMsg(isApp: true, text: text))
    }

    private func reply(_ text: String) {
        messages.append(ChatMsg(isApp: false, text: text))
    }

    private func later(_ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: block)
    }
}

// MARK: - 吹き出し行

private struct BubbleRow: View {
    let msg: ChatMsg

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.isApp {
                Image(systemName: "calendar.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text(msg.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.blue.opacity(0.1), in: AppBubble())
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .leading)

                Spacer()
            } else {
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

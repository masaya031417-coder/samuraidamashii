import SwiftUI
import EventKit

// MARK: - Step

enum WizardStep: Int, CaseIterable {
    case date, location, startTime, endTime, confirmation

    var title: String {
        switch self {
        case .date: return "日付"
        case .location: return "場所"
        case .startTime: return "開始"
        case .endTime: return "終了"
        case .confirmation: return "確認"
        }
    }
}

// MARK: - View

struct TextInputView: View {
    @State private var step: WizardStep = .date
    @State private var selectedDate = Date()
    @State private var location = ""
    @State private var startTime = Date()
    @State private var endTime: Date = {
        Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
    }()
    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var errorMsg = ""

    private let store = EKEventStore()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                progressBar
                    .padding()

                ScrollView {
                    stepContent
                        .padding()
                        .animation(.easeInOut, value: step)
                }

                navButtons
                    .padding()
            }
            .navigationTitle("予定を入れる")
            .alert("登録しました", isPresented: $showSuccess) {
                Button("OK") { resetWizard() }
            }
            .alert(errorMsg, isPresented: .constant(!errorMsg.isEmpty)) {
                Button("OK") { errorMsg = "" }
            }
        }
    }

    // MARK: Progress bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(WizardStep.allCases, id: \.rawValue) { s in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue >= s.rawValue ? Color.blue : Color(.systemGray4))
                        .frame(width: 28, height: 28)
                        .overlay(Text("\(s.rawValue + 1)").font(.caption2).foregroundColor(.white))
                    Text(s.title)
                        .font(.caption2)
                        .foregroundColor(step.rawValue >= s.rawValue ? .blue : .secondary)
                }
                if s != WizardStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue > s.rawValue ? Color.blue : Color(.systemGray4))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .date:
            VStack(alignment: .leading, spacing: 12) {
                Text("日付を選んでください").font(.headline)
                DatePicker("日付", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
            }

        case .location:
            VStack(alignment: .leading, spacing: 12) {
                Text("場所を入力してください").font(.headline)
                TextField("例：渋谷店・倉庫A（省略可）", text: $location)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
            }

        case .startTime:
            VStack(alignment: .leading, spacing: 12) {
                Text("開始時間を選んでください").font(.headline)
                DatePicker("開始時間", selection: $startTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .labelsHidden()
            }

        case .endTime:
            VStack(alignment: .leading, spacing: 12) {
                Text("終了時間を選んでください").font(.headline)
                DatePicker("終了時間", selection: $endTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .labelsHidden()
            }

        case .confirmation:
            VStack(alignment: .leading, spacing: 16) {
                Text("内容を確認してください").font(.headline)
                VStack(spacing: 0) {
                    confirmRow("calendar",        "日付",   fmt(date: selectedDate))
                    Divider()
                    confirmRow("mappin.and.ellipse", "場所", location.isEmpty ? "（未設定）" : location)
                    Divider()
                    confirmRow("clock",            "開始時間", fmt(time: startTime))
                    Divider()
                    confirmRow("clock.badge.checkmark", "終了時間", fmt(time: endTime))
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    private func confirmRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding()
    }

    // MARK: Nav buttons

    private var navButtons: some View {
        HStack(spacing: 16) {
            if step != .date {
                Button("戻る") { withAnimation { step = WizardStep(rawValue: step.rawValue - 1) ?? .date } }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step == .confirmation {
                Button(action: createEvent) {
                    if isCreating {
                        ProgressView().padding(.horizontal)
                    } else {
                        Label("カレンダーに登録", systemImage: "calendar.badge.plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
            } else {
                Button("次へ") { withAnimation { step = WizardStep(rawValue: step.rawValue + 1) ?? .confirmation } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Calendar

    private func createEvent() {
        isCreating = true
        Task {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
            } else {
                granted = await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
                }
            }

            await MainActor.run {
                defer { isCreating = false }
                guard granted else { errorMsg = "カレンダーへのアクセスが許可されていません"; return }

                let event = EKEvent(eventStore: store)
                event.title = "シフト"
                if !location.isEmpty { event.location = location }
                event.calendar = store.defaultCalendarForNewEvents
                event.startDate = combine(date: selectedDate, time: startTime)
                event.endDate   = combine(date: selectedDate, time: endTime)

                do {
                    try store.save(event, span: .thisEvent)
                    showSuccess = true
                } catch {
                    errorMsg = "登録失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    private func combine(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        var d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        d.hour = t.hour; d.minute = t.minute
        return cal.date(from: d) ?? date
    }

    private func resetWizard() {
        step = .date
        selectedDate = Date()
        location = ""
        startTime = Date()
        endTime = Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
    }

    // MARK: Formatting

    private func fmt(date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP"); f.dateStyle = .long
        return f.string(from: date)
    }

    private func fmt(time: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP"); f.timeStyle = .short
        return f.string(from: time)
    }
}

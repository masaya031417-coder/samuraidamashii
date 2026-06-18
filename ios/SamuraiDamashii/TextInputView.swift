import SwiftUI

// MARK: - Step

enum WizardStep: Int, CaseIterable {
    case date, location, startTime, endTime, confirmation

    var title: String {
        switch self {
        case .date:         return "日付"
        case .location:     return "場所"
        case .startTime:    return "開始"
        case .endTime:      return "終了"
        case .confirmation: return "確認"
        }
    }
}

// MARK: - View

struct TextInputView: View {
    @StateObject private var gcal = GoogleCalendarService.shared
    @State private var step: WizardStep = .date
    @State private var selectedDate = Date()
    @State private var location = ""
    @State private var startTime = Date()
    @State private var endTime: Date = Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
    @State private var isWorking = false
    @State private var showSuccess = false
    @State private var errorMsg = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !gcal.isSignedIn {
                    signInBanner
                } else {
                    progressBar.padding()
                    ScrollView {
                        stepContent.padding().animation(.easeInOut, value: step)
                    }
                    navButtons.padding()
                }
            }
            .navigationTitle("予定を入れる")
            .alert("Googleカレンダーに登録しました", isPresented: $showSuccess) {
                Button("OK") { resetWizard() }
            }
            .alert(errorMsg, isPresented: .constant(!errorMsg.isEmpty)) {
                Button("OK") { errorMsg = "" }
            }
        }
    }

    // MARK: Sign-in banner

    private var signInBanner: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("Googleカレンダーに予定を登録するには\nサインインが必要です")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button(action: {
                isWorking = true
                Task {
                    do { try await gcal.signIn() }
                    catch { await MainActor.run { errorMsg = error.localizedDescription } }
                    await MainActor.run { isWorking = false }
                }
            }) {
                if isWorking {
                    ProgressView().padding(.horizontal)
                } else {
                    Label("Googleでサインイン", systemImage: "person.badge.key")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                    Text(s.title).font(.caption2)
                        .foregroundColor(step.rawValue >= s.rawValue ? .blue : .secondary)
                }
                if s != WizardStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue > s.rawValue ? Color.blue : Color(.systemGray4))
                        .frame(height: 2).frame(maxWidth: .infinity).padding(.bottom, 16)
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
                    .datePickerStyle(.wheel).labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
            }
        case .endTime:
            VStack(alignment: .leading, spacing: 12) {
                Text("終了時間を選んでください").font(.headline)
                DatePicker("終了時間", selection: $endTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
            }
        case .confirmation:
            VStack(alignment: .leading, spacing: 16) {
                Text("内容を確認してください").font(.headline)
                VStack(spacing: 0) {
                    confirmRow("calendar",             "日付",   fmtDate(selectedDate))
                    Divider()
                    confirmRow("mappin.and.ellipse",   "場所",   location.isEmpty ? "（未設定）" : location)
                    Divider()
                    confirmRow("clock",                "開始時間", fmtTime(startTime))
                    Divider()
                    confirmRow("clock.badge.checkmark","終了時間", fmtTime(endTime))
                }
                .background(Color(.systemGray6)).cornerRadius(12)

                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.green)
                    Text("Googleカレンダーに登録します")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    private func confirmRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 24)
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }.padding()
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
                    if isWorking {
                        ProgressView().padding(.horizontal)
                    } else {
                        Label("Googleカレンダーに登録", systemImage: "calendar.badge.plus")
                    }
                }
                .buttonStyle(.borderedProminent).disabled(isWorking)
            } else {
                Button("次へ") { withAnimation { step = WizardStep(rawValue: step.rawValue + 1) ?? .confirmation } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Create event

    private func createEvent() {
        isWorking = true
        Task {
            do {
                try await GoogleCalendarService.shared.createShiftEvent(
                    date: selectedDate,
                    location: location,
                    startTime: startTime,
                    endTime: endTime
                )
                await MainActor.run { showSuccess = true }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
            await MainActor.run { isWorking = false }
        }
    }

    private func resetWizard() {
        step = .date; selectedDate = Date(); location = ""
        startTime = Date()
        endTime = Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
    }

    // MARK: Formatting

    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateStyle = .long
        return f.string(from: d)
    }
    private func fmtTime(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.timeStyle = .short
        return f.string(from: d)
    }
}

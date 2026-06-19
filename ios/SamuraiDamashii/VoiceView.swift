import SwiftUI
import Speech
import AVFoundation

// MARK: - Manager

class VoiceRecognitionManager: NSObject, ObservableObject {
    @Published var transcribedText = ""
    @Published var isRecording = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var onWizardTrigger: (() -> Void)?

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else { return }
        req.shouldReportPartialResults = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        DispatchQueue.main.async { self.isRecording = true; self.transcribedText = "" }

        recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            DispatchQueue.main.async {
                self.transcribedText = text
                if text.contains("予定を入れて") {
                    self.stopRecording()
                    self.onWizardTrigger?()
                }
            }
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        DispatchQueue.main.async { self.isRecording = false }
    }
}

// MARK: - View

struct VoiceView: View {
    @StateObject private var manager = VoiceRecognitionManager()
    @State private var showWizard = false
    @State private var apiResponse = ""
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                transcriptBox

                recordButton

                if manager.isRecording {
                    Text("録音中… 「予定を入れて」でウィザード起動")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if !manager.transcribedText.isEmpty && !manager.isRecording {
                    sendButton
                }

                if !apiResponse.isEmpty {
                    responseBox
                }

                Spacer()
            }
            .navigationTitle("音声入力")
            .onAppear {
                manager.requestPermissions()
                manager.onWizardTrigger = { showWizard = true }
            }
            .sheet(isPresented: $showWizard) {
                TextInputView()
            }
        }
    }

    private var transcriptBox: some View {
        ScrollView {
            Text(manager.transcribedText.isEmpty ? "マイクボタンを押して録音開始" : manager.transcribedText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 180)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var recordButton: some View {
        Button(action: {
            if manager.isRecording { manager.stopRecording() } else { manager.startRecording() }
        }) {
            ZStack {
                Circle()
                    .fill(manager.isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                Image(systemName: manager.isRecording ? "stop.fill" : "mic.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 30))
            }
        }
    }

    private var sendButton: some View {
        Button(action: sendToAPI) {
            if isProcessing {
                ProgressView().padding(.horizontal)
            } else {
                Label("APIに送信", systemImage: "paperplane.fill")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isProcessing)
    }

    private var responseBox: some View {
        ScrollView {
            Text(apiResponse)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 150)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func sendToAPI() {
        isProcessing = true
        Task {
            let text = manager.transcribedText
            let response = await APIService.shared.sendText(text)
            await MainActor.run {
                apiResponse = response
                isProcessing = false
            }
        }
    }
}

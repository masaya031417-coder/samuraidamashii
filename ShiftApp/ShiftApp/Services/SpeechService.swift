// SpeechService.swift - マイクからの音声入力をテキストに変換するサービス
// SFSpeechRecognizer（日本語）を使用

import AVFoundation
import Foundation
import Speech

@MainActor
class SpeechService: NSObject, ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        // 日本語音声認識エンジンを初期化
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    }

    // MARK: - Permissions

    /// マイクと音声認識の権限をまとめてリクエストする
    func requestPermissions() async -> Bool {
        // マイク権限リクエスト
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            errorMessage = "マイクへのアクセスが許可されていません"
            return false
        }

        // 音声認識権限リクエスト
        let speechGranted = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        if !speechGranted {
            errorMessage = "音声認識へのアクセスが許可されていません"
        }
        return speechGranted
    }

    // MARK: - Recording control

    /// 録音・音声認識を開始する
    func startRecording() {
        guard !isRecording else { return }

        transcribedText = ""
        errorMessage = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let req = recognitionRequest else { return }

            // 発話中にもリアルタイムで認識結果を受け取る
            req.shouldReportPartialResults = true

            recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                    // エラーまたは最終結果で録音を停止
                    if error != nil || result?.isFinal == true {
                        self.stopRecording()
                    }
                }
            }

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

        } catch {
            errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 録音・音声認識を停止する
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

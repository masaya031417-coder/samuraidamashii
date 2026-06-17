// FilePickerView.swift - PDF・画像ファイルを選択してシフトを読み取るビュー

import SwiftUI
import UniformTypeIdentifiers

struct FilePickerView: View {
    let onResult: (Result<[Shift], Error>) -> Void
    @Binding var isLoading: Bool

    @StateObject private var api = APIService()
    @State private var showPDFPicker   = false
    @State private var showImagePicker = false
    @State private var pickedFilename: String? = nil
    @State private var nameInput = "山本"

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("PDF・画像からシフトを読み取ります")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                // 選択済みファイル名を表示
                if let name = pickedFilename {
                    Label(name, systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // PDF読み取り時の名前フィールド
                HStack {
                    Text("検索する名前（PDF）")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("例：山本", text: $nameInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 130)
                }
                .padding(.horizontal, 32)

                // ファイル選択ボタン
                VStack(spacing: 14) {
                    Button { showPDFPicker = true } label: {
                        Label("PDFを選択", systemImage: "doc.fill")
                            .actionButtonStyle(color: .blue)
                    }

                    Button { showImagePicker = true } label: {
                        Label("画像・スクショを選択", systemImage: "photo")
                            .actionButtonStyle(color: .teal)
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 20)
            }
        }
        // PDFピッカー
        .sheet(isPresented: $showPDFPicker) {
            DocumentPickerView(types: [.pdf]) { url in
                loadFile(url: url)
            }
        }
        // 画像ピッカー
        .sheet(isPresented: $showImagePicker) {
            DocumentPickerView(types: [.png, .jpeg, .image]) { url in
                loadFile(url: url)
            }
        }
    }

    private func loadFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            onResult(.failure(FileError.cannotRead))
            return
        }

        pickedFilename = url.lastPathComponent
        isLoading = true

        Task {
            do {
                let shifts = try await api.parseFile(data, filename: url.lastPathComponent, name: nameInput)
                onResult(.success(shifts))
            } catch {
                onResult(.failure(error))
            }
        }
    }

    enum FileError: LocalizedError {
        case cannotRead
        var errorDescription: String? { "ファイルを読み込めませんでした" }
    }
}

// MARK: - DocumentPicker wrapper

struct DocumentPickerView: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}

// MARK: - View modifier helper

private extension View {
    func actionButtonStyle(color: Color) -> some View {
        self
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

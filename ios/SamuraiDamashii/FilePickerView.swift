import SwiftUI
import UniformTypeIdentifiers

struct FilePickerView: View {
    @State private var showPicker = false
    @State private var selectedName = ""
    @State private var selectedData: Data?
    @State private var isPDF = false
    @State private var apiResponse = ""
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                dropZone

                if !selectedName.isEmpty {
                    selectedFileRow
                    sendButton
                }

                if !apiResponse.isEmpty {
                    responseBox
                }

                Spacer()
            }
            .navigationTitle("ファイル選択")
            .sheet(isPresented: $showPicker) {
                DocumentPicker(selectedName: $selectedName, selectedData: $selectedData, isPDF: $isPDF)
            }
        }
    }

    private var dropZone: some View {
        Button(action: { showPicker = true }) {
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                Text("PDF・画像を選択")
                    .font(.headline)
                Text("タップしてファイルを選ぶ")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    private var selectedFileRow: some View {
        HStack {
            Image(systemName: isPDF ? "doc.richtext" : "photo")
                .foregroundColor(.blue)
            Text(selectedName)
                .lineLimit(1)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
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
        .frame(height: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func sendToAPI() {
        guard let data = selectedData else { return }
        isProcessing = true
        Task {
            let response = isPDF
                ? await APIService.shared.sendPDF(data, fileName: selectedName)
                : await APIService.shared.sendImage(data, fileName: selectedName)
            await MainActor.run {
                apiResponse = response
                isProcessing = false
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedName: String
    @Binding var selectedData: Data?
    @Binding var isPDF: Bool
    @Environment(\.presentationMode) var presentation

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .image, .jpeg, .png, .heic]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            parent.selectedName = url.lastPathComponent
            parent.selectedData = try? Data(contentsOf: url)
            parent.isPDF = url.pathExtension.lowercased() == "pdf"
            parent.presentation.wrappedValue.dismiss()
        }
    }
}

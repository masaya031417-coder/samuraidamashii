// APIService.swift - バックエンドサーバーへのHTTP通信を担うサービス

import Foundation

class APIService: ObservableObject {
    // バックエンドURL（設定画面から変更可能。デフォルトはローカル開発用）
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:8000"
    }

    // MARK: - Public API

    /// テキスト（音声認識結果やメール文）からシフトを解析
    func parseText(_ text: String, name: String = "山本") async throws -> [Shift] {
        let request = try buildMultipartRequest(
            fields: ["text": text, "name": name]
        )
        return try await perform(request)
    }

    /// ファイル（PDF/画像）からシフトを解析
    func parseFile(_ data: Data, filename: String, name: String = "山本") async throws -> [Shift] {
        let request = try buildMultipartRequest(
            fields: ["name": name],
            fileData: data,
            filename: filename
        )
        return try await perform(request)
    }

    // MARK: - Private helpers

    private func perform(_ request: URLRequest) async throws -> [Shift] {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }
        return try JSONDecoder().decode(ParseResponse.self, from: data).shifts
    }

    /// multipart/form-data リクエストを組み立てる
    private func buildMultipartRequest(
        fields: [String: String],
        fileData: Data? = nil,
        filename: String? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: "\(APIService.baseURL)/parse") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120  // Claude API呼び出しのため余裕を持たせる

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = buildBody(fields: fields, fileData: fileData, filename: filename, boundary: boundary)
        return req
    }

    /// multipart/form-data ボディを組み立てる
    private func buildBody(
        fields: [String: String],
        fileData: Data?,
        filename: String?,
        boundary: String
    ) -> Data {
        var body = Data()
        let nl = "\r\n"

        // テキストフィールドを追加
        for (key, value) in fields {
            body += "--\(boundary)\(nl)".utf8Data
            body += "Content-Disposition: form-data; name=\"\(key)\"\(nl)\(nl)".utf8Data
            body += "\(value)\(nl)".utf8Data
        }

        // ファイルフィールドを追加（存在する場合）
        if let fileData, let filename {
            let mime = filename.hasSuffix(".pdf") ? "application/pdf" : "image/jpeg"
            body += "--\(boundary)\(nl)".utf8Data
            body += "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(nl)".utf8Data
            body += "Content-Type: \(mime)\(nl)\(nl)".utf8Data
            body += fileData
            body += nl.utf8Data
        }

        body += "--\(boundary)--\(nl)".utf8Data
        return body
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case serverError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:        return "サーバーURLが無効です。設定を確認してください"
            case .invalidResponse:   return "サーバーからの応答が不正です"
            case .serverError(let c): return "サーバーエラーが発生しました（ステータス: \(c)）"
            }
        }
    }
}

// MARK: - String to Data helper
private extension String {
    var utf8Data: Data { Data(utf8) }
}

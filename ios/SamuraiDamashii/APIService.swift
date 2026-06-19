import Foundation

actor APIService {
    static let shared = APIService()

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
    }

    private let endpoint = "https://api.anthropic.com/v1/messages"
    private let model    = "claude-sonnet-4-6"

    // MARK: - Public

    func sendText(_ text: String) async -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": "あなたはシフト管理を手伝うアシスタントです。日本語で簡潔に回答してください。",
            "messages": [["role": "user", "content": text]]
        ]
        return await request(body)
    }

    func sendImage(_ data: Data, fileName: String) async -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let mime: String
        switch ext {
        case "png":  mime = "image/png"
        case "gif":  mime = "image/gif"
        case "webp": mime = "image/webp"
        default:     mime = "image/jpeg"
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": [
                        "type": "base64",
                        "media_type": mime,
                        "data": data.base64EncodedString()
                    ]],
                    ["type": "text", "text": "この画像からシフトの予定を読み取って教えてください。"]
                ]
            ]]
        ]
        return await request(body)
    }

    func sendPDF(_ data: Data, fileName: String) async -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "document", "source": [
                        "type": "base64",
                        "media_type": "application/pdf",
                        "data": data.base64EncodedString()
                    ]],
                    ["type": "text", "text": "このPDFからシフトの予定を読み取って教えてください。"]
                ]
            ]]
        ]
        return await request(body)
    }

    // MARK: - Private

    private func request(_ body: [String: Any]) async -> String {
        guard !apiKey.isEmpty else {
            return "⚠️ APIキー未設定。\nUserDefaults の \"anthropic_api_key\" にキーをセットしてください。"
        }
        guard let url = URL(string: endpoint),
              let payload = try? JSONSerialization.data(withJSONObject: body) else {
            return "エラー: リクエスト生成に失敗しました"
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")
        req.httpBody = payload

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                return "HTTPエラー \(http.statusCode): \(body)"
            }
            if let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = (json["content"] as? [[String: Any]])?.first,
               let text    = content["text"] as? String {
                return text
            }
            return "エラー: レスポンス解析失敗"
        } catch {
            return "通信エラー: \(error.localizedDescription)"
        }
    }
}

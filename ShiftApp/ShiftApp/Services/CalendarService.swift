// CalendarService.swift - Google Calendar REST APIを使ってシフトを登録するサービス
// GoogleSignIn-iOS SDK を使用（SPM: https://github.com/google/GoogleSignIn-iOS）

import Foundation
import GoogleSignIn

@MainActor
class CalendarService: ObservableObject {
    @Published var isSignedIn: Bool = false

    private let calendarBase = "https://www.googleapis.com/calendar/v3"
    // Google Calendar への書き込みスコープ
    private let calendarScope = "https://www.googleapis.com/auth/calendar.events"
    private let timeZone = "Asia/Tokyo"

    // MARK: - Sign-in

    /// アプリ起動時に前回のサインイン状態を復元する
    func restoreSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            Task { @MainActor [weak self] in
                self?.isSignedIn = user != nil
            }
        }
    }

    /// Googleアカウントでサインインしてカレンダースコープを要求する
    func signIn(presenting viewController: UIViewController) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: [calendarScope]
            ) { [weak self] result, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    Task { @MainActor [weak self] in
                        self?.isSignedIn = true
                    }
                    cont.resume()
                }
            }
        }
    }

    // MARK: - Calendar operations

    /// シフト一覧をGoogleカレンダーのprimaryカレンダーに一括登録する
    /// 変則シフト（isIrregular == true）はスキップして警告をコンソールに出力する
    func pushShifts(_ shifts: [Shift]) async throws -> Int {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw CalendarError.notSignedIn
        }

        // アクセストークンを最新にリフレッシュ
        try await user.refreshTokensIfNeeded()
        guard let token = user.accessToken.tokenString else {
            throw CalendarError.tokenUnavailable
        }

        var count = 0
        for shift in shifts {
            // 変則シフトは登録不可のためスキップ
            if shift.isIrregular {
                print("⚠️ 変則シフトをスキップ: \(shift.date)")
                continue
            }
            do {
                try await createEvent(shift: shift, token: token)
                count += 1
            } catch {
                print("❌ \(shift.date) の登録失敗: \(error.localizedDescription)")
            }
        }
        return count
    }

    // MARK: - Private

    /// 時刻文字列を HH:MM 形式に正規化する
    /// "8:00" → "08:00", "18:00:00" → "18:00"
    private func normalizeTime(_ t: String) -> String {
        guard t != "変則" else { return t }
        let parts = t.split(separator: ":").map(String.init)
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return t }
        return String(format: "%02d:%02d", h, m)
    }

    /// 日付文字列を YYYY-MM-DD 形式に正規化する
    /// "2026/06/21" → "2026-06-21"
    private func normalizeDate(_ d: String) -> String {
        d.replacingOccurrences(of: "/", with: "-")
    }

    /// Google Calendar REST API でイベントを1件作成する
    private func createEvent(shift: Shift, token: String) async throws {
        guard let url = URL(string: "\(calendarBase)/calendars/primary/events") else {
            throw CalendarError.invalidURL
        }

        // タイトルは "シフト（備考）" 形式。備考なしなら "シフト"
        let title = shift.note.isEmpty ? "シフト" : "シフト（\(shift.note)）"

        // 日付・時刻を正規化してから ISO 8601 文字列を組み立てる
        let date  = normalizeDate(shift.date)
        let start = normalizeTime(shift.start)
        let end   = normalizeTime(shift.end)

        let body: [String: Any] = [
            "summary":  title,
            "location": shift.place,
            "start": ["dateTime": "\(date)T\(start):00", "timeZone": timeZone],
            "end":   ["dateTime": "\(date)T\(end):00",   "timeZone": timeZone],
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarError.requestFailed
        }
    }

    // MARK: - Errors

    enum CalendarError: LocalizedError {
        case notSignedIn
        case tokenUnavailable
        case invalidURL
        case requestFailed

        var errorDescription: String? {
            switch self {
            case .notSignedIn:      return "Googleアカウントにサインインしてください"
            case .tokenUnavailable: return "認証トークンを取得できませんでした"
            case .invalidURL:       return "Google Calendar APIのURLが無効です"
            case .requestFailed:    return "カレンダーへの登録リクエストが失敗しました"
            }
        }
    }
}

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

// MARK: - Service

class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()

    @Published var isSignedIn = false

    private let defaults = UserDefaults.standard

    var clientID: String {
        get { defaults.string(forKey: "google_client_id") ?? "" }
        set { defaults.set(newValue, forKey: "google_client_id") }
    }

    private var accessToken:  String? {
        get { defaults.string(forKey: "google_access_token") }
        set { defaults.set(newValue, forKey: "google_access_token") }
    }
    private var refreshToken: String? {
        get { defaults.string(forKey: "google_refresh_token") }
        set { defaults.set(newValue, forKey: "google_refresh_token") }
    }
    private var tokenExpiry: Date? {
        get { defaults.object(forKey: "google_token_expiry") as? Date }
        set { defaults.set(newValue, forKey: "google_token_expiry") }
    }

    private var codeVerifier = ""
    private let scheme = "com.samuraidamashii.app"
    private var redirectURI: String { "\(scheme):/oauth2callback" }

    override init() {
        super.init()
        isSignedIn = refreshToken != nil
    }

    // MARK: - Sign In (PKCE)

    @MainActor
    func signIn() async throws {
        guard !clientID.isEmpty else { throw GCalError.invalidConfig }

        codeVerifier = makeVerifier()
        let challenge = makeChallenge(codeVerifier)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id",             value: clientID),
            .init(name: "redirect_uri",          value: redirectURI),
            .init(name: "response_type",         value: "code"),
            .init(name: "scope",                 value: "https://www.googleapis.com/auth/calendar"),
            .init(name: "access_type",           value: "offline"),
            .init(name: "prompt",                value: "consent"),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = comps.url else { throw GCalError.invalidConfig }

        let callbackURL = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { url, error in
                if let error { cont.resume(throwing: error); return }
                guard let url else { cont.resume(throwing: GCalError.authFailed); return }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = AuthAnchor.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        guard let comps2 = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = comps2.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw GCalError.authFailed }

        try await exchangeCode(code)
        isSignedIn = true
    }

    func signOut() {
        accessToken = nil; refreshToken = nil; tokenExpiry = nil
        DispatchQueue.main.async { self.isSignedIn = false }
    }

    // MARK: - Token

    private func exchangeCode(_ code: String) async throws {
        let body = "code=\(code)&client_id=\(clientID)" +
                   "&redirect_uri=\(redirectURI.percentEncoded)" +
                   "&grant_type=authorization_code" +
                   "&code_verifier=\(codeVerifier)"
        try await postToken(body)
    }

    private func refreshAccessToken() async throws {
        guard let rt = refreshToken else { throw GCalError.notSignedIn }
        let body = "refresh_token=\(rt)&client_id=\(clientID)&grant_type=refresh_token"
        try await postToken(body)
    }

    private func postToken(_ body: String) async throws {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String
        else { throw GCalError.tokenFailed }

        accessToken = token
        if let rt = json["refresh_token"] as? String { refreshToken = rt }
        if let exp = json["expires_in"] as? Int {
            tokenExpiry = Date().addingTimeInterval(TimeInterval(exp) - 60)
        }
    }

    private func validToken() async throws -> String {
        if let expiry = tokenExpiry, expiry < Date() { try await refreshAccessToken() }
        guard let token = accessToken else { throw GCalError.notSignedIn }
        return token
    }

    // MARK: - Calendar API

    func createShiftEvent(date: Date, location: String, startTime: Date, endTime: Date) async throws {
        let token = try await validToken()
        let tz    = TimeZone.current.identifier

        var body: [String: Any] = [
            "summary": "シフト",
            "start": ["dateTime": isoString(combine(date, startTime)), "timeZone": tz],
            "end":   ["dateTime": isoString(combine(date, endTime)),   "timeZone": tz]
        ]
        if !location.isEmpty { body["location"] = location }

        var req = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GCalError.apiError
        }
    }

    func fetchShiftEvents() async throws -> [GCalEvent] {
        let token = try await validToken()
        let now   = Date()
        let start = Calendar.current.date(byAdding: .month, value: -3, to: now)!
        let end   = Calendar.current.date(byAdding: .month, value: 6,  to: now)!

        var comps = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        comps.queryItems = [
            .init(name: "q",            value: "シフト"),
            .init(name: "timeMin",      value: isoString(start)),
            .init(name: "timeMax",      value: isoString(end)),
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy",      value: "startTime"),
            .init(name: "maxResults",   value: "250")
        ]

        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]]
        else { throw GCalError.apiError }

        return items.compactMap(GCalEvent.init)
    }

    func deleteEvent(id: String) async throws {
        let token = try await validToken()
        let url   = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(id)")!
        var req   = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 204 else {
            throw GCalError.apiError
        }
    }

    // MARK: - PKCE helpers

    private func makeVerifier() -> String {
        var buf = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, buf.count, &buf)
        return Data(buf).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeChallenge(_ verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func combine(_ date: Date, _ time: Date) -> Date {
        let cal = Calendar.current
        var d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        d.hour = t.hour; d.minute = t.minute
        return cal.date(from: d) ?? date
    }

    private func isoString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}

// MARK: - Presentation anchor

private class AuthAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthAnchor()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}

// MARK: - Model

struct GCalEvent: Identifiable {
    let id: String
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date

    init?(_ json: [String: Any]) {
        guard let id    = json["id"] as? String,
              let title = json["summary"] as? String,
              let sStr  = (json["start"] as? [String: Any])?["dateTime"] as? String,
              let eStr  = (json["end"]   as? [String: Any])?["dateTime"] as? String
        else { return nil }

        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        guard let s = f.date(from: sStr), let e = f.date(from: eStr) else { return nil }

        self.id = id; self.title = title
        self.location = json["location"] as? String
        self.startDate = s; self.endDate = e
    }
}

// MARK: - Errors

enum GCalError: LocalizedError {
    case invalidConfig, authFailed, tokenFailed, notSignedIn, apiError
    var errorDescription: String? {
        switch self {
        case .invalidConfig: return "Google Client IDを設定してください\n(UserDefaults: google_client_id)"
        case .authFailed:    return "Googleサインインに失敗しました"
        case .tokenFailed:   return "アクセストークンの取得に失敗しました"
        case .notSignedIn:   return "Googleアカウントにサインインしてください"
        case .apiError:      return "Google Calendar APIエラー"
        }
    }
}

// MARK: - String helper

private extension String {
    var percentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

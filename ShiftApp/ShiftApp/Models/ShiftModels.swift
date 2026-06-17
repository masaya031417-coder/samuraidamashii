// ShiftModels.swift - データモデル定義

import Foundation

/// シフト1件を表すデータモデル
struct Shift: Identifiable, Codable, Equatable {
    // Identifiable 準拠のため UUID を付与（サーバー返却値には含まれないのでローカル生成）
    var id: UUID = UUID()
    var date: String   // "2026-06-21"
    var start: String  // "18:00" または "変則"
    var end: String    // "23:00" または "変則"
    var place: String  // "GLION ARENA KOBE"
    var note: String   // 備考・シフト記号など

    /// 変則シフト（G記号）かどうかを判定
    var isIrregular: Bool {
        start == "変則" || end == "変則"
    }

    // サーバーが返すJSONキーとマッピング（id はサーバー側にないので除外）
    enum CodingKeys: String, CodingKey {
        case date, start, end, place, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date  = try c.decode(String.self, forKey: .date)
        start = try c.decode(String.self, forKey: .start)
        end   = try c.decode(String.self, forKey: .end)
        place = (try? c.decode(String.self, forKey: .place)) ?? ""
        note  = (try? c.decode(String.self, forKey: .note))  ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date,  forKey: .date)
        try c.encode(start, forKey: .start)
        try c.encode(end,   forKey: .end)
        try c.encode(place, forKey: .place)
        try c.encode(note,  forKey: .note)
    }
}

/// /parse エンドポイントのレスポンス型
struct ParseResponse: Decodable {
    let shifts: [Shift]
}

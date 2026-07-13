import Foundation

nonisolated struct RateLimitsResponse: Decodable, Sendable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: ResetCreditsSummary?

    var codexLimits: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
    }
}

nonisolated struct RateLimitSnapshot: Decodable, Sendable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let planType: String?

    var fiveHourWindow: RateLimitWindow? {
        if let window = windows.first(where: { $0.matchesDuration(minutes: 5 * 60) }) {
            return window
        }

        // Older Codex versions may omit the duration. In that legacy payload,
        // primary and secondary retain their original 5-hour/weekly meanings.
        return primary?.windowDurationMins == nil ? primary : nil
    }

    var weeklyWindow: RateLimitWindow? {
        if let window = windows.first(where: { $0.matchesDuration(minutes: 7 * 24 * 60) }) {
            return window
        }

        // Keep the positional fallback only when there is no duration to classify.
        return secondary?.windowDurationMins == nil ? secondary : nil
    }

    private var windows: [RateLimitWindow] {
        [primary, secondary].compactMap { $0 }
    }
}

nonisolated struct RateLimitWindow: Decodable, Sendable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }

    var resetDate: Date? {
        resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    func matchesDuration(minutes expectedMinutes: Int) -> Bool {
        guard let windowDurationMins else { return false }
        let tolerance = Double(expectedMinutes) * 0.05
        return abs(Double(windowDurationMins - expectedMinutes)) <= tolerance
    }
}

nonisolated struct ResetCreditsSummary: Decodable, Sendable {
    let availableCount: Int
    let credits: [ResetCredit]?

    var sortedCredits: [ResetCredit] {
        (credits ?? []).sorted {
            ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture)
        }
    }

    var nearestExpiry: Date? {
        sortedCredits.compactMap(\.expiryDate).first
    }
}

nonisolated struct ResetCredit: Decodable, Identifiable, Sendable {
    let id: String
    let resetType: String
    let status: String
    let grantedAt: Int
    let expiresAt: Int?
    let title: String?
    let description: String?

    var expiryDate: Date? {
        expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}

nonisolated struct RPCResponse<Result: Decodable>: Decodable {
    let id: Int?
    let result: Result?
    let error: RPCErrorPayload?
}

nonisolated struct RPCErrorPayload: Decodable {
    let code: Int?
    let message: String
}

nonisolated struct EmptyRPCResult: Decodable {}

enum QuotaFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

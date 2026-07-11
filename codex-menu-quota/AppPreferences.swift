import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppPreferences {
    private enum Key {
        static let showFiveHour = "menu.showFiveHour"
        static let showWeekly = "menu.showWeekly"
        static let showResetCount = "menu.showResetCount"
        static let showResetExpiry = "menu.showResetExpiry"
        static let refreshInterval = "refreshInterval"
    }

    private let defaults = UserDefaults.standard

    var showFiveHour: Bool { didSet { defaults.set(showFiveHour, forKey: Key.showFiveHour) } }
    var showWeekly: Bool { didSet { defaults.set(showWeekly, forKey: Key.showWeekly) } }
    var showResetCount: Bool { didSet { defaults.set(showResetCount, forKey: Key.showResetCount) } }
    var showResetExpiry: Bool { didSet { defaults.set(showResetExpiry, forKey: Key.showResetExpiry) } }
    var refreshInterval: Double { didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval) } }
    var launchAtLogin: Bool
    var launchAtLoginError: String?

    init() {
        defaults.register(defaults: [
            Key.showFiveHour: true,
            Key.showWeekly: true,
            Key.showResetCount: true,
            Key.showResetExpiry: false,
            Key.refreshInterval: 60.0,
        ])

        showFiveHour = defaults.bool(forKey: Key.showFiveHour)
        showWeekly = defaults.bool(forKey: Key.showWeekly)
        showResetCount = defaults.bool(forKey: Key.showResetCount)
        showResetExpiry = defaults.bool(forKey: Key.showResetExpiry)
        refreshInterval = defaults.double(forKey: Key.refreshInterval)

        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func menuBarText(for response: RateLimitsResponse?) -> String {
        guard let response else { return "Codex …" }
        var parts: [String] = []
        let limits = response.codexLimits

        if showFiveHour, let primary = limits.primary {
            parts.append("5h \(primary.remainingPercent)%")
        }
        if showWeekly, let secondary = limits.secondary {
            parts.append("周 \(secondary.remainingPercent)%")
        }
        if showResetCount, let resets = response.rateLimitResetCredits {
            parts.append("重置 \(resets.availableCount)")
        }
        if showResetExpiry, let expiry = response.rateLimitResetCredits?.nearestExpiry {
            parts.append("最近 \(QuotaFormatters.date.string(from: expiry))")
        }
        return parts.joined(separator: " | ")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = error.localizedDescription
        }
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class QuotaStore {
    var response: RateLimitsResponse?
    var isRefreshing = false
    var lastUpdated: Date?
    var errorMessage: String?

    private let client = CodexAppServerClient()
    private let preferences: AppPreferences
    private var refreshLoop: Task<Void, Never>?

    init(preferences: AppPreferences) {
        self.preferences = preferences
    }

    func start() {
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                let interval = max(15, preferences.refreshInterval)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            response = try await client.fetchRateLimits()
            lastUpdated = .now
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func executablePath() async -> String? {
        await client.executablePath()
    }
}

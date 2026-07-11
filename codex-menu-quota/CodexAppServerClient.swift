import Foundation

enum CodexClientError: LocalizedError {
    case executableNotFound
    case sandboxEnabled
    case launchFailed(String)
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "未找到 Codex。请安装并登录 Codex 桌面应用。"
        case .sandboxEnabled:
            return "当前构建仍启用了 App Sandbox，无法调用 Codex。请在 Xcode 中执行 Product > Clean Build Folder 后重新运行。"
        case .launchFailed(let message):
            return "无法启动 Codex 数据服务：\(message)"
        case .invalidResponse:
            return "Codex 返回了无法识别的数据。"
        case .server(let message):
            return message
        }
    }
}

actor CodexAppServerClient {
    private let decoder = JSONDecoder()

    func fetchRateLimits() async throws -> RateLimitsResponse {
        let data = try await performRequest(method: "account/rateLimits/read", params: NSNull())
        let envelope = try decoder.decode(RPCResponse<RateLimitsResponse>.self, from: data)
        if let error = envelope.error { throw CodexClientError.server(error.message) }
        guard let result = envelope.result else { throw CodexClientError.invalidResponse }
        return result
    }

    func executablePath() -> String? {
        Self.resolveExecutablePath()
    }

    private func performRequest(method: String, params: Any) async throws -> Data {
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            throw CodexClientError.sandboxEnabled
        }
        guard let executable = Self.resolveExecutablePath() else {
            throw CodexClientError.executableNotFound
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw CodexClientError.launchFailed(error.localizedDescription)
        }
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }

        let initialize: [String: Any] = [
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "codex-menu-quota",
                    "title": "Codex Menu Quota",
                    "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                ],
            ],
        ]
        let initialized: [String: Any] = ["method": "initialized", "params": [:]]
        let request: [String: Any] = ["id": 2, "method": method, "params": params]

        let payload = try [initialize, initialized, request]
            .map { try JSONSerialization.data(withJSONObject: $0) }
            .reduce(into: Data()) { result, line in
                result.append(line)
                result.append(0x0A)
            }
        input.fileHandleForWriting.write(payload)

        for try await line in output.fileHandleForReading.bytes.lines {
            let data = Data(line.utf8)
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = object["id"] as? Int,
                  id == 2 else { continue }
            return data
        }

        let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CodexClientError.server(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        throw CodexClientError.invalidResponse
    }

    private static func resolveExecutablePath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/.codex/plugins/.plugin-appserver/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

}

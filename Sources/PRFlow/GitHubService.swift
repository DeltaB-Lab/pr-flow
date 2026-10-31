import Foundation

enum AppLog {
    static let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("PRFlow.log")
    }()

    static func write(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path),
           let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL)
        }
    }
}

private final class LockedBuffer: @unchecked Sendable {
    private var storage = Data()
    private let lock = NSLock()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ chunk: Data) {
        lock.lock()
        storage.append(chunk)
        lock.unlock()
    }
}

final class GitHubService: Sendable {
    static let shared = GitHubService()

    enum GHError: LocalizedError {
        case ghNotFound
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .ghNotFound:
                return "gh CLI not found. Install it with `brew install gh` and run `gh auth login`."
            case .commandFailed(let message):
                return message.isEmpty ? "gh command failed" : message
            }
        }
    }

    private let ghPath: String

    private init() {
        let candidates = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
            NSHomeDirectory() + "/.local/bin/gh",
        ]
        ghPath = candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
    }

    // MARK: - Public API

    func currentUser() async throws -> String {
        let data = try await run(["api", "user", "--jq", ".login"])
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchMyPRs() async throws -> [PullRequest] {
        let data = try await run([
            "search", "prs",
            "--author=@me",
            "--state", "open",
            "--limit", "100",
            "--json", "number,title,url,repository,updatedAt,isDraft,state",
        ])
        let searchResults = try JSONDecoder().decode([SearchPR].self, from: data)
        let grouped = Dictionary(grouping: searchResults) { $0.repository.nameWithOwner }

        return await withTaskGroup(of: [PullRequest].self) { group in
            for (repo, items) in grouped {
                group.addTask {
                    await self.pullRequests(for: repo, searchItems: items)
                }
            }
            var all: [PullRequest] = []
            for await prs in group { all.append(contentsOf: prs) }
            return all
        }
    }

    func accounts() async throws -> [GHAccount] {
        let data = try await run(["auth", "status", "--json", "hosts"])
        let status = try JSONDecoder().decode(GHAuthStatus.self, from: data)
        return status.hosts.values
            .flatMap { $0 }
            .filter { $0.state == "success" }
            .sorted { $0.active && !$1.active }
    }

    func switchAccount(login: String, host: String) async throws {
        _ = try await run(["auth", "switch", "--user", login, "--hostname", host])
    }

    func openLoginTerminal() {
        let script = "tell application \"Terminal\" to activate\n" +
            "tell application \"Terminal\" to do script \"\(ghPath) auth login\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    func merge(_ pr: PullRequest, method: MergeMethod, auto: Bool = false) async throws {
        var args = ["pr", "merge", pr.url.absoluteString, method.flag]
        if auto { args.append("--auto") }
        _ = try await run(args)
    }

    func fetchMyIssues() async throws -> [IssueItem] {
        let data = try await run([
            "search", "issues",
            "--assignee=@me",
            "--state", "open",
            "--limit", "100",
            "--json", "number,title,url,repository,updatedAt,state,labels",
        ])
        return try JSONDecoder().decode([SearchIssue].self, from: data).map(IssueItem.init)
    }

    func closeIssue(_ issue: IssueItem) async throws {
        _ = try await run(["issue", "close", issue.url.absoluteString])
    }

    func close(_ pr: PullRequest) async throws {
        _ = try await run(["pr", "close", pr.url.absoluteString])
    }

    // MARK: - Internals

    private func pullRequests(for repo: String, searchItems: [SearchPR]) async -> [PullRequest] {
        let data = try? await run([
            "pr", "list",
            "--repo", repo,
            "--author", "@me",
            "--state", "open",
            "--limit", "50",
            "--json", "number,reviewDecision,mergeable,mergeStateStatus,isDraft,statusCheckRollup",
        ])
        let details = data.flatMap { try? JSONDecoder().decode([RepoPRDetail].self, from: $0) } ?? []
        let byNumber = Dictionary(details.map { ($0.number, $0) }) { first, _ in first }
        return searchItems.map { PullRequest(search: $0, detail: byNumber[$0.number]) }
    }

    private func run(_ args: [String]) async throws -> Data {
        guard !ghPath.isEmpty else {
            AppLog.write("gh binary not found")
            throw GHError.ghNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: ghPath)
            process.arguments = args
            process.standardOutput = stdout
            process.standardError = stderr

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            env["NO_COLOR"] = "1"
            process.environment = env

            let outBuffer = LockedBuffer()
            let errBuffer = LockedBuffer()

            stdout.fileHandleForReading.readabilityHandler = { handle in
                outBuffer.append(handle.availableData)
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                errBuffer.append(handle.availableData)
            }

            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                outBuffer.append(stdout.fileHandleForReading.readDataToEndOfFile())
                errBuffer.append(stderr.fileHandleForReading.readDataToEndOfFile())

                if proc.terminationStatus == 0 {
                    AppLog.write("ok: gh \(args.joined(separator: " ")) -> \(outBuffer.data.count) bytes")
                    continuation.resume(returning: outBuffer.data)
                } else {
                    let message = String(decoding: errBuffer.data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    AppLog.write("fail(\(proc.terminationStatus)): gh \(args.joined(separator: " ")) -> \(message)")
                    continuation.resume(throwing: GHError.commandFailed(message))
                }
            }

            do {
                try process.run()
            } catch {
                AppLog.write("spawn failed: gh \(args.joined(separator: " ")) -> \(error)")
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

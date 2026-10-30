import Foundation

// MARK: - gh CLI JSON shapes

struct SearchPR: Decodable {
    struct Repo: Decodable {
        let name: String
        let nameWithOwner: String
    }

    let number: Int
    let title: String
    let url: String
    let updatedAt: String
    let isDraft: Bool
    let state: String
    let repository: Repo
}

struct RepoPRDetail: Decodable {
    struct Check: Decodable {
        let __typename: String?
        // CheckRun fields
        let status: String?      // QUEUED / IN_PROGRESS / COMPLETED
        let conclusion: String?  // SUCCESS / FAILURE / NEUTRAL / SKIPPED / TIMED_OUT / CANCELLED
        let name: String?
        // StatusContext fields
        let state: String?       // SUCCESS / FAILURE / PENDING / EXPECTED / ERROR
        let context: String?
    }

    let number: Int
    let reviewDecision: String?   // APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / ""
    let mergeable: String?        // MERGEABLE / CONFLICTING / UNKNOWN
    let mergeStateStatus: String? // CLEAN / DIRTY / BLOCKED / BEHIND / UNSTABLE / UNKNOWN ...
    let isDraft: Bool?
    let statusCheckRollup: [Check]?
}

// MARK: - App models

struct PullRequest: Identifiable, Hashable {
    enum CheckStatus: String {
        case none, passing, failing, pending
    }

    enum ReviewStatus: String {
        case none, approved, changesRequested, reviewRequired
    }

    let number: Int
    let title: String
    let url: URL
    let repoName: String
    let repoFullName: String
    let updatedAt: Date
    let isDraft: Bool
    var reviewStatus: ReviewStatus
    var checkStatus: CheckStatus
    var mergeable: String
    var mergeStateStatus: String

    var id: String { "\(repoFullName)#\(number)" }
    var canMerge: Bool { !isDraft && mergeable != "CONFLICTING" }

    init(search: SearchPR, detail: RepoPRDetail?) {
        number = search.number
        title = search.title
        url = URL(string: search.url)!
        repoName = search.repository.name
        repoFullName = search.repository.nameWithOwner
        updatedAt = PullRequest.parseDate(search.updatedAt)
        isDraft = detail?.isDraft ?? search.isDraft
        reviewStatus = PullRequest.reviewStatus(from: detail?.reviewDecision)
        checkStatus = PullRequest.aggregateChecks(detail?.statusCheckRollup ?? [])
        mergeable = detail?.mergeable ?? "UNKNOWN"
        mergeStateStatus = detail?.mergeStateStatus ?? "UNKNOWN"
    }

    private static func parseDate(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string) ?? .distantPast
    }

    private static func reviewStatus(from decision: String?) -> ReviewStatus {
        switch decision {
        case "APPROVED": return .approved
        case "CHANGES_REQUESTED": return .changesRequested
        case "REVIEW_REQUIRED": return .reviewRequired
        default: return .none
        }
    }

    private static func aggregateChecks(_ checks: [RepoPRDetail.Check]) -> CheckStatus {
        guard !checks.isEmpty else { return .none }
        var hasPending = false
        for check in checks {
            if let state = check.state {
                switch state {
                case "SUCCESS": continue
                case "PENDING", "EXPECTED": hasPending = true
                default: return .failing
                }
            } else {
                if check.status != "COMPLETED" {
                    hasPending = true
                    continue
                }
                switch check.conclusion {
                case "SUCCESS", "NEUTRAL", "SKIPPED": continue
                default: return .failing
                }
            }
        }
        return hasPending ? .pending : .passing
    }
}

struct RepoGroup: Identifiable {
    let name: String
    let nameWithOwner: String
    let prs: [PullRequest]

    var id: String { nameWithOwner }
    var latestUpdate: Date { prs.map(\.updatedAt).max() ?? .distantPast }
}

// MARK: - gh auth accounts

struct GHAuthStatus: Decodable {
    let hosts: [String: [GHAccount]]
}

struct GHAccount: Decodable, Identifiable, Hashable {
    let state: String
    let active: Bool
    let host: String
    let login: String
    let tokenSource: String?
    let scopes: String?
    let gitProtocol: String?

    var id: String { "\(host)/\(login)" }
}

enum MergeMethod {
    case squash, merge, rebase

    var flag: String {
        switch self {
        case .squash: return "--squash"
        case .merge: return "--merge"
        case .rebase: return "--rebase"
        }
    }
}

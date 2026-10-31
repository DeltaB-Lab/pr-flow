import Foundation

@MainActor
final class PRStore: ObservableObject {
    @Published private(set) var prs: [PullRequest] = []
    @Published private(set) var repos: [RepoGroup] = []
    @Published private(set) var issues: [IssueItem] = []
    @Published private(set) var issueRepos: [IssueGroup] = []
    @Published var mode: ViewMode = .prs
    @Published var selectedIssueRepo: String?
    @Published private(set) var loading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var username = ""
    @Published var selectedRepo: String?
    @Published var errorMessage: String?
    @Published private(set) var busyPRs: Set<String> = []
    @Published private(set) var accounts: [GHAccount] = []
    @Published private(set) var switchingAccount = false

    private let github = GitHubService.shared
    private var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?

    var totalCount: Int { mode == .prs ? prs.count : issues.count }
    var selectedGroup: RepoGroup? { repos.first { $0.nameWithOwner == selectedRepo } }
    var selectedIssueGroup: IssueGroup? { issueRepos.first { $0.nameWithOwner == selectedIssueRepo } }

    func selectTab(_ id: String) {
        if mode == .prs {
            selectedRepo = id
        } else {
            selectedIssueRepo = id
        }
    }

    func start() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        loadAccounts()
    }

    func loadAccounts() {
        Task {
            do {
                accounts = try await github.accounts()
                username = accounts.first(where: \.active)?.login ?? ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func switchAccount(to account: GHAccount) {
        guard !account.active, !switchingAccount else { return }
        Task {
            switchingAccount = true
            defer { switchingAccount = false }
            do {
                try await github.switchAccount(login: account.login, host: account.host)
                loadAccounts()
                await performRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func openLoginTerminal() {
        github.openLoginTerminal()
    }

    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { await performRefresh() }
    }

    func merge(_ pr: PullRequest, method: MergeMethod, auto: Bool = false) {
        runAction(id: pr.id) { try await self.github.merge(pr, method: method, auto: auto) }
    }

    func close(_ pr: PullRequest) {
        runAction(id: pr.id) { try await self.github.close(pr) }
    }

    func close(_ issue: IssueItem) {
        runAction(id: issue.id) { try await self.github.closeIssue(issue) }
    }

    // MARK: - Private

    private func performRefresh() async {
        loading = true
        defer {
            loading = false
            refreshTask = nil
        }
        do {
            async let prFetch = github.fetchMyPRs()
            async let issueFetch = github.fetchMyIssues()
            let (fetchedPRs, fetchedIssues) = try await (prFetch, issueFetch)

            prs = fetchedPRs.sorted { $0.updatedAt > $1.updatedAt }
            repos = Dictionary(grouping: fetchedPRs) { $0.repoFullName }
                .map { key, value in
                    RepoGroup(
                        name: value.first?.repoName ?? key,
                        nameWithOwner: key,
                        prs: value.sorted { $0.updatedAt > $1.updatedAt }
                    )
                }
                .sorted { $0.latestUpdate > $1.latestUpdate }
            if selectedRepo == nil || !repos.contains(where: { $0.nameWithOwner == selectedRepo }) {
                selectedRepo = repos.first?.nameWithOwner
            }

            issues = fetchedIssues.sorted { $0.updatedAt > $1.updatedAt }
            issueRepos = Dictionary(grouping: fetchedIssues) { $0.repoFullName }
                .map { key, value in
                    IssueGroup(
                        name: value.first?.repoName ?? key,
                        nameWithOwner: key,
                        issues: value.sorted { $0.updatedAt > $1.updatedAt }
                    )
                }
                .sorted { $0.latestUpdate > $1.latestUpdate }
            if selectedIssueRepo == nil || !issueRepos.contains(where: { $0.nameWithOwner == selectedIssueRepo }) {
                selectedIssueRepo = issueRepos.first?.nameWithOwner
            }

            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAction(id: String, _ action: @escaping () async throws -> Void) {
        Task {
            busyPRs.insert(id)
            defer { busyPRs.remove(id) }
            do {
                try await action()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await performRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

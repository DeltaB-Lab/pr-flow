import Foundation

@MainActor
final class PRStore: ObservableObject {
    @Published private(set) var prs: [PullRequest] = []
    @Published private(set) var repos: [RepoGroup] = []
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

    var totalCount: Int { prs.count }
    var selectedGroup: RepoGroup? { repos.first { $0.nameWithOwner == selectedRepo } }

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
        runAction(for: pr) { try await self.github.merge(pr, method: method, auto: auto) }
    }

    func close(_ pr: PullRequest) {
        runAction(for: pr) { try await self.github.close(pr) }
    }

    // MARK: - Private

    private func performRefresh() async {
        loading = true
        defer {
            loading = false
            refreshTask = nil
        }
        do {
            let fetched = try await github.fetchMyPRs()
            prs = fetched.sorted { $0.updatedAt > $1.updatedAt }
            repos = Dictionary(grouping: fetched) { $0.repoFullName }
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
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAction(for pr: PullRequest, _ action: @escaping () async throws -> Void) {
        Task {
            busyPRs.insert(pr.id)
            defer { busyPRs.remove(pr.id) }
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

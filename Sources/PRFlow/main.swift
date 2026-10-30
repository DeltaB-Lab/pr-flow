import AppKit

if CommandLine.arguments.contains("--dump") {
    Task {
        do {
            let prs = try await GitHubService.shared.fetchMyPRs()
            print("fetched \(prs.count) PRs")
            for pr in prs {
                print("\(pr.repoFullName)#\(pr.number) draft=\(pr.isDraft) review=\(pr.reviewStatus.rawValue) checks=\(pr.checkStatus.rawValue) merge=\(pr.mergeable)/\(pr.mergeStateStatus) \(pr.title)")
            }
        } catch {
            print("error: \(error.localizedDescription)")
        }
        exit(0)
    }
    dispatchMain()
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

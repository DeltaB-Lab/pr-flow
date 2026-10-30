import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var store: PRStore

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.errorMessage != nil {
                errorBanner
            }
            if !store.repos.isEmpty {
                tabBar
                Divider().opacity(0.4)
            }
            content
            Divider().opacity(0.4)
            footer
        }
        .frame(width: 400, height: 540)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("PRFlow")
                .font(.system(size: 14, weight: .semibold))
            if !store.username.isEmpty {
                accountMenu
            }
            Spacer()
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .disabled(store.loading)
            .opacity(store.loading ? 0.4 : 1)
            .help("Refresh")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Quit PRFlow")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var accountMenu: some View {
        Menu {
            ForEach(store.accounts) { account in
                Button {
                    store.switchAccount(to: account)
                } label: {
                    HStack {
                        Text("@\(account.login)")
                        if account.active {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(account.active || store.switchingAccount)
            }
            Divider()
            Button {
                store.openLoginTerminal()
            } label: {
                Label("Add account…", systemImage: "plus")
            }
            Button {
                store.loadAccounts()
            } label: {
                Label("Reload accounts", systemImage: "arrow.clockwise")
            }
        } label: {
            HStack(spacing: 3) {
                if store.switchingAccount {
                    ProgressView().scaleEffect(0.45).frame(width: 10, height: 10)
                }
                Text("@\(store.username)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Switch GitHub account")
    }

    private var errorBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(store.errorMessage ?? "")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button {
                store.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(IconButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.12))
    }

    // MARK: - Tabs

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.repos) { repo in
                    TabButton(
                        title: repo.name,
                        count: repo.prs.count,
                        isSelected: store.selectedRepo == repo.nameWithOwner
                    ) {
                        store.selectedRepo = repo.nameWithOwner
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.prs.isEmpty && store.loading {
            Spacer()
            ProgressView().scaleEffect(0.9)
            Spacer()
        } else if store.prs.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                if let glyph = NSImage(named: "glyph-glass") {
                    Image(nsImage: glyph)
                        .resizable()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }
                Text(store.errorMessage == nil ? "No open pull requests" : "Couldn't load PRs")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button("Retry") { store.refresh() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
            }
            Spacer()
        } else if let group = store.selectedGroup {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(group.prs) { pr in
                        PRRowView(pr: pr, store: store)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(store.totalCount) open PR\(store.totalCount == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            if let updated = store.lastUpdated {
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            if store.loading {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Tab button

private struct TabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(isSelected ? .white.opacity(0.28) : .white.opacity(0.12))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(.white.opacity(isSelected ? 0.20 : 0.07))
            )
            .overlay(
                Capsule().strokeBorder(.white.opacity(isSelected ? 0.28 : 0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

// MARK: - Shared styles

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .primary : .secondary)
            .padding(4)
            .background(
                Circle().fill(.white.opacity(configuration.isPressed ? 0.18 : 0))
            )
            .contentShape(Circle())
    }
}

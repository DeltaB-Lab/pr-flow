import AppKit
import SwiftUI

struct PRRowView: View {
    let pr: PullRequest
    @ObservedObject var store: PRStore
    @State private var confirmClose = false
    @State private var isHovering = false

    private var busy: Bool { store.busyPRs.contains(pr.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 6) {
                Text("#\(pr.number)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
                Text(pr.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button {
                    NSWorkspace.shared.open(pr.url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(IconButtonStyle())
                .opacity(isHovering ? 1 : 0.35)
                .help("Open in browser")
            }

            badges

            HStack(spacing: 8) {
                if busy {
                    ProgressView().scaleEffect(0.55).frame(width: 14, height: 14)
                    Text("Working...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    mergeMenu
                    closeButton
                    Spacer()
                    Text(pr.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(isHovering ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .onHover { isHovering = $0 }
        .confirmationDialog("Close #\(pr.number)?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Close PR", role: .destructive) { store.close(pr) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(pr.title)
        }
    }

    // MARK: - Badges

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: 5) {
            if pr.isDraft {
                Badge(text: "Draft", icon: "pencil", color: .secondary)
            }
            switch pr.reviewStatus {
            case .approved:
                Badge(text: "Approved", icon: "checkmark.seal.fill", color: .green)
            case .changesRequested:
                Badge(text: "Changes", icon: "arrow.uturn.left", color: .orange)
            case .reviewRequired:
                Badge(text: "Review", icon: "eye", color: .secondary)
            case .none:
                EmptyView()
            }
            switch pr.checkStatus {
            case .passing:
                Badge(text: "Checks", icon: "checkmark.circle.fill", color: .green)
            case .failing:
                Badge(text: "Checks failing", icon: "xmark.circle.fill", color: .red)
            case .pending:
                Badge(text: "Running", icon: "clock.fill", color: .yellow)
            case .none:
                EmptyView()
            }
            switch pr.mergeStateStatus {
            case "DIRTY":
                Badge(text: "Conflicts", icon: "exclamationmark.arrow.triangle.2.circlepath", color: .red)
            case "BEHIND":
                Badge(text: "Behind", icon: "arrow.triangle.branch", color: .orange)
            case "BLOCKED":
                Badge(text: "Blocked", icon: "hand.raised.fill", color: .orange)
            default:
                EmptyView()
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private var mergeMenu: some View {
        Menu {
            Button("Squash & merge") { store.merge(pr, method: .squash) }
            Button("Merge commit") { store.merge(pr, method: .merge) }
            Button("Rebase & merge") { store.merge(pr, method: .rebase) }
            Divider()
            Button("Auto-merge (squash)") { store.merge(pr, method: .squash, auto: true) }
            Button("Auto-merge (merge)") { store.merge(pr, method: .merge, auto: true) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.merge")
                Text(pr.canMerge ? "Merge" : "Conflicts")
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(pr.canMerge ? .green.opacity(0.25) : .gray.opacity(0.15))
            )
            .overlay(
                Capsule().strokeBorder(pr.canMerge ? .green.opacity(0.4) : .gray.opacity(0.2), lineWidth: 0.5)
            )
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(!pr.canMerge)
        .help(pr.canMerge ? "Merge pull request" : "PR has conflicts or is a draft")
    }

    private var closeButton: some View {
        Button {
            confirmClose = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                Text("Close")
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(.red.opacity(0.15)))
            .overlay(Capsule().strokeBorder(.red.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help("Close pull request")
    }
}

private struct Badge: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.14)))
    }
}

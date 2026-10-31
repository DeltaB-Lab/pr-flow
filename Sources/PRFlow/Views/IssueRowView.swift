import AppKit
import SwiftUI

struct IssueRowView: View {
    let issue: IssueItem
    @ObservedObject var store: PRStore
    @State private var confirmClose = false
    @State private var isHovering = false

    private var busy: Bool { store.busyPRs.contains(issue.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 6) {
                Text("#\(issue.number)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
                Text(issue.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button {
                    NSWorkspace.shared.open(issue.url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(IconButtonStyle())
                .opacity(isHovering ? 1 : 0.35)
                .help("Open in browser")
            }

            if !issue.labels.isEmpty {
                HStack(spacing: 5) {
                    ForEach(issue.labels.prefix(3), id: \.name) { label in
                        LabelBadge(label: label)
                    }
                    if issue.labels.count > 3 {
                        Text("+\(issue.labels.count - 3)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                if busy {
                    ProgressView().scaleEffect(0.55).frame(width: 14, height: 14)
                    Text("Working...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    closeButton
                    Spacer()
                    Text(issue.updatedAt.formatted(.relative(presentation: .named)))
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
        .confirmationDialog("Close issue #\(issue.number)?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Close Issue", role: .destructive) { store.close(issue) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(issue.title)
        }
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
        .help("Close issue")
    }
}

private struct LabelBadge: View {
    let label: SearchIssue.Label

    var body: some View {
        Text(label.name)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(labelColor)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(labelColor.opacity(0.16)))
            .overlay(Capsule().strokeBorder(labelColor.opacity(0.35), lineWidth: 0.5))
    }

    private var labelColor: Color {
        Color(hex: label.color ?? "") ?? .secondary
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

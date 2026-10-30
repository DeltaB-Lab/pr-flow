# PRFlow

A macOS menu bar app that keeps your open GitHub pull requests one click away — grouped by repo, with merge & close actions right in a frosted-glass popover.

## Features

- **Menu bar tray** — live count badge of open PRs; left-click opens the panel, right-click shows a menu
- **Repo tabs** — PRs grouped by repository in horizontally scrollable tabs
- **Inline actions** — merge (squash / merge commit / rebase / auto-merge), close (with confirmation), open in browser
- **Status badges** — Draft, Approved, Changes requested, checks passing/failing/running, conflicts, behind, blocked
- **Account switcher** — switch between `gh` authenticated accounts from the header dropdown
- **Glass UI** — `NSVisualEffectView` popover material, adapts to light/dark
- Auto-refresh every 60s + refresh on open + manual refresh

## Requirements

- macOS 13.0+
- [`gh` CLI](https://cli.github.com) installed and logged in (`gh auth login`)

## Install

### Homebrew (recommended)

```bash
brew install --cask deltab-lab/tap/pr-flow
```

The app is ad-hoc signed (no Developer ID / notarization), so the cask installs it without quarantine. If macOS still complains, run:

```bash
xattr -dr com.apple.quarantine /Applications/PRFlow.app
```

### Build from source

```bash
git clone https://github.com/DeltaB-Lab/pr-flow.git
cd pr-flow
make run        # builds and opens PRFlow.app
```

Requires a Swift toolchain (`xcode-select --install` or Xcode). `make build` produces `PRFlow.app` with `AppIcon.icns` generated from `Assets/app-icon.png`.

## Usage

- Click the menu bar icon to open the panel; press the power icon or right-click → Quit to exit
- Click the `@username` chip in the header to switch `gh` accounts (uses `gh auth switch` — this changes the **global** active account) or add a new one via Terminal
- Merge/close operations shell out to `gh pr merge` / `gh pr close` — results surface as an in-app error banner if GitHub rejects them

### Debug

```bash
./PRFlow.app/Contents/MacOS/PRFlow --dump   # print fetched PRs to stdout
tail -f ~/Library/Logs/PRFlow.log           # every gh invocation + exit status
```

## How it works

Plain Swift + AppKit/SwiftUI built with SwiftPM — no Xcode project. `NSStatusItem` + `NSPopover` host a SwiftUI view inside an `NSVisualEffectView`. Data comes from `gh search prs --author=@me --state open`, then per-repo `gh pr list` enriches each PR with review decision, check rollup, and merge state. Icons were generated with Codex `image_gen` (prompts in `Assets/image-prompts.txt`).

## Notes

- Only PRs **authored by** the active `gh` account are shown
- `gh auth switch` is global — it also affects `gh` in your terminal
- Merging never deletes the head branch (`gh` default)

## License

MIT

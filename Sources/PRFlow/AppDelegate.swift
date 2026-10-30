import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: PRStore!
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        store = PRStore()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let menubarIcon = NSImage(named: "menubar-icon") {
                menubarIcon.size = NSSize(width: 17, height: 17)
                menubarIcon.isTemplate = true
                button.image = menubarIcon
            } else {
                button.image = NSImage(systemSymbolName: "arrow.triangle.pull", accessibilityDescription: "PRFlow")
                button.image?.isTemplate = true
            }
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popoverController = PopoverViewController()
        popoverController.store = store

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 400, height: 540)
        popover.contentViewController = popoverController
        popover.delegate = self

        store.$prs
            .map(\.count)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.statusItem.button?.title = count > 0 ? " \(count)" : ""
            }
            .store(in: &cancellables)

        store.start()
    }

    @objc @MainActor
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    @MainActor
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    @MainActor
    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "")
        refreshItem.target = self
        let quitItem = NSMenuItem(title: "Quit PRFlow", action: #selector(quitClicked), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
        sender.performClick(nil)
        statusItem.menu = nil
    }

    @objc @MainActor
    private func refreshClicked() {
        store.refresh()
    }

    @objc @MainActor
    private func quitClicked() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSPopoverDelegate {
    @MainActor
    func popoverWillShow(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        store.refresh()
    }
}

final class PopoverViewController: NSViewController {
    var store: PRStore!

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        view = effectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let hosting = NSHostingController(rootView: RootView(store: store))
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

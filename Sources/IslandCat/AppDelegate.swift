import AppKit
import IslandCatCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem?
    private var panels: [CatPanel] = []
    private var pointerMonitor: Any?

    private var showsCat: Bool {
        get { defaults.object(forKey: "showsCat") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showsCat") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Island Cat")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(placeCats),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            NSWorkspace.didWakeNotification,
        ] {
            workspace.addObserver(self, selector: #selector(placeCats), name: name, object: nil)
        }
        // Mouse movement over other apps needs no permission, unlike keys.
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        placeCats()
    }

    private func pointerMoved() {
        let location = NSEvent.mouseLocation
        for panel in panels { panel.pointer(at: location) }
    }

    /// One cat per screen with a camera island.
    @objc private func placeCats() {
        for panel in panels { panel.orderOut(nil) }
        panels = []
        guard showsCat else { return }
        let animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for screen in NSScreen.screens {
            guard let island = island(on: screen) else { continue }
            let panel = CatPanel(island: island, scale: screen.backingScaleFactor, animates: animates)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        pointerMoved()
    }

    /// The island on `screen`. The menu bar's height places it; while the
    /// menu bar hides, the height it had when it last showed stands in.
    private func island(on screen: NSScreen) -> Island? {
        let shape = ScreenShape(
            frame: screen.frame,
            visibleTop: screen.visibleFrame.maxY,
            safeTop: screen.safeAreaInsets.top,
            leftOfCamera: screen.auxiliaryTopLeftArea ?? .zero,
            rightOfCamera: screen.auxiliaryTopRightArea ?? .zero)
        let key = "menuBarHeight.\(Int(screen.frame.width))x\(Int(screen.frame.height))"
        let menuBar = shape.frame.maxY - shape.visibleTop
        if menuBar > 0 { defaults.set(Double(menuBar), forKey: key) }
        return Island.on(shape, menuBarHeight: defaults.double(forKey: key))
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if panels.isEmpty && showsCat {
            let none = NSMenuItem(title: "No screen with a camera island", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
            menu.addItem(.separator())
        }
        let show = NSMenuItem(title: "Show Cat", action: #selector(toggleCat), keyEquivalent: "")
        show.target = self
        show.state = showsCat ? .on : .off
        menu.addItem(show)

        let login = NSMenuItem(
            title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        switch SMAppService.mainApp.status {
        case .enabled: login.state = .on
        case .requiresApproval: login.state = .mixed
        default: login.state = .off
        }
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Island Cat", action: #selector(NSApp.terminate), keyEquivalent: "q"))
    }

    @objc private func toggleCat() {
        showsCat.toggle()
        placeCats()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Open at Login"
            alert.runModal()
        }
    }
}

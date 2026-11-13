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

    /// Walk in place while you swipe between desktops.
    private var walks: Bool {
        get { defaults.bool(forKey: "walks") }
        set { defaults.set(newValue, forKey: "walks") }
    }
    private lazy var swipes = DesktopSwipes { [weak self] in self?.swiped($0) }
    private var slide = Walk.Slide()
    /// Which way the cat goes; its tail trails behind, on the left while
    /// it goes right.
    private var heading = Walk.Heading()
    private var tailLeft = false
    /// How far the legs are out, 0 to 1, and how long since the desktops
    /// last moved.
    private var reach = 0.0
    private var lastMoved = 0.0
    private var walkTimer: Timer?

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
        workspace.addObserver(
            self, selector: #selector(reclaimCats),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        // Mouse movement over other apps needs no permission, unlike keys.
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        placeCats()
        if walks { _ = swipes.start() }
    }

    // MARK: Walking

    private func swiped(_ change: DesktopSwipes.Change) {
        let now = CACurrentMediaTime()
        // A new walk starts heading left from where the desktops are.
        if walkTimer == nil { heading = Walk.Heading(at: slide.offset) }
        switch change {
        case .moved(let progress):
            slide.follow(progress)
        case .lifted(let progress, let velocity):
            let screen = panels.first?.screen ?? NSScreen.main
            let neighbors = screen.map(DesktopSwipes.neighbors) ?? (left: true, right: true)
            slide.lift(
                at: progress, velocity: velocity, now: now,
                canGoLeft: neighbors.left, canGoRight: neighbors.right)
        }
        lastMoved = now
        guard walkTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stepWalk() }
        }
        RunLoop.main.add(timer, forMode: .common)
        walkTimer = timer
        stepWalk()
    }

    /// The legs come out while the desktops slide and tuck away once they
    /// stop. The tail trails behind the way the fingers go, and goes back
    /// to its place once the legs are tucked away.
    private func stepWalk() {
        let now = CACurrentMediaTime()
        if slide.advance(to: now) { lastMoved = now }
        let moving = now - lastMoved < 0.1
        reach = moving ? min(1, reach + 1.0 / 12) : max(0, reach - 1.0 / 18)
        // Only the fingers turn the cat; the system's slide after they
        // lift, even springing back, does not.
        if !slide.isSettling { _ = heading.follow(slide.offset) }
        let done = reach == 0 && !moving
        let left = heading.right && !done
        let turned = left != tailLeft
        tailLeft = left
        let phase = Walk.phase(slide.offset)
        for panel in panels {
            panel.walk(phase: phase, reach: reach)
            if turned { panel.tail(onLeft: left) }
        }
        if done {
            walkTimer?.invalidate()
            walkTimer = nil
        }
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
            if tailLeft { panel.tail(onLeft: true) }
            panels.append(panel)
        }
        FixedSpace.claim(panels)
        pointerMoved()
    }

    /// Keeps the cats in the fixed space if switching desktops pulled them
    /// back onto one.
    @objc private func reclaimCats() {
        FixedSpace.claim(panels)
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

        let walk = NSMenuItem(
            title: "Walk When Switching Desktops", action: #selector(toggleWalk),
            keyEquivalent: "")
        walk.target = self
        walk.state = walks ? .on : .off
        menu.addItem(walk)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Island Cat", action: #selector(NSApp.terminate), keyEquivalent: "q"))
    }

    @objc private func toggleCat() {
        showsCat.toggle()
        placeCats()
    }

    @objc private func toggleWalk() {
        walks.toggle()
        guard walks else {
            swipes.stop()
            return
        }
        if !swipes.start() {
            let alert = NSAlert()
            alert.messageText = "Island Cat needs Input Monitoring to walk"
            alert.informativeText =
                "To follow your swipe as it happens, Island Cat listens to the trackpad's "
                + "desktop-swipe gesture. Turn on Island Cat in System Settings › Privacy & "
                + "Security › Input Monitoring; the cat starts walking as soon as it's on."
            alert.runModal()
        }
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

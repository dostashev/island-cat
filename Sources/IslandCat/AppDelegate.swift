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
        get { defaults.object(forKey: "walks") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "walks") }
    }
    private lazy var swipes = DesktopSwipes { [weak self] in self?.swiped($0) }
    private var slide = Walk.Slide()
    /// Which way the cat goes; its tail trails behind, on the left while
    /// it goes right.
    private var heading = Walk.Heading()
    private var tailLeft = false
    private lazy var odometer = Walk.Odometer(meters: defaults.double(forKey: "metersWalked"))
    /// How far the legs are out, 0 to 1, and how long since the desktops
    /// last moved.
    private var reach = 0.0
    private var lastMoved = 0.0
    private var lastStep: Double?
    private var lastFrameOffset: Double?
    private var stride = Walk.Stride()
    /// Steps the walk on every frame the screen draws, while it lasts.
    private var walkTimer: CADisplayLink?
    /// Keeps macOS from napping the app or delaying its frames mid-walk.
    private var walkActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // As wide as the icon: macOS already spaces every item 8 pt from
        // its neighbors, and anything wider only adds to that.
        let icon = CatIcon.image()
        let item = NSStatusBar.system.statusItem(withLength: icon.size.width)
        item.button?.image = icon
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
        let before = slide.offset
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
        // The fingers moving the desktops; a swipe held still is not
        // walking.
        if slide.offset != before && !slide.isSettling { lastMoved = now }
        guard walkTimer == nil else { return }
        walkActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical], reason: "Walking with the desktops")
        let screen = panels.first?.screen ?? NSScreen.main
        if let link = screen?.displayLink(target: self, selector: #selector(stepWalk)) {
            link.add(to: .main, forMode: .common)
            walkTimer = link
        }
        stepWalk()
    }

    /// The legs come out while the desktops slide and tuck away once they
    /// stop. The tail trails behind the way the fingers go, and goes back
    /// to its place once the legs are tucked away.
    @objc private func stepWalk() {
        let now = CACurrentMediaTime()
        // By the clock, not the frame count, so a slow frame does not slow
        // the legs: out in 0.1 s, tucked away in 0.15 s.
        let elapsed = min(0.05, now - (lastStep ?? now))
        lastStep = now
        _ = slide.advance(to: now)
        // How far the desktops slid since the last frame, by the fingers or
        // the system's slide after they lift.
        let slid = slide.offset - (lastFrameOffset ?? slide.offset)
        lastFrameOffset = slide.offset
        // The cat walks while the fingers move the desktops: faster than a
        // tenth of a desktop a second. Once they lift, macOS finishes the
        // slide without drawing any app's windows, so the cat would freeze
        // mid-step; it tucks its legs away at once instead and stands still
        // through the rest of the slide.
        if slide.isSettling {
            lastMoved = 0
            reach = 0
        } else if elapsed > 0, abs(slid) / elapsed > 0.1 {
            lastMoved = now
        }
        let moving = now - lastMoved < 0.1
        if moving {
            stride.follow(slid, elapsed: elapsed)
            reach = min(1, reach + elapsed / 0.1)
        } else {
            // Finish the step on straight legs, then tuck them away.
            stride.finish(elapsed: elapsed)
            if stride.isStraight { reach = max(0, reach - elapsed / 0.15) }
        }
        // Only the fingers turn the cat; the system's slide after they
        // lift, even springing back, does not.
        if !slide.isSettling { _ = heading.follow(slide.offset) }
        // Over once the legs are tucked away and the slide has settled.
        let done = reach == 0 && !moving && !slide.isSettling
        let left = heading.right && !done
        let turned = left != tailLeft
        tailLeft = left
        odometer.follow(slide.offset, width: desktopPitch)
        let phase = stride.phase
        for panel in panels {
            panel.walk(phase: phase, reach: reach)
            if turned { panel.tail(onLeft: left) }
        }
        if done {
            walkTimer?.invalidate()
            walkTimer = nil
            lastStep = nil
            lastFrameOffset = nil
            if let walkActivity { ProcessInfo.processInfo.endActivity(walkActivity) }
            walkActivity = nil
            defaults.set(odometer.meters, forKey: "metersWalked")
        }
    }

    /// How far apart the desktops are as they slide, in meters: the width
    /// of the screen the cat walks on, as the display reports it, and the
    /// 64 pt black gap macOS leaves between desktops (measured from a
    /// screenshot mid-swipe, 12.7 mm on the 16-inch MacBook Pro). 35.9 cm,
    /// that MacBook's, when the display does not report its size.
    private var desktopPitch: Double {
        let gap: CGFloat = 64
        guard let screen = panels.first?.screen,
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID
        else { return 0.359 }
        let millimeters = CGDisplayScreenSize(id).width
        guard millimeters > 0 else { return 0.359 }
        return millimeters * (1 + gap / screen.frame.width) / 1000
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
        if walks || odometer.meters > 0 {
            let walked = NSMenuItem(
                title: "Walked \(Self.distance(odometer.meters))", action: nil, keyEquivalent: "")
            walked.isEnabled = false
            walked.indentationLevel = 1
            menu.addItem(walked)
        }

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Island Cat", action: #selector(NSApp.terminate), keyEquivalent: "q"))
    }

    @objc private func toggleCat() {
        showsCat.toggle()
        placeCats()
    }

    /// Meters with one decimal, grouped the way this Mac's locale groups
    /// numbers.
    static func distance(_ meters: Double) -> String {
        let format = NumberFormatter()
        format.numberStyle = .decimal
        format.minimumFractionDigits = 1
        format.maximumFractionDigits = 1
        return "\(format.string(from: NSNumber(value: meters)) ?? String(meters)) m"
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

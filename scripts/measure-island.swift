// Records how the Dynamic Island grows and shrinks under the pointer.
//
// Puts a white backdrop under the island so it shows black on white, records
// that part of the screen at up to 120 frames a second with ScreenCaptureKit,
// and writes a CSV of frames (time and the island's bounds) and of the
// pointer sampled on its own at 240 Hz, all in seconds and in points from
// the screen's top-left corner.
//
// Usage: swift scripts/measure-island.swift [seconds] [out.csv]
// Needs Screen Recording permission for the app that runs it. Quit Island
// Cat first, or its body will be measured as island.
import AppKit
import CoreMedia
import ScreenCaptureKit

let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1])! : 30
let outPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/island.csv"

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
guard let screen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }),
    let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea
else { fatalError("No screen with a camera housing") }

// The region to watch, in points from the screen's top-left corner.
let center = (left.maxX + right.minX) / 2 - screen.frame.minX
let region = CGRect(x: (center - 80).rounded(), y: 0, width: 160, height: 60)
let scale = screen.backingScaleFactor

let backdrop = NSWindow(
    contentRect: NSRect(
        x: screen.frame.minX + region.minX, y: screen.frame.maxY - region.maxY,
        width: region.width, height: region.height),
    styleMask: .borderless, backing: .buffered, defer: false)
backdrop.backgroundColor = .white
backdrop.level = .statusBar
backdrop.ignoresMouseEvents = true
backdrop.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
backdrop.orderFrontRegardless()

final class Recorder: NSObject, SCStreamOutput {
    var rows: [String] = ["kind,t,pointer_x,pointer_y,left,right,top,bottom"]
    let start = CACurrentMediaTime()

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
        let t = CACurrentMediaTime() - start

        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        let width = CVPixelBufferGetWidth(pixels)
        let height = CVPixelBufferGetHeight(pixels)
        let stride = CVPixelBufferGetBytesPerRow(pixels)
        let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
        func dark(_ x: Int, _ y: Int) -> Bool {
            let p = base + y * stride + x * 4  // BGRA
            return Int(p[0]) + Int(p[1]) + Int(p[2]) < 3 * 128
        }
        // The island is the dark run through the middle column, and the
        // widest dark run across any of its rows.
        let mid = width / 2
        var top = -1, bottom = -1
        for y in 0..<height where dark(mid, y) {
            if top < 0 { top = y }
            bottom = y
        }
        var minX = mid, maxX = mid
        if top >= 0 {
            for y in top...bottom {
                var a = mid, b = mid
                while a > 0 && dark(a - 1, y) { a -= 1 }
                while b < width - 1 && dark(b + 1, y) { b += 1 }
                minX = min(minX, a)
                maxX = max(maxX, b)
            }
        }
        let px = { (v: Int) in Double(v) / scale }
        let row =
            top < 0
            ? String(format: "frame,%.4f,,,,,,", t)
            : String(
                format: "frame,%.4f,,,%.1f,%.1f,%.1f,%.1f", t,
                region.minX + px(minX), region.minX + px(maxX + 1), px(top), px(bottom + 1))
        DispatchQueue.main.async { self.rows.append(row) }
    }
}

let recorder = Recorder()
var stream: SCStream?

// Frames come only when the screen changes, so sample the pointer on its own.
let pointerTimer = Timer(timeInterval: 1.0 / 240, repeats: true) { _ in
    let mouse = NSEvent.mouseLocation
    recorder.rows.append(
        String(
            format: "pointer,%.4f,%.1f,%.1f,,,,", CACurrentMediaTime() - recorder.start,
            mouse.x - screen.frame.minX, screen.frame.maxY - mouse.y))
}
RunLoop.main.add(pointerTimer, forMode: .common)

Task { @MainActor in
    do {
        // Let the backdrop reach the screen first.
        try await Task.sleep(for: .milliseconds(300))
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            fatalError("Display not shareable")
        }
        let config = SCStreamConfiguration()
        config.sourceRect = region
        config.width = Int(region.width * scale)
        config.height = Int(region.height * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 120)
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let s = SCStream(filter: filter, configuration: config, delegate: nil)
        try s.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: DispatchQueue(label: "frames"))
        try await s.startCapture()
        stream = s
        print("Recording for \(Int(seconds)) s: hover over the island and away a few times.")
        try await Task.sleep(for: .seconds(seconds))
        try await s.stopCapture()
        try recorder.rows.joined(separator: "\n").write(toFile: outPath, atomically: true, encoding: .utf8)
        print("Wrote \(recorder.rows.count - 1) frames to \(outPath)")
    } catch {
        print("Failed: \(error)")
    }
    exit(0)
}
app.run()

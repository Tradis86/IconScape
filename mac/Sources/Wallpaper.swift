// IconScape · macOS host: one borderless window per display at the desktop level (above the desktop picture, below the Finder icons),
// showing the current theme page with ?wallpaper=1. Same protocol as WallpaperForm in host/DesktopHost.cs:
//   page → host: "ready" (anything that is not a share message), "snapshot|…", "recprogress|…", "record|…"
//   host → page: settings, layout, icons, pause, snapshot, record (JSON strings)

import AppKit
import WebKit

final class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}

final class Wallpaper: NSObject {
    let displayID: CGDirectDisplayID
    private(set) var screen: NSScreen
    let window: WallpaperWindow
    let page: WebPage
    private var themePage: String
    private var manualPause: Bool
    private(set) var lastIcons = ""
    private var lastLayout = ""
    private var lastPause = -1
    private var timer: Timer?
    private var seenVisible = false                     // occlusion is trusted only once it has reported this window visible
    var sleeping = false                                // displays asleep, screen locked, screen saver or another user's session

    var settingsJSON: (() -> String)?                   // sent first when the page is ready
    var currentIcons: (() -> DesktopIcons.Snapshot?)?
    var onIconsChanged: ((String) -> Void)?             // forwarded to the settings preview (primary display)
    var onLayoutChanged: ((String) -> Void)?
    var onRecordProgress: ((String) -> Void)?

    init(screen: NSScreen, displayID: CGDirectDisplayID, pageDir: URL, themePage: String, manualPause: Bool) {
        self.screen = screen
        self.displayID = displayID
        self.themePage = themePage
        self.manualPause = manualPause
        window = WallpaperWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        page = WebPage(roots: ["app": pageDir])
        super.init()
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = NSColor(calibratedRed: 26.0 / 255, green: 163.0 / 255, blue: 196.0 / 255, alpha: 1)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.title = "IconScapeWindow"
        page.webView.autoresizingMask = [.width, .height]
        window.contentView = page.webView
        page.onMessage = { [weak self] s in self?.onPageMessage(s) }
        page.onCrash = { [weak self] in self?.page.reload() }
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                               name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    func show() {
        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()
        page.load(themePage + "?wallpaper=1")
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.pollPause() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Log.write("Wallpaper window on display \(displayID): \(NSStringFromRect(screen.frame)) @\(screen.backingScaleFactor)x")
    }

    func setManualPause(_ v: Bool) {
        manualPause = v
        pollPause()
    }

    // Switch theme: load the other page; once ready it receives settings, layout and icons again
    func loadPage(_ newPage: String) {
        themePage = newPage
        page.load(newPage + "?wallpaper=1")
    }

    func reload() { page.reload() }
    func post(_ json: String) { page.post(json) }

    private func onPageMessage(_ msg: String) {
        if msg.hasPrefix("snapshot|") { onSnapshot(msg); return }
        if msg.hasPrefix("recprogress|") { onRecordProgress?(String(msg.dropFirst(12))); return }
        if msg.hasPrefix("record|") { onRecord(msg); return }
        // The page is ready: the settings first (the scene depends on them), then where this display sits, the icons and the pause state
        if let s = settingsJSON?() { page.post(s) }
        lastLayout = ""
        relayout()
        lastIcons = ""
        lastPause = -1
        if let snap = currentIcons?() { setIcons(snap) }
        pollPause()
    }

    // ---------------------------------------------------------------- Display layout
    // The desktop as the pages see it: the union of all displays, top-left origin, y down, in points
    static func desktopRect() -> NSRect {
        return NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
    }
    static func flip(_ r: NSRect, in desktop: NSRect) -> NSRect {
        return NSRect(x: r.minX - desktop.minX, y: desktop.maxY - r.maxY, width: r.width, height: r.height)
    }

    // Moved to a display's new frame (resolution or arrangement changed)
    func place(_ s: NSScreen) {
        if s.frame != screen.frame || s.backingScaleFactor != screen.backingScaleFactor {
            lastIcons = ""
            lastPause = -1
        }
        screen = s
        window.setFrame(s.frame, display: true)
    }

    func ensurePlacement() {
        if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
        if !window.isVisible { window.orderFrontRegardless() }
    }

    // {t:'layout', x, y, w, h, mons}: this display and the whole desktop in this display's pixels (the page divides by its devicePixelRatio)
    func layoutJSON() -> String {
        let d = Wallpaper.desktopRect(), k = screen.backingScaleFactor
        let me = Wallpaper.flip(screen.frame, in: d)
        let mons: [[Int]] = NSScreen.screens.map { s in
            let r = Wallpaper.flip(s.frame, in: d)
            return [px(r.minX, k), px(r.minY, k), px(r.width, k), px(r.height, k)]
        }
        let msg: [String: Any] = ["t": "layout", "x": px(me.minX, k), "y": px(me.minY, k), "w": px(d.width, k), "h": px(d.height, k), "mons": mons]
        return Json.stringify(msg)
    }

    func relayout() {
        let json = layoutJSON()
        if json == lastLayout { return }
        lastLayout = json
        lastIcons = ""
        onLayoutChanged?(json)
        page.post(json)
        Log.write("Desktop layout (display \(displayID)): " + json)
    }

    // ---------------------------------------------------------------- Desktop icons
    // All the icons of the desktop, relative to this display's top-left corner (icons on other displays fall outside it): the page needs them all
    // to compute one continuous scene. Sent only when they change
    func setIcons(_ snap: DesktopIcons.Snapshot) {
        let d = Wallpaper.desktopRect(), k = screen.backingScaleFactor
        let me = Wallpaper.flip(screen.frame, in: d)
        var here = 0
        let rects: [[Int]] = snap.rects.map { ic in
            if ic.intersects(me) { here += 1 }
            return [px(ic.minX - me.minX, k), px(ic.minY - me.minY, k), px(ic.maxX - me.minX, k), px(ic.maxY - me.minY, k)]
        }
        let msg: [String: Any] = ["t": "icons", "vis": snap.visible, "r": rects]
        let json = Json.stringify(msg)
        if json == lastIcons { return }
        lastIcons = json
        onIconsChanged?(json)
        page.post(json)
        Log.write("Icons changed (display \(displayID)): \(here)/\(snap.rects.count), visible=\(snap.visible)")
    }

    // ---------------------------------------------------------------- Pause
    // Paused when the animations are stopped, when the displays sleep or the screen is locked, when the window is fully hidden,
    // or when an ordinary window covers this display's usable area (zoomed to fill it, or full screen)
    @objc private func occlusionChanged() {
        if window.occlusionState.contains(.visible) { seenVisible = true }
        pollPause()
    }

    func pollPause() {
        var pause = manualPause, why = manualPause ? "animations stopped" : ""
        if !pause && sleeping { pause = true; why = "displays asleep or locked" }
        if !pause && seenVisible && !window.occlusionState.contains(.visible) { pause = true; why = "window hidden" }
        if !pause, let owner = Wallpaper.coveringWindow(on: screen) { pause = true; why = "covered by " + owner }
        let p = pause ? 1 : 0
        if p == lastPause { return }
        lastPause = p
        page.post(pause ? "{\"t\":\"pause\",\"v\":true}" : "{\"t\":\"pause\",\"v\":false}")
        Log.write(pause ? "Paused (display \(displayID): \(why))" : "Running (display \(displayID))")
    }

    // Name of the app whose ordinary, opaque window covers the display's visible frame (menu bar and Dock excluded), or nil
    static func coveringWindow(on screen: NSScreen) -> String? {
        guard let primary = NSScreen.screens.first else { return nil }
        let vf = screen.visibleFrame
        // Cocoa coordinates (bottom-left origin) → window-server coordinates (top-left of the primary display)
        let target = CGRect(x: vf.minX, y: primary.frame.maxY - vf.maxY, width: vf.width, height: vf.height).insetBy(dx: 8, dy: 8)
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let me = Int(ProcessInfo.processInfo.processIdentifier)
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int) != me,
                  let alpha = w[kCGWindowAlpha as String] as? Double, alpha > 0.9,
                  let bounds = w[kCGWindowBounds as String] as? NSDictionary,
                  let b = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { continue }
            if b.contains(target) { return (w[kCGWindowOwnerName as String] as? String) ?? "?" }
        }
        return nil
    }

    // ---------------------------------------------------------------- Sharing: the page draws the picture or records the clip itself
    private var snapshotDone: ((String?, String?, String?) -> Void)?      // (thumbnail, full PNG, error)
    private var snapshotTimer: Timer?
    func requestSnapshot(_ done: @escaping (String?, String?, String?) -> Void) {
        if snapshotDone != nil { done(nil, nil, I18n.t("errBusyImage")); return }
        snapshotDone = done
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            self?.finishSnapshot(nil, nil, I18n.t("errImageTimeout"))
        }
        page.post("{\"t\":\"snapshot\"}")
    }
    private func onSnapshot(_ msg: String) {
        let p = msg.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map { String($0) }
        if p.count < 3 { finishSnapshot(nil, nil, I18n.t("errBadData")) }
        else if p[1] == "error" { finishSnapshot(nil, nil, p[2]) }
        else { finishSnapshot(p[1], p[2], nil) }
    }
    private func finishSnapshot(_ thumb: String?, _ png: String?, _ err: String?) {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
        let done = snapshotDone
        snapshotDone = nil
        done?(thumb, png, err)
    }

    private var recordDone: ((String?, String?, String?, String?) -> Void)?   // (format, poster, full video, error)
    private var recordTimer: Timer?
    func requestRecording(_ done: @escaping (String?, String?, String?, String?) -> Void) {
        if recordDone != nil { done(nil, nil, nil, I18n.t("errBusyVideo")); return }
        recordDone = done
        recordTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
            self?.finishRecord(nil, nil, nil, I18n.t("errVideoTimeout"))
        }
        page.post("{\"t\":\"record\"}")
    }
    private func onRecord(_ msg: String) {
        let p = msg.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map { String($0) }
        if p.count >= 3 && p[1] == "error" { finishRecord(nil, nil, nil, String(msg.dropFirst(13))) }
        else if p.count < 4 { finishRecord(nil, nil, nil, I18n.t("errBadData")) }
        else { finishRecord(p[1], p[2], p[3], nil) }
    }
    private func finishRecord(_ mime: String?, _ poster: String?, _ video: String?, _ err: String?) {
        recordTimer?.invalidate()
        recordTimer = nil
        let done = recordDone
        recordDone = nil
        done?(mime, poster, video, err)
    }

    // ---------------------------------------------------------------- Exit: the desktop picture shows again as soon as the window is gone
    func shutdown() {
        timer?.invalidate()
        timer = nil
        snapshotTimer?.invalidate()
        recordTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        page.close()
        window.orderOut(nil)
        window.close()
    }
}

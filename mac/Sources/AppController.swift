// IconScape · macOS host: lifetime of the program (HostContext in host/DesktopHost.cs).
// A menu bar icon instead of the tray icon; one wallpaper window per display; the settings window; sharing; open at login.

import AppKit

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let pageDir: URL
    let openSettingsAtStart: Bool
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let settingsItem = NSMenuItem(), pauseItem = NSMenuItem(), reloadItem = NSMenuItem(), autostartItem = NSMenuItem(), quitItem = NSMenuItem()
    private var walls: [Wallpaper] = []
    private let icons = DesktopIcons()
    private var settingsWin: SettingsWindow?
    private var manualPause = false
    private var saveTimer: Timer?, iconTimer: Timer?, screenTimer: Timer?
    private var syncedScreens = ""
    private var previewSize = (0, 0)                  // primary display size last sent to the settings page
    private var lastShare: URL?
    private var asleep = false, locked = false, saver = false, inactive = false

    init(pageDir: URL, openSettings: Bool) {
        self.pageDir = pageDir
        self.openSettingsAtStart = openSettings
        super.init()
    }

    // ---------------------------------------------------------------- Start and exit
    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("Start, pages: " + pageDir.path + (openSettingsAtStart ? "" : " (open at login)"))
        Settings.load()
        I18n.load(pageDir: pageDir, setting: Settings.lang)
        manualPause = Settings.still                     // animations stopped last time: they stay stopped
        buildStatusMenu()
        buildMainMenu()
        observeSystem()
        icons.onDenied = { [weak self] in self?.explainFinderAccess() }
        syncWalls()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.pollIcons() }
        RunLoop.main.add(t, forMode: .common)
        iconTimer = t
        if openSettingsAtStart { openSettings() }
    }

    // The program opened again (Finder, Dock, Spotlight) while running: open the settings
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return false }

    func applicationWillTerminate(_ notification: Notification) {
        iconTimer?.invalidate()
        if saveTimer != nil { saveTimer?.invalidate(); Settings.save() }
        settingsWin?.close()
        for w in walls { w.shutdown() }
        walls.removeAll()
        Log.write("Exit")
    }

    @objc private func exitRequested() { NSApp.terminate(nil) }
    @objc private func settingsRequested() { openSettings() }

    // ---------------------------------------------------------------- Menu bar icon
    private func buildStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusIcon.make()
        item.button?.toolTip = Profile.appName
        let entries: [(NSMenuItem, Selector, String)] = [
            (settingsItem, #selector(menuSettings), ","),
            (pauseItem, #selector(menuPause), ""),
            (reloadItem, #selector(menuReload), "r"),
            (autostartItem, #selector(menuAutostart), ""),
        ]
        for (mi, action, key) in entries {
            mi.action = action
            mi.keyEquivalent = key
            mi.target = self
            menu.addItem(mi)
        }
        menu.addItem(NSMenuItem.separator())
        quitItem.action = #selector(menuQuit)
        quitItem.keyEquivalent = "q"
        quitItem.target = self
        menu.addItem(quitItem)
        menu.delegate = self
        item.menu = menu
        statusItem = item
        applyMenuTexts()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseItem.state = manualPause ? .on : .off
        autostartItem.state = AutoStart.isOn ? .on : .off
    }

    private func applyMenuTexts() {
        settingsItem.title = I18n.t("traySettings")
        pauseItem.title = I18n.t("trayPause")
        reloadItem.title = I18n.t("trayReload")
        autostartItem.title = I18n.t("trayAutostartMac")
        quitItem.title = I18n.t("trayQuitMac")
        autostartItem.isHidden = Profile.isolated
    }

    // Not shown (the app has no Dock icon), but it gives the settings window the usual shortcuts: ⌘W, ⌘M, ⌘Q and copy/paste
    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: I18n.t("trayQuitMac"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.mainMenu = main
    }

    @objc private func menuSettings() { openSettings() }
    @objc private func menuPause() { setStill(!manualPause) }
    @objc private func menuReload() { for w in walls { w.reload() } }
    @objc private func menuAutostart() {
        AutoStart.set(!AutoStart.isOn)
        settingsWin?.post(Json.stringify(["t": "autostart", "v": AutoStart.isOn]))
    }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // Stop or restart the animations of every theme (menu or settings page): saved, so it holds after a restart
    private func setStill(_ still: Bool) {
        manualPause = still
        Settings.still = still
        saveSoon()
        for w in walls { w.setManualPause(still) }
        settingsWin?.post(Json.stringify(["t": "animate", "v": !still]))
        Log.write(still ? "Animations stopped" : "Animations running")
    }

    // ---------------------------------------------------------------- System events
    private func observeSystem() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(exitRequested), name: Profile.exitNote, object: nil)
        dnc.addObserver(self, selector: #selector(settingsRequested), name: Profile.settingsNote, object: nil)
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked", "com.apple.screensaver.didstart", "com.apple.screensaver.didstop"] {
            dnc.addObserver(self, selector: #selector(sleepChanged(_:)), name: Notification.Name(name), object: nil)
        }
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(self, selector: #selector(sleepChanged(_:)), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func sleepChanged(_ n: Notification) {
        switch n.name {
        case Notification.Name("com.apple.screenIsLocked"): locked = true
        case Notification.Name("com.apple.screenIsUnlocked"): locked = false
        case Notification.Name("com.apple.screensaver.didstart"): saver = true
        case Notification.Name("com.apple.screensaver.didstop"): saver = false
        case NSWorkspace.screensDidSleepNotification: asleep = true
        case NSWorkspace.screensDidWakeNotification: asleep = false
        case NSWorkspace.sessionDidResignActiveNotification: inactive = true
        case NSWorkspace.sessionDidBecomeActiveNotification: inactive = false
        default: return
        }
        let sleeping = asleep || locked || saver || inactive
        for w in walls {
            w.sleeping = sleeping
            w.pollPause()
        }
    }

    // A display added or removed, resolution or arrangement changed: wait until the changes settle, then rebuild
    @objc private func screensChanged() {
        screenTimer?.invalidate()
        screenTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in self?.applyScreens() }
    }

    private func applyScreens() {
        let now = AppController.screensSignature()
        if now == syncedScreens { return }
        Log.write("Display layout changed: " + now)
        let before = previewSize
        syncWalls()
        guard let sw = settingsWin else { return }
        if AppController.primaryPixelSize() != before { postInit() }
        else if let p = primaryWall(), !p.lastIcons.isEmpty { sw.post(p.lastIcons) }
    }

    static func displayID(_ s: NSScreen) -> CGDirectDisplayID {
        return (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    static func screensSignature() -> String {
        return NSScreen.screens.map { "\(displayID($0))\(NSStringFromRect($0.frame))@\($0.backingScaleFactor)" }.joined(separator: ";")
    }

    static func primaryPixelSize() -> (Int, Int) {
        guard let s = NSScreen.screens.first else { return (0, 0) }
        return (px(s.frame.width, s.backingScaleFactor), px(s.frame.height, s.backingScaleFactor))
    }

    // ---------------------------------------------------------------- Wallpaper windows, one per display
    private func syncWalls() {
        if !Themes.allowed(pageDir, Settings.theme) { Settings.theme = Themes.allowed(pageDir, "beach") ? "beach" : "meadow" }
        guard let page = Themes.page(pageDir, Settings.theme) else {
            Log.write("No theme page to load in " + pageDir.path)
            return
        }
        let screens = NSScreen.screens
        syncedScreens = AppController.screensSignature()
        for w in walls {
            if let s = screens.first(where: { AppController.displayID($0) == w.displayID }) {
                w.place(s)
            } else {
                Log.write("Display \(w.displayID) is gone: closing its wallpaper window")
                w.shutdown()
            }
        }
        walls.removeAll { w in !screens.contains { AppController.displayID($0) == w.displayID } }
        let sleeping = asleep || locked || saver || inactive
        for s in screens where !walls.contains(where: { $0.displayID == AppController.displayID(s) }) {
            let w = Wallpaper(screen: s, displayID: AppController.displayID(s), pageDir: pageDir, themePage: page, manualPause: manualPause)
            w.settingsJSON = { Json.stringify(["t": "settings", "v": Settings.forTheme(Settings.theme)]) }
            w.currentIcons = { [weak self] in self?.icons.last }
            w.onIconsChanged = { [weak self, weak w] json in
                guard let self = self, let w = w, w === self.primaryWall() else { return }
                self.settingsWin?.post(json)
            }
            w.onLayoutChanged = { [weak self, weak w] json in
                guard let self = self, let w = w, w === self.primaryWall() else { return }
                self.settingsWin?.post(json)
            }
            w.onRecordProgress = { [weak self] p in self?.settingsWin?.post("{\"t\":\"recProgress\",\"p\":" + p + "}") }
            w.sleeping = sleeping
            walls.append(w)
            w.show()
        }
        for w in walls { w.relayout() }      // the desktop changed shape: every page places itself again
    }

    // The window on the primary display (the one with the menu bar), the first one otherwise
    private func primaryWall() -> Wallpaper? {
        guard let primary = NSScreen.screens.first else { return walls.first }
        let id = AppController.displayID(primary)
        return walls.first { $0.displayID == id } ?? walls.first
    }

    // Every second: keep each window over its display, read the icons once and give them to every page
    private func pollIcons() {
        if walls.isEmpty { return }
        for w in walls { w.ensurePlacement() }
        guard let snap = icons.read() else { return }
        for w in walls { w.setIcons(snap) }
    }

    private func postToWalls(_ json: String) {
        for w in walls { w.post(json) }
    }

    private func saveSoon() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.saveTimer = nil
            Settings.save()
        }
    }

    // Shown once: the first read of the icons was refused
    private func explainFinderAccess() {
        let flag = Profile.dataDir.appendingPathComponent("finder-access.explained")
        if FileManager.default.fileExists(atPath: flag.path) { return }
        try? Date().description.data(using: .utf8)?.write(to: flag)
        let alert = NSAlert()
        alert.messageText = Profile.appName
        alert.informativeText = I18n.t("macFinderAccess")
        alert.addButton(withTitle: I18n.t("macOpenPrivacy"))
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // ---------------------------------------------------------------- Settings window
    func openSettings() {
        if settingsWin == nil {
            let sw = SettingsWindow(pageDir: pageDir)
            sw.onMessage = { [weak self] s in self?.onSettingsMessage(s) }
            sw.onClose = { [weak self] in self?.settingsWin = nil }
            settingsWin = sw
            Log.write("Settings window opened")
        }
        settingsWin?.show()
    }

    // Initial state for the settings page; its preview shows the primary display (size, place in the desktop, icons)
    private func postInit() {
        guard let sw = settingsWin else { return }
        let size = AppController.primaryPixelSize()
        previewSize = size
        let msg: [String: Any] = [
            "t": "init", "theme": Settings.theme, "params": Settings.params,
            "screen": ["w": size.0, "h": size.1], "autostart": AutoStart.isOn, "animate": !manualPause,
            "autostartWarn": false, "autostartSw": "",
            "lang": Settings.lang, "langEff": I18n.code, "langSys": I18n.sys, "platform": "mac",
        ]
        sw.post(Json.stringify(msg))
        if let p = primaryWall() {
            sw.post(p.layoutJSON())
            if !p.lastIcons.isEmpty { sw.post(p.lastIcons) }
        }
    }

    // Messages from the settings page: hello / set / reset / theme / lang / animate / autostart / share / shareVideo / openShare / revealShare
    private func onSettingsMessage(_ s: String) {
        guard let m = Json.parse(s) as? [String: Any], let sw = settingsWin else { return }
        switch (m["t"] as? String) ?? "" {
        case "hello":
            postInit()
        case "set":
            guard let theme = m["theme"] as? String, let key = m["key"] as? String else { return }
            let value: Any = m["value"] ?? NSNull()
            var d = Settings.params[theme] ?? [:]
            d[key] = value
            Settings.params[theme] = d
            if theme == Settings.theme {
                let v: [String: Any] = [key: value]
                postToWalls(Json.stringify(["t": "settings", "v": v]))
            }
            saveSoon()
        case "reset":
            guard let theme = m["theme"] as? String else { return }
            Settings.params.removeValue(forKey: theme)
            if theme == Settings.theme { postToWalls("{\"t\":\"reset\"}") }
            saveSoon()
            Log.write("Defaults restored: " + theme)
        case "theme":
            guard let id = m["id"] as? String, Themes.allowed(pageDir, id) else {
                sw.post(Json.stringify(["t": "themeChanged", "id": Settings.theme]))
                return
            }
            guard let page = Themes.page(pageDir, id), id != Settings.theme else { return }
            Settings.theme = id
            saveSoon()
            for w in walls { w.loadPage(page) }
            Log.write("Theme: " + id)
        case "lang":
            guard let v = m["v"] as? String else { return }
            Settings.lang = v
            saveSoon()
            I18n.load(pageDir: pageDir, setting: v)
            applyMenuTexts()
            sw.post(Json.stringify(["t": "lang", "v": Settings.lang, "eff": I18n.code, "sys": I18n.sys]))
        case "animate":
            setStill(!((m["v"] as? Bool) ?? false))
        case "autostart":
            AutoStart.set((m["v"] as? Bool) ?? false)
            sw.post(Json.stringify(["t": "autostart", "v": AutoStart.isOn]))
        case "share":
            guard let p = primaryWall() else { postShareResult(false, I18n.t("errNotReady")); return }
            p.requestSnapshot { [weak self] thumb, png, err in self?.onShareImage(thumb, png, err) }
        case "shareVideo":
            guard let p = primaryWall() else { postShareResult(false, I18n.t("errNotReady")); return }
            p.requestRecording { [weak self] mime, poster, video, err in self?.onShareVideo(mime, poster, video, err) }
        case "openShare":
            if let u = lastShare, FileManager.default.fileExists(atPath: u.path) { NSWorkspace.shared.open(u) }
        case "revealShare":
            if let u = lastShare, FileManager.default.fileExists(atPath: u.path) { NSWorkspace.shared.activateFileViewerSelecting([u]) }
        default:
            break
        }
    }

    // ---------------------------------------------------------------- Sharing: saved to ~/Pictures/IconScape and put on the clipboard
    private static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HHmmss"
        return f.string(from: Date())
    }

    private static func decodeDataURL(_ s: String) throws -> Data {
        let b64 = s.range(of: ",").map { String(s[$0.upperBound...]) } ?? s
        guard let d = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else {
            throw NSError(domain: Profile.appName, code: 1, userInfo: [NSLocalizedDescriptionKey: I18n.t("errBadData")])
        }
        return d
    }

    private func postShareResult(_ ok: Bool, _ msg: String) {
        settingsWin?.post(Json.stringify(["t": "shareResult", "ok": ok, "msg": msg]))
    }

    private func onShareImage(_ thumb: String?, _ png: String?, _ err: String?) {
        guard err == nil, let png = png else {
            postShareResult(false, err ?? I18n.t("errNoImage"))
            Log.write("Share image failed: " + (err ?? ""))
            return
        }
        do {
            let data = try AppController.decodeDataURL(png)
            try FileManager.default.createDirectory(at: Profile.sharesDir, withIntermediateDirectories: true)
            let url = Profile.sharesDir.appendingPathComponent(Profile.appName + " " + AppController.timestamp() + ".png")
            try data.write(to: url)
            lastShare = url
            let item = NSPasteboardItem()
            _ = item.setData(data, forType: .png)                      // apps that understand PNG
            if let tiff = NSImage(data: data)?.tiffRepresentation { _ = item.setData(tiff, forType: .tiff) }
            let pb = NSPasteboard.general
            _ = pb.clearContents()
            _ = pb.writeObjects([item])
            Log.write("Share image saved: " + url.path)
            var msg: [String: Any] = ["t": "shareResult", "ok": true, "path": url.path]
            if let thumb = thumb { msg["thumb"] = thumb }
            settingsWin?.post(Json.stringify(msg))
        } catch {
            Log.write("Saving the share image failed: " + error.localizedDescription)
            postShareResult(false, error.localizedDescription)
        }
    }

    private func onShareVideo(_ mime: String?, _ poster: String?, _ video: String?, _ err: String?) {
        guard err == nil, let video = video else {
            postShareResult(false, err ?? I18n.t("errNoVideo"))
            Log.write("Share clip failed: " + (err ?? ""))
            return
        }
        do {
            let data = try AppController.decodeDataURL(video)
            try FileManager.default.createDirectory(at: Profile.sharesDir, withIntermediateDirectories: true)
            let name = Profile.appName + " " + AppController.timestamp() + (mime == "video/webm" ? ".webm" : ".mp4")
            let url = Profile.sharesDir.appendingPathComponent(name)
            try data.write(to: url)
            lastShare = url
            let pb = NSPasteboard.general                                  // the file itself: paste it into a chat to send it
            _ = pb.clearContents()
            _ = pb.writeObjects([url as NSURL])
            Log.write("Share clip saved: \(url.path) (\(data.count / 1024) KB)")
            guard let sw = settingsWin else { return }
            sw.mapShareFolder(Profile.sharesDir)
            let link = WebPage.scheme + "://share/" + (name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)
            var msg: [String: Any] = ["t": "shareResult", "ok": true, "kind": "video", "path": url.path, "url": link]
            if let poster = poster { msg["thumb"] = poster }
            sw.post(Json.stringify(msg))
        } catch {
            Log.write("Saving the share clip failed: " + error.localizedDescription)
            postShareResult(false, error.localizedDescription)
        }
    }
}

// Menu bar icon: a template image (drawn in the menu bar's own color), the same idea as the app icon: a tile with a sun, icons and a hill
enum StatusIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let tile = NSBezierPath(roundedRect: NSRect(x: 1.75, y: 1.75, width: 14.5, height: 14.5), xRadius: 3.5, yRadius: 3.5)
            tile.lineWidth = 1.5
            NSGraphicsContext.saveGraphicsState()
            tile.addClip()
            let hill = NSBezierPath()
            hill.move(to: NSPoint(x: 0, y: 6.5))
            hill.curve(to: NSPoint(x: 18, y: 5), controlPoint1: NSPoint(x: 6, y: 10.5), controlPoint2: NSPoint(x: 11, y: 3))
            hill.line(to: NSPoint(x: 18, y: 0))
            hill.line(to: NSPoint(x: 0, y: 0))
            hill.close()
            hill.fill()
            NSGraphicsContext.restoreGraphicsState()
            tile.stroke()
            NSBezierPath(ovalIn: NSRect(x: 10.6, y: 10.2, width: 3.4, height: 3.4)).fill()
            for x in [4.4, 7.4] as [CGFloat] {
                NSBezierPath(roundedRect: NSRect(x: x, y: 10.6, width: 2.4, height: 2.4), xRadius: 0.5, yRadius: 0.5).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

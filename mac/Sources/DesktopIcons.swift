// IconScape · macOS host: where the desktop icons are.
// Finder reports the desktop position of every item (the center of its icon, in points, from the top-left corner of the primary display)
// through Apple Events; the first read asks the user to let IconScape control Finder (System Settings → Privacy & Security → Automation).
// The rectangles cover icon and label, like LVIR_BOUNDS on Windows, and are expressed in the desktop space of Wallpaper.flip.

import AppKit

final class DesktopIcons {
    struct Snapshot {
        var visible: Bool
        var rects: [NSRect]                 // points, top-left origin, relative to the top-left corner of the whole desktop
    }

    private(set) var last: Snapshot?
    var onDenied: (() -> Void)?             // Automation permission refused: called once
    private var iconSize: CGFloat = 64, textSize: CGFloat = 12
    private var optionsRead = Date.distantPast
    private var deniedReported = false
    private var errorsLogged = 0

    private let positions = NSAppleScript(source: """
        with timeout of 3 seconds
            tell application "Finder" to get desktop position of every item of desktop
        end timeout
        """)
    private let viewOptions = NSAppleScript(source: """
        with timeout of 3 seconds
            tell application "Finder"
                set o to icon view options of window of desktop
                return {icon size of o, text size of o}
            end tell
        end timeout
        """)

    // Desktop items shown at all? (Finder's CreateDesktop, and "Show items on desktop" turned off in Desktop & Dock on macOS 14 and later)
    static func desktopShown() -> Bool {
        _ = CFPreferencesAppSynchronize("com.apple.finder" as CFString)
        if let v = CFPreferencesCopyAppValue("CreateDesktop" as CFString, "com.apple.finder" as CFString) {
            if let b = v as? Bool, !b { return false }
            if let s = v as? String, ["0", "false", "no"].contains(s.lowercased()) { return false }
        }
        _ = CFPreferencesAppSynchronize("com.apple.WindowManager" as CFString)
        if let v = CFPreferencesCopyAppValue("StandardHideDesktopIcons" as CFString, "com.apple.WindowManager" as CFString),
           let b = v as? Bool, b {
            return false
        }
        return true
    }

    func read() -> Snapshot? {
        if !DesktopIcons.desktopShown() {
            last = Snapshot(visible: false, rects: [])                 // desktop icons hidden: the whole scene is open land / sea
            return last
        }
        // Never launch Finder ourselves (it may have been quit on purpose)
        if NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").isEmpty { return last }
        if Date().timeIntervalSince(optionsRead) > 15 { readOptions() }
        guard let script = positions else { return last }
        var err: NSDictionary?
        let res = script.executeAndReturnError(&err)
        if let e = err {
            let code = (e[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -1743 || code == -1744 {                     // errAEEventNotPermitted / errAEEventWouldRequireUserConsent
                if !deniedReported {
                    deniedReported = true
                    Log.write("Finder automation is not allowed: the desktop icons cannot be read")
                    onDenied?()
                }
                last = Snapshot(visible: true, rects: [])
            } else if errorsLogged < 20 {
                errorsLogged += 1
                Log.write("Reading the desktop icons failed (\(code)): \((e[NSAppleScript.errorMessage] as? String) ?? "")")
            }
            return last
        }
        guard let primary = NSScreen.screens.first else { return last }
        let d = Wallpaper.desktopRect()
        // Finder's origin (top-left of the primary display) in the desktop space of Wallpaper.flip
        let ox = primary.frame.minX - d.minX, oy = d.maxY - primary.frame.maxY
        var rects: [NSRect] = []
        let n = res.numberOfItems
        if n > 0 {
            for i in 1...n {
                guard let p = res.atIndex(i), p.numberOfItems >= 2, let x = p.atIndex(1), let y = p.atIndex(2) else { continue }
                rects.append(rect(center: CGPoint(x: CGFloat(x.int32Value) + ox, y: CGFloat(y.int32Value) + oy)))
            }
        }
        last = Snapshot(visible: true, rects: rects)
        return last
    }

    // Icon picture centered on the position, the label below it (names wrap on up to two lines)
    private func rect(center c: CGPoint) -> NSRect {
        let s = iconSize
        let label = ceil(textSize * 1.3) * 2 + 6
        let w = max(s + 24, textSize * 7.5)
        return NSRect(x: c.x - w / 2, y: c.y - s / 2 - 3, width: w, height: s + 3 + label)
    }

    private func readOptions() {
        optionsRead = Date()
        guard let script = viewOptions else { return }
        var err: NSDictionary?
        let res = script.executeAndReturnError(&err)
        if err != nil || res.numberOfItems < 2 { return }
        if let a = res.atIndex(1), a.int32Value > 0 { iconSize = CGFloat(a.int32Value) }
        if let b = res.atIndex(2), b.int32Value > 0 { textSize = CGFloat(b.int32Value) }
    }
}

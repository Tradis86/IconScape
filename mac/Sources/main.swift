// IconScape · macOS host
// IconScape is a modified version of Deskland Preview (https://github.com/BLEZZ0102/Deskland, GPL-3.0); this is its macOS host,
// written for IconScape. It shows the same pages as the Windows host (prototype/) and speaks the same message protocol:
//   1. One borderless window per display at the desktop level, above the desktop picture and below the Finder icons, showing the theme page
//   2. Every second reads the positions of the desktop icons from Finder and sends them to the pages when they change
//   3. Pauses a display while a window covers it, while the displays sleep or the screen is locked, and when the animations are stopped
//   4. Menu bar icon (settings, stop animations, reload, open at login, quit) and the settings window (prototype/settings.html)
//
// Command line: IconScape --exit (quit the running instance), --settings (open its settings), --autostart (started at login: no settings window),
// any other argument without a leading dash = folder of the pages (development; by default Contents/Resources/prototype).

import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())

func notifyRunningInstance(_ name: Notification.Name) {
    DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: nil, deliverImmediately: true)
}

if arguments.first == "--exit" { notifyRunningInstance(Profile.exitNote); exit(0) }
if arguments.first == "--settings" { notifyRunningInstance(Profile.settingsNote); exit(0) }

let fromLogin = arguments.contains("--autostart")
var pageDir = Bundle.main.resourceURL?.appendingPathComponent("prototype", isDirectory: true)
    ?? URL(fileURLWithPath: "prototype", isDirectory: true)
for a in arguments where !a.hasPrefix("-") {
    pageDir = URL(fileURLWithPath: (a as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
}

// One instance per profile: a lock file in the data folder. Started again by hand = open the settings of the running one
try? FileManager.default.createDirectory(at: Profile.dataDir, withIntermediateDirectories: true)
let lockFile = open(Profile.dataDir.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, 0o644)
if lockFile >= 0 && flock(lockFile, LOCK_EX | LOCK_NB) != 0 {
    if !fromLogin { notifyRunningInstance(Profile.settingsNote) }
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)                  // menu bar app: no Dock icon (LSUIElement)
let controller = AppController(pageDir: pageDir, openSettings: !fromLogin)
app.delegate = controller
app.run()

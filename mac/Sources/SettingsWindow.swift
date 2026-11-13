// IconScape · macOS host: the settings window (prototype/settings.html), created when opened and released when closed.

import AppKit
import WebKit

final class SettingsWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    let page: WebPage
    var onMessage: ((String) -> Void)?
    var onClose: (() -> Void)?

    init(pageDir: URL) {
        page = WebPage(roots: ["app": pageDir])
        // Themes in three columns on the left; preview and parameters on the right (same layout as on Windows), smaller on small displays
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: min(1120, visible.width - 40), height: min(800, visible.height - 40))
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = Profile.appName
        window.contentMinSize = NSSize(width: min(940, size.width), height: min(680, size.height))
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.delegate = self
        page.webView.autoresizingMask = [.width, .height]
        window.contentView = page.webView
        window.center()
        _ = window.setFrameAutosaveName("IconScapeSettings")
        page.onMessage = { [weak self] s in self?.onMessage?(s) }
        page.onCrash = { [weak self] in self?.page.reload() }
        let v = Profile.version.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        page.load("settings.html?v=" + v)
        Log.write("Settings page: \(WebPage.scheme)://app/settings.html?v=\(v)")
    }

    func show() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func post(_ json: String) { page.post(json) }

    func close() { window.close() }

    // The folder of the shared images and clips becomes iconscape://share/, so the settings page can show and play them
    func mapShareFolder(_ dir: URL) { page.schemes.roots["share"] = dir }

    func windowWillClose(_ notification: Notification) {
        page.close()
        onClose?()
    }
}

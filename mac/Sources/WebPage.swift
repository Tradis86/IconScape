// IconScape · macOS host: a WKWebView that serves the shared pages and speaks the same message protocol as the Windows host.
//
// The pages talk to the host through window.chrome.webview (WebView2 on Windows): postMessage(string) towards the host, and
// "message" events whose data is a JSON string from the host. Here a script injected at document start provides the same object
// on top of WKScriptMessageHandler / evaluateJavaScript, so the theme pages and the settings page run unchanged.

import AppKit
import WebKit

// Serves files of local folders on the iconscape:// scheme: iconscape://app/… = prototype/, iconscape://share/… = the shared images and clips.
// Range requests are answered, so <video> can play the shared clips.
final class FolderSchemeHandler: NSObject, WKURLSchemeHandler {
    var roots: [String: URL]

    init(roots: [String: URL]) {
        self.roots = roots
        super.init()
    }

    static let types: [String: String] = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "mjs": "text/javascript; charset=utf-8",
        "json": "application/json; charset=utf-8", "css": "text/css; charset=utf-8", "txt": "text/plain; charset=utf-8",
        "png": "image/png", "webp": "image/webp", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
        "svg": "image/svg+xml", "ico": "image/x-icon", "mp4": "video/mp4", "webm": "video/webm",
        "woff": "font/woff", "woff2": "font/woff2", "ttf": "font/ttf", "otf": "font/otf",
    ]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let host = url.host?.lowercased(), let root = roots[host] else {
            fail(task, 404)
            return
        }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let base = root.standardizedFileURL
        let file = base.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        guard file.path.hasPrefix(base.path + "/"), let data = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            fail(task, 404)
            return
        }
        var status = 200
        var body = data
        var headers: [String: String] = [
            "Content-Type": FolderSchemeHandler.types[file.pathExtension.lowercased()] ?? "application/octet-stream",
            "Accept-Ranges": "bytes",
            "Cache-Control": "no-cache",
        ]
        if let range = task.request.value(forHTTPHeaderField: "Range"), let r = FolderSchemeHandler.parseRange(range, count: data.count) {
            body = data.subdata(in: r)
            status = 206
            headers["Content-Range"] = "bytes \(r.lowerBound)-\(r.upperBound - 1)/\(data.count)"
        }
        headers["Content-Length"] = String(body.count)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
            fail(task, 500)
            return
        }
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) { }

    // "bytes=start-end", "bytes=start-" or "bytes=-suffix" (only the first range of a list)
    static func parseRange(_ header: String, count: Int) -> Range<Int>? {
        guard header.hasPrefix("bytes="), count > 0 else { return nil }
        let spec = header.dropFirst(6).split(separator: ",").first.map { String($0) } ?? ""
        let parts = spec.split(separator: "-", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        var start: Int, end: Int
        if parts[0].isEmpty {
            guard let n = Int(parts[1]), n > 0 else { return nil }
            start = max(0, count - n)
            end = count - 1
        } else {
            guard let s = Int(parts[0]) else { return nil }
            start = s
            end = parts[1].isEmpty ? count - 1 : (Int(parts[1]) ?? count - 1)
        }
        end = min(end, count - 1)
        guard start >= 0, start <= end else { return nil }
        return start..<(end + 1)
    }

    private func fail(_ task: WKURLSchemeTask, _ code: Int) {
        if let url = task.request.url,
           let r = HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": "0"]) {
            task.didReceive(r)
            task.didFinish()
        } else {
            task.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: nil))
        }
    }
}

// Keeps WKUserContentController from retaining the page (it holds its message handlers strongly)
final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

final class WebPage: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let scheme = "iconscape"

    // window.chrome.webview for the top frame only (the settings preview iframe talks to its parent with window.postMessage, as on Windows)
    static let bridgeScript = """
    (function () {
      if (window.chrome && window.chrome.webview) return;
      var listeners = [];
      window.chrome = window.chrome || {};
      window.chrome.webview = {
        postMessage: function (m) { window.webkit.messageHandlers.host.postMessage(typeof m === 'string' ? m : JSON.stringify(m)); },
        addEventListener: function (type, fn) { if (type === 'message' && typeof fn === 'function') listeners.push(fn); },
        removeEventListener: function (type, fn) { var i = listeners.indexOf(fn); if (i >= 0) listeners.splice(i, 1); }
      };
      window.__iconscapeDeliver = function (s) {
        listeners.slice().forEach(function (fn) { try { fn({ data: s }); } catch (e) { console.error(e); } });
      };
    })();
    """

    let webView: WKWebView
    let schemes: FolderSchemeHandler
    var onMessage: ((String) -> Void)?
    var onCrash: (() -> Void)?
    private var closed = false

    init(roots: [String: URL]) {
        let handler = FolderSchemeHandler(roots: roots)
        schemes = handler
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: WebPage.scheme)
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(source: WebPage.bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = content
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        super.init()
        content.add(WeakMessageHandler(self), name: "host")
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")       // the window's own color shows until the page has painted
        webView.allowsMagnification = false
        if #available(macOS 13.3, *) { webView.isInspectable = true }   // Safari → Develop menu, like the WebView2 DevTools on Windows
    }

    // Path inside prototype/, with its query string (e.g. "flat.html?wallpaper=1")
    func load(_ path: String) {
        guard !closed, let url = URL(string: WebPage.scheme + "://app/" + path) else { return }
        webView.load(URLRequest(url: url))
    }

    func reload() {
        if !closed { webView.reload() }
    }

    // Host → page: delivered as a "message" event whose data is the JSON string, like PostWebMessageAsString
    func post(_ json: String) {
        if closed { return }
        webView.evaluateJavaScript("window.__iconscapeDeliver && window.__iconscapeDeliver(" + Json.jsString(json) + ")", completionHandler: nil)
    }

    func close() {
        if closed { return }
        closed = true
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "host")
        webView.stopLoading()
        webView.navigationDelegate = nil
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if let s = message.body as? String { onMessage?(s) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Log.write("The web content process ended: reloading the page")
        onCrash?()
    }
}

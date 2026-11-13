// IconScape · macOS host: data folder, log, JSON helpers, settings, UI language and theme manifest.
// Mirrors the static classes of host/DesktopHost.cs and host/Themes.cs (same settings.json format and the same i18n files).

import AppKit
import Foundation

// Where IconScape keeps its data, and the per-profile names that keep an isolated test profile apart from the normal instance
enum Profile {
    static let appName = "IconScape"
    static let override: String? = {
        let v = ProcessInfo.processInfo.environment["ICONSCAPE_PROFILE_DIR"]
        return (v?.isEmpty == false) ? v : nil
    }()
    static var isolated: Bool { return override != nil }
    static let dataDir: URL = {
        if let o = override {
            return URL(fileURLWithPath: (o as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support", isDirectory: true)
        return base.appendingPathComponent(appName, isDirectory: true)
    }()
    // Suffix of the notification names and of the instance lock: empty for the normal profile, a hash of the folder for an isolated one
    static let suffix: String = {
        guard let o = override else { return "" }
        var h: UInt64 = 5381
        for b in o.utf8 { h = (h &* 33) &+ UInt64(b) }
        return "." + String(h, radix: 16)
    }()
    static let exitNote = Notification.Name("app.iconscape.exit" + suffix)
    static let settingsNote = Notification.Name("app.iconscape.settings" + suffix)
    // Shared images and clips: ~/Pictures/IconScape
    static let sharesDir: URL = {
        let pics = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Pictures", isDirectory: true)
        return pics.appendingPathComponent(appName, isDirectory: true)
    }()
    static var version: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
}

enum Log {
    static let fileURL = Profile.dataDir.appendingPathComponent("host.log")
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss "
        return f
    }()

    static func write(_ msg: String) {
        guard let data = (stamp.string(from: Date()) + msg + "\n").data(using: .utf8) else { return }
        do {
            try FileManager.default.createDirectory(at: Profile.dataDir, withIntermediateDirectories: true)
            if let h = try? FileHandle(forWritingTo: fileURL) {
                h.seekToEndOfFile()
                h.write(data)
                h.closeFile()
            } else {
                try data.write(to: fileURL)
            }
        } catch { }
    }
}

enum Json {
    static func parse(_ s: String) -> Any? {
        guard let d = s.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
    }
    // Sorted keys: the same content always gives the same string (messages are compared to send them only when they change)
    static func stringify(_ o: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(o),
              let d = try? JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]),
              let s = String(data: d, encoding: .utf8) else { return "null" }
        return s
    }
    // The text as a JavaScript string literal, for evaluateJavaScript
    static func jsString(_ s: String) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: [s], options: []),
              let a = String(data: d, encoding: .utf8), a.count >= 2 else { return "\"\"" }
        return String(a.dropFirst().dropLast())
    }
    static func readObject(_ url: URL) -> [String: Any]? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d, options: [])) as? [String: Any]
    }
}

// Physical pixels as the pages expect them (they divide by devicePixelRatio, which on macOS is the screen's backing scale factor)
func px(_ v: CGFloat, _ scale: CGFloat) -> Int {
    return Int((v * scale).rounded())
}

// User settings: current theme, UI language, animations stopped, and each theme's changed parameters (settings.json, same format as on Windows)
enum Settings {
    static let fileURL = Profile.dataDir.appendingPathComponent("settings.json")
    static var theme = "beach"
    static var lang = "auto"
    static var still = false
    static var params: [String: [String: Any]] = [:]

    static func load() {
        guard let root = Json.readObject(fileURL) else { return }
        if let v = root["theme"] as? String { theme = v }
        if let v = root["lang"] as? String { lang = v }
        if let v = root["still"] as? Bool { still = v }
        if let p = root["params"] as? [String: Any] {
            for (k, v) in p {
                if let d = v as? [String: Any] { params[k] = d }
            }
        }
        Log.write("Settings read: theme " + theme)
    }

    static func save() {
        do {
            try FileManager.default.createDirectory(at: Profile.dataDir, withIntermediateDirectories: true)
            let root: [String: Any] = ["version": 1, "theme": theme, "lang": lang, "still": still, "params": params]
            let d = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
            try d.write(to: fileURL, options: .atomic)
        } catch {
            Log.write("Saving the settings failed: " + error.localizedDescription)
        }
    }

    static func forTheme(_ id: String) -> [String: Any] {
        return params[id] ?? [:]
    }
}

// UI language: the "host" tables of prototype/i18n/<language>.json (menu bar menu and alerts). "auto" follows the macOS language order;
// languages that are not included fall back to English
enum I18n {
    // When adding a language, also update LANGS in prototype/settings.html and I18n.Supported in host/DesktopHost.cs
    static let supported = ["en", "it", "es", "fr", "de", "zh-CN"]
    static var code = "en", sys = "en"
    private static var cur: [String: Any]?, en: [String: Any]?, zh: [String: Any]?

    static func fromSystem() -> String {
        for id in Locale.preferredLanguages {
            let n = id.lowercased()
            if n.hasPrefix("zh") { return "zh-CN" }        // Traditional Chinese is not done yet: use Simplified, as on Windows
            let two = String(n.prefix(2))
            if supported.contains(two) { return two }
        }
        return "en"
    }

    static func load(pageDir: URL, setting: String) {
        sys = fromSystem()
        code = supported.contains(setting) ? setting : sys
        zh = read(pageDir, "zh-CN")
        en = read(pageDir, "en")
        cur = code == "zh-CN" ? zh : code == "en" ? en : read(pageDir, code)
        Log.write("UI language: \(code) (setting: \(setting), system: \(sys))")
    }

    private static func read(_ pageDir: URL, _ c: String) -> [String: Any]? {
        let url = pageDir.appendingPathComponent("i18n", isDirectory: true).appendingPathComponent(c + ".json")
        guard let root = Json.readObject(url) else {
            Log.write("Reading the language file failed: " + c)
            return nil
        }
        return root["host"] as? [String: Any]
    }

    // Current language → English → Simplified Chinese; {name} placeholders are replaced by the given values
    static func t(_ key: String, _ values: [String: String] = [:]) -> String {
        var s = (cur?[key] as? String) ?? (en?[key] as? String) ?? (zh?[key] as? String) ?? key
        for (k, v) in values { s = s.replacingOccurrences(of: "{" + k + "}", with: v) }
        return s
    }
}

// Theme manifest (prototype/themes.json): only ready themes marked "free" are loaded, as in host/Themes.cs
enum Themes {
    static func find(_ pageDir: URL, _ id: String) -> [String: Any]? {
        guard let root = Json.readObject(pageDir.appendingPathComponent("themes.json")),
              let list = root["themes"] as? [Any] else { return nil }
        for o in list {
            if let t = o as? [String: Any], t["id"] as? String == id, t["status"] as? String == "ready" { return t }
        }
        return nil
    }

    static func page(_ pageDir: URL, _ id: String) -> String? {
        return find(pageDir, id)?["page"] as? String
    }

    static func allowed(_ pageDir: URL, _ id: String) -> Bool {
        guard let t = find(pageDir, id), t["page"] is String else { return false }
        return t["product"] as? String == "free"
    }
}

// Open at login: a LaunchAgent in ~/Library/LaunchAgents that starts the program with --autostart (no settings window at login)
enum AutoStart {
    static let label = "app.iconscape.IconScape"
    static var plistURL: URL {
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent(label + ".plist")
    }
    static var executable: String {
        return Bundle.main.executablePath ?? CommandLine.arguments[0]
    }

    static var isOn: Bool {
        guard !Profile.isolated, let d = NSDictionary(contentsOf: plistURL),
              let args = d["ProgramArguments"] as? [String] else { return false }
        return args.first == executable
    }

    static func set(_ on: Bool) {
        if Profile.isolated { return }
        do {
            if on {
                try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let d: NSDictionary = [
                    "Label": label,
                    "ProgramArguments": [executable, "--autostart"],
                    "RunAtLoad": true,
                    "ProcessType": "Interactive",
                    "LimitLoadToSessionType": "Aqua",
                ]
                if !d.write(to: plistURL, atomically: true) {
                    Log.write("Writing the login item failed: " + plistURL.path)
                    return
                }
                Log.write("Open at login: on")
            } else if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
                Log.write("Open at login: off")
            }
        } catch {
            Log.write("Changing open at login failed: " + error.localizedDescription)
        }
    }
}

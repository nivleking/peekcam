import CoreGraphics
import Foundation

/// Where PeekCam keeps its settings.
public enum AppPaths {
    public static var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PeekCam", isDirectory: true)
    }
}

/// A global shortcut written the way people read it, e.g. `"ctrl+shift+M"` or `"cmd+shift+9"`.
public struct HotKeySpec: Equatable {
    // Carbon modifier masks (cmdKey, shiftKey, optionKey, controlKey in HIToolbox/Events.h).
    public static let command = 1 << 8
    public static let shift = 1 << 9
    public static let option = 1 << 11
    public static let control = 1 << 12

    /// Virtual key codes from HIToolbox/Events.h (kVK_ANSI_*). They follow the physical
    /// US keyboard layout, which is why they look random.
    static let keyCodes: [String: Int] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
        "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "O": 31, "U": 32, "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46,
    ]

    public var keyCode: Int
    public var modifiers: Int

    /// Returns nil for an unknown key or a shortcut without any modifier
    /// (a bare letter would steal normal typing).
    public init?(_ text: String) {
        var mods = 0
        var key: Int?
        for raw in text.split(separator: "+") {
            let part = raw.trimmingCharacters(in: .whitespaces)
            switch part.lowercased() {
            case "cmd", "command", "⌘": mods |= Self.command
            case "shift", "⇧": mods |= Self.shift
            case "opt", "option", "alt", "⌥": mods |= Self.option
            case "ctrl", "control", "⌃": mods |= Self.control
            default:
                guard key == nil, let code = Self.keyCodes[part.uppercased()] else { return nil }
                key = code
            }
        }
        guard let key, mods != 0 else { return nil }
        keyCode = key
        modifiers = mods
    }

    /// "⌃⇧M", for menus.
    public var display: String {
        var s = ""
        if modifiers & Self.control != 0 { s += "⌃" }
        if modifiers & Self.option != 0 { s += "⌥" }
        if modifiers & Self.shift != 0 { s += "⇧" }
        if modifiers & Self.command != 0 { s += "⌘" }
        return s + (Self.keyCodes.first { $0.value == keyCode }?.key ?? "?")
    }
}


public struct AppSettings: Codable, Equatable {
    public static let defaultHotKey = "ctrl+shift+M"

    public var hotKey = AppSettings.defaultHotKey
    /// Show the picture like a mirror (flipped left to right), as Photo Booth does.
    public var mirror = true
    public var size = SizePreset.medium
    public var aspect = AspectRatio.wide
    /// `uniqueID` of the chosen camera. Nil = built-in camera.
    public var cameraID: String?
    /// `~` is expanded. ~/Pictures avoids the Desktop/Documents privacy prompt.
    public var saveDirectory = "~/Pictures/PeekCam"
    /// Copy each snap to the clipboard as well as saving it.
    public var copySnapToClipboard = true
    /// Last frame of the detached window as [x, y, width, height]. Nil = never detached.
    public var detachedFrame: [Double]?

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        hotKey = try c.decodeIfPresent(String.self, forKey: .hotKey) ?? d.hotKey
        mirror = try c.decodeIfPresent(Bool.self, forKey: .mirror) ?? d.mirror
        size = (try? c.decodeIfPresent(SizePreset.self, forKey: .size)) ?? d.size
        aspect = (try? c.decodeIfPresent(AspectRatio.self, forKey: .aspect)) ?? d.aspect
        cameraID = try c.decodeIfPresent(String.self, forKey: .cameraID)
        saveDirectory = try c.decodeIfPresent(String.self, forKey: .saveDirectory) ?? d.saveDirectory
        copySnapToClipboard = try c.decodeIfPresent(Bool.self, forKey: .copySnapToClipboard) ?? d.copySnapToClipboard
        detachedFrame = try? c.decodeIfPresent([Double].self, forKey: .detachedFrame)
    }

    public var hotKeySpec: HotKeySpec {
        HotKeySpec(hotKey) ?? HotKeySpec(Self.defaultHotKey)!
    }

    /// Preview size in points.
    public var previewSize: (width: Double, height: Double) { size.dimensions(aspect) }

    public var saveDirectoryURL: URL {
        URL(fileURLWithPath: (saveDirectory as NSString).expandingTildeInPath, isDirectory: true)
    }

    public var detachedRect: CGRect? {
        guard let f = detachedFrame, f.count == 4 else { return nil }
        return CGRect(x: f[0], y: f[1], width: f[2], height: f[3])
    }

    /// Brings hand-edited values back into a safe range.
    public func validated() -> AppSettings {
        var v = self
        if HotKeySpec(v.hotKey) == nil { v.hotKey = Self.defaultHotKey }
        if v.cameraID?.trimmingCharacters(in: .whitespaces).isEmpty == true { v.cameraID = nil }
        if v.saveDirectory.trimmingCharacters(in: .whitespaces).isEmpty { v.saveDirectory = AppSettings().saveDirectory }
        if v.detachedFrame?.count != 4 { v.detachedFrame = nil }
        return v
    }

    /// Reads settings.json, or writes the defaults when it does not exist yet.
    public static func load(from directory: URL) -> AppSettings {
        let url = directory.appendingPathComponent("settings.json")
        if let data = try? Data(contentsOf: url),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings.validated()
        }
        let defaults = AppSettings()
        try? defaults.save(to: directory)
        return defaults
    }

    public func save(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: directory.appendingPathComponent("settings.json"), options: .atomic)
    }
}

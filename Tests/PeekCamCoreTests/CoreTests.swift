import Foundation
import Testing
@testable import PeekCamCore

struct HotKeySpecTests {
    @Test func parsesDefault() throws {
        let m = try #require(HotKeySpec(AppSettings.defaultHotKey))
        #expect(m.keyCode == 46)
        #expect(m.display == "⌃⇧M")
    }

    @Test func rejectsBareKeys() {
        #expect(HotKeySpec("M") == nil)
        #expect(HotKeySpec("") == nil)
    }
}

struct SettingsTests {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("peekcam-tests-\(UUID().uuidString)")
    }

    @Test func firstLoadWritesDefaults() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(AppSettings.load(from: dir) == AppSettings())
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("settings.json").path))
    }

    @Test func roundTrip() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        var s = AppSettings()
        s.mirror = false
        s.size = .large
        s.aspect = .standard
        s.cameraID = "usb-1"
        try s.save(to: dir)
        #expect(AppSettings.load(from: dir) == s)
    }

    @Test func missingAndUnknownValuesUseDefaults() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"size": "huge", "mirror": false}"#.utf8))
        #expect(s.size == .medium)
        #expect(s.aspect == .wide)
        #expect(!s.mirror)
        #expect(s.cameraID == nil)
        #expect(s.hotKey == AppSettings.defaultHotKey)
    }

    @Test func badValuesAreRepaired() {
        var s = AppSettings()
        s.hotKey = "banana"
        s.cameraID = " "
        let v = s.validated()
        #expect(v.hotKey == AppSettings.defaultHotKey)
        #expect(v.cameraID == nil)
    }
}

struct SizePresetTests {
    @Test func heightFollowsAspect() {
        #expect(SizePreset.medium.dimensions(.wide) == (360, 203))
        #expect(SizePreset.medium.dimensions(.standard) == (360, 270))
        #expect(SizePreset.small.dimensions(.wide).width < SizePreset.large.dimensions(.wide).width)
    }
}

struct CameraPickerTests {
    let builtIn = CameraInfo(id: "builtin", name: "FaceTime HD Camera", isBuiltIn: true)
    let usb = CameraInfo(id: "usb", name: "Logitech", isBuiltIn: false)

    @Test func keepsSavedCamera() {
        #expect(CameraPicker.choose(preferred: "usb", from: [builtIn, usb]) == usb)
    }

    @Test func fallsBackToBuiltInWhenSavedCameraIsGone() {
        #expect(CameraPicker.choose(preferred: "iphone", from: [usb, builtIn]) == builtIn)
        #expect(CameraPicker.choose(preferred: nil, from: [usb, builtIn]) == builtIn)
    }

    @Test func fallsBackToFirstOrNothing() {
        #expect(CameraPicker.choose(preferred: nil, from: [usb]) == usb)
        #expect(CameraPicker.choose(preferred: nil, from: []) == nil)
    }
}

struct SnapSettingsTests {
    @Test func defaultsAndRepair() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"saveDirectory": " ", "detachedFrame": [1, 2]}"#.utf8))
        let v = s.validated()
        #expect(v.saveDirectory == "~/Pictures/PeekCam")
        #expect(v.detachedFrame == nil)
        #expect(v.copySnapToClipboard)
        #expect(!v.saveDirectoryURL.path.contains("~"))
    }

    @Test func detachedRectNeedsFourNumbers() {
        var s = AppSettings()
        s.detachedFrame = [10, 20, 300, 169]
        #expect(s.detachedRect == CGRect(x: 10, y: 20, width: 300, height: 169))
    }
}

struct SnapNamerTests {
    let date: Date = {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute, c.second) = (2026, 10, 30, 9, 7, 5)
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    @Test func namesByTime() {
        let name = SnapNamer.fileName(date: date, calendar: Calendar(identifier: .gregorian)) { _ in false }
        #expect(name == "PeekCam 2026-10-30 at 09.07.05.png")
    }

    @Test func addsNumberWhenTaken() {
        let taken: Set = ["PeekCam 2026-10-30 at 09.07.05.png", "PeekCam 2026-10-30 at 09.07.05 (2).png"]
        let name = SnapNamer.fileName(date: date, calendar: Calendar(identifier: .gregorian)) { taken.contains($0) }
        #expect(name == "PeekCam 2026-10-30 at 09.07.05 (3).png")
    }
}

struct WindowPlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)

    @Test func firstTimeGoesTopRight() {
        let f = WindowPlacement.frame(saved: nil, defaultWidth: 360, aspect: .wide, visible: screen)
        #expect(f == CGRect(x: 1060, y: 652, width: 360, height: 203))
    }

    @Test func keepsSavedFrameAndAspect() {
        let saved = CGRect(x: 100, y: 300, width: 400, height: 225)
        #expect(WindowPlacement.frame(saved: saved, defaultWidth: 360, aspect: .wide, visible: screen) == saved)
        let standard = WindowPlacement.frame(saved: saved, defaultWidth: 360, aspect: .standard, visible: screen)
        #expect(standard == CGRect(x: 100, y: 225, width: 400, height: 300))
    }

    @Test func pullsPartlyOffscreenWindowBackAndIgnoresLostScreen() {
        let partly = CGRect(x: 1300, y: 800, width: 400, height: 225)
        #expect(WindowPlacement.frame(saved: partly, defaultWidth: 360, aspect: .wide, visible: screen)
            == CGRect(x: 1040, y: 650, width: 400, height: 225))
        let gone = CGRect(x: 3000, y: 0, width: 400, height: 225)
        #expect(WindowPlacement.frame(saved: gone, defaultWidth: 360, aspect: .wide, visible: screen).maxX == 1420)
    }
}

struct AudioLevelTests {
    @Test func silenceIsZeroAndFullScaleIsOne() {
        #expect(AudioLevel.meter(rms: 0) == 0)
        #expect(AudioLevel.meter(rms: 1) == 1)
    }

    @Test func quietSpeechIsInTheMiddle() {
        // 0.01 amplitude = -40 dBFS, which is the middle of the -80...0 range.
        let level = AudioLevel.meter(rms: 0.01)
        #expect(abs(level - 0.5) < 0.01)
    }

    @Test func clampsOutOfRangeValues() {
        #expect(AudioLevel.meter(rms: 5) == 1)
        #expect(AudioLevel.meter(rms: 1e-9) == 0)
        #expect(AudioLevel.meter(rms: -1) == 0)
    }

    @Test func rmsOfSamples() {
        #expect(AudioLevel.rms(of: []) == 0)
        #expect(abs(AudioLevel.rms(of: [0.5, -0.5, 0.5, -0.5]) - 0.5) < 0.0001)
    }

    @Test func smoothingFallsSlowlyAndRisesFast() {
        #expect(AudioLevel.smoothed(previous: 0.2, new: 0.8) == 0.8)
        #expect(AudioLevel.smoothed(previous: 0.8, new: 0.0) > 0.5)
    }
}

struct LightingFrameTests {
    @Test func insetKeepsAspectAndLeavesAFrame() {
        let bounds = CGRect(x: 0, y: 0, width: 480, height: 270)
        let inner = LightingFrame.cameraRect(in: bounds, thickness: 0.12)
        #expect(inner.midX == bounds.midX && inner.midY == bounds.midY)
        #expect(abs(inner.width / inner.height - 480.0 / 270.0) < 0.01)
        #expect(inner.width < bounds.width)
    }

    @Test func zeroThicknessIsFullBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        #expect(LightingFrame.cameraRect(in: bounds, thickness: 0) == bounds)
    }
}

struct Stage3SettingsTests {
    @Test func defaultsAreOff() {
        let s = AppSettings()
        #expect(!s.lighting && !s.micCheck)
    }

    @Test func roundTripAndOldFilesStillLoad() throws {
        var s = AppSettings()
        s.lighting = true
        s.micCheck = true
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        #expect(decoded == s)
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"mirror": false}"#.utf8))
        #expect(!old.lighting && !old.micCheck)
    }
}

import Foundation

/// File names for snaps: "PeekCam 2026-10-30 at 09.17.05.png", then "… (2).png" when taken
/// within the same second.
public enum SnapNamer {
    public static func fileName(date: Date, calendar: Calendar = .current, exists: (String) -> Bool) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let base = String(format: "PeekCam %04d-%02d-%02d at %02d.%02d.%02d",
                          c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        var name = "\(base).png"
        var n = 2
        while exists(name) {
            name = "\(base) (\(n)).png"
            n += 1
        }
        return name
    }
}

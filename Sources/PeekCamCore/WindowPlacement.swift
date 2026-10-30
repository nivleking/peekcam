import CoreGraphics

/// Where the detached window goes, in screen coordinates (origin bottom left, like AppKit).
public enum WindowPlacement {
    static let margin: CGFloat = 20

    /// The saved frame when it is still on a screen, otherwise the top right corner of `visible`.
    /// The height always follows the aspect ratio, and the window is pulled fully into view.
    public static func frame(saved: CGRect?, defaultWidth: CGFloat, aspect: AspectRatio, visible: CGRect) -> CGRect {
        let width = min(max(saved?.width ?? defaultWidth, 160), visible.width)
        let size = CGSize(width: width, height: (width / aspect.ratio).rounded())
        guard let saved, saved.intersects(visible) else {
            return CGRect(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin,
                          width: size.width, height: size.height)
        }
        let x = min(max(saved.minX, visible.minX), visible.maxX - size.width)
        // Keep the top edge where it was: a changed aspect ratio grows the window downward.
        let y = min(max(saved.maxY - size.height, visible.minY), visible.maxY - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

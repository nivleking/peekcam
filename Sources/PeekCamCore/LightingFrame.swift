import Foundation

/// "Lighting": a bright frame around the picture so the screen works as a face light.
public enum LightingFrame {
    /// Share of each side taken by the frame at the default setting.
    public static let defaultThickness = 0.12

    /// The camera picture, shrunk toward the center with the same aspect ratio.
    public static func cameraRect(in bounds: CGRect, thickness: Double) -> CGRect {
        let scale = 1 - 2 * min(max(thickness, 0), 0.4)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}

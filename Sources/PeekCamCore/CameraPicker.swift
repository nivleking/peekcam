/// A camera as the picker sees it, so the choice can be tested without AVFoundation.
public struct CameraInfo: Equatable {
    public var id: String
    public var name: String
    public var isBuiltIn: Bool

    public init(id: String, name: String, isBuiltIn: Bool) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}

public enum CameraPicker {
    /// The saved camera when it is still connected; otherwise the built-in one, then the first.
    /// An unplugged USB camera or an iPhone out of range must not leave the preview black.
    public static func choose(preferred id: String?, from cameras: [CameraInfo]) -> CameraInfo? {
        if let id, let match = cameras.first(where: { $0.id == id }) { return match }
        return cameras.first(where: \.isBuiltIn) ?? cameras.first
    }
}

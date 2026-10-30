/// Preview width. The height follows from the aspect ratio.
public enum SizePreset: String, Codable, CaseIterable {
    case small, medium, large

    public var width: Double {
        switch self {
        case .small: 240
        case .medium: 360
        case .large: 520
        }
    }

    public var title: String { rawValue.capitalized }

    /// Width and height in points, rounded to whole points so the layer edges stay sharp.
    public func dimensions(_ aspect: AspectRatio) -> (width: Double, height: Double) {
        (width, (width / aspect.ratio).rounded())
    }
}

public enum AspectRatio: String, Codable, CaseIterable {
    /// 16:9, what most webcams and meeting apps send.
    case wide
    /// 4:3, the older FaceTime camera shape.
    case standard

    public var ratio: Double {
        switch self {
        case .wide: 16.0 / 9.0
        case .standard: 4.0 / 3.0
        }
    }

    public var title: String {
        switch self {
        case .wide: "16:9"
        case .standard: "4:3"
        }
    }
}

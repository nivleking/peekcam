import AppKit
import PeekCamCore

/// Turns a camera still into a PNG in the snaps folder and on the clipboard.
enum Snapper {
    /// Returns the saved file, or nil when writing failed.
    static func save(_ image: CGImage, mirrored: Bool, settings: AppSettings) -> URL? {
        let image = mirrored ? flipped(image) ?? image : image
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return nil }
        let folder = settings.saveDirectoryURL
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = SnapNamer.fileName(date: Date()) {
                FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
            }
            let url = folder.appendingPathComponent(name)
            try png.write(to: url, options: .atomic)
            if settings.copySnapToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
                NSPasteboard.general.setData(png, forType: .png)
            }
            return url
        } catch {
            NSLog("PeekCam: could not save snap: \(error)")
            return nil
        }
    }

    /// The snap should look like the preview, so a mirrored preview gives a mirrored photo.
    private static func flipped(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: CGFloat(image.width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}

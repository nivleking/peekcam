// Draws the PeekCam app icon as a 1024x1024 PNG with CoreGraphics only (no Xcode).
// Usage: swift scripts/make-icon.swift [Resources/AppIcon-1024.png]
// make-app.sh turns that PNG into AppIcon.icns with sips + iconutil.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon-1024.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Draw in top-left coordinates (y grows downwards), like most design tools.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r / 255, g / 255, b / 255, a])!
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r), transform: nil)
}

/// Shadows ignore the flipped transform, so a positive `drop` moves them down on screen.
func fill(_ path: CGPath, _ color: CGColor, drop: CGFloat = 0, blur: CGFloat = 0, shadow: CGColor? = nil) {
    ctx.saveGState()
    if let shadow { ctx.setShadow(offset: CGSize(width: 0, height: -drop), blur: blur, color: shadow) }
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

func fillGradient(_ path: CGPath, top: CGColor, bottom: CGColor) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])
    ctx.restoreGState()
}

// Tile: 824 px rounded square on Apple icon grid.
let tile = rounded(100, 100, 824, 824, 185)

fill(tile, rgb(120, 70, 220), drop: 12, blur: 36, shadow: rgb(0, 0, 0, 0.43))
fillGradient(tile, top: rgb(110, 90, 240), bottom: rgb(235, 80, 160))

// A camera lens: white ring, dark glass, and a face seen in it (the "peek").
fill(circle(512, 512, 290), rgb(255, 255, 255), drop: 8, blur: 20, shadow: rgb(40, 10, 80, 0.4))
let glass = circle(512, 512, 238)
fillGradient(glass, top: rgb(70, 50, 140), bottom: rgb(25, 15, 70))
ctx.saveGState()
ctx.addPath(glass)
ctx.clip()
fill(circle(512, 455, 82), rgb(255, 255, 255, 0.92))                                  // head
fill(CGPath(ellipseIn: CGRect(x: 322, y: 570, width: 380, height: 330), transform: nil), rgb(255, 255, 255, 0.92)) // shoulders
ctx.restoreGState()
// Highlight on the glass and the little "recording" light.
fill(circle(420, 360, 34), rgb(255, 255, 255, 0.35))
fill(circle(752, 272, 34), rgb(60, 220, 120), drop: 4, blur: 14, shadow: rgb(0, 80, 40, 0.5))

let url = URL(fileURLWithPath: out)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(out)") }
print("Wrote \(out)")


// Draws the Amend app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift [variant] [out.png]
//   With an out.png, writes only a 1024px preview of the variant.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let variant = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dark"
let previewPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func pill(_ ctx: CGContext, _ r: CGRect, _ color: CGColor) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil))
    ctx.setFillColor(color)
    ctx.fillPath()
}

/// Draws at 1024×1024 points scaled to `size` pixels.
func render(size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // macOS icon grid: 824pt rounded square centered on a 1024pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    let dark = variant == "dark"
    let bgTop = dark ? rgb(0x2B2F4A) : rgb(0xFFFFFF)
    let bgBottom = dark ? rgb(0x15172A) : rgb(0xE9EBF2)
    let ink = dark ? rgb(0xFFFFFF, 0.28) : rgb(0x2B2F4A, 0.16)
    let red = dark ? rgb(0xFF6F6F) : rgb(0xFF6B6B)
    let green = dark ? rgb(0x3DDC97) : rgb(0x2FBF71)

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.28))
    ctx.addPath(tilePath)
    ctx.setFillColor(bgBottom)
    ctx.fillPath()
    ctx.restoreGState()

    // Tile gradient.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [bgTop, bgBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Text lines; the middle one is the "amendment": struck-out red, then green replacement.
    let h: CGFloat = 64
    let left: CGFloat = 238
    pill(ctx, CGRect(x: left, y: 642, width: 548, height: h), ink)

    let del = CGRect(x: left, y: 480, width: 236, height: h)
    pill(ctx, del, red)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.95))
    ctx.setLineWidth(14)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: del.minX + 30, y: del.midY))
    ctx.addLine(to: CGPoint(x: del.maxX - 30, y: del.midY))
    ctx.strokePath()

    pill(ctx, CGRect(x: left + 268, y: 480, width: 280, height: h), green)
    pill(ctx, CGRect(x: left, y: 318, width: 380, height: h), ink)

    // Check badge, bottom right.
    let c = CGPoint(x: 712, y: 312)
    let radius: CGFloat = 104
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: rgb(0x000000, dark ? 0.45 : 0.18))
    ctx.addEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
    ctx.setFillColor(green)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(26)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: c.x - 46, y: c.y + 2))
    ctx.addLine(to: CGPoint(x: c.x - 12, y: c.y - 34))
    ctx.addLine(to: CGPoint(x: c.x + 50, y: c.y + 38))
    ctx.strokePath()

    // Hairline edge for definition on light backgrounds.
    ctx.restoreGState()
    ctx.addPath(tilePath)
    ctx.setStrokeColor(dark ? rgb(0xFFFFFF, 0.08) : rgb(0x000000, 0.06))
    ctx.setLineWidth(2)
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, _ path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

if let previewPath {
    writePNG(render(size: 1024), previewPath)
    exit(0)
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(render(size: base), iconset.appendingPathComponent("icon_\(base)x\(base).png").path)
    writePNG(render(size: base * 2), iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png").path)
}
try! fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")

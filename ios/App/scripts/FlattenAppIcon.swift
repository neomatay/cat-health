import AppKit

let size = 1024
let sourceURL = URL(fileURLWithPath: "CatHealth/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
let outputURL = sourceURL

guard let source = NSImage(contentsOf: sourceURL),
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      ),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to prepare the app icon")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }

NSColor(calibratedRed: 1, green: 0.478, blue: 0.478, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
source.draw(in: NSRect(x: 0, y: 0, width: size, height: size))

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode the app icon")
}
try png.write(to: outputURL)

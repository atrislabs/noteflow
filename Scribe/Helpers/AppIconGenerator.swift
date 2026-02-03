import AppKit

/// Generates app icons programmatically for Scribe
/// Run this once to generate icons, then add them to Assets.xcassets
enum AppIconGenerator {

    /// Generate all required icon sizes
    static func generateIcons(to folder: URL) throws {
        let sizes: [(Int, Int)] = [ // (size, scale)
            (16, 1), (16, 2),
            (32, 1), (32, 2),
            (128, 1), (128, 2),
            (256, 1), (256, 2),
            (512, 1), (512, 2)
        ]

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for (size, scale) in sizes {
            let actualSize = size * scale
            let icon = generateIcon(size: actualSize)
            let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            let url = folder.appendingPathComponent(name)
            try icon.pngData()?.write(to: url)
        }
    }

    /// Generate a single icon at the specified size
    static func generateIcon(size: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.08, dy: CGFloat(size) * 0.08),
                                 xRadius: CGFloat(size) * 0.22,
                                 yRadius: CGFloat(size) * 0.22)

        // Gradient background - blue to purple
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.29, green: 0.49, blue: 0.93, alpha: 1.0),
            NSColor(calibratedRed: 0.58, green: 0.35, blue: 0.87, alpha: 1.0)
        ])
        gradient?.draw(in: path, angle: -45)

        // Draw pencil icon
        let iconSize = CGFloat(size) * 0.5
        let iconX = (CGFloat(size) - iconSize) / 2
        let iconY = (CGFloat(size) - iconSize) / 2

        NSColor.white.setFill()
        NSColor.white.setStroke()

        // Pencil body
        let pencilPath = NSBezierPath()
        let bodyWidth = iconSize * 0.18
        let bodyHeight = iconSize * 0.7

        // Rotated pencil coordinates
        let centerX = iconX + iconSize / 2
        let centerY = iconY + iconSize / 2
        let angle: CGFloat = -.pi / 4 // 45 degrees

        // Transform for rotation
        let transform = NSAffineTransform()
        transform.translateX(by: centerX, yBy: centerY)
        transform.rotate(byRadians: angle)

        // Draw pencil body (rectangle)
        pencilPath.move(to: transform.transform(NSPoint(x: -bodyWidth/2, y: -bodyHeight/2)))
        pencilPath.line(to: transform.transform(NSPoint(x: bodyWidth/2, y: -bodyHeight/2)))
        pencilPath.line(to: transform.transform(NSPoint(x: bodyWidth/2, y: bodyHeight/2)))
        pencilPath.line(to: transform.transform(NSPoint(x: -bodyWidth/2, y: bodyHeight/2)))
        pencilPath.close()
        pencilPath.fill()

        // Pencil tip
        let tipPath = NSBezierPath()
        tipPath.move(to: transform.transform(NSPoint(x: -bodyWidth/2, y: -bodyHeight/2)))
        tipPath.line(to: transform.transform(NSPoint(x: 0, y: -bodyHeight/2 - bodyWidth * 0.8)))
        tipPath.line(to: transform.transform(NSPoint(x: bodyWidth/2, y: -bodyHeight/2)))
        tipPath.close()
        tipPath.fill()

        // Lines representing text (decorative)
        NSColor.white.withAlphaComponent(0.3).setStroke()
        let lineWidth = CGFloat(size) * 0.02
        let lineY1 = centerY + iconSize * 0.15
        let lineY2 = centerY + iconSize * 0.25

        let line1 = NSBezierPath()
        line1.lineWidth = lineWidth
        line1.move(to: NSPoint(x: iconX + iconSize * 0.2, y: lineY1))
        line1.line(to: NSPoint(x: iconX + iconSize * 0.7, y: lineY1))
        line1.stroke()

        let line2 = NSBezierPath()
        line2.lineWidth = lineWidth
        line2.move(to: NSPoint(x: iconX + iconSize * 0.2, y: lineY2))
        line2.line(to: NSPoint(x: iconX + iconSize * 0.5, y: lineY2))
        line2.stroke()

        return image
    }
}

// NSImage.pngData() is defined in MarkdownEditor.swift

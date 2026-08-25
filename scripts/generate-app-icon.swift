import Cocoa
import CoreGraphics
import Foundation

func generateAppIcon() {
    let size = CGSize(width: 1024, height: 1024)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create CGContext")
        return
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // macOS Standard Icon Dimensions (1024x1024 canvas, 824x824 squircle)
    let inset: CGFloat = 100
    let squircleRect = CGRect(x: inset, y: inset, width: size.width - 2 * inset, height: size.height - 2 * inset)
    let cornerRadius: CGFloat = 185

    let squirclePath = CGPath(
        roundedRect: squircleRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    // 1. Realistic Dual-layer Drop Shadow
    // Ambient deep ground shadow
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -36),
        blur: 48,
        color: NSColor.black.withAlphaComponent(0.45).cgColor
    )
    context.addPath(squirclePath)
    context.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).cgColor)
    context.fillPath()
    context.restoreGState()

    // Contact tight shadow
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -14),
        blur: 20,
        color: NSColor.black.withAlphaComponent(0.35).cgColor
    )
    context.addPath(squirclePath)
    context.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).cgColor)
    context.fillPath()
    context.restoreGState()

    // Clip to main squircle
    context.saveGState()
    context.addPath(squirclePath)
    context.clip()

    // 2. Base Background Gradient (Deep Obsidian Slate with subtle navy-indigo warm nuance)
    let baseColors = [
        NSColor(red: 0.18, green: 0.19, blue: 0.25, alpha: 1.0).cgColor,
        NSColor(red: 0.12, green: 0.13, blue: 0.17, alpha: 1.0).cgColor,
        NSColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0).cgColor
    ] as CFArray
    let baseGradient = CGGradient(colorsSpace: colorSpace, colors: baseColors, locations: [0.0, 0.45, 1.0])!
    context.drawLinearGradient(
        baseGradient,
        start: CGPoint(x: 512, y: 1024 - inset),
        end: CGPoint(x: 512, y: inset),
        options: []
    )

    // 3. Warm Ambient Terracotta / Coral Backlight Glow
    let glowColors = [
        NSColor(red: 0.95, green: 0.46, blue: 0.28, alpha: 0.40).cgColor,
        NSColor(red: 0.90, green: 0.38, blue: 0.20, alpha: 0.18).cgColor,
        NSColor(red: 0.85, green: 0.30, blue: 0.15, alpha: 0.0).cgColor
    ] as CFArray
    let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.5, 1.0])!
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: 512, y: 580),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 580),
        endRadius: 460,
        options: []
    )

    // 4. Subtle Concentric Decorative Orbits (Reflecting AI & Connectivity)
    context.saveGState()
    context.setLineWidth(1.0)
    for r in [280.0, 360.0] as [CGFloat] {
        let orbitPath = CGPath(ellipseIn: CGRect(x: 512 - r, y: 580 - r, width: r * 2, height: r * 2), transform: nil)
        context.addPath(orbitPath)
        context.setStrokeColor(NSColor(red: 0.95, green: 0.50, blue: 0.35, alpha: 0.07).cgColor)
        context.strokePath()
    }
    context.restoreGState()

    // 5. Center Identity Card Plate (Glassmorphism & Matte Metallic Finish)
    let cardRect = CGRect(x: 236, y: 226, width: 552, height: 572)
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 64, cornerHeight: 64, transform: nil)

    // Card Drop Shadow
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -18),
        blur: 32,
        color: NSColor.black.withAlphaComponent(0.55).cgColor
    )
    context.addPath(cardPath)
    context.setFillColor(NSColor(red: 0.14, green: 0.15, blue: 0.20, alpha: 0.98).cgColor)
    context.fillPath()
    context.restoreGState()

    // Card Surface Gradient
    context.saveGState()
    context.addPath(cardPath)
    context.clip()

    let cardFillColors = [
        NSColor(red: 0.24, green: 0.26, blue: 0.34, alpha: 0.95).cgColor,
        NSColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 0.96).cgColor,
        NSColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 0.98).cgColor
    ] as CFArray
    let cardFillGradient = CGGradient(colorsSpace: colorSpace, colors: cardFillColors, locations: [0.0, 0.45, 1.0])!
    context.drawLinearGradient(
        cardFillGradient,
        start: CGPoint(x: 512, y: cardRect.maxY),
        end: CGPoint(x: 512, y: cardRect.minY),
        options: []
    )

    // Card Inner Top Highlight
    context.setLineWidth(2.0)
    context.setStrokeColor(NSColor(white: 1.0, alpha: 0.22).cgColor)
    context.addPath(cardPath)
    context.strokePath()
    context.restoreGState()

    // 6. Iconic Claude Star (8-pointed Anthropic Organic Spark)
    let starCenter = CGPoint(x: 512, y: 555)
    let starOuterRadius: CGFloat = 138
    let starInnerRadius: CGFloat = 46

    // Star Ambient Bloom
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -6),
        blur: 24,
        color: NSColor(red: 0.96, green: 0.48, blue: 0.30, alpha: 0.75).cgColor
    )

    let starPath = CGMutablePath()
    let starPoints = 8
    for i in 0..<(starPoints * 2) {
        let angle = CGFloat(i) * .pi / CGFloat(starPoints) - .pi / 2
        let radius = (i % 2 == 0) ? starOuterRadius : starInnerRadius
        let px = starCenter.x + radius * cos(angle)
        let py = starCenter.y + radius * sin(angle)
        if i == 0 {
            starPath.move(to: CGPoint(x: px, y: py))
        } else {
            starPath.addLine(to: CGPoint(x: px, y: py))
        }
    }
    starPath.closeSubpath()

    context.addPath(starPath)
    context.clip()

    // Multi-stop Radiant Sunset / Terracotta Gradient
    let starGradientColors = [
        NSColor(red: 1.00, green: 0.65, blue: 0.48, alpha: 1.0).cgColor,
        NSColor(red: 0.96, green: 0.48, blue: 0.30, alpha: 1.0).cgColor,
        NSColor(red: 0.86, green: 0.30, blue: 0.16, alpha: 1.0).cgColor,
        NSColor(red: 0.70, green: 0.18, blue: 0.08, alpha: 1.0).cgColor
    ] as CFArray
    let starGradient = CGGradient(colorsSpace: colorSpace, colors: starGradientColors, locations: [0.0, 0.35, 0.75, 1.0])!
    context.drawLinearGradient(
        starGradient,
        start: CGPoint(x: 512, y: starCenter.y + starOuterRadius),
        end: CGPoint(x: 512, y: starCenter.y - starOuterRadius),
        options: []
    )
    context.restoreGState()

    // Star Inner Chamfer & Specular Highlight
    context.saveGState()
    context.addPath(starPath)
    context.setLineWidth(2.0)
    context.setStrokeColor(NSColor(white: 1.0, alpha: 0.45).cgColor)
    context.strokePath()
    context.restoreGState()

    // 7. Security & Multi-Account Badge (Bottom Pill with Key & Status Jewel)
    let badgeCenter = CGPoint(x: 512, y: 312)
    let badgeWidth: CGFloat = 200
    let badgeHeight: CGFloat = 48
    let badgeRect = CGRect(x: badgeCenter.x - badgeWidth/2, y: badgeCenter.y - badgeHeight/2, width: badgeWidth, height: badgeHeight)
    let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: badgeHeight/2, cornerHeight: badgeHeight/2, transform: nil)

    context.saveGState()
    // Badge Background
    context.addPath(badgePath)
    context.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 0.88).cgColor)
    context.fillPath()

    // Badge Stroke with Gold/Amber Accent
    context.setLineWidth(1.5)
    context.setStrokeColor(NSColor(red: 0.95, green: 0.55, blue: 0.35, alpha: 0.45).cgColor)
    context.addPath(badgePath)
    context.strokePath()

    // Status Indicator Dot (Left - Emerald Active Jewel)
    let jewelCenter = CGPoint(x: badgeCenter.x - 62, y: badgeCenter.y)
    let jewelPath = CGPath(ellipseIn: CGRect(x: jewelCenter.x - 6, y: jewelCenter.y - 6, width: 12, height: 12), transform: nil)
    context.saveGState()
    context.setShadow(offset: .zero, blur: 8, color: NSColor(red: 0.20, green: 0.85, blue: 0.55, alpha: 0.9).cgColor)
    context.addPath(jewelPath)
    context.setFillColor(NSColor(red: 0.25, green: 0.90, blue: 0.60, alpha: 1.0).cgColor)
    context.fillPath()
    context.restoreGState()

    // Center Key / Security Shield Icon
    // Draw miniature keyhole / lock glyph
    let keyCenter = CGPoint(x: badgeCenter.x, y: badgeCenter.y)
    let keyHeadPath = CGPath(ellipseIn: CGRect(x: keyCenter.x - 7, y: keyCenter.y - 1, width: 14, height: 14), transform: nil)
    let keyShaftPath = CGMutablePath()
    keyShaftPath.move(to: CGPoint(x: keyCenter.x, y: keyCenter.y - 1))
    keyShaftPath.addLine(to: CGPoint(x: keyCenter.x, y: keyCenter.y - 10))
    keyShaftPath.addLine(to: CGPoint(x: keyCenter.x + 5, y: keyCenter.y - 10))
    keyShaftPath.move(to: CGPoint(x: keyCenter.x, y: keyCenter.y - 6))
    keyShaftPath.addLine(to: CGPoint(x: keyCenter.x + 4, y: keyCenter.y - 6))

    context.saveGState()
    context.setLineWidth(2.2)
    context.setLineCap(.round)
    context.setStrokeColor(NSColor(red: 0.98, green: 0.70, blue: 0.50, alpha: 0.95).cgColor)
    context.addPath(keyHeadPath)
    context.strokePath()
    context.addPath(keyShaftPath)
    context.strokePath()
    context.restoreGState()

    // Multi-account Indicator Dot (Right - Teal Sync Jewel)
    let rightDotCenter = CGPoint(x: badgeCenter.x + 62, y: badgeCenter.y)
    let rightDotPath = CGPath(ellipseIn: CGRect(x: rightDotCenter.x - 5, y: rightDotCenter.y - 5, width: 10, height: 10), transform: nil)
    context.saveGState()
    context.setShadow(offset: .zero, blur: 6, color: NSColor(red: 0.30, green: 0.75, blue: 0.95, alpha: 0.7).cgColor)
    context.addPath(rightDotPath)
    context.setFillColor(NSColor(red: 0.35, green: 0.80, blue: 0.98, alpha: 0.9).cgColor)
    context.fillPath()
    context.restoreGState()

    context.restoreGState()

    // 8. Outer Squircle Top Rim Specular Lighting (Apple Signature Craft)
    context.saveGState()
    context.addPath(squirclePath)
    context.setLineWidth(2.5)
    let rimColors = [
        NSColor(white: 1.0, alpha: 0.42).cgColor,
        NSColor(white: 1.0, alpha: 0.08).cgColor,
        NSColor(white: 1.0, alpha: 0.00).cgColor
    ] as CFArray
    let rimGradient = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.4, 1.0])!
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
        rimGradient,
        start: CGPoint(x: 512, y: 1024 - inset),
        end: CGPoint(x: 512, y: 720),
        options: []
    )
    context.restoreGState()

    context.restoreGState() // Unclip squircle

    // 9. Render and Export Master PNG & Iconset
    guard let cgImage = context.makeImage() else {
        print("Failed to create CGImage from context")
        return
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }

    let fileManager = FileManager.default
    let iconsetURL = URL(fileURLWithPath: "Resources/AppIcon.iconset")
    try? fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

    let masterURL = URL(fileURLWithPath: "Resources/AppIcon_1024.png")
    try? pngData.write(to: masterURL)

    let sizes: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    let nsImage = NSImage(cgImage: cgImage, size: size)
    for (filename, targetPixelSize) in sizes {
        let targetSize = CGSize(width: targetPixelSize, height: targetPixelSize)
        let resizedRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetPixelSize,
            pixelsHigh: targetPixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        resizedRep.size = targetSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resizedRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        nsImage.draw(in: CGRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        if let png = resizedRep.representation(using: .png, properties: [:]) {
            let fileURL = iconsetURL.appendingPathComponent(filename)
            try? png.write(to: fileURL)
        }
    }
    print("Generated all iconset files in Resources/AppIcon.iconset")

    // Compile into AppIcon.icns
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", "Resources/AppIcon.iconset", "-o", "Resources/AppIcon.icns"]
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            print("Successfully compiled Resources/AppIcon.icns")
        } else {
            print("iconutil failed with code \(process.terminationStatus)")
        }
    } catch {
        print("Failed to run iconutil: \(error.localizedDescription)")
    }
}

generateAppIcon()

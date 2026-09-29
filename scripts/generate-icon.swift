import AppKit

func renderIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    
    let ctx = NSGraphicsContext.current?.cgContext
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    
    // macOS App Icon standard padding & squircle corner radius
    let margin = size * 0.08
    let iconRect = bounds.insetBy(dx: margin, dy: margin)
    let cornerRadius = iconRect.width * 0.2237
    let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    // Background Dark Gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        NSColor(srgbRed: 0.08, green: 0.10, blue: 0.15, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.03, green: 0.04, blue: 0.07, alpha: 1.0).cgColor
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0.0, 1.0]) {
        ctx?.saveGState()
        squirclePath.addClip()
        ctx?.drawLinearGradient(
            gradient,
            start: CGPoint(x: iconRect.midX, y: iconRect.maxY),
            end: CGPoint(x: iconRect.midX, y: iconRect.minY),
            options: []
        )
        ctx?.restoreGState()
    }
    
    // Subtle border glow
    squirclePath.lineWidth = size * 0.015
    NSColor(srgbRed: 0.2, green: 0.7, blue: 0.9, alpha: 0.4).setStroke()
    squirclePath.stroke()
    
    // Draw Sound Waves & Central Speaker Cone
    ctx?.saveGState()
    squirclePath.addClip()
    
    let centerX = iconRect.midX
    let centerY = iconRect.midY
    
    // Radial glow behind speaker
    let glowColors = [
        NSColor(srgbRed: 0.0, green: 0.8, blue: 0.9, alpha: 0.25).cgColor,
        NSColor(srgbRed: 0.0, green: 0.5, blue: 0.8, alpha: 0.0).cgColor
    ] as CFArray
    if let radGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx?.drawRadialGradient(
            radGrad,
            startCenter: CGPoint(x: centerX, y: centerY),
            startRadius: 0,
            endCenter: CGPoint(x: centerX, y: centerY),
            endRadius: size * 0.4,
            options: []
        )
    }
    
    // Concentric EQ / Sound wave rings
    let waveColors: [NSColor] = [
        NSColor(srgbRed: 0.0, green: 0.85, blue: 0.95, alpha: 0.9), // Cyan
        NSColor(srgbRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.7),  // Blue
        NSColor(srgbRed: 0.5, green: 0.3, blue: 0.95, alpha: 0.5)  // Purple
    ]
    
    let radii: [CGFloat] = [size * 0.18, size * 0.26, size * 0.34]
    for (i, r) in radii.enumerated() {
        let arcPath = NSBezierPath()
        arcPath.appendArc(
            withCenter: NSPoint(x: centerX - size * 0.05, y: centerY),
            radius: r,
            startAngle: -55,
            endAngle: 55,
            clockwise: false
        )
        arcPath.lineWidth = size * 0.03
        arcPath.lineCapStyle = .round
        waveColors[i].setStroke()
        arcPath.stroke()
    }
    
    // Main Speaker Icon in center-left
    let speakerConfig = NSImage.SymbolConfiguration(pointSize: size * 0.32, weight: .semibold)
    if let speakerImage = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: nil)?.withSymbolConfiguration(speakerConfig) {
        let imageRect = CGRect(
            x: centerX - size * 0.22,
            y: centerY - size * 0.16,
            width: size * 0.44,
            height: size * 0.32
        )
        
        // Draw glow
        ctx?.setShadow(offset: .zero, blur: size * 0.05, color: NSColor.cyan.cgColor)
        speakerImage.draw(in: NSRect(origin: imageRect.origin, size: imageRect.size))
    }
    
    // Protective Shield Badge in lower right
    let shieldSize = size * 0.22
    let shieldRect = NSRect(
        x: iconRect.maxX - shieldSize - size * 0.04,
        y: iconRect.minY + size * 0.04,
        width: shieldSize,
        height: shieldSize
    )
    
    let shieldBg = NSBezierPath(ovalIn: shieldRect)
    NSColor(srgbRed: 0.05, green: 0.15, blue: 0.12, alpha: 0.9).setFill()
    shieldBg.fill()
    shieldBg.lineWidth = size * 0.012
    NSColor.green.setStroke()
    shieldBg.stroke()
    
    let checkConfig = NSImage.SymbolConfiguration(pointSize: shieldSize * 0.55, weight: .bold)
    if let checkImg = NSImage(systemSymbolName: "checkmark.shield.fill", accessibilityDescription: nil)?.withSymbolConfiguration(checkConfig) {
        let chkRect = NSRect(
            x: shieldRect.midX - shieldSize * 0.28,
            y: shieldRect.midY - shieldSize * 0.28,
            width: shieldSize * 0.56,
            height: shieldSize * 0.56
        )
        checkImg.draw(in: chkRect)
    }
    
    ctx?.restoreGState()
    img.unlockFocus()
    return img
}

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let resDir = "\(root)/Resources"
let docsDir = "\(root)/docs"
let iconsetDir = "\(resDir)/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: resDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: docsDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// Generate Master 1024x1024 AppIcon.png
let masterImg = renderIcon(size: 1024)
if let tiff = masterImg.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "\(resDir)/AppIcon.png"))
    try? png.write(to: URL(fileURLWithPath: "\(docsDir)/logo.png"))
    print("Rendered 1024x1024 AppIcon.png and docs/logo.png")
}

// Generate iconset resolutions for iconutil -> AppIcon.icns
let iconSizes: [(String, CGFloat)] = [
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

for (fileName, px) in iconSizes {
    let icon = renderIcon(size: px)
    if let tiff = icon.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(fileName)"))
    }
}

// Run iconutil to produce AppIcon.icns
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", "\(resDir)/AppIcon.icns"]
try? task.run()
task.waitUntilExit()

// Cleanup iconset directory
try? FileManager.default.removeItem(atPath: iconsetDir)

print("Generated \(resDir)/AppIcon.icns successfully.")

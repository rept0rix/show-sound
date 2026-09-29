import AppKit

let width = 800.0
let height = 460.0
let size = NSSize(width: width, height: height)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("could not make a bitmap\n", stderr)
    exit(1)
}
rep.size = size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Theme Colors
let bg = NSColor(srgbRed: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
let cyan = NSColor(srgbRed: 0.15, green: 0.78, blue: 0.85, alpha: 1.0)
let textMain = NSColor(srgbRed: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
let textMuted = NSColor(srgbRed: 0.55, green: 0.58, blue: 0.65, alpha: 1.0)
let cardBg = NSColor(srgbRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0)

bg.setFill()
NSRect(origin: .zero, size: size).fill()

func drawText(_ text: String, font: NSFont, color: NSColor, rect: NSRect, align: NSTextAlignment) {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]).draw(in: rect)
}

// Header
drawText(
    "INSTALL SHOW SOUND",
    font: .systemFont(ofSize: 12, weight: .bold),
    color: cyan,
    rect: NSRect(x: 48, y: height - 52, width: 400, height: 18),
    align: .left
)
drawText(
    "Pure Sound. Zero Distortion.",
    font: .systemFont(ofSize: 34, weight: .bold),
    color: textMain,
    rect: NSRect(x: 48, y: height - 98, width: 550, height: 42),
    align: .left
)
drawText(
    "Drag Show Sound into Applications to start managing system audio.",
    font: .systemFont(ofSize: 14, weight: .regular),
    color: textMuted,
    rect: NSRect(x: 48, y: height - 128, width: 600, height: 24),
    align: .left
)

// Decorative Icon Pods
let appTarget = NSRect(x: 136, y: 150, width: 128, height: 128)
let arrow = NSRect(x: 370, y: 200, width: 60, height: 28)
let appFolderTarget = NSRect(x: 536, y: 150, width: 128, height: 128)

// Subtle Card Backgrounds
let path1 = NSBezierPath(roundedRect: NSRect(x: 120, y: 120, width: 160, height: 170), xRadius: 16, yRadius: 16)
cardBg.setFill()
path1.fill()

let path2 = NSBezierPath(roundedRect: NSRect(x: 520, y: 120, width: 160, height: 170), xRadius: 16, yRadius: 16)
cardBg.setFill()
path2.fill()

// Drag Arrow
drawText(
    "➔",
    font: .systemFont(ofSize: 32, weight: .bold),
    color: cyan,
    rect: arrow,
    align: .center
)

// Footer
drawText(
    "Show Sound · GainGuard DSP & Hardware Protection · Naor Yanko",
    font: .systemFont(ofSize: 11, weight: .medium),
    color: textMuted,
    rect: NSRect(x: 48, y: 24, width: 704, height: 16),
    align: .center
)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("could not encode png\n", stderr)
    exit(1)
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
try data.write(to: URL(fileURLWithPath: outPath))

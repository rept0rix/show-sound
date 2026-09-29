import AppKit

func createBitmap(width: CGFloat, height: CGFloat) -> (NSBitmapImageRep, CGContext)? {
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
    ) else { return nil }
    
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
    return (rep, ctx)
}

func savePNG(rep: NSBitmapImageRep, path: String) {
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    }
}

// 1. Render docs/hero.png (3200 x 2000)
if let (rep, ctx) = createBitmap(width: 3200, height: 2000) {
    let bounds = CGRect(x: 0, y: 0, width: 3200, height: 2000)
    
    // Deep Studio Gradient Background
    let cs = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(srgbRed: 0.05, green: 0.07, blue: 0.12, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.02, green: 0.03, blue: 0.05, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 1600, y: 2000), end: CGPoint(x: 1600, y: 0), options: [])
    }
    
    // Background Glow Orbs
    let cyanGlow = [NSColor(srgbRed: 0.0, green: 0.8, blue: 0.95, alpha: 0.22).cgColor, NSColor.clear.cgColor] as CFArray
    if let g1 = CGGradient(colorsSpace: cs, colors: cyanGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g1, startCenter: CGPoint(x: 800, y: 1400), startRadius: 0, endCenter: CGPoint(x: 800, y: 1400), endRadius: 900, options: [])
    }
    let violetGlow = [NSColor(srgbRed: 0.5, green: 0.2, blue: 0.9, alpha: 0.18).cgColor, NSColor.clear.cgColor] as CFArray
    if let g2 = CGGradient(colorsSpace: cs, colors: violetGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g2, startCenter: CGPoint(x: 2400, y: 800), startRadius: 0, endCenter: CGPoint(x: 2400, y: 800), endRadius: 1000, options: [])
    }
    
    // Title & Tagline
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 110, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: p
    ]
    NSAttributedString(string: "Show Sound", attributes: titleAttr)
        .draw(in: CGRect(x: 400, y: 1650, width: 2400, height: 140))
        
    let subAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 46, weight: .medium),
        .foregroundColor: NSColor(srgbRed: 0.2, green: 0.85, blue: 0.95, alpha: 1.0),
        .paragraphStyle: p
    ]
    NSAttributedString(string: "The Safe 600% Audio Booster & Per-App Mixer for Mac", attributes: subAttr)
        .draw(in: CGRect(x: 400, y: 1530, width: 2400, height: 80))
        
    // Central UI Card Mockup
    let cardRect = CGRect(x: 950, y: 220, width: 1300, height: 1220)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 40, yRadius: 40)
    
    // Card Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 80, color: NSColor.black.withAlphaComponent(0.7).cgColor)
    NSColor(srgbRed: 0.10, green: 0.12, blue: 0.16, alpha: 0.95).setFill()
    cardPath.fill()
    ctx.restoreGState()
    
    cardPath.lineWidth = 4
    NSColor(srgbRed: 0.25, green: 0.35, blue: 0.5, alpha: 0.4).setStroke()
    cardPath.stroke()
    
    // Inside UI Card
    let headerStyle = NSMutableParagraphStyle()
    headerStyle.alignment = .left
    NSAttributedString(string: "Master SafeBoost", attributes: [
        .font: NSFont.systemFont(ofSize: 42, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: headerStyle
    ]).draw(in: CGRect(x: 1040, y: 1300, width: 600, height: 60))
    
    let pctStyle = NSMutableParagraphStyle()
    pctStyle.alignment = .right
    NSAttributedString(string: "350%", attributes: [
        .font: NSFont.systemFont(ofSize: 64, weight: .black),
        .foregroundColor: NSColor(srgbRed: 0.1, green: 0.85, blue: 0.95, alpha: 1.0),
        .paragraphStyle: pctStyle
    ]).draw(in: CGRect(x: 1750, y: 1290, width: 400, height: 80))
    
    // Slider Track
    let trackRect = CGRect(x: 1040, y: 1240, width: 1120, height: 24)
    let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 12, yRadius: 12)
    NSColor(white: 0.2, alpha: 1.0).setFill()
    trackPath.fill()
    
    let fillRect = CGRect(x: 1040, y: 1240, width: 672, height: 24)
    let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 12, yRadius: 12)
    NSColor(srgbRed: 0.1, green: 0.85, blue: 0.95, alpha: 1.0).setFill()
    fillPath.fill()
    
    // Thumb Knob
    let thumb = CGRect(x: 1690, y: 1226, width: 52, height: 52)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: thumb).fill()
    
    // Equalizer Section in Hero
    NSAttributedString(string: "10-Band Hardware Equalizer", attributes: [
        .font: NSFont.systemFont(ofSize: 36, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: headerStyle
    ]).draw(in: CGRect(x: 1040, y: 1120, width: 800, height: 50))
    
    let eqFrequencies = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    let eqHeights: [CGFloat] = [140, 220, 180, 120, 90, 160, 240, 200, 170, 130]
    let pCenter = NSMutableParagraphStyle()
    pCenter.alignment = .center
    
    for (i, freq) in eqFrequencies.enumerated() {
        let x = 1060 + CGFloat(i) * 108
        let barBg = CGRect(x: x + 34, y: 720, width: 12, height: 320)
        NSColor(white: 0.18, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: barBg, xRadius: 6, yRadius: 6).fill()
        
        let h = eqHeights[i]
        let barFill = CGRect(x: x + 34, y: 720, width: 12, height: h)
        let col = NSColor(srgbRed: 0.15 + CGFloat(i) * 0.05, green: 0.75, blue: 0.95, alpha: 1.0)
        col.setFill()
        NSBezierPath(roundedRect: barFill, xRadius: 6, yRadius: 6).fill()
        
        // Knob
        let kRect = CGRect(x: x + 24, y: 710 + h, width: 32, height: 18)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: kRect, xRadius: 5, yRadius: 5).fill()
        
        NSAttributedString(string: freq, attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor(white: 0.6, alpha: 1.0),
            .paragraphStyle: pCenter
        ]).draw(in: CGRect(x: x, y: 660, width: 80, height: 36))
    }
    
    // Per-App Cards Row
    let appNames = ["Spotify", "Google Chrome", "WhatsApp Call", "Zoom Meeting"]
    let appVols = ["100%", "135%", "90% (Left)", "110% (Right)"]
    let appColors = [
        NSColor(srgbRed: 0.12, green: 0.84, blue: 0.38, alpha: 1.0),
        NSColor(srgbRed: 0.95, green: 0.7, blue: 0.1, alpha: 1.0),
        NSColor(srgbRed: 0.15, green: 0.8, blue: 0.4, alpha: 1.0),
        NSColor(srgbRed: 0.2, green: 0.55, blue: 0.95, alpha: 1.0)
    ]
    
    for (i, name) in appNames.enumerated() {
        let appCardRect = CGRect(x: 1040, y: 280 + CGFloat(3 - i) * 85, width: 1120, height: 70)
        let aPath = NSBezierPath(roundedRect: appCardRect, xRadius: 14, yRadius: 14)
        NSColor(white: 0.15, alpha: 0.8).setFill()
        aPath.fill()
        
        let dot = CGRect(x: 1064, y: 305 + CGFloat(3 - i) * 85, width: 20, height: 20)
        appColors[i].setFill()
        NSBezierPath(ovalIn: dot).fill()
        
        NSAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: headerStyle
        ]).draw(in: CGRect(x: 1105, y: 298 + CGFloat(3 - i) * 85, width: 400, height: 40))
        
        NSAttributedString(string: appVols[i], attributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor(white: 0.8, alpha: 1.0),
            .paragraphStyle: pctStyle
        ]).draw(in: CGRect(x: 1800, y: 298 + CGFloat(3 - i) * 85, width: 320, height: 40))
    }
    
    savePNG(rep: rep, path: "\(CommandLine.arguments[1])/docs/hero.png")
}

// 2. Render docs/features.png (3200 x 840)
if let (rep, ctx) = createBitmap(width: 3200, height: 840) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(srgbRed: 0.07, green: 0.09, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.03, green: 0.04, blue: 0.07, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 1600, y: 840), end: CGPoint(x: 1600, y: 0), options: [])
    }
    
    let features = [
        ("🛡️ GainGuard DSP", "55Hz Sub-Bass HPF + True-Peak Limiter (-0.3 dBFS). 100% protection against speaker blowout and digital square-wave distortion."),
        ("🎚️ Per-App Audio Mixer", "Independent volume & L/R panning for every Mac app. Listen to podcasts in your left ear and calls in your right ear."),
        ("🎙️ Call Music Injection", "Stream background music straight into Zoom/WhatsApp call mics. Auto-Ducking drops music by -18dB when you talk."),
        ("🎛️ 10-Band Graphic EQ", "Studio-grade parametric biquad equalizer with acoustic presets and intelligent background noise gate isolation.")
    ]
    
    let pLeft = NSMutableParagraphStyle()
    pLeft.alignment = .left
    
    for (i, feat) in features.enumerated() {
        let x = 120 + CGFloat(i) * 750
        let fRect = CGRect(x: x, y: 80, width: 700, height: 680)
        let fPath = NSBezierPath(roundedRect: fRect, xRadius: 24, yRadius: 24)
        NSColor(white: 0.12, alpha: 0.9).setFill()
        fPath.fill()
        fPath.lineWidth = 2
        NSColor(white: 0.22, alpha: 0.6).setStroke()
        fPath.stroke()
        
        NSAttributedString(string: feat.0, attributes: [
            .font: NSFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: NSColor(srgbRed: 0.15, green: 0.85, blue: 0.95, alpha: 1.0),
            .paragraphStyle: pLeft
        ]).draw(in: CGRect(x: x + 40, y: 640, width: 620, height: 60))
        
        NSAttributedString(string: feat.1, attributes: [
            .font: NSFont.systemFont(ofSize: 28, weight: .regular),
            .foregroundColor: NSColor(white: 0.85, alpha: 1.0),
            .paragraphStyle: pLeft
        ]).draw(in: CGRect(x: x + 40, y: 160, width: 620, height: 440))
    }
    
    savePNG(rep: rep, path: "\(CommandLine.arguments[1])/docs/features.png")
}

// 3. Render docs/product.png (3200 x 1800)
if let (rep, ctx) = createBitmap(width: 3200, height: 1800) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(srgbRed: 0.04, green: 0.06, blue: 0.10, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.02, green: 0.03, blue: 0.05, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 1600, y: 1800), end: CGPoint(x: 1600, y: 0), options: [])
    }
    
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    NSAttributedString(string: "The macOS Menu Bar Sound Engine", attributes: [
        .font: NSFont.systemFont(ofSize: 72, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: p
    ]).draw(in: CGRect(x: 400, y: 1560, width: 2400, height: 100))
    
    NSAttributedString(string: "Seamlessly floating in your menu bar. 0ms latency. Pure Swift & CoreAudio.", attributes: [
        .font: NSFont.systemFont(ofSize: 36, weight: .medium),
        .foregroundColor: NSColor(srgbRed: 0.2, green: 0.85, blue: 0.95, alpha: 1.0),
        .paragraphStyle: p
    ]).draw(in: CGRect(x: 400, y: 1470, width: 2400, height: 60))
    
    // Draw 3 Feature Panels (SafeBoost, 10-Band EQ, Call Injection)
    let titles = ["1. Master SafeBoost & VU", "2. Studio 10-Band EQ", "3. Voice Auto-Ducking"]
    let descs = [
        "Up to 600% volume with live dual-channel VU meters and true-peak protection.",
        "Precision ISO octave-band sliders with presets for Movies, Vocals & Night Mode.",
        "Inject music into calls with real-time RMS speech detection and -18dB ducking."
    ]
    let colors = [NSColor.cyan, NSColor(srgbRed: 0.4, green: 0.8, blue: 1.0, alpha: 1.0), NSColor(srgbRed: 0.2, green: 0.9, blue: 0.5, alpha: 1.0)]
    
    for i in 0..<3 {
        let x = 200 + CGFloat(i) * 960
        let pRect = CGRect(x: x, y: 300, width: 880, height: 1050)
        let pPath = NSBezierPath(roundedRect: pRect, xRadius: 32, yRadius: 32)
        NSColor(white: 0.11, alpha: 0.95).setFill()
        pPath.fill()
        pPath.lineWidth = 3
        colors[i].withAlphaComponent(0.4).setStroke()
        pPath.stroke()
        
        let pLeft = NSMutableParagraphStyle()
        pLeft.alignment = .left
        NSAttributedString(string: titles[i], attributes: [
            .font: NSFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: colors[i],
            .paragraphStyle: pLeft
        ]).draw(in: CGRect(x: x + 50, y: 1220, width: 780, height: 60))
        
        NSAttributedString(string: descs[i], attributes: [
            .font: NSFont.systemFont(ofSize: 28, weight: .regular),
            .foregroundColor: NSColor(white: 0.8, alpha: 1.0),
            .paragraphStyle: pLeft
        ]).draw(in: CGRect(x: x + 50, y: 1040, width: 780, height: 160))
    }
    
    savePNG(rep: rep, path: "\(CommandLine.arguments[1])/docs/product.png")
}

print("Rendered docs graphics successfully.")

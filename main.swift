import Cocoa
import WebKit
import QuartzCore

func notchPath(_ rect: CGRect, radius: CGFloat = 28) -> CGPath {
    let r = min(radius, rect.height / 2)
    let p = CGMutablePath()
    p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r))
    p.addCurve(to: CGPoint(x: rect.maxX-r, y: rect.minY), control1: CGPoint(x: rect.maxX, y: rect.minY+r * 0.447715), control2: CGPoint(x: rect.maxX-r * 0.447715, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.minX+r, y: rect.minY))
    p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY+r), control1: CGPoint(x: rect.minX+r * 0.447715, y: rect.minY), control2: CGPoint(x: rect.minX, y: rect.minY+r * 0.447715))
    p.closeSubpath()
    return p
}

// Open U-shaped path: no stroke crosses the top edge.
func sideRimPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let r = min(radius, rect.height / 2)
    let k: CGFloat = 0.447715
    let p = CGMutablePath()
    p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
    p.addCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.minY + r*k), control2: CGPoint(x: rect.minX+r*k, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX-r, y: rect.minY))
    p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY+r), control1: CGPoint(x: rect.maxX-r*k, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY+r*k))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    return p
}

func hoverZone(frame: CGRect, safeTop: CGFloat, left: CGRect?, right: CGRect?) -> CGRect {
    let low = left?.maxX ?? (frame.midX - 90)
    let high = right?.minX ?? (frame.midX + 90)
    let width = max(180, high - low)
    let center = (low + high) / 2
    let depth = max(32, safeTop) + 8
    return CGRect(x: center - width / 2 - 14, y: frame.maxY - depth, width: width + 28, height: depth + 2)
}
struct HoverGate {
    var since: TimeInterval?
    mutating func reset() { since = nil }
    mutating func ready(inside: Bool, time: TimeInterval) -> Bool {
        guard inside else { reset(); return false }
        if since == nil { since = time }
        return time - since! >= 0.18
    }
}

final class NotchSurface: NSView {
    var lightTheme = false
    var auroraEnabled = true
    var phraseVisible = true
    var symbolOnly = false
    var phrases = ["保持好奇", "灵感浮现", "THINK · CREATE"]
    private let auroraGroup = CALayer()
    private let auroraBlobs = (0..<5).map { _ in CAGradientLayer() }
    private let glyphLayer = CATextLayer()
    private let nextGlyphLayer = CATextLayer()
    private var nextGlyphActive = false
    private let bottomLight = CAGradientLayer()
    private let signalBar = CALayer()
    private var glyphTimer: Timer?
    private var glyphStep = 0

    private let rim = CALayer()
    private let glowGroup = CALayer()
    private let glowMask = CAGradientLayer()
    var webpageTop: CGFloat = 410
    private let leftSpill = CAGradientLayer()
    private let rightSpill = CAGradientLayer()
    private let bottomSpill = CAGradientLayer()
    private let brightCore = CAShapeLayer()
    private let flowMasks = (0..<3).map { _ in CAGradientLayer() }
    private var cachedSize = CGSize.zero
    private var breathing = false
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        let color = lightTheme ? NSColor(calibratedRed: 0.975, green: 0.978, blue: 0.985, alpha: 1) : NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.16, alpha: 1)
        ctx.setFillColor(color.cgColor); ctx.fill(bounds)
    }
    override func layout() {
        super.layout()
        guard cachedSize != bounds.size else { return }
        cachedSize = bounds.size
        updateRim()
    }
    func updateRim() {
        guard let layer else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        if rim.superlayer == nil {
            layer.addSublayer(rim)
            rim.addSublayer(glowGroup)
            for spill in [leftSpill, rightSpill, bottomSpill] { glowGroup.addSublayer(spill) }
            rim.addSublayer(auroraGroup)
            auroraGroup.addSublayer(bottomLight)
            for blob in auroraBlobs { auroraGroup.addSublayer(blob) }
            rim.addSublayer(glyphLayer)
            rim.addSublayer(nextGlyphLayer)
            rim.addSublayer(signalBar)
            glyphLayer.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
            glyphLayer.fontSize = 9
            glyphLayer.alignmentMode = .center
            glyphLayer.contentsScale = window?.backingScaleFactor ?? 2
            rim.addSublayer(brightCore)
            glowGroup.mask = glowMask
        }
        rim.frame = bounds
        rim.zPosition = 10
        glowGroup.frame = bounds
        let top = min(bounds.height, max(60, webpageTop))
        glowMask.frame = CGRect(x: 0, y: 0, width: bounds.width, height: top)
        glowMask.startPoint = CGPoint(x: 0.5, y: 0)
        glowMask.endPoint = CGPoint(x: 0.5, y: 1)
        glowMask.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor, NSColor.clear.cgColor]
        glowMask.locations = [0, NSNumber(value: Double(max(0.05, 1 - 110 / top))), NSNumber(value: Double(max(0.1, 1 - 24 / top))), 1]
        let spillColor = lightTheme
            ? NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.95, alpha: 0.56)
            : NSColor(calibratedRed: 0.035, green: 0.48, blue: 1, alpha: 0.94)
        for spill in [leftSpill, rightSpill, bottomSpill] {
            spill.colors = [spillColor.cgColor, spillColor.withAlphaComponent(lightTheme ? 0.17 : 0.48).cgColor, NSColor.clear.cgColor]
            spill.locations = [0, lightTheme ? 0.36 : 0.46, 1]
        }
        let spillWidth: CGFloat = lightTheme ? 32 : 44
        leftSpill.frame = CGRect(x: 0, y: 0, width: spillWidth, height: top)
        leftSpill.startPoint = CGPoint(x: 0, y: 0.5); leftSpill.endPoint = CGPoint(x: 1, y: 0.5)
        rightSpill.frame = CGRect(x: bounds.width - spillWidth, y: 0, width: spillWidth, height: top)
        rightSpill.startPoint = CGPoint(x: 1, y: 0.5); rightSpill.endPoint = CGPoint(x: 0, y: 0.5)
        bottomSpill.frame = CGRect(x: 0, y: 0, width: bounds.width, height: spillWidth)
        bottomSpill.startPoint = CGPoint(x: 0.5, y: 0); bottomSpill.endPoint = CGPoint(x: 0.5, y: 1)
        // Vary light along each edge without distorting the window outline.
        for (index, spill) in [leftSpill, rightSpill, bottomSpill].enumerated() {
            let mask = flowMasks[index]
            mask.frame = spill.bounds
            mask.startPoint = CGPoint(x: 0, y: 0)
            mask.endPoint = index == 2 ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 1)
            mask.locations = [0, 0.22, 0.48, 0.73, 1]
            mask.colors = [0.8, 0.38, 1.0, 0.48, 0.85].map { NSColor.black.withAlphaComponent($0).cgColor }
            spill.mask = lightTheme ? nil : mask
        }
        // One visible stroke; the separate gradient layers provide only soft light.
        brightCore.frame = bounds
        brightCore.path = sideRimPath(CGRect(x: 1.9, y: 1.9, width: bounds.width - 3.8, height: bounds.height - 1.9), radius: 26.1)
        brightCore.fillColor = nil
        brightCore.lineCap = .butt
        brightCore.lineJoin = .round
        brightCore.lineWidth = 1.0
        brightCore.strokeColor = (lightTheme ? NSColor(calibratedRed: 0.60, green: 0.70, blue: 0.82, alpha: 0.90) : NSColor(calibratedRed: 0.20, green: 0.72, blue: 1, alpha: 1)).cgColor
        brightCore.isHidden = auroraEnabled
        glowGroup.isHidden = auroraEnabled
        auroraGroup.isHidden = true // B light is drawn outside by ExteriorFrame.
        glyphLayer.isHidden = !auroraEnabled || !phraseVisible || symbolOnly
        signalBar.isHidden = !auroraEnabled || !phraseVisible || !symbolOnly
        auroraGroup.frame = bounds
        bottomLight.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 20)
        bottomLight.startPoint = CGPoint(x: 0.5, y: 0)
        bottomLight.endPoint = CGPoint(x: 0.5, y: 1)
        bottomLight.colors = [NSColor(calibratedRed: 0.16, green: 0.64, blue: 1, alpha: 0.78).cgColor,
                              NSColor(calibratedRed: 0.30, green: 0.94, blue: 1, alpha: 0.98).cgColor,
                              NSColor(calibratedRed: 0.04, green: 0.60, blue: 1, alpha: 0.45).cgColor,
                              NSColor.clear.cgColor]
        bottomLight.locations = [0, 0.20, 0.46, 1]
        let palette: [NSColor] = [
            NSColor(calibratedRed: 0.05, green: 0.38, blue: 0.95, alpha: 1),
            NSColor(calibratedRed: 0.04, green: 0.72, blue: 0.90, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.30, blue: 0.85, alpha: 1),
            NSColor(calibratedRed: 0.08, green: 0.43, blue: 0.85, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.82, alpha: 1)
        ]
        let frames = [
            CGRect(x: -bounds.width * 0.30, y: -116, width: bounds.width * 1.60, height: 190),
            CGRect(x: -bounds.width * 0.13, y: -100, width: bounds.width * 1.15, height: 164),
            CGRect(x: bounds.width * 0.25, y: -110, width: bounds.width, height: 166),
            CGRect(x: -83, y: top * 0.03, width: 105, height: top * 0.90),
            CGRect(x: bounds.width - 23, y: top * 0.02, width: 105, height: top * 0.90)
        ]
        for (index, blob) in auroraBlobs.enumerated() {
            blob.isHidden = index >= 3
            blob.frame = frames[index]
            blob.type = .radial
            blob.startPoint = CGPoint(x: 0.5, y: 0.5)
            blob.endPoint = CGPoint(x: 1, y: 1)
            let color = palette[index]
            blob.colors = [color.withAlphaComponent(lightTheme ? 0.26 : (index == 1 ? 0.82 : 0.52)).cgColor,
                           color.withAlphaComponent(lightTheme ? 0.10 : (index == 1 ? 0.34 : 0.20)).cgColor,
                           color.withAlphaComponent(0).cgColor]
            blob.locations = [0, 0.36, 1]
        }
        glyphLayer.bounds = CGRect(x: 0, y: 0, width: 260, height: 13)
        glyphLayer.position = CGPoint(x: bounds.width - 14, y: top * 0.57)
        glyphLayer.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 2))
        glyphLayer.foregroundColor = (lightTheme ? NSColor(calibratedRed: 0.32, green: 0.36, blue: 0.53, alpha: 0.85) : NSColor(calibratedRed: 0.67, green: 0.74, blue: 0.98, alpha: 0.85)).cgColor
        for label in [glyphLayer, nextGlyphLayer] {
            label.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            label.fontSize = 10
            label.alignmentMode = .center
            label.contentsScale = window?.backingScaleFactor ?? 2
            label.bounds = glyphLayer.bounds
            label.position = glyphLayer.position
            label.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 2))
            label.foregroundColor = glyphLayer.foregroundColor
            label.isHidden = !auroraEnabled || !phraseVisible || symbolOnly
        }
        let active = nextGlyphActive ? nextGlyphLayer : glyphLayer
        active.string = phrases.isEmpty ? "" : phrases[glyphStep % phrases.count]
        active.opacity = 1
        (nextGlyphActive ? glyphLayer : nextGlyphLayer).opacity = 0
        signalBar.frame = CGRect(x: bounds.width - 15, y: top * 0.57 - 11, width: 2, height: 22)
        signalBar.cornerRadius = 1
        signalBar.backgroundColor = glyphLayer.foregroundColor
        signalBar.shadowColor = NSColor.systemCyan.cgColor
        signalBar.shadowRadius = 4
        signalBar.shadowOpacity = lightTheme ? 0 : 0.5
        signalBar.shadowOffset = .zero
        if auroraEnabled {
            brightCore.strokeColor = (lightTheme ? NSColor(calibratedRed: 0.62, green: 0.65, blue: 0.83, alpha: 0.80) : NSColor(calibratedRed: 0.46, green: 0.55, blue: 1, alpha: 0.86)).cgColor
        }
        CATransaction.commit()
    }
    private func startAurora() {
        guard phraseVisible else { return }
        if symbolOnly {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.35; pulse.toValue = 1
            pulse.duration = 1.8; pulse.autoreverses = true; pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            signalBar.add(pulse, forKey: "signalPulse")
            return
        }
        guard phrases.count > 1 else { return }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.advanceGlyphs() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        glyphTimer = timer
    }
    private func advanceGlyphs() {
        guard phrases.count > 1 else { return }
        glyphStep = (glyphStep + 1) % phrases.count
        let outgoing = nextGlyphActive ? nextGlyphLayer : glyphLayer
        let incoming = nextGlyphActive ? glyphLayer : nextGlyphLayer
        CATransaction.begin(); CATransaction.setDisableActions(true)
        incoming.string = phrases[glyphStep]
        incoming.opacity = 1
        outgoing.opacity = 0
        CATransaction.commit()
        for (label, entering) in [(incoming, true), (outgoing, false)] {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = entering ? 0 : 1
            fade.toValue = entering ? 1 : 0
            let slide = CABasicAnimation(keyPath: "position.y")
            slide.fromValue = label.position.y + (entering ? 5 : 0)
            slide.toValue = label.position.y - (entering ? 0 : 5)
            let transition = CAAnimationGroup()
            transition.animations = [fade, slide]
            transition.duration = 0.95
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            label.add(transition, forKey: "smoothPhrase")
        }
        nextGlyphActive.toggle()
    }
    func startBreathing() {
        updateRim()
        guard !breathing else { return }
        breathing = true
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            brightCore.opacity = 0.85; glowGroup.opacity = 0.65; return
        }
        if auroraEnabled {
            brightCore.opacity = 1
            startAurora()
            return
        }
        func pulse(_ target: CALayer, low: Float, duration: CFTimeInterval) {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = low; animation.toValue = 1.0
            animation.duration = duration; animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            target.add(animation, forKey: "breathing")
        }
        brightCore.opacity = 1
        glowGroup.opacity = 1
        if lightTheme {
            pulse(glowGroup, low: 0.22, duration: 1.05)
        } else {
            for (index, spill) in [leftSpill, rightSpill, bottomSpill].enumerated() {
                let rhythm = CAKeyframeAnimation(keyPath: "opacity")
                rhythm.values = [0.52, 0.92, 0.66, 1.0, 0.52]
                rhythm.keyTimes = [0, 0.19, 0.46, 0.72, 1]
                rhythm.duration = [3.0, 3.9, 3.4][index]
                rhythm.calculationMode = .cubic
                rhythm.repeatCount = .infinity
                spill.add(rhythm, forKey: "flowPulse")
                let spread = CAKeyframeAnimation(keyPath: "locations")
                spread.values = [[0, 0.29, 0.78], [0, 0.53, 1], [0, 0.37, 0.88], [0, 0.29, 0.78]]
                spread.duration = [4.4, 5.2, 3.8][index]
                spread.calculationMode = .linear
                spread.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                spread.repeatCount = .infinity
                spill.add(spread, forKey: "flowSpread")
                let drift = CABasicAnimation(keyPath: "colors")
                drift.fromValue = flowMasks[index].colors
                drift.toValue = [0.4, 0.95, 0.5, 1.0, 0.55].map { NSColor.black.withAlphaComponent($0).cgColor }
                drift.duration = [1.9, 2.4, 2.2][index]
                drift.autoreverses = true
                drift.repeatCount = .infinity
                drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                flowMasks[index].add(drift, forKey: "flowDrift")
            }
        }
    }
    func stopBreathing() {
        glyphTimer?.invalidate(); glyphTimer = nil
        glyphLayer.removeAllAnimations()
        nextGlyphLayer.removeAllAnimations()
        bottomLight.removeAllAnimations()
        signalBar.removeAllAnimations()
        for blob in auroraBlobs { blob.removeAllAnimations() }
        brightCore.removeAnimation(forKey: "breathing")
        glowGroup.removeAnimation(forKey: "breathing")
        for spill in [leftSpill, rightSpill, bottomSpill] { spill.removeAllAnimations() }
        for mask in flowMasks { mask.removeAllAnimations() }
        breathing = false
    }

}

// Transparent space around the clipped chat surface carries the exterior effects.
final class ExteriorFrame: NSView {
    let depthLayer = CAShapeLayer()
    let light = CALayer()
    let halo = CALayer()
    private var glowCache: [String: CGImage] = [:]
    private func glowImage(size: CGSize, scale: CGFloat, wide: Bool) -> CGImage? {
        let w = max(1, Int(ceil(size.width * scale)))
        let h = max(1, Int(ceil(size.height * scale)))
        let key = "\(w)x\(h)-\(wide)"
        if let image = glowCache[key] { return image }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let rgb: [Double] = wide ? [0.025, 0.57, 1] : [0.10, 0.85, 1]
        func falloff(_ v: Double) -> Double {
            max(0, (exp(-5.5 * v * v) - exp(-5.5)) / (1 - exp(-5.5)))
        }
        for y in 0..<h {
            let ny = (Double(y) + 0.5) / Double(h) * 2 - 1
            let vertical = falloff(ny)
            for x in 0..<w {
                let nx = (Double(x) + 0.5) / Double(w) * 2 - 1
                let horizontal = falloff(nx * nx)
                let alpha = vertical * horizontal * (wide ? 0.78 : 0.90)
                // Sub-pixel alpha dithering softens 8-bit bands without visible grain.
                let hash = (UInt32(x) &* 374761393) ^ (UInt32(y) &* 668265263)
                let random = Double((hash ^ (hash >> 13)) & 1023) / 1023 - 0.5
                let a = max(0, min(255, Int((alpha * 255 + random).rounded())))
                let offset = (y * w + x) * 4
                for c in 0..<3 { pixels[offset+c] = UInt8((Double(a) * rgb[c]).rounded()) }
                pixels[offset+3] = UInt8(a)
            }
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        if glowCache.count > 6 { glowCache.removeAll() }
        glowCache[key] = image
        return image
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        glowCache.removeAll()
        for item in [halo, light] where item.bounds.width > 0 {
            let scale = window?.backingScaleFactor ?? 2
            item.contentsScale = scale
            item.contents = glowImage(size: item.bounds.size, scale: scale, wide: item === halo)
        }
    }
    override var isOpaque: Bool { false }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for item: CALayer in [depthLayer, halo, light] {
            item.zPosition = -1
            layer?.addSublayer(item)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(surface: CGRect, enabled: Bool, lightTheme: Bool, animate: Bool) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for item: CALayer in [depthLayer, halo, light] { item.frame = bounds; item.isHidden = !enabled }
        let shape = notchPath(surface)
        depthLayer.path = shape
        depthLayer.fillColor = NSColor.black.cgColor
        depthLayer.shadowPath = shape
        depthLayer.shadowColor = NSColor.black.cgColor
        depthLayer.shadowOpacity = lightTheme ? 0.20 : 0.48
        depthLayer.shadowRadius = 16
        depthLayer.shadowOffset = CGSize(width: 0, height: -5)
        let scale = window?.backingScaleFactor ?? 2
        depthLayer.contentsScale = scale
        for (item, wide) in [(halo, true), (light, false)] {
            let width = surface.width * (wide ? 1.10 : 0.94)
            let height: CGFloat = wide ? 78 : 38
            item.frame = CGRect(x: surface.midX - width / 2, y: surface.minY - height / 2 - 6, width: width, height: height)
            item.contentsScale = scale
            item.contents = glowImage(size: item.bounds.size, scale: scale, wide: wide)
            item.contentsGravity = .resize
        }
        CATransaction.commit()
        for item in [halo, light] {
            if enabled && animate && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                if item.animation(forKey: "exteriorBreath") == nil {
                    let pulse = CABasicAnimation(keyPath: "opacity")
                    pulse.fromValue = item === halo ? 0.20 : 0.12
                    pulse.toValue = 1
                    pulse.duration = 1.25; pulse.autoreverses = true; pulse.repeatCount = .infinity
                    pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    item.add(pulse, forKey: "exteriorBreath")

                }
            } else { item.removeAllAnimations() }
        }
    }
}

final class ChatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var panel: ChatPanel!
    var status: NSStatusItem!
    var container = NSView()
    var address = NSTextField(labelWithString: "")
    var picker = NSPopUpButton()
    var lightTheme = UserDefaults.standard.bool(forKey: "lightTheme")
    var themeButton: NSButton!
    var themeMenuItems: [NSMenuItem] = []
    var toolbarButtons: [NSButton] = []
    var effectMenuItems: [NSMenuItem] = []
    var auroraEnabled = UserDefaults.standard.object(forKey: "auroraEnabled") as? Bool ?? true
    var contentTrailing: NSLayoutConstraint!
    var contentBottom: NSLayoutConstraint!
    var phraseVisible = UserDefaults.standard.object(forKey: "phraseVisible") as? Bool ?? true
    var symbolOnly = UserDefaults.standard.bool(forKey: "symbolOnly")
    var customPhrases = UserDefaults.standard.stringArray(forKey: "customPhrases") ?? ["保持好奇", "灵感浮现", "THINK · CREATE"]
    var pin = NSButton(checkboxWithTitle: "固定", target: nil, action: nil)
    let sites = [("ChatGPT", "https://chatgpt.com/"), ("DeepSeek", "https://chat.deepseek.com/"), ("Gemini", "https://gemini.google.com/")]
    var views: [Int: WKWebView] = [:]
    var current: WKWebView { views[picker.indexOfSelectedItem]! }
    var hoverGate = HoverGate()
    var leaveStart: Date?
    var timer: Timer?
    var keyMonitor: Any?
    var clickMonitor: Any?
    var engaged = false
    let surface = NotchSurface()
    let exterior = ExteriorFrame(frame: .zero)
    var largeReading = false
    var popups: [NSWindow] = []
    var activeScreen: NSScreen?
    var toolbarTop: NSLayoutConstraint!
    var outsideMonitor: Any?
    var suppressUntil = Date.distantPast
    let revealMask = CAShapeLayer()
    var transitionID = 0
    var transitioningUntil = Date.distantPast
    var revealedAt = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        panel = ChatPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 660), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let root = surface
        root.appearance = NSAppearance(named: .darkAqua)
        root.wantsLayer = true
        root.layer?.mask = revealMask
        panel.contentView = exterior
        exterior.addSubview(root)
        root.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: exterior.leadingAnchor, constant: 36),
            root.trailingAnchor.constraint(equalTo: exterior.trailingAnchor, constant: -36),
            root.topAnchor.constraint(equalTo: exterior.topAnchor),
            root.bottomAnchor.constraint(equalTo: exterior.bottomAnchor, constant: -64)
        ])
        picker.addItems(withTitles: sites.map { $0.0 })
        picker.isBordered = false
        picker.font = .systemFont(ofSize: 13, weight: .medium)
        picker.target = self
        picker.action = #selector(switchSite)
        let previous = UserDefaults.standard.integer(forKey: "provider")
        picker.selectItem(at: sites.indices.contains(previous) ? previous : 0)
        func icon(_ name: String, _ label: String, _ action: Selector) -> NSButton {
            let button = NSButton(image: NSImage(systemSymbolName: name, accessibilityDescription: label)!, target: self, action: action)
            button.isBordered = false
            button.contentTintColor = .lightGray
            button.toolTip = label
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 26).isActive = true
            toolbarButtons.append(button)
            return button
        }
        themeButton = icon("sun.max", "切换主题：午夜蓝 / 银瓷白", #selector(toggleTheme))
        let back = icon("chevron.left", "后退", #selector(goBack))
        let home = icon("bubble.left", "回到聊天（退出图片或文件页面）", #selector(returnToChat))
        let refresh = icon("arrow.clockwise", "刷新网页", #selector(reload))
        let browser = icon("safari", "在浏览器中打开（登录状态独立）", #selector(openBrowser))
        let hide = icon("chevron.up", "收起 · Esc", #selector(hidePanel))
        let size = icon("arrow.up.left.and.arrow.down.right", "切换大阅读区域", #selector(toggleSize))
        pin = icon("pin", "固定窗口", #selector(togglePin))
        pin.setButtonType(.toggle)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [picker, spacer, themeButton, back, home, refresh, pin, size, browser, hide])
        toolbar.spacing = 8
        address.font = .systemFont(ofSize: 11)
        address.textColor = .secondaryLabelColor
        address.lineBreakMode = .byTruncatingMiddle
        for view in [toolbar, address, container] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        toolbarTop = toolbar.topAnchor.constraint(equalTo: root.topAnchor, constant: 40)
        contentTrailing = container.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: auroraEnabled && phraseVisible ? -26 : -4.5)
        contentBottom = container.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -4.5)
        NSLayoutConstraint.activate([
            toolbarTop,
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            address.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 2),
            address.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 23),
            address.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -23),
            container.topAnchor.constraint(equalTo: address.bottomAnchor, constant: 6),
            contentBottom,
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 4.5),
            contentTrailing
        ])
        container.wantsLayer = true
        container.layer?.cornerRadius = 25
        container.layer?.masksToBounds = true
        switchSite()
        applyTheme()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            self.engaged = true
            if event.keyCode == 53 { self.hidePanel(); return nil }
            return event
        }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let self, event.window === self.panel { self.engaged = true }
            return event
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.pin.state != .on, self.panel.attachedSheet == nil, !self.popups.contains(where: { $0.isVisible }) else { return }
            self.hidePanel()
        }
        let hoverTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(hoverTimer, forMode: .common)
        timer = hoverTimer
        showPanel()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }
    func buildMenu() {
        let appMenu = NSMenu()
        let edit = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (title, action, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            submenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        edit.submenu = submenu
        appMenu.addItem(edit)
        NSApp.mainMenu = appMenu
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "聊"
        let menu = NSMenu()
        menu.addItem(withTitle: "展开聊天", action: #selector(expandChat), keyEquivalent: "").target = self
        menu.addItem(withTitle: "收起", action: #selector(hidePanel), keyEquivalent: "").target = self
        menu.addItem(.separator())
        for (index, title) in ["午夜蓝 · 电光呼吸", "银瓷白 · 银蓝呼吸"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.tag = index; item.target = self
            themeMenuItems.append(item); menu.addItem(item)
        }
        menu.addItem(.separator())
        for (index, title) in ["经典蓝光", "底部光幕 · B"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(selectEffect(_:)), keyEquivalent: "")
            item.tag = index; item.target = self
            item.state = (index == (auroraEnabled ? 1 : 0)) ? .on : .off
            effectMenuItems.append(item); menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "自定义侧边文字…", action: #selector(editPhrases), keyEquivalent: "").target = self
        menu.addItem(withTitle: "退出刘海聊天", action: #selector(quit), keyEquivalent: "q").target = self
        status.menu = menu
    }

    @objc func switchSite() {
        let index = picker.indexOfSelectedItem
        UserDefaults.standard.set(index, forKey: "provider")
        container.subviews.forEach { $0.removeFromSuperview() }
        if views[index] == nil {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            config.userContentController.addUserScript(WKUserScript(source: themeScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            let view = WKWebView(frame: .zero, configuration: config)
            view.navigationDelegate = self
            view.uiDelegate = self
            view.allowsBackForwardNavigationGestures = true
            views[index] = view
            view.load(URLRequest(url: URL(string: sites[index].1)!, timeoutInterval: 40))
        }
        let view = current
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
        view.underPageBackgroundColor = themeBackground
        applyWebTheme(view)
        address.stringValue = view.url?.host ?? sites[index].1
    }

    var themeBackground: NSColor {
        lightTheme ? NSColor(calibratedRed: 0.975, green: 0.978, blue: 0.985, alpha: 1) : NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.16, alpha: 1)
    }
    private var lastThemeSwitch = Date.distantPast
    @objc func toggleTheme() {
        guard Date().timeIntervalSince(lastThemeSwitch) > 0.4 else { return }
        lastThemeSwitch = Date()
        engaged = true
        lightTheme.toggle(); applyTheme()
    }
    @objc func selectTheme(_ sender: NSMenuItem) { lightTheme = sender.tag == 1; applyTheme() }
    @objc func editPhrases() {
        showPanel()
        engaged = true
        let alert = NSAlert()
        alert.messageText = "自定义侧边文字"
        alert.informativeText = "每行一句，最多 6 句，每句最多 24 个字符。多句每 5 秒柔和滑动切换；一句则固定显示。可选仅显示柔和呼吸的细光条。用于底部光幕模式。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let enabled = NSButton(checkboxWithTitle: "显示侧边文字", target: nil, action: nil)
        enabled.state = phraseVisible ? .on : .off
        let minimal = NSButton(checkboxWithTitle: "极简：只显示呼吸光条", target: nil, action: nil)
        minimal.state = symbolOnly ? .on : .off
        let input = NSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 110))
        input.isRichText = false
        input.font = .systemFont(ofSize: 13)
        input.string = customPhrases.joined(separator: "\n")
        let scroll = NSScrollView(frame: input.frame)
        scroll.documentView = input
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let stack = NSStackView(views: [enabled, minimal, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: 175)
        scroll.widthAnchor.constraint(equalToConstant: 320).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
        alert.accessoryView = stack
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else { return }
            let lines = input.string.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            self.customPhrases = Array(lines.prefix(6)).map { String($0.prefix(24)) }
            self.symbolOnly = minimal.state == .on
            self.phraseVisible = enabled.state == .on && (self.symbolOnly || !self.customPhrases.isEmpty)
            UserDefaults.standard.set(self.symbolOnly, forKey: "symbolOnly")
            UserDefaults.standard.set(self.customPhrases, forKey: "customPhrases")
            UserDefaults.standard.set(self.phraseVisible, forKey: "phraseVisible")
            self.surface.stopBreathing()
            self.applyTheme()
            self.contentTrailing.constant = self.auroraEnabled && self.phraseVisible ? -26 : -4.5
        }
    }
    @objc func selectEffect(_ sender: NSMenuItem) {
        auroraEnabled = sender.tag == 1
        UserDefaults.standard.set(auroraEnabled, forKey: "auroraEnabled")
        surface.stopBreathing()
        surface.auroraEnabled = auroraEnabled
        contentTrailing.constant = auroraEnabled && phraseVisible ? -26 : -4.5
        contentBottom.constant = -4.5
        surface.layoutSubtreeIfNeeded()
        surface.updateRim()
        if panel.isVisible { surface.startBreathing() }
        refreshExterior()
        for item in effectMenuItems { item.state = item.tag == sender.tag ? .on : .off }
    }
    func applyTheme() {
        surface.auroraEnabled = auroraEnabled
        surface.phraseVisible = phraseVisible
        surface.phrases = customPhrases
        surface.symbolOnly = symbolOnly
        UserDefaults.standard.set(lightTheme, forKey: "lightTheme")
        surface.lightTheme = lightTheme
        surface.appearance = NSAppearance(named: lightTheme ? .aqua : .darkAqua)
        surface.needsDisplay = true
        surface.updateRim()
        if panel.isVisible { surface.stopBreathing(); surface.startBreathing() }
        refreshExterior()
        for button in toolbarButtons { button.contentTintColor = lightTheme ? .darkGray : NSColor(calibratedRed: 0.74, green: 0.84, blue: 1, alpha: 1) }
        pin.contentTintColor = pin.state == .on ? .systemBlue : (lightTheme ? .darkGray : .lightGray)
        themeButton.image = NSImage(systemSymbolName: lightTheme ? "moon.stars" : "sun.max", accessibilityDescription: lightTheme ? "切换到午夜蓝" : "切换到银瓷白")
        for item in themeMenuItems { item.state = (item.tag == (lightTheme ? 1 : 0)) ? .on : .off }
        for view in views.values {
            view.appearance = surface.appearance
            view.underPageBackgroundColor = themeBackground
            view.configuration.userContentController.removeAllUserScripts()
            view.configuration.userContentController.addUserScript(WKUserScript(source: themeScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            applyWebTheme(view)
        }
    }
    func applyWebTheme(_ view: WKWebView) {
        view.evaluateJavaScript(themeScript(), completionHandler: nil)
    }
    func themeScript() -> String {
        let mode = lightTheme ? "light" : "dark"
        let primary = lightTheme ? "#f8f9fb" : "#091329"
        let secondary = lightTheme ? "#eceff3" : "#152a48"
        let tertiary = lightTheme ? "#dfe5ed" : "#203b60"
        let text = lightTheme ? "#262c35" : "#e4efff"
        let muted = lightTheme ? "#68707c" : "#9db3d1"
        let edge = lightTheme ? "rgba(104,116,136,.20)" : "rgba(125,184,255,.24)"
        let css = """
        :root, html.light, html.dark { color-scheme: \(mode) !important;
          --bg-primary: \(primary) !important; --bg-secondary: \(secondary) !important; --bg-tertiary: \(tertiary) !important;
          --main-surface-primary: \(primary) !important; --main-surface-secondary: \(secondary) !important; --main-surface-tertiary: \(tertiary) !important;
          --message-surface: \(secondary) !important; --text-primary: \(text) !important; --text-secondary: \(muted) !important;
          --border-light: \(edge) !important; --border-medium: \(edge) !important;
          --bg-elevated-primary: \(secondary) !important; --bg-elevated-secondary: \(tertiary) !important;
        }
        html, body { background: \(primary) !important; color: \(text) !important; }
        main, #main { background-color: transparent !important; }
        [class~="bg-token-bg-primary"], [class~="bg-token-main-surface-primary"] { background-color: \(primary) !important; }
        [role="menu"], [role="listbox"], [role="dialog"] {
          background: \(secondary) !important;
          color: \(text) !important;
          border-color: \(edge) !important;
          box-shadow: 0 8px 28px rgba(0,0,0,.24) !important;
        }
        [class~="bg-token-bg-secondary"], [class~="bg-token-main-surface-secondary"], [class~="bg-token-message-surface"] {
            background: linear-gradient(135deg, \(secondary), \(primary)) !important;
            border-color: \(edge) !important;
        }
        [role="tablist"] { border: 1px solid \(edge) !important; border-radius: 22px; }
        [role="tab"][aria-selected="true"], [role="radio"][aria-checked="true"] {
          background: \(tertiary) !important; box-shadow: inset 0 1px 0 \(edge), 0 0 12px \(edge);
        }
        #composer-background { background: \(secondary) !important; border: 1px solid \(edge) !important; }
        #prompt-textarea { color: \(text) !important; }
        """
        let data = try! JSONSerialization.data(withJSONObject: ["css": css, "mode": mode])
        let json = String(data: data, encoding: .utf8)!
        return """
        (() => {
          if (!['chatgpt.com','chat.deepseek.com','gemini.google.com'].includes(location.hostname)) return;
          const cfg = \(json);
          window.__notchThemeConfig = cfg;
          function apply() {
            const c = window.__notchThemeConfig, r = document.documentElement;
            if (!r) return;
            r.classList.toggle('dark', c.mode === 'dark'); r.classList.toggle('light', c.mode === 'light');
            let el = document.getElementById('notch-chat-theme');
            if (!el) { el = document.createElement('style'); el.id = 'notch-chat-theme'; (document.head || r).appendChild(el); }
            if (el.textContent !== c.css) el.textContent = c.css;
          }
          if (window.__notchThemeObserver) window.__notchThemeObserver.disconnect();
          if (window.__notchSurfaceObserver) window.__notchSurfaceObserver.disconnect();
          if (window.__notchSurfaceTimer) clearTimeout(window.__notchSurfaceTimer);
          apply();
          // No DOM-wide color scans or mutation observers; CSS handles dynamic content.

        })();
        """
    }

    func screenAtMouse() -> NSScreen? {
        NSScreen.screens.first {
            let p = NSEvent.mouseLocation, f = $0.frame
            return p.x >= f.minX && p.x <= f.maxX && p.y >= f.minY && p.y <= f.maxY + 1
        } ?? NSScreen.main
    }
    func positionPanel() {
        guard let screen = activeScreen ?? screenAtMouse() else { return }
        let width = min(540.0, screen.frame.width - 24)
        let inset = max(26, screen.safeAreaInsets.top)
        let height = min(largeReading ? 720.0 : 500.0, screen.visibleFrame.height - 20)
        toolbarTop.constant = inset + 7
        panel.setFrame(NSRect(x: screen.frame.midX - width / 2 - 36, y: screen.frame.maxY - height - 64, width: width + 72, height: height + 64), display: true)
        exterior.layoutSubtreeIfNeeded()
        surface.layoutSubtreeIfNeeded()
        surface.webpageTop = container.frame.maxY
        surface.updateRim()
        refreshExterior()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        revealMask.frame = surface.bounds
        revealMask.path = notchPath(surface.bounds)
        CATransaction.commit()
    }
    func refreshExterior() {
        exterior.update(surface: surface.frame, enabled: auroraEnabled, lightTheme: lightTheme, animate: panel.isVisible)
    }
    func animateReveal(opening: Bool) {
        exterior.update(surface: surface.frame, enabled: auroraEnabled, lightTheme: lightTheme, animate: opening)
        for item: CALayer in [exterior.depthLayer, exterior.halo, exterior.light] {
            item.opacity = opening ? 1 : 0
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = opening ? 0 : 1; fade.toValue = opening ? 1 : 0
            fade.duration = opening ? 0.30 : 0.20
            item.add(fade, forKey: "revealFade")
        }
        transitionID += 1
        let identifier = transitionID
        let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : (opening ? 0.30 : 0.20)
        transitioningUntil = Date().addingTimeInterval(duration)
        let full = notchPath(surface.bounds)
        let small = notchPath(CGRect(x: 0, y: surface.bounds.height - 32, width: surface.bounds.width, height: 32))
        let previous = revealMask.presentation()?.path
        revealMask.removeAllAnimations()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        revealMask.path = opening ? full : small
        CATransaction.commit()
        if duration > 0 {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = previous ?? (opening ? small : full)
            animation.toValue = opening ? full : small
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.8, 0.25, 1)
            revealMask.add(animation, forKey: "reveal")
        }
        if !opening {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self, self.transitionID == identifier else { return }
                self.panel.orderOut(nil)
                self.surface.stopBreathing()
                self.revealMask.path = full
            }
        }
    }
    @objc func showPanel() {
        guard !panel.isVisible else { return }
        activeScreen = screenAtMouse()
        engaged = false
        positionPanel()
        revealedAt = Date()
        panel.orderFrontRegardless()
        surface.startBreathing()
        animateReveal(opening: true)
        leaveStart = nil
    }
    @objc func expandChat() {
        showPanel()
        engaged = true
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(current)
    }
    @objc func hidePanel() {
        guard panel.isVisible, Date() >= transitioningUntil else { return }
        engaged = false
        hoverGate.reset()
        leaveStart = nil
        suppressUntil = Date().addingTimeInterval(0.8)
        animateReveal(opening: false)
    }
    func tick() {
        let now = Date()
        guard now > suppressUntil, now >= transitioningUntil, let screen = screenAtMouse() else { return }
        let point = NSEvent.mouseLocation
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea
        let hot = hoverZone(frame: screen.frame, safeTop: screen.safeAreaInsets.top, left: left, right: right)
        if hot.contains(point) {
            leaveStart = nil
            if !panel.isVisible {
                if hoverGate.ready(inside: true, time: now.timeIntervalSinceReferenceDate) { showPanel() }
            }
        } else {
            hoverGate.reset()
            if panel.isVisible && !panel.frame.insetBy(dx: -10, dy: -10).contains(point) && pin.state != .on && !engaged && NSApp.modalWindow == nil && !popups.contains(where: { $0.isVisible }) {
                if leaveStart == nil { leaveStart = now }
                if now.timeIntervalSince(leaveStart!) >= 0.8 { hidePanel() }
            } else { leaveStart = nil }
        }
    }
    @objc func togglePin() {
        pin.contentTintColor = pin.state == .on ? .systemCyan : .lightGray
    }
    @objc func toggleSize() {
        largeReading.toggle()
        if !panel.isVisible { showPanel() } else { positionPanel(); animateReveal(opening: true) }
    }
    // Restrict recovery to known conversation routes, never an attachment URL.
    func isChatURL(_ url: URL, provider: Int) -> Bool {
        guard url.scheme == "https", url.host == URL(string: sites[provider].1)?.host else { return false }
        let parts = url.path.split(separator: "/")
        if parts.isEmpty { return true }
        switch provider {
        case 0:
            return (parts.count == 2 && parts[0] == "c") ||
                (parts.count == 4 && parts[0] == "g" && parts[2] == "c")
        case 1: return parts.count == 3 && parts[0] == "a" && parts[1] == "chat"
        case 2: return parts[0] == "app" && parts.count <= 2
        default: return false
        }
    }
    @objc func returnToChat() {
        let index = picker.indexOfSelectedItem
        let view = current
        let destination = ([view.url].compactMap { $0 } + view.backForwardList.backList.reversed().map { $0.url })
            .first { isChatURL($0, provider: index) } ?? URL(string: sites[index].1)!
        popups.filter { $0.isVisible }.forEach { $0.close() }
        view.stopLoading()
        view.load(URLRequest(url: destination, timeoutInterval: 40))
        engaged = true
        showPanel()
    }
    @objc func goBack() {
        if current.canGoBack { current.goBack() } else { returnToChat() }
    }
    @objc func reload() { current.reload() }
    @objc func openBrowser() { NSWorkspace.shared.open(current.url ?? URL(string: sites[picker.indexOfSelectedItem].1)!) }
    @objc func quit() { NSApp.terminate(nil) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyWebTheme(webView)
        if webView === current { address.stringValue = webView.url?.host ?? "" }
        if popups.contains(where: { $0 === webView.window }) { webView.window?.title = webView.url?.host ?? "网页登录" }

    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView === current { address.stringValue = "网页已暂停，请点刷新重新加载" }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView === current { address.stringValue = "加载中断，请刷新或在浏览器打开" }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if webView === current { address.stringValue = "加载失败：\(error.localizedDescription)；可刷新或在浏览器打开" }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if ["http", "https", "about", "blob"].contains(url.scheme ?? "") {
            if webView === current, navigationAction.targetFrame?.isMainFrame == true { address.stringValue = url.host ?? "" }
            decisionHandler(.allow)
        } else { decisionHandler(.cancel) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let child = WKWebView(frame: NSRect(x: 0, y: 0, width: 620, height: 700), configuration: configuration)
        child.navigationDelegate = self
        child.uiDelegate = self
        let window = NSWindow(contentRect: child.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "网页登录"
        window.contentView = child
        window.isReleasedWhenClosed = false
        window.level = .statusBar
        window.center()
        popups.removeAll { !$0.isVisible }
        popups.append(window)
        window.makeKeyAndOrderFront(nil)
        return child
    }
    func webViewDidClose(_ webView: WKWebView) { webView.window?.close() }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = webView.url?.host ?? "网页提示"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.beginSheetModal(for: webView.window ?? panel) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = webView.url?.host ?? "网页确认"
        alert.informativeText = message
        alert.addButton(withTitle: "确定"); alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: webView.window ?? panel) { completionHandler($0 == .alertFirstButtonReturn) }
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let chooser = NSOpenPanel()
        chooser.allowsMultipleSelection = parameters.allowsMultipleSelection
        chooser.canChooseDirectories = parameters.allowsDirectories
        chooser.beginSheetModal(for: panel) { result in completionHandler(result == .OK ? chooser.urls : nil) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

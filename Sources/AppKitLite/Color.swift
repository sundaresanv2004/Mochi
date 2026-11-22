#if os(Windows)
import Foundation

/// An sRGB colour. Calibrated, device and sRGB colours are all treated alike.
public final class NSColor: Equatable, Hashable, CustomStringConvertible {
    public let redComponent: CGFloat
    public let greenComponent: CGFloat
    public let blueComponent: CGFloat
    public let alphaComponent: CGFloat

    public init(calibratedRed r: CGFloat, green g: CGFloat, blue b: CGFloat, alpha a: CGFloat) {
        redComponent = r; greenComponent = g; blueComponent = b; alphaComponent = a
    }
    public convenience init(red r: CGFloat, green g: CGFloat, blue b: CGFloat, alpha a: CGFloat) {
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    public convenience init(srgbRed r: CGFloat, green g: CGFloat, blue b: CGFloat, alpha a: CGFloat) {
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    public convenience init(deviceRed r: CGFloat, green g: CGFloat, blue b: CGFloat, alpha a: CGFloat) {
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    public convenience init(calibratedWhite w: CGFloat, alpha a: CGFloat) {
        self.init(calibratedRed: w, green: w, blue: w, alpha: a)
    }
    public convenience init(white w: CGFloat, alpha a: CGFloat) { self.init(calibratedWhite: w, alpha: a) }
    public convenience init(deviceWhite w: CGFloat, alpha a: CGFloat) { self.init(calibratedWhite: w, alpha: a) }
    public convenience init(calibratedHue h: CGFloat, saturation s: CGFloat, brightness v: CGFloat, alpha a: CGFloat) {
        let i = floor(h * 6), f = h * 6 - i
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch Int(i) % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    public convenience init(hue h: CGFloat, saturation s: CGFloat, brightness v: CGFloat, alpha a: CGFloat) {
        self.init(calibratedHue: h, saturation: s, brightness: v, alpha: a)
    }

    public var whiteComponent: CGFloat { (redComponent + greenComponent + blueComponent) / 3 }
    public var hueComponent: CGFloat { hsb.0 }
    public var saturationComponent: CGFloat { hsb.1 }
    public var brightnessComponent: CGFloat { hsb.2 }

    private var hsb: (CGFloat, CGFloat, CGFloat) {
        let r = redComponent, g = greenComponent, b = blueComponent
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h: CGFloat = 0
        if d > 0 {
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    public func getRed(_ r: UnsafeMutablePointer<CGFloat>?, green g: UnsafeMutablePointer<CGFloat>?,
                       blue b: UnsafeMutablePointer<CGFloat>?, alpha a: UnsafeMutablePointer<CGFloat>?) {
        r?.pointee = redComponent; g?.pointee = greenComponent; b?.pointee = blueComponent; a?.pointee = alphaComponent
    }

    public func withAlphaComponent(_ a: CGFloat) -> NSColor {
        NSColor(calibratedRed: redComponent, green: greenComponent, blue: blueComponent, alpha: a)
    }

    public func blended(withFraction f: CGFloat, of c: NSColor) -> NSColor? {
        let k = min(max(f, 0), 1)
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * k }
        return NSColor(calibratedRed: mix(redComponent, c.redComponent), green: mix(greenComponent, c.greenComponent),
                       blue: mix(blueComponent, c.blueComponent), alpha: mix(alphaComponent, c.alphaComponent))
    }

    public func highlight(withLevel level: CGFloat) -> NSColor? { blended(withFraction: level, of: .white) }
    public func shadow(withLevel level: CGFloat) -> NSColor? { blended(withFraction: level, of: .black) }

    public func usingColorSpace(_ space: NSColorSpace) -> NSColor? { self }
    public func usingType(_ type: Any) -> NSColor? { self }

    public func setFill() { NSGraphicsContext.current?.fillColor = self }
    public func setStroke() { NSGraphicsContext.current?.strokeColor = self }
    public func set() { setFill(); setStroke() }

    /// Fills `rect` with this colour (like `NSRect.fill()` after `set()`).
    public func drawSwatch(in rect: NSRect) {
        let saved = NSGraphicsContext.current?.fillColor
        setFill()
        NSBezierPath(rect: rect).fill()
        if let saved { NSGraphicsContext.current?.fillColor = saved }
    }

    public var description: String {
        String(format: "NSColor(%.3f, %.3f, %.3f, %.3f)", Double(redComponent), Double(greenComponent),
               Double(blueComponent), Double(alphaComponent))
    }

    public static func == (a: NSColor, b: NSColor) -> Bool {
        a.redComponent == b.redComponent && a.greenComponent == b.greenComponent
            && a.blueComponent == b.blueComponent && a.alphaComponent == b.alphaComponent
    }
    public func hash(into h: inout Hasher) {
        h.combine(redComponent); h.combine(greenComponent); h.combine(blueComponent); h.combine(alphaComponent)
    }

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
        NSColor(calibratedRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    public static let clear = NSColor(calibratedWhite: 0, alpha: 0)
    public static let black = NSColor(calibratedWhite: 0, alpha: 1)
    public static let white = NSColor(calibratedWhite: 1, alpha: 1)
    public static let darkGray = NSColor(calibratedWhite: 1.0 / 3, alpha: 1)
    public static let gray = NSColor(calibratedWhite: 0.5, alpha: 1)
    public static let lightGray = NSColor(calibratedWhite: 2.0 / 3, alpha: 1)
    public static let red = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
    public static let green = NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)
    public static let blue = NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
    public static let yellow = NSColor(calibratedRed: 1, green: 1, blue: 0, alpha: 1)
    public static let orange = NSColor(calibratedRed: 1, green: 0.5, blue: 0, alpha: 1)
    public static let purple = NSColor(calibratedRed: 0.5, green: 0, blue: 0.5, alpha: 1)
    public static let brown = NSColor(calibratedRed: 0.6, green: 0.4, blue: 0.2, alpha: 1)
    public static let cyan = NSColor(calibratedRed: 0, green: 1, blue: 1, alpha: 1)
    public static let magenta = NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1)

    // The light-appearance system colours.
    public static let systemRed = rgb(255, 59, 48)
    public static let systemOrange = rgb(255, 149, 0)
    public static let systemYellow = rgb(255, 204, 0)
    public static let systemGreen = rgb(52, 199, 89)
    public static let systemMint = rgb(0, 199, 190)
    public static let systemTeal = rgb(48, 176, 199)
    public static let systemCyan = rgb(50, 173, 230)
    public static let systemBlue = rgb(0, 122, 255)
    public static let systemIndigo = rgb(88, 86, 214)
    public static let systemPurple = rgb(175, 82, 222)
    public static let systemPink = rgb(255, 45, 85)
    public static let systemBrown = rgb(162, 132, 94)
    public static let systemGray = rgb(142, 142, 147)
    public static let labelColor = NSColor(calibratedWhite: 0, alpha: 0.85)
    public static let secondaryLabelColor = NSColor(calibratedWhite: 0, alpha: 0.5)
    public static let textColor = NSColor(calibratedWhite: 0, alpha: 1)
    public static let windowBackgroundColor = rgb(236, 236, 236)
    public static let controlAccentColor = rgb(0, 122, 255)
}

public enum NSColorSpace {
    case sRGB, deviceRGB, genericRGB, displayP3
}
#endif

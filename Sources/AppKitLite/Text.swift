#if os(Windows)
import Foundation
import LiteCanvas

/// A font: a family, a size in points and a weight. The system font is Segoe UI.
public final class NSFont {
    public struct Weight: RawRepresentable, Hashable {
        public let rawValue: CGFloat
        public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public init(_ rawValue: CGFloat) { self.rawValue = rawValue }
        public static let ultraLight = Weight(-0.8)
        public static let thin = Weight(-0.6)
        public static let light = Weight(-0.4)
        public static let regular = Weight(0)
        public static let medium = Weight(0.23)
        public static let semibold = Weight(0.3)
        public static let bold = Weight(0.4)
        public static let heavy = Weight(0.56)
        public static let black = Weight(0.62)

        /// The DirectWrite weight (100…900).
        var dwrite: Int32 {
            switch rawValue {
            case ..<(-0.7): return 100
            case ..<(-0.5): return 200
            case ..<(-0.2): return 300
            case ..<0.1: return 400
            case ..<0.26: return 500
            case ..<0.35: return 600
            case ..<0.5: return 700
            case ..<0.6: return 800
            default: return 900
            }
        }
    }

    public let familyName: String
    public let pointSize: CGFloat
    public let weight: Weight
    public var fontName: String { familyName }

    init(family: String, size: CGFloat, weight: Weight) {
        familyName = family; pointSize = size; self.weight = weight
    }

    public static let systemFamily = "Segoe UI"

    public static func systemFont(ofSize size: CGFloat) -> NSFont { NSFont(family: systemFamily, size: size, weight: .regular) }
    public static func systemFont(ofSize size: CGFloat, weight: Weight) -> NSFont {
        NSFont(family: systemFamily, size: size, weight: weight)
    }
    public static func boldSystemFont(ofSize size: CGFloat) -> NSFont { NSFont(family: systemFamily, size: size, weight: .bold) }
    public static func monospacedDigitSystemFont(ofSize size: CGFloat, weight: Weight) -> NSFont {
        NSFont(family: systemFamily, size: size, weight: weight)
    }
    public static func monospacedSystemFont(ofSize size: CGFloat, weight: Weight) -> NSFont {
        NSFont(family: "Consolas", size: size, weight: weight)
    }
    public static func labelFont(ofSize size: CGFloat) -> NSFont { systemFont(ofSize: size) }
    public static var systemFontSize: CGFloat { 13 }

    public convenience init?(name: String, size: CGFloat) { self.init(family: name, size: size, weight: .regular) }

    public convenience init?(descriptor: NSFontDescriptor, size: CGFloat) {
        self.init(family: descriptor.family, size: size > 0 ? size : descriptor.size, weight: descriptor.weight)
    }

    public var fontDescriptor: NSFontDescriptor { NSFontDescriptor(family: familyName, size: pointSize, weight: weight) }

    /// Rough metrics for code that lays text out by hand.
    public var ascender: CGFloat { pointSize * 0.92 }
    public var descender: CGFloat { -pointSize * 0.22 }
    public var capHeight: CGFloat { pointSize * 0.7 }
    public var xHeight: CGFloat { pointSize * 0.5 }
}

public final class NSFontDescriptor {
    public enum SystemDesign { case `default`, rounded, serif, monospaced }
    let family: String
    let size: CGFloat
    let weight: NSFont.Weight

    init(family: String, size: CGFloat, weight: NSFont.Weight) { self.family = family; self.size = size; self.weight = weight }

    /// Windows has no rounded system font, so every design is the system font.
    public func withDesign(_ design: SystemDesign) -> NSFontDescriptor? {
        design == .monospaced ? NSFontDescriptor(family: "Consolas", size: size, weight: weight) : self
    }
}

public enum NSTextAlignment: Int { case left, center, right, justified, natural }
public enum NSLineBreakMode: Int { case byWordWrapping, byCharWrapping, byClipping, byTruncatingHead, byTruncatingTail, byTruncatingMiddle }

public class NSParagraphStyle {
    public var alignment: NSTextAlignment = .natural
    public var lineBreakMode: NSLineBreakMode = .byWordWrapping
    public var lineSpacing: CGFloat = 0
    public static let `default` = NSParagraphStyle()
    public init() {}
}

/// AppKit's mutable version (here every paragraph style can change).
public final class NSMutableParagraphStyle: NSParagraphStyle {}

extension NSAttributedString.Key {
    public static let font = NSAttributedString.Key("NSFont")
    public static let foregroundColor = NSAttributedString.Key("NSColor")
    public static let backgroundColor = NSAttributedString.Key("NSBackgroundColor")
    public static let paragraphStyle = NSAttributedString.Key("NSParagraphStyle")
    public static let kern = NSAttributedString.Key("NSKern")
    public static let shadow = NSAttributedString.Key("NSShadow")
    public static let strokeColor = NSAttributedString.Key("NSStrokeColor")
    public static let strokeWidth = NSAttributedString.Key("NSStrokeWidth")
    public static let baselineOffset = NSAttributedString.Key("NSBaselineOffset")
}

extension NSString {
    public struct DrawingOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let usesLineFragmentOrigin = DrawingOptions(rawValue: 1)
        public static let usesFontLeading = DrawingOptions(rawValue: 2)
        public static let usesDeviceMetrics = DrawingOptions(rawValue: 8)
        public static let truncatesLastVisibleLine = DrawingOptions(rawValue: 32)
    }
}

/// What a set of string attributes means for DirectWrite.
struct TextStyle {
    var font: NSFont
    var color: NSColor
    var align: Int32

    init(_ attrs: [NSAttributedString.Key: Any]?) {
        font = attrs?[.font] as? NSFont ?? .systemFont(ofSize: 12)
        color = attrs?[.foregroundColor] as? NSColor ?? .black
        switch (attrs?[.paragraphStyle] as? NSParagraphStyle)?.alignment {
        case .center?: align = 1
        case .right?: align = 2
        default: align = 0
        }
    }

    func measure(_ text: String, maxWidth: CGFloat) -> NSSize {
        var w: Float = 0, h: Float = 0
        let u = Array(text.utf16)
        u.withUnsafeBufferPointer { t in
            font.familyName.withCString(encodedAs: UTF16.self) { fam in
                lc_measure_text(t.baseAddress, Int32(t.count), fam, Float(font.pointSize), font.weight.dwrite,
                                Float(maxWidth), align, &w, &h)
            }
        }
        return NSSize(width: CGFloat(w), height: CGFloat(h))
    }

    /// Draws in `rect` (y up), the first line at the top.
    func draw(_ text: String, in rect: NSRect, wrap: Bool) {
        guard let ctx = NSGraphicsContext.current, !text.isEmpty else { return }
        // Text comes out of DirectWrite top-down: flip it upright at the rect's top-left corner.
        let m = ctx.ctm.concatenating(first: LiteMatrix(a: 1, b: 0, c: 0, d: -1, tx: rect.minX, ty: rect.maxY))
        ctx.applyTransform(m)
        let u = Array(text.utf16)
        u.withUnsafeBufferPointer { t in
            font.familyName.withCString(encodedAs: UTF16.self) { fam in
                lc_draw_text(ctx.canvas, t.baseAddress, Int32(t.count), fam, Float(font.pointSize), font.weight.dwrite,
                             color.lc, Float(max(rect.width, 1)), Float(max(rect.height, 1)), align, wrap ? 1 : 0)
            }
        }
    }
}

extension NSString {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> NSSize {
        TextStyle(attrs).measure(self as String, maxWidth: 0)
    }

    public func boundingRect(with size: NSSize, options: NSString.DrawingOptions = [],
                             attributes: [NSAttributedString.Key: Any]? = nil, context: Any? = nil) -> NSRect {
        let s = TextStyle(attributes).measure(self as String, maxWidth: size.width > 0 ? size.width : 0)
        return NSRect(x: 0, y: 0, width: min(s.width, size.width > 0 ? size.width : s.width), height: s.height)
    }

    public func draw(at p: NSPoint, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {
        let style = TextStyle(attrs)
        let s = style.measure(self as String, maxWidth: 0)
        style.draw(self as String, in: NSRect(x: p.x, y: p.y, width: ceil(s.width) + 1, height: ceil(s.height)), wrap: false)
    }

    public func draw(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {
        TextStyle(attrs).draw(self as String, in: rect, wrap: true)
    }

    public func draw(with rect: NSRect, options: NSString.DrawingOptions = [],
                     attributes: [NSAttributedString.Key: Any]? = nil, context: Any? = nil) {
        draw(in: rect, withAttributes: attributes)
    }
}

extension String {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> NSSize {
        (self as NSString).size(withAttributes: attrs)
    }
    public func draw(at p: NSPoint, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {
        (self as NSString).draw(at: p, withAttributes: attrs)
    }
    public func draw(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {
        (self as NSString).draw(in: rect, withAttributes: attrs)
    }
}
#endif

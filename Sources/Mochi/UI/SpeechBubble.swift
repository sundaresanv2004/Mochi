#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

final class BubbleView: NSView {
    /// Follows the pet's size (see `PetSize.bubbleScale`): text, padding, tail and corners all shrink together.
    static var scale: CGFloat = 1

    static var tailH: CGFloat { 8 * scale }
    static var hPad: CGFloat { 12 * scale }
    static var vPad: CGFloat { 8 * scale }

    private static let paragraph: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        return p
    }()

    static var attributes: [NSAttributedString.Key: Any] {
        let pt = 13 * scale
        let base = NSFont.systemFont(ofSize: pt, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: pt) } ?? base
        return [.font: font,
                .foregroundColor: NSColor(calibratedRed: 0.2, green: 0.17, blue: 0.2, alpha: 1),
                .paragraphStyle: paragraph]
    }

    static func textSize(_ text: String) -> NSSize {
        let r = (text as NSString).boundingRect(with: NSSize(width: 190 * scale, height: 400),
                                                options: [.usesLineFragmentOrigin], attributes: attributes)
        return NSSize(width: ceil(r.width), height: ceil(r.height))
    }

    static func windowSize(for text: String) -> NSSize {
        let t = textSize(text)
        return NSSize(width: max(54 * scale, t.width + hPad * 2 + 3), height: t.height + vPad * 2 + tailH + 3)
    }

    var text = "" { didSet { needsDisplay = true } }
    var tailOnTop = false { didSet { needsDisplay = true } }
    var tailX: CGFloat = 40 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let th = Self.tailH
        let k = Self.scale
        let body = NSRect(x: 1.5, y: tailOnTop ? 1.5 : th + 1.5,
                          width: bounds.width - 3, height: bounds.height - th - 3)
        let bubble = NSBezierPath(roundedRect: body, xRadius: 12 * k, yRadius: 12 * k)

        let tail = NSBezierPath()
        let baseY = tailOnTop ? body.maxY : body.minY
        let apexY = tailOnTop ? body.maxY + th - 1 : body.minY - th + 1
        tail.move(to: NSPoint(x: tailX - 6 * k, y: baseY))
        tail.line(to: NSPoint(x: tailX, y: apexY))
        tail.line(to: NSPoint(x: tailX + 6 * k, y: baseY))

        let fill = NSColor(calibratedWhite: 1, alpha: 0.97)
        let border = NSColor(calibratedRed: 0.36, green: 0.3, blue: 0.32, alpha: 1)

        fill.setFill()
        bubble.fill()
        let tailFill = tail.copy() as! NSBezierPath
        tailFill.close(); tailFill.fill()

        border.setStroke()
        bubble.lineWidth = 1.5; bubble.stroke()
        tail.lineWidth = 1.5; tail.lineJoinStyle = .round; tail.stroke()

        // hide the seam where the tail joins the bubble
        fill.setStroke()
        let seam = NSBezierPath()
        seam.move(to: NSPoint(x: tailX - 6 * k + 1, y: baseY))
        seam.line(to: NSPoint(x: tailX + 6 * k - 1, y: baseY))
        seam.lineWidth = 2.6; seam.stroke()

        let size = Self.textSize(text)
        let rect = NSRect(x: (bounds.width - size.width) / 2,
                          y: body.minY + (body.height - size.height) / 2,
                          width: size.width, height: size.height)
        (text as NSString).draw(in: rect, withAttributes: Self.attributes)
    }
}

/// A small floating window that follows the pet and shows what it says.
final class SpeechBubble {
    private let window: NSWindow
    private let view = BubbleView()
    private var hideAt = Date.distantPast
    private var size = NSSize(width: 80, height: 40)
    private(set) var visible = false

    init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 80, height: 40),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false
        window.contentView = view
    }

    func hide() {
        visible = false
        window.orderOut(nil)
    }

    /// Call after `BubbleView.scale` changes so a bubble that is already showing is re-measured.
    func rescale() {
        size = BubbleView.windowSize(for: view.text)
        view.needsDisplay = true
    }

    func say(_ text: String, for seconds: TimeInterval = 3.6) {
        view.text = text
        size = BubbleView.windowSize(for: text)
        hideAt = Date().addingTimeInterval(seconds)
        visible = true
    }

    /// Place the bubble above the pet (or below when there's no room / on the ceiling).
    func update(centerX: CGFloat, aboveY: CGFloat, belowY: CGFloat, preferBelow: Bool, limit: NSRect) {
        guard visible else { return }
        if Date() > hideAt {
            visible = false
            window.orderOut(nil)
            return
        }
        var x = centerX - size.width / 2
        x = min(max(x, limit.minX + 4), limit.maxX - size.width - 4)

        let fitsAbove = aboveY + size.height <= limit.maxY
        let below = preferBelow || !fitsAbove
        let y = below ? belowY - size.height : aboveY

        view.tailOnTop = below
        view.tailX = min(max(centerX - x, 18 * BubbleView.scale), size.width - 18 * BubbleView.scale)
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        if frame != window.frame { window.setFrame(frame, display: true) }
        if !window.isVisible { window.orderFrontRegardless() }
    }
}

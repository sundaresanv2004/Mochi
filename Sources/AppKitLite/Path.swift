#if os(Windows)
import Foundation
import LiteCanvas

/// A Bézier path with AppKit's API, drawn through Direct2D.
public final class NSBezierPath {
    public enum LineCapStyle: Int { case butt, round, square }
    public enum LineJoinStyle: Int { case miter, round, bevel }
    public enum WindingRule: Int { case nonZero, evenOdd }
    public enum ElementType { case moveTo, lineTo, curveTo, closePath }

    enum Element {
        case move(CGPoint)
        case line(CGPoint)
        case curve(CGPoint, CGPoint, CGPoint)       // control 1, control 2, end
        case close
    }

    var elements: [Element] = []
    private var subpathStart = CGPoint.zero
    public private(set) var currentPoint = CGPoint.zero

    public var lineWidth: CGFloat = 1
    public var lineCapStyle: LineCapStyle = .butt
    public var lineJoinStyle: LineJoinStyle = .miter
    public var miterLimit: CGFloat = 10
    public var windingRule: WindingRule = .nonZero
    public var flatness: CGFloat = 0.6
    var dash: [CGFloat] = []
    var dashPhase: CGFloat = 0

    public static var defaultLineWidth: CGFloat = 1

    public init() { lineWidth = Self.defaultLineWidth }

    public convenience init(rect r: NSRect) {
        self.init()
        appendRect(r)
    }

    public convenience init(ovalIn r: NSRect) {
        self.init()
        appendOval(in: r)
    }

    public convenience init(roundedRect r: NSRect, xRadius: CGFloat, yRadius: CGFloat) {
        self.init()
        appendRoundedRect(r, xRadius: xRadius, yRadius: yRadius)
    }

    public func copy() -> Any {
        let p = NSBezierPath()
        p.elements = elements; p.subpathStart = subpathStart; p.currentPoint = currentPoint
        p.lineWidth = lineWidth; p.lineCapStyle = lineCapStyle; p.lineJoinStyle = lineJoinStyle
        p.miterLimit = miterLimit; p.windingRule = windingRule; p.flatness = flatness
        p.dash = dash; p.dashPhase = dashPhase
        return p
    }

    // MARK: Building

    public func move(to p: NSPoint) {
        elements.append(.move(p)); subpathStart = p; currentPoint = p
    }

    public func line(to p: NSPoint) {
        if elements.isEmpty { move(to: currentPoint) }
        elements.append(.line(p)); currentPoint = p
    }

    public func curve(to p: NSPoint, controlPoint1 c1: NSPoint, controlPoint2 c2: NSPoint) {
        if elements.isEmpty { move(to: currentPoint) }
        elements.append(.curve(c1, c2, p)); currentPoint = p
    }

    /// A quadratic curve, as a cubic.
    public func curve(to p: NSPoint, controlPoint c: NSPoint) {
        let s = currentPoint
        curve(to: p, controlPoint1: NSPoint(x: s.x + 2 / 3 * (c.x - s.x), y: s.y + 2 / 3 * (c.y - s.y)),
              controlPoint2: NSPoint(x: p.x + 2 / 3 * (c.x - p.x), y: p.y + 2 / 3 * (c.y - p.y)))
    }

    public func relativeMove(to d: NSPoint) { move(to: NSPoint(x: currentPoint.x + d.x, y: currentPoint.y + d.y)) }
    public func relativeLine(to d: NSPoint) { line(to: NSPoint(x: currentPoint.x + d.x, y: currentPoint.y + d.y)) }
    public func relativeCurve(to d: NSPoint, controlPoint1 c1: NSPoint, controlPoint2 c2: NSPoint) {
        let o = currentPoint
        curve(to: NSPoint(x: o.x + d.x, y: o.y + d.y), controlPoint1: NSPoint(x: o.x + c1.x, y: o.y + c1.y),
              controlPoint2: NSPoint(x: o.x + c2.x, y: o.y + c2.y))
    }

    public func close() {
        guard !elements.isEmpty else { return }
        elements.append(.close); currentPoint = subpathStart
    }

    public func removeAllPoints() { elements.removeAll(); currentPoint = .zero; subpathStart = .zero }

    public func appendRect(_ r: NSRect) {
        move(to: NSPoint(x: r.minX, y: r.minY))
        line(to: NSPoint(x: r.maxX, y: r.minY))
        line(to: NSPoint(x: r.maxX, y: r.maxY))
        line(to: NSPoint(x: r.minX, y: r.maxY))
        close()
    }

    /// An ellipse in four Bézier quarters, starting at the right and going anticlockwise like AppKit.
    public func appendOval(in r: NSRect) {
        let k: CGFloat = 0.5522847498
        let cx = r.midX, cy = r.midY, rx = r.width / 2, ry = r.height / 2
        move(to: NSPoint(x: cx + rx, y: cy))
        curve(to: NSPoint(x: cx, y: cy + ry), controlPoint1: NSPoint(x: cx + rx, y: cy + ry * k),
              controlPoint2: NSPoint(x: cx + rx * k, y: cy + ry))
        curve(to: NSPoint(x: cx - rx, y: cy), controlPoint1: NSPoint(x: cx - rx * k, y: cy + ry),
              controlPoint2: NSPoint(x: cx - rx, y: cy + ry * k))
        curve(to: NSPoint(x: cx, y: cy - ry), controlPoint1: NSPoint(x: cx - rx, y: cy - ry * k),
              controlPoint2: NSPoint(x: cx - rx * k, y: cy - ry))
        curve(to: NSPoint(x: cx + rx, y: cy), controlPoint1: NSPoint(x: cx + rx * k, y: cy - ry),
              controlPoint2: NSPoint(x: cx + rx, y: cy - ry * k))
        close()
    }

    public func appendRoundedRect(_ r: NSRect, xRadius: CGFloat, yRadius: CGFloat) {
        let rx = min(max(xRadius, 0), r.width / 2), ry = min(max(yRadius, 0), r.height / 2)
        guard rx > 0, ry > 0 else { appendRect(r); return }
        let k: CGFloat = 0.5522847498
        move(to: NSPoint(x: r.minX + rx, y: r.minY))
        line(to: NSPoint(x: r.maxX - rx, y: r.minY))
        curve(to: NSPoint(x: r.maxX, y: r.minY + ry), controlPoint1: NSPoint(x: r.maxX - rx + rx * k, y: r.minY),
              controlPoint2: NSPoint(x: r.maxX, y: r.minY + ry - ry * k))
        line(to: NSPoint(x: r.maxX, y: r.maxY - ry))
        curve(to: NSPoint(x: r.maxX - rx, y: r.maxY), controlPoint1: NSPoint(x: r.maxX, y: r.maxY - ry + ry * k),
              controlPoint2: NSPoint(x: r.maxX - rx + rx * k, y: r.maxY))
        line(to: NSPoint(x: r.minX + rx, y: r.maxY))
        curve(to: NSPoint(x: r.minX, y: r.maxY - ry), controlPoint1: NSPoint(x: r.minX + rx - rx * k, y: r.maxY),
              controlPoint2: NSPoint(x: r.minX, y: r.maxY - ry + ry * k))
        line(to: NSPoint(x: r.minX, y: r.minY + ry))
        curve(to: NSPoint(x: r.minX + rx, y: r.minY), controlPoint1: NSPoint(x: r.minX, y: r.minY + ry - ry * k),
              controlPoint2: NSPoint(x: r.minX + rx - rx * k, y: r.minY))
        close()
    }

    /// Angles in degrees, anticlockwise from +x (in AppKit's y-up space) unless `clockwise`.
    public func appendArc(withCenter c: NSPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat,
                          clockwise: Bool = false) {
        var sweep = endAngle - startAngle
        if clockwise {
            if sweep > 0 { sweep = sweep.truncatingRemainder(dividingBy: 360) - (sweep.truncatingRemainder(dividingBy: 360) == 0 ? 0 : 360) }
            if sweep < -360 { sweep = -360 }
        } else {
            if sweep < 0 { sweep = sweep.truncatingRemainder(dividingBy: 360) + (sweep.truncatingRemainder(dividingBy: 360) == 0 ? 0 : 360) }
            if sweep > 360 { sweep = 360 }
        }
        arc(center: c, radius: radius, start: startAngle, sweep: sweep)
    }

    /// An arc from `start` degrees turning `sweep` degrees (positive: anticlockwise), joined to the path.
    private func arc(center c: NSPoint, radius: CGFloat, start: CGFloat, sweep: CGFloat) {
        let a0 = start * .pi / 180
        let begin = NSPoint(x: c.x + radius * cos(a0), y: c.y + radius * sin(a0))
        if elements.isEmpty { move(to: begin) } else { line(to: begin) }
        guard sweep != 0, radius > 0 else { return }
        let pieces = max(1, Int(ceil(abs(sweep) / 90)))
        let step = sweep / CGFloat(pieces) * .pi / 180
        let k = 4.0 / 3.0 * tan(step / 4)
        var a = a0
        for _ in 0..<pieces {
            let b = a + step
            let p0 = NSPoint(x: c.x + radius * cos(a), y: c.y + radius * sin(a))
            let p3 = NSPoint(x: c.x + radius * cos(b), y: c.y + radius * sin(b))
            let c1 = NSPoint(x: p0.x - k * radius * sin(a), y: p0.y + k * radius * cos(a))
            let c2 = NSPoint(x: p3.x + k * radius * sin(b), y: p3.y - k * radius * cos(b))
            curve(to: p3, controlPoint1: c1, controlPoint2: c2)
            a = b
        }
    }

    /// The arc of `radius` fitted into the corner p1 → p2 (from the current point), like AppKit.
    public func appendArc(from p1: NSPoint, to p2: NSPoint, radius: CGFloat) {
        let p0 = currentPoint
        let v1 = CGPoint(x: p0.x - p1.x, y: p0.y - p1.y), v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let l1 = hypot(v1.x, v1.y), l2 = hypot(v2.x, v2.y)
        guard l1 > 0, l2 > 0, radius > 0 else { line(to: p1); return }
        let u1 = CGPoint(x: v1.x / l1, y: v1.y / l1), u2 = CGPoint(x: v2.x / l2, y: v2.y / l2)
        let cosA = u1.x * u2.x + u1.y * u2.y
        let angle = acos(max(-1, min(1, cosA)))
        guard angle > 0.0001, angle < .pi - 0.0001 else { line(to: p1); return }
        let dist = radius / tan(angle / 2)
        let t1 = NSPoint(x: p1.x + u1.x * dist, y: p1.y + u1.y * dist)
        let t2 = NSPoint(x: p1.x + u2.x * dist, y: p1.y + u2.y * dist)
        let bis = CGPoint(x: u1.x + u2.x, y: u1.y + u2.y), bl = hypot(bis.x, bis.y)
        let cd = radius / sin(angle / 2)
        let center = NSPoint(x: p1.x + bis.x / bl * cd, y: p1.y + bis.y / bl * cd)
        let s = atan2(t1.y - center.y, t1.x - center.x) * 180 / .pi
        let e = atan2(t2.y - center.y, t2.x - center.x) * 180 / .pi
        // The short way round, from the tangent point on the way in to the one on the way out.
        var sweep = e - s
        while sweep > 180 { sweep -= 360 }
        while sweep < -180 { sweep += 360 }
        arc(center: center, radius: radius, start: s, sweep: sweep)
    }

    public func append(_ other: NSBezierPath) {
        for e in other.elements {
            switch e {
            case .move(let p): move(to: p)
            case .line(let p): line(to: p)
            case .curve(let c1, let c2, let p): curve(to: p, controlPoint1: c1, controlPoint2: c2)
            case .close: close()
            }
        }
    }

    public func setLineDash(_ pattern: UnsafePointer<CGFloat>?, count: Int, phase: CGFloat) {
        dash = pattern.map { Array(UnsafeBufferPointer(start: $0, count: count)) } ?? []
        dashPhase = phase
    }

    public func transform(using t: AffineTransform) { transform(LiteMatrix(t)) }

    func transform(_ m: LiteMatrix) {
        elements = elements.map {
            switch $0 {
            case .move(let p): return .move(m.apply(p))
            case .line(let p): return .line(m.apply(p))
            case .curve(let a, let b, let p): return .curve(m.apply(a), m.apply(b), m.apply(p))
            case .close: return .close
            }
        }
        currentPoint = m.apply(currentPoint); subpathStart = m.apply(subpathStart)
    }

    public var isEmpty: Bool { elements.isEmpty }
    public var elementCount: Int { elements.count }

    public var bounds: NSRect { box(controls: false) }
    public var controlPointBounds: NSRect { box(controls: true) }

    private func box(controls: Bool) -> NSRect {
        var lo = CGPoint(x: CGFloat.infinity, y: CGFloat.infinity), hi = CGPoint(x: -CGFloat.infinity, y: -CGFloat.infinity)
        func add(_ p: CGPoint) { lo.x = min(lo.x, p.x); lo.y = min(lo.y, p.y); hi.x = max(hi.x, p.x); hi.y = max(hi.y, p.y) }
        var cur = CGPoint.zero
        for e in elements {
            switch e {
            case .move(let p), .line(let p): add(p); cur = p
            case .curve(let c1, let c2, let p):
                if controls { add(c1); add(c2); add(p) } else {
                    for i in 1...16 {
                        let t = CGFloat(i) / 16, u = 1 - t
                        add(CGPoint(x: u * u * u * cur.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p.x,
                                    y: u * u * u * cur.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p.y))
                    }
                }
                cur = p
            case .close: break
            }
        }
        guard lo.x <= hi.x else { return .zero }
        return NSRect(x: lo.x, y: lo.y, width: hi.x - lo.x, height: hi.y - lo.y)
    }

    /// Whether `p` is inside (by the winding rule), on a flattened copy of the path.
    public func contains(_ p: NSPoint) -> Bool {
        var winding = 0, crossings = 0
        for poly in polygons() where poly.count > 2 {
            for i in 0..<poly.count {
                let a = poly[i], b = poly[(i + 1) % poly.count]
                if (a.y <= p.y) != (b.y <= p.y) {
                    let x = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
                    if x > p.x { crossings += 1; winding += b.y > a.y ? 1 : -1 }
                }
            }
        }
        return windingRule == .evenOdd ? crossings % 2 == 1 : winding != 0
    }

    func polygons() -> [[CGPoint]] {
        var out: [[CGPoint]] = [], cur: [CGPoint] = []
        var last = CGPoint.zero
        for e in elements {
            switch e {
            case .move(let p): if !cur.isEmpty { out.append(cur) }; cur = [p]; last = p
            case .line(let p): cur.append(p); last = p
            case .curve(let c1, let c2, let p):
                for i in 1...12 {
                    let t = CGFloat(i) / 12, u = 1 - t
                    cur.append(CGPoint(x: u * u * u * last.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p.x,
                                       y: u * u * u * last.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p.y))
                }
                last = p
            case .close: if !cur.isEmpty { out.append(cur) }; cur = []
            }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    // MARK: Drawing

    /// Hands the path to Direct2D as flat command and point arrays.
    func withPath<R>(_ body: (LCPath) -> R) -> R {
        var cmds: [Int32] = [], pts: [Float] = []
        cmds.reserveCapacity(elements.count)
        for e in elements {
            switch e {
            case .move(let p): cmds.append(0); pts += [Float(p.x), Float(p.y)]
            case .line(let p): cmds.append(1); pts += [Float(p.x), Float(p.y)]
            case .curve(let a, let b, let p):
                cmds.append(2); pts += [Float(a.x), Float(a.y), Float(b.x), Float(b.y), Float(p.x), Float(p.y)]
            case .close: cmds.append(3)
            }
        }
        if pts.isEmpty { pts.append(0) }
        return cmds.withUnsafeBufferPointer { c in
            pts.withUnsafeBufferPointer { p in
                body(LCPath(cmds: c.baseAddress, count: Int32(c.count), pts: p.baseAddress,
                            evenOdd: windingRule == .evenOdd ? 1 : 0))
            }
        }
    }

    public func fill() {
        guard let ctx = NSGraphicsContext.current, !elements.isEmpty else { return }
        ctx.applyTransform()
        let color = ctx.fillColor.lc
        withPath { lc_fill(ctx.canvas, $0, color) }
    }

    public func stroke() {
        guard let ctx = NSGraphicsContext.current, !elements.isEmpty else { return }
        ctx.applyTransform()
        let color = ctx.strokeColor.lc
        let width = Float(lineWidth > 0 ? lineWidth : 0.5)
        let dashes = dash.map { Float($0) }
        withPath { path in
            dashes.withUnsafeBufferPointer { d in
                lc_stroke(ctx.canvas, path, color, width, Int32(lineCapStyle.rawValue), Int32(lineJoinStyle.rawValue),
                          Float(miterLimit), d.baseAddress, Int32(d.count), Float(dashPhase))
            }
        }
    }

    /// Narrows the clip to this path until the graphics state is restored.
    public func addClip() {
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.applyTransform()
        withPath { lc_push_clip(ctx.canvas, $0) }
    }

    public func setClip() { addClip() }

    public static func fill(_ r: NSRect) { NSBezierPath(rect: r).fill() }
    public static func stroke(_ r: NSRect) { NSBezierPath(rect: r).stroke() }
    public static func strokeLine(from a: NSPoint, to b: NSPoint) {
        let p = NSBezierPath(); p.move(to: a); p.line(to: b); p.stroke()
    }
    public static func clip(_ r: NSRect) { NSBezierPath(rect: r).addClip() }
}

extension NSColor {
    var lc: LCColor {
        LCColor(r: Float(redComponent), g: Float(greenComponent), b: Float(blueComponent), a: Float(alphaComponent))
    }
}

extension NSRect {
    public func fill() { NSBezierPath(rect: self).fill() }
    public func frame() { NSBezierPath(rect: self).stroke() }
}

/// A gradient between colours, linear or radial, like AppKit's.
public final class NSGradient {
    let colors: [NSColor]
    let locations: [CGFloat]

    public init?(starting: NSColor, ending: NSColor) {
        colors = [starting, ending]; locations = [0, 1]
    }

    public init?(colors: [NSColor]) {
        guard !colors.isEmpty else { return nil }
        self.colors = colors
        locations = colors.count == 1 ? [0] : colors.indices.map { CGFloat($0) / CGFloat(colors.count - 1) }
    }

    public init?(colors: [NSColor], atLocations locs: UnsafePointer<CGFloat>?, colorSpace: NSColorSpace) {
        guard !colors.isEmpty else { return nil }
        self.colors = colors
        if let locs { locations = Array(UnsafeBufferPointer(start: locs, count: colors.count)) }
        else { locations = colors.indices.map { colors.count == 1 ? 0 : CGFloat($0) / CGFloat(colors.count - 1) } }
    }

    public convenience init?(colorsAndLocations pairs: (NSColor, CGFloat)...) {
        let c = pairs.map(\.0), l = pairs.map(\.1)
        self.init(colors: c, atLocations: l, colorSpace: .sRGB)
    }

    private func stops<R>(_ body: (UnsafePointer<LCColor>, UnsafePointer<Float>, Int32) -> R) -> R {
        let c = colors.map(\.lc), l = locations.map { Float($0) }
        return c.withUnsafeBufferPointer { cp in l.withUnsafeBufferPointer { lp in body(cp.baseAddress!, lp.baseAddress!, Int32(c.count)) } }
    }

    /// Fills `path` with the gradient running across its bounds at `angle` degrees.
    public func draw(in path: NSBezierPath, angle: CGFloat) {
        guard let ctx = NSGraphicsContext.current, !path.isEmpty else { return }
        let r = path.bounds
        let a = angle * .pi / 180
        let dx = cos(a), dy = sin(a)
        let half = (abs(r.width * dx) + abs(r.height * dy)) / 2
        let x0 = r.midX - dx * half, y0 = r.midY - dy * half, x1 = r.midX + dx * half, y1 = r.midY + dy * half
        ctx.applyTransform()
        path.withPath { p in stops { c, l, n in lc_fill_linear(ctx.canvas, p, Float(x0), Float(y0), Float(x1), Float(y1), c, l, n) } }
    }

    public func draw(in rect: NSRect, angle: CGFloat) { draw(in: NSBezierPath(rect: rect), angle: angle) }

    public func draw(from start: NSPoint, to end: NSPoint, options: NSGradient.DrawingOptions = []) {
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.applyTransform()
        let all = NSBezierPath(rect: NSRect(x: -10000, y: -10000, width: 20000, height: 20000))
        all.withPath { p in stops { c, l, n in
            lc_fill_linear(ctx.canvas, p, Float(start.x), Float(start.y), Float(end.x), Float(end.y), c, l, n)
        } }
    }

    /// A radial gradient centred `relativeCenterPosition` (−1…1 across the bounds) and reaching the far corner.
    public func draw(in path: NSBezierPath, relativeCenterPosition rel: NSPoint) {
        guard let ctx = NSGraphicsContext.current, !path.isEmpty else { return }
        let r = path.bounds
        let c = NSPoint(x: r.midX + rel.x * r.width / 2, y: r.midY + rel.y * r.height / 2)
        let far = [NSPoint(x: r.minX, y: r.minY), NSPoint(x: r.maxX, y: r.minY), NSPoint(x: r.minX, y: r.maxY),
                   NSPoint(x: r.maxX, y: r.maxY)].map { hypot($0.x - c.x, $0.y - c.y) }.max() ?? 1
        ctx.applyTransform()
        path.withPath { p in stops { cs, l, n in lc_fill_radial(ctx.canvas, p, Float(c.x), Float(c.y), 0, Float(far), cs, l, n) } }
    }

    public func draw(in rect: NSRect, relativeCenterPosition rel: NSPoint) {
        draw(in: NSBezierPath(rect: rect), relativeCenterPosition: rel)
    }

    public func drawRadialGradient(from: NSPoint, radius r0: CGFloat, to: NSPoint, radius r1: CGFloat,
                                   options: NSGradient.DrawingOptions = []) {
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.applyTransform()
        let all = NSBezierPath(rect: NSRect(x: -10000, y: -10000, width: 20000, height: 20000))
        all.withPath { p in stops { cs, l, n in lc_fill_radial(ctx.canvas, p, Float(to.x), Float(to.y), Float(r0), Float(r1), cs, l, n) } }
    }

    public struct DrawingOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let drawsBeforeStartingLocation = DrawingOptions(rawValue: 1)
        public static let drawsAfterEndingLocation = DrawingOptions(rawValue: 2)
    }
}
#endif

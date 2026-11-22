#if os(Windows)
import Foundation
import LiteCanvas

/// A 2D affine transform: x' = a x + c y + tx, y' = b x + d y + ty.
public struct LiteMatrix: Equatable {
    public var a: CGFloat = 1, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 1, tx: CGFloat = 0, ty: CGFloat = 0

    public init() {}
    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }
    public init(_ t: AffineTransform) {
        self.init(a: t.m11, b: t.m12, c: t.m21, d: t.m22, tx: t.tX, ty: t.tY)
    }

    public static let identity = LiteMatrix()
    public static func translation(_ x: CGFloat, _ y: CGFloat) -> LiteMatrix { LiteMatrix(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y) }
    public static func scaling(_ x: CGFloat, _ y: CGFloat) -> LiteMatrix { LiteMatrix(a: x, b: 0, c: 0, d: y, tx: 0, ty: 0) }
    public static func rotation(_ r: CGFloat) -> LiteMatrix {
        let cs = cos(r), sn = sin(r)
        return LiteMatrix(a: cs, b: sn, c: -sn, d: cs, tx: 0, ty: 0)
    }

    /// `self ∘ first`: points go through `first`, then through `self` (how the CTM grows).
    public func concatenating(first m: LiteMatrix) -> LiteMatrix {
        LiteMatrix(a: a * m.a + c * m.b, b: b * m.a + d * m.b,
                   c: a * m.c + c * m.d, d: b * m.c + d * m.d,
                   tx: a * m.tx + c * m.ty + tx, ty: b * m.tx + d * m.ty + ty)
    }

    public func apply(_ p: CGPoint) -> CGPoint { CGPoint(x: a * p.x + c * p.y + tx, y: b * p.x + d * p.y + ty) }

    public var inverted: LiteMatrix? {
        let det = a * d - b * c
        guard det != 0 else { return nil }
        return LiteMatrix(a: d / det, b: -b / det, c: -c / det, d: a / det,
                          tx: (c * ty - d * tx) / det, ty: (b * tx - a * ty) / det)
    }

    /// Roughly how many pixels one user unit becomes.
    public var scale: CGFloat { sqrt(abs(a * d - b * c)) }
}

/// Where drawing goes: a Direct2D canvas, with AppKit's graphics state (transform, colours, clip) on top.
public final class NSGraphicsContext {
    public static var current: NSGraphicsContext?

    struct State {
        var ctm: LiteMatrix
        var fill: NSColor
        var stroke: NSColor
        var clipDepth: Int32
    }

    let canvas: OpaquePointer
    var state: State
    private var stack: [State] = []
    public lazy var cgContext = CGContext(self)

    /// `base` maps the view's coordinates (origin bottom-left, y up) to the canvas pixels.
    init(canvas: OpaquePointer, base: LiteMatrix) {
        self.canvas = canvas
        state = State(ctm: base, fill: .black, stroke: .black, clipDepth: lc_clip_depth(canvas))
    }

    public var fillColor: NSColor {
        get { state.fill }
        set { state.fill = newValue }
    }
    public var strokeColor: NSColor {
        get { state.stroke }
        set { state.stroke = newValue }
    }
    var ctm: LiteMatrix {
        get { state.ctm }
        set { state.ctm = newValue }
    }

    public var shouldAntialias = true
    public var compositingOperation = NSCompositingOperation.sourceOver
    public var imageInterpolation = NSImageInterpolation.default

    public func saveGraphicsState() {
        state.clipDepth = lc_clip_depth(canvas)
        stack.append(state)
    }

    public func restoreGraphicsState() {
        guard let saved = stack.popLast() else { return }
        while lc_clip_depth(canvas) > saved.clipDepth { lc_pop_clip(canvas) }
        state = saved
    }

    public static func saveGraphicsState() { current?.saveGraphicsState() }
    public static func restoreGraphicsState() { current?.restoreGraphicsState() }

    func applyTransform(_ m: LiteMatrix? = nil) {
        let t = m ?? state.ctm
        lc_set_transform(canvas, Float(t.a), Float(t.b), Float(t.c), Float(t.d), Float(t.tx), Float(t.ty))
    }

    /// Adds `m` to the current transform (applied before what is already there).
    func concat(_ m: LiteMatrix) { state.ctm = state.ctm.concatenating(first: m) }

    public func flushGraphics() {}
}

public enum NSCompositingOperation { case sourceOver, copy, clear, destinationOut, plusLighter }
public enum NSImageInterpolation { case `default`, none, low, medium, high }

/// The few Core Graphics calls Mochi makes, on the current `NSGraphicsContext`.
public final class CGContext {
    unowned let owner: NSGraphicsContext
    init(_ owner: NSGraphicsContext) { self.owner = owner }

    public func saveGState() { owner.saveGraphicsState() }
    public func restoreGState() { owner.restoreGraphicsState() }
    public func translateBy(x: CGFloat, y: CGFloat) { owner.concat(.translation(x, y)) }
    public func scaleBy(x: CGFloat, y: CGFloat) { owner.concat(.scaling(x, y)) }
    public func rotate(by angle: CGFloat) { owner.concat(.rotation(angle)) }
    public func concatenate(_ t: AffineTransform) { owner.concat(LiteMatrix(t)) }
    public func setAlpha(_ a: CGFloat) {}
    public func setShouldAntialias(_ on: Bool) { owner.shouldAntialias = on }
}

/// AppKit's mutable transform object. Each call applies before what is already there, like the CTM.
public final class NSAffineTransform {
    var m = LiteMatrix()

    public init() {}
    public init(transform: NSAffineTransform) { m = transform.m }

    public func translateX(by x: CGFloat, yBy y: CGFloat) { m = m.concatenating(first: .translation(x, y)) }
    public func rotate(byRadians r: CGFloat) { m = m.concatenating(first: .rotation(r)) }
    public func rotate(byDegrees deg: CGFloat) { rotate(byRadians: deg * .pi / 180) }
    public func scale(by s: CGFloat) { m = m.concatenating(first: .scaling(s, s)) }
    public func scaleX(by x: CGFloat, yBy y: CGFloat) { m = m.concatenating(first: .scaling(x, y)) }
    public func append(_ t: NSAffineTransform) { m = t.m.concatenating(first: m) }
    public func prepend(_ t: NSAffineTransform) { m = m.concatenating(first: t.m) }
    public func invert() { if let i = m.inverted { m = i } }
    public func transform(_ p: NSPoint) -> NSPoint { m.apply(p) }

    /// Adds this transform to the current graphics context.
    public func concat() { NSGraphicsContext.current?.concat(m) }
    /// Replaces the current transform (keeping the view's own placement on the canvas is up to the caller).
    public func set() { NSGraphicsContext.current?.ctm = m }

    public var transformStruct: AffineTransform {
        AffineTransform(m11: m.a, m12: m.b, m21: m.c, m22: m.d, tX: m.tx, tY: m.ty)
    }
}
#endif

#if os(Windows)
/// An offscreen picture to draw into and save as a PNG (for `--render` and the tray icon).
public final class ImageCanvas {
    public let size: NSSize
    public let scale: CGFloat
    private let canvas: OpaquePointer
    private let ctx: NSGraphicsContext

    public init?(size: NSSize, scale: CGFloat = 2) {
        guard let c = lc_create(Int32((size.width * scale).rounded()), Int32((size.height * scale).rounded())),
              lc_begin(c) == 0 else { return nil }
        self.size = size; self.scale = scale; canvas = c
        ctx = NSGraphicsContext(canvas: c, base: LiteMatrix(a: scale, b: 0, c: 0, d: -scale, tx: 0, ty: size.height * scale))
    }

    deinit { lc_destroy(canvas) }

    /// Runs `body` with drawing going into this picture, its origin moved to `origin` (y up).
    public func draw(at origin: NSPoint = .zero, _ body: () -> Void) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = ctx
        ctx.saveGraphicsState()
        ctx.concat(.translation(origin.x, origin.y))
        body()
        ctx.restoreGraphicsState()
        NSGraphicsContext.current = previous
    }

    @discardableResult
    public func writePNG(to path: String) -> Bool {
        _ = lc_end(canvas)
        let ok = path.withCString(encodedAs: UTF16.self) { lc_write_png(canvas, $0) } == 0
        _ = lc_begin(canvas)
        return ok
    }
}
#endif

#if os(Windows)
import Foundation

// The few pieces of Combine that Mochi uses: @Published, ObservableObject, and
// `$value.dropFirst().receive(on:).sink { }.store(in:)`.

public final class AnyCancellable: Hashable {
    private var onCancel: (() -> Void)?

    public init(_ cancel: @escaping () -> Void) { onCancel = cancel }
    deinit { cancel() }

    public func cancel() {
        let c = onCancel
        onCancel = nil
        c?()
    }

    public func store(in set: inout Set<AnyCancellable>) { set.insert(self) }
    public func store(in array: inout [AnyCancellable]) { array.append(self) }

    public static func == (a: AnyCancellable, b: AnyCancellable) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}

/// Where `receive(on:)` delivers values.
public protocol LiteScheduler {
    func liteSchedule(_ work: @escaping () -> Void)
}

extension DispatchQueue: LiteScheduler {
    public func liteSchedule(_ work: @escaping () -> Void) { async(execute: work) }
}

extension RunLoop: LiteScheduler {
    public func liteSchedule(_ work: @escaping () -> Void) { DispatchQueue.main.async(execute: work) }
}

/// A stream of values. Subscribing to a `@Published` property sends its current value first, like Combine.
public struct LitePublisher<Output> {
    public typealias Failure = Never
    let subscribe: (@escaping (Output) -> Void) -> AnyCancellable

    public init(_ subscribe: @escaping (@escaping (Output) -> Void) -> AnyCancellable) { self.subscribe = subscribe }

    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable { subscribe(receiveValue) }

    public func dropFirst(_ count: Int = 1) -> LitePublisher<Output> {
        LitePublisher { receive in
            var left = count
            return self.subscribe { value in
                if left > 0 { left -= 1 } else { receive(value) }
            }
        }
    }

    public func receive<S: LiteScheduler>(on scheduler: S) -> LitePublisher<Output> {
        LitePublisher { receive in self.subscribe { value in scheduler.liteSchedule { receive(value) } } }
    }

    public func map<T>(_ transform: @escaping (Output) -> T) -> LitePublisher<T> {
        LitePublisher<T> { receive in self.subscribe { receive(transform($0)) } }
    }

    public func filter(_ isIncluded: @escaping (Output) -> Bool) -> LitePublisher<Output> {
        LitePublisher { receive in self.subscribe { if isIncluded($0) { receive($0) } } }
    }

    public func eraseToAnyPublisher() -> LitePublisher<Output> { self }
}

extension LitePublisher where Output: Equatable {
    public func removeDuplicates() -> LitePublisher<Output> {
        LitePublisher { receive in
            var last: Output?
            return self.subscribe { value in
                if last != value { last = value; receive(value) }
            }
        }
    }
}

public typealias AnyPublisher<Output, Failure> = LitePublisher<Output>

/// Sends to everyone listening. Used by `@Published` and `objectWillChange`.
public final class PassthroughSubject<Output, Failure> {
    private var listeners: [Int: (Output) -> Void] = [:]
    private var next = 0

    public init() {}

    public func send(_ value: Output) {
        for l in listeners.sorted(by: { $0.key < $1.key }) { l.value(value) }
    }

    fileprivate func listen(_ f: @escaping (Output) -> Void) -> AnyCancellable {
        next += 1
        let id = next
        listeners[id] = f
        return AnyCancellable { [weak self] in self?.listeners[id] = nil }
    }

    public func eraseToAnyPublisher() -> LitePublisher<Output> {
        LitePublisher { [self] receive in self.listen(receive) }
    }

    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable { listen(receiveValue) }
}

extension PassthroughSubject where Output == Void {
    public func send() { send(()) }
}

@propertyWrapper
public struct Published<Value> {
    final class Box {
        var value: Value
        let subject = PassthroughSubject<Value, Never>()
        init(_ value: Value) { self.value = value }
    }

    private let box: Box

    public init(wrappedValue: Value) { box = Box(wrappedValue) }

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set {
            box.value = newValue
            box.subject.send(newValue)
        }
    }

    public var projectedValue: LitePublisher<Value> {
        let box = self.box
        return LitePublisher { receive in
            receive(box.value)
            return box.subject.sink(receiveValue: receive)
        }
    }
}

public typealias ObservableObjectPublisher = PassthroughSubject<Void, Never>

public protocol ObservableObject: AnyObject {}

private var willChange: [ObjectIdentifier: ObservableObjectPublisher] = [:]

extension ObservableObject {
    /// Nothing on Windows redraws from this (there is no SwiftUI), but code that sends it keeps working.
    public var objectWillChange: ObservableObjectPublisher {
        let id = ObjectIdentifier(self)
        if let p = willChange[id] { return p }
        let p = ObservableObjectPublisher()
        willChange[id] = p
        return p
    }
}
#endif

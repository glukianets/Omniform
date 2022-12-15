import Foundation

// MARK: - String

internal extension StringProtocol {
    var humanReadable: String {
        let result: String = self.components(separatedBy: .whitespacesAndNewlines).flatMap { word in
            word.split { l, r in !l.isUppercase && r.isUppercase }.flatMap { group -> [String] in
                if let index = group.firstIndex(where: \.isLowercase), index > 0 {
                    return [String(group[0..<(index-1)]), String(group[(index-1)...])]
                } else {
                    return [String(group)]
                }
            }
        }.filter { !$0.isEmpty }.joined(separator: " ")

        return (result.first?.uppercased() ?? "") + result.dropFirst()
    }
    
    func dropPrefix(_ prefix: String) -> Self.SubSequence {
        self.hasPrefix(prefix) ? self.dropFirst(prefix.count) : self[...]
    }
    
    func indent(_ indent: String) -> String {
        self.components(separatedBy: .newlines)
            .map { indent + $0 }
            .joined(separator: "\n")
    }
}

// MARK: - Sequence

private extension Sequence {
    func split(when predicate: (Element, Element) throws -> Bool) rethrows -> [[Element]] {
        guard let first = self.first(where: { _ in true }) else { return [] }
        var result: [[Element]] = []
        var previous: Element = first
        var current: [Element] = []
        for element in self.dropFirst() {
            if try predicate(previous, element) {
                current.append(previous)
                result.append(current)
                current = []
            } else {
                current.append(previous)
            }
            previous = element
        }
        current.append(previous)
        result.append(current)
        return result
    }
    
    func group<R: Equatable>(by predicate: (Element) throws -> R) rethrows -> [(trait: R, elements: [Element])] {
        var result: [(R, [Element])] = []
        var current: (trait: R, elements: [Element])! = nil
        
        for element in self {
            let trait = try predicate(element)
            if trait != current?.trait {
                if current != nil {
                    result.append(current)
                }
                current = (trait, [element])
            } else {
                current.elements.append(element)
            }
        }
        
        if current != nil && !current.elements.isEmpty {
            result.append(current)
        }
        
        return result
    }
}

// MARK: - _OptionalProtocol

public protocol _OptionalProtocol<Wrapped>: ExpressibleByNilLiteral {
    associatedtype Wrapped
    
    static var none: Self { get }
    static func some(_: Self.Wrapped) -> Self
    
    var normalized: Wrapped? { get }
    
    var description: String { get }
}

extension Optional: _OptionalProtocol {
    @_implements(_OptionalProtocol, normalized)
    public var omniform_normalized: Wrapped? { self }
    
    @_implements(_OptionalProtocol, description)
    public var omniform_description: String {
        guard let wrapped = self else { return "" }
        if let optional = wrapped as? any _OptionalProtocol {
            return optional.description
        } else {
            return String(describing: wrapped)
        }
    }
}

// MARK: - Lock

final class Lock {
    private let lock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        self.lock = lock
    }

    deinit {
        lock.deallocate()
    }

    func whileLocked<R>(do block: () throws -> R) rethrows -> R {
        os_unfair_lock_assert_not_owner(self.lock)
        os_unfair_lock_lock(self.lock)
        os_unfair_lock_assert_owner(self.lock)
        defer { os_unfair_lock_unlock(self.lock); os_unfair_lock_assert_not_owner(self.lock) }
        return try block()
    }
    
    func ifWasUnlocked<R>(do block: () throws -> R) rethrows -> R? {
        os_unfair_lock_assert_not_owner(self.lock)
        guard os_unfair_lock_trylock(self.lock) else { return nil }
        os_unfair_lock_assert_owner(self.lock)
        defer { os_unfair_lock_unlock(self.lock); os_unfair_lock_assert_not_owner(self.lock) }
        return try block()
    }
}

// MARK: - Binding

public extension ValueBinding {
    func format<R>(_ format: AnyParseableFormatStyle<Value, R>) -> any ValueBinding<R> {
        self.map {
            format.format($0)
        } set: {
            try? format.parseStrategy.parse($0)
        }
    }
    
    @_disfavoredOverload
    func format<R>(_ format: AnyFormatStyle<Value, R>) -> any ValueBinding<R> {
        self.map {
            format.format($0)
        }
    }
}

// MARK: - String

internal extension String {
    @usableFromInline
    init(optionallyDescribing value: some Any) {
        self = (value as? any _OptionalProtocol)?.description ?? String(describing: value)
    }
}

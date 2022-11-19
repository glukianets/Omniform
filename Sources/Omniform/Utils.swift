import Foundation

// MARK: - String

internal extension String {
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
    
    func dropPrefix(_ prefix: String) -> Self {
        self.hasPrefix(prefix) ? String(self.dropFirst(prefix.count)) : self
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
    
    var _optional: Wrapped? { get }
}

extension Optional: _OptionalProtocol {
    public var _optional: Wrapped? { self }
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

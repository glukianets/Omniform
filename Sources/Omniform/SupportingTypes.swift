import Foundation

// MARK: - AnyFormatStyle

public class AnyFormatStyle<FormatInput, FormatOutput>: FormatStyle {
    @available(iOS 15.0, *)
    public static func wrapping<F>(_ f: F) -> AnyFormatStyle<FormatInput, FormatOutput>
    where F: FormatStyle, F.FormatInput == FormatInput, F.FormatOutput == FormatOutput
    {
        func erase<F: ParseableFormatStyle>(_ format: F) -> Any {
            AnyParseableFormatStyle.wrapping(f)
        }
       
        if let parseable = f as? any ParseableFormatStyle {
            return _openExistential(parseable, do: erase(_:)) as! AnyParseableFormatStyle<FormatInput, FormatOutput>
        } else {
            return SomeFormatStyle(wrapping: f)
        }
    }
    
    @available(iOS 15.0, *)
    public static func wrapping<F>(_ f: F) -> AnyParseableFormatStyle<FormatInput, FormatOutput>
    where F: ParseableFormatStyle, F.FormatInput == FormatInput, F.FormatOutput == FormatOutput
    {
        SomeParseableFormatStyle(wrapping: f)
    }

    public static func == (lhs: AnyFormatStyle, rhs: AnyFormatStyle) -> Bool {
        lhs.isEqual(to: rhs)
    }

    fileprivate init() { /* nothing */ }
    
    required public init(from decoder: Decoder) throws {
        fatalError("abstract; not implemented")
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("abstract; not implemented")
    }
    
    public func hash(into hasher: inout Hasher) {
        fatalError("abstract; not implemented")
    }
    
    public func format(_ value: FormatInput) -> FormatOutput {
        fatalError("abstract; not implemented")
    }
    
    public func locale(_ locale: Locale) -> Self {
        fatalError("abstract; not implemented")
    }
    
    internal func isEqual(to other: AnyFormatStyle) -> Bool {
        return false
    }
}

@available(iOS 15.0, *)
private final class SomeFormatStyle<F: FormatStyle>: AnyFormatStyle<F.FormatInput, F.FormatOutput> {
    private let wrapped: F
        
    public init(wrapping wrapped: F) {
        self.wrapped = wrapped
        super.init()
    }
    
    public required init(from decoder: Decoder) throws {
        preconditionFailure("\(Self.self) doesn't support decoding")
    }
    
    override public func encode(to encoder: Encoder) throws {
        try self.wrapped.encode(to: encoder)
    }
    
    override public func hash(into hasher: inout Hasher) {
        self.wrapped.hash(into: &hasher)
    }
    
    public override func format(_ value: FormatInput) -> FormatOutput {
        self.wrapped.format(value)
    }
    
    public override func locale(_ locale: Locale) -> SomeFormatStyle<F> {
        .init(wrapping: self.wrapped.locale(locale))
    }
    
    override internal func isEqual(to other: AnyFormatStyle<FormatInput, FormatOutput>) -> Bool {
        guard let other = other as? Self else { return false }
        return self.wrapped == other.wrapped
    }
}

// MARK: - AnyParseableFormatStyle

public class AnyParseableFormatStyle<I, O>: AnyFormatStyle<I, O>, ParseableFormatStyle {
    public typealias Strategy = AnyParseStrategy<O, I>
        
    public var parseStrategy: Strategy {
        fatalError("abstract; not implemented")
    }
}

@available(iOS 15.0, *)
private final class SomeParseableFormatStyle<F: ParseableFormatStyle>: AnyParseableFormatStyle<F.FormatInput, F.FormatOutput> {
    private let wrapped: F
    
    public init(wrapping wrapped: F) {
        self.wrapped = wrapped
        super.init()
    }
    
    public required init(from decoder: Decoder) throws {
        preconditionFailure("\(Self.self) doesn't support decoding")
    }
    
    override public func encode(to encoder: Encoder) throws {
        try self.wrapped.encode(to: encoder)
    }
    
    override public func hash(into hasher: inout Hasher) {
        self.wrapped.hash(into: &hasher)
    }
    
    public override func format(_ value: FormatInput) -> FormatOutput {
        self.wrapped.format(value)
    }
    
    public override func locale(_ locale: Locale) -> SomeParseableFormatStyle<F> {
        .init(wrapping: self.wrapped.locale(locale))
    }
    
    public override var parseStrategy: Strategy {
        .wrapping(self.wrapped.parseStrategy)
    }
    
    override internal func isEqual(to other: AnyFormatStyle<FormatInput, FormatOutput>) -> Bool {
        guard let other = other as? Self else { return false }
        return self.wrapped == other.wrapped
    }
}

// MARK: - AnyParseStrategy

public class AnyParseStrategy<ParseInput, ParseOutput>: ParseStrategy {
    @available(iOS 15.0, *)
    public static func wrapping<F>(_ f: F) -> AnyParseStrategy<ParseInput, ParseOutput>
    where F: ParseStrategy, F.ParseInput == ParseInput, F.ParseOutput == ParseOutput
    {
        SomeParseStrategy(wrapping: f)
    }

    public static func == (lhs: AnyParseStrategy, rhs: AnyParseStrategy) -> Bool {
        lhs.isEqual(to: rhs)
    }

    fileprivate init() { /* nothing */ }
    
    required public init(from decoder: Decoder) throws {
        fatalError("abstract; not implemented")
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("abstract; not implemented")
    }
    
    public func hash(into hasher: inout Hasher) {
        fatalError("abstract; not implemented")
    }

    public func parse(_ value: ParseInput) throws -> ParseOutput {
        fatalError("abstract; not implemented")
    }

    internal func isEqual(to other: AnyParseStrategy) -> Bool {
        return false
    }
}

@available(iOS 15.0, *)
private final class SomeParseStrategy<F: ParseStrategy>: AnyParseStrategy<F.ParseInput, F.ParseOutput> {
    private let wrapped: F
        
    public init(wrapping wrapped: F) {
        self.wrapped = wrapped
        super.init()
    }
    
    public required init(from decoder: Decoder) throws {
        preconditionFailure("\(Self.self) doesn't support decoding")
    }
    
    override public func encode(to encoder: Encoder) throws {
        try self.wrapped.encode(to: encoder)
    }
    
    override public func hash(into hasher: inout Hasher) {
        self.wrapped.hash(into: &hasher)
    }
    
    override public func parse(_ value: ParseInput) throws -> ParseOutput {
        try self.wrapped.parse(value)
    }
    
    override internal func isEqual(to other: AnyParseStrategy<ParseInput, ParseOutput>) -> Bool {
        guard let other = other as? Self else { return false }
        return self.wrapped == other.wrapped
    }
}

// MARK: - StringFormatStyle

internal struct StringFormatStyle<T: LosslessStringConvertible>: ParseableFormatStyle {
    public enum Error: Swift.Error {
        case parseFailed(String)
    }
    
    public struct Strategy: ParseStrategy {
        public func parse(_ value: String) throws -> T {
            guard let result = T(value) else { throw Error.parseFailed(value) }
            return result
        }
    }
    
    var parseStrategy: Strategy

    func format(_ value: T) -> String {
        value.description
    }
}

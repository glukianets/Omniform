import Foundation

// MARK: - AnyFormatStyle

public class AnyFormatStyle<FormatInput, FormatOutput>: FormatStyle {
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

// MARK: - BlockParseStrategy

private final class BlockFormatStyle<I, O>: AnyFormatStyle<I, O> {
    private let format: (FormatInput, Locale) -> FormatOutput
    private let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent, format: @escaping (FormatInput, Locale) -> FormatOutput) {
        self.format = format
        self.locale = locale
        super.init()
    }
    
    public init(format: @escaping (FormatInput) -> FormatOutput) {
        self.format = { f, l in format(f) }
        self.locale = .current
        super.init()
    }
    
    public required init(from decoder: Decoder) throws {
        preconditionFailure("\(Self.self) doesn't support decoding")
    }
    
    override public func encode(to encoder: Encoder) throws {
        preconditionFailure("\(Self.self) doesn't support encoding")
    }
    
    override public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    public override func format(_ value: FormatInput) -> FormatOutput {
        self.format(value, self.locale)
    }
    
    public override func locale(_ locale: Locale) -> BlockFormatStyle<FormatInput, FormatOutput> {
        .init(locale: locale, format: self.format)
    }
    
    override internal func isEqual(to other: AnyFormatStyle<FormatInput, FormatOutput>) -> Bool {
        guard let other = other as? Self else { return false }
        return self === other
    }
}

private final class BlockParseableFormatStyle<I, O>: AnyParseableFormatStyle<I, O> {
    private let parse: (FormatOutput, Locale) throws -> FormatInput
    private let format: (FormatInput, Locale) -> FormatOutput
    private let locale: Locale

    public init(
        locale: Locale = .autoupdatingCurrent,
        format: @escaping (FormatInput, Locale) -> FormatOutput,
        parse: @escaping (FormatOutput, Locale) throws -> FormatInput
    ) {
        self.parse = parse
        self.format = format
        self.locale = locale
        super.init()
    }
    
    public init(
        format: @escaping (FormatInput) -> FormatOutput,
        parse: @escaping (FormatOutput) throws -> FormatInput
    ) {
        self.parse = { p, l in try parse(p) }
        self.format = { f, l in format(f) }
        self.locale = .current
        super.init()
    }

    public required init(from decoder: Decoder) throws {
        preconditionFailure("\(Self.self) doesn't support decoding")
    }

    override public func encode(to encoder: Encoder) throws {
        preconditionFailure("\(Self.self) doesn't support encoding")
    }

    override public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    fileprivate func parse(_ value: FormatOutput) throws -> FormatInput {
        try self.parse(value, self.locale)
    }
    
    public override func format(_ value: FormatInput) -> FormatOutput {
        self.format(value, self.locale)
    }
    
    public override func locale(_ locale: Locale) -> BlockParseableFormatStyle<FormatInput, FormatOutput> {
        .init(locale: locale, format: self.format, parse: self.parse)
    }
    
    override internal func isEqual(to other: AnyFormatStyle<FormatInput, FormatOutput>) -> Bool {
        guard let other = other as? Self else { return false }
        return self === other
    }
    
    public override var parseStrategy: Strategy {
        SomeBlockParseStrategy(wrapping: self)
    }
}

private final class SomeBlockParseStrategy<I, O, F: BlockParseableFormatStyle<O, I>>: AnyParseStrategy<I, O> {
    private var wrapped: F
    
    public init(wrapping wrapped: F) {
        self.wrapped = wrapped
        super.init()
    }

    public required init(from decoder: Decoder) throws {
        preconditionFailure("\(Self.self) doesn't support decoding")
    }

    override public func encode(to encoder: Encoder) throws {
        preconditionFailure("\(Self.self) doesn't support encoding")
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

// MARK: - Initialization

extension AnyFormatStyle {
    @available(iOS 15.0, *)
    public static func wrapping<F>(_ f: F) -> AnyFormatStyle<FormatInput, FormatOutput>
    where F: FormatStyle, F.FormatInput == FormatInput, F.FormatOutput == FormatOutput
    {
        func erase<F: ParseableFormatStyle>(_ f: F) -> Any {
            AnyParseableFormatStyle<F.FormatInput, F.FormatOutput>.wrapping(f)
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
    
    public static func dynamic(
        locale: Locale = .autoupdatingCurrent,
        format: @escaping (FormatInput, Locale) -> FormatOutput,
        parse: @escaping (FormatOutput, Locale) throws -> FormatInput
    ) -> AnyParseableFormatStyle<FormatInput, FormatOutput> {
        BlockParseableFormatStyle(locale: locale, format: format, parse: parse)
    }
    
    public static func dynamic(
        format: @escaping (FormatInput) -> FormatOutput,
        parse: @escaping (FormatOutput) throws -> FormatInput
    ) -> AnyParseableFormatStyle<FormatInput, FormatOutput> {
        BlockParseableFormatStyle(format: format, parse: parse)
    }
    
    public static func dynamic(
        locale: Locale = .autoupdatingCurrent,
        format: @escaping (FormatInput, Locale) -> FormatOutput
    ) -> AnyFormatStyle<FormatInput, FormatOutput> {
        BlockFormatStyle(locale: locale, format: format)
    }
    
    public static func dynamic(
        format: @escaping (FormatInput) -> FormatOutput
    ) -> AnyFormatStyle<FormatInput, FormatOutput> {
        BlockFormatStyle(format: format)
    }
}

extension AnyFormatStyle where FormatOutput == String {
    public static var `default`: AnyFormatStyle<FormatInput, String>? {
        let dd = FormatDispatch<FormatInput>()
        let format = (dd as? FormatThroughCustomFieldFormattable)?.preferredFormat
            ?? (dd as? FormatThroughCustomStringPresentable)?.descriptionFormat

        return format as! AnyFormatStyle<FormatInput, String>?
    }
}

private struct FormatDispatch<Value> { }

private protocol FormatThroughCustomFieldFormattable {
    var preferredFormat: Any { get }
}

@available(iOS 15, *)
extension FormatDispatch: FormatThroughCustomFieldFormattable where Value: CustomFieldFormattable {
    var preferredFormat: Any {
        AnyFormatStyle<Value, String>.wrapping(Value.preferredFormatStyle)
    }
}

private protocol FormatThroughCustomStringPresentable {
    var descriptionFormat: Any { get }
}

extension FormatDispatch: FormatThroughCustomStringPresentable where Value: CustomStringConvertible {
    var descriptionFormat: Any {
        AnyFormatStyle<Value, String>.dynamic(format: \.description)
    }
}

import Foundation

// MARK: -

public protocol FieldPresenting<Value> {
    associatedtype Value
}

extension FieldPresenting where Self.Value: CustomFieldPresentable {
    public static func `default`() -> Self where Self == Self.Value.PreferredPresentation { Self.Value.preferredPresentation }
}

public struct FieldPresentations {
    /* namespace */
}

// MARK: - GroupPresentation

extension FieldPresentations {
    public enum GroupKind {
        case section(caption: String?)
        case screen
        case inline
    }
    
    public struct Group<Value>: FieldPresenting {
        public typealias Value = Value
                
        public var kind: GroupKind
        
        public init(kind: GroupKind) {
            self.kind = kind
        }
    }
}

extension FieldPresenting {
    @inlinable
    public static func section<T>(caption: String? = nil) -> Self where Self == FieldPresentations.Group<T> {
        .init(kind: .section(caption: caption))
    }

    @inlinable
    public static func screen<T>() -> Self where Self == FieldPresentations.Group<T> {
        .init(kind: .screen)
    }

    @inlinable
    public static func inline<T>() -> Self where Self == FieldPresentations.Group<T> {
        .init(kind: .inline)
    }
}

// MARK: - NoPresentation

extension FieldPresentations {
    public struct None<Value>: FieldPresenting {
        public typealias Value = Value
        
        public init() {
            // nothing
        }
    }
}

extension FieldPresenting {
    @inlinable
    public static func none<T>() -> Self where Self == FieldPresentations.None<T>, Value == T { .init() }
}

// MARK: - NestedPresentation

extension FieldPresentations {
    public struct Nested<Value, Wrapped>: FieldPresenting where Wrapped: FieldPresenting {
        public typealias Value = Value
        public typealias Wrapped = Wrapped
        
        public var keyPath: KeyPath<Value, Wrapped.Value>
        public var wrapped: Wrapped
       
        public init(wrapping wrapped: Wrapped, keyPath: KeyPath<Value, Wrapped.Value>) {
            self.wrapped = wrapped
            self.keyPath = keyPath
        }
    }
}

extension FieldPresenting {
    @inlinable
    public static func lifting<Value, Wrapped: FieldPresenting>(
        _ presentation: Wrapped,
        through keyPath: KeyPath<Value, Wrapped.Value>
    ) -> Self where Self == FieldPresentations.Nested<Value, Wrapped> {
        .init(wrapping: presentation, keyPath: keyPath)
    }
    
    @inlinable
    public func lifting<Outer>(
        through keyPath: KeyPath<Outer, Value>
    ) -> FieldPresentations.Nested<Outer, Self> {
        .init(wrapping: self, keyPath: keyPath)
    }
}

// MARK: - InputPresentation

extension FieldPresentations {
    public struct TextInput<Value>: FieldPresenting where Value: LosslessStringConvertible {
        public typealias Value = Value
        
        public var isSecure: Bool = false
        
        public init(secure: Bool = false) {
            self.isSecure = secure
        }
    }
}

extension FieldPresenting where Value: LosslessStringConvertible {
    @inlinable
    public static func input<T>(secure: Bool = false) -> Self
    where
        Self == FieldPresentations.TextInput<T>,
        Value == T
    {
        .init(secure: secure)
    }
}

extension FieldPresenting where Value: _OptionalProtocol, Value.Wrapped: StringProtocol {
    @inlinable
    public static func input<T>(secure: Bool = false) -> Self
    where
        Self == FieldPresentations.Nullified<T.Wrapped, FieldPresentations.TextInput<T>>,
        Value == T,
        T.Wrapped: LosslessStringConvertible
    {
        .init(wrapped: .init(secure: secure), nilValue: "")
    }
}

// MARK: - TogglePresentation

extension FieldPresentations {
    public struct Toggle: FieldPresenting {
        public typealias Value = Bool
        
        public init() {
            // nothing
        }
    }
}

extension FieldPresenting where Self == FieldPresentations.Toggle {
    @inlinable
    public static var toggle: Self { .init() }
}

// MARK: - PickerPresentation

extension FieldPresentations {
    public struct PickerStyle: Hashable {
        private enum Represenation: Hashable {
            case auto, inline, segments, selection, wheel, menu
        }

        public static let auto = Self(representation: .auto)
        public static let inline = Self(representation: .inline)
        public static let segments = Self(representation: .segments)
        public static let selection = Self(representation: .selection)
        public static let wheel = Self(representation: .wheel)

        @available(iOS 14.0, *)
        public static let menu = Self(representation: .menu)
    
        private let representation: Represenation
    }

    public struct Picker<Value>: FieldPresenting where Value: Hashable {
        public typealias Value = Value
        
        public var style: PickerStyle
        public var values: [Value]
        public var deselectionValue: Value?
        
        public init(style: PickerStyle, values: some Sequence<Value>, deselectionValue: Value?) {
            self.style = style
            self.values = Array(values)
            self.deselectionValue = deselectionValue
        }
    }
}

extension FieldPresenting where Value: CaseIterable & Hashable {
    @inlinable
    public static func picker<T>(style: FieldPresentations.PickerStyle = .auto) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: Value.allCases, deselectionValue: nil)
    }

    @inlinable
    public static func picker<T>(style: FieldPresentations.PickerStyle = .auto, deselectUsingValue value: Value) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: Value.allCases, deselectionValue: value)
    }
}

extension FieldPresenting where Value: _OptionalProtocol & Hashable, Value.Wrapped: CaseIterable {
    @inlinable
    public static func picker<T>(style: FieldPresentations.PickerStyle = .auto) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: T.Wrapped.allCases.map { .some($0) }, deselectionValue: .some(nil))
    }

    @inlinable
    public static func picker<T>(style: FieldPresentations.PickerStyle = .auto, deselectUsingValue value: Value) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: T.Wrapped.allCases.map { .some($0) }, deselectionValue: value)
    }
}

extension FieldPresenting where Value: Hashable {
    @inlinable
    public static func picker<T>(
        style: FieldPresentations.PickerStyle = .auto,
        cases: Value...
    ) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: cases, deselectionValue: nil)
    }

    @inlinable
    public static func picker<T>(
        style: FieldPresentations.PickerStyle = .auto,
        cases: Value...,
        deselectUsing value: Value
    ) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: cases, deselectionValue: value)
    }
}

// MARK: - SliderPresentation

extension FieldPresentations {
    public struct Slider<Value>: FieldPresenting where Value: BinaryFloatingPoint, Value.Stride: BinaryFloatingPoint {
        public typealias Value = Value
        
        public var range: ClosedRange<Value>
        public var step: Value.Stride?
        
        public init(range: ClosedRange<Value>, step: Value.Stride?) {
            self.range = range
            self.step = step
        }
    }
}

extension FieldPresenting where Value: BinaryFloatingPoint, Value.Stride: BinaryFloatingPoint {
    @inlinable
    public static func slider<T>(
        in range: ClosedRange<Value> = 0...1,
        by step: T.Stride? = nil
    ) -> Self where
        Self == FieldPresentations.Slider<T>,
        Value == T
    {
        .init(range: range, step: step)
    }
}

// MARK: - StepperPresentation

extension FieldPresentations {
    public struct Stepper<Value>: FieldPresenting where Value: Strideable {
        public typealias Value = Value
        
        public var range: ClosedRange<Value>
        public var step: Value.Stride
        
        public init(range: ClosedRange<Value>, step: Value.Stride) {
            self.range = range
            self.step = step
        }
    }
}

extension FieldPresenting where Value: FixedWidthInteger, Value.Stride: BinaryInteger {
    @inlinable
    public static func stepper<T>(
        by step: T.Stride = 1
    ) -> Self where
        Self == FieldPresentations.Stepper<T>,
        Value == T
    {
        .stepper(in: max(Value(clamping: Int32.min), Value.min)...min(Value(clamping: Int32.max), Value.max), by: step)
    }
    
    @inlinable
    public static func stepper<T>(
        in range: some RangeExpression<Value>,
        by step: T.Stride = 1
    ) -> Self where
        Self == FieldPresentations.Stepper<T>,
        Value == T
    {
        .init(range: ClosedRange(range.relative(to: Value.min..<Value.max)), step: step)
    }
}

extension FieldPresenting where Value: BinaryInteger, Value.Stride: BinaryInteger {
    @inlinable
    public static func stepper<T>(
        in range: ClosedRange<Value>,
        by step: T.Stride = 1
    ) -> Self where
        Self == FieldPresentations.Stepper<T>,
        Value == T
    {
        .init(range: range, step: step)
    }
}

// MARK: - ButtonPresentation

extension FieldPresentations {
    public struct ButtonRole {
        private enum Representation {
            case destructive, regular
        }
        
        public static let destructive = Self(representation: .destructive)
        
        public static let regular = Self(representation: .regular)
        
        private let representation: Representation
    }

    public struct Button: FieldPresenting {
        public typealias Value = () -> Void
           
        public var role: ButtonRole
        
        public init(role: ButtonRole) {
            self.role = role
        }
    }
}

extension FieldPresenting where Value == () -> Void {
    @inlinable
    public static func button(
        role: FieldPresentations.ButtonRole = .regular
    ) -> Self where
        Self == FieldPresentations.Button
    {
        .init(role: role)
    }
}

// MARK: - DatePickerPresentation

extension FieldPresentations {
    public struct DatePickerComponents: OptionSet {
        public static let date = Self(rawValue: 1 << 1)
        public static let hourAndMinute = Self(rawValue: 1 << 2)
        
        public var rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
    
    public struct DatePicker: FieldPresenting {
        public typealias Value = Date
        
        public var range: DateInterval
        public var components: DatePickerComponents
        
        public init(range: DateInterval, components: DatePickerComponents) {
            self.range = range
            self.components = components
        }
    }
}

extension FieldPresenting where Value == Date {
    @inlinable
    public static func datePicker(
        in interval: DateInterval = .init(start: .distantPast, end: .distantFuture),
        components: FieldPresentations.DatePickerComponents = .date
    ) -> Self where
        Self == FieldPresentations.DatePicker
    {
        .init(range: interval, components: components)
    }
}

// MARK: - URL

extension FieldPresentations {
    public struct URLInput: FieldPresenting {
        public typealias Value = URL
        
        public init() {
            // nothing
        }
    }
}

extension FieldPresentations {
    public struct OptionalURLInput: FieldPresenting {
        public typealias Value = URL?
        
        public init() {
            // nothing
        }
    }
}

extension FieldPresenting where Value == URL {
    @inlinable
    public static func input() -> Self where Self == FieldPresentations.URLInput {
        .init()
    }
}

extension FieldPresenting where Value == URL? {
    @inlinable
    public static func input() -> Self where Self == FieldPresentations.OptionalURLInput {
        .init()
    }
}

// MARK: - DocumentingPresentation

extension FieldPresentations {
    public struct Documented<Value, Presentation: FieldPresenting>: FieldPresenting where Presentation.Value == Value {
        public typealias Value = Value
        
        public var wrapped: Presentation
        public var documentation: String
        
        public init(wrapped: Presentation, documentation: String) {
            self.wrapped = wrapped
            self.documentation = documentation
        }
    }
}

extension FieldPresenting {
    public static func documenting<T, P: FieldPresenting, S: StringProtocol>(
        _ wrapped: P,
        _ doc: S
    ) -> Self where
        Self == FieldPresentations.Documented<T, P>,
        Value == T
    {
        .init(wrapped: wrapped, documentation: String(doc))
    }
}

extension FieldPresenting {
    public func document<S: StringProtocol>(_ doc: S) -> FieldPresentations.Documented<Self.Value, Self> {
        .init(wrapped: self, documentation: String(doc))
    }
}

// MARK: - NullifyingPresentation

extension FieldPresentations {
    public struct Nullified<Value, Presentation>: FieldPresenting
    where
        Presentation: FieldPresenting,
        Presentation.Value == Value.Wrapped,
        Value: _OptionalProtocol,
        Value.Wrapped: Equatable
    {
        public typealias Value = Value
        
        public var wrapped: Presentation
        public var nilValue: Value.Wrapped
        
        public init(wrapped: Presentation, nilValue: Value.Wrapped) {
            self.wrapped = wrapped
            self.nilValue = nilValue
        }
    }
}

extension FieldPresenting {
    public static func nullifying<P, V>(
        _ wrapped: P,
        when value: V.Wrapped
    ) -> Self where
        Self == FieldPresentations.Nullified<V, P>,
        V: _OptionalProtocol,
        P: FieldPresenting<V>
    {
        .init(wrapped: wrapped, nilValue: value)
    }
    
    public func nullifying<V>(
        when value: V.Wrapped
    ) -> FieldPresentations.Nullified<V, Self> where
        V: _OptionalProtocol,
        Self.Value == V.Wrapped,
        V.Wrapped: Equatable
    {
        .init(wrapped: self, nilValue: value)
    }
}

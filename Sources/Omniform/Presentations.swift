import Foundation

// MARK: -

/// A type that aids field resentation inside a form
public protocol FieldPresenting<Value> {
    associatedtype Value
}

public protocol GroupPresenting<Value>: FieldPresenting {
    func makeForm(metadata: Metadata, binding: some ValueBinding<Value>) -> FormModel?
}

public struct FieldPresentations {
    /* namespace */
}

// MARK: - Default

extension FieldPresenting where Self.Value: CustomFieldPresentable {
    /// The same presentation that ``CustomFieldPresentable`` dictates
    /// - Returns: ``CustomFieldPresentable``'s preferred presentation
    public static func `default`() -> Self where Self == Self.Value.PreferredPresentation { Self.Value.preferredPresentation }
}

// MARK: - GroupPresentation

extension FieldPresentations {
    public enum Group<Value>: GroupPresenting, Equatable {
        public typealias Value = Value
        
        public struct Section: Equatable {
            public let caption: String?
            
            public init(caption: String?) {
                self.caption = caption
            }
        }

        case section(Section)
        
        public struct Screen: Equatable {
            public init() {
                // nothing
            }
        }
        
        case screen(Screen)
        
        public struct Inline: Equatable {
            public init() {
                // nothing
            }
        }
        
        case inline(Inline)
        
        public func makeForm(metadata: Metadata, binding: some ValueBinding<Value>) -> FormModel? {
            var model = FormModel(binding)
            model.metadata = model.metadata.coalescing(with: metadata)
            return model
        }
    }
}

extension FieldPresenting {
    @inlinable
    public static func section<T>(caption: String? = nil) -> Self where Self == FieldPresentations.Group<T> {
        .section(.init(caption: caption))
    }

    @inlinable
    public static func screen<T>() -> Self where Self == FieldPresentations.Group<T> {
        .screen(.init())
    }

    @inlinable
    public static func inline<T>() -> Self where Self == FieldPresentations.Group<T> {
        .inline(.init())
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
    public enum Nested<Value, Wrapped>: FieldPresenting where Wrapped: FieldPresenting {
        public typealias Value = Value
        public typealias Wrapped = Wrapped
        
        public struct Subscript {
            public let wrapped: Wrapped
            public let keyPath: KeyPath<Value, Wrapped.Value>
            
            public init(wrapped: Wrapped, keyPath: KeyPath<Value, Wrapped.Value>) {
                self.wrapped = wrapped
                self.keyPath = keyPath
            }
        }
        
        case `subscript`(Subscript)
       
        public init(wrapping wrapped: Wrapped, keyPath: KeyPath<Value, Wrapped.Value>) {
            self = .subscript(Subscript(wrapped: wrapped, keyPath: keyPath))
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
    public enum TextInput<Value>: FieldPresenting where Value: LosslessStringConvertible {
        public typealias Value = Value
       
        public struct Regular {
            public init() {
                // nothing
            }
        }
        
        public struct Secure {
            public init() {
                // nothing
            }
        }
        
        case regular(Regular = .init())
        case secure(Secure = .init())
    }
}

extension FieldPresenting where Value: LosslessStringConvertible {
    @inlinable
    public static func input<T>(secure: Bool = false) -> Self
    where
        Self == FieldPresentations.TextInput<T>,
        Value == T
    {
        secure ? .secure() : .regular()
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
        .nullifying(secure ? .secure() : .regular(), when: "")
    }
}

// MARK: - TogglePresentation

extension FieldPresentations {
    public enum Toggle: FieldPresenting {
        public typealias Value = Bool
        
        public struct Regular {
            public init() {
                // nothing
            }
        }
        
        case regular(Regular = .init())
    }
}

extension FieldPresenting where Self == FieldPresentations.Toggle {
    @inlinable
    public static var toggle: Self { .regular() }
}

// MARK: - PickerPresentation

extension FieldPresentations {
    public enum Picker<Value>: GroupPresenting where Value: Hashable {
        public struct Style {
            fileprivate enum Represenation {
                case auto, segments, selection(Group<Value>), wheel, menu
            }

            public static var auto: Self { Self(representation: .auto) }
            public static var segments: Self { Self(representation: .segments) }
            public static var wheel: Self { Self(representation: .wheel) }
            public static var selection: Self { Self(representation: .selection(.screen())) }
            public static func selection(_ presentation: Group<Value> = .screen()) -> Self {
                Self(representation: .selection(presentation))
            }

            @available(iOS 14.0, *)
            public static var menu: Self { Self(representation: .menu) }
        
            fileprivate let representation: Represenation
        }
        
        public typealias Value = Value
        
        public struct Data {
            public let values: [Value]
            public let deselectionValue: Value?
            
            internal init(values: some Sequence<Value>, deselectionValue: Value?) {
                self.values = Array(values)
                self.deselectionValue = deselectionValue
            }
        }
        
        public struct Auto {
            public let data: Data
        }
                
        public struct Segments {
            public let data: Data
        }
        
        public struct Selection {
            public let data: Data
            public let presentation: (any GroupPresenting<Value>)?
        }
        
        public struct Wheel {
            public let data: Data
        }
        
        public struct Menu {
            public let data: Data
        }
        
        case auto(Auto)
        case segments(Segments)
        case selection(Selection)
        case wheel(Wheel)
        case menu(Menu)
        
        public var data: Data {
            switch self {
            case .auto(let content):
                return content.data
            case .segments(let content):
                return content.data
            case .selection(let content):
                return content.data
            case .wheel(let content):
                return content.data
            case .menu(let content):
                return content.data
            }
        }

        public func makeForm(metadata: Metadata, binding: some ValueBinding<Value>) -> FormModel? {
            guard case .selection(let content) = self else { return nil }
            if let group = content.presentation as? Group<Value>, case .inline = group { return nil }
            return .init(name: metadata.name, icon: metadata.icon) {
                .field(
                    binding,
                    metadata: metadata,
                    presentation: Picker.selection(.init(data: self.data, presentation: nil))
                )
            }
        }
        
        @usableFromInline
        internal init(style: Style, values: some Sequence<Value>, deselectionValue: Value?) {
            let data = Data(values: values, deselectionValue: deselectionValue)
            switch style.representation {
            case .auto:
                self = .auto(.init(data: data))
                break
            case .segments:
                self = .segments(.init(data: data))
                break
            case .selection(let group):
                self = .selection(.init(data: data, presentation: group))
                break
            case .wheel:
                self = .wheel(.init(data: data))
                break
            case .menu:
                self = .menu(.init(data: data))
                break
            }
        }
    }
}

extension FieldPresenting where Value: CaseIterable & Hashable {
    @inlinable
    public static func picker<T>(style: FieldPresentations.Picker<T>.Style = .auto) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: Value.allCases, deselectionValue: nil)
    }

    @inlinable
    public static func picker<T>(style: FieldPresentations.Picker<T>.Style = .auto, deselectUsingValue value: Value) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: Value.allCases, deselectionValue: value)
    }
}

extension FieldPresenting where Value: _OptionalProtocol & Hashable, Value.Wrapped: CaseIterable {
    @inlinable
    public static func picker<T>(style: FieldPresentations.Picker<T>.Style = .auto) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: T.Wrapped.allCases.map { .some($0) }, deselectionValue: .some(nil))
    }

    @inlinable
    public static func picker<T>(style: FieldPresentations.Picker<T>.Style = .auto, deselectUsingValue value: Value) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: T.Wrapped.allCases.map { .some($0) }, deselectionValue: value)
    }
}

extension FieldPresenting where Value: Hashable {
    @inlinable
    public static func picker<T>(
        style: FieldPresentations.Picker<T>.Style = .auto,
        cases: Value...
    ) -> Self where
        Self == FieldPresentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: cases, deselectionValue: nil)
    }

    @inlinable
    public static func picker<T>(
        style: FieldPresentations.Picker<T>.Style = .auto,
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
    public enum Slider<Value>: FieldPresenting where Value: BinaryFloatingPoint, Value.Stride: BinaryFloatingPoint {
        public typealias Value = Value
       
        public struct Regular {
            public let range: ClosedRange<Value>
            public let step: Value.Stride?
            
            public init(range: ClosedRange<Value>, step: Value.Stride?) {
                self.range = range
                self.step = step
            }
        }

        case regular(Regular)
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
        .regular(.init(range: range, step: step))
    }
}

// MARK: - StepperPresentation

extension FieldPresentations {
    public enum Stepper<Value>: FieldPresenting where Value: Strideable {
        public typealias Value = Value

        public struct Regular {
            public let range: ClosedRange<Value>
            public let step: Value.Stride
            
            public init(range: ClosedRange<Value>, step: Value.Stride) {
                self.range = range
                self.step = step
            }
        }

        case regular(Regular)
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
        .regular(.init(range: ClosedRange(range.relative(to: Value.min..<Value.max)), step: step))
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
        .regular(.init(range: range, step: step))
    }
}

// MARK: - ButtonPresentation

extension FieldPresentations {
    public struct ButtonRole: Equatable {
        private enum Representation: Equatable {
            case destructive, regular
        }
        
        public static let destructive = Self(representation: .destructive)
        
        public static let regular = Self(representation: .regular)
        
        private let representation: Representation
    }

    public enum Button: FieldPresenting {
        public typealias Value = () -> Void
           
        public struct Regular {
            public let role: ButtonRole
            
            public init(role: ButtonRole) {
                self.role = role
            }
        }

        case regular(Regular)
    }
}

extension FieldPresenting where Value == () -> Void {
    @inlinable
    public static func button(
        role: FieldPresentations.ButtonRole = .regular
    ) -> Self where
        Self == FieldPresentations.Button
    {
        .regular(.init(role: role))
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
    
    public enum DatePicker: FieldPresenting {
        public typealias Value = Date
       
        public struct Inline {
            public var interval: DateInterval
            public var components: DatePickerComponents
            
            public init(components: DatePickerComponents, interval: DateInterval) {
                self.components = components
                self.interval = interval
            }
        }
                
        case inline(Inline)
    }
}

extension FieldPresenting where Value == Date {
    @inlinable
    public static func picker(
        in interval: DateInterval = .init(start: .distantPast, end: .distantFuture),
        components: FieldPresentations.DatePickerComponents = .date
    ) -> Self where
        Self == FieldPresentations.DatePicker
    {
        .inline(.init(components: components, interval: interval))
    }
}

// MARK: - DocumentingPresentation

extension FieldPresentations {
    public enum Documented<Value, Presentation: FieldPresenting>: FieldPresenting where Presentation.Value == Value {
        public typealias Value = Value
        
        public struct DocString {
            public let wrapped: Presentation
            public let documentation: String
            
            public init(wrapped: Presentation, documentation: String) {
                self.wrapped = wrapped
                self.documentation = documentation
            }
        }
        
        case docString(DocString)
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
        .docString(.init(wrapped: wrapped, documentation: String(doc)))
    }
}

extension FieldPresenting {
    public func document<S: StringProtocol>(_ doc: S) -> FieldPresentations.Documented<Self.Value, Self> {
        .docString(.init(wrapped: self, documentation: String(doc)))
    }
}

// MARK: - NullifyingPresentation

extension FieldPresentations {
    public enum Nullified<Value, Presentation>: FieldPresenting
    where
        Presentation: FieldPresenting,
        Presentation.Value == Value.Wrapped,
        Value: _OptionalProtocol,
        Value.Wrapped: Equatable
    {
        public typealias Value = Value
        
        public struct Matching {
            public var wrapped: Presentation
            public var nilValue: Value.Wrapped
            
            public init(wrapped: Presentation, nilValue: Value.Wrapped) {
                self.wrapped = wrapped
                self.nilValue = nilValue
            }
        }
        
        case matching(Matching)
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
        .matching(.init(wrapped: wrapped, nilValue: value))
    }
    
    public func nullifying<V>(
        when value: V.Wrapped
    ) -> FieldPresentations.Nullified<V, Self> where
        V: _OptionalProtocol,
        Self.Value == V.Wrapped,
        V.Wrapped: Equatable
    {
        .matching(.init(wrapped: self, nilValue: value))
    }
}

// MARK: - EitherPresentation

extension FieldPresentations {
    public enum EitherPresentation<First, Second>: FieldPresenting
    where
        First: FieldPresenting,
        Second: FieldPresenting,
        First.Value == Second.Value
    {
        public typealias Value = First.Value
                
        case first(First)
        case second(Second)
    }
}


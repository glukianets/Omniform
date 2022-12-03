import Foundation

// MARK: -

/// A type that aids field resentation inside a form
public protocol FieldPresenting<Value> {
    associatedtype Value
}

public protocol GroupPresenting<Value>: FieldPresenting {
    mutating func makeForm(metadata: Metadata, binding: some ValueBinding<Value>) -> FormModel?
}

public struct Presentations {
    /* namespace */
}

// MARK: - Default

extension FieldPresenting where Self.Value: CustomFieldPresentable {
    /// The same presentation that ``CustomFieldPresentable`` dictates
    /// - Returns: ``CustomFieldPresentable``'s preferred presentation
    public static func `default`() -> Self where Self == Self.Value.PreferredPresentation { Self.Value.preferredPresentation }
}

// MARK: - GroupPresentation

extension Presentations {
    public enum Group<Value>: GroupPresenting, Equatable {
        public typealias Value = Value
        
        public struct Section: Equatable {
            public let caption: Metadata.Text?
            
            public init(caption: Metadata.Text?) {
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
        
        public mutating func makeForm(metadata: Metadata, binding: some ValueBinding<Value>) -> FormModel? {
            var model = FormModel(binding)
            model.metadata = model.metadata.coalescing(with: metadata)
            self = .inline()
            let result = FormModel(metadata:  model.metadata.coalescing(with: metadata)) {
                for submodel in GroupSectionFlattener().flatten(model) {
                    .group(model: submodel, ui: .section())
                }
            }
            return result
        }
    }
    
    fileprivate struct GroupSectionFlattener: FieldVisiting {
        enum Result {
            case one(FormModel.Member)
            case many([FormModel])
        }
        
        func visit<Value>(
            field: Metadata,
            id: AnyHashable,
            using presentation: some FieldPresenting<Value>,
            through binding: some ValueBinding<Value>
        ) -> Result {
            .one(.field(binding, metadata: field, ui: presentation))
        }
        
        func visit<Value>(
            group: FormModel,
            id: AnyHashable,
            using presentation: some GroupPresenting<Value>,
            through binding: some ValueBinding<Value>
        ) -> Result {
            switch presentation as? Group<Value> {
            case nil, .screen:
                return .one(.group(binding, model: group, ui: presentation))
            case .section, .inline:
                break
            }
            return .many(self.flatten(group))
        }
        
        func flatten(_ group: FormModel) -> [FormModel] {
            let result = group.fields(using: self)
            
            let head: [FormModel.Member] = result.compactMap {
                guard case .one(let field) = $0 else { return nil }
                return field
            }
            
            let tail: [FormModel] = result.flatMap {
                switch $0 {
                case .one:
                    return [] as [FormModel]
                case .many(let models):
                    return models
                }
            }
            
            if tail.isEmpty {
                return [group]
            } else if head.isEmpty {
                return tail
            } else {
                return [FormModel(metadata: group.metadata, prototype: .init(members: head))] + tail
            }
        }
    }
}

extension FieldPresenting {
    @inlinable
    public static func section<T>(caption: Metadata.Text? = nil) -> Self where Self == Presentations.Group<T> {
        .section(.init(caption: caption))
    }

    @inlinable
    public static func screen<T>() -> Self where Self == Presentations.Group<T> {
        .screen(.init())
    }

    @inlinable
    public static func inline<T>() -> Self where Self == Presentations.Group<T> {
        .inline(.init())
    }
}

// MARK: - NoPresentation

extension Presentations {
    public struct None<Value>: FieldPresenting {
        public typealias Value = Value
        
        public init() {
            // nothing
        }
    }
}

extension FieldPresenting {
    @inlinable
    public static func none<T>() -> Self where Self == Presentations.None<T>, Value == T { .init() }
}

// MARK: - NestedPresentation

extension Presentations {
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
    ) -> Self where Self == Presentations.Nested<Value, Wrapped> {
        .init(wrapping: presentation, keyPath: keyPath)
    }
    
    @inlinable
    public func lifting<Outer>(
        through keyPath: KeyPath<Outer, Value>
    ) -> Presentations.Nested<Outer, Self> {
        .init(wrapping: self, keyPath: keyPath)
    }
}

// MARK: - InputPresentation

extension Presentations {
    public enum TextInput<Value>: GroupPresenting {
        public typealias Value = Value
        
        public enum Style {
            case inline
            case screen
            case section
            case custom(any GroupPresenting<Value>)
        }
       
        public struct Plain {
            public internal(set) var style: Style
            public internal(set) var prompt: Metadata.Text?
            private let rebinder: (any ValueBinding<Value>) -> any ValueBinding<String>
            
            @usableFromInline
            internal init(style: Style = .screen, prompt: Metadata.Text? = nil)
            where Value: LosslessStringConvertible
            {
                self.style = style
                self.prompt = prompt
                self.rebinder = { $0.map { $0.description } set: { Value($0) } }
            }
            
            public func lower(binding: some ValueBinding<Value>) -> any ValueBinding<String> {
                self.rebinder(binding)
            }
        }
        
        public struct Secure {
            public internal(set) var style: Style
            public internal(set) var prompt: Metadata.Text?
            private let rebinder: (any ValueBinding<Value>) -> any ValueBinding<String>
            
            @usableFromInline
            internal init(style: Style = .screen, prompt: Metadata.Text? = nil)
            where Value: LosslessStringConvertible
            {
                self.style = style
                self.prompt = prompt
                self.rebinder = { $0.map { $0.description } set: { Value($0) } }
            }

            public func lower(binding: some ValueBinding<Value>) -> any ValueBinding<String> {
                self.rebinder(binding)
            }
        }
        
        public struct Format {
            public internal(set) var format: AnyParseableFormatStyle<Value, String>
            public internal(set) var style: Style
            public internal(set) var prompt: Metadata.Text?

            @available(iOS 15.0, *)
            public init<F>(
                format: F,
                style: Style = .screen,
                prompt: Metadata.Text? = nil
            ) where F: ParseableFormatStyle, F.FormatInput == Value, F.FormatOutput == String {
                self.style = style
                self.prompt = prompt
                self.format = .wrapping(format)
            }
        }
        
        case plain(Plain)
        case secure(Secure)
        case format(Format)
        
        public mutating func makeForm(metadata: Metadata, binding: some ValueBinding<Value>) -> FormModel? {
            let style: Style
            let prompt: Metadata.Text?
            switch self {
            case .plain(let content):
                style = content.style
                prompt = content.prompt
            case .secure(let content):
                style = content.style
                prompt = content.prompt
            case .format(let content):
                style = content.style
                prompt = content.prompt
            }
            
            switch style {
            case .inline:
                return nil
            case .screen:
                return FormModel(name: metadata.name, icon: metadata.icon) {
                    .group(ui: .section(caption: prompt)) {
                        .field(binding, metadata: metadata, ui: self)
                    }
                }
            case .section:
                return FormModel(name: metadata.name, icon: metadata.icon) {
                    .field(binding, metadata: metadata, ui: self)
                }
            case .custom(var presentation):
                defer {
                    switch self {
                    case .plain(var content):
                        content.style = .custom(presentation)
                        self = .plain(content)
                    case .secure(var content):
                        content.style = .custom(presentation)
                        self = .secure(content)
                    case .format(var content):
                        content.style = .custom(presentation)
                        self = .format(content)
                    }
                }
                return presentation.makeForm(metadata: metadata, binding: binding)
            }
        }
    }
}

extension FieldPresenting where Value: LosslessStringConvertible {
    @inlinable
    public static func input<T>(
        secure: Bool = false,
        presentation: Self.Style = .screen,
        prompt: Metadata.Text? = nil
    ) -> Self where
        Self == Presentations.TextInput<T>,
        Value == T
    {
        if secure {
            return .secure(.init(style: presentation, prompt: prompt))
        } else {
            return .plain(.init(style: presentation, prompt: prompt))
        }
    }
}

extension FieldPresenting where Value: _OptionalProtocol, Value.Wrapped: StringProtocol {
    @inlinable
    public static func input<T>(
        secure: Bool = false,
        presentation: Self.Presentation.Style = .screen,
        prompt: Metadata.Text? = nil
    ) -> Self where
        Self == Presentations.Nullified<T.Wrapped, Presentations.TextInput<T>>,
        Value == T
    {
        if secure {
            return .nullifying(.secure(.init(style: presentation, prompt: prompt)), when: "")
        } else {
            return .nullifying(.plain(.init(style: presentation, prompt: prompt)), when: "")
        }
    }
}

extension FieldPresenting {
    @inlinable
    @available(iOS 15.0, *)
    public static func input<F>(
        format: F,
        presentation: Self.Style = .screen,
        prompt: Metadata.Text? = nil
    ) -> Self where
        F: ParseableFormatStyle,
        F.FormatOutput == String,
        Self == Presentations.TextInput<F.FormatInput>
    {
        .format(.init(format: format, style: presentation, prompt: prompt))
    }
}

extension FieldPresenting where Value: _OptionalProtocol, Value.Wrapped: StringProtocol {
    @inlinable
    @available(iOS 15.0, *)
    public static func input<T, F>(
        format: F,
        presentation: Self.Presentation.Style = .screen,
        prompt: Metadata.Text? = nil
    ) -> Self where
        Self == Presentations.Nullified<T.Wrapped, Presentations.TextInput<T>>,
        Value == T,
        F: ParseableFormatStyle,
        F.FormatInput == T.Wrapped,
        F.FormatOutput == String
    {
        .nullifying(.format(.init(format: format, style: presentation, prompt: prompt)), when: "")
    }
}

// MARK: - TogglePresentation

extension Presentations {
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

extension FieldPresenting where Self == Presentations.Toggle {
    @inlinable
    public static var toggle: Self { .regular() }
}

// MARK: - PickerPresentation

extension Presentations {
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
                    ui: Picker.selection(.init(data: self.data, presentation: nil))
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
    public static func picker<T>(style: Presentations.Picker<T>.Style = .auto) -> Self where
        Self == Presentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: Value.allCases, deselectionValue: nil)
    }

    @inlinable
    public static func picker<T>(style: Presentations.Picker<T>.Style = .auto, deselectUsingValue value: Value) -> Self where
        Self == Presentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: Value.allCases, deselectionValue: value)
    }
}

extension FieldPresenting where Value: _OptionalProtocol & Hashable, Value.Wrapped: CaseIterable {
    @inlinable
    public static func picker<T>(style: Presentations.Picker<T>.Style = .auto) -> Self where
        Self == Presentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: T.Wrapped.allCases.map { .some($0) }, deselectionValue: .some(nil))
    }

    @inlinable
    public static func picker<T>(style: Presentations.Picker<T>.Style = .auto, deselectUsingValue value: Value) -> Self where
        Self == Presentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: T.Wrapped.allCases.map { .some($0) }, deselectionValue: value)
    }
}

extension FieldPresenting where Value: Hashable {
    @inlinable
    public static func picker<T>(
        style: Presentations.Picker<T>.Style = .auto,
        cases: Value...
    ) -> Self where
        Self == Presentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: cases, deselectionValue: nil)
    }

    @inlinable
    public static func picker<T>(
        style: Presentations.Picker<T>.Style = .auto,
        cases: Value...,
        deselectUsing value: Value
    ) -> Self where
        Self == Presentations.Picker<T>,
        T == Value
    {
        .init(style: style, values: cases, deselectionValue: value)
    }
}

// MARK: - SliderPresentation

extension Presentations {
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
        Self == Presentations.Slider<T>,
        Value == T
    {
        .regular(.init(range: range, step: step))
    }
}

// MARK: - StepperPresentation

extension Presentations {
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
        Self == Presentations.Stepper<T>,
        Value == T
    {
        .stepper(in: max(Value(clamping: Int32.min), Value.min)...min(Value(clamping: Int32.max), Value.max), by: step)
    }
    
    @inlinable
    public static func stepper<T>(
        in range: some RangeExpression<Value>,
        by step: T.Stride = 1
    ) -> Self where
        Self == Presentations.Stepper<T>,
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
        Self == Presentations.Stepper<T>,
        Value == T
    {
        .regular(.init(range: range, step: step))
    }
}

// MARK: - ButtonPresentation

extension Presentations {
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
        role: Presentations.ButtonRole = .regular
    ) -> Self where
        Self == Presentations.Button
    {
        .regular(.init(role: role))
    }
}

// MARK: - DatePickerPresentation

extension Presentations {
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
        components: Presentations.DatePickerComponents = .date
    ) -> Self where
        Self == Presentations.DatePicker
    {
        .inline(.init(components: components, interval: interval))
    }
}

// MARK: - DocumentingPresentation

extension Presentations {
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
        Self == Presentations.Documented<T, P>,
        Value == T
    {
        .docString(.init(wrapped: wrapped, documentation: String(doc)))
    }
}

extension FieldPresenting {
    public func document<S: StringProtocol>(_ doc: S) -> Presentations.Documented<Self.Value, Self> {
        .docString(.init(wrapped: self, documentation: String(doc)))
    }
}

// MARK: - NullifyingPresentation

extension Presentations {
    public enum Nullified<Value, Presentation>: FieldPresenting
    where
        Presentation: FieldPresenting,
        Presentation.Value == Value.Wrapped,
        Value: _OptionalProtocol,
        Value.Wrapped: Equatable
    {
        public typealias Value = Value
        public typealias Presentation = Presentation
        
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
        Self == Presentations.Nullified<V, P>,
        V: _OptionalProtocol,
        P: FieldPresenting<V>
    {
        .matching(.init(wrapped: wrapped, nilValue: value))
    }
    
    public func nullifying<V>(
        when value: V.Wrapped
    ) -> Presentations.Nullified<V, Self> where
        V: _OptionalProtocol,
        Self.Value == V.Wrapped,
        V.Wrapped: Equatable
    {
        .matching(.init(wrapped: self, nilValue: value))
    }
}

// MARK: - EitherPresentation

extension Presentations {
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

// MARK: - GroupingPresentation

extension Presentations {
    public struct Grouped<Group: GroupPresenting, Field: FieldPresenting>: GroupPresenting where Group.Value == Field.Value {
        public typealias Value = Field.Value
        public typealias Field = Field
        public typealias Group = Group
        
        public private(set) var groupPresentation: Group?
        public private(set) var fieldPresentation: Field
        
        public init(_ fieldPresentation: Field, inside groupPresenation: Group? = nil) {
            self.groupPresentation = groupPresenation
            self.fieldPresentation = fieldPresentation
        }
        
        public mutating func makeForm(metadata: Metadata, binding: some ValueBinding<Value>) -> FormModel? {
            if let group = self.groupPresentation as? Presentations.Group<Value>, case .inline = group { return nil }

            return FormModel(metadata: metadata) {
                .field(binding, metadata: metadata, ui: self.fieldPresentation)
            }
        }
    }
}

extension FieldPresenting {
    public static func grouping<P, G>(
        _ fieldPresentation: P,
        inside groupPresenation: G
    ) -> Self where
        Self == Presentations.Grouped<G, P>,
        P: FieldPresenting,
        G: GroupPresenting,
        P.Value == G.Value
    {
        .init(fieldPresentation, inside: groupPresenation)
    }
    
    public func grouping<G>(
        inside groupPresenation: G
    ) -> Presentations.Grouped<G, Self> where
        G: GroupPresenting,
        Self.Value == G.Value
    {
        .init(self, inside: groupPresenation)
    }
}

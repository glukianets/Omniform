import Foundation

// MARK: - PropertyWrapper

public protocol PropertyWrapper {
    associatedtype WrappedValue
    
    var wrappedValue: WrappedValue { get }
}

// MARK: - WritablePropertyWrapper

public protocol WritablePropertyWrapper: PropertyWrapper {
    var wrappedValue: WrappedValue { get set }
}

// MARK: - FieldVisiting

public protocol FieldVisiting<Result> {
    associatedtype Result
    
    func visit<Value>(
        field: Metadata,
        id: AnyHashable,
        using presentation: some FieldPresenting<Value>,
        through binding: some ValueBinding<Value>
    ) -> Result
    
    func visit<Value>(
        group: FormModel,
        id: AnyHashable,
        using presentation: some FieldPresenting<Value>,
        through binding: some ValueBinding<Value>
    ) -> Result
}

// MARK: - CustomFieldsContaining

public protocol CustomFormPresentable: CustomFieldPresentable {
    static func formModel(for binding: some ValueBinding<Self>) -> FormModel
}

extension CustomFormPresentable {
    public static var preferredPresentation: FieldPresentations.Group<Self> {
        .section()
    }
}

extension CustomFormPresentable where Self: CustomFormBuilding {
    public static func formModel(for binding: some ValueBinding<Self>) -> FormModel {
        let builder: () -> FormModel.Prototype = { self.buildForm(binding) }
        return FormModel(name: self.formName, icon: self.formIcon, builder: builder)
    }
}

// MARK: - CustomFieldsBuilding

public protocol CustomFormBuilding: CustomFormPresentable {
    static var formName: Metadata.Text? { get }
    static var formIcon: Metadata.Image? { get }
    
    @FormModel.Builder
    static func buildForm(_ binding: some ValueBinding<Self>) -> FormModel.Prototype
}

extension CustomFormBuilding {
    public static var formName: Metadata.Text? {
        .runtime(self)
    }
    
    public static var formIcon: Metadata.Image? {
        nil
    }
    
    public static func buildForm(_ binding: some ValueBinding<Self>) -> FormModel.Prototype {
        .init(dynamicallyInspecting: binding, options: .default)
    }
}

// MARK: - FieldPresentable

public protocol CustomFieldPresentable {
    associatedtype PreferredPresentation: FieldPresenting<Self>
    
    static var preferredPresentation: PreferredPresentation { get }
}

extension Bool: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.Toggle {
        .toggle
    }
}

extension String: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Character: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Float: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Double: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Int: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Int8: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Int16: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Int32: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Int64: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension UInt: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension UInt8: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension UInt16: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension UInt32: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension UInt64: CustomFieldPresentable {
    public static var preferredPresentation: FieldPresentations.TextInput<Self> {
        .input()
    }
}

extension Optional: CustomFieldPresentable where Wrapped: CustomFieldPresentable & Equatable & _DefaultInitializable {
    public static var preferredPresentation: FieldPresentations.Nullified<Self, Wrapped.PreferredPresentation> {
        Wrapped.preferredPresentation.nullifying(when: Wrapped.init())
    }
}

extension CustomFieldPresentable where Self: Hashable & CaseIterable {
    public static var preferredPresentation: FieldPresentations.Picker<Self> {
        .picker()
    }
}

// MARK: - _DefaultInitializable

public protocol _DefaultInitializable {
    init()
}

extension _DefaultInitializable where Self: ExpressibleByNilLiteral {
    public init() {
        self = nil
    }
}

extension Bool: _DefaultInitializable { }

extension String: _DefaultInitializable { }

extension Float: _DefaultInitializable { }

extension Double: _DefaultInitializable { }

extension Int: _DefaultInitializable { }

extension Int8: _DefaultInitializable { }

extension Int16: _DefaultInitializable { }

extension Int32: _DefaultInitializable { }

extension Int64: _DefaultInitializable { }

extension UInt: _DefaultInitializable { }

extension UInt8: _DefaultInitializable { }

extension UInt16: _DefaultInitializable { }

extension UInt32: _DefaultInitializable { }

extension UInt64: _DefaultInitializable { }

extension Optional: _DefaultInitializable { }

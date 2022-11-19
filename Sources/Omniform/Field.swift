import Foundation

internal protocol FieldProtocol: WritablePropertyWrapper {
    var metadata: SurrogateMetadata { get }
  
    var presentation: any FieldPresenting<Self.WrappedValue> { get }
}

@propertyWrapper
public struct Field<WrappedValue>: FieldProtocol {
    public var wrappedValue: WrappedValue
    internal let metadata: SurrogateMetadata
    internal let presentation: any FieldPresenting<WrappedValue>

    public init(
        wrappedValue: WrappedValue,
        presentation: some FieldPresenting<WrappedValue>
    ) {
        self.wrappedValue = wrappedValue
        self.presentation = presentation
        self.metadata = .init(type: Self.self)
    }
}

extension Field {
    @inlinable
    public init() where WrappedValue: CustomFieldPresentable, WrappedValue: _DefaultInitializable {
        self.init(wrappedValue: .init(), presentation: WrappedValue.preferredPresentation)
    }
    
    @inlinable
    public init(wrappedValue: WrappedValue) where WrappedValue: CustomFieldPresentable {
        self.init(wrappedValue: wrappedValue, presentation: WrappedValue.preferredPresentation)
    }
    
    @inlinable
    public init(presentation: some FieldPresenting<WrappedValue>) where WrappedValue: _DefaultInitializable {
        self.init(wrappedValue: .init(), presentation: presentation)
    }
}

extension Field {
    @inlinable
    public init(wrappedValue: WrappedValue)
    where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: WrappedValue.WrappedValue.preferredPresentation.lifting(
                through: \.wrappedValue
            )
        )
    }
    
    @inlinable
    public init(wrappedValue: WrappedValue, presentation: some FieldPresenting<WrappedValue.WrappedValue>)
    where
        WrappedValue: PropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue
            )
        )
    }
    
    @inlinable
    public init(wrappedValue: WrappedValue)
    where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue)
        )
    }
    
    @inlinable
    public init(wrappedValue: WrappedValue, presentation: some FieldPresenting<WrappedValue.WrappedValue>)
    where
        WrappedValue: WritablePropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue as WritableKeyPath<WrappedValue, WrappedValue.WrappedValue>
            )
        )
    }
}

extension Field {
    @inlinable
    public init(wrappedValue: WrappedValue)
    where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: WrappedValue.WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue.wrappedValue)
        )
    }

    @inlinable
    public init(wrappedValue: WrappedValue, presentation: some FieldPresenting<WrappedValue.WrappedValue.WrappedValue>)
    where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: PropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue.wrappedValue
            )
        )
    }
    
    @inlinable
    public init(wrappedValue: WrappedValue)
    where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: WrappedValue.WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue.wrappedValue)
        )
    }

    @inlinable
    public init(wrappedValue: WrappedValue, presentation: some FieldPresenting<WrappedValue.WrappedValue.WrappedValue>)
    where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: WritablePropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue.wrappedValue as WritableKeyPath<WrappedValue, WrappedValue.WrappedValue.WrappedValue>
            )
        )
    }
}

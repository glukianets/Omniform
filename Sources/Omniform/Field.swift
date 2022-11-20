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
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        presentation: some FieldPresenting<WrappedValue>,
        tags: AnyHashable...
    ) {
        self.wrappedValue = wrappedValue
        self.presentation = presentation
        self.metadata = .init(type: Self.self, name: name, icon: icon, tags: tags)
    }
}

extension Field {
    @inlinable
    public init(
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        tags: AnyHashable...
    ) where WrappedValue: CustomFieldPresentable, WrappedValue: _DefaultInitializable {
        self.init(
            wrappedValue: .init(),
            name: name,
            icon: icon,
            presentation: WrappedValue.preferredPresentation,
            tags: tags
        )
    }
    
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        tags: AnyHashable...
    ) where WrappedValue: CustomFieldPresentable {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: WrappedValue.preferredPresentation,
            tags: tags
        )
    }
    
    @inlinable
    public init(
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        presentation: some FieldPresenting<WrappedValue>,
        tags: AnyHashable...
    ) where WrappedValue: _DefaultInitializable {
        self.init(
            wrappedValue: .init(),
            name: name,
            icon: icon,
            presentation: presentation,
            tags: tags
        )
    }
}

extension Field {
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: WrappedValue.WrappedValue.preferredPresentation.lifting(
                through: \.wrappedValue
            ),
            tags: tags
        )
    }
    
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        presentation: some FieldPresenting<WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue
            ),
            tags: tags
        )
    }
    
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue),
            tags: tags
        )
    }
    
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        presentation: some FieldPresenting<WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue as WritableKeyPath<WrappedValue, WrappedValue.WrappedValue>
            ),
            tags: tags
        )
    }
}

extension Field {
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: WrappedValue.WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue.wrappedValue),
            tags: tags
        )
    }

    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        presentation: some FieldPresenting<WrappedValue.WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: PropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue.wrappedValue
            ),
            tags: tags
        )
    }
    
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: WrappedValue.WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue.wrappedValue),
            tags: tags
        )
    }

    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        presentation: some FieldPresenting<WrappedValue.WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: WritablePropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            presentation: presentation.lifting(
                through: \WrappedValue.wrappedValue.wrappedValue as WritableKeyPath<WrappedValue, WrappedValue.WrappedValue.WrappedValue>
            ),
            tags: tags
        )
    }
}

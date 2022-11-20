import Foundation

public struct Metadata: Equatable {
    public let type: Any.Type
    public let id: AnyHashable
    public let name: FieldName?
    public let icon: FieldIcon?
    public let externalName: String?
    public let tags: Set<AnyHashable>
    
    internal init(
        type: Any.Type,
        id: AnyHashable,
        name: FieldName? = nil,
        icon: FieldIcon? = nil,
        externalName: String? = nil,
        tags: Set<AnyHashable> = []
    ) {
        self.type = type
        self.id = id
        self.name = name ?? (externalName?.dropPrefix("_").humanReadable).map { FieldName($0, options: []) }
        self.icon = icon
        self.externalName = externalName
        self.tags = tags
        print(self)
    }
    
    internal func with(
        type: Any.Type? = nil,
        id: AnyHashable? = nil,
        name: FieldName?? = .none,
        icon: FieldIcon?? = .none,
        externalName: String?? = .none
    ) -> Self {
        .init(
            type: type ?? self.type,
            id: id ?? self.id,
            name: name ?? self.name,
            icon: icon ?? self.icon,
            externalName: externalName ?? self.externalName
        )
    }
    
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return lhs.type == rhs.type
        && lhs.name == rhs.name
        && lhs.icon == rhs.icon
        && lhs.externalName == rhs.externalName
    }
}

internal struct SurrogateMetadata: Equatable {
    public var type: Any.Type
    public var name: FieldName?
    public var icon: FieldIcon?
    public var tags: Set<AnyHashable>
    
    internal init(type: Any.Type, name: FieldName? = nil, icon: FieldIcon? = nil, tags: AnyHashable...) {
        self.type = type
        self.name = name
        self.icon = icon
        self.tags = Set(tags)
    }
    
    internal func with(id: AnyHashable, externalName: String? = nil) -> Metadata {
        .init(type: self.type, id: id, name: self.name, externalName: externalName)
    }
    
    public static func == (lhs: SurrogateMetadata, rhs: SurrogateMetadata) -> Bool {
        lhs.type == rhs.type
    }
}

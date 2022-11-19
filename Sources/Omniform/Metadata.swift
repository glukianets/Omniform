import Foundation

public struct Metadata: Equatable {
    public let type: Any.Type
    public let id: AnyHashable
    public let name: String?
    public let externalName: String?
    
    internal init(type: Any.Type, id: AnyHashable, name: String? = nil, externalName: String? = nil) {
        self.type = type
        self.id = id
        self.name = name ?? externalName?.dropPrefix("_").humanReadable
        self.externalName = externalName
        print(self)
    }
    
    internal func with(
        type: Any.Type? = nil,
        id: AnyHashable? = nil,
        name: String?? = .none,
        externalName: String?? = .none
    ) -> Self {
        .init(
            type: type ?? self.type,
            id: id ?? self.id,
            name: name ?? self.name,
            externalName: externalName ?? self.name
        )
    }
    
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return lhs.type == rhs.type
        && lhs.name == rhs.name
        && lhs.externalName == rhs.externalName
    }
}

internal struct SurrogateMetadata: Equatable {
    public var type: Any.Type
    public var name: String?
    
    internal init(type: Any.Type, name: String? = nil) {
        self.type = type
        self.name = name
    }
    
    internal func with(id: AnyHashable, externalName: String? = nil) -> Metadata {
        .init(type: self.type, id: id, name: self.name, externalName: externalName)
    }
    
    public static func == (lhs: SurrogateMetadata, rhs: SurrogateMetadata) -> Bool {
        lhs.type == rhs.type
    }
}

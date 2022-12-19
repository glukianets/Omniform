import Foundation

public struct Transforms {
    public struct GroupFlattener: FormTransforming {
        public enum Result {
            case one(FormModel.Member)
            case many([FormModel])
        }
        
        public init() {
            // nothing
        }
        
        public func visit<Value>(
            field: Metadata,
            id: AnyHashable,
            using presentation: some FieldPresenting<Value>,
            through binding: some ValueBinding<Value>
        ) -> Result {
            .one(.field(metadata: field, ui: presentation, binding: binding))
        }
        
        public func visit<Value>(
            group: FormModel,
            id: AnyHashable,
            using presentation: some GroupPresenting<Value>,
            through binding: some ValueBinding<Value>
        ) -> Result {
            switch presentation as? Presentations.Group<Value> {
            case nil, .screen?:
                return .one(.group(ui: presentation, binding: binding, model: group))
            case .section?, .inline?:
                return .many(self.flatten(metadata: group.metadata, fields: group.fields(using: self)))
            }
        }
        
        public func build(metadata: Metadata, fields: some Collection<Result>) throws -> FormModel {
            let result = FormModel(id: metadata.id) {
                for submodel in self.flatten(metadata: metadata, fields: fields) {
                    .group(ui: .section(), model: submodel)
                }
            }
            return result
        }
        
        private func flatten(metadata: Metadata, fields: some Collection<Result>) -> [FormModel] {
            return fields.group {
                switch $0 {
                case .one:
                    return true
                case .many:
                    return false
                }
            }.flatMap { isInline, elements in
                if isInline {
                    return [FormModel(metadata: metadata) {
                        for case let .one(field) in elements {
                            field
                        }
                    }]
                } else {
                    return elements.flatMap {
                        if case let .many(models) = $0 {
                            return models
                        } else {
                            return []
                        }
                    }
                }
            }
         }
    }

    public struct QueryTransform: FormTransforming {
        public typealias Result = FormModel.Member?
        struct ModelDoesNotMatchError: Error {}

        private var query: String
        
        public init(query: String) {
            self.query = query
        }
        
        public func build(metadata: Metadata, fields: some Collection<Result>) throws -> FormModel {
            guard !fields.isEmpty else { throw ModelDoesNotMatchError() }
            return FormModel(metadata: metadata, prototype: .init(members: fields.compactMap { $0 }))
        }

        public func visit<Value>(
            field: Metadata,
            id: AnyHashable,
            using presentation: some FieldPresenting<Value>,
            through binding: some ValueBinding<Value>
        ) -> FormModel.Member? {
            guard field.matches(query: self.query) else { return nil }
            return .field(metadata: field, ui: presentation, binding: binding)
        }
        
        public func visit<Value>(
            group: FormModel,
            id: AnyHashable,
            using presentation: some GroupPresenting<Value>,
            through binding: some ValueBinding<Value>
        ) -> FormModel.Member? {
            (try? group.applying(transform: self)).map {
                var model = $0
                model.metadata = model.metadata.with(id: id)
                return .group(ui: .section(), model: $0)
            }
        }
    }
}

extension Metadata {
    fileprivate func matches(query: String) -> Bool {
        return self.name?.description.localizedStandardContains(query) ?? false
    }
}

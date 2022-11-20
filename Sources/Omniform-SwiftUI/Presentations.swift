import Foundation
import SwiftUI

public protocol SwiftUIFieldPresenting<Value>: FieldPresenting {
    associatedtype Body: SwiftUI.View

    func body(for field: Metadata, binding: some ValueBinding<Value>) -> Body
}

public protocol SwiftUIFormPresenting<Value>: FieldPresenting {
    func body<R>(for model: FormModel, id: AnyHashable, builder: some FieldVisiting<R>) -> R
}

// MARK: - Group

private extension FieldPresentations {
    struct GroupPresentationTrampoline<Value>: SwiftUIFieldPresenting {
        typealias Value = Value
        
        @ViewBuilder
        let body: (Metadata) -> AnyView
        
        public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
            self.body(field)
        }
    }
}

extension FieldPresentations.Group: SwiftUIFormPresenting {
    private struct NavigationLinkView: View {
        @Environment(\.omniformPresentation) var presentationKind
        let model: FormModel
        
        var body: some View {
            if self.presentationKind == .navigation {
                NavigationLink(destination: DynamicView(OmniformView(model: model))) {
                    MetadataLabel(model.metadata, value: .constant(model))
                }
            } else {
                SectionView(model: self.model, caption: nil)
            }
        }
    }
    
    private struct SectionView: View {
        let model: FormModel
        let caption: String?
        
        var body: some View {
            SwiftUI.Section {
                OmniformContentView(model: self.model)
            } header: {
                MetadataLabel(self.model.metadata, value: .constant(model))
            } footer: {
                if let caption = self.caption {
                    Text(caption)
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    public func body<R>(for model: FormModel, id: AnyHashable, builder: some FieldVisiting<R>) -> R {
        let presentation = FieldPresentations.GroupPresentationTrampoline<FormModel> { _ in
            SwiftUI.Group {
                switch self {
                case .section(let section):
                    SectionView(model: model, caption: section.caption).erased
                case .screen:
                    NavigationLinkView(model: model).erased
                case .inline:
                    OmniformContentView(model: model)
                }
            }.erased
        }

        return builder.visit(field: model.metadata, id: id, using: presentation, through: bind(value: model))
    }
}

// MARK: - Nested

extension FieldPresentations.Nested: SwiftUIFieldPresenting where Wrapped: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> Wrapped.Body {
        switch self {
        case .subscript(let representation):
            let subBinding = binding.map(keyPath: representation.keyPath)
            return representation.wrapped.body(for: field, binding: subBinding)
        }
    }
}

// MARK: - None

extension FieldPresentations.None: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> EmptyView {
        EmptyView()
    }
}

// MARK: - Nullifying

extension FieldPresentations.Nullified: SwiftUIFieldPresenting where Presentation: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        switch self {
        case .matching(let content):
            let binding = binding.map {
                $0._optional ?? content.nilValue
            } set: {
                $0 == content.nilValue ? .some(nil) : .some($0)
            }
            
            return content.wrapped.body(for: field, binding: binding).erased
        }
    }
}

// MARK: - Documented

extension FieldPresentations.Documented: SwiftUIFieldPresenting where Presentation: SwiftUIFieldPresenting {
    private struct DocumentationView<Content: View>: View {
        @State var isShowingDoc: Bool = false
        
        var documentation: String
        let content: Content
        
        var body: some View {
            HStack {
                if !self.documentation.isEmpty {
                    Button {
                        self.isShowingDoc.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }.padding(.trailing)
                }
                
                self.content
                    .popover(isPresented: self.$isShowingDoc, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "info.circle")
                                .font(.largeTitle)
                            Text(self.documentation)
                            Spacer()
                        }.padding()
                    }
            }
        }
    }
    
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        switch self {
        case .docString(let info):
            let content = info.wrapped.body(for: field, binding: binding)
            return DocumentationView(documentation: info.documentation, content: content.erased).erased
        }
    }
}

// MARK: - View

extension FieldPresentations {
    public struct ViewPresentation<Value>: FieldPresenting where Value: SwiftUI.View {
        public typealias Value = Value
        
        public func body(for field: Metadata, binding: some ValueBinding<Value>) -> Value {
            binding.value
        }
    }
}

extension FieldPresenting where Value: SwiftUI.View {
    public static func view<T>() -> Self where
        Self == FieldPresentations.ViewPresentation<T>,
        Value == T
    {
        .init()
    }
}

// MARK: - Toggle

extension FieldPresentations.Toggle: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        let binding = binding.forSwiftUI
        return SwiftUI.Toggle(isOn: binding) {
            MetadataLabel(field, value: binding)
        }.erased
    }
}

// MARK: - TextInput

extension FieldPresentations.TextInput: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        let binding = binding.map { $0.description } set: { Value($0) }
        
        return SwiftUI.Group {
            switch self {
            case .secure:
                SwiftUI.SecureField<Text>(field.displayName, text: binding.forSwiftUI)
            case .regular:
                SwiftUI.TextField<Text>(field.displayName, text: binding.forSwiftUI)
                    .textContentType(nil)
                    .keyboardType(.asciiCapable)
            }
        }.erased
    }
}

// MARK: - Picker

extension FieldPresentations.Picker: SwiftUIFieldPresenting {
    private struct SelectionItem: View {
        @Binding var selection: Value?
        var value: Value
        
        init(value: Value, selection: Binding<Value?>) {
            self.value = value
            self._selection = selection
        }
        
        var body: some View {
            Button {
                self.selection = self.selection != self.value ? self.value : nil
            } label: {
                HStack {
                    Text(String(optionalyDescribing: self.value))
                        .foregroundColor(.primary)
                    Spacer()
                    if self.selection == self.value {
                        Image(systemName: "checkmark")
                            .renderingMode(.template)
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
    }
    
    private struct SelectionView: View {
        internal let allCases: [Value]
        @Binding var selection: Value?
        
        init(allCases: [Value], selection: Binding<Value?>) {
            self._selection = selection
            self.allCases = allCases
        }
        
        init(allCases: [Value], selection: Binding<Value>) {
            let binding: any WritableValueBinding<Value?> = selection.map(get: { $0 }, set: { $0 })
            self._selection = binding.forSwiftUI
            self.allCases = allCases
        }

        
        var body: some View {
            List(self.allCases, id: \.self) { item in
                SelectionItem(value: item, selection: self.$selection)
            }
        }
    }
    
    private struct SelectionScreenView: View {
        @Environment(\.presentationMode) var presentationMode
        internal let allCases: [Value]
        @Binding var selection: Value?
        
        
        init(allCases: [Value], selection: Binding<Value?>) {
            self._selection = selection
            self.allCases = allCases
        }
        
        init(allCases: [Value], selection: Binding<Value>) {
            let binding: any WritableValueBinding<Value?> = selection.map(get: { $0 }, set: { $0 })
            self._selection = binding.forSwiftUI
            self.allCases = allCases
        }

        
        var body: some View {
            let selectionView = SelectionView(allCases: self.allCases, selection: self.$selection)
            
            if #available(iOS 14.0, *) {
                selectionView
                    .onChange(of: self.selection) { newValue in
                        self.presentationMode.wrappedValue.dismiss()
                    }
            } else {
                selectionView
            }
        }
    }
    
    private struct PickerView: View {
        @Environment(\.omniformPresentation) var omniformPresentation
        let presentation: FieldPresentations.Picker<Value>
        let field: Metadata
        let binding: Binding<Value>
        let canDeselect: Bool
        
        var body: some View {
            let picker = SwiftUI.Picker(selection: binding) {
                ForEach(presentation.values, id: \.self) { item in
                    Text(String(optionalyDescribing: item))
                }
            } label: {
                MetadataLabel(field, value: binding)
            }

            return SwiftUI.Group {
                switch self.presentation.style {
                case .auto:
                    picker.pickerStyle(.automatic)
                case .inline:
                    SelectionView(allCases: presentation.values, selection: binding)
                case .segments:
                    picker.pickerStyle(.segmented)
                case .selection where self.omniformPresentation == .navigation:
                    if #available(iOS 16, *) {
                        picker.pickerStyle(.navigationLink)
                    } else {
                        NavigationLink {
                            DynamicView {
                                SelectionScreenView(allCases: presentation.values, selection: binding)
                                    .listStyle(.grouped)
                                    .navigationBarTitle(field.displayName, displayMode: .inline)
                            }
                        } label: {
                            HStack {
                                MetadataLabel(field, value: binding)
                                Spacer()
                                Text(String(optionalyDescribing: binding.value))
                                    .foregroundColor(Color.secondary)
                            }
                        }
                    }
                case .wheel where !canDeselect:
                    picker.pickerStyle(.wheel)
                case .menu where !canDeselect:
                    if #available(iOS 14, *) {
                        picker.pickerStyle(.menu)
                    } else {
                        picker.pickerStyle(.automatic)
                    }
                default:
                    picker.pickerStyle(.automatic)
                }
            }
        }
    }
    
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        let swiftUIBinding: Binding<Value>
        if let dv = self.deselectionValue {
            let mapped = binding.map { $0 } set: { $0 = $0 == $1 ? dv : $1 }
            swiftUIBinding = mapped.forSwiftUI
        } else {
            swiftUIBinding = binding.forSwiftUI
        }
        let canDeselect = self.deselectionValue != nil

        return PickerView(presentation: self, field: field, binding: swiftUIBinding, canDeselect: canDeselect).erased
    }
}

// MARK: - Slider

extension FieldPresentations.Slider: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        SwiftUI.Group {
            switch self {
            case .regular(let content):
                SwiftUI.Slider(
                    value: binding.forSwiftUI,
                    in: content.range,
                    step: content.step ?? content.range.lowerBound.distance(to: content.range.upperBound) / 100,
                    label: { Text(field.displayName) },
                    minimumValueLabel: { Text(String(format: "%.2f", Double(content.range.lowerBound))) },
                    maximumValueLabel: { Text(String(format: "%.2f", Double(content.range.upperBound))) }
                )
            }
        }.erased
    }
}

// MARK: - Stepper

extension FieldPresentations.Stepper: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        SwiftUI.Group {
            switch self {
            case .regular(let content):
                SwiftUI.Stepper(value: binding.forSwiftUI, in: content.range, step: content.step) {
                    HStack {
                        MetadataLabel(field, value: binding.forSwiftUI)
                        Spacer()
                        Text(String(describing: binding.value))
                    }.padding(.trailing)
                }
            }
        }.erased
    }
}

// MARK: - Button

extension FieldPresentations.Button: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        SwiftUI.Group {
            let label = MetadataLabel(field, value: binding.forSwiftUI)
            
            switch self {
            case .regular(let content):
                SwiftUI.Button(action: binding.value) {
                    switch content.role {
                    case .regular:
                        label
                    case .destructive:
                        MetadataLabel(field, value: binding.forSwiftUI)
                            //.fontWeight(.semibold)
                            .foregroundColor(.red)
                    default:
                        fatalError("unreachable")
                    }
                }
            }
        }.erased
    }
}

// MARK: - DatePicker

extension FieldPresentations.DatePickerComponents {
    fileprivate var swiftUI: DatePickerComponents {
        var componets: DatePickerComponents = []
        if self.contains(.date) {
            componets.insert(.date)
        }
        if self.contains(.hourAndMinute) {
            componets.insert(.hourAndMinute)
        }
        return componets
    }
}

extension FieldPresentations.DatePicker: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        SwiftUI.Group {
            switch self {
            case .inline(let content):
                switch (content.interval.start, content.interval.end) {
                case (.distantPast, .distantFuture):
                    SwiftUI.DatePicker(
                        selection: binding.forSwiftUI,
                        displayedComponents: content.components.swiftUI
                    ) {
                        MetadataLabel(field, value: binding.forSwiftUI)
                    }
                
                case (.distantPast, let future):
                    SwiftUI.DatePicker(
                        selection: binding.forSwiftUI,
                        in: ...future,
                        displayedComponents: content.components.swiftUI
                    ) {
                        MetadataLabel(field, value: binding.forSwiftUI)
                    }
                    
                case (let past, .distantFuture):
                    SwiftUI.DatePicker(
                        selection: binding.forSwiftUI,
                        in: past...,
                        displayedComponents: content.components.swiftUI
                    ) {
                        MetadataLabel(field, value: binding.forSwiftUI)
                    }

                case (let past, let future):
                    SwiftUI.DatePicker(
                        selection: binding.forSwiftUI,
                        in: past...future,
                        displayedComponents: content.components.swiftUI
                    ) {
                        MetadataLabel(field, value: binding.forSwiftUI)
                    }
                }
            }
        }.erased
    }
}

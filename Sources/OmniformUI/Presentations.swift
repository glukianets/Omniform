import Foundation
import SwiftUI
import Omniform

public protocol SwiftUIFieldPresenting<Value>: FieldPresenting {
    associatedtype Body: SwiftUI.View

    func body(for field: Metadata, binding: some ValueBinding<Value>) -> Body
}

public protocol SwiftUIGroupPresenting<Value>: GroupPresenting {
    func body<R>(for model: FormModel, binding: some ValueBinding<Value>, builder: some FieldVisiting<R>) -> [R]
}

// MARK: - Group

private extension Presentations {
    struct GroupPresentationTrampoline<Value>: SwiftUIFieldPresenting {
        typealias Value = Value
        
        @ViewBuilder
        let body: (Metadata) -> AnyView
        
        public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
            self.body(field)
        }
    }
}

extension Presentations.Group: SwiftUIGroupPresenting {
    private struct NavigationLinkView<Value>: View {
        @Environment(\.omniformPresentation) var presentationKind
        @State var isPresenting: Bool = false
        let model: FormModel
        @Binding var value: Value
        var format: AnyFormatStyle<Value, String>?

        var body: some View {
            if self.presentationKind != .standalone {
                NavigationLink(destination: DynamicView(OmniformView(model: model))) {
                    MetadataDisplay(model.metadata, value: self.$value, format: self.format)
                }
            } else {
                Button(action: { self.isPresenting.toggle() }) {
                    MetadataDisplay(model.metadata, value: self.$value, format: self.format)
                        .popover(isPresented: self.$isPresenting) {
                            OmniformView(model: model)
                        }
                }
            }
        }
    }
    
    private struct SectionView: View {
        let model: FormModel
        let caption: Metadata.Text?
        @Binding var value: Value

        var body: some View {
            SwiftUI.Section {
                OmniformContentView(model: self.model)
            } header: {
                MetadataLabel(self.model.metadata, value: self.$value)
            } footer: {
                if let caption = self.caption {
                    MetadataTextView(caption)
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    public func body<R>(for model: FormModel, binding: some ValueBinding<Value>, builder: some FieldVisiting<R>) -> [R] {
        let presentation: Presentations.GroupPresentationTrampoline<Value>
        
        switch self {
        case .section(let section):
            presentation = .init { _ in
                SectionView(model: model, caption: section.caption, value: binding.forSwiftUI).erased
            }
        case .screen(let content):
            presentation = .init { _ in
                NavigationLinkView(model: model, value: binding.forSwiftUI, format: content.format).erased
            }
        case .inline:
            presentation = .init { _ in
                OmniformContentView(model: model).erased
            }
        }

        return [builder.visit(field: model.metadata, id: model.metadata.id, using: presentation, through: binding)]
    }
}

// MARK: - Grouped

extension Presentations.Grouped: SwiftUIGroupPresenting, SwiftUIFieldPresenting where Group: SwiftUIGroupPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        if #available(iOS 16.0.0, *) {
            guard let presentation = self.fieldPresentation as? any SwiftUIFieldPresenting<Value> else {
                return EmptyView().erased
            }
            return presentation.body(for: field, binding: binding).erased
        } else {
            return EmptyView().erased
        }
    }
    
    public typealias Body = AnyView
    
    public func body<R>(for model: FormModel, binding: some ValueBinding<Value>, builder: some FieldVisiting<R>) -> [R] {
        self.groupPresentation?.body(for: model, binding: binding, builder: builder) ?? []
    }
}

// MARK: - Nested

extension Presentations.Nested: SwiftUIFieldPresenting where Wrapped: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> Wrapped.Body {
        switch self {
        case .subscript(let representation):
            let subBinding = binding.map(keyPath: representation.keyPath)
            return representation.wrapped.body(for: field, binding: subBinding)
        }
    }
}

// MARK: - None

extension Presentations.None: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> EmptyView {
        EmptyView()
    }
}

// MARK: - Nullifying

extension Presentations.Nullified: SwiftUIFieldPresenting where Presentation: SwiftUIFieldPresenting {
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

extension Presentations.Documented: SwiftUIFieldPresenting where Presentation: SwiftUIFieldPresenting {
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

extension Presentations {
    public struct ViewPresentation<Value>: FieldPresenting where Value: SwiftUI.View {
        public typealias Value = Value
        
        public func body(for field: Metadata, binding: some ValueBinding<Value>) -> Value {
            binding.value
        }
    }
}

extension FieldPresenting where Value: SwiftUI.View {
    public static func view<T>() -> Self where
        Self == Presentations.ViewPresentation<T>,
        Value == T
    {
        .init()
    }
}

// MARK: - Toggle

extension Presentations.Toggle: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        let binding = binding.forSwiftUI
        return SwiftUI.Toggle(isOn: binding) {
            MetadataLabel(field, value: binding)
        }.erased
    }
}

// MARK: - TextInput

extension Presentations.TextInput: SwiftUIFieldPresenting, SwiftUIGroupPresenting {
    private final class StateContainer: ObservableObject {
        @Published public var text: String
        
        public init(text: String) {
            self.text = text
        }
    }
    
    private struct Content: View {
        @Environment(\.omniformResourceResolver) var resourceResolver
        var metadata: Metadata
        var binding: any ValueBinding<Value>
        var presentation: Presentations.TextInput<Value>
        @StateObject var state: StateContainer = StateContainer(text: "")
        
        public init(metadata: Metadata, binding: any ValueBinding<Value>, presentation: Presentations.TextInput<Value>) {
            self.metadata = metadata
            self.binding = binding
            self.presentation = presentation
        }
        
        public var body: some View {
            return HStack {
                switch self.presentation {
                case .plain(let content):
                    let stringBinding = content.lower(binding: self.binding).forSwiftUI
                    
                    Group {
                        if #available(iOS 15.0, *) {
                            SwiftUI.TextField(text: self.$state.text) {
                                metadata.name.map(self.resourceResolver.text(_:)) ?? Text("?")
                            }
                        } else {
                            SwiftUI.TextField<Text>(
                                metadata.name.map(self.resourceResolver.string(_:)) ?? "?",
                                text: self.$state.text
                            )
                        }
                    }
                    .onAppear {
                        self.state.text = stringBinding.value
                    }
                    .onDisappear {
                        self.state.text = stringBinding.value
                    }
                    .onReceive(self.state.$text.debounce(for: .seconds(2), scheduler: RunLoop.main)) { newValue in
                        stringBinding.value = newValue
                    }

                case .secure(let content):
                    let stringBinding = content.lower(binding: self.binding).forSwiftUI

                    Group {
                        if #available(iOS 15.0, *) {
                            SwiftUI.SecureField(text: self.$state.text) {
                                metadata.name.map(self.resourceResolver.text(_:)) ?? Text("?")
                            }
                        } else {
                            SwiftUI.SecureField(
                                metadata.name.map(self.resourceResolver.string(_:)) ?? "?",
                                text: self.$state.text
                            )
                        }
                    }
                    .onAppear {
                        self.state.text = stringBinding.value
                    }
                    .onDisappear {
                        self.state.text = stringBinding.value
                    }
                    .onReceive(self.state.$text.debounce(for: .seconds(2), scheduler: RunLoop.main)) { newValue in
                        stringBinding.value = newValue
                    }

                case .format(let content):
                    if #available(iOS 15.0, *) {
                        SwiftUI.TextField(value: self.binding.forSwiftUI, format: content.format) {
                            self.resourceResolver.text(metadata.name ?? "?")
                        }
                    } else {
                        // this is unreachable since Format isn't constructible under iOS 15
                        EmptyView()
                    }
                }
                
                if !self.state.text.isEmpty {
                    Button {
                        self.state.text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }.padding(.leading)
                }
            }
            .textContentType(nil)
            .keyboardType(.asciiCapable)
        }
    }
    

    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        return Content(metadata: field, binding: binding.forSwiftUI, presentation: self).erased
    }
    
    public func body<R>(for model: FormModel, binding: some ValueBinding<Value>, builder: some FieldVisiting<R>) -> [R] {
        let style: Style
        switch self {
        case .plain(let content):
            style = content.style
        case .secure(let content):
            style = content.style
        case .format(let content):
            style = content.style
        }
        
        switch style {
        case .inline:
            fatalError("unreachable")
        case .screen:
            return Presentations.Group<Value>.screen().body(for: model, binding: binding, builder: builder)
        case .section:
            return Presentations.Group<Value>.section().body(for: model, binding: binding, builder: builder)
        case .custom(let presentation):
            guard let dd = dispatch(presentation: presentation, binding: binding) as? GroupViewBuilding else { return [] }
            return dd.build(model: model, id: model.metadata.id, builder: builder)
        }
    }
}

// MARK: - Picker

extension Presentations.Picker: SwiftUIFieldPresenting, SwiftUIGroupPresenting {
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
        public struct Options: OptionSet {
            public static var dismissOnSelection: Self { .init(rawValue: 1 << 1) }
            
            public var rawValue: UInt
            public init(rawValue: UInt) {
                self.rawValue = rawValue
            }
        }
        
        @Environment(\.presentationMode) var presentationMode
        internal let allCases: [Value]
        @Binding var selection: Value?
        internal let options: Options
        
        init(allCases: [Value], selection: Binding<Value?>, options: Options) {
            self._selection = selection
            self.allCases = allCases
            self.options = options
        }
        
        init(allCases: [Value], selection: Binding<Value>, options: Options) {
            let binding: any WritableValueBinding<Value?> = selection.map(get: { $0 }, set: { $0 })
            self._selection = binding.forSwiftUI
            self.allCases = allCases
            self.options = options
        }

        
        var body: some View {
            List(self.allCases, id: \.self) { item in
                SelectionItem(value: item, selection: self.$selection)
            }.onChange(of: self.selection) { newValue in
                guard self.options.contains(.dismissOnSelection) else { return }
                self.presentationMode.wrappedValue.dismiss()
            }

        }
    }
    
    private struct PickerView: View {
        @Environment(\.omniformPresentation) var omniformPresentation
        let presentation: Presentations.Picker<Value>
        let field: Metadata
        let binding: Binding<Value>
        let canDeselect: Bool
        
        var body: some View {
            let picker = SwiftUI.Picker(selection: binding) {
                ForEach(presentation.data.values, id: \.self) { item in
                    Text(String(optionalyDescribing: item))
                }
            } label: {
                MetadataLabel(field, value: binding)
            }

            return SwiftUI.Group {
                switch self.presentation {
                case .auto:
                    picker.pickerStyle(.automatic)
                case .segments:
                    picker.pickerStyle(.segmented)
                case let .selection(content):
                    SelectionView(
                        allCases: self.presentation.data.values,
                        selection: self.binding,
                        options: {
                            if
                                case .none = content.presentation,
                                self.omniformPresentation != .standalone
                            {
                                return .dismissOnSelection
                            } else {
                                return []
                            }
                        }()
                    )
#if os(iOS)
                case .wheel where !canDeselect:
                    picker.pickerStyle(.wheel)
#endif
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
        if let dv = self.data.deselectionValue {
            let mapped = binding.map { $0 } set: { $0 = $0 == $1 ? dv : $1 }
            swiftUIBinding = mapped.forSwiftUI
        } else {
            swiftUIBinding = binding.forSwiftUI
        }
        let canDeselect = self.data.deselectionValue != nil

        return PickerView(presentation: self, field: field, binding: swiftUIBinding, canDeselect: canDeselect).erased
    }
    
    public func body<R>(for model: FormModel, binding: some ValueBinding<Value>, builder: some FieldVisiting<R>) -> [R] {
        if
            case .selection(let content) = self,
            let presentation = content.presentation,
            let dispatch = dispatch(presentation: presentation, binding: binding) as? GroupViewBuilding
        {
            return dispatch.build(model: model, id: model.metadata.id, builder: builder)
        } else {
            return Presentations.Group<Value>.inline().body(for: model, binding: binding, builder: builder)
        }
    }
}

// MARK: - Slider

extension Presentations.Slider: SwiftUIFieldPresenting {
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        SwiftUI.Group {
            switch self {
            case .regular(let content):
                SwiftUI.Slider(
                    value: binding.forSwiftUI,
                    in: content.range,
                    step: content.step ?? content.range.lowerBound.distance(to: content.range.upperBound) / 100,
                    label: { MetadataLabel(field, value: binding.forSwiftUI) },
                    minimumValueLabel: { Text(String(format: "%.2f", Double(content.range.lowerBound))) },
                    maximumValueLabel: { Text(String(format: "%.2f", Double(content.range.upperBound))) }
                )
            }
        }.erased
    }
}

// MARK: - Stepper

extension Presentations.Stepper: SwiftUIFieldPresenting {
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

extension Presentations.Button: SwiftUIFieldPresenting {
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

extension Presentations.DatePickerComponents {
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

extension Presentations.DatePicker: SwiftUIFieldPresenting {
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

// MARK: - EitherPresentation

extension Presentations.EitherPresentation: SwiftUIFieldPresenting
where
    First: SwiftUIFieldPresenting,
    Second: SwiftUIFieldPresenting
{
    public func body(for field: Metadata, binding: some ValueBinding<Value>) -> AnyView {
        Group {
            switch self {
            case .first(let presentation):
                presentation.body(for: field, binding: binding)
            case .second(let presentation):
                presentation.body(for: field, binding: binding)
            }
        }.erased
    }
}

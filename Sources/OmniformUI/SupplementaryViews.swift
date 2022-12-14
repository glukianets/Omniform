import Foundation
import SwiftUI
import Combine

// MARK: - Metadata

internal struct MetadataImageView<Value>: View {
    @Environment(\.omniformResourceResolver) private var resourceResolver
    @Binding private var value: Value
    private let image: Metadata.Image
    
    public init(_ image: Metadata.Image, value: Binding<Value> = .constant(())) {
        self._value = value
        self.image = image
    }
    
    public var body: some View {
        self.resourceResolver.image(self.image, value: self.value)
    }
}

internal struct MetadataTextView<Value>: View {
    @Environment(\.omniformResourceResolver) private var resourceResolver
    @Binding private var value: Value
    private let text: Metadata.Text
    
    public init(_ text: Metadata.Text, value: Binding<Value> = .constant(())) {
        self._value = value
        self.text = text
    }
    
    public var body: some View {
        self.resourceResolver.text(self.text, value: self.value)
    }
}

internal struct MetadataLabel<Value>: View {
    @Environment(\.omniformResourceResolver) private var resourceResolver
    @Binding private var value: Value
    private let text: Metadata.Text?
    private let image: Metadata.Image?
    
    public init(_ metadata: Metadata, value: Binding<Value> = .constant(())) {
        self.init(text: metadata.name, image: metadata.icon, value: value)
    }

    public init(text: Metadata.Text?, image: Metadata.Image?, value: Binding<Value> = .constant(())) {
        self._value = value
        self.text = text
        self.image = image
    }
    
    public var body: some View {
        Label {
            if let view = self.text.map({ self.resourceResolver.text($0, value: self.value) }) {
                view
            } else {
                EmptyView()
            }
        } icon: {
            if let view = self.image.map({ self.resourceResolver.image($0, value: self.value) }) {
                view
            } else {
                EmptyView()
            }
        }
    }
}

internal struct MetadataDisplay<Value>: View {
    @Environment(\.omniformResourceResolver) private var resourceResolver
    @Binding private var value: Value
    private let text: Metadata.Text?
    private let image: Metadata.Image?
    private let format: AnyFormatStyle<Value, String>?
    
    public init(_ metadata: Metadata, value: Binding<Value>, format: AnyFormatStyle<Value, String>? = .default) {
        self.init(text: metadata.name, image: metadata.icon, value: value, format: format)
    }

    public init(
        text: Metadata.Text?,
        image: Metadata.Image?,
        value: Binding<Value>,
        format: AnyFormatStyle<Value, String>? = .default
    ) {
        self._value = value
        self.text = text
        self.image = image
        self.format = format
    }
    
    public var body: some View {
        HStack {
            MetadataLabel(text: self.text, image: self.image)
            if let format = self.format {
                Spacer()
                Formatted(value: self.$value, format: format)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
        }
    }
}

internal struct Formatted<Value>: View {
    @Binding private var value: Value
    private let format: AnyFormatStyle<Value, String>

    public init(value: Binding<Value>, format: AnyFormatStyle<Value, String>) {
        self._value = value
        self.format = format
    }

    public var body: Text {
        if let text = (self as? FormatTextBuilding)?.textView {
            return text
        } else {
            return Text(self.format.format(self.value))
        }
    }
}

private protocol FormatTextBuilding {
    var textView: Text? { get }
}

@available(iOS 15, macOS 13, *)
extension Formatted: FormatTextBuilding where Value: Equatable {
    var textView: Text? {
        Text(self.value, format: self.format)
    }
}

// MARK: - SplitNavigationView

internal struct SplitNavigationView: View {
    fileprivate struct Detail {
        let id: AnyHashable
        let view: () -> AnyView
        
        public init(id: some Hashable, @ViewBuilder view: @escaping () -> some View) {
            self.id = id
            self.view = { view().erased }
        }
    }
    
    @State var selection: AnyHashable? = nil
    @State var content: [AnyHashable: ImposedIdentity<AnyHashable, AnyView>] = [:]
    
    private let master: AnyView
    private let detail: AnyView
    
    public init<Master, Detail>(
        @ViewBuilder master: @escaping () -> Master,
        @ViewBuilder detail: @escaping () -> Detail
    ) where Master: View, Detail: View {
        self.master = master().erased
        self.detail = detail().erased
    }

    var body: some View {
        GeometryReader{ geometry in
            HStack {
                NavigationView {
                    self.master
                        .environment(\.splitViewSelection, self.$selection)
                }.frame(width: max(320, geometry.size.width / 3.0))
                Divider()
                NavigationView {
                    if let selection = self.selection, let content = self.content[selection] {
                        content.value
                    } else {
                        self.detail
                    }
                }
            }.navigationViewStyle(.stack)
        }
        .background(Color.primaryGroupedBackground.ignoresSafeArea())
        .onPreferenceChange(SplitNavigationViewContentKey.self) { content in
            self.content = content
        }
    }
}

fileprivate struct SplitNavigationViewSelectionKey: EnvironmentKey {
    static var defaultValue: Binding<AnyHashable?>? { nil }
}

extension EnvironmentValues {
    fileprivate var splitViewSelection: Binding<AnyHashable?>? {
        get { self[SplitNavigationViewSelectionKey.self] }
        set { self[SplitNavigationViewSelectionKey.self] = newValue }
    }
}

fileprivate struct SplitNavigationViewContentKey: PreferenceKey {
    static var defaultValue: [AnyHashable: ImposedIdentity<AnyHashable, AnyView>] = [:]
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { l, _ in l }
    }
}

internal struct SplitNavigationLink<Label, Destination>: View where Label: View, Destination: View {
    @Environment(\.splitViewSelection) var selection
    @State var id: AnyHashable = UUID()
    var tid: AnyHashable = UUID()
    var label: () -> Label
    var destination: () -> Destination
    
    public init(destination: @autoclosure @escaping () -> Destination, @ViewBuilder label: @escaping () -> Label) {
        self.destination = destination
        self.label = label
    }
    
    var body: some View {
        Group {
            if let selection = self.selection {
                Button {
                    selection.value = self.id
                } label: {
                    HStack {
                        self.label()
                            .foregroundColor(self.isSelected ? .primaryBackground : .primaryLabel)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundColor(self.isSelected ? .tertiaryBackground : .tertiaryLabel)
                    }
                }
                .listRowBackground(self.isSelected ? Color.accentColor : Color.secondaryGroupedBackground)
            } else {
                NavigationLink(destination: self.destination, label: self.label)
            }
        }
        .preference(
            key: SplitNavigationViewContentKey.self,
            value: [self.id: ImposedIdentity(id: self.tid, value: self.destination().erased)]
        )
    }
    
    private var isSelected: Bool {
        self.selection?.value == AnyHashable(self.id)
    }
}

// MARK: - Decoupler

internal struct Decoupler {
    private final class FormState<Value>: ObservableObject {
        @Published var value: Value {
            willSet {
                self.updateCount += 1;
                self.binding = newValue
            }
        }

        private var updateCount: Int = 0 {
            didSet {
                print("update: \(self.updateCount) @ \(ObjectIdentifier(self))")
            }
        }
        
        private var binding: Value {
            get { self._binding.value }
            set { self._binding.value = newValue; self.updateCount += 1; }
        }
        private var _binding: Binding<Value>
        private var cancellables: [AnyCancellable] = []

        public lazy var model: FormModel = {
            let binding = bind(object: self, through: \.value)
            return FormModel(binding)
        }()

        public init(binding: some ValueBinding<Value>) {
            self.value = binding.value
            self._binding = binding.forSwiftUI
        }

        public func update(binding: some ValueBinding<Value>) {
            self.value = binding.value
            self._binding = binding.forSwiftUI
        }
    }

    private struct DecouplingView<Value, Content: View>: View {
        @ObservedObject private var state: FormState<Value>
        private let binding: any ValueBinding<Value>
        private let content: (FormModel) -> Content
        
        public init(binding: any ValueBinding<Value>, content: @escaping (FormModel) -> Content) {
            self._state = .init(wrappedValue: .init(binding: binding))
            self.binding = binding
            self.content = content
        }
        
        public var body: some View {
            return self.content(self.state.model)
        }
    }
    
    private let binding: any ValueBinding
    
    public init(binding: some ValueBinding) {
        self.binding = binding
    }

    public init(form: FormModel) {
        self.init(binding: bind(value: form))
    }

    func body(@ViewBuilder _ content: @escaping (FormModel) -> some View) -> some View {
        Self.body(binding: self.binding, content: content).erased
    }

    private static func body(binding: some ValueBinding, content: @escaping (FormModel) -> some View) -> some View {
        DecouplingView(binding: binding, content: content).erased
    }
}


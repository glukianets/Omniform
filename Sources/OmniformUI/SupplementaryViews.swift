import Foundation
import SwiftUI

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
    private let format: AnyFormatStyle<Value, String>
    
    public init(_ metadata: Metadata, value: Binding<Value>, format: AnyFormatStyle<Value, String> = .default) {
        self.init(text: metadata.name, image: metadata.icon, value: value, format: format)
    }

    public init(
        text: Metadata.Text?,
        image: Metadata.Image?,
        value: Binding<Value>,
        format: AnyFormatStyle<Value, String> = .default
    ) {
        self._value = value
        self.text = text
        self.image = image
        self.format = format
    }
    
    public var body: some View {
        HStack {
            MetadataLabel(text: self.text, image: self.image)
            Spacer()
            Group {
                if let text = (self as? FormatTextBuilding)?.textView {
                    text
                } else {
                    Text(self.format.format(self.value))
                }
            }
            .foregroundColor(.secondary)
        }
    }
}

private protocol FormatTextBuilding {
    var textView: Text { get }
}

@available(iOS 15, macOS 13, *)
extension MetadataDisplay: FormatTextBuilding where Value: Equatable {
    var textView: Text {
        Text(self.value, format: self.format)
    }
}

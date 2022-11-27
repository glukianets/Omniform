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
    
    public init(_ metadata: Metadata, value: Binding<Value>) {
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

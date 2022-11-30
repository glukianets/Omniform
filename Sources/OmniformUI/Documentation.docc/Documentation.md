# ``OmniformUI``

Omniform is a library for generating comprehensive SwiftUI forms for arbitrary value types.

## Overview

Creating settings-like screens could never been easier! Consider you have a struct:
```swift
struct Hitchhiker {
    var name: String = ""
    var hasTowel: Bool = false
}
```

To present a beautiful settings-like screen, just pass a binding to it to ``Omniform`` view like so:
```swift
struct ContentView: View {
    @State var hitchhiker = Hitchhiker()

    var body: some View {
        Omniform(self.$hitchhiker)
    }
}
```

It'll produce the following ui:
![Simple ui example](readme_1)

You can further customize it using ``Field`` property wrapper:
```swift
struct Hitchhiker {
    @Field(name: "Individual name", icon: "tag", ui: .input(presentation: .section))
    var name: String = ""
    @Field(name: "Personal towel",  icon: "switch.2")
    var hasTowel: Bool = false
}
```

Which will give us this:
![Simple ui example](readme_2)

For further examples please refer to ``Samples``.

## Topics

### Basics

- ``Omniform``
- ``Field``
- ``FormModel``
- ``Samples``

### Views

- ``Omniform``
- ``OmniformView``

###

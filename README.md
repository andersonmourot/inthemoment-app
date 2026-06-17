# In The Moment

A native **SwiftUI** iOS app where artists and event companies post photos and
videos from their events, and fans can browse and **download** them to use however
they like.

Each creator can run **multiple independent events**; every event is its own page
that owns its own media collection.

## Features

- **Discover** — a public feed of published events, with search.
- **Event pages** — cover, details, and a grid of photos/videos.
- **Full-screen viewer** — view photos and play videos, then **Save to your photo library**.
- **Creator mode** — create events and upload photos/videos to each event from your library.
- **Profiles** — creator info and an account switcher (for the demo seed data).

## Architecture

The project is split into a platform-agnostic core and the SwiftUI app so the
business logic can be compiled and unit-tested on any platform (including Linux/CI),
while the UI stays iOS-native.

```
.
├── Package.swift                 # SwiftPM manifest for the core library
├── Sources/InTheMomentCore/      # Models + store + logic (no UIKit/SwiftUI)
│   ├── Models/                   # Creator, Event, MediaItem
│   ├── Store/                    # EventStore protocol + InMemoryEventStore (actor)
│   ├── EventFeed.swift           # Pure search/sort/group helpers
│   └── SampleData.swift          # Deterministic seed data
├── Tests/InTheMomentCoreTests/   # XCTest suite (runs on Linux)
├── App/InTheMoment/              # SwiftUI app (views, view-model, services)
├── project.yml                   # XcodeGen project definition (source of truth)
└── InTheMoment.xcodeproj         # Generated Xcode project
```

### Swappable backend

The app talks only to the [`EventStore`](Sources/InTheMomentCore/Store/EventStore.swift)
protocol, so the backend is a one-line injection into `AppModel` — no view changes.
Three implementations ship today:

| Store | Use |
| --- | --- |
| `InMemoryEventStore` | previews & tests |
| `FileEventStore` | on-device JSON persistence (app default) |
| `APIEventStore` | REST backend; the production path once a server exists |

```swift
AppModel(store: try FileEventStore(fileURL: url, seed: SampleData.makeState())) // default
AppModel(store: APIEventStore(baseURL: URL(string: "https://api.inthemoment.app/v1")!))
```

`APIEventStore`'s REST/JSON contract (ISO-8601 dates) is documented at the top of
[`APIEventStore.swift`](Sources/InTheMomentCore/Store/APIEventStore.swift); it takes an
injectable `HTTPTransport` so it is fully unit-tested without hitting the network.

## Requirements

- Xcode 15+ (iOS 16.0 deployment target)

## Open & run the iOS app

```bash
open InTheMoment.xcodeproj   # then run the "InTheMoment" scheme on a simulator
```

If you change files or the project layout, regenerate the project with
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
```

## Build & test the core (no Xcode needed)

```bash
swift build
swift test
```

CI runs `swift build` / `swift test` against the core library on Linux (see
`.github/workflows/ci.yml`).

> Note: the SwiftUI app target requires Apple's iOS SDK and is built from Xcode /
> `xcodebuild` on macOS; it is not built on the Linux CI job.

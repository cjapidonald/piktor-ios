# Piktor iOS - Pixel Art Studio

SwiftUI pixel art editor that connects to the shared Piktor Supabase backend. Users browse tasks, draw sprites with touch, and save artwork to cloud storage.

## Stack
- Swift 5.9 + SwiftUI (iOS 17+)
- supabase-swift 2.x (Auth, Database, Storage)
- Swift Package Manager
- No third-party UI libraries — pure SwiftUI

## Project Structure
```
piktor-ios/
├── Package.swift                        # SPM manifest (supabase-swift 2.x, iOS 17+)
├── Package.resolved                     # Locked deps (supabase-swift 2.43.1 + 7 transitive)
└── Sources/
    ├── PiktorApp.swift                  # @main entry: RootView (session check) → MainTabView or LoginView
    ├── Config.swift                     # AppConfig: Supabase URL, anon key, bundle ID, canvas defaults
    ├── Models/
    │   ├── Models.swift                 # Codable structs: Profile, World, PixelTask, Drawing, DrawingData, Frame, Layer
    │   │                                # TaskStatus enum (4 states: not_started, in_progress, review, done)
    │   │                                # Color.init(hex:) and .hexString helpers
    │   └── SupabaseManager.swift        # @MainActor singleton: auth, profiles, worlds, tasks, drawings CRUD,
    │                                    # thumbnail upload, dashboard stats computation
    ├── Views/
    │   ├── Auth/
    │   │   └── LoginView.swift          # 4-quadrant gradient bg, email/password, sign in/up toggle
    │   ├── Dashboard/
    │   │   └── DashboardView.swift      # Welcome header, 4 stat cards, world progress bars, pull-to-refresh
    │   ├── Tasks/
    │   │   └── TasksView.swift          # Filterable task list (world/status/mine), status cycling, Draw button
    │   └── Editor/
    │       ├── EditorView.swift         # Editor orchestrator: toolbar + canvas + magnification gesture (0.5x–5x)
    │       ├── PixelCanvasView.swift    # SwiftUI Canvas: checkerboard, pixel rendering, shape preview, touch handling
    │       ├── ToolBarView.swift        # Left sidebar: 11 tools (2-col grid) + undo/redo + mirror + color
    │       ├── ColorPickerView.swift    # 32-color palette grid (12 cols) + SwiftUI ColorPicker + hex display
    │       └── DrawingsGalleryView.swift # 2-column grid, thumbnails (AsyncImage), tap to edit, new drawing button
    └── Utils/
        ├── DrawingTools.swift           # Algorithms: floodFill (BFS), linePixels (Bresenham), rectanglePixels,
        │                                # circlePixels (midpoint), brushPixels, sprayPixels, mirrorPoints
        └── EditorState.swift            # @MainActor Observable: pixels, canvasSize, tool, color, undo/redo (50 max),
                                         # mirror mode, shape preview, zoom/pan, save to Supabase, PNG thumbnail gen
```

## How to Build

### Xcode (recommended)
1. File > Open > select `piktor-ios/Package.swift`
2. Wait for SPM dependency resolution
3. Select iOS 17+ simulator or device
4. Cmd+R to build and run

### Command Line
```bash
cd piktor-ios
xcodebuild -scheme Piktor -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' build
```

## Supabase Connection
- URL: `https://xrsmyzgdoqpqaimrtnrv.supabase.co`
- Anon key in `Sources/Config.swift`
- Auth: email/password, session persisted in Keychain by supabase-swift

### Tables Used
- profiles (id, full_name, role, avatar_url)
- worlds (id, name, theme, color_header)
- tasks (id, world_id, category, asset_name, description, sprites_needed, status, assigned_to)
- drawings (id, task_id, user_id, pixel_data JSON, image_url, timestamps)

### Storage
- Bucket: `drawings` — PNG thumbnails

## Editor
- **Canvas**: 32x32 default (up to 128), grid lines for <=64px, checkerboard transparency
- **11 Tools**: Pen, Brush, Spray, Eraser, Fill (BFS flood fill), Line (Bresenham), Rectangle, Circle (midpoint), Gradient, Eyedropper, Text
- **Mirror**: Horizontal / Vertical / Both
- **Undo/Redo**: Stack-based (50 states max)
- **Zoom**: Magnification gesture (0.5x–5x)
- **Color**: 32-color palette + native SwiftUI ColorPicker
- **Save**: UIGraphicsImageRenderer generates PNG thumbnail → uploads to Storage, saves DrawingData JSON to DB

## Architecture
- **SupabaseManager**: @MainActor singleton — all API calls, session management
- **EditorState**: @MainActor Observable — canvas state, tool selection, undo/redo, save
- **DrawingTools**: Static utility enum with pure drawing algorithms
- **Navigation**: 3-tab TabView (Dashboard, Tasks, Gallery) + NavigationStack to EditorView
- **Data format**: `{ frames: [{ layers: [{ name, visible, pixels }] }], fps }` — same as web/Android
- **Task status cycle**: not_started → in_progress → review → done (iOS has 4 states, web has 3)

## Related
- Web app: github.com/cjapidonald/piktor-web
- Android app: github.com/cjapidonald/piktor-android

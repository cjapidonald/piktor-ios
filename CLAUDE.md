# Piktor iOS - Pixel Art Editor

## Overview
Piktor is a SwiftUI-based iOS pixel art editor that connects to an existing Supabase backend. It allows team members to manage pixel art tasks, draw sprites using a touch-based editor, and save artwork to cloud storage.

## Project Structure
```
piktor-ios/
├── Package.swift                    # SPM manifest (supabase-swift 2.x, iOS 17+)
├── CLAUDE.md                        # This file
├── Sources/
│   ├── PiktorApp.swift            # @main App entry point
│   ├── Config.swift                 # Supabase URL + anon key
│   ├── Models/
│   │   ├── Models.swift             # Codable data models matching Supabase schema
│   │   └── SupabaseManager.swift    # Supabase client singleton + API methods
│   ├── Views/
│   │   ├── Auth/
│   │   │   └── LoginView.swift      # Email/password login with themed background
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift  # Stats cards + world progress bars
│   │   ├── Tasks/
│   │   │   └── TasksView.swift      # Task list with filters + status cycling
│   │   └── Editor/
│   │       ├── EditorView.swift     # Editor orchestrator (toolbar + canvas + palette)
│   │       ├── PixelCanvasView.swift # Custom Canvas for pixel drawing with touch
│   │       ├── ToolBarView.swift    # Tool selection (pen/eraser/fill/eyedropper)
│   │       ├── ColorPickerView.swift # 32-color palette grid
│   │       └── DrawingsGalleryView.swift # Saved drawings list
│   └── Utils/
│       ├── DrawingTools.swift       # BFS flood fill + drawing tool logic
│       └── EditorState.swift        # Observable editor state (canvas data, tool, color)
```

## How to Build

### Using Xcode (Recommended)
1. Open Xcode
2. File > Open > select `piktor-ios/Package.swift`
3. Wait for SPM to resolve dependencies
4. Select an iOS 17+ simulator or device
5. Build & Run (Cmd+R)

### Using Command Line
```bash
cd piktor-ios
swift build
```
Note: `swift build` will compile but the app runs on iOS so you need Xcode/simulator for full testing.

### Using xcodebuild
```bash
cd piktor-ios
xcodebuild -scheme Piktor -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' build
```

## Supabase Connection
- **URL**: `https://xrsmyzgdoqpqaimrtnrv.supabase.co`
- **Anon Key**: Stored in `Sources/Config.swift`
- **Auth**: Email/password via Supabase Auth (session persisted in Keychain by supabase-swift)
- **Database Tables**: profiles, worlds, tasks, drawings
- **Storage Bucket**: `drawings` (for thumbnail PNGs)

## Architecture
- **SupabaseManager**: Singleton holding the Supabase client, exposes async methods for all API calls
- **EditorState**: ObservableObject managing canvas pixel data, selected tool/color, undo/redo stacks
- **DrawingTools**: Static utility for flood fill (BFS), line drawing, and pixel operations
- **Views**: SwiftUI views using @StateObject/@EnvironmentObject for state management

## Data Flow
1. User logs in via LoginView -> Supabase auth session stored in Keychain
2. TabView shows Dashboard, Tasks, Admin tabs
3. Tasks can be opened in EditorView for drawing
4. Drawings saved as JSON (DrawingData) to Supabase `drawings` table
5. Thumbnail PNGs uploaded to Supabase Storage `drawings` bucket

## Key Dependencies
- [supabase-swift 2.x](https://github.com/supabase/supabase-swift) - Auth, Database, Storage, Realtime

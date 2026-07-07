# Scriptorium Bible Studio for iOS

Native SwiftUI/Core Data port of the Scriptorium Bible Studio workspace.

## Open in Xcode

Open:

```sh
ios/ScriptoriumBibleStudio/ScriptoriumBibleStudio.xcodeproj
```

Choose the `ScriptoriumBibleStudio` scheme and run on an iPhone or iPad simulator.

## Regenerate the project

The Xcode project is generated with XcodeGen from `project.yml`:

```sh
cd ios/ScriptoriumBibleStudio
xcodegen generate --spec project.yml
```

## Notes

- Persistent storage is implemented with Core Data using a programmatic model.
- First launch seeds sample books, chapters, collections, and a bookmark.
- The chapter editor uses a SwiftUI-wrapped `UITextView` with attributed text, selection-aware formatting, read-aloud, autosave, export, notes, bookmarks, search, and font settings.

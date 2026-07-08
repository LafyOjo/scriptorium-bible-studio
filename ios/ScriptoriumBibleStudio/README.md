# Scriptorium Bible Studio for iOS

Native SwiftUI/Core Data Bible authoring studio for writing your own manuscript version: books, chapters, rich text, annotations, bookmarks, read-aloud, search, export and local backup.

## Open in Xcode

Install XcodeGen once, then generate the project:

```sh
brew install xcodegen
cd ios/ScriptoriumBibleStudio
xcodegen generate --spec project.yml
```

Open `ios/ScriptoriumBibleStudio/ScriptoriumBibleStudio.xcodeproj`, choose the `ScriptoriumBibleStudio` scheme, and run on an iPhone or iPad simulator.

## Regenerate the project

The Xcode project is generated with XcodeGen from `project.yml`:

Run `xcodegen generate --spec project.yml` after changing `project.yml`, adding resources, or adding/removing Swift files.

## Fonts

The app bundles these OFL Google Fonts in `ScriptoriumBibleStudio/Resources/Fonts/`:

- `Cinzel[wght].ttf`
- `CormorantGaramond[wght].ttf`
- `CormorantGaramond-Italic[wght].ttf`
- `Inter[opsz,wght].ttf`
- `Inter-Italic[opsz,wght].ttf`

They are registered by `UIAppFonts` in `project.yml`:

```yaml
UIAppFonts:
  - Cinzel[wght].ttf
  - CormorantGaramond[wght].ttf
  - CormorantGaramond-Italic[wght].ttf
  - Inter[opsz,wght].ttf
  - Inter-Italic[opsz,wght].ttf
```

If you replace them with static font files later, update both `project.yml` and `SBTheme.FontName`.

## Reset Seed Data

In the app, open `Settings` and choose `Reset Sample Library`. This deletes the current local Core Data library and reseeds the starter manuscript scaffold: Genesis 1, Psalms 1, John 1, Revelation 1, collections and a bookmark.

For simulator-only testing, you can also delete the app from the simulator and run again.

## Notes

- Persistent local storage is implemented with Core Data using a programmatic model. Drafts, attributed RTF data, plain-text search copies, notes, bookmarks, tags, collections, statuses and writing settings are saved on device.
- The model includes stable UUID-string identifiers, created/updated timestamps, denormalized `plainText`, rich text binary data, note ranges, bookmark locations, and settings fields that are ready to map to CloudKit records later.
- The persistent store enables automatic lightweight migration, history tracking, remote-change notifications and `automaticallyMergesChangesFromParent`, which keeps the model CloudKit-ready while remaining local-only for the MVP.
- JSON backup/export round-trips the full library, including collections, books, chapters, notes, bookmarks and settings.
- First launch seeds sample content only as a scaffold; the UI copy frames every chapter as your version and your manuscript.
- The app uses an adaptive SwiftUI shell: iPad and regular-width layouts use a three-column `NavigationSplitView`, while compact iPhone layouts use bottom tabs and an editor/tools switch so menus and sidebars do not crowd portrait mode.
- Supported orientations are declared for portrait and landscape on iPhone, and portrait, upside-down portrait, and both landscape directions on iPad.
- The chapter editor uses a SwiftUI-wrapped `UITextView` with attributed text, selection-aware formatting, heading levels, paragraph/preformatted/quote styles, lists, alignment, super/subscript, strikethrough, indentation, semantic highlights, text colours, read-aloud, autosave, export, notes, bookmarks, search, tags and font settings.

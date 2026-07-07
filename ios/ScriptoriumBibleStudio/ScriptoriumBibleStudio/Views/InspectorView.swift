import CoreData
import SwiftUI

struct InspectorView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let chapter: SBChapter?
    let book: SBBook?
    @Binding var selectedText: String
    let bookmarks: [SBBookmark]

    @State private var tab: InspectorTab = .preview

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $tab) {
                ForEach(InspectorTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            Group {
                switch tab {
                case .preview:
                    PreviewPane(chapter: chapter, book: book)
                case .notes:
                    NotesPane(chapter: chapter, selectedText: $selectedText)
                case .bookmarks:
                    BookmarksPane(chapter: chapter, book: book, selectedText: $selectedText, bookmarks: bookmarks)
                case .metadata:
                    MetadataPane(chapter: chapter, book: book)
                }
            }
        }
        .navigationTitle("Inspector")
    }
}

private enum InspectorTab: String, CaseIterable, Identifiable {
    case preview
    case notes
    case bookmarks
    case metadata

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: return "Page"
        case .notes: return "Notes"
        case .bookmarks: return "Marks"
        case .metadata: return "Info"
        }
    }

    var systemImage: String {
        switch self {
        case .preview: return "doc.text"
        case .notes: return "note.text"
        case .bookmarks: return "bookmark"
        case .metadata: return "tag"
        }
    }
}

private struct PreviewPane: View {
    let chapter: SBChapter?
    let book: SBBook?

    var body: some View {
        ScrollView {
            if let chapter {
                VStack(spacing: 14) {
                    Panel(padding: 22) {
                        VStack(spacing: 12) {
                            Text(book?.name.uppercased() ?? "BOOK")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(ScriptoriumPalette.rose)
                                .tracking(1.5)
                            Text("Chapter \(chapter.number)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Divider()
                            AttributedPreview(
                                text: AttributedContent.fromRTFData(chapter.contentData),
                                isScrollEnabled: false
                            )
                            .frame(minHeight: 360)
                        }
                    }
                    .aspectRatio(0.72, contentMode: .fit)

                    ExportMenuButton(chapter: chapter, book: book)
                        .buttonStyle(.borderedProminent)
                        .tint(ScriptoriumPalette.indigo)
                }
                .padding()
            } else {
                EmptyStateView(
                    title: "Manuscript Preview",
                    message: "Open a chapter to preview it as a page.",
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
    }
}

private struct NotesPane: View {
    @Environment(\.managedObjectContext) private var viewContext

    let chapter: SBChapter?
    @Binding var selectedText: String

    @State private var noteText = ""
    @State private var theme: HighlightTheme?

    var body: some View {
        ScrollView {
            if let chapter {
                VStack(alignment: .leading, spacing: 14) {
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Selected Passage")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            if selectedText.isEmpty {
                                Text("Select text in the editor to attach a note.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(selectedText)
                                    .font(.callout)
                                    .italic()
                            }

                            Picker("Theme", selection: $theme) {
                                Text("No theme").tag(Optional<HighlightTheme>.none)
                                ForEach(HighlightTheme.allCases) { theme in
                                    Text(theme.label).tag(Optional(theme))
                                }
                            }

                            TextField("Write your note", text: $noteText, axis: .vertical)
                                .lineLimit(2...5)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                ScriptoriumActions.addNote(
                                    chapter: chapter,
                                    text: noteText,
                                    excerpt: selectedText,
                                    theme: theme,
                                    context: viewContext
                                )
                                noteText = ""
                                theme = nil
                            } label: {
                                Label("Add Note", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ScriptoriumPalette.teal)
                            .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedText.isEmpty)
                        }
                    }

                    Text("\(chapter.noteArray.count) notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(chapter.noteArray, id: \.objectID) { note in
                        Panel(padding: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    Text(note.excerpt)
                                        .font(.callout)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                    Spacer()
                                    Button(role: .destructive) {
                                        ScriptoriumActions.deleteNote(note, context: viewContext)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                Text(note.text)
                                    .font(.body)
                                if let theme = note.themeValue {
                                    TagChip(label: theme.label)
                                        .background(theme.color.opacity(0.16), in: Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            } else {
                EmptyStateView(title: "Notes", message: "Select a chapter to add annotations.", systemImage: "note.text")
            }
        }
    }
}

private struct BookmarksPane: View {
    @Environment(\.managedObjectContext) private var viewContext

    let chapter: SBChapter?
    let book: SBBook?
    @Binding var selectedText: String
    let bookmarks: [SBBookmark]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let book {
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bookmark Here")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack {
                                Button("Book") {
                                    ScriptoriumActions.addBookmark(book: book, chapter: nil, passage: nil, context: viewContext)
                                }
                                .buttonStyle(.bordered)

                                if let chapter {
                                    Button("Chapter") {
                                        ScriptoriumActions.addBookmark(book: book, chapter: chapter, passage: nil, context: viewContext)
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Passage") {
                                        ScriptoriumActions.addBookmark(book: book, chapter: chapter, passage: selectedText, context: viewContext)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(selectedText.isEmpty)
                                }
                            }
                        }
                    }
                }

                Text("Saved Bookmarks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if bookmarks.isEmpty {
                    EmptyStateView(title: "No Bookmarks", message: "Bookmark a book, chapter, or selected passage.", systemImage: "bookmark")
                } else {
                    ForEach(bookmarks, id: \.objectID) { bookmark in
                        Panel(padding: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(bookmark.label)
                                        .font(.headline)
                                    Text(bookmark.book?.name ?? "Book")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let passage = bookmark.passage {
                                        Text(passage)
                                            .font(.caption)
                                            .italic()
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    ScriptoriumActions.deleteBookmark(bookmark, context: viewContext)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

private struct MetadataPane: View {
    @Environment(\.managedObjectContext) private var viewContext

    let chapter: SBChapter?
    let book: SBBook?

    @State private var newTag = ""

    var body: some View {
        ScrollView {
            if let chapter {
                VStack(alignment: .leading, spacing: 14) {
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(book?.name ?? "Book")
                                .font(.title3.weight(.semibold))
                            Text("Chapter \(chapter.number)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            StatusPill(status: chapter.statusValue)
                            Text("Edited \(chapter.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tags")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            FlowLayout(spacing: 8) {
                                ForEach(chapter.tagArray, id: \.self) { tag in
                                    TagChip(label: tag) {
                                        ScriptoriumActions.removeTag(tag, from: chapter, context: viewContext)
                                    }
                                }
                            }
                            HStack {
                                TextField("Add tag", text: $newTag)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    ScriptoriumActions.addTag(newTag, to: chapter, context: viewContext)
                                    newTag = ""
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(.bordered)
                                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
                .padding()
            } else {
                EmptyStateView(title: "Metadata", message: "Select a chapter to edit tags and details.", systemImage: "tag")
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var current = CGSize.zero
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if current.width + size.width > maxWidth {
                current.width = 0
                current.height += lineHeight + spacing
                lineHeight = 0
            }
            current.width += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: current.height + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

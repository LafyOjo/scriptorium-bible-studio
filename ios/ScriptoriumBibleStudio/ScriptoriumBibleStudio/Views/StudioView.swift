import CoreData
import SwiftUI

struct StudioView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBBook.orderIndex, ascending: true)])
    private var books: FetchedResults<SBBook>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBChapter.updatedAt, ascending: false)])
    private var chapters: FetchedResults<SBChapter>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBCollection.name, ascending: true)])
    private var collections: FetchedResults<SBCollection>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBBookmark.createdAt, ascending: false)])
    private var bookmarks: FetchedResults<SBBookmark>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBNote.createdAt, ascending: false)])
    private var notes: FetchedResults<SBNote>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBAppSettings.id, ascending: true)])
    private var appSettings: FetchedResults<SBAppSettings>

    @State private var selectedSection: StudioSection = .dashboard
    @State private var selectedChapterID: String?
    @State private var selectedText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var activeChapter: SBChapter? {
        if let selectedChapterID,
           let chapter = chapters.first(where: { $0.id == selectedChapterID }) {
            return chapter
        }
        return chapters.first
    }

    private var activeBook: SBBook? {
        activeChapter?.book
    }

    private var settings: SBAppSettings? {
        appSettings.first
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedSection: $selectedSection,
                selectedChapterID: $selectedChapterID,
                books: Array(books),
                chapters: Array(chapters),
                collections: Array(collections),
                settings: settings,
                openChapter: openChapter
            )
            .navigationTitle("Scriptorium")
        } content: {
            contentView
                .navigationTitle(selectedSection.title)
                .studioBackground()
        } detail: {
            InspectorView(
                chapter: activeChapter,
                book: activeBook,
                selectedText: $selectedText,
                bookmarks: Array(bookmarks)
            )
            .studioBackground()
        }
        .onAppear {
            if selectedChapterID == nil {
                selectedChapterID = chapters.first?.id
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(
                books: Array(books),
                chapters: Array(chapters),
                bookmarks: Array(bookmarks),
                openChapter: openChapter,
                openLibrary: { selectedSection = .library }
            )
        case .library:
            LibraryView(
                books: Array(books),
                chapters: Array(chapters),
                settings: settings,
                openChapter: openChapter
            )
        case .editor:
            if let activeChapter, let activeBook {
                EditorView(
                    chapter: activeChapter,
                    book: activeBook,
                    settings: settings,
                    selectedText: $selectedText
                )
            } else {
                EmptyStateView(
                    title: "No Chapter Selected",
                    message: "Create or select a chapter to begin writing.",
                    systemImage: "text.book.closed"
                )
            }
        case .search:
            SearchView(
                chapters: Array(chapters),
                books: Array(books),
                openChapter: openChapter
            )
        case .settings:
            SettingsView(
                books: Array(books),
                chapters: Array(chapters),
                collections: Array(collections),
                notes: Array(notes),
                bookmarks: Array(bookmarks),
                settings: settings
            )
        }
    }

    private func openChapter(_ chapter: SBChapter) {
        selectedChapterID = chapter.id
        selectedSection = .editor
    }
}

import CoreData
import SwiftUI

struct LibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let books: [SBBook]
    let chapters: [SBChapter]
    let settings: SBAppSettings?
    let openChapter: (SBChapter) -> Void

    @State private var addBookPresented = false
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var expandedBookIDs: Set<String> = []
    @State private var renameTarget: LibraryRenameTarget?
    @State private var renameText = ""

    private var filteredBooks: [SBBook] {
        let query = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return books }

        return books.filter { book in
            let chapterText = book.chapterArray
                .map { "\($0.title) chapter \($0.number) \($0.tags) \($0.plainText)" }
                .joined(separator: " ")
            let searchable = "\(book.name) \(book.testamentValue.label) \(chapterText)".lowercased()
            return searchable.contains(query)
        }
    }

    private var completedChapters: Int {
        chapters.filter { $0.statusValue == .final }.count
    }

    private var progress: Double {
        chapters.isEmpty ? 0 : Double(completedChapters) / Double(chapters.count)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                libraryHeader
                searchField

                if filteredBooks.isEmpty {
                    ParchmentPanel {
                        EmptyStateView(
                            title: "No Volumes Found",
                            message: "Search by book, chapter title, tag, or phrase from your manuscript.",
                            systemImage: "books.vertical"
                        )
                        .frame(minHeight: 260)
                    }
                } else {
                    ForEach(filteredBooks, id: \.objectID) { book in
                        bookSection(book)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 96)
        }
        .safeAreaInset(edge: .bottom) {
            bottomCreateBar
        }
        .sheet(isPresented: $addBookPresented) {
            LibraryAddBookSheet(books: books, onCreate: { name, testament in
                let book = ScriptoriumActions.createBook(
                    name: name,
                    testament: testament,
                    collection: nil,
                    existingBooks: books,
                    context: viewContext
                )
                let chapter = ScriptoriumActions.createChapter(book: book, settings: settings, context: viewContext)
                expandedBookIDs.insert(book.id)
                openChapter(chapter)
            })
        }
        .alert("Rename", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Save") { applyRename() }
            Button("Cancel", role: .cancel) {
                renameTarget = nil
                renameText = ""
            }
        }
        .onAppear {
            debouncedSearchText = searchText
        }
        .onChange(of: searchText) { _, value in
            scheduleLibrarySearch(value)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var libraryHeader: some View {
        ParchmentPanel {
            VStack(alignment: .leading, spacing: 16) {
                ManuscriptHeader(
                    eyebrow: "Your Manuscript",
                    title: "Library",
                    subtitle: "\(books.count) books • \(chapters.count) chapters • \(Int(progress * 100))% final"
                )

                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(SBTheme.parchmentDeep)
                            Capsule()
                                .fill(SBTheme.gold)
                                .frame(width: max(8, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Label("\(completedChapters) final", systemImage: "checkmark.seal")
                        Spacer()
                        Label("\(chapters.count - completedChapters) in progress", systemImage: "pencil.line")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(SBTheme.mutedForeground)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SBTheme.mutedForeground)
            TextField("Search books, chapters, or manuscript text", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(SBTheme.mutedForeground)
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 14)
        .background(SBTheme.ivory, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SBTheme.border, lineWidth: 1)
        )
    }

    private var bottomCreateBar: some View {
        HStack {
            Button {
                addBookPresented = true
            } label: {
                Label("New Book", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(SBTheme.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func bookSection(_ book: SBBook) -> some View {
        let bookChapters = book.chapterArray
        let isExpanded = Binding(
            get: { !debouncedSearchText.isEmpty || expandedBookIDs.contains(book.id) },
            set: { expanded in
                if expanded {
                    expandedBookIDs.insert(book.id)
                } else {
                    expandedBookIDs.remove(book.id)
                }
            }
        )

        return ParchmentPanel(padding: 16) {
            DisclosureGroup(isExpanded: isExpanded) {
                VStack(spacing: 10) {
                    if bookChapters.isEmpty {
                        EmptyStateView(
                            title: "No Chapters Yet",
                            message: "Start the first chapter for \(book.name).",
                            systemImage: "doc.badge.plus"
                        )
                        .frame(minHeight: 160)
                    } else {
                        ForEach(bookChapters, id: \.objectID) { chapter in
                            chapterRow(chapter, book: book)
                        }
                    }

                    Button {
                        let chapter = ScriptoriumActions.createChapter(book: book, settings: settings, context: viewContext)
                        expandedBookIDs.insert(book.id)
                        openChapter(chapter)
                    } label: {
                        Label("Add Chapter", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(SBTheme.primary)
                }
                .padding(.top, 12)
            } label: {
                bookHeader(book)
            }
            .tint(SBTheme.primary)
            .contextMenu {
                Button { beginRename(.book(book)) } label: {
                    Label("Rename Book", systemImage: "pencil")
                }
                Button { ScriptoriumActions.moveBook(book, direction: .up, in: books, context: viewContext) } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                Button { ScriptoriumActions.moveBook(book, direction: .down, in: books, context: viewContext) } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                Button(role: .destructive) {
                    ScriptoriumActions.deleteBook(book, context: viewContext)
                } label: {
                    Label("Delete Book", systemImage: "trash")
                }
            }
        }
    }

    private func bookHeader(_ book: SBBook) -> some View {
        let bookChapters = book.chapterArray
        let finalCount = bookChapters.filter { $0.statusValue == .final }.count
        let bookProgress = bookChapters.isEmpty ? 0 : Double(finalCount) / Double(bookChapters.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.name)
                        .font(SBTheme.body(26, weight: .semibold))
                        .foregroundStyle(SBTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(book.testamentValue.label.uppercased())
                        .font(SBTheme.display(10, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(SBTheme.mutedForeground)
                }

                Spacer(minLength: 8)

                Text("\(bookChapters.count)")
                    .font(SBTheme.display(18, weight: .semibold))
                    .foregroundStyle(SBTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SBTheme.goldSoft.opacity(0.28), in: Capsule())
            }

            ProgressView(value: bookProgress)
                .tint(SBTheme.gold)
        }
        .contentShape(Rectangle())
    }

    private func chapterRow(_ chapter: SBChapter, book: SBBook) -> some View {
        Button {
            openChapter(chapter)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(chapter.number)")
                    .font(SBTheme.display(13, weight: .semibold))
                    .foregroundStyle(SBTheme.gold)
                    .frame(width: 28, height: 28)
                    .background(SBTheme.goldSoft.opacity(0.24), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(chapter.title)
                            .font(.headline)
                            .foregroundStyle(SBTheme.ink)
                            .lineLimit(2)
                        Spacer(minLength: 10)
                        StatusPill(status: chapter.statusValue)
                    }

                    HStack(spacing: 10) {
                        Text("\(wordCount(chapter)) words")
                        Text(chapter.updatedAt, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(SBTheme.mutedForeground)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(SBTheme.parchment.opacity(0.54), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { beginRename(.chapter(chapter)) } label: {
                Label("Rename Chapter", systemImage: "pencil")
            }
            Button { ScriptoriumActions.moveChapter(chapter, direction: .up, in: book, context: viewContext) } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            Button { ScriptoriumActions.moveChapter(chapter, direction: .down, in: book, context: viewContext) } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            Button(role: .destructive) {
                ScriptoriumActions.deleteChapter(chapter, context: viewContext)
            } label: {
                Label("Delete Chapter", systemImage: "trash")
            }
        }
    }

    private func beginRename(_ target: LibraryRenameTarget) {
        renameTarget = target
        renameText = target.currentName
    }

    private func applyRename() {
        guard let renameTarget else { return }
        switch renameTarget {
        case .book(let book):
            ScriptoriumActions.renameBook(book, name: renameText, context: viewContext)
        case .chapter(let chapter):
            ScriptoriumActions.renameChapter(chapter, title: renameText, context: viewContext)
        }
        self.renameTarget = nil
        renameText = ""
    }

    private func scheduleLibrarySearch(_ value: String) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            debouncedSearchText = value
        }
    }

    private func wordCount(_ chapter: SBChapter) -> Int {
        chapter.plainText.split { $0.isWhitespace || $0.isNewline }.count
    }
}

private struct ManuscriptHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(SBTheme.display(10, weight: .semibold))
                .tracking(2.6)
                .foregroundStyle(SBTheme.crimson)
            Text(title)
                .font(SBTheme.body(36, weight: .semibold))
                .foregroundStyle(SBTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(SBTheme.mutedForeground)
        }
    }
}

private enum LibraryRenameTarget: Identifiable {
    case book(SBBook)
    case chapter(SBChapter)

    var id: String {
        switch self {
        case .book(let book): return book.objectID.uriRepresentation().absoluteString
        case .chapter(let chapter): return chapter.objectID.uriRepresentation().absoluteString
        }
    }

    var currentName: String {
        switch self {
        case .book(let book): return book.name
        case .chapter(let chapter): return chapter.title
        }
    }
}

private struct LibraryAddBookSheet: View {
    @Environment(\.dismiss) private var dismiss

    let books: [SBBook]
    let onCreate: (String, Testament) -> Void

    @State private var name = ""
    @State private var testament: Testament = .custom

    var body: some View {
        NavigationStack {
            ScrollView {
                ParchmentPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        ManuscriptHeader(
                            eyebrow: "New Volume",
                            title: "Add Book",
                            subtitle: "Create a custom book or section for your manuscript structure."
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SBTheme.mutedForeground)
                                .textCase(.uppercase)
                            TextField("Book or section name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        Picker("Testament", selection: $testament) {
                            ForEach(Testament.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Book")
            .studioBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, testament)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Library") {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext
    let books = (try? context.fetch(SBBook.fetchRequest())) ?? []
    let chapters = (try? context.fetch(SBChapter.fetchRequest())) ?? []
    let settings = (try? context.fetch(SBAppSettings.fetchRequest()))?.first

    return NavigationStack {
        LibraryView(books: books, chapters: chapters, settings: settings) { _ in }
            .studioBackground()
    }
    .environment(\.managedObjectContext, context)
}

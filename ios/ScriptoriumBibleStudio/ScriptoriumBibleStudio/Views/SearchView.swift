import SwiftUI

struct SearchView: View {
    let chapters: [SBChapter]
    let books: [SBBook]
    let bookmarks: [SBBookmark]
    let openChapter: (SBChapter) -> Void

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var selectedTheme: HighlightTheme?
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>?

    private func makeResults(query: String, theme: HighlightTheme?) -> [SearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bookmarksByChapter = Dictionary(grouping: bookmarks) { bookmark in
            bookmark.chapter?.objectID.uriRepresentation().absoluteString ?? bookmark.chapterID ?? ""
        }

        return chapters.compactMap { chapter in
            let book = chapter.book ?? books.first { book in
                book.chapterArray.contains { $0.objectID == chapter.objectID }
            }
            let bookName = book?.name ?? ""
            let chapterKey = chapter.objectID.uriRepresentation().absoluteString
            let text = chapter.plainText
            let lowerText = text.lowercased()
            let notes = chapter.noteArray
            let chapterBookmarks = (bookmarksByChapter[chapterKey] ?? []) + (bookmarksByChapter[chapter.id] ?? [])

            let matchesQuery = cleanQuery.isEmpty
                || lowerText.contains(cleanQuery)
                || bookName.lowercased().contains(cleanQuery)
                || "\(bookName) \(chapter.number)".lowercased().contains(cleanQuery)
                || "chapter \(chapter.number)".contains(cleanQuery)
                || chapter.title.lowercased().contains(cleanQuery)
                || chapter.tagArray.contains { $0.lowercased().contains(cleanQuery) }
                || notes.contains { $0.text.lowercased().contains(cleanQuery) || $0.excerpt.lowercased().contains(cleanQuery) }
                || chapterBookmarks.contains { bookmarkMatches($0, query: cleanQuery) }

            let matchesTheme: Bool
            if let theme {
                matchesTheme = chapter.themeArray.contains(theme)
                    || notes.contains { $0.themeValue == theme }
            } else {
                matchesTheme = true
            }

            guard matchesQuery && matchesTheme else { return nil }

            let match = matchContext(
                chapterText: text,
                notes: notes,
                bookmarks: chapterBookmarks,
                query: cleanQuery
            )

            return SearchResult(
                id: chapterKey,
                chapter: chapter,
                bookName: bookName.isEmpty ? "Book" : bookName,
                excerpt: match.excerpt,
                source: match.source
            )
        }
        .sorted { $0.chapter.updatedAt > $1.chapter.updatedAt }
    }

    var body: some View {
        ScrollView {
            searchHeader

            LazyVStack(spacing: 12) {
                if results.isEmpty {
                    ParchmentPanel {
                        EmptyStateView(
                            title: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedTheme == nil ? "Search Your Manuscript" : "No Results",
                            message: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedTheme == nil
                                ? "Look across chapters, notes, bookmarks, tags and highlight colours."
                                : "Try another phrase, book, chapter, note, bookmark, tag, or highlight colour.",
                            systemImage: "magnifyingglass"
                        )
                        .frame(minHeight: 300)
                    }
                } else {
                    ForEach(results) { result in
                        searchResultCard(result)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .onAppear { scheduleSearch(immediate: true) }
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onChange(of: selectedTheme) { _, _ in scheduleSearch() }
        .onChange(of: chapters.map(\.updatedAt)) { _, _ in scheduleSearch(immediate: true) }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func searchResultCard(_ result: SearchResult) -> some View {
        Button {
            openChapter(result.chapter)
        } label: {
            ParchmentPanel(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(result.bookName) \(result.chapter.number)")
                                .font(SBTheme.display(10, weight: .semibold))
                                .tracking(1.8)
                                .foregroundStyle(SBTheme.crimson)
                            Text(result.chapter.title)
                                .font(SBTheme.body(24, weight: .semibold))
                                .foregroundStyle(SBTheme.ink)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 10)
                        StatusPill(status: result.chapter.statusValue)
                    }

                    Text(result.source.uppercased())
                        .font(SBTheme.display(9, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(SBTheme.gold)

                    HighlightedExcerpt(text: result.excerpt, query: debouncedQuery)
                        .lineLimit(4)

                    if !result.chapter.tagArray.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(result.chapter.tagArray, id: \.self) { tag in
                                TagChip(label: tag)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var searchHeader: some View {
        ParchmentPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Manuscript Index")
                            .font(SBTheme.display(10, weight: .semibold))
                            .tracking(2.2)
                            .foregroundStyle(SBTheme.crimson)
                            .textCase(.uppercase)
                        Text("Search")
                            .font(SBTheme.body(34, weight: .semibold))
                            .foregroundStyle(SBTheme.primary)
                    }
                    Spacer()
                    Text("\(results.count)")
                        .font(SBTheme.display(24, weight: .semibold))
                        .foregroundStyle(SBTheme.gold)
                        .frame(width: 54, height: 54)
                        .background(SBTheme.goldSoft.opacity(0.24), in: Circle())
                }

                HStack(spacing: 10) {
                    Label("Query", systemImage: "magnifyingglass")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(SBTheme.mutedForeground)
                    TextField("Search chapters, notes, bookmarks and tags", text: $query)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SBTheme.mutedForeground)
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(SBTheme.parchment.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SBTheme.border, lineWidth: 1)
                )

                Picker("Highlight", selection: $selectedTheme) {
                    Text("Any Highlight").tag(Optional<HighlightTheme>.none)
                    ForEach(HighlightTheme.allCases) { theme in
                        Text(theme.label).tag(Optional(theme))
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private func excerpt(for text: String, query: String) -> String {
        guard !query.isEmpty, let range = text.lowercased().range(of: query) else {
            return String(text.prefix(180))
        }

        let start = text.index(range.lowerBound, offsetBy: -60, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 90, limitedBy: text.endIndex) ?? text.endIndex
        return "..." + text[start..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func bookmarkMatches(_ bookmark: SBBookmark, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return bookmark.label.lowercased().contains(query)
            || bookmark.passage?.lowercased().contains(query) == true
            || bookmark.snippet?.lowercased().contains(query) == true
    }

    private func matchContext(
        chapterText: String,
        notes: [SBNote],
        bookmarks: [SBBookmark],
        query: String
    ) -> SearchMatchContext {
        if !query.isEmpty,
           let bookmark = bookmarks.first(where: { bookmarkMatches($0, query: query) }) {
            return SearchMatchContext(
                source: "Bookmark",
                excerpt: bookmark.snippet ?? bookmark.passage ?? bookmark.label
            )
        }

        if !query.isEmpty,
           let note = notes.first(where: { $0.text.lowercased().contains(query) || $0.excerpt.lowercased().contains(query) }) {
            return SearchMatchContext(source: "Note", excerpt: note.excerpt.isEmpty ? note.text : note.excerpt)
        }

        if !query.isEmpty {
            return SearchMatchContext(source: "Manuscript", excerpt: excerpt(for: chapterText, query: query))
        }

        if let bookmark = bookmarks.first {
            return SearchMatchContext(source: "Bookmark", excerpt: bookmark.snippet ?? bookmark.passage ?? bookmark.label)
        }

        return SearchMatchContext(source: "Manuscript", excerpt: String(chapterText.prefix(180)))
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let pendingQuery = query
        let pendingTheme = selectedTheme
        searchTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(350))
            }
            guard !Task.isCancelled else { return }
            debouncedQuery = pendingQuery
            results = makeResults(query: pendingQuery, theme: pendingTheme)
        }
    }
}

private struct SearchResult: Identifiable {
    let id: String
    let chapter: SBChapter
    let bookName: String
    let excerpt: String
    let source: String
}

private struct SearchMatchContext {
    let source: String
    let excerpt: String
}

private struct HighlightedExcerpt: View {
    let text: String
    let query: String

    var body: some View {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanQuery.isEmpty,
           let range = text.range(of: cleanQuery, options: [.caseInsensitive, .diacriticInsensitive]) {
            Text(String(text[..<range.lowerBound]))
                .font(.callout)
                .foregroundStyle(SBTheme.mutedForeground)
            + Text(String(text[range]))
                .font(.callout.weight(.semibold))
                .foregroundStyle(SBTheme.crimson)
            + Text(String(text[range.upperBound...]))
                .font(.callout)
                .foregroundStyle(SBTheme.mutedForeground)
        } else {
            Text(text)
                .font(.callout)
                .foregroundStyle(SBTheme.mutedForeground)
        }
    }
}

#Preview("Search") {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext
    let books = (try? context.fetch(SBBook.fetchRequest())) ?? []
    let chapters = (try? context.fetch(SBChapter.fetchRequest())) ?? []
    let bookmarks = (try? context.fetch(SBBookmark.fetchRequest())) ?? []

    return NavigationStack {
        SearchView(chapters: chapters, books: books, bookmarks: bookmarks) { _ in }
            .studioBackground()
    }
    .environment(\.managedObjectContext, context)
}

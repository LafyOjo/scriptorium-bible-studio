import SwiftUI

struct SearchView: View {
    let chapters: [SBChapter]
    let books: [SBBook]
    let openChapter: (SBChapter) -> Void

    @State private var query = ""
    @State private var selectedTheme: HighlightTheme?

    private var results: [SearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return chapters.compactMap { chapter in
            let book = chapter.book ?? books.first { $0.id == chapter.book?.id }
            let text = chapter.plainText
            let notes = chapter.noteArray

            let matchesQuery = cleanQuery.isEmpty
                || text.lowercased().contains(cleanQuery)
                || chapter.title.lowercased().contains(cleanQuery)
                || chapter.tagArray.contains { $0.lowercased().contains(cleanQuery) }
                || notes.contains { $0.text.lowercased().contains(cleanQuery) || $0.excerpt.lowercased().contains(cleanQuery) }

            let matchesTheme: Bool
            if let selectedTheme {
                matchesTheme = chapter.themeArray.contains(selectedTheme)
                    || notes.contains { $0.themeValue == selectedTheme }
            } else {
                matchesTheme = true
            }

            guard matchesQuery && matchesTheme else { return nil }

            let excerpt = excerpt(for: text, query: cleanQuery)
            return SearchResult(chapter: chapter, bookName: book?.name ?? "Book", excerpt: excerpt)
        }
        .sorted { $0.chapter.updatedAt > $1.chapter.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            if results.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    message: "Try another phrase, tag, note, or highlight colour.",
                    systemImage: "magnifyingglass"
                )
            } else {
                List(results) { result in
                    Button {
                        openChapter(result.chapter)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(result.bookName) \(result.chapter.number)")
                                    .font(.headline)
                                Spacer()
                                StatusPill(status: result.chapter.statusValue)
                            }
                            Text(result.chapter.title)
                                .font(.title3.weight(.semibold))
                            Text(result.excerpt)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                            if !result.chapter.tagArray.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(result.chapter.tagArray, id: \.self) { tag in
                                        TagChip(label: tag)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search")
                .font(.largeTitle.weight(.semibold))

            HStack(spacing: 10) {
                Label("Query", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                TextField("Search across chapters, notes, and tags", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            Picker("Highlight", selection: $selectedTheme) {
                Text("Any Highlight").tag(Optional<HighlightTheme>.none)
                ForEach(HighlightTheme.allCases) { theme in
                    Text(theme.label).tag(Optional(theme))
                }
            }
            .pickerStyle(.menu)

            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(20)
        .background(.thinMaterial)
    }

    private func excerpt(for text: String, query: String) -> String {
        guard !query.isEmpty, let range = text.lowercased().range(of: query) else {
            return String(text.prefix(180))
        }

        let start = text.index(range.lowerBound, offsetBy: -60, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 90, limitedBy: text.endIndex) ?? text.endIndex
        return "..." + text[start..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

private struct SearchResult: Identifiable {
    let id = UUID()
    let chapter: SBChapter
    let bookName: String
    let excerpt: String
}

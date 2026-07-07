import CoreData
import SwiftUI

struct SidebarView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @Binding var selectedSection: StudioSection
    @Binding var selectedChapterID: String?

    let books: [SBBook]
    let chapters: [SBChapter]
    let collections: [SBCollection]
    let settings: SBAppSettings?
    let openChapter: (SBChapter) -> Void

    @State private var addBookPresented = false
    @State private var addCollectionPresented = false
    @State private var newCollectionName = ""

    var body: some View {
        List {
            Section {
                ForEach(StudioSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                    }
                }
            }

            Section {
                ForEach(books, id: \.objectID) { book in
                    DisclosureGroup {
                        ForEach(book.chapterArray, id: \.objectID) { chapter in
                            Button {
                                openChapter(chapter)
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(chapter.statusValue.tint)
                                        .frame(width: 7, height: 7)
                                    Text("\(chapter.number). \(chapter.title)")
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(chapter.id == selectedChapterID ? ScriptoriumPalette.indigo : .primary)
                        }

                        Button {
                            let chapter = ScriptoriumActions.createChapter(book: book, settings: settings, context: viewContext)
                            openChapter(chapter)
                        } label: {
                            Label("New Chapter", systemImage: "plus")
                        }
                        .font(.caption)
                    } label: {
                        Label {
                            HStack {
                                Text(book.name)
                                Spacer()
                                Text("\(book.chapterArray.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "book.closed")
                                .foregroundStyle(ScriptoriumPalette.gold)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Books")
                    Spacer()
                    Button {
                        addBookPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Section {
                ForEach(collections, id: \.objectID) { collection in
                    Label(collection.name, systemImage: "folder")
                }

                Button {
                    addCollectionPresented = true
                } label: {
                    Label("New Collection", systemImage: "folder.badge.plus")
                }
            } header: {
                Text("Collections")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SCRIPTORIUM")
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .tracking(1.2)
                Text("Bible Studio")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .sheet(isPresented: $addBookPresented) {
            AddBookSheet(
                books: books,
                collections: collections,
                onCreate: { name, testament, collection in
                    let book = ScriptoriumActions.createBook(
                        name: name,
                        testament: testament,
                        collection: collection,
                        existingBooks: books,
                        context: viewContext
                    )
                    let chapter = ScriptoriumActions.createChapter(book: book, settings: settings, context: viewContext)
                    openChapter(chapter)
                }
            )
        }
        .alert("New Collection", isPresented: $addCollectionPresented) {
            TextField("Collection name", text: $newCollectionName)
            Button("Create") {
                if !newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScriptoriumActions.createCollection(name: newCollectionName, context: viewContext)
                }
                newCollectionName = ""
            }
            Button("Cancel", role: .cancel) {
                newCollectionName = ""
            }
        }
    }
}

private struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss

    let books: [SBBook]
    let collections: [SBCollection]
    let onCreate: (String, Testament, SBCollection?) -> Void

    @State private var name = ""
    @State private var testament: Testament = .custom
    @State private var collectionID: String = ""

    var selectedCollection: SBCollection? {
        collections.first { $0.id == collectionID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Name", text: $name)
                    Picker("Testament", selection: $testament) {
                        ForEach(Testament.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    Picker("Collection", selection: $collectionID) {
                        Text("None").tag("")
                        ForEach(collections, id: \.id) { collection in
                            Text(collection.name).tag(collection.id)
                        }
                    }
                }
            }
            .navigationTitle("New Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, testament, selectedCollection)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

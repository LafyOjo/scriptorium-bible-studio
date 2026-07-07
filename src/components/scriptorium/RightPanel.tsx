import { useEffect, useMemo, useRef, useState } from "react";
import { Bookmark as BookmarkIcon, Download, FileJson, FileText, Search, StickyNote, Trash2, X } from "lucide-react";
import { THEME_COLORS, type HighlightTheme } from "@/lib/scriptorium/types";
import type { Bookmark, Chapter, Book, ScriptoriumState } from "@/lib/scriptorium/store";
import { htmlToPlainText } from "@/lib/scriptorium/store";
import { cn } from "@/lib/utils";

type Props = {
  state: ScriptoriumState;
  activeChapter: Chapter | null;
  activeBook: Book | null;
  selectionText: string;
  onAddBookmark: (b: Omit<Bookmark, "id" | "createdAt">) => void;
  onRemoveBookmark: (id: string) => void;
  onAddNote: (chapterId: string, note: { text: string; excerpt: string; theme?: HighlightTheme }) => void;
  onRemoveNote: (chapterId: string, noteId: string) => void;
  onSelectChapter: (id: string) => void;
};

type Tab = "notes" | "bookmarks" | "search" | "preview";

export function RightPanel(p: Props) {
  const [tab, setTab] = useState<Tab>("preview");
  return (
    <aside className="flex h-full min-h-0 w-80 shrink-0 flex-col parchment-panel rounded-2xl overflow-hidden">
      <div className="flex border-b border-border/60">
        {([
          { k: "preview", icon: FileText, label: "Page" },
          { k: "notes", icon: StickyNote, label: "Notes" },
          { k: "bookmarks", icon: BookmarkIcon, label: "Marks" },
          { k: "search", icon: Search, label: "Search" },
        ] as const).map((t) => (
          <button
            key={t.k}
            onClick={() => setTab(t.k)}
            className={cn(
              "flex-1 flex flex-col items-center gap-0.5 py-2.5 text-[10px] uppercase tracking-widest",
              tab === t.k ? "bg-ivory text-primary border-b-2 border-gold" : "text-muted-foreground hover:text-primary",
            )}
          >
            <t.icon className="h-4 w-4" />
            {t.label}
          </button>
        ))}
      </div>

      <div className="flex-1 overflow-auto">
        {tab === "preview" && <PagePreview chapter={p.activeChapter} book={p.activeBook} />}
        {tab === "notes" && (
          <NotesTab chapter={p.activeChapter} selectionText={p.selectionText}
            onAdd={p.onAddNote} onRemove={p.onRemoveNote} />
        )}
        {tab === "bookmarks" && (
          <BookmarksTab
            bookmarks={p.state.bookmarks} chapters={p.state.chapters} books={p.state.books}
            activeChapter={p.activeChapter} activeBook={p.activeBook} selectionText={p.selectionText}
            onAdd={p.onAddBookmark} onRemove={p.onRemoveBookmark} onSelect={p.onSelectChapter}
          />
        )}
        {tab === "search" && (
          <SearchTab state={p.state} onSelect={p.onSelectChapter} />
        )}
      </div>

      {p.activeChapter && (
        <ExportBar chapter={p.activeChapter} book={p.activeBook} state={p.state} />
      )}
    </aside>
  );
}

function PagePreview({ chapter, book }: { chapter: Chapter | null; book: Book | null }) {
  if (!chapter || !book) {
    return <EmptyPanel title="Manuscript Preview" body="Open a chapter to see it rendered as a manuscript page." />;
  }
  return (
    <div className="p-4">
      <div className="manuscript-page rounded-md p-6 aspect-[3/4] overflow-hidden relative">
        <div className="absolute inset-4 border border-gold/40 rounded-sm pointer-events-none" />
        <div className="text-center font-display text-[10px] tracking-[0.4em] text-oxblood">
          {book.name.toUpperCase()}
        </div>
        <div className="text-center font-display text-xs tracking-[0.3em] text-primary/80 mt-1">
          CHAPTER {chapter.number}
        </div>
        <div className="gold-divider my-3" />
        <div
          className="reader-prose font-serif text-[10px] leading-snug text-ink max-h-[70%] overflow-hidden"
          dangerouslySetInnerHTML={{ __html: chapter.html }}
        />
        <div className="absolute bottom-3 left-0 right-0 text-center font-display text-[9px] tracking-[0.3em] text-muted-foreground">
          — {chapter.number} —
        </div>
      </div>
      <p className="mt-3 text-[11px] text-muted-foreground text-center italic">
        Live preview updates as you write.
      </p>
    </div>
  );
}

function NotesTab({
  chapter, selectionText, onAdd, onRemove,
}: {
  chapter: Chapter | null; selectionText: string;
  onAdd: (chapterId: string, n: { text: string; excerpt: string; theme?: HighlightTheme }) => void;
  onRemove: (chapterId: string, id: string) => void;
}) {
  const [text, setText] = useState("");
  const [theme, setTheme] = useState<HighlightTheme | "">("");
  if (!chapter) return <EmptyPanel title="Notes" body="Select a chapter to add annotations." />;
  return (
    <div className="p-4 space-y-4">
      <div className="rounded-lg border border-border bg-ivory p-3">
        <div className="text-[10px] uppercase tracking-widest text-muted-foreground mb-1">Selected passage</div>
        <div className="font-serif text-sm text-ink min-h-[2rem] italic">
          {selectionText || <span className="text-muted-foreground not-italic">Select text in the editor…</span>}
        </div>
        <div className="mt-2 flex flex-wrap gap-1">
          <select value={theme} onChange={(e) => setTheme(e.target.value as HighlightTheme | "")}
            className="rounded-md border border-border bg-background px-2 py-1 text-xs">
            <option value="">No theme</option>
            {(Object.keys(THEME_COLORS) as HighlightTheme[]).map((k) => (
              <option key={k} value={k}>{THEME_COLORS[k].label}</option>
            ))}
          </select>
        </div>
        <textarea
          value={text} onChange={(e) => setText(e.target.value)}
          rows={2} placeholder="Write your note…"
          className="mt-2 w-full rounded-md border border-border bg-background p-2 text-sm"
        />
        <button
          disabled={!text.trim() || !selectionText}
          onClick={() => {
            onAdd(chapter.id, { text: text.trim(), excerpt: selectionText, theme: theme || undefined });
            setText(""); setTheme("");
          }}
          className="mt-2 w-full rounded-md bg-primary text-primary-foreground py-1.5 text-xs disabled:opacity-40"
        >
          Add note
        </button>
      </div>

      <div>
        <div className="text-[10px] uppercase tracking-widest text-muted-foreground mb-2">
          {chapter.notes.length} notes on this chapter
        </div>
        {chapter.notes.length === 0 && (
          <div className="text-xs italic text-muted-foreground">No notes yet.</div>
        )}
        <ul className="space-y-2">
          {chapter.notes.map((n) => (
            <li key={n.id} className="rounded-md border border-border bg-ivory p-2 text-xs">
              <div className="flex items-start justify-between gap-2">
                <blockquote className="font-serif italic text-ink/80 border-l-2 border-gold pl-2">
                  “{n.excerpt}”
                </blockquote>
                <button onClick={() => onRemove(chapter.id, n.id)} className="text-muted-foreground hover:text-destructive">
                  <X className="h-3.5 w-3.5" />
                </button>
              </div>
              <p className="mt-1">{n.text}</p>
              {n.theme && (
                <span className={cn("mt-1 inline-block px-1.5 py-0.5 rounded text-[10px]", THEME_COLORS[n.theme].className)}>
                  {THEME_COLORS[n.theme].label}
                </span>
              )}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function BookmarksTab({
  bookmarks, chapters, books, activeChapter, activeBook, selectionText, onAdd, onRemove, onSelect,
}: {
  bookmarks: Bookmark[]; chapters: Chapter[]; books: Book[];
  activeChapter: Chapter | null; activeBook: Book | null; selectionText: string;
  onAdd: (b: Omit<Bookmark, "id" | "createdAt">) => void; onRemove: (id: string) => void;
  onSelect: (id: string) => void;
}) {
  return (
    <div className="p-4 space-y-4">
      {activeChapter && activeBook && (
        <div className="rounded-lg border border-border bg-ivory p-3">
          <div className="text-[10px] uppercase tracking-widest text-muted-foreground mb-2">Bookmark here</div>
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => onAdd({ bookId: activeBook.id, label: activeBook.name })}
              className="rounded-md border border-border bg-background px-2 py-1 text-xs">Book</button>
            <button
              onClick={() => onAdd({ bookId: activeBook.id, chapterId: activeChapter.id, label: `${activeBook.name} ${activeChapter.number}` })}
              className="rounded-md border border-border bg-background px-2 py-1 text-xs">Chapter</button>
            <button
              disabled={!selectionText}
              onClick={() => onAdd({
                bookId: activeBook.id, chapterId: activeChapter.id,
                label: `${activeBook.name} ${activeChapter.number}`, passage: selectionText,
              })}
              className="rounded-md border border-border bg-background px-2 py-1 text-xs disabled:opacity-40">
              Passage
            </button>
          </div>
        </div>
      )}
      <div>
        <div className="text-[10px] uppercase tracking-widest text-muted-foreground mb-2">Saved bookmarks</div>
        {bookmarks.length === 0 && <div className="text-xs italic text-muted-foreground">No bookmarks yet.</div>}
        <ul className="space-y-2">
          {bookmarks.map((b) => {
            const book = books.find((x) => x.id === b.bookId);
            return (
              <li key={b.id} className="rounded-md border border-border bg-ivory p-2 text-xs">
                <div className="flex items-start justify-between gap-2">
                  <button
                    className="text-left"
                    onClick={() => b.chapterId && onSelect(b.chapterId)}
                  >
                    <div className="font-serif text-sm text-primary">{b.label}</div>
                    {b.passage && <div className="italic text-ink/70 mt-0.5 line-clamp-2">“{b.passage}”</div>}
                    <div className="text-[10px] text-muted-foreground mt-1">{book?.name ?? "—"}</div>
                  </button>
                  <button onClick={() => onRemove(b.id)} className="text-muted-foreground hover:text-destructive">
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}

function SearchTab({ state, onSelect }: { state: ScriptoriumState; onSelect: (id: string) => void }) {
  const [q, setQ] = useState("");
  const [theme, setTheme] = useState<HighlightTheme | "">("");

  const results = useMemo(() => {
    const query = q.trim().toLowerCase();
    return state.chapters.flatMap((c) => {
      const book = state.books.find((b) => b.id === c.bookId);
      const plain = htmlToPlainText(c.html);
      const matchesQuery = !query
        || plain.toLowerCase().includes(query)
        || c.title.toLowerCase().includes(query)
        || c.tags.some((t) => t.toLowerCase().includes(query))
        || c.notes.some((n) => n.text.toLowerCase().includes(query) || n.excerpt.toLowerCase().includes(query));
      const matchesTheme = !theme
        || c.html.includes(`hl-${theme}`)
        || c.notes.some((n) => n.theme === theme);
      if (!matchesQuery || !matchesTheme) return [];
      const idx = query ? plain.toLowerCase().indexOf(query) : 0;
      const excerpt = query
        ? plain.slice(Math.max(0, idx - 40), idx + query.length + 60)
        : plain.slice(0, 100);
      return [{ chapter: c, book, excerpt }];
    });
  }, [q, theme, state]);

  return (
    <div className="p-4 space-y-3">
      <div className="relative">
        <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
        <input
          value={q} onChange={(e) => setQ(e.target.value)}
          placeholder="Search across your Bible…"
          className="w-full rounded-md border border-border bg-ivory pl-8 pr-2 py-2 text-sm"
        />
      </div>
      <select value={theme} onChange={(e) => setTheme(e.target.value as HighlightTheme | "")}
        className="w-full rounded-md border border-border bg-ivory px-2 py-1.5 text-xs">
        <option value="">Any highlight colour</option>
        {(Object.keys(THEME_COLORS) as HighlightTheme[]).map((k) => (
          <option key={k} value={k}>{THEME_COLORS[k].label}</option>
        ))}
      </select>
      <div className="text-[10px] uppercase tracking-widest text-muted-foreground">
        {results.length} result{results.length === 1 ? "" : "s"}
      </div>
      <ul className="space-y-2">
        {results.map(({ chapter, book, excerpt }) => (
          <li key={chapter.id}>
            <button
              onClick={() => onSelect(chapter.id)}
              className="w-full text-left rounded-md border border-border bg-ivory p-2 text-xs hover:border-gold"
            >
              <div className="font-serif text-primary text-sm">{book?.name} · {chapter.number}. {chapter.title}</div>
              <div className="text-ink/70 italic mt-1 line-clamp-2">…{excerpt}…</div>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

function ExportBar({ chapter, book, state }: { chapter: Chapter; book: Book | null; state: ScriptoriumState }) {
  const download = (filename: string, content: string, type: string) => {
    const blob = new Blob([content], { type });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = filename; a.click();
    URL.revokeObjectURL(url);
  };

  const base = `${book?.name ?? "chapter"}-${chapter.number}-${chapter.title}`.replace(/\s+/g, "_");
  const html = `<!doctype html><html><head><meta charset="utf-8"><title>${book?.name ?? ""} ${chapter.number}</title>
<style>body{font-family:Georgia,serif;max-width:640px;margin:2rem auto;padding:1rem;color:#2a1a10;background:#faf6ec}
.verse-num{font-size:.7em;vertical-align:super;color:#7a1f13;font-weight:700;margin-right:.25em}
.section-title{display:block;text-align:center;letter-spacing:.15em;text-transform:uppercase;color:#7a1f13;margin:1em 0}
blockquote{border-left:2px solid #b58a2c;padding-left:1rem;font-style:italic;color:#3a2a10}
.small-caps{font-variant:small-caps;letter-spacing:.05em}p{text-indent:1.25em}p.no-indent{text-indent:0}
</style></head><body><h1 style="text-align:center;font-variant:small-caps">${book?.name ?? ""} — Chapter ${chapter.number}</h1>
<h2 style="text-align:center;font-weight:400">${chapter.title}</h2>${chapter.html}</body></html>`;

  return (
    <div className="border-t border-border/60 bg-ivory/70 px-3 py-2">
      <div className="text-[10px] uppercase tracking-widest text-muted-foreground mb-1">Export</div>
      <div className="grid grid-cols-4 gap-1">
        <button title="Plain text" onClick={() => download(`${base}.txt`, htmlToPlainText(chapter.html), "text/plain")}
          className="inline-flex items-center justify-center gap-1 rounded-md border border-border bg-background py-1 text-[10px] hover:bg-gold-soft/40">
          <FileText className="h-3 w-3" /> TXT
        </button>
        <button title="HTML" onClick={() => download(`${base}.html`, html, "text/html")}
          className="inline-flex items-center justify-center gap-1 rounded-md border border-border bg-background py-1 text-[10px] hover:bg-gold-soft/40">
          <FileText className="h-3 w-3" /> HTML
        </button>
        <button title="JSON backup of all data"
          onClick={() => download(`scriptorium-backup.json`, JSON.stringify(state, null, 2), "application/json")}
          className="inline-flex items-center justify-center gap-1 rounded-md border border-border bg-background py-1 text-[10px] hover:bg-gold-soft/40">
          <FileJson className="h-3 w-3" /> JSON
        </button>
        <button disabled title="PDF export coming soon"
          className="inline-flex items-center justify-center gap-1 rounded-md border border-dashed border-border bg-background py-1 text-[10px] text-muted-foreground opacity-60 cursor-not-allowed">
          <Download className="h-3 w-3" /> PDF
        </button>
      </div>
    </div>
  );
}

function EmptyPanel({ title, body }: { title: string; body: string }) {
  return (
    <div className="p-8 text-center">
      <div className="font-display text-xs tracking-widest text-muted-foreground uppercase">{title}</div>
      <div className="gold-divider my-3" />
      <p className="text-sm italic text-muted-foreground">{body}</p>
    </div>
  );
}

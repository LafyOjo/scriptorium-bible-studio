import { useMemo, useState } from "react";
import { BookOpen, ChevronRight, FolderOpen, LayoutDashboard, Library, Plus, ScrollText } from "lucide-react";
import { STATUS_META } from "@/lib/scriptorium/types";
import type { Book, Chapter, Collection } from "@/lib/scriptorium/store";
import { cn } from "@/lib/utils";

type View = "dashboard" | "library" | "editor";

type Props = {
  view: View;
  onView: (v: View) => void;
  books: Book[];
  chapters: Chapter[];
  collections: Collection[];
  activeChapterId: string | null;
  onSelectChapter: (id: string) => void;
  onAddBook: (name: string, collectionId?: string) => void;
  onAddChapter: (bookId: string) => void;
  onAddCollection: (name: string) => void;
};

export function LeftPanel({
  view, onView, books, chapters, collections, activeChapterId, onSelectChapter,
  onAddBook, onAddChapter, onAddCollection,
}: Props) {
  const [openBook, setOpenBook] = useState<string | null>(books[0]?.id ?? null);
  const [addingBook, setAddingBook] = useState(false);
  const [newBook, setNewBook] = useState("");
  const [addingCol, setAddingCol] = useState(false);
  const [newCol, setNewCol] = useState("");

  const chaptersByBook = useMemo(() => {
    const map = new Map<string, Chapter[]>();
    for (const c of chapters) {
      const list = map.get(c.bookId) ?? [];
      list.push(c);
      map.set(c.bookId, list);
    }
    for (const list of map.values()) list.sort((a, b) => a.number - b.number);
    return map;
  }, [chapters]);

  return (
    <aside className="flex h-full min-h-0 w-72 shrink-0 flex-col parchment-panel rounded-2xl overflow-hidden">
      <div className="px-4 pt-5 pb-3">
        <div className="font-display text-lg text-primary tracking-widest">SCRIPTORIUM</div>
        <div className="text-[10px] uppercase tracking-[0.35em] text-muted-foreground">Bible Studio</div>
        <div className="gold-divider mt-3" />
      </div>

      <nav className="px-3 pb-2">
        <NavItem icon={LayoutDashboard} label="Dashboard" active={view === "dashboard"} onClick={() => onView("dashboard")} />
        <NavItem icon={Library} label="Bible Library" active={view === "library"} onClick={() => onView("library")} />
        <NavItem icon={ScrollText} label="Chapter Editor" active={view === "editor"} onClick={() => onView("editor")} />
      </nav>

      <div className="gold-divider mx-4 my-1" />

      <div className="flex items-center justify-between px-4 pt-3 pb-1">
        <div className="text-[10px] uppercase tracking-[0.3em] text-muted-foreground">Books</div>
        <button onClick={() => setAddingBook((v) => !v)} className="text-primary hover:text-oxblood" title="Add book">
          <Plus className="h-3.5 w-3.5" />
        </button>
      </div>
      {addingBook && (
        <div className="px-3 pb-2 flex gap-1">
          <input
            autoFocus value={newBook} onChange={(e) => setNewBook(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && newBook.trim()) { onAddBook(newBook.trim()); setNewBook(""); setAddingBook(false); }
            }}
            placeholder="New book name…"
            className="flex-1 rounded-md border border-border bg-ivory px-2 py-1 text-xs"
          />
        </div>
      )}

      <div className="flex-1 overflow-auto px-2 pb-3">
        {books.map((b) => {
          const list = chaptersByBook.get(b.id) ?? [];
          const isOpen = openBook === b.id;
          return (
            <div key={b.id} className="mb-1">
              <button
                onClick={() => setOpenBook(isOpen ? null : b.id)}
                className="w-full flex items-center gap-2 rounded-md px-2 py-1.5 text-sm text-primary hover:bg-gold-soft/30"
              >
                <ChevronRight className={cn("h-3.5 w-3.5 transition", isOpen && "rotate-90")} />
                <BookOpen className="h-3.5 w-3.5 shrink-0 text-gold" />
                <span className="truncate font-serif">{b.name}</span>
                <span className="ml-auto text-[10px] text-muted-foreground">{list.length}</span>
              </button>
              {isOpen && (
                <div className="ml-6 border-l border-border/50 pl-2">
                  {list.length === 0 && (
                    <div className="py-2 text-xs italic text-muted-foreground">No chapters yet.</div>
                  )}
                  {list.map((c) => (
                    <button
                      key={c.id}
                      onClick={() => { onSelectChapter(c.id); onView("editor"); }}
                      className={cn(
                        "w-full flex items-center gap-2 rounded-md px-2 py-1 text-left text-xs group",
                        activeChapterId === c.id ? "bg-primary/10 text-primary" : "text-foreground hover:bg-gold-soft/30",
                      )}
                    >
                      <span className="h-1.5 w-1.5 rounded-full" style={{ background: STATUS_META[c.status].color }} />
                      <span className="truncate">{c.number}. {c.title}</span>
                    </button>
                  ))}
                  <button
                    onClick={() => { const id = onAddChapter(b.id); }}
                    className="mt-1 w-full inline-flex items-center gap-1 rounded-md px-2 py-1 text-[11px] text-muted-foreground hover:text-primary"
                  >
                    <Plus className="h-3 w-3" /> New chapter
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div className="border-t border-border/50 px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="text-[10px] uppercase tracking-[0.3em] text-muted-foreground">Collections</div>
          <button onClick={() => setAddingCol((v) => !v)} className="text-primary" title="Add collection">
            <Plus className="h-3.5 w-3.5" />
          </button>
        </div>
        {addingCol && (
          <input
            autoFocus value={newCol} onChange={(e) => setNewCol(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && newCol.trim()) { onAddCollection(newCol.trim()); setNewCol(""); setAddingCol(false); }
            }}
            placeholder="Collection name…"
            className="mt-2 w-full rounded-md border border-border bg-ivory px-2 py-1 text-xs"
          />
        )}
        <ul className="mt-2 space-y-1">
          {collections.map((c) => (
            <li key={c.id} className="flex items-center gap-2 text-xs text-foreground">
              <FolderOpen className="h-3.5 w-3.5 text-gold" />
              <span className="truncate">{c.name}</span>
            </li>
          ))}
        </ul>
      </div>
    </aside>
  );
}

function NavItem({ icon: Icon, label, active, onClick }: { icon: any; label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "w-full flex items-center gap-2 rounded-md px-3 py-2 text-sm",
        active ? "bg-primary text-primary-foreground" : "text-primary hover:bg-gold-soft/40",
      )}
    >
      <Icon className="h-4 w-4" />
      {label}
    </button>
  );
}

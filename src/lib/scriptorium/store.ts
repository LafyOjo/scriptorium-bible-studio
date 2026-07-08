import { useCallback, useEffect, useRef, useState } from "react";
import type { Bookmark, Chapter, Collection, Book, Note, ScriptoriumState } from "./types";
import { seedState } from "./seed";

const KEY = "scriptorium-bible-studio:v1";
const uid = () => Math.random().toString(36).slice(2, 10);

function load(): ScriptoriumState {
  if (typeof window === "undefined") return seedState();
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return seedState();
    const parsed = JSON.parse(raw) as ScriptoriumState;
    if (!parsed.version) return seedState();
    return parsed;
  } catch {
    return seedState();
  }
}

function save(state: ScriptoriumState) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(KEY, JSON.stringify(state));
}

export function useScriptorium() {
  const [state, setState] = useState<ScriptoriumState>(() =>
    typeof window === "undefined" ? seedState() : load(),
  );
  const hydrated = useRef(false);

  useEffect(() => {
    if (!hydrated.current) {
      setState(load());
      hydrated.current = true;
      return;
    }
    save(state);
  }, [state]);

  const updateChapter = useCallback((id: string, patch: Partial<Chapter>) => {
    setState((s) => ({
      ...s,
      chapters: s.chapters.map((c) =>
        c.id === id ? { ...c, ...patch, updatedAt: Date.now() } : c,
      ),
    }));
  }, []);

  const addChapter = useCallback((bookId: string) => {
    const id = uid();
    setState((s) => {
      const existing = s.chapters.filter((c) => c.bookId === bookId);
      const number = existing.length + 1;
      const chapter: Chapter = {
        id,
        bookId,
        number,
        title: `Chapter ${number}`,
        html: "<p><br/></p>",
        status: "not-started",
        tags: [],
        updatedAt: Date.now(),
        notes: [],
      };
      return { ...s, chapters: [...s.chapters, chapter] };
    });
    return id;
  }, []);

  const deleteChapter = useCallback((id: string) => {
    setState((s) => ({ ...s, chapters: s.chapters.filter((c) => c.id !== id) }));
  }, []);

  const addBook = useCallback(
    (name: string, testament: Book["testament"] = "custom", collectionId?: string) => {
      const id = uid();
      setState((s) => ({
        ...s,
        books: [...s.books, { id, name, testament, collectionId, order: s.books.length + 1 }],
      }));
      return id;
    },
    [],
  );

  const addCollection = useCallback((name: string) => {
    const id = uid();
    setState((s) => ({ ...s, collections: [...s.collections, { id, name }] }));
    return id;
  }, []);

  const addBookmark = useCallback((b: Omit<Bookmark, "id" | "createdAt">) => {
    setState((s) => ({
      ...s,
      bookmarks: [...s.bookmarks, { ...b, id: uid(), createdAt: Date.now() }],
    }));
  }, []);

  const removeBookmark = useCallback((id: string) => {
    setState((s) => ({ ...s, bookmarks: s.bookmarks.filter((b) => b.id !== id) }));
  }, []);

  const addNote = useCallback((chapterId: string, note: Omit<Note, "id" | "createdAt">) => {
    setState((s) => ({
      ...s,
      chapters: s.chapters.map((c) =>
        c.id === chapterId
          ? { ...c, notes: [...c.notes, { ...note, id: uid(), createdAt: Date.now() }] }
          : c,
      ),
    }));
  }, []);

  const removeNote = useCallback((chapterId: string, noteId: string) => {
    setState((s) => ({
      ...s,
      chapters: s.chapters.map((c) =>
        c.id === chapterId ? { ...c, notes: c.notes.filter((n) => n.id !== noteId) } : c,
      ),
    }));
  }, []);

  const importState = useCallback((s: ScriptoriumState) => setState(s), []);
  const resetSeed = useCallback(() => setState(seedState()), []);

  return {
    state,
    setState,
    updateChapter,
    addChapter,
    deleteChapter,
    addBook,
    addCollection,
    addBookmark,
    removeBookmark,
    addNote,
    removeNote,
    importState,
    resetSeed,
  };
}

export function htmlToPlainText(html: string): string {
  if (typeof document === "undefined") return html.replace(/<[^>]+>/g, "");
  const el = document.createElement("div");
  el.innerHTML = html;
  // Preserve verse numbers with brackets
  el.querySelectorAll(".verse-num").forEach((n) => {
    n.textContent = `[${n.textContent}] `;
  });
  el.querySelectorAll("p, blockquote").forEach((n) => n.append("\n"));
  return el.textContent?.trim() ?? "";
}

export function countWords(html: string): number {
  const text = htmlToPlainText(html);
  return text.split(/\s+/).filter(Boolean).length;
}

export type { Book, Chapter, Collection, Bookmark, Note, ScriptoriumState };

export type ChapterStatus = "not-started" | "drafting" | "revised" | "complete";

export type HighlightTheme =
  | "covenant"
  | "prophecy"
  | "wisdom"
  | "judgement"
  | "mercy"
  | "genealogy"
  | "law"
  | "gospel"
  | "personal";

export interface Note {
  id: string;
  text: string;
  excerpt: string;
  theme?: HighlightTheme;
  createdAt: number;
}

export interface Chapter {
  id: string;
  bookId: string;
  number: number;
  title: string;
  html: string; // rich text
  status: ChapterStatus;
  tags: string[];
  updatedAt: number;
  notes: Note[];
}

export interface Book {
  id: string;
  name: string;
  testament: "old" | "new" | "custom";
  collectionId?: string;
  order: number;
}

export interface Collection {
  id: string;
  name: string;
}

export interface Bookmark {
  id: string;
  bookId: string;
  chapterId?: string;
  label: string;
  passage?: string;
  createdAt: number;
}

export interface ScriptoriumState {
  books: Book[];
  chapters: Chapter[];
  collections: Collection[];
  bookmarks: Bookmark[];
  version: 1;
}

export const THEME_COLORS: Record<
  HighlightTheme,
  { label: string; className: string; swatch: string }
> = {
  covenant: { label: "Covenant", className: "hl-covenant", swatch: "oklch(0.88 0.11 85)" },
  prophecy: { label: "Prophecy", className: "hl-prophecy", swatch: "oklch(0.82 0.12 300)" },
  wisdom: { label: "Wisdom", className: "hl-wisdom", swatch: "oklch(0.85 0.11 180)" },
  judgement: { label: "Judgement", className: "hl-judgement", swatch: "oklch(0.72 0.16 25)" },
  mercy: { label: "Mercy", className: "hl-mercy", swatch: "oklch(0.85 0.1 145)" },
  genealogy: { label: "Genealogy", className: "hl-genealogy", swatch: "oklch(0.85 0.05 60)" },
  law: { label: "Law", className: "hl-law", swatch: "oklch(0.8 0.09 250)" },
  gospel: { label: "Gospel", className: "hl-gospel", swatch: "oklch(0.88 0.13 95)" },
  personal: { label: "Personal Study", className: "hl-personal", swatch: "oklch(0.85 0.08 340)" },
};

export const STATUS_META: Record<ChapterStatus, { label: string; color: string }> = {
  "not-started": { label: "Not Started", color: "oklch(0.7 0.02 80)" },
  drafting: { label: "Drafting", color: "oklch(0.7 0.14 65)" },
  revised: { label: "Revised", color: "oklch(0.65 0.12 220)" },
  complete: { label: "Complete", color: "oklch(0.6 0.13 145)" },
};

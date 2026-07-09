import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import {
  AlignCenter,
  AlignJustify,
  AlignLeft,
  AlignRight,
  Asterisk,
  Bold,
  BookOpenText,
  CaseUpper,
  Eraser,
  Eye,
  Hash,
  Heading1,
  Heading2,
  Highlighter,
  Indent,
  Italic,
  Link2,
  Link2Off,
  List,
  ListOrdered,
  Outdent,
  Palette,
  Pause,
  PencilLine,
  Play,
  Quote,
  Redo2,
  Square,
  Strikethrough,
  Subscript,
  Superscript,
  Type,
  Underline,
  Undo2,
  type LucideIcon,
} from "lucide-react";
import { THEME_COLORS, STATUS_META, type HighlightTheme } from "@/lib/scriptorium/types";
import type { Chapter, Book } from "@/lib/scriptorium/store";
import { countWords, htmlToPlainText } from "@/lib/scriptorium/store";
import { cn } from "@/lib/utils";

type Props = {
  chapter: Chapter;
  book: Book;
  onChange: (patch: Partial<Chapter>) => void;
  onSelectionText: (text: string) => void;
};

type ReadingBlock = {
  html: string;
  text: string;
  start: number;
  end: number;
};

const FONT_SIZES = [
  { label: "XS", px: "13px" },
  { label: "S", px: "15px" },
  { label: "M", px: "18px" },
  { label: "L", px: "22px" },
  { label: "XL", px: "28px" },
  { label: "2XL", px: "34px" },
];

const BLOCKS: Array<{ label: string; tag: string }> = [
  { label: "Paragraph", tag: "P" },
  { label: "Heading 1", tag: "H1" },
  { label: "Heading 2", tag: "H2" },
  { label: "Heading 3", tag: "H3" },
  { label: "Blockquote", tag: "BLOCKQUOTE" },
  { label: "Preformatted", tag: "PRE" },
];

const TEXT_COLORS = [
  { label: "Ink", value: "#3b2a1a" },
  { label: "Crimson", value: "#7a1f13" },
  { label: "Gold", value: "#8a6a1e" },
  { label: "Mercy Green", value: "#2f5230" },
  { label: "Prophecy Blue", value: "#1f3b6b" },
  { label: "Royal Purple", value: "#5c2a72" },
  { label: "Black", value: "#111111" },
];

function exec(cmd: string, value?: string) {
  try {
    document.execCommand("styleWithCSS", false, "true");
  } catch {
    // Some browsers ignore styleWithCSS; the command still works with defaults.
  }
  document.execCommand(cmd, false, value);
}

function wrapSelection(className: string) {
  const sel = window.getSelection();
  if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
  const range = sel.getRangeAt(0);
  const span = document.createElement("span");
  span.className = className;
  try {
    span.appendChild(range.extractContents());
    range.insertNode(span);
    sel.removeAllRanges();
  } catch {
    return;
  }
}

function wrapSelectionWithStyle(style: Partial<CSSStyleDeclaration>) {
  const sel = window.getSelection();
  if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
  const range = sel.getRangeAt(0);
  const span = document.createElement("span");
  Object.assign(span.style, style);
  try {
    span.appendChild(range.extractContents());
    range.insertNode(span);
    sel.removeAllRanges();
  } catch {
    return;
  }
}

function insertHTML(html: string) {
  exec("insertHTML", html);
}

function readingBlocksFromHtml(html: string): ReadingBlock[] {
  if (typeof document === "undefined") {
    return [{ html, text: html.replace(/<[^>]+>/g, " "), start: 0, end: html.length }];
  }

  const host = document.createElement("div");
  host.innerHTML = html;
  const elements = Array.from(host.querySelectorAll("p, blockquote, h1, h2, h3, li"));
  const blocks = (elements.length ? elements : [host]).flatMap((element) => {
    const text = htmlToPlainText(element.outerHTML || element.textContent || "");
    if (!text.trim()) return [];
    return [{ html: element.outerHTML || `<p>${text}</p>`, text }];
  });

  let cursor = 0;
  return blocks.map((block) => {
    const start = cursor;
    const end = start + block.text.length;
    cursor = end + 2;
    return { ...block, start, end };
  });
}

export function ChapterEditor({ chapter, book, onChange, onSelectionText }: Props) {
  const editorRef = useRef<HTMLDivElement>(null);
  const selectionRangeRef = useRef<Range | null>(null);
  const loadedChapterIdRef = useRef<string | null>(null);
  const timer = useRef<number | null>(null);
  const utteranceRef = useRef<SpeechSynthesisUtterance | null>(null);

  const [mode, setMode] = useState<"edit" | "reader">("edit");
  const [saveState, setSaveState] = useState<"saved" | "saving">("saved");
  const [draftHtml, setDraftHtml] = useState(chapter.html);
  const [readingBlockIndex, setReadingBlockIndex] = useState<number | null>(null);
  const [speaking, setSpeaking] = useState(false);
  const [paused, setPaused] = useState(false);
  const [fontSize, setFontSize] = useState("M");
  const [nextVerse, setNextVerse] = useState(() => {
    const nums = Array.from(chapter.html.matchAll(/verse-num[^>]*>(\d+)</g)).map((m) =>
      Number(m[1]),
    );
    return (nums.length ? Math.max(...nums) : 0) + 1;
  });

  useEffect(() => {
    if (loadedChapterIdRef.current === chapter.id) return;
    loadedChapterIdRef.current = chapter.id;
    if (editorRef.current && editorRef.current.innerHTML !== chapter.html) {
      editorRef.current.innerHTML = chapter.html;
    }
    setDraftHtml(chapter.html);
    setReadingBlockIndex(null);
    const nums = Array.from(chapter.html.matchAll(/verse-num[^>]*>(\d+)</g)).map((m) =>
      Number(m[1]),
    );
    setNextVerse((nums.length ? Math.max(...nums) : 0) + 1);
    // Avoid replacing contentEditable HTML while typing inside the same chapter.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chapter.id]);

  useEffect(
    () => () => {
      if (timer.current) window.clearTimeout(timer.current);
      if (typeof window !== "undefined") window.speechSynthesis?.cancel();
    },
    [],
  );

  const handleInput = () => {
    if (!editorRef.current) return;
    const html = editorRef.current.innerHTML;
    setDraftHtml(html);
    setSaveState("saving");
    if (timer.current) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      onChange({ html });
      setSaveState("saved");
    }, 700);
  };

  const focusEditor = () => editorRef.current?.focus();

  const handleSelection = () => {
    const sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) return;
    const range = sel.getRangeAt(0);
    if (!editorRef.current?.contains(range.commonAncestorContainer)) return;
    selectionRangeRef.current = range.cloneRange();
    if (!sel.isCollapsed) onSelectionText(sel.toString());
  };

  const restoreSelection = () => {
    const range = selectionRangeRef.current;
    if (!range) return;
    const sel = window.getSelection();
    if (!sel) return;
    focusEditor();
    sel.removeAllRanges();
    sel.addRange(range);
  };

  const runEditorTool = (run: () => void) => {
    restoreSelection();
    run();
    handleInput();
    window.setTimeout(handleSelection, 0);
  };

  const runCmd = (cmd: string, value?: string) => {
    runEditorTool(() => exec(cmd, value));
  };

  const insertVerseNumber = () => {
    runEditorTool(() => insertHTML(`<span class="verse-num">${nextVerse}</span>&nbsp;`));
    setNextVerse((n) => n + 1);
  };

  const applyHighlight = (theme: HighlightTheme) => {
    runEditorTool(() => wrapSelection(THEME_COLORS[theme].className));
  };

  const applyColor = (color: string) => {
    runEditorTool(() => exec("foreColor", color));
  };

  const applyFontSize = (label: string) => {
    setFontSize(label);
    const size = FONT_SIZES.find((f) => f.label === label);
    if (!size) return;
    runEditorTool(() => wrapSelectionWithStyle({ fontSize: size.px }));
  };

  const applyBlock = (tag: string) => {
    runEditorTool(() => {
      exec("formatBlock", tag);
      if (tag === "BLOCKQUOTE") {
        const sel = window.getSelection();
        const node = sel?.anchorNode?.parentElement?.closest("blockquote");
        if (node) node.classList.add("poetic");
      }
    });
  };

  const insertLink = () => {
    const url = window.prompt("Link URL", "https://");
    if (!url) return;
    runCmd("createLink", url);
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (!(event.metaKey || event.ctrlKey)) return;
    const key = event.key.toLowerCase();
    if (key === "b") {
      event.preventDefault();
      runCmd("bold");
    } else if (key === "i") {
      event.preventDefault();
      runCmd("italic");
    } else if (key === "u") {
      event.preventDefault();
      runCmd("underline");
    } else if (key === "k") {
      event.preventDefault();
      insertLink();
    } else if (key === "z" && !event.shiftKey) {
      event.preventDefault();
      runCmd("undo");
    } else if ((key === "z" && event.shiftKey) || key === "y") {
      event.preventDefault();
      runCmd("redo");
    }
  };

  const readingBlocks = useMemo(() => readingBlocksFromHtml(draftHtml), [draftHtml]);

  const startReading = () => {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
    window.speechSynthesis.cancel();
    const liveHtml = editorRef.current?.innerHTML ?? draftHtml;
    if (liveHtml !== draftHtml) setDraftHtml(liveHtml);
    const blocks = readingBlocksFromHtml(liveHtml);
    const text = blocks.map((block) => block.text).join("\n\n");
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 0.95;
    utterance.pitch = 1;
    utterance.onstart = () => setReadingBlockIndex(0);
    utterance.onboundary = (event) => {
      const index = blocks.findIndex(
        (block) => event.charIndex >= block.start && event.charIndex <= block.end,
      );
      if (index >= 0) setReadingBlockIndex(index);
    };
    utterance.onend = () => {
      setSpeaking(false);
      setPaused(false);
      setReadingBlockIndex(null);
    };
    utteranceRef.current = utterance;
    window.speechSynthesis.speak(utterance);
    setMode("reader");
    setSpeaking(true);
    setPaused(false);
  };

  const pauseReading = () => {
    window.speechSynthesis.pause();
    setPaused(true);
  };

  const resumeReading = () => {
    window.speechSynthesis.resume();
    setPaused(false);
  };

  const stopReading = () => {
    window.speechSynthesis.cancel();
    setSpeaking(false);
    setPaused(false);
    setReadingBlockIndex(null);
  };

  const words = countWords(draftHtml);
  const status = STATUS_META[chapter.status];

  const IconBtn = ({
    icon: Icon,
    label,
    onClick,
  }: {
    icon: LucideIcon;
    label: string;
    onClick: () => void;
  }) => (
    <button
      title={label}
      aria-label={label}
      onMouseDown={(event) => event.preventDefault()}
      onClick={onClick}
      className="grid h-8 w-8 place-items-center rounded-md text-primary transition hover:bg-gold-soft/40"
    >
      <Icon className="h-4 w-4" />
    </button>
  );

  const Divider = () => <div className="mx-1.5 h-6 w-px bg-border" />;

  return (
    <div className="flex h-full flex-col overflow-hidden rounded-2xl parchment-panel">
      <div className="flex flex-col gap-3 border-b border-border/60 px-6 pb-3 pt-5">
        <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 sm:flex sm:flex-wrap sm:justify-between">
          <div className="min-w-0">
            <div className="font-display text-xs uppercase tracking-[0.3em] text-muted-foreground">
              {book.name} · Chapter {chapter.number}
            </div>
            <input
              className="mt-1 w-full bg-transparent font-serif text-3xl font-semibold text-primary outline-none placeholder:text-muted-foreground/50"
              value={chapter.title}
              onChange={(event) => onChange({ title: event.target.value })}
              placeholder="Chapter title"
            />
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <span className="inline-flex items-center gap-2 rounded-full border border-border/60 bg-ivory/60 px-3 py-1 text-xs">
              <span className="h-2 w-2 rounded-full" style={{ background: status.color }} />
              {status.label}
            </span>
            <select
              value={chapter.status}
              onChange={(event) => onChange({ status: event.target.value as Chapter["status"] })}
              className="rounded-md border border-border bg-ivory px-2 py-1 text-xs"
            >
              {Object.entries(STATUS_META).map(([key, value]) => (
                <option key={key} value={key}>
                  {value.label}
                </option>
              ))}
            </select>
            <div className="flex overflow-hidden rounded-md border border-border">
              <button
                onClick={() => setMode("edit")}
                className={cn(
                  "inline-flex items-center gap-1 px-2.5 py-1 text-xs",
                  mode === "edit"
                    ? "bg-primary text-primary-foreground"
                    : "bg-ivory text-foreground",
                )}
              >
                <PencilLine className="h-3.5 w-3.5" /> Editor
              </button>
              <button
                onClick={() => setMode("reader")}
                className={cn(
                  "inline-flex items-center gap-1 px-2.5 py-1 text-xs",
                  mode === "reader"
                    ? "bg-primary text-primary-foreground"
                    : "bg-ivory text-foreground",
                )}
              >
                <Eye className="h-3.5 w-3.5" /> Reader
              </button>
            </div>
          </div>
        </div>

        {mode === "edit" && (
          <div className="flex flex-wrap items-center gap-1 border-t border-border/50 pt-3">
            <select
              onChange={(event) => {
                applyBlock(event.target.value);
                event.currentTarget.selectedIndex = 0;
              }}
              className="h-8 rounded-md border border-border bg-ivory px-2 font-display text-xs"
              defaultValue=""
              title="Paragraph style"
              aria-label="Paragraph style"
            >
              <option value="" disabled>
                Style
              </option>
              {BLOCKS.map((block) => (
                <option key={block.tag} value={block.tag}>
                  {block.label}
                </option>
              ))}
            </select>

            <select
              value={fontSize}
              onChange={(event) => applyFontSize(event.target.value)}
              className="h-8 rounded-md border border-border bg-ivory px-2 font-display text-xs"
              title="Font size"
              aria-label="Font size"
            >
              {FONT_SIZES.map((size) => (
                <option key={size.label} value={size.label}>
                  {size.label}
                </option>
              ))}
            </select>

            <Divider />

            <IconBtn icon={Undo2} label="Undo" onClick={() => runCmd("undo")} />
            <IconBtn icon={Redo2} label="Redo" onClick={() => runCmd("redo")} />

            <Divider />

            <IconBtn icon={Bold} label="Bold" onClick={() => runCmd("bold")} />
            <IconBtn icon={Italic} label="Italic" onClick={() => runCmd("italic")} />
            <IconBtn icon={Underline} label="Underline" onClick={() => runCmd("underline")} />
            <IconBtn
              icon={Strikethrough}
              label="Strikethrough"
              onClick={() => runCmd("strikeThrough")}
            />
            <IconBtn icon={Superscript} label="Superscript" onClick={() => runCmd("superscript")} />
            <IconBtn icon={Subscript} label="Subscript" onClick={() => runCmd("subscript")} />
            <IconBtn
              icon={Type}
              label="Small Caps"
              onClick={() => runEditorTool(() => wrapSelection("small-caps"))}
            />
            <IconBtn
              icon={CaseUpper}
              label="Uppercase Selection"
              onClick={() =>
                runEditorTool(() => {
                  const sel = window.getSelection();
                  if (!sel || sel.isCollapsed) return;
                  insertHTML(sel.toString().toUpperCase());
                })
              }
            />

            <Divider />

            <IconBtn
              icon={Heading1}
              label="Heading 1"
              onClick={() => runCmd("formatBlock", "H1")}
            />
            <IconBtn
              icon={Heading2}
              label="Heading 2"
              onClick={() => runCmd("formatBlock", "H2")}
            />
            <IconBtn
              icon={Quote}
              label="Poetic Blockquote"
              onClick={() => applyBlock("BLOCKQUOTE")}
            />
            <IconBtn
              icon={BookOpenText}
              label="Section Title"
              onClick={() =>
                runEditorTool(() =>
                  insertHTML(
                    `<p class="no-indent"><span class="section-title">Section Title</span></p>`,
                  ),
                )
              }
            />

            <Divider />

            <IconBtn
              icon={List}
              label="Bulleted list"
              onClick={() => runCmd("insertUnorderedList")}
            />
            <IconBtn
              icon={ListOrdered}
              label="Numbered list"
              onClick={() => runCmd("insertOrderedList")}
            />
            <IconBtn icon={Indent} label="Indent" onClick={() => runCmd("indent")} />
            <IconBtn icon={Outdent} label="Outdent" onClick={() => runCmd("outdent")} />

            <Divider />

            <IconBtn icon={AlignLeft} label="Align left" onClick={() => runCmd("justifyLeft")} />
            <IconBtn
              icon={AlignCenter}
              label="Align center"
              onClick={() => runCmd("justifyCenter")}
            />
            <IconBtn icon={AlignRight} label="Align right" onClick={() => runCmd("justifyRight")} />
            <IconBtn icon={AlignJustify} label="Justify" onClick={() => runCmd("justifyFull")} />

            <Divider />

            <button
              title="Insert verse number"
              aria-label="Insert verse number"
              onMouseDown={(event) => event.preventDefault()}
              onClick={insertVerseNumber}
              className="inline-flex h-8 place-items-center gap-1 rounded-md px-2 font-display text-xs text-primary hover:bg-gold-soft/40"
            >
              <Hash className="h-3.5 w-3.5" /> v{nextVerse}
            </button>
            <IconBtn
              icon={Asterisk}
              label="Footnote marker"
              onClick={() =>
                runEditorTool(() => insertHTML(`<sup class="footnote-marker">*</sup>`))
              }
            />
            <IconBtn icon={Link2} label="Insert link" onClick={insertLink} />
            <IconBtn icon={Link2Off} label="Remove link" onClick={() => runCmd("unlink")} />
            <IconBtn
              icon={Eraser}
              label="Clear formatting"
              onClick={() => runCmd("removeFormat")}
            />

            <Divider />

            <div className="group relative">
              <button
                aria-label="Highlight selected text"
                className="inline-flex h-8 items-center gap-1 rounded-md px-2 text-xs hover:bg-gold-soft/40"
              >
                <Highlighter className="h-4 w-4" /> Highlight
              </button>
              <div className="absolute left-0 top-full z-20 mt-1 hidden grid-cols-3 gap-1 rounded-lg border border-border bg-popover p-2 shadow-lg group-hover:grid">
                {(Object.keys(THEME_COLORS) as HighlightTheme[]).map((key) => (
                  <button
                    key={key}
                    onMouseDown={(event) => event.preventDefault()}
                    onClick={() => applyHighlight(key)}
                    title={THEME_COLORS[key].label}
                    aria-label={`Highlight ${THEME_COLORS[key].label}`}
                    className="flex items-center gap-1.5 whitespace-nowrap rounded px-1.5 py-1 text-xs hover:bg-muted"
                  >
                    <span
                      className="h-3 w-3 rounded-sm border border-border"
                      style={{ background: THEME_COLORS[key].swatch }}
                    />
                    {THEME_COLORS[key].label}
                  </button>
                ))}
              </div>
            </div>

            <div className="group relative">
              <button
                aria-label="Text colour"
                className="inline-flex h-8 items-center gap-1 rounded-md px-2 text-xs hover:bg-gold-soft/40"
              >
                <Palette className="h-4 w-4" /> Colour
              </button>
              <div className="absolute left-0 top-full z-20 mt-1 hidden gap-1 rounded-lg border border-border bg-popover p-2 shadow-lg group-hover:flex">
                {TEXT_COLORS.map((color) => (
                  <button
                    key={color.value}
                    onMouseDown={(event) => event.preventDefault()}
                    onClick={() => applyColor(color.value)}
                    className="h-5 w-5 rounded-full border border-border"
                    style={{ background: color.value }}
                    title={color.label}
                    aria-label={`Text colour ${color.label}`}
                  />
                ))}
              </div>
            </div>

            <div className="ml-auto flex items-center gap-3 text-xs text-muted-foreground">
              <span>{words} words</span>
              <span>· {saveState === "saved" ? "Saved" : "Saving..."}</span>
            </div>
          </div>
        )}

        <div className="flex items-center gap-2 pt-1">
          {!speaking ? (
            <button
              onClick={startReading}
              className="inline-flex items-center gap-1.5 rounded-full border border-gold bg-gold-soft/40 px-3 py-1 text-xs text-primary hover:bg-gold-soft/70"
            >
              <Play className="h-3.5 w-3.5" /> Read aloud
            </button>
          ) : (
            <>
              {paused ? (
                <button
                  onClick={resumeReading}
                  className="inline-flex items-center gap-1.5 rounded-full border border-gold bg-gold-soft/60 px-3 py-1 text-xs"
                >
                  <Play className="h-3.5 w-3.5" /> Resume
                </button>
              ) : (
                <button
                  onClick={pauseReading}
                  className="inline-flex items-center gap-1.5 rounded-full border border-gold bg-gold-soft/60 px-3 py-1 text-xs"
                >
                  <Pause className="h-3.5 w-3.5" /> Pause
                </button>
              )}
              <button
                onClick={stopReading}
                className="inline-flex items-center gap-1.5 rounded-full border border-border bg-ivory px-3 py-1 text-xs"
              >
                <Square className="h-3.5 w-3.5" /> Stop
              </button>
              <span className="text-xs text-muted-foreground">Reading with browser voice...</span>
            </>
          )}
        </div>
      </div>

      <div className="flex-1 overflow-auto">
        <div className="mx-auto max-w-3xl px-8 py-8">
          {mode === "edit" ? (
            <div
              ref={editorRef}
              contentEditable
              suppressContentEditableWarning
              onInput={handleInput}
              onMouseUp={handleSelection}
              onKeyUp={handleSelection}
              onKeyDown={handleKeyDown}
              onBlur={handleSelection}
              className="reader-prose min-h-[60vh] font-serif text-lg leading-relaxed text-ink outline-none"
              spellCheck
            />
          ) : (
            <div className="reader-prose font-serif text-lg leading-relaxed text-ink">
              {readingBlocks.map((block, index) => (
                <div
                  key={`${index}-${block.start}`}
                  className={cn(
                    "reader-block rounded-md px-3 py-1 transition-colors",
                    readingBlockIndex === index && "reader-block-active",
                  )}
                  dangerouslySetInnerHTML={{ __html: block.html }}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

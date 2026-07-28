# local-tools - the one C# MCP server

Everything custom in this setup lives here, in **one .NET project you can open in Visual
Studio / Rider, set breakpoints in, and tweak**. No Node, no Python. It exposes five tools
to Claude Code over stdio:

| Tool | What it does |
|------|--------------|
| `search_datasheets` | Semantic search over your indexed docs (the big context-window win). |
| `index_datasheets` | (Re)build the index after adding/changing files. |
| `list_datasheets` | List what's in the corpus. |
| `ingest_url` | **Online.** Fetch a page/PDF, save it to the corpus, re-index (persists offline). |
| `web_search` | **Online.** Keyless DuckDuckGo search -> titles + URLs. |
| `describe_image` | **Offline-OK.** Read an image (whiteboard photo / screenshot / diagram) with a LOCAL vision model -> transcribed text + structure. Default `gemma3:4b`; override with `LOCALTOOLS_VISION_MODEL`. |
| `detect_objects` | **Offline-OK.** WHERE things are: local ONNX detector -> labels + confidence + pixel boxes. Bring your own YOLO-family `.onnx` via `LOCALTOOLS_DETECT_MODEL`. |
| `transcribe_audio` | **Offline-OK.** Recording -> timestamped text via local Whisper (uv + `transcribe.py`). |

## How it's wired (C# perspective)

- **`Program.cs`** - generic host + `AddMcpServer().WithStdioServerTransport().WithToolsFromAssembly()`.
  That last call reflects over the assembly and registers every `[McpServerTool]` method it finds.
- **`Tools.cs`** - the `[McpServerToolType]` class. Each method = one tool; its `Name` and
  `[Description]` are what Claude Code sees. Keep these thin; they just call `Rag`.
- **`Rag.cs`** - the actual logic: chunking, embeddings, cosine search, URL fetch, DDG search.

The only external dependency at runtime is **Ollama over HTTP** (`/api/embed`) for embeddings -
language-agnostic, so C# just POSTs JSON. Indexing **batches** chunks (one `/api/embed` call per
64, not one per chunk) for fast (re)indexing. Vectors are stored raw in `.index/chunks.json` and
searched with **SIMD cosine** (`System.Numerics.Tensors.TensorPrimitives.CosineSimilarity`) - fast
for thousands of chunks, no vector-DB server needed.

**Multimodal corpus:** images (`.png/.jpg/.jpeg/.webp/.bmp/.gif`) in `docs/` are CAPTIONED with the local
vision model at index time, and audio (`.wav/.mp3/.m4a/.flac/.ogg`) is TRANSCRIBED when
`LOCALTOOLS_TRANSCRIBE_AUDIO=1` - the resulting TEXT is embedded, so a whiteboard photo or a recorded spec
discussion is searchable through the normal `search_datasheets` path. Derived text is cached in
`.index/derived/` keyed by the source file's mtime+size, so each file is processed once no matter how often
you reindex; failures are never cached (a later run can succeed) and never abort the index.

**Chunking:** Markdown is split by heading - one chunk per section, so a hit returns a whole story / task /
spec block (fenced ``` code is skipped, so a `#` inside an example is not treated as a heading). `.txt` and
PDF pages use a ~1000-char window with 150 overlap; an oversized markdown section falls back to that window
with its heading kept as a prefix. The index is written **atomically** (temp file + move) so a concurrent
search never reads a half-written index during a reindex.

NuGet packages: `ModelContextProtocol` (the SDK), `PdfPig` (PDF text), `AngleSharp` (HTML->text),
`Microsoft.Extensions.Hosting`.

## Build

```
dotnet build local-tools.csproj -c Release
```
Produces `bin\Release\net8.0\local-tools.exe`. `.mcp.json` points Claude Code straight at that exe.
Targets `net8.0` with `RollForward=LatestMajor`, so it **builds on any .NET 8+ SDK and runs on any
.NET 8+ runtime** (9, 10, ...) - you don't need the .NET 8 runtime specifically.

## THE stdio rule (important when debugging)

MCP talks JSON-RPC over **stdout**. Anything else on stdout - a stray `Console.WriteLine`, an
unconfigured logger - corrupts the stream and the client drops the connection. That's why
`Program.cs` sends *all* logging to **stderr** (`LogToStandardErrorThreshold = Trace`). When you
add diagnostics, use `Console.Error.WriteLine` or `ILogger`, never `Console.WriteLine`.

## Debugging by hand

Run the exe and drive it from a second process with redirected pipes. One gotcha learned the hard
way: **keep stdin open** while reading responses - if you close stdin immediately the transport
cancels before flushing, and stdout looks empty. Claude Code holds the pipe open for the whole
session, so this only bites manual testing. A handshake + `tools/list` confirms it's alive.

## Adding a new tool

Add a method to `Tools.cs`:
```csharp
[McpServerTool(Name = "my_tool"), Description("what it does")]
public static Task<string> MyTool([Description("the arg")] string arg) => Rag.MyThing(arg);
```
Rebuild. `WithToolsFromAssembly()` picks it up automatically - no registration needed.

## Keeping the index fresh

By default the index updates only when you call `index_datasheets` (or `ingest_url`, which
re-indexes automatically). Two ways to automate it:

- **Auto-reindex (opt-in, per project):** set `LOCALTOOLS_AUTO_REINDEX=1` in the project's
  `.mcp.json` env. Then `search_datasheets` checks a cheap corpus signature (`.index/manifest.sig`
  - file paths + mtimes + sizes, no content reads) and re-indexes first if `docs/` changed. Drop a
  file in, search, and it's already fresh. Default off, so it never surprises you.
- **CLI one-off / scheduled:** `local-tools.exe --reindex "C:\path\to\project\docs"` rebuilds the
  index without starting the MCP server (exit 0 = ok). Use `reindex.cmd <docsDir>` or point a
  Windows Scheduled Task at it.

(Reindex is currently a full rebuild - fine for typical doc sets; incremental is a future optimization.)

## Config (env vars, set in .mcp.json)

| Var | Default | Meaning |
|-----|---------|---------|
| `LOCALTOOLS_DOCS_DIR` | `<exe>/datasheets` | Where your source documents live |
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama endpoint |
| `RAG_EMBED_MODEL` | `nomic-embed-text` | Embedding model |
| `LOCALTOOLS_AUTO_REINDEX` | `0` | `1` = auto-reindex at search time when `docs/` changed (per-project) |
| `LOCALTOOLS_VISION_MODEL` | `gemma3:4b` | Vision model for `describe_image` (must be a multimodal Ollama model, e.g. `qwen2.5vl`, `llama3.2-vision`) |
| `LOCALTOOLS_CAPTION_IMAGES` | `1` (on) | Caption images in `docs/` at index time so they are searchable. `0` disables. |
| `LOCALTOOLS_TRANSCRIBE_AUDIO` | `0` (off) | Transcribe audio in `docs/` at index time. Opt-in: can take minutes per file. |
| `LOCALTOOLS_DETECT_MODEL` | (unset) | Path to a YOLO-family ONNX detector; `detect_objects` is inert until set. |
| `LOCALTOOLS_DETECT_LABELS` | COCO-80 | Text file, one class name per line, matching your detector. |
| `LOCALTOOLS_WHISPER_MODEL` | `small` | Whisper size for `transcribe_audio` (`tiny`/`base`/`small`/`medium`). |

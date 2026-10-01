using System.Net.Http.Json;
using System.Numerics.Tensors;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using AngleSharp.Html.Parser;
using UglyToad.PdfPig;

namespace LocalTools;

/// <summary>One indexed passage: where it came from + its (normalized) embedding.</summary>
public class Chunk
{
    public string Source { get; set; } = "";
    public int? Page { get; set; }
    public string Text { get; set; } = "";
    public float[]? Vector { get; set; }
}

/// <summary>
/// S20: true when Program.cs got the docs root as an EXPLICIT CLI path arg (--reindex/--ingest/--corpus
/// &lt;dir&gt;), which it passes on by setting LOCALTOOLS_DOCS_DIR - so the env var alone cannot tell the two
/// apart. A SEPARATE type on purpose: Rag's static initializers run on first touch of any Rag static, so a
/// flag stored on Rag could be read by BuildRoots() before Program had set it.
/// </summary>
public static class DocsRootSource
{
    public static bool Explicit;
}

/// <summary>
/// Local, offline RAG. Embeddings come from Ollama over HTTP (language-agnostic); vectors
/// are stored in a single JSON file and searched with brute-force cosine (instant for
/// thousands of chunks). Plus online helpers: ingest_url and web_search.
/// </summary>
public static class Rag
{
    static readonly string[] Exts = { ".pdf", ".txt", ".md", ".csv", ".tsv", ".json" };
    // Multimodal corpus: images are CAPTIONED and audio TRANSCRIBED at index time, and the resulting TEXT
    // is what gets embedded - so a whiteboard photo or a recorded spec discussion becomes searchable with
    // the normal text pipeline. Results are cached per file (see CachedSidecarAsync) so reindexing is cheap.
    static readonly string[] ImgExts = { ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif" };
    static readonly string[] AudExts = { ".wav", ".mp3", ".m4a", ".flac", ".ogg" };
    const int ChunkChars = 1000;
    const int Overlap = 150;

    // Corpus location. Set LOCALTOOLS_DOCS_DIR in .mcp.json so you drop files in the SOURCE
    // folder, not the build output. Falls back to a datasheets/ folder next to the exe.
    //
    // MULTIPLE ROOTS: separate them with ';' - LOCALTOOLS_DOCS_DIR="C:\proj\docs;D:\shared\reference".
    // The FIRST root is primary: it owns .index\ and is where ingest_url writes. One index spans them
    // all, so a research corpus on another drive (or shared between projects) is searchable without
    // copying it. Roots that do not exist are skipped rather than fatal - a missing shared drive should
    // degrade the corpus, not break the server.
    // S20 (mirrors S19's docs-dir rule): an ENV-VAR primary holding none of DESIGN/TEDD/STORIES/CORPUS.md
    // yields to <cwd>\docs when that one passes (one WARN on stderr) - the kit's .mcp.json placeholder was
    // otherwise indexed as an empty corpus. An explicit CLI path arg (DocsRootSource.Explicit) bypasses it.
    static readonly string[] DocsRoots = BuildRoots();
    static string DocsDir => DocsRoots[0];                              // primary root
    // Derived from DocsRoots (computed ONCE) so the WARN prints once and .index\/web\ follow a substituted
    // primary - nothing is ever created under a rejected override (S19's original empty-folder incident).
    static readonly string IndexDir = Path.Combine(DocsRoots[0], ".index");  // self-contained per project
    static readonly string WebDir = Path.Combine(DocsRoots[0], "web");

    static string[] BuildRoots()
    {
        var raw = Environment.GetEnvironmentVariable("LOCALTOOLS_DOCS_DIR");
        if (string.IsNullOrWhiteSpace(raw)) return new[] { Path.Combine(AppContext.BaseDirectory, "datasheets") };
        var seen = new List<string>();
        foreach (var part in raw.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            string full;
            try { full = Path.GetFullPath(part); } catch { continue; }
            // Skip a root nested inside one we already have - it would index every file twice.
            if (seen.Any(s => full.StartsWith(s.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar,
                                              StringComparison.OrdinalIgnoreCase))) continue;
            if (!seen.Any(s => s.Equals(full, StringComparison.OrdinalIgnoreCase))) seen.Add(full);
        }
        if (seen.Count == 0) seen.Add(Path.GetFullPath(raw.Split(';')[0]));   // keep the primary even if absent

        // S20: the docs-dir rule, for an env-var-sourced primary only (seen[0]); secondary roots untouched.
        // Never write to stdout here - it is the MCP protocol channel - and never create a directory.
        if (!DocsRootSource.Explicit && !HasProjectDocs(seen[0]))
        {
            string? cwdDocs = null;
            try { cwdDocs = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "docs")); } catch { }
            if (cwdDocs != null && HasProjectDocs(cwdDocs)
                && !cwdDocs.Equals(seen[0], StringComparison.OrdinalIgnoreCase))
            {
                var rejected = seen[0];
                seen.RemoveAll(s => s.Equals(cwdDocs, StringComparison.OrdinalIgnoreCase));
                seen[0] = cwdDocs;
                Console.Error.WriteLine($"WARN: ignoring LOCALTOOLS_DOCS_DIR {rejected} (no DESIGN/TEDD/STORIES/CORPUS there); using {cwdDocs}");
            }
        }
        return seen.ToArray();
    }

    // S20: a dir counts as project docs only if it holds one of these markers (CORPUS.md marks a /corpus
    // folder). Extends S19's predicate for the SERVER only; docs-dir.ps1 is unchanged.
    static bool HasProjectDocs(string d) =>
        Directory.Exists(d) && new[] { "DESIGN.md", "TEDD.md", "STORIES.md", "CORPUS.md" }
            .Any(n => File.Exists(Path.Combine(d, n)));

    static string IndexFile => Path.Combine(IndexDir, "chunks.json");
    static string SigFile   => Path.Combine(IndexDir, "manifest.sig");  // corpus signature, for staleness

    // Per-project opt-in: set LOCALTOOLS_AUTO_REINDEX=1 in the project's .mcp.json env block to
    // make search auto-reindex when the docs folder has changed. Default off (manual reindex).
    static bool AutoReindex
    {
        get
        {
            var v = Environment.GetEnvironmentVariable("LOCALTOOLS_AUTO_REINDEX");
            return !string.IsNullOrEmpty(v) &&
                   (v == "1" || v.Equals("true", StringComparison.OrdinalIgnoreCase)
                             || v.Equals("yes",  StringComparison.OrdinalIgnoreCase));
        }
    }

    // Caption images at index time (default ON - a few seconds per image, then cached).
    // Transcribe audio at index time (default OFF - can be minutes per file; enable per project).
    static bool CaptionImages => !IsOff(Environment.GetEnvironmentVariable("LOCALTOOLS_CAPTION_IMAGES"));
    static bool TranscribeAudio => IsOn(Environment.GetEnvironmentVariable("LOCALTOOLS_TRANSCRIBE_AUDIO"));
    static bool IsOn(string? v) => !string.IsNullOrEmpty(v) &&
        (v == "1" || v.Equals("true", StringComparison.OrdinalIgnoreCase) || v.Equals("yes", StringComparison.OrdinalIgnoreCase));
    static bool IsOff(string? v) => !string.IsNullOrEmpty(v) &&
        (v == "0" || v.Equals("false", StringComparison.OrdinalIgnoreCase) || v.Equals("no", StringComparison.OrdinalIgnoreCase));

    static readonly string OllamaHost =
        Environment.GetEnvironmentVariable("OLLAMA_HOST") ?? "http://localhost:11434";
    static readonly string EmbedModel =
        Environment.GetEnvironmentVariable("RAG_EMBED_MODEL") ?? "nomic-embed-text";

    static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(120) };

    // HYBRID mode: install.ps1 -Hybrid sets LOCALTOOLS_HYBRID=1. Program.cs registers HybridTools (the
    // local_generate drudge tool) ONLY when this is on, so in local/cloud mode the tool does not exist.
    public static bool HybridEnabled => IsOn(Environment.GetEnvironmentVariable("LOCALTOOLS_HYBRID"));
    // The LOCAL generation model behind local_generate. Defaults to the models.json default 'from' (devstral);
    // override per project with LOCALTOOLS_DRAFT_MODEL in .mcp.json.
    static readonly string DraftModel =
        Environment.GetEnvironmentVariable("LOCALTOOLS_DRAFT_MODEL") ?? "devstral";

    // ---------- embeddings (Ollama). We store RAW vectors; cosine is computed at search time by
    //            TensorPrimitives.CosineSimilarity (SIMD), so no manual normalize/dot needed. ----------
    static float[] ParseVector(JsonElement arr)
    {
        var vec = new float[arr.GetArrayLength()];
        int i = 0;
        foreach (var v in arr.EnumerateArray()) vec[i++] = (float)v.GetDouble();
        return vec;
    }

    // Single embedding (used for the search query). Handles new /api/embed and old /api/embeddings.
    static async Task<float[]> EmbedAsync(string text)
    {
        var attempts = new (string path, object payload, string key)[]
        {
            ("/api/embed", new { model = EmbedModel, input = text }, "embeddings"),
            ("/api/embeddings", new { model = EmbedModel, prompt = text }, "embedding"),
        };
        foreach (var a in attempts)
        {
            try
            {
                var resp = await Http.PostAsJsonAsync(OllamaHost + a.path, a.payload);
                resp.EnsureSuccessStatusCode();
                using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync());
                var el = doc.RootElement.GetProperty(a.key);
                return ParseVector(a.key == "embeddings" ? el[0] : el);
            }
            catch { /* try the next endpoint shape */ }
        }
        throw new Exception(
            $"Embedding failed. Is Ollama running and '{EmbedModel}' pulled? (ollama pull {EmbedModel})");
    }

    // Batch embedding: ONE /api/embed call for many texts (big indexing speedup vs one call per chunk).
    // Falls back to per-item if the batch endpoint isn't available or returns an unexpected count.
    static async Task<List<float[]>> EmbedBatchAsync(IReadOnlyList<string> texts)
    {
        try
        {
            var resp = await Http.PostAsJsonAsync(OllamaHost + "/api/embed", new { model = EmbedModel, input = texts });
            resp.EnsureSuccessStatusCode();
            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync());
            var rows = doc.RootElement.GetProperty("embeddings");
            if (rows.GetArrayLength() == texts.Count)
            {
                var result = new List<float[]>(texts.Count);
                foreach (var row in rows.EnumerateArray()) result.Add(ParseVector(row));
                return result;
            }
        }
        catch { /* fall back to per-item below */ }

        var list = new List<float[]>(texts.Count);
        foreach (var t in texts) list.Add(await EmbedAsync(t));
        return list;
    }

    // ---------- chunking + file reading ----------
    static readonly Regex HeadingRe = new(@"^#{1,6}\s", RegexOptions.Compiled);

    // Character-window splitter with overlap. Used for .txt, PDF pages, and oversized markdown sections.
    // An optional prefix (the section heading) is prepended to every piece so split chunks keep context.
    static IEnumerable<Chunk> ChunkText(string text, string source, int? page, string? prefix = null)
    {
        text = text.Trim();
        if (text.Length == 0) yield break;
        for (int i = 0; i < text.Length; i += ChunkChars - Overlap)
        {
            int len = Math.Min(ChunkChars, text.Length - i);
            var body = text.Substring(i, len);
            yield return new Chunk { Source = source, Page = page, Text = prefix is null ? body : prefix + "\n" + body };
            if (i + len >= text.Length) break;
        }
    }

    // Markdown-aware splitter: one chunk per heading section, so a search hit returns a whole
    // story / task / spec section instead of an arbitrary 1000-char window. Oversized sections fall back
    // to ChunkText (heading kept as a context prefix). Fenced ``` code blocks are skipped so a '#'/'###'
    // line INSIDE an example (e.g. the TASKS.md template) is not mistaken for a heading.
    static IEnumerable<Chunk> ChunkMarkdown(string text, string source)
    {
        var lines = text.Replace("\r\n", "\n").Replace("\r", "\n").Split('\n');
        var section = new System.Text.StringBuilder();
        string heading = "";

        IEnumerable<Chunk> Emit()
        {
            var body = section.ToString().Trim();
            section.Clear();
            if (body.Length == 0) yield break;
            if (body.Length <= ChunkChars) { yield return new Chunk { Source = source, Text = body }; yield break; }
            var rest = heading.Length > 0 && body.StartsWith(heading) ? body.Substring(heading.Length).TrimStart() : body;
            foreach (var c in ChunkText(rest, source, null, heading.Length > 0 ? heading : null)) yield return c;
        }

        var outChunks = new List<Chunk>();
        bool inFence = false;
        foreach (var line in lines)
        {
            if (line.TrimStart().StartsWith("```")) inFence = !inFence;
            if (!inFence && HeadingRe.IsMatch(line))
            {
                foreach (var c in Emit()) outChunks.Add(c);   // close the previous section
                heading = line.Trim();
            }
            section.AppendLine(line);
        }
        foreach (var c in Emit()) outChunks.Add(c);           // last section
        return outChunks;
    }

    static IEnumerable<Chunk> ReadFile(string path)
    {
        var ext = Path.GetExtension(path).ToLowerInvariant();
        var name = Path.GetFileName(path);
        if (ext == ".pdf")
        {
            using var pdf = PdfDocument.Open(path);
            foreach (var page in pdf.GetPages())
            {
                var txt = page.Text;
                if (!string.IsNullOrWhiteSpace(txt))
                    foreach (var c in ChunkText(txt, name, page.Number)) yield return c;
            }
        }
        else if (ext == ".md")
        {
            foreach (var c in ChunkMarkdown(File.ReadAllText(path), name)) yield return c;
        }
        else if (ext == ".txt")
        {
            foreach (var c in ChunkText(File.ReadAllText(path), name, null)) yield return c;
        }
        else if (ext == ".csv" || ext == ".tsv")
        {
            // A dataset is part of the corpus too: "what columns does the harvest log have, and what do
            // typical rows look like?" is a question the model asks constantly and previously could not
            // answer, because the index only held .pdf/.txt/.md. Chunking a CSV naively would bury the
            // header - the single most useful line - somewhere in chunk 1 and nowhere else, so the header
            // is REPEATED at the top of every chunk. Without that, chunk 7 is a wall of anonymous numbers.
            var lines = File.ReadAllLines(path);
            if (lines.Length == 0) yield break;
            var header = lines[0];
            const int rowsPerChunk = 40;
            for (int start = 1; start < lines.Length; start += rowsPerChunk)
            {
                var take = Math.Min(rowsPerChunk, lines.Length - start);
                var sb = new StringBuilder();
                sb.Append(name).Append(" rows ").Append(start).Append('-').Append(start + take - 1).Append('\n');
                sb.Append(header).Append('\n');
                for (int i = start; i < start + take; i++) sb.Append(lines[i]).Append('\n');
                yield return new Chunk { Source = name, Page = null, Text = sb.ToString() };
            }
        }
        else if (ext == ".json")
        {
            // Indexed as text. No parsing: a malformed or unusual JSON file must not break a reindex of
            // the whole corpus, and for retrieval the raw text is what answers "what shape is this file".
            foreach (var c in ChunkText(File.ReadAllText(path), name, null)) yield return c;
        }
    }

    static bool IsCorpusExt(string f)
    {
        var e = Path.GetExtension(f).ToLowerInvariant();
        return Exts.Contains(e) || ImgExts.Contains(e) || AudExts.Contains(e);
    }

    /// <summary>What would be indexed, grouped by root. No embeddings needed - a pure enumeration probe,
    /// so multi-root configuration can be checked (and tested) without Ollama running.</summary>
    public static string DescribeCorpus()
    {
        var files = CorpusFiles();
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"{DocsRoots.Length} root(s), {files.Count} indexable file(s):");
        foreach (var root in DocsRoots)
        {
            var mine = files.Where(f => f.StartsWith(root, StringComparison.OrdinalIgnoreCase)).ToList();
            var state = Directory.Exists(root) ? "" : "  [MISSING - skipped]";
            sb.AppendLine($"  {root}{state}  -> {mine.Count} file(s)");
            foreach (var f in mine.Take(20)) sb.AppendLine("      " + Path.GetRelativePath(root, f));
            if (mine.Count > 20) sb.AppendLine($"      ... +{mine.Count - 20} more");
        }
        sb.Append($"index: {IndexFile}");
        return sb.ToString();
    }

    // Walks EVERY configured root. A root that has gone missing (unmounted drive, moved reference
    // folder) contributes nothing instead of throwing - the rest of the corpus stays searchable.
    static List<string> CorpusFiles()
    {
        var outp = new List<string>();
        foreach (var root in DocsRoots)
        {
            if (!Directory.Exists(root)) continue;
            try
            {
                outp.AddRange(Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories)
                    .Where(f => IsCorpusExt(f)
                                && !f.StartsWith(IndexDir, StringComparison.OrdinalIgnoreCase)));  // never index our own index
            }
            catch (Exception e) when (e is UnauthorizedAccessException or IOException) { }
        }
        // Two roots can surface the same file via different paths (a junction, a symlink); index it once.
        return outp.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }

    // ---------- derived-text cache (captions / transcripts) ----------
    // Producing text from an image or audio file is expensive, and /build reindexes often. Cache the
    // result next to the index, keyed by the source file's mtime+size, so each file is processed ONCE.
    static string DerivedDir => Path.Combine(IndexDir, "derived");

    static async Task<string?> CachedSidecarAsync(string path, string kind, Func<Task<string>> produce)
    {
        var fi = new FileInfo(path);
        var sig = $"{fi.LastWriteTimeUtc.Ticks}|{fi.Length}";
        var key = Convert.ToHexString(
            System.Security.Cryptography.SHA1.HashData(System.Text.Encoding.UTF8.GetBytes(path))).ToLowerInvariant();
        var cacheFile = Path.Combine(DerivedDir, $"{kind}-{key}.txt");

        if (File.Exists(cacheFile))
        {
            var cached = await File.ReadAllTextAsync(cacheFile);
            var nl = cached.IndexOf('\n');
            if (nl > 0 && cached[..nl].Trim() == sig) return cached[(nl + 1)..];
        }

        string text;
        try { text = await produce(); }
        catch (Exception e) { Console.Error.WriteLine($"[index] {kind} failed for {Path.GetFileName(path)}: {e.Message}"); return null; }

        // Don't cache failures - the tool returns a human-readable error string rather than throwing,
        // so a later run (model pulled, uv installed) can succeed.
        if (string.IsNullOrWhiteSpace(text) || text.StartsWith("describe_image failed") ||
            text.StartsWith("transcribe failed") || text.StartsWith("File not found"))
        {
            Console.Error.WriteLine($"[index] skipped {kind} for {Path.GetFileName(path)}: {text?.Split('\n')[0]}");
            return null;
        }

        Directory.CreateDirectory(DerivedDir);
        await File.WriteAllTextAsync(cacheFile, sig + "\n" + text);
        return text;
    }

    // Cheap signature of the corpus (path + mtime + size per file) - no content reads. Used to
    // detect whether the docs folder changed since the last index.
    static string CorpusSignature()
    {
        var sb = new System.Text.StringBuilder();
        foreach (var f in CorpusFiles().OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
        {
            var fi = new FileInfo(f);
            sb.Append(f).Append('|').Append(fi.LastWriteTimeUtc.Ticks).Append('|').Append(fi.Length).Append('\n');
        }
        return Convert.ToHexString(
            System.Security.Cryptography.SHA1.HashData(System.Text.Encoding.UTF8.GetBytes(sb.ToString())));
    }

    static bool IsStale() => !File.Exists(SigFile) || File.ReadAllText(SigFile) != CorpusSignature();

    // ---------- public tool logic ----------
    public static async Task<string> IndexAsync()
    {
        Directory.CreateDirectory(DocsDir);
        Directory.CreateDirectory(IndexDir);
        var files = CorpusFiles();
        if (files.Count == 0)
            return $"No documents in {string.Join(" ; ", DocsRoots)}. Drop .pdf/.txt/.md files there and re-run.";

        var chunks = new List<Chunk>();
        int captioned = 0, transcribed = 0;
        foreach (var f in files)
        {
            var ext = Path.GetExtension(f).ToLowerInvariant();
            var name = Path.GetFileName(f);
            if (Exts.Contains(ext))
            {
                chunks.AddRange(ReadFile(f));
            }
            else if (ImgExts.Contains(ext))
            {
                if (!CaptionImages) continue;
                var text = await CachedSidecarAsync(f, "caption", () => DescribeImageAsync(f, null));
                if (text is null) continue;
                // Prefix the source so a hit reads as "this came from an image".
                chunks.AddRange(ChunkText($"[image: {name}]\n{text}", name, null));
                captioned++;
            }
            else if (AudExts.Contains(ext))
            {
                if (!TranscribeAudio) continue;
                var text = await CachedSidecarAsync(f, "transcript", () => Sensors.TranscribeAsync(f));
                if (text is null) continue;
                chunks.AddRange(ChunkText($"[audio: {name}]\n{text}", name, null));
                transcribed++;
            }
        }
        if (chunks.Count == 0)
            return "Found files but extracted no text (scanned PDFs need OCR; images need a vision model).";

        const int batch = 64;
        for (int i = 0; i < chunks.Count; i += batch)
        {
            int n = Math.Min(batch, chunks.Count - i);
            var texts = new List<string>(n);
            for (int k = 0; k < n; k++) texts.Add(chunks[i + k].Text);
            var vecs = await EmbedBatchAsync(texts);
            for (int k = 0; k < n; k++) chunks[i + k].Vector = vecs[k];
        }
        // Write atomically (temp + move) so a concurrent search never reads a half-written index -
        // /build reindexes after every task while other agents may be searching.
        var tmp = IndexFile + ".tmp";
        await File.WriteAllTextAsync(tmp, JsonSerializer.Serialize(chunks));
        File.Move(tmp, IndexFile, overwrite: true);
        await File.WriteAllTextAsync(SigFile, CorpusSignature());   // record what we just indexed

        var sources = chunks.Select(c => c.Source).Distinct().OrderBy(x => x).ToList();
        var extra = (captioned > 0 ? $" ({captioned} image(s) captioned" : "")
                  + (transcribed > 0 ? (captioned > 0 ? $", {transcribed} audio transcribed)" : $" ({transcribed} audio transcribed)")
                                     : (captioned > 0 ? ")" : ""));
        return $"Indexed {chunks.Count} chunks from {sources.Count} file(s){extra}: {string.Join(", ", sources)}";
    }

    public static async Task<string> SearchAsync(string query, int k)
    {
        if (!File.Exists(IndexFile))
        {
            var msg = await IndexAsync();
            if (!File.Exists(IndexFile)) return msg;
        }
        else if (AutoReindex && IsStale())   // opt-in: refresh if docs/ changed since last index
        {
            await IndexAsync();
        }
        var chunks = JsonSerializer.Deserialize<List<Chunk>>(await File.ReadAllTextAsync(IndexFile))
                     ?? new List<Chunk>();
        var q = await EmbedAsync(query);
        var top = chunks
            .Where(c => c.Vector is { Length: > 0 } v && v.Length == q.Length)   // skip null/dim-mismatched
            .Select(c => (c, score: TensorPrimitives.CosineSimilarity(c.Vector!, q)))
            .OrderByDescending(x => x.score).Take(k).ToList();
        if (top.Count == 0) return "No results.";

        var blocks = top.Select(t =>
        {
            var loc = t.c.Source + (t.c.Page is int p ? $" p.{p}" : "");
            return $"[{loc}] (score {t.score:F2})\n{t.c.Text.Trim()}";
        });
        return string.Join("\n\n---\n\n", blocks);
    }

    public static string ListDocs()
    {
        var files = CorpusFiles().Select(Path.GetFileName).OrderBy(x => x).ToList();
        return files.Count > 0
            ? (DocsRoots.Length > 1 ? $"roots: {string.Join(" ; ", DocsRoots)}\n" : "") + string.Join("\n", files)
            : $"(empty) Drop files in {string.Join(" ; ", DocsRoots)}";
    }

    // ---------- web (online only) ----------
    static string Slug(string url)
    {
        var s = new string(url.Select(ch => char.IsLetterOrDigit(ch) ? ch : '-').ToArray()).Trim('-');
        if (s.Length > 60) s = s[..60];
        var hash = Convert.ToHexString(
            System.Security.Cryptography.SHA1.HashData(System.Text.Encoding.UTF8.GetBytes(url)))[..8]
            .ToLowerInvariant();
        return $"{s}-{hash}";
    }

    static string HtmlToText(string html)
    {
        var dom = new HtmlParser().ParseDocument(html);
        foreach (var n in dom.QuerySelectorAll("script,style,nav,footer,header,noscript")) n.Remove();
        return dom.Body?.TextContent ?? "";
    }

    public static async Task<string> IngestUrlAsync(string url)
    {
        Directory.CreateDirectory(WebDir);
        byte[] raw;
        string ctype;
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.UserAgent.ParseAdd("Mozilla/5.0 (local-tools)");
            using var resp = await Http.SendAsync(req);
            resp.EnsureSuccessStatusCode();
            ctype = resp.Content.Headers.ContentType?.MediaType ?? "";
            raw = await resp.Content.ReadAsByteArrayAsync();
        }
        catch (Exception e) { return $"Could not fetch {url} (are you online?): {e.Message}"; }

        var slug = Slug(url);
        string destName;
        if (ctype.Contains("pdf") || url.ToLowerInvariant().EndsWith(".pdf"))
        {
            destName = $"web/{slug}.pdf";
            await File.WriteAllBytesAsync(Path.Combine(WebDir, $"{slug}.pdf"), raw);
        }
        else
        {
            var text = HtmlToText(System.Text.Encoding.UTF8.GetString(raw));
            destName = $"web/{slug}.md";
            await File.WriteAllTextAsync(Path.Combine(WebDir, $"{slug}.md"), $"# Source: {url}\n\n{text}");
        }
        return $"Ingested {url} -> {destName}. {await IndexAsync()}";
    }

    public static async Task<string> WebSearchAsync(string query, int k)
    {
        string html;
        try
        {
            using var req = new HttpRequestMessage(
                HttpMethod.Get, "https://html.duckduckgo.com/html/?q=" + Uri.EscapeDataString(query));
            req.Headers.UserAgent.ParseAdd("Mozilla/5.0 (local-tools)");
            using var resp = await Http.SendAsync(req);
            resp.EnsureSuccessStatusCode();
            html = await resp.Content.ReadAsStringAsync();
        }
        catch (Exception e) { return $"Web search failed (are you online?): {e.Message}"; }

        var dom = new HtmlParser().ParseDocument(html);
        var results = dom.QuerySelectorAll("a.result__a").Take(k).Select(a =>
        {
            var title = a.TextContent.Trim();
            var href = a.GetAttribute("href") ?? "";
            // DuckDuckGo wraps links as /l/?uddg=<urlencoded>&... - unwrap to the real URL.
            var idx = href.IndexOf("uddg=", StringComparison.Ordinal);
            if (idx >= 0)
            {
                var enc = href[(idx + 5)..];
                var amp = enc.IndexOf('&');
                if (amp >= 0) enc = enc[..amp];
                href = Uri.UnescapeDataString(enc);
            }
            return $"- {title}\n  {href}";
        }).ToList();

        return results.Count > 0
            ? string.Join("\n", results)
            : "No results (or DuckDuckGo markup changed - tweak the selector in Rag.WebSearchAsync).";
    }

    // ---------- vision (a LOCAL multimodal model over Ollama; offline) ----------
    // Reads an image (whiteboard photo, screenshot, diagram) and returns its content as text.
    // Default model is gemma3:4b - multimodal, and install.ps1 already pulls it. Override per project
    // with LOCALTOOLS_VISION_MODEL in .mcp.json (e.g. qwen2.5vl, llama3.2-vision, minicpm-v).
    static readonly string VisionModel =
        Environment.GetEnvironmentVariable("LOCALTOOLS_VISION_MODEL") ?? "gemma3:4b";

    public static async Task<string> DescribeImageAsync(string path, string? prompt)
    {
        if (!File.Exists(path)) return $"File not found: {path}";
        var ext = Path.GetExtension(path).ToLowerInvariant();
        if (ext is not (".png" or ".jpg" or ".jpeg" or ".webp" or ".gif" or ".bmp"))
            return $"Unsupported image type '{ext}' (use png/jpg/jpeg/webp/gif/bmp).";

        var b64 = Convert.ToBase64String(await File.ReadAllBytesAsync(path));
        var ask = string.IsNullOrWhiteSpace(prompt)
            ? "Describe this image precisely. If it is a whiteboard, diagram, or screenshot of a design or " +
              "architecture: transcribe ALL text exactly, then describe every box/node, arrow/connection, " +
              "and grouping as structured text an engineer could rebuild the diagram from."
            : prompt;
        try
        {
            var resp = await Http.PostAsJsonAsync(OllamaHost + "/api/chat", new
            {
                model = VisionModel,
                stream = false,
                messages = new[] { new { role = "user", content = ask, images = new[] { b64 } } }
            });
            resp.EnsureSuccessStatusCode();
            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync());
            var text = doc.RootElement.GetProperty("message").GetProperty("content").GetString();
            return string.IsNullOrWhiteSpace(text) ? "(the vision model returned no text)" : text!;
        }
        catch (Exception e)
        {
            return $"describe_image failed: {e.Message}. Is Ollama running, and is '{VisionModel}' a pulled " +
                   "VISION-capable model? Set LOCALTOOLS_VISION_MODEL in the project's .mcp.json env to " +
                   "override (e.g. gemma3:4b, qwen2.5vl, llama3.2-vision, minicpm-v).";
        }
    }

    // ---------- local generation (HYBRID mode; the 5080 as a drudge co-processor) ----------
    // The cloud model runs the agent loop and delegates BOUNDED, low-stakes generation here to keep it off the
    // cloud budget: an implementation GUESS it will review, synthetic TEST DATA, boilerplate. The output is a
    // DRAFT - it is prefixed so the caller (and its logs) can never mistake it for a verified result.
    public static async Task<string> LocalGenerateAsync(string prompt, string? system)
    {
        if (string.IsNullOrWhiteSpace(prompt)) return "local_generate: empty prompt.";
        try
        {
            var messages = new List<object>();
            if (!string.IsNullOrWhiteSpace(system)) messages.Add(new { role = "system", content = system });
            messages.Add(new { role = "user", content = prompt });
            var resp = await Http.PostAsJsonAsync(OllamaHost + "/api/chat", new
            {
                model = DraftModel,
                stream = false,
                messages = messages.ToArray()
            });
            resp.EnsureSuccessStatusCode();
            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync());
            var text = doc.RootElement.GetProperty("message").GetProperty("content").GetString();
            return string.IsNullOrWhiteSpace(text)
                ? "(the local model returned no text)"
                : $"[LOCAL DRAFT from {DraftModel} - verify before use]\n\n{text}";
        }
        catch (Exception e)
        {
            return $"local_generate failed: {e.Message}. Is Ollama running and '{DraftModel}' pulled? " +
                   $"(ollama pull {DraftModel}); override the model with LOCALTOOLS_DRAFT_MODEL in .mcp.json.";
        }
    }
}

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using LocalTools;

// One-off CLI reindex (for manual runs / scheduled tasks), does NOT start the MCP server:
//   local-tools.exe --reindex "C:\path\to\project\docs"
// The path arg is optional; without it, uses LOCALTOOLS_DOCS_DIR. Exit code 0 = success.
if (args.Length > 0 && args[0] == "--reindex")
{
    if (args.Length > 1) Environment.SetEnvironmentVariable("LOCALTOOLS_DOCS_DIR", args[1]);
    try { Console.WriteLine(await Rag.IndexAsync()); }
    catch (Exception e) { Console.Error.WriteLine("reindex failed: " + e.Message); Environment.Exit(1); }
    return;
}

// One-off CLI web INGEST into a chosen root, does NOT start the MCP server:
//   local-tools.exe --ingest "https://example.com/page" ["C:\path\to\corpus"]
// The ingest_url MCP tool always writes to the RUNNING server's root - the current project's docs\web\ -
// because WebDir is fixed from LOCALTOOLS_DOCS_DIR at server start and a per-call env change cannot move it.
// So a /corpus refresh could not fetch into its OWN folder; it landed in whatever project was open. This
// shell door fetches into the GIVEN root's web\ and reindexes THAT root, so 'dad corpus ingest' targets the
// corpus, not the project. Falls back to LOCALTOOLS_DOCS_DIR when no root arg is given. Exit code 0 = success.
if (args.Length > 0 && args[0] == "--ingest")
{
    if (args.Length < 2) { Console.Error.WriteLine("usage: local-tools.exe --ingest \"url\" [docsDir]"); Environment.Exit(1); return; }
    if (args.Length > 2) Environment.SetEnvironmentVariable("LOCALTOOLS_DOCS_DIR", args[2]);
    try { Console.WriteLine(await Rag.IngestUrlAsync(args[1])); }
    catch (Exception e) { Console.Error.WriteLine("ingest failed: " + e.Message); Environment.Exit(1); }
    return;
}

// One-off CLI corpus SEARCH, does NOT start the MCP server:
//   local-tools.exe --search "what does C9 say about tile sizes" [topK]
// The same semantic search as the search_datasheets MCP tool, reachable from a SHELL. Across nine graded
// runs search_datasheets was called ZERO times while the kit's own .ps1 scripts were called constantly -
// the model reaches for the shell, so the corpus needs a shell door. It also works when the MCP server is
// NOT connected, which is exactly when you most need to look something up and least expect to fail.
if (args.Length > 0 && args[0] == "--search")
{
    if (args.Length < 2) { Console.Error.WriteLine("usage: local-tools.exe --search \"query\" [topK]"); Environment.Exit(1); return; }
    var topK = 5;
    if (args.Length > 2 && int.TryParse(args[2], out var k)) topK = k;
    try { Console.WriteLine(await Rag.SearchAsync(args[1], topK)); }
    catch (Exception e) { Console.Error.WriteLine("search failed: " + e.Message); Environment.Exit(1); }
    return;
}

// One-off CLI corpus listing, does NOT start the MCP server:
//   local-tools.exe --corpus            what WOULD be indexed, per root
// Needs no Ollama, so it is how you debug LOCALTOOLS_DOCS_DIR (including multi-root ";" lists) and how
// the test suite verifies enumeration without embeddings.
if (args.Length > 0 && args[0] == "--corpus")
{
    if (args.Length > 1) Environment.SetEnvironmentVariable("LOCALTOOLS_DOCS_DIR", args[1]);
    try { Console.WriteLine(Rag.DescribeCorpus()); }
    catch (Exception e) { Console.Error.WriteLine("corpus listing failed: " + e.Message); Environment.Exit(1); }
    return;
}

// One-off CLI API-surface generation, does NOT start the MCP server:
//   local-tools.exe --api-surface "C:\path\to\project" ["C:\out\API-SURFACE.md"]
// Reflects over the project's built assemblies and its NuGet dependencies, writing exact public
// signatures into docs\API-SURFACE.md so the RAG index carries them. Run after every build.
if (args.Length > 0 && args[0] == "--api-surface")
{
    var dir = args.Length > 1 ? args[1] : Directory.GetCurrentDirectory();
    var outFile = args.Length > 2 ? args[2] : null;
    try { Console.WriteLine(ApiSurface.Generate(dir, outFile)); }
    catch (Exception e) { Console.Error.WriteLine("api-surface failed: " + e.Message); Environment.Exit(1); }
    return;
}

// MCP speaks JSON-RPC over stdout. ANY stray text on stdout corrupts the stream and the
// client kills the connection - so all logging must go to stderr.
var builder = Host.CreateApplicationBuilder(args);
builder.Logging.AddConsole(o => o.LogToStandardErrorThreshold = LogLevel.Trace);

// Register each tool TYPE explicitly (rather than scanning the whole assembly) so the HYBRID tool set can be
// gated: the base tools are always present; HybridTools (local_generate) is added ONLY when LOCALTOOLS_HYBRID=1,
// so in local/cloud mode that tool does not exist in the advertised list at all.
var mcp = builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithTools<Tools>();
if (Rag.HybridEnabled) mcp.WithTools<HybridTools>();

await builder.Build().RunAsync();

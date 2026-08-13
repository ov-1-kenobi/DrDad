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

builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly();   // discovers [McpServerToolType] classes + [McpServerTool] methods

await builder.Build().RunAsync();

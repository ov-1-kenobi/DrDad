using System.ComponentModel;
using ModelContextProtocol.Server;

namespace LocalTools;

// Every public method here becomes an MCP tool. In Claude Code they appear as
// mcp__local-tools__<Name>. Keep these thin - the real work lives in Rag.cs.
[McpServerToolType]
public class Tools   // non-static: WithTools<T> needs a real type arg; the methods stay static
{
    [McpServerTool(Name = "index_datasheets"), Description(
        "(Re)build the search index over the project's docs folder - design docs, stories, the task map, " +
        "notes, datasheets (.pdf/.txt/.md). Run after adding or changing docs so searches see the update.")]
    public static Task<string> IndexDatasheets() => Rag.IndexAsync();

    [McpServerTool(Name = "search_datasheets"), Description(
        "Semantic search over the project's indexed docs (DESIGN/TEDD, stories, TASKS, notes, datasheets). " +
        "Returns the top-k most relevant passages with source file and page. Use it to pull a specific fact " +
        "- a story's acceptance, a spec value, a register/pinout - instead of loading whole docs into context.")]
    public static Task<string> SearchDatasheets(
        [Description("What to look up, e.g. 'BME280 I2C address and ctrl_meas register'")] string query,
        [Description("How many passages to return (default 5)")] int k = 5)
        => Rag.SearchAsync(query, k);

    [McpServerTool(Name = "list_datasheets"), Description(
        "List the documents currently in the project's docs corpus.")]
    public static string ListDatasheets() => Rag.ListDocs();

    [McpServerTool(Name = "ingest_url"), Description(
        "ONLINE ONLY. Fetch a web page or PDF from a URL, extract its text, save it into the project's " +
        "docs corpus, and re-index so it is searchable forever - including offline later. " +
        "Use this to permanently capture a reference you found via web_search.")]
    public static Task<string> IngestUrl(
        [Description("The URL to fetch and persist")] string url)
        => Rag.IngestUrlAsync(url);

    [McpServerTool(Name = "web_search"), Description(
        "ONLINE ONLY. Keyless DuckDuckGo web search. Returns top result titles + URLs. Follow up " +
        "with ingest_url to persist a source for offline use.")]
    public static Task<string> WebSearch(
        [Description("Search query")] string query,
        [Description("How many results to return (default 5)")] int k = 5)
        => Rag.WebSearchAsync(query, k);

    [McpServerTool(Name = "describe_image"), Description(
        "OFFLINE-OK. Read an image (whiteboard photo, screenshot, diagram) with a LOCAL vision model and " +
        "return its content as text: transcribed labels + boxes/arrows/relationships. Use it to seed /forge " +
        "from a whiteboard or to read an architecture screenshot. Default model gemma3:4b (installed by the " +
        "kit); override with LOCALTOOLS_VISION_MODEL in .mcp.json.")]
    public static Task<string> DescribeImage(
        [Description("Path to the image file (png/jpg/jpeg/webp/gif/bmp)")] string path,
        [Description("Optional custom question; default = transcribe + describe the diagram/architecture")] string? prompt = null)
        => Rag.DescribeImageAsync(path, prompt);

    [McpServerTool(Name = "detect_objects"), Description(
        "OFFLINE-OK. Locate objects in an image with a local ONNX detector - returns labels with confidence " +
        "and pixel bounding boxes. Use when you need WHERE something is (layout/element position, visual " +
        "verification, counting), as opposed to describe_image which tells you WHAT an image shows. " +
        "Requires LOCALTOOLS_DETECT_MODEL (a YOLO-family .onnx) in .mcp.json; classes default to COCO-80.")]
    public static Task<string> DetectObjects(
        [Description("Path to the image file")] string path,
        [Description("Minimum confidence 0..1 (default 0.35)")] float minConfidence = 0.35f,
        [Description("NMS IoU overlap threshold 0..1 (default 0.45)")] float iouThreshold = 0.45f)
        => Sensors.DetectAsync(path, minConfidence, iouThreshold);

    [McpServerTool(Name = "transcribe_audio"), Description(
        "OFFLINE-OK. Transcribe a recording (wav/mp3/m4a/flac/ogg) to timestamped text with local Whisper. " +
        "Use to turn a recorded spec discussion or voice note into searchable text. Requires uv " +
        "(winget install astral-sh.uv); model via LOCALTOOLS_WHISPER_MODEL (default small).")]
    public static Task<string> TranscribeAudio(
        [Description("Path to the audio file")] string path)
        => Sensors.TranscribeAsync(path);
}

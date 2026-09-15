using System.ComponentModel;
using ModelContextProtocol.Server;

namespace LocalTools;

// Tools exposed ONLY in HYBRID mode (install.ps1 -Hybrid sets LOCALTOOLS_HYBRID=1). In hybrid, the CLOUD
// model runs the agent loop and can hand BOUNDED, low-stakes generation to the LOCAL model on this machine's
// GPU - the 5080 as a drudge co-processor. Program.cs registers this type only when Rag.HybridEnabled is true,
// so in local/cloud mode the tool does not exist at all (not merely disabled). Keep these thin - the work
// lives in Rag.cs.
[McpServerToolType]
public class HybridTools   // non-static: WithTools<T> needs a real type arg; the methods stay static
{
    [McpServerTool(Name = "local_generate"), Description(
        "HYBRID MODE. Delegate a BOUNDED, low-stakes generation to the LOCAL model on this machine's GPU, to " +
        "keep drudge-work off the cloud budget. Good for: a first-pass IMPLEMENTATION GUESS you will review, " +
        "synthetic TEST DATA / fixtures, boilerplate, throwaway scaffolding. Returns the local model's raw text " +
        "as a DRAFT (prefixed as such) - you MUST read and correct it before use; NEVER bank, ship, or trust it " +
        "unverified, and do NOT use it for reasoning that has to be right or for anything a test cannot check. " +
        "Model defaults to devstral; override with LOCALTOOLS_DRAFT_MODEL in .mcp.json.")]
    public static Task<string> LocalGenerate(
        [Description("The instruction / prompt for the local model")] string prompt,
        [Description("Optional system framing, e.g. 'Return only JSON rows, no prose'")] string? system = null)
        => Rag.LocalGenerateAsync(prompt, system);
}

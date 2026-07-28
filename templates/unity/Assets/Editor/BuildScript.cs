using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

// Headless build entry point. Invoked from the CLI with:
//   Unity.exe -batchmode -nographics -quit -projectPath <proj> -executeMethod BuildScript.PerformBuild -logFile -
// Calls EditorApplication.Exit with 0 (success) / 1 (failure) so the CLI reflects the result.
public static class BuildScript
{
    public static void PerformBuild()
    {
        var scenes = EditorBuildSettings.scenes
            .Where(s => s.enabled)
            .Select(s => s.path)
            .ToArray();

        var options = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = "Builds/Game.exe",
            target = BuildTarget.StandaloneWindows64,
            options = BuildOptions.None,
        };

        BuildReport report = BuildPipeline.BuildPlayer(options);
        BuildSummary summary = report.summary;

        if (summary.result == BuildResult.Succeeded)
        {
            Debug.Log($"BUILD SUCCEEDED: {summary.totalSize} bytes, {summary.totalTime}");
            EditorApplication.Exit(0);
        }
        else
        {
            Debug.LogError($"BUILD FAILED: {summary.result} ({summary.totalErrors} errors)");
            EditorApplication.Exit(1);
        }
    }
}

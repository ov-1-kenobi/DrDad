using System.Reflection;
using System.Reflection.Metadata;
using System.Text;

namespace LocalTools;

/// <summary>
/// Generates docs/API-SURFACE.md: the exact public signatures of a solution's own assemblies AND of the
/// third-party packages it references, read straight out of the compiled DLLs.
///
/// Why this exists: a dev model that cannot find a signature INVENTS one. One project shipped 16 compile
/// errors from guessed Magick.NET calls; a later task burned 4h25m whose own summary was "fixed all Azure
/// Table Storage API calls to use proper generic type parameters". That is signature archaeology, and the
/// answer was sitting in the DLLs the whole time.
///
/// Reflection, not source parsing: the metadata IS the truth, there is nothing to misparse, and it covers
/// NuGet dependencies whose source you do not have. MetadataLoadContext reads without executing or
/// locking, so this is safe to run on every build and works across target frameworks (a net8.0 tool can
/// read net10.0 assemblies - which is also why this lives here and not in PowerShell 5.1, which runs on
/// .NET Framework and cannot load them at all).
///
/// The output lands in docs/, so it is picked up by the SAME index everything else uses - no new tool,
/// no new server, and search_datasheets can already find it.
/// </summary>
public static class ApiSurface
{
    // Third-party surface is only useful for what the solution actually touches; emitting all of Azure
    // SDK would bury the project's own types and blow the index up.
    private static readonly string[] AlwaysSkip =
    {
        "System.", "Microsoft.CodeAnalysis", "Microsoft.Extensions.", "Microsoft.Win32.",
        "netstandard", "mscorlib", "WindowsBase", "Microsoft.CSharp", "Microsoft.VisualStudio.TestPlatform",
        "xunit", "NUnit", "Moq", "FluentAssertions", "Castle.", "coverlet", "testhost", "JetBrains."
    };

    public static string Generate(string projectDir, string? outFile = null)
    {
        projectDir = Path.GetFullPath(projectDir);
        outFile ??= Path.Combine(projectDir, "docs", "API-SURFACE.md");

        // Prefer Debug then Release; take the newest copy of each assembly name.
        var dlls = new Dictionary<string, FileInfo>(StringComparer.OrdinalIgnoreCase);
        foreach (var f in Directory.EnumerateFiles(projectDir, "*.dll", SearchOption.AllDirectories))
        {
            var parts = f.Split(Path.DirectorySeparatorChar);
            if (!parts.Contains("bin")) continue;                 // built output only
            if (parts.Contains("obj")) continue;
            var name = Path.GetFileNameWithoutExtension(f);
            if (AlwaysSkip.Any(s => name.StartsWith(s, StringComparison.OrdinalIgnoreCase))) continue;
            var fi = new FileInfo(f);
            if (!dlls.TryGetValue(name, out var prev) || fi.LastWriteTimeUtc > prev.LastWriteTimeUtc)
                dlls[name] = fi;
        }
        if (dlls.Count == 0) return "no built assemblies found under bin\\ - build the solution first";

        // Which assemblies are the SOLUTION's own? One per .csproj in the tree.
        var ownNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        // ...and which third-party packages did the project DELIBERATELY reference? Only those. Walking
        // every DLL under bin/ pulled 131 assemblies and 3,928 types (1.2 MB) - transitive dependencies
        // nobody writes code against, which would bury the project's own types in the index and make the
        // whole file useless. Direct PackageReferences are the ones a dev-agent actually calls.
        var wanted = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var proj in Directory.EnumerateFiles(projectDir, "*.csproj", SearchOption.AllDirectories))
        {
            if (proj.Split(Path.DirectorySeparatorChar).Contains("obj")) continue;
            ownNames.Add(Path.GetFileNameWithoutExtension(proj));
            try
            {
                foreach (var line in File.ReadLines(proj))
                {
                    var m = System.Text.RegularExpressions.Regex.Match(line, @"PackageReference\s+Include=""([^""]+)""");
                    if (m.Success) wanted.Add(m.Groups[1].Value);
                }
            }
            catch { }
        }
        // Package id must be a prefix of the ASSEMBLY name, one direction only. Matching both ways let
        // the package Microsoft.AspNetCore.Mvc.Testing drag in the entire Mvc family (14 assemblies of
        // framework surface nobody was going to call).
        bool Wanted(string asm) =>
            (ownNames.Contains(asm) && !asm.EndsWith(".Tests", StringComparison.OrdinalIgnoreCase)) ||
            wanted.Any(w => asm.Equals(w, StringComparison.OrdinalIgnoreCase)
                         || asm.StartsWith(w + ".", StringComparison.OrdinalIgnoreCase));
        // Resolution and emission are DIFFERENT sets. TableClient's methods return Response<T> from
        // Azure.Core, which is not a direct PackageReference - dropping it from the resolver made every
        // one of those signatures unresolvable, and the type came out with a single constructor and no
        // methods at all. Keep everything for the resolver; filter only what gets WRITTEN.
        var resolverPaths = dlls.Values.Select(f => f.FullName).ToList();
        foreach (var k in dlls.Keys.Where(k => !Wanted(k)).ToList()) dlls.Remove(k);
        if (dlls.Count == 0) return "no relevant assemblies (no .csproj PackageReferences matched bin\\ output)";
        // Runtime assemblies must be resolvable or member signatures fail to load.
        resolverPaths.AddRange(Directory.GetFiles(Path.GetDirectoryName(typeof(object).Assembly.Location)!, "*.dll"));

        var sb = new StringBuilder();
        sb.AppendLine("# API surface (generated - do not edit)");
        sb.AppendLine();
        sb.AppendLine("Exact public signatures read from the compiled assemblies. Regenerated on every build,");
        sb.AppendLine("so it cannot drift from the code. **Search this before writing a call you are unsure of** -");
        sb.AppendLine("it is faster than grepping source and it is the only copy that includes NuGet packages.");
        sb.AppendLine();

        int typeCount = 0;
        using var mlc = new MetadataLoadContext(new PathAssemblyResolver(resolverPaths));

        foreach (var own in new[] { true, false })
        {
            var group = dlls.Keys.Where(k => ownNames.Contains(k) == own)
                                 .OrderBy(k => k, StringComparer.OrdinalIgnoreCase).ToList();
            if (group.Count == 0) continue;
            sb.AppendLine(own ? "## This solution" : "## Referenced packages");
            sb.AppendLine();

            foreach (var asmName in group)
            {
                Assembly asm;
                try { asm = mlc.LoadFromAssemblyPath(dlls[asmName].FullName); }
                catch { continue; }

                Type[] types;
                try { types = asm.GetExportedTypes(); }
                catch (Exception e) when (e is TypeLoadException or FileNotFoundException or ReflectionTypeLoadException) { continue; }
                if (types.Length == 0) continue;

                sb.AppendLine($"### {asmName}");
                sb.AppendLine();
                foreach (var t in types.OrderBy(t => t.FullName, StringComparer.Ordinal))
                {
                    if (t.IsNested) continue;
                    var members = Describe(t, deep: own);
                    if (members.Count == 0) continue;
                    typeCount++;
                    sb.AppendLine($"`{Kind(t)} {Pretty(t)}`");
                    foreach (var m in members) sb.AppendLine($"  - `{m}`");
                    sb.AppendLine();
                }
            }
        }

        sb.AppendLine("---");
        sb.AppendLine($"{typeCount} public type(s) from {dlls.Count} assembly(ies).");

        Directory.CreateDirectory(Path.GetDirectoryName(outFile)!);
        File.WriteAllText(outFile, sb.ToString(), new UTF8Encoding(false));
        return $"wrote {outFile} ({typeCount} types, {dlls.Count} assemblies)";
    }

    private static string Kind(Type t) =>
        t.IsInterface ? "interface" : t.IsEnum ? "enum" : t.IsValueType ? "struct" : "class";

    private static List<string> Describe(Type t, bool deep)
    {
        var outp = new List<string>();
        try
        {
            if (t.IsEnum)
            {
                outp.Add("values: " + string.Join(", ", t.GetFields(BindingFlags.Public | BindingFlags.Static).Select(f => f.Name)));
                return outp;
            }
            const BindingFlags F = BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;
            // Per-member try/catch, NOT one around the whole walk: a single signature naming a type the
            // load context cannot resolve used to abort the rest, so TableClient emitted one constructor
            // and none of its methods - the exact signatures we are here to provide.
            void Try(Action a) { try { a(); } catch { } }
            Try(() => { foreach (var c in t.GetConstructors(F)) Try(() => outp.Add($"{t.Name}({Params(c)})")); });
            Try(() => { foreach (var m in t.GetMethods(F).Where(m => !m.IsSpecialName).OrderBy(m => m.Name, StringComparer.Ordinal))
                            Try(() => outp.Add($"{Pretty(m.ReturnType)} {m.Name}{Generics(m)}({Params(m)})")); });
            Try(() => { foreach (var p in t.GetProperties(F).OrderBy(p => p.Name, StringComparer.Ordinal))
                            Try(() => outp.Add($"{Pretty(p.PropertyType)} {p.Name} {{ {(p.CanRead ? "get; " : "")}{(p.CanWrite ? "set; " : "")}}}")); });
            // A dependency's every property is noise; its call signatures are the point.
            // Trim by KIND, not by position: truncating the tail cut methods off dependencies, which is
            // the only part anyone needs from them.
            if (!deep && outp.Count > 60)
                outp = outp.Where(s => !s.Contains(" { get")).Take(60).Append("... (properties omitted)").ToList();
        }
        catch { /* a type whose dependencies did not resolve - skip it rather than fail the file */ }
        return outp;
    }

    private static string Generics(MethodInfo m) =>
        m.IsGenericMethodDefinition ? "<" + string.Join(", ", m.GetGenericArguments().Select(a => a.Name)) + ">" : "";

    private static string Params(MethodBase m) =>
        string.Join(", ", m.GetParameters().Select(p =>
            $"{(p.IsOut ? "out " : "")}{Pretty(p.ParameterType)} {p.Name}{(p.HasDefaultValue ? " = ..." : "")}"));

    private static string Pretty(Type t)
    {
        if (t.IsByRef) return Pretty(t.GetElementType()!);   // "out"/"ref" is added by the caller
        if (t.IsArray) return Pretty(t.GetElementType()!) + "[]";
        if (!t.IsGenericType) return Simple(t.Name);
        var name = t.Name;
        var tick = name.IndexOf('`');
        if (tick > 0) name = name.Substring(0, tick);
        return $"{name}<{string.Join(", ", t.GetGenericArguments().Select(Pretty))}>";
    }

    private static string Simple(string n) => n switch
    {
        "Void" => "void", "Int32" => "int", "Int64" => "long", "String" => "string", "Boolean" => "bool",
        "Double" => "double", "Single" => "float", "Object" => "object", "Byte" => "byte", "Char" => "char",
        "Decimal" => "decimal", _ => n
    };
}

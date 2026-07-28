using System.Diagnostics;
using Microsoft.ML.OnnxRuntime;
using SkiaSharp;

namespace LocalTools;

/// <summary>
/// "Sensor" tools: turn non-text input into TEXT the agent can reason over.
///   - DetectAsync:     ONNX object detection (bring your own YOLO-family .onnx) -> labels + boxes.
///   - TranscribeAsync: speech-to-text via a uv-run faster-whisper helper -> transcript.
/// Both are EPHEMERAL and small: they run, emit text, and release - so the chat model stays resident.
/// Everything returns text so it flows into the normal RAG/context path (no pixels/audio in context).
/// </summary>
public static class Sensors
{
    // ---------- object detection (ONNX, CPU) ----------
    static readonly string? DetectModel = Environment.GetEnvironmentVariable("LOCALTOOLS_DETECT_MODEL");
    static readonly string? LabelsPath  = Environment.GetEnvironmentVariable("LOCALTOOLS_DETECT_LABELS");
    static InferenceSession? _session;
    static string[]? _labels;
    static readonly object _initLock = new();

    static string[] LoadLabels()
    {
        if (_labels is not null) return _labels;
        if (!string.IsNullOrWhiteSpace(LabelsPath) && File.Exists(LabelsPath))
            _labels = File.ReadAllLines(LabelsPath).Where(l => l.Trim().Length > 0).Select(l => l.Trim()).ToArray();
        else
            _labels = CocoLabels;
        return _labels;
    }

    static InferenceSession GetSession(string modelPath)
    {
        lock (_initLock) { return _session ??= new InferenceSession(modelPath); }
    }

    public static Task<string> DetectAsync(string imagePath, float minConfidence, float iouThreshold)
    {
        if (string.IsNullOrWhiteSpace(DetectModel))
            return Task.FromResult(
                "detect_objects is not configured. Set LOCALTOOLS_DETECT_MODEL in this project's .mcp.json env " +
                "to an ONNX detector (a YOLOv8/v11 export works; e.g. yolov8n.onnx), and optionally " +
                "LOCALTOOLS_DETECT_LABELS to a text file with one class name per line (defaults to COCO-80).");
        if (!File.Exists(DetectModel))
            return Task.FromResult($"Detector model not found: {DetectModel}");
        if (!File.Exists(imagePath))
            return Task.FromResult($"File not found: {imagePath}");

        try { return Task.FromResult(Detect(imagePath, minConfidence, iouThreshold)); }
        catch (Exception e)
        {
            return Task.FromResult($"detect_objects failed: {e.Message}. Confirm the model is a YOLO-family " +
                                   "ONNX export with output [1, 4+numClasses, anchors] (or the transposed form).");
        }
    }

    static string Detect(string imagePath, float minConf, float iou)
    {
        var session = GetSession(DetectModel!);
        var labels = LoadLabels();

        // --- model input geometry (NCHW; fall back to 640x640 if the model has dynamic dims) ---
        var inputMeta = session.InputMetadata.First();
        var dims = inputMeta.Value.Dimensions;
        int inW = dims.Length == 4 && dims[3] > 0 ? dims[3] : 640;
        int inH = dims.Length == 4 && dims[2] > 0 ? dims[2] : 640;

        using var bmp = SKBitmap.Decode(imagePath)
            ?? throw new Exception("could not decode the image (unsupported or corrupt file)");
        int origW = bmp.Width, origH = bmp.Height;

        // --- letterbox: scale preserving aspect, pad to inW x inH so boxes map back cleanly ---
        float scale = Math.Min((float)inW / origW, (float)inH / origH);
        int newW = (int)Math.Round(origW * scale), newH = (int)Math.Round(origH * scale);
        int padX = (inW - newW) / 2, padY = (inH - newH) / 2;

        using var canvasBmp = new SKBitmap(inW, inH, SKColorType.Rgba8888, SKAlphaType.Premul);
        using (var canvas = new SKCanvas(canvasBmp))
        {
            canvas.Clear(new SKColor(114, 114, 114));   // standard YOLO letterbox grey
            using var resized = bmp.Resize(new SKImageInfo(newW, newH), SKFilterQuality.Medium)
                ?? throw new Exception("image resize failed");
            canvas.DrawBitmap(resized, padX, padY);
        }

        // --- NCHW float tensor, RGB, normalized 0..1 ---
        var input = new Microsoft.ML.OnnxRuntime.Tensors.DenseTensor<float>(new[] { 1, 3, inH, inW });
        for (int y = 0; y < inH; y++)
            for (int x = 0; x < inW; x++)
            {
                var p = canvasBmp.GetPixel(x, y);
                input[0, 0, y, x] = p.Red   / 255f;
                input[0, 1, y, x] = p.Green / 255f;
                input[0, 2, y, x] = p.Blue  / 255f;
            }

        using var results = session.Run(new[] {
            NamedOnnxValue.CreateFromTensor(inputMeta.Key, input)
        });

        var outTensor = results.First().AsTensor<float>();
        var od = outTensor.Dimensions.ToArray();
        if (od.Length != 3) throw new Exception($"unexpected output rank {od.Length} (expected 3)");

        // YOLOv8/v11: [1, 4+nc, anchors].  YOLOv5: [1, anchors, 5+nc].
        // Disambiguate by which of the last two dims is the "channel" dim (the smaller one).
        bool channelsFirst = od[1] <= od[2];
        int channels = channelsFirst ? od[1] : od[2];
        int anchors  = channelsFirst ? od[2] : od[1];
        float Get(int c, int a) => channelsFirst ? outTensor[0, c, a] : outTensor[0, a, c];

        int nc = channels - 4;                 // v8 layout: 4 box + nc class scores
        int classOffset = 4;
        bool hasObjectness = false;
        if (nc - 1 == labels.Length) { nc = labels.Length; classOffset = 5; hasObjectness = true; }  // v5 layout

        var dets = new List<(float x1, float y1, float x2, float y2, float conf, int cls)>();
        for (int a = 0; a < anchors; a++)
        {
            float best = 0f; int bestCls = -1;
            for (int c = 0; c < nc; c++)
            {
                float s = Get(classOffset + c, a);
                if (s > best) { best = s; bestCls = c; }
            }
            float conf = hasObjectness ? best * Get(4, a) : best;
            if (bestCls < 0 || conf < minConf) continue;

            // box is cx,cy,w,h in letterboxed input pixels -> undo padding + scale
            float cx = Get(0, a), cy = Get(1, a), w = Get(2, a), h = Get(3, a);
            float x1 = (cx - w / 2 - padX) / scale, y1 = (cy - h / 2 - padY) / scale;
            float x2 = (cx + w / 2 - padX) / scale, y2 = (cy + h / 2 - padY) / scale;
            dets.Add((Math.Clamp(x1, 0, origW), Math.Clamp(y1, 0, origH),
                      Math.Clamp(x2, 0, origW), Math.Clamp(y2, 0, origH), conf, bestCls));
        }

        var kept = Nms(dets, iou);
        if (kept.Count == 0)
            return $"No objects above confidence {minConf:F2} in {Path.GetFileName(imagePath)} " +
                   $"({origW}x{origH}). Lower minConfidence, or the model may not cover these classes.";

        var lines = kept
            .OrderByDescending(d => d.conf)
            .Select(d => $"- {(d.cls < labels.Length ? labels[d.cls] : $"class{d.cls}")} " +
                         $"conf={d.conf:F2} box=[{d.x1:F0},{d.y1:F0},{d.x2:F0},{d.y2:F0}]");
        return $"{kept.Count} detection(s) in {Path.GetFileName(imagePath)} ({origW}x{origH}), " +
               $"box=[x1,y1,x2,y2] in source pixels:\n" + string.Join("\n", lines);
    }

    // Greedy non-max suppression, per class.
    static List<(float x1, float y1, float x2, float y2, float conf, int cls)> Nms(
        List<(float x1, float y1, float x2, float y2, float conf, int cls)> dets, float iouThreshold)
    {
        var kept = new List<(float x1, float y1, float x2, float y2, float conf, int cls)>();
        foreach (var group in dets.GroupBy(d => d.cls))
        {
            var sorted = group.OrderByDescending(d => d.conf).ToList();
            while (sorted.Count > 0)
            {
                var top = sorted[0];
                kept.Add(top);
                sorted.RemoveAt(0);
                sorted.RemoveAll(d => Iou(top, d) > iouThreshold);
            }
        }
        return kept;
    }

    static float Iou((float x1, float y1, float x2, float y2, float conf, int cls) a,
                     (float x1, float y1, float x2, float y2, float conf, int cls) b)
    {
        float ix = Math.Max(0, Math.Min(a.x2, b.x2) - Math.Max(a.x1, b.x1));
        float iy = Math.Max(0, Math.Min(a.y2, b.y2) - Math.Max(a.y1, b.y1));
        float inter = ix * iy;
        float areaA = Math.Max(0, a.x2 - a.x1) * Math.Max(0, a.y2 - a.y1);
        float areaB = Math.Max(0, b.x2 - b.x1) * Math.Max(0, b.y2 - b.y1);
        float union = areaA + areaB - inter;
        return union <= 0 ? 0 : inter / union;
    }

    // ---------- speech to text (uv + faster-whisper helper) ----------
    // Whisper in pure C#/ONNX means hand-rolling mel spectrograms + decoding; shelling out to the same
    // faster-whisper stack voice.py already uses is far more reliable. uv builds the env from the
    // script's inline dependency block on first run.
    static string? FindScript()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 7 && dir is not null; i++, dir = dir.Parent)
        {
            var p = Path.Combine(dir.FullName, "transcribe.py");
            if (File.Exists(p)) return p;
        }
        var env = Environment.GetEnvironmentVariable("LOCALTOOLS_TRANSCRIBE_SCRIPT");
        return !string.IsNullOrWhiteSpace(env) && File.Exists(env) ? env : null;
    }

    public static async Task<string> TranscribeAsync(string audioPath)
    {
        if (!File.Exists(audioPath)) return $"File not found: {audioPath}";
        var script = FindScript();
        if (script is null)
            return "transcribe failed: transcribe.py not found. It ships in the kit root; set " +
                   "LOCALTOOLS_TRANSCRIBE_SCRIPT to its full path if the server runs from elsewhere.";

        var psi = new ProcessStartInfo("uv")
        {
            UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true,
            CreateNoWindow = true
        };
        psi.ArgumentList.Add("run");
        psi.ArgumentList.Add(script);
        psi.ArgumentList.Add(audioPath);

        try
        {
            using var p = Process.Start(psi) ?? throw new Exception("could not start uv");
            var stdout = await p.StandardOutput.ReadToEndAsync();
            var stderr = await p.StandardError.ReadToEndAsync();
            await p.WaitForExitAsync();
            if (p.ExitCode != 0)
                return $"transcribe failed (exit {p.ExitCode}): {stderr.Trim().Split('\n').LastOrDefault()}";
            var text = stdout.Trim();
            return text.Length > 0 ? text : "transcribe failed: the model returned no text.";
        }
        catch (Exception e)
        {
            return $"transcribe failed: {e.Message}. Is uv installed? (winget install astral-sh.uv)";
        }
    }

    // COCO-80, the default label set for stock YOLO exports.
    static readonly string[] CocoLabels = {
        "person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light",
        "fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow",
        "elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee",
        "skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard",
        "tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple",
        "sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake","chair","couch",
        "potted plant","bed","dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone",
        "microwave","oven","toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear",
        "hair drier","toothbrush"
    };
}

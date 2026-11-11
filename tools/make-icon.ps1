# Draws the IconScape application icon and writes host/IconScape.ico (PNG frames: 16, 20, 24, 32, 40, 48, 64, 128 and 256 px).
# The picture: a tile with a dusk-to-teal sky, a sun, four white desktop icons and two rolling hills: the icons become part of the scenery.
# Small sizes are drawn separately (fewer details, pixel-aligned tiles) instead of being scaled down from the big one.
param([string]$Out = (Join-Path $PSScriptRoot '..\host\IconScape.ico'), [string]$PreviewPng = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
public static class IconArt {
    static GraphicsPath Round(float x, float y, float w, float h, float r) {
        var p = new GraphicsPath(); float d = r * 2;
        p.AddArc(x, y, d, d, 180, 90); p.AddArc(x + w - d, y, d, d, 270, 90);
        p.AddArc(x + w - d, y + h - d, d, d, 0, 90); p.AddArc(x, y + h - d, d, d, 90, 90);
        p.CloseFigure(); return p;
    }
    // A hill: from the left edge at height y0, a smooth crest at (cx, cy), down to the right edge at y1; filled to the bottom
    static GraphicsPath Hill(float S, float y0, float cx, float cy, float y1) {
        var p = new GraphicsPath();
        p.AddBezier(0, y0 * S, cx * S * 0.55f, cy * S, cx * S + (1 - cx) * S * 0.3f, cy * S, S, y1 * S);
        p.AddLine(S, y1 * S, S, S); p.AddLine(S, S, 0, S); p.CloseFigure();
        return p;
    }
    public static Bitmap Draw(int S) {
        var bmp = new Bitmap(S, S, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.Clear(Color.Transparent);
            bool small = S <= 24;
            float m = S <= 20 ? 0 : S * 0.03f, R = S * (small ? 0.2f : 0.22f);
            using (var tile = Round(m, m, S - 2 * m, S - 2 * m, R)) {
                g.SetClip(tile);
                using (var sky = new LinearGradientBrush(new PointF(0, 0), new PointF(S, S), Color.FromArgb(255, 74, 58, 200), Color.FromArgb(255, 22, 160, 182))) {
                    var blend = new ColorBlend(3);
                    blend.Colors = new[] { Color.FromArgb(255, 70, 52, 196), Color.FromArgb(255, 120, 86, 214), Color.FromArgb(255, 30, 168, 186) };
                    blend.Positions = new[] { 0f, 0.45f, 1f };
                    sky.InterpolationColors = blend;
                    g.FillRectangle(sky, 0, 0, S, S);
                }
                // sun with a soft glow
                float sx = S * 0.73f, sy = S * 0.3f, sr = S * (small ? 0.13f : 0.11f);
                if (!small) using (var glow = new GraphicsPath()) {
                    glow.AddEllipse(sx - sr * 2.4f, sy - sr * 2.4f, sr * 4.8f, sr * 4.8f);
                    using (var pb = new PathGradientBrush(glow)) { pb.CenterColor = Color.FromArgb(110, 255, 214, 120); pb.SurroundColors = new[] { Color.FromArgb(0, 255, 214, 120) }; g.FillPath(pb, glow); }
                }
                using (var sun = new SolidBrush(Color.FromArgb(255, 255, 209, 102))) g.FillEllipse(sun, sx - sr, sy - sr, sr * 2, sr * 2);
                // hills: a light one behind, a deeper one in front
                using (var back = Hill(S, 0.7f, 0.62f, 0.5f, 0.6f)) using (var b = new SolidBrush(Color.FromArgb(255, 126, 224, 176))) g.FillPath(b, back);
                using (var front = Hill(S, 0.64f, 0.3f, 0.66f, 0.86f))
                using (var f = new LinearGradientBrush(new PointF(0, S * 0.6f), new PointF(0, S), Color.FromArgb(255, 46, 170, 128), Color.FromArgb(255, 22, 112, 96))) g.FillPath(f, front);
                // four desktop icons standing on the scenery (a 2×2 grid at the upper left)
                float t = S * (small ? 0.2f : 0.15f), gap = S * (small ? 0.08f : 0.055f), x0 = S * (small ? 0.16f : 0.19f), y0 = S * (small ? 0.18f : 0.21f);
                if (small) { t = (float)Math.Max(2, Math.Round(t)); gap = (float)Math.Max(1, Math.Round(gap)); x0 = (float)Math.Round(x0); y0 = (float)Math.Round(y0); }
                for (int k = 0; k < 4; k++) {
                    float x = x0 + (k % 2) * (t + gap), y = y0 + (k / 2) * (t + gap);
                    if (!small) using (var sh = Round(x + S * 0.012f, y + S * 0.02f, t, t, t * 0.26f)) using (var sb = new SolidBrush(Color.FromArgb(70, 20, 10, 60))) g.FillPath(sb, sh);
                    using (var ic = Round(x, y, t, t, small ? t * 0.2f : t * 0.26f)) using (var wb = new SolidBrush(Color.FromArgb(255, 252, 252, 255))) g.FillPath(wb, ic);
                    if (!small) {                                 // a hint of a label under each icon
                        float lw = t * 0.7f, lh = Math.Max(1f, S * 0.016f);
                        using (var lb = new SolidBrush(Color.FromArgb(200, 255, 255, 255))) g.FillRectangle(lb, x + (t - lw) / 2, y + t + S * 0.012f, lw, lh);
                    }
                }
                g.ResetClip();
            }
            if (!small) using (var edge = Round(m + 0.5f, m + 0.5f, S - 2 * m - 1, S - 2 * m - 1, R)) using (var pen = new Pen(Color.FromArgb(60, 255, 255, 255), Math.Max(1f, S / 128f))) g.DrawPath(pen, edge);
        }
        return bmp;
    }
}
"@
$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256
$frames = foreach ($s in $sizes) {
    $bmp = [IconArt]::Draw($s)
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    if ($PreviewPng -and $s -eq 256) { $bmp.Save($PreviewPng, [Drawing.Imaging.ImageFormat]::Png) }
    $bmp.Dispose()
    , $ms.ToArray()
}
# ICO: header, one 16-byte directory entry per frame, then the PNG data
$ico = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter -ArgumentList $ico
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $len = $frames[$i].Length
    $w.Write([byte]($s % 256)); $w.Write([byte]($s % 256)); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$len); $w.Write([uint32]$offset)
    $offset += $len
}
foreach ($f in $frames) { $w.Write($f) }
$w.Flush()
[IO.File]::WriteAllBytes([IO.Path]::GetFullPath($Out), $ico.ToArray())
Write-Host "Icon written: $([IO.Path]::GetFullPath($Out)) ($($ico.Length) bytes, $($sizes -join '/') px)"

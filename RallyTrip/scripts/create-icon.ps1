$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskIconPath = Join-Path $taskRoot 'RallyTrip\Assets.xcassets\AppIcon.appiconset\AppIcon.png'
$bitmap = New-Object System.Drawing.Bitmap 1024,1024
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(17,20,19))
$lime = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(202,245,71))
$ink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(17,20,19))
$graphics.FillEllipse($lime,112,112,800,800)
$graphics.FillEllipse($ink,180,180,664,664)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(202,245,71)),42
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($pen,512,512,705,319)
$graphics.FillEllipse($lime,457,457,110,110)
foreach ($i in 0..4) {
    $angle = (145 + $i * 42) * [Math]::PI / 180
    $x1 = [single](512 + 265 * [Math]::Cos($angle))
    $y1 = [single](512 + 265 * [Math]::Sin($angle))
    $x2 = [single](512 + 300 * [Math]::Cos($angle))
    $y2 = [single](512 + 300 * [Math]::Sin($angle))
    $graphics.DrawLine($pen,$x1,$y1,$x2,$y2)
}
$graphics.FillRectangle($ink,254,690,516,190)
for ($row = 0; $row -lt 2; $row++) {
    for ($col = 0; $col -lt 6; $col++) {
        if (($row + $col) % 2 -eq 0) { $graphics.FillRectangle($lime,(302 + $col * 70),(710 + $row * 70),70,70) }
    }
}
$bitmap.Save($taskIconPath,[System.Drawing.Imaging.ImageFormat]::Png)
$pen.Dispose()
$lime.Dispose()
$ink.Dispose()
$graphics.Dispose()
$bitmap.Dispose()
Write-Output "App icon created: $taskIconPath"

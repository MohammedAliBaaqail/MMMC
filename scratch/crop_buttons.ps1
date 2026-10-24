Add-Type -AssemblyName System.Drawing

$clean = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")

# Let's crop small 60x60 patches around where each button is located and save them to scratch
# so we can inspect them and verify the exact button centers!
$buttons = @{
    "Wheel"       = @{ x = 145; y = 10;  w = 70; h = 70 }
    "G8_G7"       = @{ x = 20;  y = 65;  w = 60; h = 60 }
    "DpiShift"    = @{ x = 40;  y = 175; w = 70; h = 80 }
    "G5_G4"       = @{ x = 85;  y = 200; w = 150; h = 90 }
    "G9"          = @{ x = 210; y = 50;  w = 70; h = 70 }
}

foreach ($name in $buttons.Keys) {
    $b = $buttons[$name]
    $rect = New-Object System.Drawing.Rectangle($b.x, $b.y, $b.w, $b.h)
    $crop = $clean.Clone($rect, $clean.PixelFormat)
    $crop.Save("D:\For Safe Keeping\OBM AHK\scratch\crop_$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
    Write-Output "Saved crop_$name.png"
}

$clean.Dispose()

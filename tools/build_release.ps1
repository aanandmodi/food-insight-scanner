$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$frontendPath = Join-Path $projectRoot 'frontend'
Push-Location $frontendPath
try {
    flutter analyze --no-fatal-infos
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed' }
    flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Regression tests failed' }
    flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
    $releasePath = Join-Path $projectRoot 'releases/1.0.2'
    New-Item -ItemType Directory -Force -Path $releasePath | Out-Null
    foreach ($abi in @('arm64-v8a','armeabi-v7a','x86_64')) {
        Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-$abi-release.apk" -Destination (Join-Path $releasePath "food-insight-1.0.2-$abi.apk") -Force
    }
    Copy-Item -LiteralPath 'build/symbols' -Destination $releasePath -Recurse -Force
    Copy-Item -LiteralPath 'build/app/outputs/mapping/release/mapping.txt' -Destination (Join-Path $releasePath 'r8-mapping.txt') -Force
    Get-ChildItem -LiteralPath $releasePath -Filter '*.apk' | Get-FileHash -Algorithm SHA256 |
        ForEach-Object { "$($_.Hash)  $(Split-Path $_.Path -Leaf)" } |
        Set-Content -LiteralPath (Join-Path $releasePath 'SHA256SUMS.txt')
} finally { Pop-Location }

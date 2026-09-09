param(
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$installerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $installerDir "../..")).Path
$pluginCfg = Join-Path $repoRoot "addons/godot_mcp_chatgpt/plugin.cfg"
$match = [regex]::Match([IO.File]::ReadAllText($pluginCfg), 'version="([^"]+)"')
if (-not $match.Success) { throw "Unable to read plugin version from $pluginCfg" }
$version = $match.Groups[1].Value
$commit = (& git -C $repoRoot rev-parse --short=12 HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "dist/v$version"
} elseif (-not [IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot $OutputDirectory
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null

$payload = Join-Path $installerDir "payload.zip"
$addonSource = Join-Path $repoRoot "addons/godot_mcp_chatgpt"
$exeName = "godot-mcp-chatgpt-v$version-windows-x64-installer.exe"
$zipName = "godot-mcp-chatgpt-v$version-addon.zip"
$exePath = Join-Path $OutputDirectory $exeName
$zipPath = Join-Path $OutputDirectory $zipName
$sumPath = Join-Path $OutputDirectory "SHA256SUMS.txt"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-AddonZip([string]$Destination) {
    if (Test-Path $Destination) { Remove-Item -Force $Destination }
    $stream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
    try {
        $archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            $files = Get-ChildItem -LiteralPath $addonSource -File -Recurse | Sort-Object FullName
            foreach ($file in $files) {
                $relative = $file.FullName.Substring($addonSource.Length).TrimStart('\','/') -replace '\\','/'
                $entryName = "addons/godot_mcp_chatgpt/$relative"
                $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::new([DateTime]::Parse("2026-01-01T00:00:00Z"))
                $input = [IO.File]::OpenRead($file.FullName)
                try {
                    $output = $entry.Open()
                    try { $input.CopyTo($output) } finally { $output.Dispose() }
                } finally { $input.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
}

try {
    New-AddonZip $payload
    Copy-Item -Force $payload $zipPath

    Push-Location $installerDir
    try {
        $ldflags = "-s -w -H=windowsgui -X main.version=$version -X main.buildCommit=$commit"
        & go build -trimpath -ldflags $ldflags -o $exePath .
        if ($LASTEXITCODE -ne 0) { throw "go build installer failed" }
    } finally { Pop-Location }

    $lines = @()
    foreach ($path in @($exePath, $zipPath)) {
        $hash = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
        $lines += "$hash  $([IO.Path]::GetFileName($path))"
    }
    [IO.File]::WriteAllText($sumPath, ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))

    Write-Host "INSTALLER_BUILD=PASS"
    Write-Host "VERSION=$version"
    Write-Host "COMMIT=$commit"
    Write-Host "INSTALLER=$exePath"
    Write-Host "ADDON_ZIP=$zipPath"
    Write-Host "SHA256=$sumPath"
} finally {
    if (Test-Path $payload) { Remove-Item -Force $payload }
}
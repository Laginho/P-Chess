#requires -Version 5.1
<#
.SYNOPSIS
Downloads and verifies the pinned Windows engines and nine Maia-1 networks.
.EXAMPLE
powershell -NoProfile -File scripts/fetch-engine.ps1 -Root 'C:\Games\P Chess'
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Official release assets, verified on 2026-10-24. The archive hash also matches
# GitHub's published SHA-256 digest. Maia v1.0 has no published asset digests;
# its hashes below were computed from the actual official release downloads.
$lc0Release = 'https://github.com/LeelaChessZero/lc0/releases/download/v0.32.1'
$stockfishRelease = 'https://github.com/official-stockfish/Stockfish/releases/download/sf_19'
$stockfishZip = 'stockfish-windows-x86-64-universal.zip'
$stockfishZipHash = '3c8bf1f9ea66a09350a40df4f632288285ac206d99f33ab5842c408fc30b48a7'
$stockfishFiles = [ordered]@{
    'stockfish.exe' = @('stockfish/stockfish-windows-x86-64-universal.exe', '45bc8e4969147db9c2eb533810637994619bff0eacc81ccfd9854394901bcbd0')
    'Copying.txt' = @('stockfish/Copying.txt', '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986')
}
$maiaRelease = 'https://github.com/CSSLab/maia-chess/releases/download/v1.0'
$zipName = 'lc0-v0.32.1-windows-cpu-dnnl.zip'
$zipHash = 'b9cfcfbd3dabffbfd452f6e8e087c22273721bef48eba19640b6d92006c142f5'

# Verify installed files too, so a valid cached zip cannot hide a modified exe,
# DLL or network. All entries are flat files in this exact pinned archive.
$lc0Files = [ordered]@{
    '791556.pb.gz' = 'b1c7047582a8ad37620849bf328935cb46f2ccbbecb7f2696c30c6b913ed690d'
    'COPYING' = '230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809'
    'DNNL-LICENSE' = '3e4086117a15fb5ca2f9e2e72009f2c4c3d7a12142a08ddaff8c85676c18b701'
    'DNNL-THIRD-PARTY-PROGRAMS' = 'a457dde040ec0b4e2bdde3e878f97363d4329a99a41d7a2960020ff545f840be'
    'dnnl.dll' = '4c642ebe5e4300fb74417d43cc57d5ef33656f7b5fc536a9655ca02f8120c930'
    'lc0.exe' = '2130a6b980c8d9543888d3d4b2e45642b550ba73b36e05ae892e9c9130afd5ed'
    'mimalloc-LICENSE' = '5ce3e462f520c1588bcfd0385f0aebb1acc55c7af4ca33c049d9f23cdfa59813'
    'mimalloc-override.dll' = 'e082b62637c82319eb0936e73822a7667c77e263e3d00fb61917e0e3beb677b3'
    'mimalloc-readme.md' = '7e34c53f84757b8a792557e76021bb26d2b0430aa049e608eade3d6ed8bb33c7'
    'mimalloc-redirect.dll' = '63dc4f158fd76940ec018b42f83d92d8ceec70043b1ac2a8455fb0d67e1feebf'
}
$maiaFiles = [ordered]@{
    'maia-1100.pb.gz' = 'e1cf1cd0c96b8a4fa6a275f4b9fd54ed1ffebf9fe44641b9fceded310e9619c4'
    'maia-1200.pb.gz' = 'ead4ba953f233ae732999ebc1e2b675378148527ebcfad2f0acbc5e4c224d98e'
    'maia-1300.pb.gz' = '36195f87bf4761834baa0bf87472b18509a7261a9d7d6f1a8443261369a733f2'
    'maia-1400.pb.gz' = 'd5353ea6766356dad2d28920c6692f37a5f30963767f1a3105d33b4d0af011e8'
    'maia-1500.pb.gz' = '35ab6f20421d59e1df3b17c5a5016947af4c6761368ef84044a9a9c7619a9a00'
    'maia-1600.pb.gz' = 'd2c9e5948581acf4b9fc0b1e720c5dc0fe64ce80cfc4a239d3f8a42e1176c876'
    'maia-1700.pb.gz' = 'd277eacd792d340a30abb464dc65127254e65cac57abca17facc469889b96478'
    'maia-1800.pb.gz' = '0031ad7c4256b1fd09fbebd28418d644d68b26cd2a45df4967ccf5c7ec9c4965'
    'maia-1900.pb.gz' = 'e2f565f42d7cd9f122557e6dc4eb84e5bbaedceda1d404dc485d3611c7c97a12'
}

function Test-PinnedFile([string]$Path, [string]$Hash) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Hash) {
        Remove-Item -LiteralPath $Path -Force
        throw "SHA-256 mismatch: $Path (expected $Hash, got $actual). Deleted; run again to restore."
    }
    return $true
}

function Get-PinnedDownload([string]$Url, [string]$Path, [string]$Hash) {
    if (Test-PinnedFile $Path $Hash) {
        Write-Host "Verified, skipping download: $Path"
        return
    }
    Write-Host "Downloading: $Url"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Path -TimeoutSec 120
        if (-not (Test-PinnedFile $Path $Hash)) {
            throw "Download did not create $Path"
        }
    } catch {
        # Interrupted transfers must not become a cached file on the next run.
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            Remove-Item -LiteralPath $Path -Force
        }
        throw
    }
}

$previousTls = [Net.ServicePointManager]::SecurityProtocol
try {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls -bor [Net.SecurityProtocolType]::Tls12
    if (-not $PSBoundParameters.ContainsKey('Root')) {
        $Root = Split-Path -Parent $PSScriptRoot
    }
    $Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
    $lc0Dir = Join-Path $Root 'engine/lc0'
    $weightsDir = Join-Path $Root 'engine/weights'
    $stockfishDir = Join-Path $Root 'engine/stockfish'
    [IO.Directory]::CreateDirectory($stockfishDir) | Out-Null
    [IO.Directory]::CreateDirectory($lc0Dir) | Out-Null
    [IO.Directory]::CreateDirectory($weightsDir) | Out-Null

    # Keep the verified archives outside -Root, so a release package built in
    # -Root never ships them, but still cache them for reruns and offline
    # recovery of missing extracted files.
    $cacheDir = Join-Path ([IO.Path]::GetTempPath()) 'P-Chess-engine-cache'
    [IO.Directory]::CreateDirectory($cacheDir) | Out-Null
    $zipPath = Join-Path $cacheDir $zipName
    Get-PinnedDownload "$lc0Release/$zipName" $zipPath $zipHash
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($file in $lc0Files.GetEnumerator()) {
            $path = Join-Path $lc0Dir $file.Key
            if (Test-PinnedFile $path $file.Value) {
                continue
            }
            $entry = $archive.GetEntry($file.Key)
            if ($null -eq $entry) {
                throw "Pinned archive is missing $($file.Key)"
            }
            Write-Host "Extracting: $path"
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $path)
            if (-not (Test-PinnedFile $path $file.Value)) {
                throw "Extraction did not create $path"
            }
        }
    } finally {
        $archive.Dispose()
    }

    $stockfishZipPath = Join-Path $cacheDir $stockfishZip
    Get-PinnedDownload "$stockfishRelease/$stockfishZip" $stockfishZipPath $stockfishZipHash
    $archive = [IO.Compression.ZipFile]::OpenRead($stockfishZipPath)
    try {
        foreach ($file in $stockfishFiles.GetEnumerator()) {
            $path = Join-Path $stockfishDir $file.Key
            if (Test-PinnedFile $path $file.Value[1]) { continue }
            $entry = $archive.GetEntry($file.Value[0])
            if ($null -eq $entry) { throw "Pinned archive is missing $($file.Value[0])" }
            Write-Host "Extracting: $path"
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $path)
            if (-not (Test-PinnedFile $path $file.Value[1])) { throw "Extraction did not create $path" }
        }
    } finally {
        $archive.Dispose()
    }

    foreach ($file in $maiaFiles.GetEnumerator()) {
        Get-PinnedDownload "$maiaRelease/$($file.Key)" (Join-Path $weightsDir $file.Key) $file.Value
    }
    Write-Host 'Verified Lc0 v0.32.1, Stockfish 19 and all nine Maia v1.0 networks.'
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls
}
exit 0

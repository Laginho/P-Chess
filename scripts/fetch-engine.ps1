#requires -Version 5.1
<#
.SYNOPSIS
Downloads and verifies the pinned Windows engines, Maia-1 networks and Syzygy tablebases.
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

# Syzygy 3-4-5 WDL and DTZ files: hashes from the RES-001 Lichess manifest.
$tablebaseRelease = 'https://tablebase.lichess.ovh/tables/standard'
$tablebaseFiles = [ordered]@{
    'KBvK.rtbw' = 'bc0d8ab3560de9038460f0e8f61e3b7efd3e3d0327d19ae0387c0da7ddeb244d'
    'KBvK.rtbz' = '6246c8a5c643eec9d4758d55ed843e31cc28a9b82a6f630c1c950d8b7755975b'
    'KNvK.rtbw' = '9d3518b12df3d2006441df758bce31e961346e70a11920aaad75c647003bb6e7'
    'KNvK.rtbz' = '0e49a0f2810a131c32fc14872e83044aa9810ce2c86df071851512077291fc25'
    'KPvK.rtbw' = '02fd2bdcd92821c869458f019f63524def1c9e7a2862ca8d2b16dc7712b16183'
    'KPvK.rtbz' = 'ad01af2076183c90ccee662ca6c5d74da3222ff1fee47c01b5d4e56ed01938de'
    'KQRvK.rtbw' = 'b018ece9cc195618981b027268f9cca929a1ed4c0bdd739874b7846640ef479a'
    'KQRvK.rtbz' = '9766d3e684582297943583e1981154609655034cea2aa78a5494cc01c8c6bcee'
    'KQRvKR.rtbw' = '13477ef681468dfb19d09ab8dbeb08d259f9db57a6e5e2c7cdb902880fc2166b'
    'KQRvKR.rtbz' = '6ed2eba7b9d5b7813a30751a0e1dd3561e499c1ffe76b5de98ea7ad5b006fdbd'
    'KQvK.rtbw' = '517667dff787162dbb1ed9d5d6484d30ee854e686ee0675c08d99ecf045d2d50'
    'KQvK.rtbz' = '71ea9444fa5bd42897d781a0c356975ea6f23e0f65a4254e470897031c161c8c'
    'KQvKR.rtbw' = '8cdbe3c8e098037875de5854c656f8afeadb8327c85b5b7b1cac81719afd3e2c'
    'KQvKR.rtbz' = '0c15a2aaa3bdef39da4c26932006b5d38b55b8e3ad13e8a44815d63f84738618'
    'KRBvK.rtbw' = '9e6eced11a37cad71b4fc1a4f62a15e191e58883b51ce8c4c45f341051c6ae8e'
    'KRBvK.rtbz' = 'e3bb6fbd54a57a154136ecee763a8e9862d8ab3f57b2f55387df70bdbff1b140'
    'KRBvKR.rtbw' = '6343cff1ca9d4026aed57ede37ebd29004d11c9d8ec932351b04b4e8018ce8b9'
    'KRBvKR.rtbz' = 'e6ee6691bde20eceedd44b26adab5b3328d9ca758153693775b65d3a51ae11cb'
    'KRNvK.rtbw' = '4f96cab9fc0005f2679eacb92cec32edf9c932db7bb29b5dc7659be0012d6c35'
    'KRNvK.rtbz' = '150b85874a78474a38d0f36f1ab39d387f524a1c2092ad92d3d0945d96c17d16'
    'KRNvKR.rtbw' = '163432941d6f625c093c7291d2045453f712435e906e9d91d371105da96f97c4'
    'KRNvKR.rtbz' = '4183e43f92e4ea0126028acc59b991b36dabdf944d53a61e9e7367374aebbe06'
    'KRPvK.rtbw' = '6bc2aa9db5ee7fcc287e6c3b006ab6cfc2be4dff4ae7ca4a524a78520eea61db'
    'KRPvK.rtbz' = '5c89c9ef70c144bb2d6d823a41668ccf2f79b486b6bc128ff01aadb5485c06a9'
    'KRPvKR.rtbw' = '1100e6deaee14ca9a56b69441208462c02ef45b3f56daa3d75f687eb5cf12319'
    'KRPvKR.rtbz' = '184ce33fa4dcfa931f7a3b9955662e166287ec203224ae9681d527d3b8cd9c6f'
    'KRRvK.rtbw' = '4c05ec32e6e43b690d235307de75432a3ceecdbc3d2659d8101ed15b48b8445d'
    'KRRvK.rtbz' = 'e68314e00bf9f16122005a06f7d42bc0f6c682f30e8ca50532ba44444f3b96ce'
    'KRRvKR.rtbw' = '7897a69c7ad337adc93aa39c9d22dcf1a5e215908437b36d92db5e4bebf9217e'
    'KRRvKR.rtbz' = 'dd0fe4d32ccbfc390e8d4468fa5a31484e26abdb45d712cdfe1b8b5fe0a05c14'
    'KRvK.rtbw' = '386fbde73308e49a4207836922c68b30b664e83c5a37f7fa37305a15cd16f2f1'
    'KRvK.rtbz' = 'cab59f42e75c2a25da3939231850a79fa838593fff5c28d7772da92062ed965a'
    'KRvKB.rtbw' = '69b247cb390ffcd729cf5fe5c40f8a24803190bf67b108b8f05b8b08b26a6a72'
    'KRvKB.rtbz' = '4fa644478a516e1425b22a740ddefc4d54e51298250b8208d26073df3638630b'
    'KRvKN.rtbw' = 'a8cde902b010bf6c8763c97d19b5430b422e74db9cb8e9d5e67fa07373c13c5b'
    'KRvKN.rtbz' = 'c0df57d0b066cdd7be5bdf9b14745f6ead1fd8e9fba2b77fe0f3cb56ebef7ae0'
    'KRvKP.rtbw' = '3968c2bfced3a5ecfbb54166ec13d4e7b70f3b03c495af4ae87cad2ec75a0749'
    'KRvKP.rtbz' = '6d4b1389832854119df815ff89ed2cb0786e8887f000009f0db3484457f7f6ff'
    'KRvKR.rtbw' = '797081b5b3fbac20c4baa5453d68bdae1425b63895f5c9a5ac5c68ea63a97712'
    'KRvKR.rtbz' = 'c23fa5a0209204b847232ed49e079c099cf603b43d6ace9e27257793b1839850'
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

function Get-PinnedDownload([string]$Url, [string]$Path, [string]$Hash, [switch]$StageOutsideDestination) {
    if (Test-PinnedFile $Path $Hash) {
        Write-Host "Verified, skipping download: $Path"
        return
    }
    $stagingDir = $null
    $downloadPath = $Path
    try {
        if ($StageOutsideDestination) {
            # A killed transfer must not leave an incomplete table in the probe's folder.
            $stagingDir = Join-Path (Split-Path -Parent (Split-Path -Parent $Path)) (".tablebase-staging-" + [guid]::NewGuid())
            [IO.Directory]::CreateDirectory($stagingDir) | Out-Null
            $downloadPath = Join-Path $stagingDir ([IO.Path]::GetFileName($Path))
        }
        Write-Host "Downloading: $Url"
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $downloadPath -TimeoutSec 120
        if (-not (Test-PinnedFile $downloadPath $Hash)) {
            throw "Download did not create $downloadPath"
        }
        if ($StageOutsideDestination) {
            [IO.File]::Move($downloadPath, $Path)
        }
    } catch {
        # Interrupted transfers must not become a cached file on the next run.
        if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
            Remove-Item -LiteralPath $downloadPath -Force
        }
        throw
    } finally {
        if ($null -ne $stagingDir -and (Test-Path -LiteralPath $stagingDir)) {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force
        }
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
    $tablebaseDir = Join-Path $Root 'engine/tablebase'
    [IO.Directory]::CreateDirectory($stockfishDir) | Out-Null
    [IO.Directory]::CreateDirectory($lc0Dir) | Out-Null
    [IO.Directory]::CreateDirectory($weightsDir) | Out-Null
    [IO.Directory]::CreateDirectory($tablebaseDir) | Out-Null

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
    foreach ($file in $tablebaseFiles.GetEnumerator()) {
        $kind = if ($file.Key.EndsWith('.rtbw')) { 'wdl' } else { 'dtz' }
        Get-PinnedDownload "$tablebaseRelease/3-4-5-$kind/$($file.Key)" (Join-Path $tablebaseDir $file.Key) $file.Value -StageOutsideDestination
    }
    Write-Host 'Verified Lc0 v0.32.1, Stockfish 19, all nine Maia v1.0 networks and the Syzygy tablebases.'
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls
}
exit 0

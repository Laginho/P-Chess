#requires -Version 5.1
<# Builds the pinned, single-threaded Fathom UCI helper for this host. #>
[CmdletBinding()]
param([ValidateNotNullOrEmpty()][string]$Root)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$commit = 'c9c6fef0dddc05d2e242c183acf5833149ab676d'
$files = [ordered]@{
    'src/tbprobe.c' = '7ed0cc80626271342bfe413d6c421756b6851f977a064461f5f555e1b598df35'
    'src/tbprobe.h' = 'dc7808dc58c2a1af921a612f94041b917dfac94d3215a76a2b2b0c53c94ea561'
    'src/tbchess.c' = '119f19fa8714686798ca7be011e5b234f99c93aec751e9492f2664757d6c029d'
    'src/tbconfig.h' = '69fe1821b471164bd759cf46c486d55b7fa727e348a5ee306b18d19537ac3a03'
    'src/stdendian.h' = 'e5b8187eec89ef83e731ea92be8ca0df4b533d8d21075fc4e2c86b4b00d7b7c3'
    'LICENSE' = 'c8038055839bd02f995cd7d1bba19657720097f5604411a7977ebcb5b4a37759'
}
$onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$staging = $null
$target = $null
$previousTls = [Net.ServicePointManager]::SecurityProtocol
try {
    if (-not $PSBoundParameters.ContainsKey('Root')) { $Root = Split-Path -Parent $PSScriptRoot }
    $Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
    $repo = Split-Path -Parent $PSScriptRoot
    $destination = Join-Path $Root 'engine/tbprobe'
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    $binary = if ($onWindows) { 'tbprobe.exe' } else { 'tbprobe' }
    $target = Join-Path $destination $binary
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }

    if ($onWindows) {
        $vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
        if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio Build Tools with Desktop development with C++ (MSVC x64).' }
        $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($LASTEXITCODE -ne 0 -or -not $vs) { throw 'Install Visual Studio Build Tools with Desktop development with C++ (MSVC x64).' }
        $vcvars = Join-Path $vs 'VC/Auxiliary/Build/vcvars64.bat'
        if (-not (Test-Path -LiteralPath $vcvars)) { throw 'Install Visual Studio Build Tools with Desktop development with C++ (MSVC x64).' }
    } else {
        $compiler = Get-Command cc -ErrorAction SilentlyContinue
        if (-not $compiler) { throw 'Install a C compiler (GCC or Clang, e.g. build-essential) providing cc.' }
    }

    # Local Linux storage policy: keep downloads and object files on the HDD.
    $cacheRoot = if (-not $onWindows -and (Test-Path -LiteralPath '/run/media/lage/New Volume/Scratch')) {
        '/run/media/lage/New Volume/Scratch/P-Chess-tbprobe-cache'
    } else { Join-Path ([IO.Path]::GetTempPath()) 'P-Chess-tbprobe-cache' }
    $cacheRoot = [IO.Path]::GetFullPath($cacheRoot)
    foreach ($excluded in @($Root, $repo)) {
        $prefix = [IO.Path]::GetFullPath($excluded).TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
        if ($cacheRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fathom cache must be outside -Root and the repo: $cacheRoot"
        }
    }
    $cache = Join-Path $cacheRoot $commit
    [Net.ServicePointManager]::SecurityProtocol = $previousTls -bor [Net.SecurityProtocolType]::Tls12
    foreach ($file in $files.GetEnumerator()) {
        $path = Join-Path $cache $file.Key
        [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $partial = "$path.download"
            try {
                Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/jdart1/Fathom/$commit/$($file.Key)" -OutFile $partial -TimeoutSec 120
                if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ne $file.Value) { throw "SHA-256 mismatch: $($file.Key)" }
                Move-Item -LiteralPath $partial -Destination $path
            } finally {
                if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
            }
        }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.Value) {
            Remove-Item -LiteralPath $path -Force
            throw "SHA-256 mismatch: $($file.Key) (deleted; run again to restore)"
        }
        Write-Host "Verified Fathom $($file.Key)"
    }
    $staging = Join-Path $cacheRoot ("build-" + [guid]::NewGuid())
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    $output = Join-Path $staging $binary
    $main = Join-Path $repo 'native/tbprobe/main.c'
    $source = Join-Path $cache 'src/tbprobe.c'
    $include = Join-Path $cache 'src'
    if ($onWindows) {
        # Fathom supports C++; MSVC's C++ atomics avoid an experimental C11 flag.
        # /MT embeds the CRT; the helper must never depend on app-local VC++ DLLs.
        $batch = Join-Path $staging 'build.cmd'
        $text = "@call `"$vcvars`" >nul`r`n@if errorlevel 1 exit /b %errorlevel%`r`n"
        $text += "@cl /nologo /TP /std:c++14 /O2 /MT /DTB_NO_THREADS /DTB_NO_HW_POP_COUNT /D_CRT_SECURE_NO_WARNINGS /DFATHOM_COMMIT=\`"$commit\`" /I`"$include`" `"$main`" `"$source`" /Fe:`"$output`"`r`n@exit /b %errorlevel%`r`n"
        [IO.File]::WriteAllText($batch, $text, [Text.Encoding]::Default)
        Push-Location $staging
        try { & $env:ComSpec /d /c $batch } finally { Pop-Location }
    } else {
        & $compiler.Source -std=c11 -O2 -D_POSIX_C_SOURCE=200809L -DTB_NO_THREADS -DTB_NO_HW_POP_COUNT "-DFATHOM_COMMIT=`"$commit`"" "-I$include" $main $source -o $output
    }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $output -PathType Leaf)) { throw 'Fathom helper compilation failed.' }
    Copy-Item -LiteralPath $output -Destination $target
    if (-not $onWindows) {
        & chmod 755 $target
        if ($LASTEXITCODE -ne 0) { throw 'Could not make the Fathom helper executable.' }
    }
    Write-Host "Built $target (Fathom $commit)"
} catch {
    if ($target -and (Test-Path -LiteralPath $target)) { Remove-Item -LiteralPath $target -Force }
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls
    if ($staging -and (Test-Path -LiteralPath $staging)) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
exit 0

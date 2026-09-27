[CmdletBinding()]
param(
    [ValidateSet("host", "client")]
    [string]$Mode = "host",
    [string]$HollowKnightPath = "",
    [string]$SilksongPath = ""
)

$ErrorActionPreference = "Stop"
$script:FailureCount = 0

function Write-Check([bool]$Ok, [string]$Name, [string]$Detail) {
    if ($Ok) {
        Write-Host ("[PASS] " + $Name + " - " + $Detail) -ForegroundColor Green
    }
    else {
        Write-Host ("[FAIL] " + $Name + " - " + $Detail) -ForegroundColor Red
        $script:FailureCount++
    }
}

function Write-Advisory([bool]$Ok, [string]$Name, [string]$Detail) {
    if ($Ok) {
        Write-Host ("[PASS] " + $Name + " - " + $Detail) -ForegroundColor Green
    }
    else {
        Write-Host ("[WARN] " + $Name + " - " + $Detail) -ForegroundColor Yellow
    }
}

function Get-SteamCommonFolders {
    $folders = New-Object System.Collections.Generic.List[string]
    $steamRoots = New-Object System.Collections.Generic.List[string]
    if (${env:ProgramFiles(x86)}) { $steamRoots.Add((Join-Path ${env:ProgramFiles(x86)} "Steam")) }
    if ($env:ProgramFiles) { $steamRoots.Add((Join-Path $env:ProgramFiles "Steam")) }

    try {
        $registryPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
        if ($registryPath) { $steamRoots.Add($registryPath) }
    }
    catch { }

    foreach ($root in ($steamRoots | Select-Object -Unique)) {
        $defaultCommon = Join-Path $root "steamapps\common"
        if (Test-Path -LiteralPath $defaultCommon) { $folders.Add($defaultCommon) }

        $libraries = Join-Path $root "steamapps\libraryfolders.vdf"
        if (Test-Path -LiteralPath $libraries) {
            foreach ($line in Get-Content -LiteralPath $libraries) {
                if ($line -match '"path"\s+"([^"]+)"') {
                    $libraryRoot = $matches[1] -replace '\\\\', '\'
                    $common = Join-Path $libraryRoot "steamapps\common"
                    if (Test-Path -LiteralPath $common) { $folders.Add($common) }
                }
            }
        }
    }

    return $folders | Select-Object -Unique
}

function Find-GameRoot([string]$ExplicitPath, [string]$DirectoryName) {
    if ($ExplicitPath) { return [IO.Path]::GetFullPath($ExplicitPath) }
    foreach ($common in Get-SteamCommonFolders) {
        $candidate = Join-Path $common $DirectoryName
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return ""
}

function Find-FirstFile([string[]]$Candidates) {
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return ""
}

function Test-VersionMarker([string]$AssemblyPath, [string]$Version) {
    if (!$AssemblyPath -or !(Test-Path -LiteralPath $AssemblyPath -PathType Leaf)) { return $false }
    $bytes = [IO.File]::ReadAllBytes($AssemblyPath)
    return [Text.Encoding]::Unicode.GetString($bytes).Contains($Version)
}

function Get-AssemblyVersion([string]$AssemblyPath) {
    if (!$AssemblyPath -or !(Test-Path -LiteralPath $AssemblyPath -PathType Leaf)) { return "missing" }
    try { return [Reflection.AssemblyName]::GetAssemblyName($AssemblyPath).Version.ToString() }
    catch { return "unreadable" }
}

function Test-DotNet8Runtime {
    if (!(Get-Command dotnet -ErrorAction SilentlyContinue)) { return $false }
    try {
        $installedRuntimes = & dotnet --list-runtimes 2>$null
        return [bool]($installedRuntimes | Where-Object { $_ -match '^Microsoft\.NETCore\.App 8\.' })
    }
    catch { return $false }
}

function Test-ExactHash([string]$Path, [string]$ExpectedHash) {
    if (!$Path -or !(Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $ExpectedHash
}

function Read-Ini([string]$Path) {
    $result = @{}
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $result }
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (!$trimmed -or $trimmed.StartsWith("#") -or !$trimmed.Contains("=")) { continue }
        $parts = $trimmed.Split(@("="), 2, [StringSplitOptions]::None)
        $result[$parts[0].Trim()] = $parts[1].Trim()
    }
    return $result
}

$hkRoot = Find-GameRoot $HollowKnightPath "Hollow Knight"
$ssRoot = Find-GameRoot $SilksongPath "Hollow Knight Silksong"
Write-Host "Game Handoff 0.2.2 preflight ($Mode)" -ForegroundColor Cyan
Write-Host "Hollow Knight root: $hkRoot"
Write-Host "Silksong root:     $ssRoot"
Write-Host ""

Write-Check ([bool]$hkRoot -and (Test-Path -LiteralPath $hkRoot -PathType Container)) `
    "Hollow Knight install" $(if ($hkRoot) { $hkRoot } else { "not found; pass -HollowKnightPath" })
Write-Check ([bool]$ssRoot -and (Test-Path -LiteralPath $ssRoot -PathType Container)) `
    "Silksong install" $(if ($ssRoot) { $ssRoot } else { "not found; pass -SilksongPath" })

$hkManaged = if ($hkRoot) { Join-Path $hkRoot "hollow_knight_Data\Managed" } else { "" }
$ssManaged = if ($ssRoot) { Join-Path $ssRoot "Hollow Knight Silksong_Data\Managed" } else { "" }
$hkAssembly = if ($hkManaged) { Join-Path $hkManaged "Assembly-CSharp.dll" } else { "" }
$ssAssembly = if ($ssManaged) { Join-Path $ssManaged "Assembly-CSharp.dll" } else { "" }

Write-Advisory (Test-VersionMarker $hkAssembly "1.5.78.11833") `
    "Hollow Knight version" "1.5.78.11833 is tested; other versions are allowed but unverified"
Write-Check (Test-VersionMarker $ssAssembly "1.0.30000") `
    "Silksong version" "required 1.0.30000"
Write-Check (Test-ExactHash $hkAssembly "5944411BD93830369390A4B51766EE68C4AB26195B299E25A07B5E7D0E00086D") `
    "HK Modding API" "required v77 patched Assembly-CSharp.dll"

$hkDebug = Find-FirstFile @(
    $(if ($hkManaged) { Join-Path $hkManaged "Mods\DebugMod\DebugMod.dll" } else { "" }),
    $(if ($hkManaged) { Join-Path $hkManaged "Mods\DebugMod.dll" } else { "" })
)
$hkAdapter = Find-FirstFile @(
    $(if ($hkManaged) { Join-Path $hkManaged "Mods\GameHandoff\GameHandoff.HollowKnight.dll" } else { "" }),
    $(if ($hkManaged) { Join-Path $hkManaged "Mods\GameHandoff.HollowKnight.dll" } else { "" })
)
$hkCommon = Find-FirstFile @(
    $(if ($hkManaged) { Join-Path $hkManaged "Mods\GameHandoff\GameHandoff.Common.dll" } else { "" }),
    $(if ($hkManaged) { Join-Path $hkManaged "Mods\GameHandoff.Common.dll" } else { "" })
)

Write-Check ((Get-AssemblyVersion $hkDebug) -eq "1.4.10.5") `
    "HK DebugMod version" ("found " + (Get-AssemblyVersion $hkDebug) + "; required 1.4.10.5")
Write-Check (Test-ExactHash $hkDebug "F3712E5AAAC6DA9C8967CEE513CCBECEB8B7981342D3D850E897F77AE9F531A3") `
    "HK DebugMod binary" "must match the tested 1.4.10.5 build"
Write-Check ((Get-AssemblyVersion $hkAdapter) -eq "0.2.2.0") `
    "HK Game Handoff adapter" ("found " + (Get-AssemblyVersion $hkAdapter) + "; required 0.2.2.0")
Write-Check ((Get-AssemblyVersion $hkCommon) -eq "0.2.2.0") `
    "HK shared library" ("found " + (Get-AssemblyVersion $hkCommon) + "; required 0.2.2.0")

$ssBepInEx = if ($ssRoot) { Join-Path $ssRoot "BepInEx\core\BepInEx.dll" } else { "" }
$ssDebug = if ($ssRoot) { Join-Path $ssRoot "BepInEx\plugins\hk_speedrunning-DebugMod\DebugMod.dll" } else { "" }
$ssAdapter = if ($ssRoot) { Join-Path $ssRoot "BepInEx\plugins\GameHandoff\GameHandoff.Silksong.dll" } else { "" }
$ssCommon = if ($ssRoot) { Join-Path $ssRoot "BepInEx\plugins\GameHandoff\GameHandoff.Common.dll" } else { "" }

Write-Check ((Get-AssemblyVersion $ssBepInEx) -eq "5.4.23.4") `
    "Silksong BepInEx" ("found " + (Get-AssemblyVersion $ssBepInEx) + "; required 5.4.23.4")
Write-Check ((Get-AssemblyVersion $ssDebug) -eq "1.1.2.0") `
    "Silksong DebugMod version" ("found " + (Get-AssemblyVersion $ssDebug) + "; required 1.1.2.0")
Write-Check (Test-ExactHash $ssDebug "7E7D52C11A7A67C9D2E27D3B497FA192CD50CB38B314602417011671F7E8CC78") `
    "Silksong DebugMod binary" "must match the tested 1.1.2 build"
Write-Check ((Get-AssemblyVersion $ssAdapter) -eq "0.2.2.0") `
    "Silksong Game Handoff adapter" ("found " + (Get-AssemblyVersion $ssAdapter) + "; required 0.2.2.0")
Write-Check ((Get-AssemblyVersion $ssCommon) -eq "0.2.2.0") `
    "Silksong shared library" ("found " + (Get-AssemblyVersion $ssCommon) + "; required 0.2.2.0")

$coordinator = Join-Path $PSScriptRoot "Coordinator\GameHandoff.Coordinator.dll"
Write-Check ((Get-AssemblyVersion $coordinator) -eq "0.2.2.0") `
    "Coordinator" ("found " + (Get-AssemblyVersion $coordinator) + "; required 0.2.2.0")
Write-Check (Test-DotNet8Runtime) ".NET runtime" "Microsoft.NETCore.App 8.x is required"

$configPath = Join-Path $PSScriptRoot ("Coordinator\" + $Mode + ".ini")
$config = Read-Ini $configPath
$sessionKey = [string]$config["sessionKey"]
$keyReady = $sessionKey.Length -ge 12 -and !$sessionKey.Contains("CHANGE_ME")
Write-Check $keyReady "Coordinator session key" "must be changed and identical on both computers"

if ($Mode -eq "client") {
    $peerAddress = [string]$config["peerAddress"]
    $addressReady = $peerAddress -and $peerAddress -ne "25.0.0.1"
    Write-Check $addressReady "Hamachi host address" ("configured as " + $peerAddress)
}

Write-Host ""
if ($script:FailureCount -eq 0) {
    Write-Host "PREFLIGHT PASSED. Launch both games and the coordinator, then use status before arm." -ForegroundColor Green
    exit 0
}

Write-Host ("PREFLIGHT FAILED: " + $script:FailureCount + " required check(s) need attention.") -ForegroundColor Red
exit 1

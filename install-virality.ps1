<#
.SYNOPSIS
    Installs the Virality mod (MaxWasUnavailable) for Content Warning on Windows 10/11.
.DESCRIPTION
    Finds the Steam install of Content Warning, downloads the latest Virality release
    and all its dependencies (BepInExPack etc.) from Thunderstore and installs them.
.PARAMETER GamePath
    Optional. Path to the "Content Warning" folder if auto-detection fails.
.PARAMETER Uninstall
    Removes the Virality plugin folder again (BepInEx itself stays).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install-virality.ps1
#>
[CmdletBinding()]
param(
    [string]$GamePath,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RootPackage = @{ Namespace = 'MaxWasUnavailable'; Name = 'Virality' }
$ApiBase = 'https://thunderstore.io/api/experimental/package'
$DlBase = 'https://thunderstore.io/package/download'

function Find-GamePath {
    $roots = @()
    foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props.SteamPath) { $roots += $props.SteamPath }
        if ($props.InstallPath) { $roots += $props.InstallPath }
    }
    $libs = @($roots)
    foreach ($root in $roots) {
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libs += $m.Groups[1].Value -replace '\\\\', '\'
            }
        }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $candidate = Join-Path $lib 'steamapps\common\Content Warning'
        if (Test-Path (Join-Path $candidate 'Content Warning.exe')) { return $candidate }
    }
    return $null
}

if (-not $GamePath) { $GamePath = Find-GamePath }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath 'Content Warning.exe'))) {
    throw 'Content Warning not found. Re-run with -GamePath "<path to Content Warning folder>".'
}
Write-Host "Game folder: $GamePath"

if (Get-Process -Name 'Content Warning' -ErrorAction SilentlyContinue) {
    throw 'Content Warning is running. Close it and run the script again.'
}

$pluginDir = Join-Path $GamePath 'BepInEx\plugins'
$modDir = Join-Path $pluginDir "$($RootPackage.Namespace)-$($RootPackage.Name)"

if ($Uninstall) {
    if (Test-Path $modDir) {
        Remove-Item $modDir -Recurse -Force
        Write-Host 'Virality removed.'
    } else {
        Write-Host 'Virality is not installed.'
    }
    return
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cw-virality-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$seen = @{}

function Install-Package([string]$Namespace, [string]$Name, [string]$Version) {
    $id = "$Namespace-$Name"
    if ($seen.ContainsKey($id)) { return }
    $seen[$id] = $true

    # Version info: root package resolves to latest, dependencies are pinned
    $info = $null
    try {
        $url = if ($Version) { "$ApiBase/$Namespace/$Name/$Version/" } else { "$ApiBase/$Namespace/$Name/" }
        $info = Invoke-RestMethod -Uri $url
    } catch {
        if (-not $Version) { throw "Package $id not found on Thunderstore: $($_.Exception.Message)" }
        Write-Warning "No metadata for $id-$Version, dependencies of it are skipped."
    }
    $meta = if ($info -and $info.latest) { $info.latest } else { $info }
    if (-not $Version) { $Version = $meta.version_number }

    Write-Host "Installing $id $Version"
    $zip = Join-Path $tmp "$id-$Version.zip"
    Invoke-WebRequest -Uri "$DlBase/$Namespace/$Name/$Version/" -OutFile $zip -UseBasicParsing
    $extract = Join-Path $tmp "$id-$Version"
    Expand-Archive -Path $zip -DestinationPath $extract -Force

    if ($Name -eq 'BepInExPack') {
        # Pack ships a BepInExPack folder whose contents belong into the game root
        Copy-Item -Path (Join-Path $extract 'BepInExPack\*') -Destination $GamePath -Recurse -Force
    } else {
        $target = Join-Path $pluginDir $id
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item -Path (Join-Path $extract '*') -Destination $target -Recurse -Force
    }

    foreach ($dep in @($meta.dependencies)) {
        if (-not $dep) { continue }
        $p = $dep -split '-'
        if ($p.Count -ne 3) { Write-Warning "Skipping unparsable dependency: $dep"; continue }
        Install-Package $p[0] $p[1] $p[2]
    }
}

try {
    # BepInExPack must be in place before plugins; Install-Package handles deps after the root,
    # so create the plugins dir up front.
    New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
    Install-Package $RootPackage.Namespace $RootPackage.Name $null
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Done. Start Content Warning once, then adjust settings in-game (Settings > Mods > Virality).'
Write-Host 'All players in the lobby need the mod.'

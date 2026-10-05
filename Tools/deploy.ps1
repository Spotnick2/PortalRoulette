<#
    deploy.ps1 - Deploy Portal Roulette (and optionally the dev probe) into
    the WoW: Forever AddOns folder.

    The addon's files are the git-tracked files outside the dev-only folders
    (tests, Tools, docs, .github, ...), copied with their folder structure,
    so untracked scratch folders never reach the client. The repo keeps
    `## Version: @project-version@` for the packager; the deployed TOC gets
    `## Version: dev`. A file the previous deploy wrote that is no longer
    tracked is removed.

    Embedded libraries come from sibling checkouts, each through its own
    Tools\deploy.ps1, and only once the TOC loads them:
      - LibGlass-1.0     ($env:LIBGLASS or -LibGlass, else ..\LibGlass)
      - LibShowcase-1.0  ($env:LIBSHOWCASE or -LibShowcase, else ..\LibShowcase)

    Usage:
        pwsh Tools/deploy.ps1                 # addon only
        pwsh Tools/deploy.ps1 -Probe          # addon + PortalRouletteProbe
        pwsh Tools/deploy.ps1 -ProbeOnly      # just PortalRouletteProbe
        pwsh Tools/deploy.ps1 -AddOnsPath "D:\...\_classic_beta_\Interface\AddOns"
#>

param(
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns",
    [switch]$Probe,
    [switch]$ProbeOnly,
    [string]$LibGlass = "",
    [string]$LibShowcase = "",
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AddonName = "PortalRoulette"
$DevOnly = @("tests/", "Tools/", "docs/", ".github/", ".claude/")
$DevFiles = @(".gitignore", ".gitattributes", ".pkgmeta", "AGENTS.md", "CLAUDE.md", "README.md", "CHANGELOG.md")

if (-not (Test-Path $AddOnsPath)) {
    Write-Error "AddOns path not found: $AddOnsPath"
    exit 1
}

function Get-ShippedFiles {
    Push-Location $RepoRoot
    try {
        $files = @(git ls-files)
        if ($LASTEXITCODE -ne 0) { throw "git ls-files failed" }
    } finally { Pop-Location }
    return @($files | Where-Object {
        $f = $_
        -not ($DevFiles -contains $f) -and -not ($DevOnly | Where-Object { $f.StartsWith($_) })
    })
}

function Deploy-Library {
    param([string]$Name, [string]$Root, [string]$EnvValue, [string]$Folder)
    $toc = Get-Content (Join-Path $RepoRoot "$AddonName.toc") -Raw
    if ($toc -notmatch [regex]::Escape("Libs\$Name")) { return }
    if (-not $Root) { $Root = $EnvValue }
    if (-not $Root) { $Root = Join-Path (Split-Path -Parent $RepoRoot) $Folder }
    $script = Join-Path $Root "Tools\deploy.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        throw "$Name checkout not found at $Root. Clone it next to this repository, or pass its path."
    }
    & pwsh -NoProfile -File $script -Addon $AddonName -AddOnsPath $AddOnsPath -Lua $Lua
    if ($LASTEXITCODE -ne 0) { throw "$Name deploy refused; $AddonName was not touched" }
}

function Deploy-Addon {
    $dest = Join-Path $AddOnsPath $AddonName
    $files = Get-ShippedFiles
    foreach ($f in $files) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $f))) { throw "tracked file missing on disk: $f" }
    }

    # Libraries first: a refusal there leaves the deployed addon untouched.
    Deploy-Library -Name "LibGlass-1.0" -Root $LibGlass -EnvValue $env:LIBGLASS -Folder "LibGlass"
    Deploy-Library -Name "LibShowcase-1.0" -Root $LibShowcase -EnvValue $env:LIBSHOWCASE -Folder "LibShowcase"

    Write-Host "Deploying $AddonName -> $dest" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force $dest | Out-Null
    foreach ($f in $files) {
        $src = Join-Path $RepoRoot $f
        $target = Join-Path $dest $f
        $dir = Split-Path -Parent $target
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
        if ($f -like "*.toc") {
            (Get-Content -LiteralPath $src -Raw) -replace '## Version: @project-version@', '## Version: dev' |
                Set-Content -LiteralPath $target -NoNewline
        } else {
            Copy-Item -LiteralPath $src -Destination $target -Force
        }
    }
    Write-Host "  $($files.Count) files"

    # Remove what an earlier deploy wrote and git no longer tracks. Libs\ is
    # owned by the library deploys.
    $manifest = Join-Path $dest ".portalroulette-deploy.txt"
    if (Test-Path $manifest) {
        foreach ($old in Get-Content $manifest) {
            if ($old -and -not ($files -contains $old)) {
                $p = Join-Path $dest $old
                if (Test-Path -LiteralPath $p) {
                    Write-Host "  removing stale $old" -ForegroundColor DarkYellow
                    Remove-Item -LiteralPath $p -Force
                }
            }
        }
    }
    $files | Set-Content $manifest
}

function Deploy-Probe {
    $src = Join-Path $RepoRoot "Tools\PortalRouletteProbe"
    $dest = Join-Path $AddOnsPath "PortalRouletteProbe"
    Write-Host "Deploying PortalRouletteProbe -> $dest" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force $dest | Out-Null
    Get-ChildItem -LiteralPath $src -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dest $_.Name) -Force
        Write-Host "  $($_.Name)"
    }
}

if (-not $ProbeOnly) { Deploy-Addon }
if ($Probe -or $ProbeOnly) { Deploy-Probe }

Write-Host ""
Write-Host "Done. In game:  /console scriptErrors 1  then  /reload (a new addon folder needs a client restart)" -ForegroundColor Green
Write-Host "Check the AddOn list: enabled AND not flagged out of date." -ForegroundColor Green

<#
    run.ps1 - Syntax-check every tracked Lua file, check the library
    checkouts, and run every tests\test_*.lua under Lua 5.1, through
    WowTestKit at the commit tests\kit.pin names (its scripts\run.ps1).

    The tests are plain Lua 5.1 scripts that load the addon against
    tests/wow_stubs.lua (on the kit). WoW uses Lua 5.1, so the tests do too,
    not whatever newer Lua may be first on PATH.

    Usage:
        pwsh tests/run.ps1
        pwsh tests/run.ps1 -Lua "C:\path\to\lua5.1.exe"
        pwsh tests/run.ps1 -KitDev      # the ..\WowTestKit working copy, not the pin
#>

param(
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe",
    [switch]$KitDev
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Lua)) {
    Write-Error "Lua 5.1 interpreter not found at: $Lua  (pass -Lua <path>)"
    exit 1
}
$Luac = Join-Path (Split-Path -Parent $Lua) "luac.exe"

# Run from the repo root so tests can dofile("tests/...") and read the TOC.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    # Every Lua file git knows about (tracked or staged/new, minus ignored),
    # so a file missing from the TOC (the probe, the tests) is still
    # syntax-checked. The kit's runner checks only a TOC's files, so it is
    # not given one: this is the wider check.
    $luaFiles = @(git ls-files --cached --others --exclude-standard -- "*.lua" |
        Where-Object { -not $_.StartsWith("Libs/") -and (Test-Path $_) })
    & $Luac -p @luaFiles
    if ($LASTEXITCODE -ne 0) { Write-Error "luac -p failed"; exit 1 }
    Write-Host "luac -p: $($luaFiles.Count) Lua files OK"

    # The library tests run against sibling checkouts. Prove their runtime
    # file is what the .pkgmeta tag packages; otherwise the result says so.
    $pkg = Get-Content ".pkgmeta" -Raw
    foreach ($lib in @(
            @{ Name = "LibGlass-1.0"; Env = $env:LIBGLASS; Dir = "..\LibGlass"; File = "LibGlass.lua" },
            @{ Name = "LibShowcase-1.0"; Env = $env:LIBSHOWCASE; Dir = "..\LibShowcase"; File = "LibShowcase.lua" })) {
        $dir = if ($lib.Env) { $lib.Env } else { $lib.Dir }
        $m = [regex]::Match($pkg, "Libs/" + [regex]::Escape($lib.Name) + ":\s*\r?\n\s*url: [^\r\n]+\r?\n\s*tag: (\S+)")
        if (-not $m.Success) { Write-Error "no tag pin for $($lib.Name) in .pkgmeta"; exit 1 }
        $tag = $m.Groups[1].Value
        $file = Join-Path $dir $lib.File
        if (-not (Test-Path $file)) {
            Write-Host "WARNING: $($lib.Name) checkout missing at $dir - its tests are SKIPPED" -ForegroundColor Yellow
            continue
        }
        $pinned = git -C $dir show "$($tag):$($lib.File)" 2>$null
        $current = Get-Content $file
        if ($LASTEXITCODE -ne 0 -or ($pinned -join "`n") -ne ($current -join "`n")) {
            Write-Host "WARNING: $dir/$($lib.File) differs from the pinned tag $tag - tests are not testing the release" -ForegroundColor Yellow
        } else {
            Write-Host "$($lib.Name): checkout matches pinned tag $tag"
        }
    }
} finally {
    Pop-Location
}

. (Join-Path $PSScriptRoot "kit.ps1")
$kit = Get-WowTestKit -RepoRoot $RepoRoot -KitDev:$KitDev
& (Join-Path $kit "scripts\run.ps1") -RepoRoot $RepoRoot -Lua $Lua
exit $LASTEXITCODE

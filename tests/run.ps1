<#
    run.ps1 - Syntax-check every tracked Lua file and run every unit test.

    The tests are plain Lua 5.1 scripts that load the addon against
    tests/wow_stubs.lua. WoW uses Lua 5.1, so the tests do too, not whatever
    newer Lua may be first on PATH.

    Usage:
        pwsh tests/run.ps1
        pwsh tests/run.ps1 -Lua "C:\path\to\lua5.1.exe"
#>

param(
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe"
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
    # so a file missing from the TOC is still syntax-checked.
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

    $failed = 0
    foreach ($t in Get-ChildItem "tests\test_*.lua" | Sort-Object Name) {
        & $Lua $t.FullName
        if ($LASTEXITCODE -ne 0) { $failed++ }
    }
    if ($failed -gt 0) { Write-Error "$failed test file(s) failed"; exit 1 }
    Write-Host "All tests passed" -ForegroundColor Green
} finally {
    Pop-Location
}

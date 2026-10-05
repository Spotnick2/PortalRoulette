-- The TOC, the deploy file set and .pkgmeta.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local toc = assert(io.open("PortalRoulette.toc")):read("*a"):gsub("\r", "")
H.check(toc:find("## Interface: 16001\n"), "Interface is 16001")
H.check(toc:find("## Version: @project%-version@\n"), "Version stays the packager token")
H.check(toc:find("## SavedVariables: PortalRouletteDB\n"), "PortalRouletteDB is the saved table")
H.check(toc:find("## X%-Curse%-Project%-ID: 1540067\n"), "CurseForge project ID is 1540067")

local files = H.tocFiles("PortalRoulette.toc")
for _, f in ipairs(files) do
    if not f:find("^Libs/LibGlass") and not f:find("^Libs/LibShowcase") then
        H.check(io.open(f) ~= nil, "TOC file exists: " .. f)
    end
end
H.eq(files[1], "Libs/LibStub/LibStub.lua", "LibStub loads first")
local order = {}
for i, f in ipairs(files) do order[f] = i end
H.check(order["Core/Constants.lua"] < order["Core/Compat.lua"], "Constants before Compat")
H.check(order["Core/Compat.lua"] < order["Core/Events.lua"], "Compat before Events")
H.check(order["Libs/LibGlass-1.0/LibGlass-1.0.xml"] < order["Core/Constants.lua"], "libraries before the addon")
H.eq(files[#files], "Core/Init.lua", "Init loads last")
H.check(not order["Tools/PortalRouletteProbe/PortalRouletteProbe.lua"], "the probe is not shipped")

local pkg = assert(io.open(".pkgmeta")):read("*a"):gsub("\r", "")
H.check(pkg:find("package%-as: PortalRoulette\n"), ".pkgmeta packages as PortalRoulette")
for _, ignored in ipairs({ "tests", "Tools", "docs", "AGENTS.md", "CLAUDE.md" }) do
    H.check(pkg:find("\n%s*%- " .. ignored:gsub("%p", "%%%0") .. "\n"), ".pkgmeta ignores " .. ignored)
end
local ignore = assert(io.open(".gitignore")):read("*a")
H.check(ignore:find("Libs/LibGlass%-1.0/"), "LibGlass is never committed")
H.check(ignore:find("Libs/LibShowcase%-1.0/"), "LibShowcase is never committed")
-- The .pkgmeta pins match the minimum library versions the code requires.
local function needs(file)
    local src = assert(io.open(file)):read("*a")
    return tonumber(src:match("local NEEDS_MINOR = (%d+)"))
end
local glassPin = tonumber(pkg:match("Libs/LibGlass%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
local showcasePin = tonumber(pkg:match("Libs/LibShowcase%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
H.check(glassPin and glassPin >= needs("UI/Skin.lua"), "LibGlass pin covers what Skin.lua needs")
H.check(showcasePin and showcasePin >= needs("UI/Wheel/Presentation.lua"), "LibShowcase pin covers what Presentation.lua needs")
for _, lib in ipairs({ "LibGlass-1.0", "LibShowcase-1.0" }) do
    for _, sub in ipairs({ "tests", "docs", "Tools" }) do
        local line = "- Libs/" .. lib .. "/" .. sub .. "\n"
        H.check(pkg:find(line, 1, true), ".pkgmeta ignores Libs/" .. lib .. "/" .. sub)
    end
end

H.done("test_manifest")

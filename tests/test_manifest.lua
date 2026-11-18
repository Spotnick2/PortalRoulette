-- The TOC, the deploy file set and .pkgmeta.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- What every addon TOC must get right (interface, version token, every
-- listed .lua file exists, each line listed once). The .xml lines are the
-- gitignored libraries; the existence loop below handles them.
Kit.checkToc("PortalRoulette.toc")

local toc =assert(io.open("PortalRoulette.toc")):read("*a"):gsub("\r", "")
check(toc:find("## Interface: 16001\n"), "Interface is 16001")
check(toc:find("## Version: @project%-version@\n"), "Version stays the packager token")
check(toc:find("## SavedVariables: PortalRouletteDB\n"), "PortalRouletteDB is the saved table")
check(toc:find("## X%-Curse%-Project%-ID: 1540067\n"), "CurseForge project ID is 1540067")

local files = H.tocFiles("PortalRoulette.toc")
for _, f in ipairs(files) do
    if not f:find("^Libs/LibGlass") and not f:find("^Libs/LibShowcase") then
        check(io.open(f) ~= nil, "TOC file exists: " .. f)
    end
end
eq(files[1], "Libs/LibStub/LibStub.lua", "LibStub loads first")
local order = {}
for i, f in ipairs(files) do order[f] = i end
check(order["Core/Constants.lua"] < order["Core/Compat.lua"], "Constants before Compat")
check(order["Core/Compat.lua"] < order["Core/Events.lua"], "Compat before Events")
check(order["Libs/LibGlass-1.0/LibGlass-1.0.xml"] < order["Core/Constants.lua"], "libraries before the addon")
eq(files[#files], "Core/Init.lua", "Init loads last")
check(not order["Tools/PortalRouletteProbe/PortalRouletteProbe.lua"], "the probe is not shipped")

local pkg = assert(io.open(".pkgmeta")):read("*a"):gsub("\r", "")
check(pkg:find("package%-as: PortalRoulette\n"), ".pkgmeta packages as PortalRoulette")
for _, ignored in ipairs({ "tests", "Tools", "docs", "AGENTS.md", "CLAUDE.md" }) do
    check(pkg:find("\n%s*%- " .. ignored:gsub("%p", "%%%0") .. "\n"), ".pkgmeta ignores " .. ignored)
end
local ignore = assert(io.open(".gitignore")):read("*a")
check(ignore:find("Libs/LibGlass%-1.0/"), "LibGlass is never committed")
check(ignore:find("Libs/LibShowcase%-1.0/"), "LibShowcase is never committed")
-- The .pkgmeta pins match the minimum library versions the code requires.
local function needs(file)
    local src = assert(io.open(file)):read("*a")
    return tonumber(src:match("local NEEDS_MINOR = (%d+)"))
end
local glassPin = tonumber(pkg:match("Libs/LibGlass%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
local showcasePin = tonumber(pkg:match("Libs/LibShowcase%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
check(glassPin and glassPin >= needs("UI/Skin.lua"), "LibGlass pin covers what Skin.lua needs")
check(showcasePin and showcasePin >= needs("UI/Wheel/Presentation.lua"), "LibShowcase pin covers what Presentation.lua needs")
for _, lib in ipairs({ "LibGlass-1.0", "LibShowcase-1.0" }) do
    for _, sub in ipairs({ "tests", "docs", "Tools" }) do
        local line = "- Libs/" .. lib .. "/" .. sub .. "\n"
        check(pkg:find(line, 1, true), ".pkgmeta ignores Libs/" .. lib .. "/" .. sub)
    end
end

done("test_manifest")

------------------------------------------------------------
-- harness.lua: addon loading for the tests (adapted from Apotheca's
-- tests/harness.lua). The assertions are WowTestKit's globals (check, eq,
-- done), loaded by tests/wow_stubs.lua.
--
--     dofile("tests/wow_stubs.lua")
--     local H = dofile("tests/harness.lua")
--     H.loadForeverProbe(); H.loadProbe()
--     check(cond, "message")
--     done("test_name")
------------------------------------------------------------

local H = {}

-- The files a TOC lists (every line, .xml too), in load order, with forward
-- slashes, under the TOC's folder: Kit.tocLines as paths.
function H.tocFiles(toc)
    local files = {}
    local dir = toc:match("^(.*)/[^/]+$")
    for _, line in ipairs(Kit.tocLines(toc)) do
        line = line:gsub("\\", "/")
        files[#files + 1] = dir and (dir .. "/" .. line) or line
    end
    return files
end

local function loadFiles(files, addonName, ns)
    ns = ns or {}
    for _, f in ipairs(files) do
        local chunk, err = loadfile(f)
        if not chunk then error(err) end
        chunk(addonName, ns)
    end
    return ns
end

-- ForeverProbe, the host the dev probe depends on, from its checkout
-- ($FOREVERPROBE, else ..\ForeverProbe; GlassChat's tests/harness.lua). It's
-- private and only on the owner's disk, so CI doesn't have it: with
-- FOREVERPROBE_OPTIONAL=1 (CI) a missing checkout skips the calling test
-- file; without it (locally) it's an error, never a silent skip. Loaded into
-- THIS stub environment, the way the client loads a dependency: its files,
-- then its ADDON_LOADED. The host reads every client API through rawget, so
-- the strict globals never trip on one the stub lacks.
function H.loadForeverProbe()
    local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
    local toc = io.open(root .. "/ForeverProbe.toc", "rb")
    if not toc then
        if os.getenv("FOREVERPROBE_OPTIONAL") == "1" then
            io.write("SKIPPED: ForeverProbe isn't here (private, local only); the probe tests run locally\n")
            os.exit(0)
        end
        error("ForeverProbe checkout not found at " .. root .. ": clone it there or set FOREVERPROBE", 0)
    end
    local files = {}
    for line in toc:read("*a"):gmatch("[^\r\n]+") do
        if line:match("%.lua$") and not line:match("^#") then files[#files + 1] = root .. "/" .. line end
    end
    toc:close()
    for _, file in ipairs(files) do assert(loadfile(file))("ForeverProbe", {}) end
    WoW.fire("ADDON_LOADED", "ForeverProbe")
    return rawget(_G, "ForeverProbe")
end

-- The dev-only probe addon (a ForeverProbe module: load the host first),
-- then the client's login sequence. Returns the probe's namespace (its
-- _test seam).
function H.loadProbe(savedDB)
    local ns = loadFiles(H.tocFiles("Tools/PortalRouletteProbe/PortalRouletteProbe.toc"), "PortalRouletteProbe")
    if savedDB then rawset(_G, "PortalRouletteProbeDB", savedDB) end
    WoW.fire("ADDON_LOADED", "PortalRouletteProbe")
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD")
    return ns
end

-- /fp <msg>: the ForeverProbe slash command, as typed in game.
function H.fp(msg) H.slash("FOREVERPROBE", msg) end

-- Portal Roulette itself. Libs\ lines load only LibStub: the vendored
-- LibDBIcon stack needs far more of the client than the stubs model, and
-- LibGlass / LibShowcase come from sibling checkouts (opts.libs = paths).
-- The addon's fallbacks (no LibGlass, no LibShowcase) are what run here.
function H.loadAddon(opts)
    opts = opts or {}
    local ns = {}
    for _, f in ipairs(H.tocFiles("PortalRoulette.toc")) do
        local isLib = f:find("^Libs/")
        if not isLib or f == "Libs/LibStub/LibStub.lua" then
            local chunk, err = loadfile(f)
            if not chunk then error(err) end
            chunk("PortalRoulette", ns)
        end
    end
    for _, lib in ipairs(opts.libs or {}) do
        if type(lib) == "function" then
            lib() -- a fake library built in the test
        else
            local chunk, err = loadfile(lib)
            if not chunk then error(err) end
            chunk()
        end
    end
    if opts.savedDB then rawset(_G, "PortalRouletteDB", opts.savedDB) end
    WoW.fire("ADDON_LOADED", "PortalRoulette")
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD")
    WoW.advance(0)
    return ns
end

-- Run a slash command by its SlashCmdList key.
function H.slash(key, msg)
    local fn = SlashCmdList[key]
    if not fn then error("no slash command " .. key) end
    fn(msg or "")
end

-- Frames created from a template, by template name.
function H.framesWithTemplate(template)
    local out = {}
    for _, f in ipairs(WoW.frames) do
        if f._template == template then out[#out + 1] = f end
    end
    return out
end

-- Printed lines (the chat frame's included) matching a pattern.
function H.messagesMatching(pattern)
    local n = 0
    for _, m in ipairs(WoW.chat) do if m:find(pattern) then n = n + 1 end end
    return n
end

return H

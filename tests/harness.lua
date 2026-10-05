------------------------------------------------------------
-- harness.lua: assertions and addon loading for the tests
-- (adapted from Apotheca's tests/harness.lua).
--
--     dofile("tests/wow_stubs.lua")
--     local H = dofile("tests/harness.lua")
--     H.loadProbe()
--     H.check(cond, "message")
--     H.done("test_name")
------------------------------------------------------------

local H = {}
local passed, failed = 0, 0

function H.check(cond, msg)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

function H.eq(actual, expected, msg)
    H.check(actual == expected, (msg or "") .. " (expected " .. tostring(expected)
            .. ", got " .. tostring(actual) .. ")")
end

function H.done(name)
    if failed > 0 then
        io.stderr:write(name .. ": " .. failed .. " failed, " .. passed .. " passed\n")
        os.exit(1)
    end
    io.write(name .. ": " .. passed .. " tests passed\n")
end

-- The files a TOC lists, in load order, with forward slashes.
function H.tocFiles(toc)
    local files = {}
    local dir = toc:match("^(.*)/[^/]+$")
    for line in io.lines(toc) do
        line = line:gsub("\r", ""):gsub("\\", "/")
        if line ~= "" and not line:match("^#") then
            files[#files + 1] = dir and (dir .. "/" .. line) or line
        end
    end
    return files
end

local function loadFiles(files, addonName)
    for _, f in ipairs(files) do
        local chunk, err = loadfile(f)
        if not chunk then error(err) end
        chunk(addonName, {})
    end
end

-- The dev-only probe addon, then the client's login sequence.
function H.loadProbe(savedDB)
    loadFiles(H.tocFiles("Tools/PortalRouletteProbe/PortalRouletteProbe.toc"), "PortalRouletteProbe")
    if savedDB then rawset(_G, "PortalRouletteProbeDB", savedDB) end
    WoW.fire("ADDON_LOADED", "PortalRouletteProbe")
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD")
end

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
        local chunk, err = loadfile(lib)
        if not chunk then error(err) end
        chunk()
    end
    if opts.savedDB then rawset(_G, "PortalRouletteDB", opts.savedDB) end
    WoW.fire("ADDON_LOADED", "PortalRoulette")
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD")
    WoW.runTimers(0)
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

function H.messagesMatching(pattern)
    local n = 0
    for _, m in ipairs(WoW.messages) do if m:find(pattern) then n = n + 1 end end
    return n
end

return H

local _, ns = ...

-- Geometry of the wheel. Everything is measured from the disc's center.
local Layout = {
    ROOT_W = 680,       -- room for Karazhan outside the disc
    ROOT_H = 560,
    HEADER_H = 34,
    DISC = 440,
    DISC_Y = 16,        -- disc center above the root's center
    NODE = 72,          -- capital beads
    BONUS = 64,         -- bonus beads (Dalaran, Karazhan)
    NODE_RADIUS = 150,  -- the 6 o'clock plate stays inside the disc
    OUTER_RADIUS = 295, -- satellites outside the disc (Karazhan)
    ORB = 128,
    STRIP_H = 44,
    PLATE_H = 22,
}
ns.Layout = Layout

-- Offset of a clock position (12 = top, clockwise) at `radius`.
function Layout.ClockOffset(clock, radius)
    local angle = math.rad(90 - (clock % 12) * 30)
    return math.cos(angle) * radius, math.sin(angle) * radius
end

-- The side of the disc a clock position is on: "LEFT", "RIGHT" or "TOP"/"BOTTOM".
function Layout.Side(clock)
    clock = clock % 12
    if clock == 0 then
        return "TOP"
    elseif clock == 6 then
        return "BOTTOM"
    elseif clock < 6 then
        return "RIGHT"
    end
    return "LEFT"
end

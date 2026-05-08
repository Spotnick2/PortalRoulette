local _, ns = ...

local ReagentPanel = {}
ns.ReagentPanel = ReagentPanel

local PANEL_W = 170
local PANEL_H = 108
local ROW_W = 148
local ROW_H = 38
local ICON_SIZE = 30

local reagentRows = {
    {
        itemID      = ns.Constants.ITEM_RUNE_TELEPORTATION,
        iconTexture = ns.Media.REAGENT_ICON_TELEPORT,
        fallbackIcon = ns.Media.ICON_RUNE_TELEPORT_CUSTOM,
    },
    {
        itemID      = ns.Constants.ITEM_RUNE_PORTALS,
        iconTexture = ns.Media.REAGENT_ICON_PORTAL,
        fallbackIcon = ns.Media.ICON_RUNE_PORTAL_CUSTOM,
    },
}

local function createSolidTexture(parent, layer, color)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(color[1], color[2], color[3], color[4])
    return texture
end

local function addBorder(frame, r, g, b, a)
    local top = createSolidTexture(frame, "BORDER", { r, g, b, a })
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    top:SetHeight(1)

    local bottom = createSolidTexture(frame, "BORDER", { r, g, b, a })
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    bottom:SetHeight(1)

    local left = createSolidTexture(frame, "BORDER", { r, g, b, a })
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    left:SetWidth(1)

    local right = createSolidTexture(frame, "BORDER", { r, g, b, a })
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    right:SetWidth(1)
end

function ReagentPanel:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(PANEL_W, PANEL_H)
    frame:EnableMouse(false)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.bg:SetVertexColor(0.02, 0.025, 0.035, 0.78)
    addBorder(frame, 0.72, 0.55, 0.24, 0.78)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -7)
    frame.title:SetText("Reagents")
    frame.title:SetTextColor(0.90, 0.82, 0.55)

    frame.rows = {}
    for index, rowData in ipairs(reagentRows) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(ROW_W, ROW_H)
        row:SetPoint("TOP", frame, "TOP", 0, -26 - ((index - 1) * (ROW_H + 5)))
        row:EnableMouse(false)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.bg:SetVertexColor(0.04, 0.045, 0.06, 0.52)
        addBorder(row, 0.55, 0.42, 0.20, 0.42)

        row.iconFrame = CreateFrame("Frame", nil, row)
        row.iconFrame:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
        row.iconFrame:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.iconFrame:EnableMouse(false)
        row.iconFrame.bg = row.iconFrame:CreateTexture(nil, "BACKGROUND")
        row.iconFrame.bg:SetAllPoints()
        row.iconFrame.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.iconFrame.bg:SetVertexColor(0, 0, 0, 0.46)
        addBorder(row.iconFrame, 0.74, 0.58, 0.26, 0.6)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("CENTER", row.iconFrame, "CENTER")
        row.icon:SetTexture(rowData.iconTexture or rowData.fallbackIcon)
        row.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.count:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -1, 1)
        row.count:SetJustifyH("RIGHT")
        row.count:SetShadowOffset(1, -1)
        row.count:SetShadowColor(0, 0, 0, 1)

        row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameLabel:SetPoint("LEFT", row.iconFrame, "RIGHT", 7, 1)
        row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -6, 1)
        row.nameLabel:SetJustifyH("LEFT")
        row.nameLabel:SetTextColor(0.92, 0.90, 0.80)

        row.itemID      = rowData.itemID
        row.fallbackLabel = rowData.itemID == ns.Constants.ITEM_RUNE_TELEPORTATION
                            and "Rune of Teleportation" or "Rune of Portals"
        frame.rows[#frame.rows + 1] = row
    end

    self.frame = frame
    self:Refresh()
    return frame
end

function ReagentPanel:Refresh()
    local frame = self.frame
    if not frame then return end

    for _, row in ipairs(frame.rows) do
        local count = GetItemCount(row.itemID, false, false) or 0
        row.count:SetText(count > 0 and count or "0")
        if count > 0 then
            row.count:SetTextColor(1, 1, 1)
        else
            row.count:SetTextColor(1, 0.3, 0.3)
        end

        local name = GetItemInfo and GetItemInfo(row.itemID)
        row.nameLabel:SetText(name or row.fallbackLabel)
    end
end

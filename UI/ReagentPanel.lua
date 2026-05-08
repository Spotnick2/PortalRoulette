local _, ns = ...

local ReagentPanel = {}
ns.ReagentPanel = ReagentPanel

-- Row texture aspect: 2172×724 = 3:1. Icon texture: 1254×1254 = 1:1.
-- We use the standalone icon files for reliable layout control rather than
-- trying to guess where the blank count area falls in the row art.
local ROW_H  = 42
local ROW_W  = ROW_H * 3  -- 126, preserving the 3:1 source ratio
local ICON_SIZE = 34

local reagentRows = {
    {
        itemID      = ns.Constants.ITEM_RUNE_TELEPORTATION,
        rowTexture  = ns.Media.REAGENT_ROW_TELEPORT,
        iconTexture = ns.Media.REAGENT_ICON_TELEPORT,
        fallbackIcon = ns.Media.ICON_RUNE_TELEPORT_CUSTOM,
    },
    {
        itemID      = ns.Constants.ITEM_RUNE_PORTALS,
        rowTexture  = ns.Media.REAGENT_ROW_PORTAL,
        iconTexture = ns.Media.REAGENT_ICON_PORTAL,
        fallbackIcon = ns.Media.ICON_RUNE_PORTAL_CUSTOM,
    },
}

function ReagentPanel:Create(parent)
    -- Panel outer — backplate is 1122×1402 (~0.8:1, portrait).
    -- We size it to fit two rows + title + padding without stretching the art badly.
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(ROW_W + 16, ROW_H * 2 + 50)   -- 142 × 134

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(ns.Media.REAGENT_PANEL_BACKPLATE)
    frame.bg:SetAlpha(1.0)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -9)
    frame.title:SetText("Reagents")
    frame.title:SetTextColor(0.90, 0.82, 0.55)

    frame.rows = {}
    for index, rowData in ipairs(reagentRows) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(ROW_W, ROW_H)
        row:SetPoint("TOP", frame, "TOP", 0, -28 - ((index - 1) * (ROW_H + 6)))

        -- Row art (baked icon + name in the texture, provides the background style).
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture(rowData.rowTexture)

        -- Standalone icon overlaid on the left, giving full control over positioning.
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.icon:SetTexture(rowData.iconTexture or rowData.fallbackIcon)
        row.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

        -- Count number centered over the icon (stack-count badge style).
        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.count:SetPoint("BOTTOM", row.icon, "BOTTOM", 0, -1)
        row.count:SetWidth(ICON_SIZE)
        row.count:SetJustifyH("CENTER")

        -- Item name from GetItemInfo (localized, correct for all locales).
        row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
        row.nameLabel:SetWidth(ROW_W - ICON_SIZE - 14)
        row.nameLabel:SetJustifyH("LEFT")
        row.nameLabel:SetTextColor(0.90, 0.88, 0.76)

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

        -- Populate label from game data the first time (or if empty).
        if not row.nameLabel:GetText() or row.nameLabel:GetText() == "" then
            local name = GetItemInfo and GetItemInfo(row.itemID)
            row.nameLabel:SetText(name or row.fallbackLabel)
        end
    end
end

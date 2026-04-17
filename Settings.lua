-- ============================================================
-- Settings.lua  
-- In-game options panel for BlisteringScalesAlert.
-- Registered under Game Menu → Interface → AddOns.
-- Requires BSA namespace populated by BlisteringScalesAlert.lua.
-- ============================================================

-- ── Panel frame ───────────────────────────────────────────────────────────
local panel = CreateFrame("Frame", "BSASettingsPanel", UIParent)
panel:SetSize(600, 500)
panel:Hide()

-- ── Layout constants ──────────────────────────────────────────────────────
local PAD_L        = 20    -- left margin
local COL_GAP      = 12    -- gap between columns
local BTN_W        = 168   -- standard button width
local BTN_H        = 28    -- standard button height
local COLOR_BTN_W  = 130   -- color-swatch button width
local COLOR_BTN_H  = 28

-- ── Metadata constants ────────────────────────────────────────────────────
local VERSION = "@project-version@"
local TIMESTAMP = "@project-date-iso@"
local REPO = "https://github.com/Seems-Good/BlisteringScalesAlert"
local AUTHOR = "Jeremy-Gstein"
local WEBSITE = "https://seemsgood.org"



-- ── Shared helpers ────────────────────────────────────────────────────────
local function MakeSectionHeader(parent, text, anchorY)
    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD_L, anchorY)
    hdr:SetTextColor(1, 0.82, 0, 1)   -- gold
    hdr:SetText(text)
    return hdr
end

local function MakeDivider(parent, anchorY)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetSize(560, 1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD_L, anchorY)
    line:SetColorTexture(0.35, 0.35, 0.35, 0.7)
    return line
end

local function MakeButton(parent, label, w, h)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w or BTN_W, h or BTN_H)
    btn:SetText(label)
    return btn
end

-- ── Title ─────────────────────────────────────────────────────────────────
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, -16)
title:SetTextColor(1, 0.82, 0, 1)
title:SetFont(title:GetFont(), 16, "OUTLINE")
title:SetText("Blistering Scales Alert [ BSA ] |cff888888".. VERSION .."|r")

MakeDivider(panel, -38)

-- ═══════════════════════════════════════════════════════════════
--  SECTION 1 — POSITION
-- ═══════════════════════════════════════════════════════════════
MakeSectionHeader(panel, "Position", -52)

-- Show Warning
local showBtn = MakeButton(panel, "Show Warning")
showBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, -76)
showBtn:SetScript("OnClick", function()
    if BSA and BSA.alertFrame then
        BSA.alertFrame:Show()
    end
end)

-- Hide Warning
local hideBtn = MakeButton(panel, "Hide Warning")
hideBtn:SetPoint("LEFT", showBtn, "RIGHT", COL_GAP, 0)
hideBtn:SetScript("OnClick", function()
    if BSA and BSA.alertFrame then
        BSA.alertFrame:Hide()
    end
end)

-- Drag to Reposition
-- Clicking once enables drag mode (alert becomes mouse-interactive).
-- Releasing the mouse button saves the new position automatically.
local dragging = false
local dragBtn  = MakeButton(panel, "Drag to Reposition")
dragBtn:SetPoint("TOPLEFT", showBtn, "BOTTOMLEFT", 0, -8)
dragBtn:SetScript("OnClick", function()
    if not (BSA and BSA.alertFrame) then return end
    local f = BSA.alertFrame

    if dragging then
        -- Second click: exit drag mode
        dragging = false
        f:EnableMouse(false)
        f:SetScript("OnMouseDown", nil)
        f:SetScript("OnMouseUp",   nil)
        BSA.SavePosition()
        dragBtn:SetText("Drag to Reposition")
        print("|cff00ccff[BSA]|r Position saved.")
    else
        -- First click: enter drag mode
        dragging = true
        f:Show()   -- must be visible so the player can grab it
        f:EnableMouse(true)
        f:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then self:StartMoving() end
        end)
        f:SetScript("OnMouseUp", function(self)
            self:StopMovingOrSizing()
            BSA.SavePosition()
        end)
        dragBtn:SetText("|cffff4444Click again to lock|r")
        print("|cff00ccff[BSA]|r Drag mode ON - grab the alert text and move it, then click the button again to lock.")
    end
end)

-- Reset Position
local resetBtn = MakeButton(panel, "Reset Position")
resetBtn:SetPoint("LEFT", dragBtn, "RIGHT", COL_GAP, 0)
resetBtn:SetScript("OnClick", function()
    if not (BSA and BSADB) then return end
    BSADB.point    = "TOP"
    BSADB.relPoint = "TOP"
    BSADB.x        = 0
    BSADB.y        = -160
    BSA.ApplySettings()
    -- if drag mode was active, exit it cleanly
    if dragging then
        dragging = false
        BSA.alertFrame:EnableMouse(false)
        BSA.alertFrame:SetScript("OnMouseDown", nil)
        BSA.alertFrame:SetScript("OnMouseUp",   nil)
        dragBtn:SetText("Drag to Reposition")
    end
    print("|cff00ccff[BSA]|r Position reset to default (top-centre).")
end)

MakeDivider(panel, -145)

-- ═══════════════════════════════════════════════════════════════
--  SECTION 2 — FONT SIZE
-- ═══════════════════════════════════════════════════════════════
MakeSectionHeader(panel, "Font Size", -150)

local sizeSlider = CreateFrame("Slider", "BSASizeSlider", panel, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L + 8, -172)
sizeSlider:SetWidth(320)
sizeSlider:SetMinMaxValues(18, 48)
sizeSlider:SetValueStep(1)
sizeSlider:SetObeyStepOnDrag(true)

-- Sub-labels created by OptionsSliderTemplate are accessible as globals
-- "SliderNameLow", "SliderNameHigh", "SliderNameText"
local sliderName = sizeSlider:GetName()
local sliderLow  = _G[sliderName .. "Low"]
local sliderHigh = _G[sliderName .. "High"]
local sliderText = _G[sliderName .. "Text"]
-- also try dot-access for newer WoW builds
sliderLow  = sliderLow  or sizeSlider.Low
sliderHigh = sliderHigh or sizeSlider.High
sliderText = sliderText or sizeSlider.Text
if sliderLow  then sliderLow:SetText("18pt")  end
if sliderHigh then sliderHigh:SetText("48pt")  end
if sliderText then sliderText:SetText("")      end   -- we show the value to the right instead

local sizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
sizeLabel:SetPoint("LEFT", sizeSlider, "RIGHT", 16, 0)
sizeLabel:SetTextColor(1, 0.82, 0, 1)

sizeSlider:SetScript("OnValueChanged", function(self, value, userInput)
    local v = math.floor(value + 0.5)
    sizeLabel:SetText(v .. "pt")
    if userInput and BSADB then
        BSADB.fontSize = v
        if BSA then BSA.ApplySettings() end
    end
end)

sizeSlider:SetValue(20)

MakeDivider(panel, -219)

-- ═══════════════════════════════════════════════════════════════
--  SECTION 3 — TEXT COLOR
-- ═══════════════════════════════════════════════════════════════
MakeSectionHeader(panel, "Text Color", -233)

-- Color definitions ordered as: Red, Orange, Yellow / White, Cyan, Green
local COLOR_ORDER = {
    { key = "RED",    label = "Red",    r = 1,   g = 0.1,  b = 0.1  },
    { key = "ORANGE", label = "Orange", r = 1,   g = 0.5,  b = 0    },
    { key = "YELLOW", label = "Yellow", r = 1,   g = 0.85, b = 0.1  },
    { key = "WHITE",  label = "White",  r = 1,   g = 1,    b = 1    },
    { key = "CYAN",   label = "Cyan",   r = 0,   g = 1,    b = 1    },
    { key = "GREEN",  label = "Green",  r = 0,   g = 1,    b = 0.2  },
}

local colorBtns = {}

for i, def in ipairs(COLOR_ORDER) do
    local col = (i - 1) % 3          -- 0, 1, 2
    local row = math.floor((i - 1) / 3)   -- 0 or 1

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(COLOR_BTN_W, COLOR_BTN_H)
    btn:SetPoint(
        "TOPLEFT", panel, "TOPLEFT",
        PAD_L + col * (COLOR_BTN_W + COL_GAP),
        -261 - row * (COLOR_BTN_H + 8)
    )
    btn:SetText(def.label)
    -- Tint the button label text with the colour itself
    btn:GetFontString():SetTextColor(def.r, def.g, def.b)

    btn:SetScript("OnClick", function()
        if not BSADB then return end
        BSADB.colorKey = def.key
        if BSA then BSA.ApplySettings() end
        -- Visual: underline the selected button by highlighting it
        for _, b in pairs(colorBtns) do
            b:SetAlpha(0.55)
        end
        btn:SetAlpha(1.0)
    end)

    colorBtns[def.key] = btn
end

-- ── Refresh UI when the panel becomes visible ─────────────────────────────
panel:SetScript("OnShow", function()
    if not BSADB then return end

    -- Sync slider
    sizeSlider:SetValue(BSADB.fontSize or 20)

    -- Sync colour button highlights
    for key, btn in pairs(colorBtns) do
        btn:SetAlpha(key == BSADB.colorKey and 1.0 or 0.55)
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  FOOTER — About / Links
-- ═══════════════════════════════════════════════════════════════
MakeDivider(panel, -335)

local FOOTER_Y = -349

local authorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
authorLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, FOOTER_Y)
authorLabel:SetTextColor(0.7, 0.7, 0.7, 1)
authorLabel:SetText("Author:  |cffffd700" .. AUTHOR .. "|r    Website:  |cffffd700" .. WEBSITE .. "|r")

local versionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
versionLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, FOOTER_Y - 22)
versionLabel:SetTextColor(0.7, 0.7, 0.7, 1)
versionLabel:SetText("Version:  |cffffd700" .. VERSION .. "|r    Built:  |cffffd700" .. TIMESTAMP .. "|r")

local repoLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
repoLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, FOOTER_Y - 44)
repoLabel:SetTextColor(0.7, 0.7, 0.7, 1)
repoLabel:SetText("Bugs & feature requests:  |cffffd700" .. REPO .. "|r")

-- ── Register with WoW's Settings system (12.x) ───────────────────────────
local category = Settings.RegisterCanvasLayoutCategory(panel, "BlisteringScalesAlert")
Settings.RegisterAddOnCategory(category)
BSA.settingsCategory = category

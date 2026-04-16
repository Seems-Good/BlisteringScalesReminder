-- ============================================================
-- BlisteringScalesAlert.lua
-- Core logic. Exposes the BSA namespace for Settings.lua.
-- ============================================================

BSA = BSA or {}   -- shared namespace; Settings.lua reads/writes this

local ADDON_NAME                 = "BlisteringScalesAlert"
local BLISTERING_SCALES_SPELL_ID = 360827
local AUG_SPEC_ID                = 1473

-- Default saved-variable values used when BSADB is absent or missing a key
local BSA_DEFAULTS = {
    fontSize  = 20,
    colorKey  = "RED",
    point     = "TOP",
    relPoint  = "TOP",
    x         = 0,
    y         = -160,
}

-- Color presets referenced by both this file and Settings.lua
BSA.COLORS = {
    RED    = { r = 1,   g = 0.1,  b = 0.1  },
    ORANGE = { r = 1,   g = 0.5,  b = 0    },
    YELLOW = { r = 1,   g = 0.85, b = 0.1  },
    WHITE  = { r = 1,   g = 1,    b = 1    },
    CYAN   = { r = 0,   g = 1,    b = 1    },
    GREEN  = { r = 0,   g = 1,    b = 0.2  },
}

local State = {
    isAugEvoker    = false,
    inCombat       = false,
    tankUnits      = {},
    tankCount      = 0,
    buffHolderUnit = nil,
    alertVisible   = false,
    checkCount     = 0,
    eventLog       = {},
}

-- ── Alert frame (invisible anchor; no background / border / icon) ─────────
local alertFrame = CreateFrame("Frame", "BSAAlertFrame", UIParent)
alertFrame:SetSize(500, 52)
alertFrame:SetMovable(true)
alertFrame:SetClampedToScreen(true)
alertFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)   -- overridden by ApplySettings on login
alertFrame:Hide()

local mainText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
mainText:SetPoint("TOP", alertFrame, "TOP", 0, 0)
mainText:SetJustifyH("CENTER")
mainText:SetTextColor(1, 0.1, 0.1, 1)
mainText:SetFont(mainText:GetFont(), 20, "OUTLINE, THICKOUTLINE")
mainText:SetText("BLISTERING SCALES MISSING")

local subText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
subText:SetPoint("TOP", alertFrame, "TOP", 0, -26)
subText:SetJustifyH("CENTER")
subText:SetTextColor(1, 1, 1, 1)
subText:SetFont(subText:GetFont(), 14, "OUTLINE")
subText:SetText("")

-- Expose to Settings.lua
BSA.alertFrame = alertFrame
BSA.mainText   = mainText
BSA.subText    = subText

-- ── DB helpers ────────────────────────────────────────────────────────────
function BSA.InitDB()
    if type(BSADB) ~= "table" then BSADB = {} end
    for k, v in pairs(BSA_DEFAULTS) do
        if BSADB[k] == nil then
            BSADB[k] = v
        end
    end
end

-- Apply current BSADB values to the live UI elements
function BSA.ApplySettings()
    local db = BSADB
    if not db then return end

    -- Font sizes  (subText tracks main at 70%, minimum 12)
    local mainFontPath = mainText:GetFont() or "Fonts\\FRIZQT__.TTF"
    local subFontPath  = subText:GetFont()  or "Fonts\\FRIZQT__.TTF"
    local mainSize     = db.fontSize or BSA_DEFAULTS.fontSize
    local subSize      = math.max(12, math.floor(mainSize * 0.70))

    mainText:SetFont(mainFontPath, mainSize, "OUTLINE, THICKOUTLINE")
    subText:SetFont(subFontPath,   subSize,  "OUTLINE")

    -- Reposition subText so it sits just below mainText regardless of size
    subText:ClearAllPoints()
    subText:SetPoint("TOP", alertFrame, "TOP", 0, -(mainSize + 4))

    -- Frame height grows with font
    alertFrame:SetHeight(mainSize + subSize + 12)

    -- Text color (mainText only; subText stays white for readability)
    local c = BSA.COLORS[db.colorKey] or BSA.COLORS.RED
    mainText:SetTextColor(c.r, c.g, c.b, 1)

    -- Screen position
    alertFrame:ClearAllPoints()
    alertFrame:SetPoint(
        db.point    or "TOP",
        UIParent,
        db.relPoint or "TOP",
        db.x        or 0,
        db.y        or -160
    )
end

-- Store the frame's current screen position back into BSADB
function BSA.SavePosition()
    if not BSADB then return end
    local point, _, relPoint, x, y = alertFrame:GetPoint(1)
    if not point then return end
    BSADB.point    = point
    BSADB.relPoint = relPoint
    BSADB.x        = math.floor(x + 0.5)
    BSADB.y        = math.floor(y + 0.5)
end

-- ── Internal helpers ──────────────────────────────────────────────────────
local function LogEvent(tag, detail)
    local log = State.eventLog
    local entry = string.format("[%.1f] %-22s %s", GetTime(), tag, detail or "")
    log[#log + 1] = entry
    if #log > 40 then table.remove(log, 1) end
end

local function ShowAlert()
    local names = {}
    for unit in pairs(State.tankUnits) do
        if UnitExists(unit) then
            names[#names + 1] = UnitName(unit) or unit
        end
    end
    table.sort(names)

    local label = #names > 0
        and ("Tank" .. (#names > 1 and "s" or "") .. ": " .. table.concat(names, ", "))
        or "No buff on any group tank"
    subText:SetText(label .. " — cast it now!")

    if not State.alertVisible then
        alertFrame:Show()
        State.alertVisible = true
        LogEvent("ALERT_SHOWN", label)
    end
end

local function HideAlert(reason)
    if State.alertVisible then
        alertFrame:Hide()
        State.alertVisible = false
        LogEvent("ALERT_HIDDEN", reason or "")
    end
end

local function RebuildTankList()
    local newUnits = {}
    local newCount = 0

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
                newUnits[unit] = true
                newCount = newCount + 1
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
                newUnits[unit] = true
                newCount = newCount + 1
            end
        end
        if UnitGroupRolesAssigned("player") == "TANK" then
            newUnits["player"] = true
            newCount = newCount + 1
        end
    end

    State.tankUnits = newUnits
    State.tankCount = newCount

    LogEvent("TANK_REBUILT",
        string.format("count=%d inRaid=%s inGroup=%s",
            State.tankCount,
            tostring(IsInRaid() and true or false),
            tostring(IsInGroup() and true or false)))
end

local function UnitHasBuffBySpellID(unit, spellID)
    if not UnitExists(unit) then return false end

    local slots = { C_UnitAuras.GetAuraSlots(unit, "HELPFUL") }
    if #slots == 0 then return false end

    for i = 2, #slots do
        local slot = slots[i]
        if slot then
            local data = C_UnitAuras.GetAuraDataBySlot(unit, slot)
            if data and data.spellId == spellID then
                return true
            end
        end
    end
    return false
end

local function FindBuffOnTank()
    for unit in pairs(State.tankUnits) do
        if UnitExists(unit) and not UnitIsDead(unit) then
            if UnitHasBuffBySpellID(unit, BLISTERING_SCALES_SPELL_ID) then
                return true, unit
            end
        end
    end
    return false, nil
end

local function CheckAndUpdate(trigger)
    State.checkCount = State.checkCount + 1

    if not State.isAugEvoker then
        State.buffHolderUnit = nil
        HideAlert("not aug evoker")
        return
    end

    if State.inCombat then
        State.buffHolderUnit = nil
        HideAlert("in combat")
        return
    end

    if State.tankCount == 0 then
        State.buffHolderUnit = nil
        HideAlert("no tanks in group")
        return
    end

    local hasBuff, holderUnit = FindBuffOnTank()
    State.buffHolderUnit = holderUnit

    LogEvent("CHECK",
        string.format("trigger=%-22s tanks=%d buff=%s holder=%s",
            tostring(trigger), State.tankCount,
            tostring(hasBuff), tostring(holderUnit)))

    if hasBuff then
        HideAlert("buff on " .. tostring(holderUnit))
    else
        ShowAlert()
    end
end

local function UpdateSpec()
    local idx = GetSpecialization()
    if not idx then
        State.isAugEvoker = false
        return
    end
    local specID = GetSpecializationInfo(idx)
    local prev = State.isAugEvoker
    State.isAugEvoker = (specID == AUG_SPEC_ID)
    if prev ~= State.isAugEvoker then
        LogEvent("SPEC_CHANGED", State.isAugEvoker and "Augmentation" or "other spec")
    end
end

local function IsTrackedTankUnit(unit)
    return unit and State.tankUnits[unit] == true
end

-- ── Event handler ─────────────────────────────────────────────────────────
local frame = CreateFrame("Frame", "BSAEventFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("ROLE_CHANGED_INFORM")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

frame:SetScript("OnEvent", function(_, event, arg1, arg2, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        print("|cff00ccff[BSA]|r Blistering Scales Alert loaded. Type |cffffd700/bsa|r for commands.")
        LogEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- DB must be initialised before anything else touches BSADB
        BSA.InitDB()
        BSA.ApplySettings()
        State.inCombat = UnitAffectingCombat("player") and true or false
        UpdateSpec()
        RebuildTankList()
        LogEvent("PLAYER_LOGIN",
            string.format("aug=%s combat=%s tanks=%d fontSize=%d color=%s",
                tostring(State.isAugEvoker),
                tostring(State.inCombat),
                State.tankCount,
                BSADB.fontSize,
                BSADB.colorKey))
        CheckAndUpdate("PLAYER_LOGIN")

    elseif event == "PLAYER_ENTERING_WORLD" then
        State.inCombat = UnitAffectingCombat("player") and true or false
        UpdateSpec()
        RebuildTankList()
        LogEvent("ENTERING_WORLD")
        CheckAndUpdate("ENTERING_WORLD")

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdateSpec()
        CheckAndUpdate("SPEC_CHANGED")

    elseif event == "PLAYER_REGEN_DISABLED" then
        State.inCombat = true
        LogEvent("COMBAT", "entered")
        HideAlert("combat started")

    elseif event == "PLAYER_REGEN_ENABLED" then
        State.inCombat = false
        LogEvent("COMBAT", "left")
        CheckAndUpdate("LEFT_COMBAT")

    elseif event == "GROUP_ROSTER_UPDATE" or event == "ROLE_CHANGED_INFORM" then
        LogEvent("ROSTER_UPDATE", event)
        RebuildTankList()
        CheckAndUpdate(event)

    elseif event == "UNIT_AURA" then
        local unit = arg1
        LogEvent("UNIT_AURA", tostring(unit))
        if IsTrackedTankUnit(unit) then
            CheckAndUpdate("UNIT_AURA:" .. tostring(unit))
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        LogEvent("TARGET_CHANGED", tostring(UnitName("target")))
        CheckAndUpdate("TARGET_CHANGED")

    elseif event == "PLAYER_FOCUS_CHANGED" then
        LogEvent("FOCUS_CHANGED", tostring(UnitName("focus")))
        CheckAndUpdate("FOCUS_CHANGED")

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = arg1, arg2, ...
        if unit == "player" and spellID == BLISTERING_SCALES_SPELL_ID then
            LogEvent("CAST_SUCCEEDED", "Blistering Scales")
            CheckAndUpdate("CAST_SUCCEEDED")
        end
    end
end)

-- ── Slash commands ────────────────────────────────────────────────────────
SLASH_BLISTERINGSCALESALERT1 = "/bsa"
SlashCmdList["BLISTERINGSCALESALERT"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "state" or cmd == "debug" then
        print("|cff00ccff[BSA] State dump:|r")
        print(string.format("  isAugEvoker    = %s", tostring(State.isAugEvoker)))
        print(string.format("  inCombat       = %s", tostring(State.inCombat)))
        print(string.format("  alertVisible   = %s", tostring(State.alertVisible)))
        print(string.format("  tankCount      = %d", State.tankCount))
        print(string.format("  buffHolderUnit = %s", tostring(State.buffHolderUnit)))
        print(string.format("  checkCount     = %d", State.checkCount))
        if BSADB then
            print(string.format("  fontSize       = %d", BSADB.fontSize or 0))
            print(string.format("  colorKey       = %s", BSADB.colorKey or "?"))
            print(string.format("  position       = %s/%s  x=%s  y=%s",
                tostring(BSADB.point), tostring(BSADB.relPoint),
                tostring(BSADB.x), tostring(BSADB.y)))
        end
        local idx = GetSpecialization()
        if idx then
            local sid, sname = GetSpecializationInfo(idx)
            print(string.format("  spec = %s (ID %s)", tostring(sname), tostring(sid)))
        else
            print("  spec = none")
        end
        print("  Tanks:")
        if State.tankCount == 0 then
            print("    (none detected)")
        else
            for unit in pairs(State.tankUnits) do
                local alive  = UnitExists(unit) and not UnitIsDead(unit)
                local hasBuff = alive and UnitHasBuffBySpellID(unit, BLISTERING_SCALES_SPELL_ID)
                print(string.format("    %-8s  %-22s  alive=%-5s  buff=%s",
                    unit,
                    UnitExists(unit) and (UnitName(unit) or "?") or "(gone)",
                    tostring(alive),
                    hasBuff and "|cff00ff00YES|r" or "|cffff4444NO|r"))
            end
        end

    elseif cmd == "log" then
        print("|cff00ccff[BSA] Event log:|r")
        if #State.eventLog == 0 then
            print("  (empty)")
        else
            for _, entry in ipairs(State.eventLog) do
                print("  " .. entry)
            end
        end

    elseif cmd == "check" then
        RebuildTankList()
        CheckAndUpdate("MANUAL_CHECK")
        print(string.format("|cff00ccff[BSA]|r Manual check. tanks=%d holder=%s alert=%s",
            State.tankCount,
            tostring(State.buffHolderUnit),
            tostring(State.alertVisible)))

    elseif cmd == "tanks" then
        RebuildTankList()
        print(string.format("|cff00ccff[BSA]|r %d tank(s) in group:", State.tankCount))
        for unit in pairs(State.tankUnits) do
            print(string.format("  %s → %s  [role=%s]",
                unit,
                UnitExists(unit) and (UnitName(unit) or "?") or "(missing)",
                UnitGroupRolesAssigned(unit) or "?"))
        end
        if State.tankCount == 0 then print("  (none)") end

    elseif cmd == "show" then
        State.alertVisible = false
        ShowAlert()
        print("|cff00ccff[BSA]|r Alert force-shown (UI test).")

    elseif cmd == "hide" then
        HideAlert("manual hide")
        print("|cff00ccff[BSA]|r Alert hidden.")

    elseif cmd == "spellid" then
        print(string.format("|cff00ccff[BSA]|r Watching spell ID %d.", BLISTERING_SCALES_SPELL_ID))
        local name = C_Spell.GetSpellName(BLISTERING_SCALES_SPELL_ID)
        print(string.format("  C_Spell.GetSpellName → %s", tostring(name)))

    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        Settings.OpenToCategory("BlisteringScalesAlert")

    else
        print("|cff00ccff[BSA]|r Commands:")
        print("  /bsa state    — full state + per-tank buff status")
        print("  /bsa log      — rolling event log (last 40 events)")
        print("  /bsa check    — force tank rescan + buff re-evaluate")
        print("  /bsa tanks    — list detected tanks and their roles")
        print("  /bsa show     — force alert visible (UI positioning test)")
        print("  /bsa hide     — hide alert")
        print("  /bsa spellid  — verify spell ID → name lookup")
        print("  /bsa settings — open the settings panel")
    end
end

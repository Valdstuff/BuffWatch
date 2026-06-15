-- BuffWatch.lua | Author: Valdstein | WotLK 3.3.5a
-- Tracks self-buffs and weapon enchants. /bw toggles, /bw config opens settings.

local ADDON_NAME = "BuffWatch"

local ICON_SIZE = 30
local ICON_PAD  = 3
local BG_PAD    = 5

local TRACKED = {
    { spell = "Power Word: Fortitude" },
    { spell = "Power Word: Shield"    },
    { spell = "Inner Fire"            },
    { spell = "Demon Skin", upgradedBy = "Demon Armor" },
    { spell = "Demon Armor"           },
    { spell = "Fel Armor"             },
    { spell = "Frost Armor", upgradedBy = "Ice Armor" },
    { spell = "Ice Armor"             },
    { spell = "Mage Armor"            },
    { spell = "Molten Armor"          },
    { spell = "Water Shield"          },
    { spell = "Lightning Shield"      },
    { spell = "Mark of the Wild"      },
    { spell = "Thorns"                },
    { spell = "Devotion Aura"         },
    { spell = "Righteous Fury"        },
    { spell = "Blessing of Might"     },
    { spell = "Blessing of Kings"     },
    { spell = "Blessing of Wisdom"    },
    { spell = "Seal of Righteousness", group = "seal" },
    { spell = "Seal of Wisdom",        group = "seal" },
    { spell = "Seal of Light",         group = "seal" },
    { spell = "Seal of Justice",       group = "seal" },
    { spell = "Seal of Command",       group = "seal" },
    { spell = "Seal of Vengeance",     group = "seal" },
    { spell = "Seal of Corruption",    group = "seal" },
    { spell = "Seal of the Martyr",    group = "seal" },
    { spell = "Blood Presence",  group = "presence" },
    { spell = "Frost Presence",  group = "presence" },
    { spell = "Unholy Presence", group = "presence" },
    { spell = "Windfury Weapon",     weapon = true },
    { spell = "Frostbrand Weapon",   weapon = true },
    { spell = "Flametongue Weapon",  weapon = true },
    { spell = "Rockbiter Weapon",    weapon = true },
    { spell = "Instant Poison",      weapon = true, prefix = true },
    { spell = "Deadly Poison",       weapon = true, prefix = true },
    { spell = "Crippling Poison",    weapon = true, prefix = true },
    { spell = "Mind-numbing Poison", weapon = true, prefix = true },
}

for _, t in ipairs(TRACKED) do
    if not t.buff then t.buff = t.spell end
    -- Weapon tooltips read "Windfury", not "Windfury Weapon".
    if t.weapon and not t.match then
        t.match = (t.spell:gsub(" Weapon$", "")):lower()
    end
end

local knownSpells = {}
local knownSlot   = {}
local activeBuffs = {}
local visButtons  = {}
local allButtons  = {}

local weaponEnchant = { main = "", off = "" }
local haveWeaponEntries = false

local DB_DEFAULTS = {
    locked = false, hidden = false, scale = 1.0, opacity = 0.85, vertical = false,
}

local function EnsureDB()
    if type(BuffWatchDB) ~= "table" then BuffWatchDB = {} end
    for k, v in pairs(DB_DEFAULTS) do
        if type(BuffWatchDB[k]) ~= type(v) then BuffWatchDB[k] = v end
    end
end

local function RebuildKnownSpells()
    wipe(knownSpells)
    wipe(knownSlot)
    local numTabs = GetNumSpellTabs()
    for t = 1, numTabs do
        local _, _, offset, count = GetSpellTabInfo(t)
        for i = offset + 1, offset + count do
            local name = GetSpellName(i, BOOKTYPE_SPELL)
            if name and not knownSpells[name] then
                local icon = GetSpellTexture(i, BOOKTYPE_SPELL)
                knownSpells[name] = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                knownSlot[name]   = i
            end
        end
    end
end

-- activeBuffs maps buff name -> absolute expiration time, or 0 for no duration.
local function RebuildActiveBuffs()
    wipe(activeBuffs)
    for i = 1, 40 do
        local name, _, _, _, _, _, expirationTime = UnitBuff("player", i)
        if not name then break end
        activeBuffs[name] = expirationTime or 0
    end
end

local scanTip = CreateFrame("GameTooltip", "BuffWatchScanTooltip", UIParent,
    "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local tipName = scanTip:GetName()
local function ReadEnchantText(slot)
    -- The owner MUST be re-set before each scan, or a hidden tooltip returns
    -- no lines on later calls.
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    local hasItem = scanTip:SetInventoryItem("player", slot)
    local n = scanTip:NumLines()
    local text = ""
    for i = 1, n do
        local fs = _G[tipName .. "TextLeft" .. i]
        local s  = fs and fs:GetText()
        if s then text = text .. s .. "\n" end
    end
    return text:lower(), hasItem, n
end

-- Match the imbue/poison name in the weapon tooltip directly; GetWeaponEnchantInfo
-- is unreliable on some custom servers. Slots: 16 = main hand, 17 = off hand.
local function RebuildWeaponEnchants()
    weaponEnchant.main = ReadEnchantText(16)
    weaponEnchant.off  = ReadEnchantText(17)
end

local ENCHANTABLE_SLOT = {
    INVTYPE_WEAPON         = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND  = true,
    INVTYPE_2HWEAPON       = true,
}

local function IsEnchantableWeapon(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return false end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    return ENCHANTABLE_SLOT[equipLoc] == true
end

-- True if any equipped, enchantable weapon is missing its enchant.
local function WeaponEnchantNeeded()
    local hasMain, _, _, hasOff = GetWeaponEnchantInfo()
    if IsEnchantableWeapon(16) and not hasMain then return true end
    if IsEnchantableWeapon(17) and not hasOff  then return true end
    return false
end

-- Returns active (boolean), expiry (absolute GetTime, or nil if no timer).
local function GetBuffState(entry)
    if entry.weapon then
        local m = entry.match
        local onMain = weaponEnchant.main:find(m, 1, true) ~= nil
        local onOff  = weaponEnchant.off:find(m, 1, true) ~= nil
        if not (onMain or onOff) then return false, nil end
        local _, mainMs, _, _, offMs = GetWeaponEnchantInfo()
        local now, expiry = GetTime(), nil
        if onMain and mainMs then expiry = now + mainMs / 1000 end
        if onOff and offMs then
            local oe = now + offMs / 1000
            if not expiry or oe < expiry then expiry = oe end
        end
        return true, expiry
    end

    if not entry.prefix then
        local exp = activeBuffs[entry.buff]
        if exp == nil then return false, nil end
        return true, (exp ~= 0 and exp or nil)
    end
    -- Prefix match: "Instant Poison" matches "Instant Poison IX".
    local prefix = entry.buff
    local plen   = #prefix
    for name, exp in pairs(activeBuffs) do
        if #name >= plen and name:sub(1, plen) == prefix then
            return true, (exp ~= 0 and exp or nil)
        end
    end
    return false, nil
end

local function FormatTime(t)
    if t >= 3600 then
        return math.floor(t / 3600) .. "h"
    elseif t >= 60 then
        return math.floor(t / 60) .. "m"
    else
        return math.floor(t) .. "s"
    end
end

local mainFrame = CreateFrame("Frame", "BuffWatchFrame", UIParent)
mainFrame:SetFrameStrata("MEDIUM")
mainFrame:SetClampedToScreen(true)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
})
mainFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
mainFrame:SetBackdropBorderColor(0, 0, 0, 1)

mainFrame:SetScript("OnDragStart", function(self)
    if not BuffWatchDB.locked then self:StartMoving() end
end)
mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    BuffWatchDB.x = self:GetLeft()
    BuffWatchDB.y = self:GetBottom()
end)

local function ApplyPosition()
    mainFrame:ClearAllPoints()
    if BuffWatchDB.x and BuffWatchDB.y then
        mainFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
            BuffWatchDB.x, BuffWatchDB.y)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

local function ApplyVisuals()
    mainFrame:SetScale(BuffWatchDB.scale or 1.0)
    mainFrame:SetBackdropColor(0.06, 0.06, 0.06, BuffWatchDB.opacity or 0.85)
end

-- Forward declaration; assigned before InitButtons runs (from ADDON_LOADED).
local OpenConfig

local function InitButtons()
    for i, entry in ipairs(TRACKED) do
        if not allButtons[i] then
            -- Casting is protected in 3.3.5a; it must be driven by attributes on
            -- a SecureActionButtonTemplate, not a plain OnClick.
            local btn = CreateFrame("Button", "BuffWatchButton" .. i, mainFrame,
                "SecureActionButtonTemplate")
            btn:SetSize(ICON_SIZE, ICON_SIZE)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            if entry.weapon then
                -- /use <slot> applies the imbue/poison to a hand with no
                -- targeting cursor: left = main hand (16), right = off hand (17).
                btn:SetAttribute("type1", "macro")
                btn:SetAttribute("macrotext1", "/cast " .. entry.spell .. "\n/use 16")
                btn:SetAttribute("type2", "macro")
                btn:SetAttribute("macrotext2", "/cast " .. entry.spell .. "\n/use 17")
            else
                btn:SetAttribute("type1", "spell")
                btn:SetAttribute("spell1", entry.spell)
            end

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints()
            btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            btn.overlay = btn:CreateTexture(nil, "OVERLAY")
            btn.overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
            btn.overlay:SetAllPoints()
            btn.overlay:SetVertexColor(0, 0, 0, 0.65)

            -- Pulsing ring (alpha pulsed in OnUpdate) around buffs needing reapply.
            btn.glow = CreateFrame("Frame", nil, btn)
            btn.glow:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -2,  2)
            btn.glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  2, -2)
            btn.glow:SetFrameLevel(btn:GetFrameLevel() + 4)
            btn.glow:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 3,
            })
            btn.glow:SetBackdropBorderColor(0.55, 0.0, 0.0, 1)
            btn.glow:Hide()

            btn.timer = btn:CreateFontString(nil, "OVERLAY")
            btn.timer:SetDrawLayer("OVERLAY", 8)
            btn.timer:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            btn.timer:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
            btn.timer:SetText("")

            btn.infinity = btn:CreateFontString(nil, "OVERLAY")
            btn.infinity:SetDrawLayer("OVERLAY", 8)
            btn.infinity:SetFont("Fonts\\FRIZQT__.TTF", 33, "OUTLINE")
            btn.infinity:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.infinity:SetTextColor(0.8, 0.8, 0.8, 1)
            btn.infinity:SetText("")

            btn._entry = entry

            btn:SetScript("OnEnter", function(self)
                local e = self._entry
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local slot = knownSlot[e.spell]
                if slot then
                    GameTooltip:SetSpell(slot, BOOKTYPE_SPELL)
                else
                    GameTooltip:SetText("|cffffd100" .. e.spell .. "|r")
                end
                if e.weapon then
                    if self._needs then
                        GameTooltip:AddLine("Needs applying", 1, 0.25, 0.25)
                        GameTooltip:AddLine("Left-click: main hand", 0.67, 0.67, 0.67)
                        GameTooltip:AddLine("Right-click: off hand", 0.67, 0.67, 0.67)
                    else
                        GameTooltip:AddLine("Applied", 0.27, 1, 0.27)
                    end
                elseif self._active then
                    GameTooltip:AddLine("Active", 0.27, 1, 0.27)
                elseif self._needs then
                    GameTooltip:AddLine("Missing - click to cast", 1, 0.25, 0.25)
                else
                    GameTooltip:AddLine("Not needed", 0.67, 0.67, 0.67)
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btn:Hide()
            allButtons[i] = btn
        end
    end
end

-- Showing/hiding/moving secure buttons is forbidden in combat; defer if needed.
local layoutPending = false

local function LayoutButtons()
    if InCombatLockdown() then
        layoutPending = true
        return
    end
    wipe(visButtons)
    haveWeaponEntries = false
    local vertical = BuffWatchDB.vertical
    local offset = BG_PAD
    for i, entry in ipairs(TRACKED) do
        local btn  = allButtons[i]
        local icon = knownSpells[entry.spell]
        -- Hide a base spell when its upgrade is also learned.
        if entry.upgradedBy and knownSpells[entry.upgradedBy] then
            icon = nil
        end
        if icon then
            btn.icon:SetTexture(icon)
            btn:ClearAllPoints()
            if vertical then
                btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", BG_PAD, -offset)
            else
                btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", offset, -BG_PAD)
            end
            btn:Show()
            visButtons[#visButtons + 1] = btn
            offset = offset + ICON_SIZE + ICON_PAD
            if entry.weapon then haveWeaponEntries = true end
        else
            btn:Hide()
        end
    end

    local n    = #visButtons
    local long = n > 0
        and (n * (ICON_SIZE + ICON_PAD) - ICON_PAD + BG_PAD * 2)
        or  (ICON_SIZE + BG_PAD * 2)
    local short = ICON_SIZE + BG_PAD * 2
    if vertical then
        mainFrame:SetSize(short, long)
    else
        mainFrame:SetSize(long, short)
    end
end

local groupActive = {}

-- UTF-8 bytes for U+221E (infinity). Swap for a texture if the font lacks it.
local INFINITY = "\226\136\158"

local function RefreshStates()
    wipe(groupActive)
    for _, btn in ipairs(visButtons) do
        local active, expiry = GetBuffState(btn._entry)
        btn._active = active
        btn._expiry = expiry
        if active and btn._entry.group then
            groupActive[btn._entry.group] = true
        end
    end

    -- Weapon icons stop needing attention once every equipped weapon is enchanted.
    local weaponSatisfied = (not haveWeaponEntries) or (not WeaponEnchantNeeded())

    for _, btn in ipairs(visButtons) do
        local entry  = btn._entry
        local active = btn._active

        local needs
        if entry.weapon then
            -- Keep glowing until EVERY equipped weapon is enchanted, even if this
            -- imbue is already on one hand (it may be wanted on both).
            needs = not weaponSatisfied
        elseif entry.group then
            needs = (not active) and (not groupActive[entry.group])
        else
            needs = not active
        end
        btn._needs = needs

        if active and btn._expiry then
            btn._showTimer = true
            btn.infinity:SetText("")
        elseif active then
            btn._showTimer = false
            btn.timer:SetText("")
            btn.infinity:SetText(INFINITY)
        else
            btn._showTimer = false
            btn.timer:SetText("")
            btn.infinity:SetText("")
        end

        if needs then
            btn.icon:SetDesaturated(false)
            btn.overlay:Hide()
            btn.glow:Show()
            btn._glow = true
        else
            btn.icon:SetDesaturated(true)
            btn.overlay:Show()
            btn.glow:Hide()
            btn._glow = false
        end
    end
end

local function RebuildEverything()
    RebuildKnownSpells()
    RebuildActiveBuffs()
    RebuildWeaponEnchants()
    LayoutButtons()
    RefreshStates()
end

-- Weapon imbues/poisons do not fire UNIT_AURA, so re-scan on a light throttle.
local pulseT, scanT, timerT = 0, 0, 0
mainFrame:SetScript("OnUpdate", function(self, elapsed)
    pulseT = pulseT + elapsed
    local a = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(pulseT * 4))
    for _, btn in ipairs(visButtons) do
        if btn._glow then btn.glow:SetAlpha(a) end
    end

    timerT = timerT + elapsed
    if timerT >= 0.1 then
        timerT = 0
        local now = GetTime()
        for _, btn in ipairs(visButtons) do
            if btn._showTimer and btn._expiry then
                local rem = btn._expiry - now
                if rem < 0 then rem = 0 end
                btn.timer:SetText(FormatTime(rem))
                if rem <= 10 then
                    btn.timer:SetTextColor(1, 0.2, 0.2)
                elseif rem <= 60 then
                    btn.timer:SetTextColor(1, 0.85, 0.1)
                else
                    btn.timer:SetTextColor(1, 1, 1)
                end
            end
        end
    end

    scanT = scanT + elapsed
    if scanT >= 0.5 then
        scanT = 0
        if haveWeaponEntries then
            RebuildWeaponEnchants()
            RefreshStates()
        end
    end
end)

local configPanel

local function BuildConfigPanel()
    if configPanel then return end

    local PW, PH = 260, 224

    configPanel = CreateFrame("Frame", "BuffWatchConfigFrame", UIParent)
    configPanel:SetSize(PW, PH)
    configPanel:SetPoint("CENTER")
    configPanel:SetFrameStrata("DIALOG")
    configPanel:SetToplevel(true)
    configPanel:SetClampedToScreen(true)
    configPanel:SetMovable(true)
    configPanel:EnableMouse(true)
    configPanel:RegisterForDrag("LeftButton")
    configPanel:SetScript("OnDragStart", configPanel.StartMoving)
    configPanel:SetScript("OnDragStop",  configPanel.StopMovingOrSizing)
    configPanel:Hide()

    configPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    configPanel:SetBackdropColor(0, 0, 0, 1.0)

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    title:SetText("BuffWatch")
    title:SetTextColor(1, 0.82, 0, 1)

    local closeBtn = CreateFrame("Button", nil, configPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local sep = configPanel:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(1, 0.82, 0, 0.25)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  configPanel, "TOPLEFT",  14, -36)
    sep:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -14, -36)

    local SW = PW - 36

    local function MakeSlider(yTop, initLabel, minV, maxV, step, loText, hiText, onChange)
        local lbl = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", 18, yTop)
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        lbl:SetTextColor(1, 0.82, 0, 1)
        lbl:SetText(initLabel)

        local sl = CreateFrame("Slider", nil, configPanel)
        sl:SetOrientation("HORIZONTAL")
        sl:SetHeight(16)
        sl:SetWidth(SW)
        sl:SetPoint("TOPLEFT", 18, yTop - 18)
        sl:SetMinMaxValues(minV, maxV)
        sl:SetValueStep(step)

        local track = sl:CreateTexture(nil, "BACKGROUND")
        track:SetTexture("Interface\\Buttons\\WHITE8X8")
        track:SetPoint("TOPLEFT",     sl, "TOPLEFT",     0, -6)
        track:SetPoint("BOTTOMRIGHT", sl, "BOTTOMRIGHT", 0,  6)
        track:SetGradientAlpha("VERTICAL", 0.78, 0.80, 0.86, 1, 0.36, 0.38, 0.44, 1)

        local thumb = sl:CreateTexture(nil, "OVERLAY")
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        thumb:SetSize(32, 18)
        sl:SetThumbTexture(thumb)

        local loFs = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        loFs:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 0, -2)
        loFs:SetText(loText)
        loFs:SetTextColor(0.6, 0.6, 0.6, 1)

        local hiFs = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hiFs:SetPoint("TOPRIGHT", sl, "BOTTOMRIGHT", 0, -2)
        hiFs:SetText(hiText)
        hiFs:SetTextColor(0.6, 0.6, 0.6, 1)

        sl._lbl = lbl
        sl:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v / step + 0.5) * step
            onChange(v, lbl)
        end)
        return sl
    end

    configPanel.scaleSlider = MakeSlider(-50, "Scale: 1.00x", 0.5, 2.0, 0.05,
        "0.5x", "2.0x",
        function(v, lbl)
            EnsureDB()
            BuffWatchDB.scale = v
            mainFrame:SetScale(v)
            lbl:SetText(string.format("Scale: %.2fx", v))
        end)

    configPanel.opSlider = MakeSlider(-106, "Opacity: 85%", 0, 100, 1,
        "0%", "100%",
        function(v, lbl)
            EnsureDB()
            BuffWatchDB.opacity = v / 100
            mainFrame:SetBackdropColor(0.06, 0.06, 0.06, v / 100)
            lbl:SetText(string.format("Opacity: %d%%", v))
        end)

    local lockCB = CreateFrame("CheckButton", "BuffWatchLockCB", configPanel,
        "UICheckButtonTemplate")
    lockCB:SetPoint("TOPLEFT", 14, -158)
    lockCB:SetSize(24, 24)
    local lockLbl = lockCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockLbl:SetPoint("LEFT", lockCB, "RIGHT", 4, 0)
    lockLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    lockLbl:SetText("Lock window position")
    lockCB:SetScript("OnClick", function(self)
        EnsureDB()
        BuffWatchDB.locked = self:GetChecked() and true or false
    end)
    configPanel.lockCB = lockCB

    local vertCB = CreateFrame("CheckButton", "BuffWatchVertCB", configPanel,
        "UICheckButtonTemplate")
    vertCB:SetPoint("TOPLEFT", 14, -186)
    vertCB:SetSize(24, 24)
    local vertLbl = vertCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vertLbl:SetPoint("LEFT", vertCB, "RIGHT", 4, 0)
    vertLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    vertLbl:SetText("Vertical layout")
    vertCB:SetScript("OnClick", function(self)
        EnsureDB()
        BuffWatchDB.vertical = self:GetChecked() and true or false
        LayoutButtons()
        RefreshStates()
    end)
    configPanel.vertCB = vertCB

    tinsert(UISpecialFrames, "BuffWatchConfigFrame")
end

OpenConfig = function()
    BuildConfigPanel()
    if configPanel:IsShown() then
        configPanel:Hide()
        return
    end
    EnsureDB()
    configPanel.scaleSlider:SetValue(BuffWatchDB.scale or 1.0)
    configPanel.opSlider:SetValue(
        math.floor((BuffWatchDB.opacity or 0.85) * 100 + 0.5))
    configPanel.lockCB:SetChecked(BuffWatchDB.locked and 1 or nil)
    configPanel.vertCB:SetChecked(BuffWatchDB.vertical and 1 or nil)
    configPanel:Show()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        EnsureDB()
        ApplyPosition()
        ApplyVisuals()
        InitButtons()
        RebuildEverything()
        if BuffWatchDB.hidden then mainFrame:Hide() end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        RebuildEverything()
        return
    end

    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then
        RebuildKnownSpells()
        LayoutButtons()
        RefreshStates()
        return
    end

    if event == "UNIT_AURA" and arg1 == "player" then
        RebuildActiveBuffs()
        RefreshStates()
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" and (arg1 == "player" or arg1 == nil) then
        RebuildWeaponEnchants()
        RefreshStates()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if layoutPending then
            layoutPending = false
            LayoutButtons()
            RefreshStates()
        end
        return
    end
end)

SLASH_BUFFWATCH1 = "/buffwatch"
SLASH_BUFFWATCH2 = "/bw"
SlashCmdList["BUFFWATCH"] = function(msg)
    local m = (msg or ""):lower():match("^%s*(.-)%s*$")
    if m == "config" then
        OpenConfig()
    elseif m == "debug" then
        local hasM, _, _, hasO = GetWeaponEnchantInfo()
        local t16, item16, n16 = ReadEnchantText(16)
        local t17, item17, n17 = ReadEnchantText(17)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100BuffWatch debug|r")
        DEFAULT_CHAT_FRAME:AddMessage("  GetWeaponEnchantInfo main=" ..
            tostring(hasM) .. " off=" .. tostring(hasO))
        DEFAULT_CHAT_FRAME:AddMessage("  main-hand: hasItem=" .. tostring(item16) ..
            " lines=" .. tostring(n16))
        DEFAULT_CHAT_FRAME:AddMessage("    " .. (t16:gsub("\n", " | ")))
        DEFAULT_CHAT_FRAME:AddMessage("  off-hand: hasItem=" .. tostring(item17) ..
            " lines=" .. tostring(n17))
        DEFAULT_CHAT_FRAME:AddMessage("    " .. (t17:gsub("\n", " | ")))
    else
        EnsureDB()
        if mainFrame:IsShown() then
            mainFrame:Hide()
            BuffWatchDB.hidden = true
        else
            mainFrame:Show()
            BuffWatchDB.hidden = false
        end
    end
end

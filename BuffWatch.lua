-- BuffWatch.lua | Author: Valdstein | WotLK 3.3.5a
-- Tracks self-buffs and weapon enchants. /bw toggles, /bw config opens settings.

local ADDON_NAME = "BuffWatch"

local ICON_SIZE = 30
local ICON_PAD  = 3
local BG_PAD    = 5

local TRACKED = {
    { spell = "Power Word: Fortitude", id = 1243, class = "Priest" },
    { spell = "Power Word: Shield", id = 17,    class = "Priest" },
    { spell = "Inner Fire", id = 588,            class = "Priest" },
    { spell = "Demon Skin", id = 687, upgradedBy = "Demon Armor", class = "Warlock" },
    { spell = "Demon Armor", id = 706,           class = "Warlock" },
    { spell = "Fel Armor", id = 28176,             class = "Warlock" },
    { spell = "Frost Armor", id = 168, upgradedBy = "Ice Armor", class = "Mage" },
    { spell = "Ice Armor", id = 7302,             class = "Mage" },
    { spell = "Mage Armor", id = 6117,            class = "Mage" },
    { spell = "Molten Armor", id = 30482,          class = "Mage" },
    { spell = "Water Shield", id = 24398,          class = "Shaman" },
    { spell = "Lightning Shield", id = 324,      class = "Shaman" },
    { spell = "Mark of the Wild", id = 1126,      class = "Druid" },
    { spell = "Thorns", id = 467,                class = "Druid" },
    { spell = "Aspect of the Hawk",       id = 13165, group = "aspect", class = "Hunter" },
    { spell = "Aspect of the Dragonhawk", id = 61846, group = "aspect", class = "Hunter" },
    { spell = "Aspect of the Monkey",     id = 13163, group = "aspect", class = "Hunter" },
    { spell = "Aspect of the Cheetah",    id = 5118,  group = "aspect", class = "Hunter" },
    { spell = "Aspect of the Pack",       id = 13159, group = "aspect", class = "Hunter" },
    { spell = "Aspect of the Beast",      id = 13161, group = "aspect", class = "Hunter" },
    { spell = "Aspect of the Wild",       id = 20043, group = "aspect", class = "Hunter" },
    { spell = "Aspect of the Viper",      id = 34074, group = "aspect", class = "Hunter" },
    { spell = "Devotion Aura", id = 465,         class = "Paladin" },
    { spell = "Righteous Fury", id = 25780,        class = "Paladin" },
    { spell = "Blessing of Might", id = 19740,     class = "Paladin" },
    { spell = "Blessing of Kings", id = 20217,     class = "Paladin" },
    { spell = "Blessing of Wisdom", id = 19742,    class = "Paladin" },
    { spell = "Seal of Righteousness", id = 21084, group = "seal", class = "Paladin" },
    { spell = "Seal of Wisdom", id = 20166,        group = "seal", class = "Paladin" },
    { spell = "Seal of Light", id = 20165,         group = "seal", class = "Paladin" },
    { spell = "Seal of Justice", id = 20164,       group = "seal", class = "Paladin" },
    { spell = "Seal of Command", id = 20375,       group = "seal", class = "Paladin" },
    { spell = "Seal of Vengeance",  id = 31801, group = "seal", class = "Paladin", toggleKey = "seal_vc", toggleLabel = "Seal of Vengeance / Corruption" },
    { spell = "Seal of Corruption", id = 53736, group = "seal", class = "Paladin", toggleKey = "seal_vc", toggleLabel = "Seal of Vengeance / Corruption" },
    { spell = "Seal of the Martyr", id = 53720, group = "seal", class = "Paladin", toggleKey = "seal_mb", toggleLabel = "Seal of the Martyr / Blood" },
    { spell = "Seal of Blood",      id = 31892, group = "seal", class = "Paladin", toggleKey = "seal_mb", toggleLabel = "Seal of the Martyr / Blood" },
    { spell = "Blood Presence", id = 48263,  group = "presence", class = "Death Knight" },
    { spell = "Frost Presence", id = 48266,  group = "presence", class = "Death Knight" },
    { spell = "Unholy Presence", id = 48265, group = "presence", class = "Death Knight" },
    { spell = "Windfury Weapon", id = 8232,     weapon = true, class = "Shaman" },
    { spell = "Frostbrand Weapon", id = 8033,   weapon = true, class = "Shaman" },
    { spell = "Flametongue Weapon", id = 8024,  weapon = true, class = "Shaman" },
    { spell = "Rockbiter Weapon", id = 8017,    weapon = true, class = "Shaman" },
    { spell = "Instant Poison", id = 8679,      weapon = true, prefix = true, class = "Rogue" },
    { spell = "Deadly Poison", id = 2823,       weapon = true, prefix = true, class = "Rogue" },
    { spell = "Crippling Poison", id = 3408,    weapon = true, prefix = true, class = "Rogue" },
    { spell = "Mind-numbing Poison", id = 5761, weapon = true, prefix = true, class = "Rogue" },
}

-- Classes listed alphabetically in the config sidebar.
local CLASS_ORDER = {
    "Death Knight", "Druid", "Hunter", "Mage", "Paladin",
    "Priest", "Rogue", "Shaman", "Warlock",
}

-- Classes temporarily hidden from the bar and the config sidebar. The
-- data and code stay intact; clear an entry to re-enable it.
local DISABLED_CLASSES = { ["Rogue"] = true }

-- class name -> ordered list of its TRACKED entries (built after the loop below).
local CLASS_BUFFS = {}

for _, t in ipairs(TRACKED) do
    if not t.buff then t.buff = t.spell end
    -- Weapon tooltips read "Windfury", not "Windfury Weapon".
    if t.weapon and not t.match then
        t.match = (t.spell:gsub(" Weapon$", "")):lower()
    end
    if t.class then
        CLASS_BUFFS[t.class] = CLASS_BUFFS[t.class] or {}
        CLASS_BUFFS[t.class][#CLASS_BUFFS[t.class] + 1] = t
    end
end

local knownSpells = {}
local knownSlot   = {}
local activeBuffs = {}
local visButtons  = {}
local allButtons  = {}
local playerClass        -- englishClass token, e.g. "ROGUE"; set in RebuildKnownSpells

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
    -- hiddenBuffs[spellName] = true means the user toggled that buff off.
    if type(BuffWatchDB.hiddenBuffs) ~= "table" then BuffWatchDB.hiddenBuffs = {} end
end

local function RebuildKnownSpells()
    wipe(knownSpells)
    wipe(knownSlot)
    local _, c = UnitClass("player"); playerClass = c
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
                -- Shaman imbues are cast spells; rogue poisons are consumable
                -- items. Either way we finish with "/use <slot>" to apply to a
                -- hand: left = main hand (16), right = off hand (17).
                local verb = entry.prefix and "/use " or "/cast "
                btn:SetAttribute("type1", "macro")
                btn:SetAttribute("macrotext1", verb .. entry.spell .. "\n/use 16")
                btn:SetAttribute("type2", "macro")
                btn:SetAttribute("macrotext2", verb .. entry.spell .. "\n/use 17")
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
        -- Poisons are consumable items, not spellbook spells, so the
        -- spellbook scan never finds them. Show them for Rogues and take
        -- the icon from the spell database by ID.
        if entry.prefix then
            if playerClass == "ROGUE" and entry.id then
                icon = select(3, GetSpellInfo(entry.id))
            else
                icon = nil
            end
        end
        -- Temporarily disabled classes (e.g. Rogue poisons) are hidden.
        if entry.class and DISABLED_CLASSES[entry.class] then
            icon = nil
        end
        -- Hide a base spell when its upgrade is also learned.
        if entry.upgradedBy and knownSpells[entry.upgradedBy] then
            icon = nil
        end
        -- Respect the user's per-buff visibility toggle from the config panel.
        -- Paired buffs (e.g. Seal of Vengeance/Corruption) share a toggle key.
        if BuffWatchDB.hiddenBuffs
            and BuffWatchDB.hiddenBuffs[entry.toggleKey or entry.spell] then
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

local GOLD = { 1, 0.82, 0 }

local function BuildConfigPanel()
    if configPanel then return end

    local PW, PH      = 440, 420
    local SIDEBAR_W   = 120  -- left category column width
    local CONTENT_X   = SIDEBAR_W + 10
    local CONTENT_TOP = -44

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
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)

    local closeBtn = CreateFrame("Button", nil, configPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    -- Horizontal rule under the title.
    local sep = configPanel:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.25)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  configPanel, "TOPLEFT",  14, -36)
    sep:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -14, -36)

    -- Vertical rule dividing the sidebar from the content area.
    local vsep = configPanel:CreateTexture(nil, "ARTWORK")
    vsep:SetTexture("Interface\\Buttons\\WHITE8X8")
    vsep:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.25)
    vsep:SetWidth(1)
    vsep:SetPoint("TOPLEFT",    configPanel, "TOPLEFT",    SIDEBAR_W, -40)
    vsep:SetPoint("BOTTOMLEFT", configPanel, "BOTTOMLEFT", SIDEBAR_W,  12)

    --------------------------------------------------------------------------
    -- Right-side content containers (only one shown at a time).
    --------------------------------------------------------------------------
    local function MakeContainer()
        local c = CreateFrame("Frame", nil, configPanel)
        c:SetPoint("TOPLEFT",     configPanel, "TOPLEFT",     CONTENT_X, CONTENT_TOP)
        c:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -12, 12)
        return c
    end

    local configContainer = MakeContainer()
    local buffContainer   = MakeContainer()
    buffContainer:Hide()

    --------------------------------------------------------------------------
    -- Configuration view: display settings (scale, opacity, lock, layout).
    --------------------------------------------------------------------------
    local cfgHeader = configContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cfgHeader:SetPoint("TOPLEFT", 0, -2)
    cfgHeader:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    cfgHeader:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
    cfgHeader:SetText("Display Settings")

    local SW = PW - CONTENT_X - 24

    local function MakeSlider(yTop, initLabel, minV, maxV, step, loText, hiText, onChange)
        local lbl = configContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", 0, yTop)
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        lbl:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
        lbl:SetText(initLabel)

        local sl = CreateFrame("Slider", nil, configContainer)
        sl:SetOrientation("HORIZONTAL")
        sl:SetHeight(16)
        sl:SetWidth(SW)
        sl:SetPoint("TOPLEFT", 0, yTop - 18)
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

        local loFs = configContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        loFs:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 0, -2)
        loFs:SetText(loText)
        loFs:SetTextColor(0.6, 0.6, 0.6, 1)

        local hiFs = configContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

    configPanel.scaleSlider = MakeSlider(-34, "Scale: 1.00x", 0.5, 2.0, 0.05,
        "0.5x", "2.0x",
        function(v, lbl)
            EnsureDB()
            BuffWatchDB.scale = v
            mainFrame:SetScale(v)
            lbl:SetText(string.format("Scale: %.2fx", v))
        end)

    configPanel.opSlider = MakeSlider(-90, "Opacity: 85%", 0, 100, 1,
        "0%", "100%",
        function(v, lbl)
            EnsureDB()
            BuffWatchDB.opacity = v / 100
            mainFrame:SetBackdropColor(0.06, 0.06, 0.06, v / 100)
            lbl:SetText(string.format("Opacity: %d%%", v))
        end)

    local lockCB = CreateFrame("CheckButton", "BuffWatchLockCB", configContainer,
        "UICheckButtonTemplate")
    lockCB:SetPoint("TOPLEFT", 0, -142)
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

    local vertCB = CreateFrame("CheckButton", "BuffWatchVertCB", configContainer,
        "UICheckButtonTemplate")
    vertCB:SetPoint("TOPLEFT", 0, -170)
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

    --------------------------------------------------------------------------
    -- Buff view: per-class list of toggleable buffs.
    --------------------------------------------------------------------------
    local buffHeader = buffContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buffHeader:SetPoint("TOPLEFT", 0, -2)
    buffHeader:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    buffHeader:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)

    local buffHint = buffContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buffHint:SetPoint("TOPLEFT", 0, -20)
    buffHint:SetText("Checked buffs are shown on the bar.")
    buffHint:SetTextColor(0.6, 0.6, 0.6, 1)

    local ROW_TOP, ROW_H = -38, 24
    buffContainer.rows = {}

    local function GetRow(i)
        local r = buffContainer.rows[i]
        if not r then
            r = CreateFrame("CheckButton", "BuffWatchBuffRow" .. i, buffContainer,
                "UICheckButtonTemplate")
            r:SetSize(22, 22)
            r:SetPoint("TOPLEFT", buffContainer, "TOPLEFT", 0, ROW_TOP - (i - 1) * ROW_H)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(18, 18)
            r.icon:SetPoint("LEFT", r, "RIGHT", 2, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            r.label:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
            r.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            r:SetScript("OnClick", function(self)
                EnsureDB()
                if self:GetChecked() then
                    BuffWatchDB.hiddenBuffs[self._toggleKey] = nil
                else
                    BuffWatchDB.hiddenBuffs[self._toggleKey] = true
                end
                LayoutButtons()
                RefreshStates()
            end)
            buffContainer.rows[i] = r
        end
        return r
    end

    local function PopulateBuffs(class)
        EnsureDB()
        buffHeader:SetText(class)
        local list = CLASS_BUFFS[class] or {}
        local seen, n = {}, 0
        for _, entry in ipairs(list) do
            local key = entry.toggleKey or entry.spell
            if not seen[key] then
                seen[key] = true
                n = n + 1
                local r = GetRow(n)
                r._toggleKey = key
                r.label:SetText(entry.toggleLabel or entry.spell)
                -- Prefer a known member's icon (the player's own faction seal);
                -- otherwise resolve by spell ID.
                local icon
                for _, e2 in ipairs(list) do
                    if (e2.toggleKey or e2.spell) == key and knownSpells[e2.spell] then
                        icon = knownSpells[e2.spell]
                        break
                    end
                end
                icon = icon or (entry.id and select(3, GetSpellInfo(entry.id)))
                    or "Interface\\Icons\\INV_Misc_QuestionMark"
                r.icon:SetTexture(icon)
                r:SetChecked(not BuffWatchDB.hiddenBuffs[key])
                r:Show()
            end
        end
        for i = n + 1, #buffContainer.rows do
            buffContainer.rows[i]:Hide()
        end
    end

    --------------------------------------------------------------------------
    -- Left sidebar: "Configuration" then each class alphabetically.
    --------------------------------------------------------------------------
    configPanel.catButtons = {}

    local function SelectCategory(name)
        for n, b in pairs(configPanel.catButtons) do
            if n == name then
                b.sel:Show()
                b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
            else
                b.sel:Hide()
                b.label:SetTextColor(0.85, 0.85, 0.85, 1)
            end
        end
        if name == "Configuration" then
            buffContainer:Hide()
            configContainer:Show()
        else
            configContainer:Hide()
            PopulateBuffs(name)
            buffContainer:Show()
        end
    end
    configPanel.SelectCategory = SelectCategory

    local categories = { "Configuration" }
    for _, c in ipairs(CLASS_ORDER) do
        if not DISABLED_CLASSES[c] then categories[#categories + 1] = c end
    end

    local cy = -42
    for _, name in ipairs(categories) do
        local b = CreateFrame("Button", nil, configPanel)
        b:SetSize(SIDEBAR_W - 16, 22)
        b:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 10, cy)

        local selTex = b:CreateTexture(nil, "BACKGROUND")
        selTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        selTex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.18)
        selTex:SetAllPoints()
        selTex:Hide()
        b.sel = selTex

        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.10)
        hl:SetAllPoints()

        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", 4, 0)
        fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        fs:SetText(name)
        fs:SetTextColor(0.85, 0.85, 0.85, 1)
        b.label = fs

        b:SetScript("OnClick", function() SelectCategory(name) end)
        configPanel.catButtons[name] = b
        cy = cy - 24
    end

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
    configPanel.SelectCategory("Configuration")
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

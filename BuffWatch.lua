-- BuffWatch.lua | Author: Valdstein | WotLK 3.3.5a
-- Tracks self-buffs and weapon enchants. /bw toggles, /bw config opens settings.

local ADDON_NAME = "BuffWatch"

local ICON_SIZE = 30
local ICON_PAD  = 3
local BG_PAD    = 5

local TRACKED = {
    { spell = "Power Word: Fortitude", id = 1243, group = "fort", class = "Priest" },
    { spell = "Prayer of Fortitude", id = 21562, group = "fort", class = "Priest" },
    { spell = "Power Word: Shield", id = 17,    class = "Priest" },
    { spell = "Inner Fire", id = 588,            class = "Priest" },
    { spell = "Demon Skin", id = 687, upgradedBy = "Demon Armor", class = "Warlock" },
    { spell = "Demon Armor", id = 706,           class = "Warlock" },
    { spell = "Fel Armor", id = 28176,             class = "Warlock" },
    { spell = "Frost Armor", id = 168, upgradedBy = "Ice Armor", class = "Mage" },
    { spell = "Ice Armor", id = 7302,             class = "Mage" },
    { spell = "Mage Armor", id = 6117,            class = "Mage" },
    { spell = "Molten Armor", id = 30482,          class = "Mage" },
    { spell = "Arcane Intellect", id = 1459, group = "aint", class = "Mage" },
    { spell = "Arcane Brilliance", id = 23028, group = "aint", class = "Mage" },
    { spell = "Water Shield", id = 24398,          class = "Shaman" },
    { spell = "Lightning Shield", id = 324,      class = "Shaman" },
    { spell = "Mark of the Wild", id = 1126, group = "motw", class = "Druid" },
    { spell = "Gift of the Wild", id = 21849, group = "motw", class = "Druid" },
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
    { spell = "Blessing of Might", id = 19740, group = "bless_might", class = "Paladin" },
    { spell = "Greater Blessing of Might", id = 25782, group = "bless_might", class = "Paladin" },
    { spell = "Blessing of Kings", id = 20217, group = "bless_kings", class = "Paladin" },
    { spell = "Greater Blessing of Kings", id = 25898, group = "bless_kings", class = "Paladin" },
    { spell = "Blessing of Wisdom", id = 19742, group = "bless_wisdom", class = "Paladin" },
    { spell = "Greater Blessing of Wisdom", id = 25894, group = "bless_wisdom", class = "Paladin" },
    { spell = "Blessing of Sanctuary", id = 20911, group = "bless_sanc", class = "Paladin" },
    { spell = "Greater Blessing of Sanctuary", id = 25899, group = "bless_sanc", class = "Paladin" },
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
    { spell = "Horn of Winter", id = 57330, class = "Death Knight" },
    { spell = "Battle Shout", id = 6673, class = "Warrior", rageCost = 10 },
    { spell = "Commanding Shout", id = 469, class = "Warrior", rageCost = 10 },
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
    "Priest", "Rogue", "Shaman", "Warlock", "Warrior",
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
local alertMissing = {}  -- entries currently missing, for the centre alert
local alertIndex   = 0   -- which missing buff the alert is currently showing
local alertShown   = {}  -- filtered display list (after the rage gate)

local weaponEnchant = { main = "", off = "" }
local haveWeaponEntries = false

local DB_DEFAULTS = {
    locked = false, hidden = false, scale = 1.0, opacity = 0.85, vertical = false,
    alertEnabled = false, alertScale = 1.0, alertMode = "always", alertLocked = false,
}

local function EnsureDB()
    if type(BuffWatchDB) ~= "table" then BuffWatchDB = {} end
    for k, v in pairs(DB_DEFAULTS) do
        if type(BuffWatchDB[k]) ~= type(v) then BuffWatchDB[k] = v end
    end
    -- hiddenBuffs[spellName] = true means the user toggled that buff off.
    if type(BuffWatchDB.hiddenBuffs) ~= "table" then BuffWatchDB.hiddenBuffs = {} end
    -- alertRageGate[spell] = true -> only flash that buff when enough rage.
    if type(BuffWatchDB.alertRageGate) ~= "table" then BuffWatchDB.alertRageGate = {} end
    -- Orientation/grow (migrate the old `vertical` boolean if present).
    if type(BuffWatchDB.orientation) ~= "string" then
        BuffWatchDB.orientation = (BuffWatchDB.vertical and "vertical") or "horizontal"
    end
    if type(BuffWatchDB.growH) ~= "string" then BuffWatchDB.growH = "right" end
    if type(BuffWatchDB.growV) ~= "string" then BuffWatchDB.growV = "down" end
end

local function RebuildKnownSpells()
    wipe(knownSpells)
    wipe(knownSlot)
    local _, c = UnitClass("player"); playerClass = c
    -- The spellbook can list each rank of a spell as its own entry. Keep the
    -- highest known rank per spell so the tooltip (SetSpell) and icon match
    -- what actually gets cast (casting by name always uses the highest rank).
    local bestRank = {}
    local numTabs = GetNumSpellTabs()
    for t = 1, numTabs do
        local _, _, offset, count = GetSpellTabInfo(t)
        for i = offset + 1, offset + count do
            local name, sub = GetSpellName(i, BOOKTYPE_SPELL)
            if name then
                local rank = tonumber(string.match(sub or "", "%d+")) or 0
                if knownSpells[name] == nil or rank >= bestRank[name] then
                    bestRank[name]    = rank
                    local icon = GetSpellTexture(i, BOOKTYPE_SPELL)
                    knownSpells[name] = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                    knownSlot[name]   = i
                end
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

local ApplyPosition, StorePosition

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
    StorePosition()
end)

-- The anchored corner = the fixed origin the bar grows away from.
local function AnchorPoint()
    if (BuffWatchDB.orientation or "horizontal") == "vertical" then
        return (BuffWatchDB.growV == "up") and "BOTTOMLEFT" or "TOPLEFT"
    end
    return (BuffWatchDB.growH == "left") and "BOTTOMRIGHT" or "BOTTOMLEFT"
end

ApplyPosition = function()
    mainFrame:ClearAllPoints()
    if BuffWatchDB.x and BuffWatchDB.y then
        mainFrame:SetPoint(AnchorPoint(), UIParent, "BOTTOMLEFT",
            BuffWatchDB.x, BuffWatchDB.y)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

-- Save the current screen position of the anchored corner.
StorePosition = function()
    local L, B = mainFrame:GetLeft(), mainFrame:GetBottom()
    local R, T = mainFrame:GetRight(), mainFrame:GetTop()
    if not L then return end
    local pt = AnchorPoint()
    if pt == "BOTTOMRIGHT" then
        BuffWatchDB.x, BuffWatchDB.y = R, B
    elseif pt == "TOPLEFT" then
        BuffWatchDB.x, BuffWatchDB.y = L, T
    else
        BuffWatchDB.x, BuffWatchDB.y = L, B
    end
end

local function ApplyVisuals()
    mainFrame:SetScale(BuffWatchDB.scale or 1.0)
    mainFrame:SetBackdropColor(0.06, 0.06, 0.06, BuffWatchDB.opacity or 0.85)
end

-- Forward declarations; assigned later but referenced earlier.
local OpenConfig
local RefreshAlert
local ApplyAlertVisuals

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
                -- Right-click casts the buff on the player's current target.
                btn:SetAttribute("type2", "spell")
                btn:SetAttribute("spell2", entry.spell)
                btn:SetAttribute("unit2", "target")
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
                if not e.weapon then
                    GameTooltip:AddLine("Right-click: cast on target", 0.67, 0.67, 0.67)
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
    local vertical = (BuffWatchDB.orientation == "vertical")
    local growLeft = (BuffWatchDB.growH == "left")
    local growUp   = (BuffWatchDB.growV == "up")
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
                if growUp then
                    btn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", BG_PAD, offset)
                else
                    btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", BG_PAD, -offset)
                end
            elseif growLeft then
                btn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -offset, -BG_PAD)
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
    ApplyPosition()
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

    -- Collect the buffs currently flagged as missing, for the centre alert.
    wipe(alertMissing)
    for _, btn in ipairs(visButtons) do
        if btn._needs then
            alertMissing[#alertMissing + 1] = btn._entry
        end
    end
    if RefreshAlert then RefreshAlert() end
end

local function RebuildEverything()
    RebuildKnownSpells()
    RebuildActiveBuffs()
    RebuildWeaponEnchants()
    LayoutButtons()
    RefreshStates()
end

--------------------------------------------------------------------------------
-- Centre-screen alert: one large pulsing icon for a missing buff. It cycles
-- through all missing buffs. This is a plain frame (no secure actions), so it is
-- safe to show/hide/resize even in combat.
--------------------------------------------------------------------------------
local alertFrame

ApplyAlertVisuals = function()
    if not alertFrame then return end
    alertFrame:SetScale(BuffWatchDB.alertScale or 1.0)
    alertFrame:ClearAllPoints()
    if BuffWatchDB.alertX and BuffWatchDB.alertY then
        alertFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
            BuffWatchDB.alertX, BuffWatchDB.alertY)
    else
        alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function AlertModeAllows()
    local m = BuffWatchDB.alertMode or "always"
    if m == "ooc"      then return not InCombatLockdown() end
    if m == "incombat" then return InCombatLockdown() end
    return true
end

local alertPulseT, alertCycleT, alertGateT = 0, 0, 0

-- Some buffs (Battle Shout) cost rage; gate the alert so it doesn't flash when
-- the player can't afford the cast. Compares rage as a percent of max so it is
-- agnostic to the 0-100 vs 0-1000 rage scale.
local rageReadySince = {}
local RAGE_POWER = SPELL_POWER_RAGE or 1  -- rage power index

-- True only after the player has held >= the buff's rage cost continuously for
-- 1.5s, so the alert doesn't flash on a brief rage spike. Reads the RAGE power
-- explicitly: UnitMana returns the *primary* power, which on classless servers
-- can be mana, not rage.
local function HasEnoughRage(entry)
    local cost = entry.rageCost
    if not cost then return true end
    local cur  = (UnitPower and UnitPower("player", RAGE_POWER)) or 0
    local maxR = (UnitPowerMax and UnitPowerMax("player", RAGE_POWER)) or 0
    local enough
    if maxR > 0 then
        enough = (cur / maxR) * 100 >= cost   -- percent: scale-agnostic
    else
        enough = cur >= cost                  -- fall back to raw rage value
    end
    local now = GetTime()
    if enough then
        if not rageReadySince[cost] then rageReadySince[cost] = now end
        return (now - rageReadySince[cost]) >= 1.5
    end
    rageReadySince[cost] = nil
    return false
end

local function BuildAlertFrame()
    if alertFrame then return end
    alertFrame = CreateFrame("Frame", "BuffWatchAlertFrame", UIParent)
    alertFrame:SetSize(64, 64)
    alertFrame:SetFrameStrata("HIGH")
    alertFrame:SetClampedToScreen(true)
    alertFrame:SetMovable(true)
    alertFrame:EnableMouse(true)
    alertFrame:RegisterForDrag("LeftButton")
    alertFrame:SetScript("OnDragStart", function(self)
        if not BuffWatchDB.alertLocked then self:StartMoving() end
    end)
    alertFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        BuffWatchDB.alertX = self:GetLeft()
        BuffWatchDB.alertY = self:GetBottom()
    end)

    -- Proc-style glow behind the icon, tinted by the pulse colour.
    alertFrame.glow = alertFrame:CreateTexture(nil, "BACKGROUND")
    alertFrame.glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    alertFrame.glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    alertFrame.glow:SetBlendMode("ADD")
    alertFrame.glow:SetPoint("CENTER")
    alertFrame.glow:SetSize(120, 120)

    alertFrame.icon = alertFrame:CreateTexture(nil, "ARTWORK")
    alertFrame.icon:SetPoint("CENTER")
    alertFrame.icon:SetSize(56, 56)
    alertFrame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    alertFrame.label = alertFrame:CreateFontString(nil, "OVERLAY")
    alertFrame.label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    alertFrame.label:SetPoint("TOP", alertFrame, "BOTTOM", 0, -2)
    alertFrame.label:SetTextColor(1, 1, 1, 1)

    alertFrame:SetScript("OnUpdate", function(self, elapsed)
        alertPulseT = alertPulseT + elapsed
        local p = 0.5 + 0.5 * math.sin(alertPulseT * 5)
        self.glow:SetAlpha(0.25 + 0.75 * p)
        -- Textures have no SetScale in 3.3.5a; pulse their size instead.
        local sc = 1.0 + 0.10 * p
        self.icon:SetSize(56 * sc, 56 * sc)
        self.glow:SetSize(120 * sc, 120 * sc)
        -- Re-evaluate the rage gate / visibility a few times a second.
        alertGateT = alertGateT + elapsed
        if alertGateT >= 0.3 then
            alertGateT = 0
            RefreshAlert()
        end
        if #alertShown > 1 then
            alertCycleT = alertCycleT + elapsed
            if alertCycleT >= 1.0 then
                alertCycleT = 0
                alertIndex = alertIndex + 1
                RefreshAlert()
            end
        end
    end)

    alertFrame:Hide()
end

RefreshAlert = function()
    if not alertFrame then return end
    EnsureDB()
    -- Display list = missing buffs minus any rage-gated buff we can't afford.
    wipe(alertShown)
    for _, e in ipairs(alertMissing) do
        local gated = e.rageCost and BuffWatchDB.alertRageGate[e.spell]
            and not HasEnoughRage(e)
        if not gated then alertShown[#alertShown + 1] = e end
    end
    if (not BuffWatchDB.alertEnabled) or #alertShown == 0 or (not AlertModeAllows()) then
        alertFrame:Hide()
        return
    end
    if alertIndex < 1 or alertIndex > #alertShown then alertIndex = 1 end
    local entry = alertShown[alertIndex]
    local icon = knownSpells[entry.spell]
        or (entry.id and select(3, GetSpellInfo(entry.id)))
        or "Interface\\Icons\\INV_Misc_QuestionMark"
    alertFrame.icon:SetTexture(icon)
    alertFrame.label:SetText(entry.spell)
    alertFrame:Show()
end

-- A small always-running ticker so the rage gate / centre alert keeps
-- re-evaluating even while the alert frame itself is hidden.
local alertTicker = CreateFrame("Frame", nil, UIParent)
local alertTickerT = 0
alertTicker:SetScript("OnUpdate", function(self, elapsed)
    alertTickerT = alertTickerT + elapsed
    if alertTickerT >= 0.2 then
        alertTickerT = 0
        if RefreshAlert then RefreshAlert() end
    end
end)

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
    local alertContainer  = MakeContainer()
    alertContainer:Hide()

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

    -- Layout: orientation (mutually exclusive) + grow direction.
    local function ReapplyLayout()
        StorePosition()
        ApplyPosition()
        LayoutButtons()
        RefreshStates()
    end

    local function mkCB(name, x, y, size, text)
        local cb = CreateFrame("CheckButton", name, configContainer, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb:SetSize(size, size)
        local lb = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lb:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lb:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        lb:SetText(text)
        return cb
    end

    local horizCB     = mkCB("BuffWatchHorizCB",     0,  -172, 24, "Horizontal layout")
    local growRightCB = mkCB("BuffWatchGrowRightCB", 24, -194, 22, "Grow right")
    local growLeftCB  = mkCB("BuffWatchGrowLeftCB",  140,-194, 22, "Grow left")
    local vertCB      = mkCB("BuffWatchVertCB",      0,  -220, 24, "Vertical layout")
    local growDownCB  = mkCB("BuffWatchGrowDownCB",  24, -242, 22, "Grow down")
    local growUpCB    = mkCB("BuffWatchGrowUpCB",    140,-242, 22, "Grow up")

    local function UpdateLayoutControls()
        EnsureDB()
        local o = BuffWatchDB.orientation or "horizontal"
        horizCB:SetChecked(o == "horizontal")
        vertCB:SetChecked(o == "vertical")
        growRightCB:SetChecked(BuffWatchDB.growH ~= "left")
        growLeftCB:SetChecked(BuffWatchDB.growH == "left")
        growDownCB:SetChecked(BuffWatchDB.growV ~= "up")
        growUpCB:SetChecked(BuffWatchDB.growV == "up")
        if o == "horizontal" then
            growRightCB:Enable(); growLeftCB:Enable()
            growDownCB:Disable(); growUpCB:Disable()
        else
            growDownCB:Enable(); growUpCB:Enable()
            growRightCB:Disable(); growLeftCB:Disable()
        end
    end
    configPanel.UpdateLayoutControls = UpdateLayoutControls

    horizCB:SetScript("OnClick", function()
        EnsureDB(); BuffWatchDB.orientation = "horizontal"
        UpdateLayoutControls(); ReapplyLayout()
    end)
    vertCB:SetScript("OnClick", function()
        EnsureDB(); BuffWatchDB.orientation = "vertical"
        UpdateLayoutControls(); ReapplyLayout()
    end)
    growRightCB:SetScript("OnClick", function()
        EnsureDB(); BuffWatchDB.growH = "right"
        UpdateLayoutControls(); ReapplyLayout()
    end)
    growLeftCB:SetScript("OnClick", function()
        EnsureDB(); BuffWatchDB.growH = "left"
        UpdateLayoutControls(); ReapplyLayout()
    end)
    growDownCB:SetScript("OnClick", function()
        EnsureDB(); BuffWatchDB.growV = "down"
        UpdateLayoutControls(); ReapplyLayout()
    end)
    growUpCB:SetScript("OnClick", function()
        EnsureDB(); BuffWatchDB.growV = "up"
        UpdateLayoutControls(); ReapplyLayout()
    end)

    --------------------------------------------------------------------------
    -- Center Alert view: pulsing missing-buff alert.
    --------------------------------------------------------------------------
    local alHeader = alertContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alHeader:SetPoint("TOPLEFT", 0, -2)
    alHeader:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    alHeader:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
    alHeader:SetText("Center Alert")

    local alHint = alertContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alHint:SetPoint("TOPLEFT", 0, -20)
    alHint:SetText("Large pulsing icon for a missing buff.")
    alHint:SetTextColor(0.6, 0.6, 0.6, 1)

    local enCB = CreateFrame("CheckButton", "BuffWatchAlertEnableCB", alertContainer,
        "UICheckButtonTemplate")
    enCB:SetPoint("TOPLEFT", 0, -36)
    enCB:SetSize(24, 24)
    local enLbl = enCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enLbl:SetPoint("LEFT", enCB, "RIGHT", 4, 0)
    enLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    enLbl:SetText("Enable center alert")
    enCB:SetScript("OnClick", function(self)
        EnsureDB()
        BuffWatchDB.alertEnabled = self:GetChecked() and true or false
        if RefreshAlert then RefreshAlert() end
    end)
    configPanel.alertEnableCB = enCB

    local alScaleLbl = alertContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alScaleLbl:SetPoint("TOPLEFT", 0, -68)
    alScaleLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    alScaleLbl:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
    alScaleLbl:SetText("Scale: 1.00x")
    local alScale = CreateFrame("Slider", nil, alertContainer)
    alScale:SetOrientation("HORIZONTAL")
    alScale:SetHeight(16)
    alScale:SetWidth(PW - CONTENT_X - 24)
    alScale:SetPoint("TOPLEFT", 0, -86)
    alScale:SetMinMaxValues(0.5, 3.0)
    alScale:SetValueStep(0.05)
    local alTrack = alScale:CreateTexture(nil, "BACKGROUND")
    alTrack:SetTexture("Interface\\Buttons\\WHITE8X8")
    alTrack:SetPoint("TOPLEFT", alScale, "TOPLEFT", 0, -6)
    alTrack:SetPoint("BOTTOMRIGHT", alScale, "BOTTOMRIGHT", 0, 6)
    alTrack:SetGradientAlpha("VERTICAL", 0.78, 0.80, 0.86, 1, 0.36, 0.38, 0.44, 1)
    local alThumb = alScale:CreateTexture(nil, "OVERLAY")
    alThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    alThumb:SetSize(32, 18)
    alScale:SetThumbTexture(alThumb)
    alScale:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 0.05 + 0.5) * 0.05
        EnsureDB()
        BuffWatchDB.alertScale = v
        alScaleLbl:SetText(string.format("Scale: %.2fx", v))
        if ApplyAlertVisuals then ApplyAlertVisuals() end
    end)
    configPanel.alertScaleSlider = alScale

    local alLockCB = CreateFrame("CheckButton", "BuffWatchAlertLockCB", alertContainer,
        "UICheckButtonTemplate")
    alLockCB:SetPoint("TOPLEFT", 0, -116)
    alLockCB:SetSize(24, 24)
    local alLockLbl = alLockCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alLockLbl:SetPoint("LEFT", alLockCB, "RIGHT", 4, 0)
    alLockLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    alLockLbl:SetText("Lock alert position")
    alLockCB:SetScript("OnClick", function(self)
        EnsureDB()
        BuffWatchDB.alertLocked = self:GetChecked() and true or false
    end)
    configPanel.alertLockCB = alLockCB

    local modeLbl = alertContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLbl:SetPoint("TOPLEFT", 0, -148)
    modeLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    modeLbl:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
    modeLbl:SetText("Show alert:")
    local modeCBs = {}
    local modes = { { key = "always", text = "Always" },
        { key = "ooc", text = "Out of combat" },
        { key = "incombat", text = "In combat" } }
    local function SetModeChecks(active)
        for _, mc in ipairs(modeCBs) do mc:SetChecked(mc._mode == active) end
    end
    configPanel.alertModeSet = SetModeChecks
    for i, m in ipairs(modes) do
        local cb = CreateFrame("CheckButton", nil, alertContainer, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", 0, -166 - (i - 1) * 24)
        cb._mode = m.key
        local lb = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lb:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lb:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        lb:SetText(m.text)
        cb:SetScript("OnClick", function(self)
            EnsureDB()
            BuffWatchDB.alertMode = self._mode
            SetModeChecks(self._mode)
            if RefreshAlert then RefreshAlert() end
        end)
        modeCBs[i] = cb
    end

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

    local ROW_H = 24

    -- Scrollable list so classes with many buffs (e.g. Paladin) all fit.
    local scroll = CreateFrame("ScrollFrame", "BuffWatchBuffScroll", buffContainer,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", buffContainer, "TOPLEFT", 0, -38)
    scroll:SetPoint("BOTTOMRIGHT", buffContainer, "BOTTOMRIGHT", -24, 0)
    local scrollChild = CreateFrame("Frame", "BuffWatchBuffScrollChild", scroll)
    scrollChild:SetSize(1, 1)
    scroll:SetScrollChild(scrollChild)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur  = self:GetVerticalScroll()
        local maxs = self:GetVerticalScrollRange()
        local new  = cur - delta * ROW_H * 2
        if new < 0 then new = 0 elseif new > maxs then new = maxs end
        self:SetVerticalScroll(new)
    end)
    buffContainer.scroll = scroll
    buffContainer.rows = {}

    local function GetRow(i)
        local r = buffContainer.rows[i]
        if not r then
            r = CreateFrame("CheckButton", "BuffWatchBuffRow" .. i, scrollChild,
                "UICheckButtonTemplate")
            r:SetSize(22, 22)
            r:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_H)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(18, 18)
            r.icon:SetPoint("LEFT", r, "RIGHT", 2, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            r.label:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
            r.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            r:SetScript("OnClick", function(self)
                EnsureDB()
                if self._kind == "rage" then
                    if self:GetChecked() then
                        BuffWatchDB.alertRageGate[self._spell] = true
                    else
                        BuffWatchDB.alertRageGate[self._spell] = nil
                    end
                    if RefreshAlert then RefreshAlert() end
                else
                    if self:GetChecked() then
                        BuffWatchDB.hiddenBuffs[self._toggleKey] = nil
                    else
                        BuffWatchDB.hiddenBuffs[self._toggleKey] = true
                    end
                    LayoutButtons()
                    RefreshStates()
                end
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
                r._kind = "buff"
                r._toggleKey = key
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(n - 1) * ROW_H)
                r.icon:Show()
                r.label:ClearAllPoints()
                r.label:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
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

                -- Rage-gated buffs (e.g. Battle Shout) get an indented
                -- "only when enough rage" alert sub-option.
                if entry.rageCost then
                    n = n + 1
                    local sr = GetRow(n)
                    sr._kind = "rage"
                    sr._spell = entry.spell
                    sr:ClearAllPoints()
                    sr:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 22, -(n - 1) * ROW_H)
                    sr.icon:Hide()
                    sr.label:ClearAllPoints()
                    sr.label:SetPoint("LEFT", sr, "RIGHT", 5, 0)
                    sr.label:SetText("Center Alert: Only when enough rage")
                    sr:SetChecked(BuffWatchDB.alertRageGate[entry.spell] and true or false)
                    sr:Show()
                end
            end
        end
        for i = n + 1, #buffContainer.rows do
            buffContainer.rows[i]:Hide()
        end
        -- Size the scroll child to the row count and reset to the top.
        local w = scroll:GetWidth()
        if not w or w <= 0 then w = 240 end
        scrollChild:SetWidth(w)
        scrollChild:SetHeight(math.max(n * ROW_H, 1))
        scroll:SetVerticalScroll(0)
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
            buffContainer:Hide(); alertContainer:Hide()
            configContainer:Show()
        elseif name == "Center Alert" then
            configContainer:Hide(); buffContainer:Hide()
            alertContainer:Show()
        else
            configContainer:Hide(); alertContainer:Hide()
            PopulateBuffs(name)
            buffContainer:Show()
        end
    end
    configPanel.SelectCategory = SelectCategory

    local categories = { "Configuration", "Center Alert" }
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
    configPanel.UpdateLayoutControls()
    if configPanel.alertEnableCB then
        configPanel.alertEnableCB:SetChecked(BuffWatchDB.alertEnabled and 1 or nil)
        configPanel.alertScaleSlider:SetValue(BuffWatchDB.alertScale or 1.0)
        configPanel.alertModeSet(BuffWatchDB.alertMode or "always")
        configPanel.alertLockCB:SetChecked(BuffWatchDB.alertLocked and 1 or nil)
    end
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
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        EnsureDB()
        ApplyPosition()
        ApplyVisuals()
        InitButtons()
        BuildAlertFrame()
        ApplyAlertVisuals()
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
        if RefreshAlert then RefreshAlert() end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        if RefreshAlert then RefreshAlert() end
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

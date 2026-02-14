local soloPool, soloActive, soloLookup = {}, {}, {}
local previousMoney = 0
local soloGoldSession = 0

local SOLO_XP_ICON = "Interface\\Icons\\spell_holy_surgeoflight"
local SOLO_REP_ICON = "Interface\\Icons\\inv_misc_note_02"
local SOLO_GOLD_ICONS = {
    copper = "Interface\\Icons\\inv_misc_coin_04",
    silver = "Interface\\Icons\\inv_misc_coin_03",
    gold   = "Interface\\Icons\\inv_misc_coin_01",
}

function LootEnh_InitSoloMoney()
    previousMoney = GetMoney()
    soloGoldSession = 0
end

-- ============================================================
-- Helpers
-- ============================================================

local function FormatGold(diff)
    local gold = math.floor(diff / 10000)
    local silver = math.floor((diff % 10000) / 100)
    local copper = diff % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = "|cffffd700" .. gold .. "g|r" end
    if silver > 0 then parts[#parts + 1] = "|cffc7c7cf" .. silver .. "s|r" end
    if copper > 0 then parts[#parts + 1] = "|cffeda55f" .. copper .. "c|r" end
    return table.concat(parts, " ")
end

local function GetGoldIcon(diff)
    if diff >= 10000 then return SOLO_GOLD_ICONS.gold
    elseif diff >= 100 then return SOLO_GOLD_ICONS.silver
    else return SOLO_GOLD_ICONS.copper end
end

local function FormatCountWithTotal(count, bagTotal)
    local parts = ""
    if count and count > 1 then
        parts = "x" .. count
    end
    if bagTotal and bagTotal > 0 then
        parts = parts .. " |cff888888(" .. bagTotal .. ")|r"
    end
    return parts
end

local function CreateQuestBorder(f)
    local borders = {}
    local r, g, b, a = 1, 0.82, 0, 0.8
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(r, g, b, a)
        if side == "TOP" then
            tex:SetHeight(2)
            tex:SetPoint("TOPLEFT", 0, 0)
            tex:SetPoint("TOPRIGHT", 0, 0)
        elseif side == "BOTTOM" then
            tex:SetHeight(2)
            tex:SetPoint("BOTTOMLEFT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", 0, 0)
        elseif side == "LEFT" then
            tex:SetWidth(2)
            tex:SetPoint("TOPLEFT", 0, 0)
            tex:SetPoint("BOTTOMLEFT", 0, 0)
        elseif side == "RIGHT" then
            tex:SetWidth(2)
            tex:SetPoint("TOPRIGHT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        tex:Hide()
        borders[#borders + 1] = tex
    end
    return borders
end

-- ============================================================
-- Frame management
-- ============================================================

local function RestackSoloFrames()
    if not SoloAnchor then return end
    local cfg = MonLootDB.solo or {}
    local spacing = cfg.spacing or 5
    local growUp = (cfg.growDir or "up") == "up"

    for i, f in ipairs(soloActive) do
        f:ClearAllPoints()
        local offset = (i - 1) * (37 + spacing)
        if growUp then
            f:SetPoint("BOTTOM", SoloAnchor, "TOP", 0, offset)
        else
            f:SetPoint("TOP", SoloAnchor, "BOTTOM", 0, -offset)
        end
    end
end

local function DismissSoloBar(f)
    f:Hide()
    if f.soloKey and soloLookup[f.soloKey] == f then
        soloLookup[f.soloKey] = nil
    end
    for i, fr in ipairs(soloActive) do
        if fr == f then
            table.remove(soloActive, i)
            break
        end
    end
    -- Clean cumulation fields
    f.soloLink = nil
    f.goldRaw = nil
    f.xpRaw = nil
    f.repRaw = nil
    f.soloCount = nil
    for _, tex in ipairs(f.questBorders or {}) do tex:Hide() end
    if f.questIcon then f.questIcon:Hide() end

    table.insert(soloPool, f)
    RestackSoloFrames()
end

local function GetSoloFrame()
    local f = table.remove(soloPool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(220, 32)
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10
        })
        f:SetBackdropColor(0, 0, 0, 0.8)

        f.i = f:CreateTexture(nil, "ARTWORK")
        f.i:SetSize(24, 24)
        f.i:SetPoint("LEFT", 4, 0)

        f.t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.t:SetPoint("LEFT", 32, 0)
        f.t:SetPoint("RIGHT", -38, 0)
        f.t:SetJustifyH("LEFT")

        f.q = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.q:SetPoint("RIGHT", -20, 0)
        f.q:SetJustifyH("RIGHT")

        f.x = CreateFrame("Button", nil, f)
        f.x:SetSize(16, 16)
        f.x:SetPoint("RIGHT", -2, 0)
        f.x:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        f.x:SetScript("OnClick", function() DismissSoloBar(f) end)

        -- Tooltip on hover
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            if self.soloLink and self.soloLink:find("|Hitem:") then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.soloLink:match("(item:[%d:]+)"))
                GameTooltip:Show()
            end
        end)
        f:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Quest highlight elements
        f.questBorders = CreateQuestBorder(f)
        f.questIcon = f:CreateTexture(nil, "OVERLAY")
        f.questIcon:SetSize(14, 14)
        f.questIcon:SetPoint("TOPRIGHT", -18, -1)
        f.questIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        f.questIcon:Hide()
    end
    return f
end

-- ============================================================
-- ShowSoloBanner
-- ============================================================

function LootEnh_ShowSoloBanner(entryType, icon, text, count, link, isQuest, duration)
    if not MonLootDB.solo or not MonLootDB.solo.enabled then return end

    local cfg = MonLootDB.solo or {}
    duration = duration or 5
    local maxBars = cfg.maxBars or 4

    -- Build lookup key (cumulation logic is now handled per-handler)
    local lookupKey
    if entryType == "gold" then
        lookupKey = "gold:total"
    elseif entryType == "xp" then
        lookupKey = "xp:total"
    elseif entryType == "loot" then
        local mod = cfg.loot
        if mod and mod.cumulate then
            lookupKey = "loot:" .. text
        else
            lookupKey = "loot:" .. text .. ":" .. GetTime()
        end
    elseif entryType == "rep" then
        local mod = cfg.rep
        if mod and mod.cumulate then
            lookupKey = "rep:" .. text
        else
            lookupKey = "rep:" .. text .. ":" .. GetTime()
        end
    else
        lookupKey = entryType .. ":" .. text
    end

    -- Cumulation: check if a bar with same key already exists
    local existing = soloLookup[lookupKey]
    if existing and existing:IsShown() then
        local oldCount = existing.soloCount or 1
        local addCount = count or 1
        existing.soloCount = oldCount + addCount
        -- Update display with bag total for loot items
        local bagTotal = existing.soloLink and GetItemCount(existing.soloLink) or nil
        existing.q:SetText(FormatCountWithTotal(existing.soloCount, bagTotal))
        -- Reset timer
        existing.endT = GetTime() + duration
        return
    end

    -- Cap check
    if #soloActive >= maxBars then
        DismissSoloBar(soloActive[1])
    end

    local f = GetSoloFrame()
    f.i:SetTexture(icon)
    f.t:SetText(text)
    f.soloCount = count or 1
    f.soloLink = link
    f.soloKey = lookupKey
    soloLookup[lookupKey] = f

    -- Bag total for loot items
    local bagTotal = link and GetItemCount(link) or nil
    f.q:SetText(FormatCountWithTotal(f.soloCount, bagTotal))

    -- Quest highlight — read from loot module
    local lootMod = cfg.loot or {}
    local showQuest = isQuest and lootMod.questHighlight
    for _, tex in ipairs(f.questBorders or {}) do
        if showQuest then tex:Show() else tex:Hide() end
    end
    if f.questIcon then
        if showQuest then f.questIcon:Show() else f.questIcon:Hide() end
    end

    -- Apply shared solo visuals
    f:SetFrameStrata(cfg.strata or "MEDIUM")
    f:SetScale(cfg.scale or 1.0)
    f:SetBackdropColor(0, 0, 0, cfg.alpha or 0.8)

    f.endT = GetTime() + duration
    f:SetScript("OnUpdate", function(s)
        local r = s.endT - GetTime()
        if r <= 0 then
            DismissSoloBar(s)
        elseif r < 1 then
            s:SetAlpha(r)
        else
            s:SetAlpha(1)
        end
    end)

    table.insert(soloActive, f)
    f:Show()
    RestackSoloFrames()
end

function LootEnh_RefreshActiveSoloFrames()
    local cfg = MonLootDB.solo or {}
    for _, f in ipairs(soloActive) do
        f:SetFrameStrata(cfg.strata or "MEDIUM")
        f:SetScale(cfg.scale or 1.0)
        f:SetBackdropColor(0, 0, 0, cfg.alpha or 0.8)
    end
    RestackSoloFrames()
end

-- ============================================================
-- Event handlers (wired in Core.lua)
-- ============================================================

function LootEnh_OnSoloLoot(msg)
    if not MonLootDB.solo or not MonLootDB.solo.enabled then return end
    local mod = MonLootDB.solo.loot
    if not mod or not mod.enabled then return end
    if not msg then return end

    -- Only process "You receive loot:" messages (solo loot)
    local m = msg:lower()
    if not m:find("^you receive loot") and not m:find("^vous recevez") then return end

    -- Extract item link
    local itemLink = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if not itemLink then return end

    -- Extract count (e.g. "x3" at end)
    local itemCount = tonumber(msg:match("x(%d+)")) or 1

    -- Get item info
    local name, _, quality, _, _, itemType, _, _, _, texture = GetItemInfo(itemLink)
    if not name then return end

    -- Rarity check
    local minRarity = mod.minRarity or 2
    if quality < minRarity then return end

    -- Detect quest item
    local isQuest = (itemType == "Quest") or (quality == 6)

    -- Truncate long names
    if #name > 25 then
        name = name:sub(1, 25) .. "..."
    end

    -- Color by quality
    local colors = {
        [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00",
        [3] = "0070dd", [4] = "a335ee", [5] = "ff8000", [6] = "e6cc80",
    }
    local c = colors[quality] or "ffffff"
    local displayName = "|cff" .. c .. name .. "|r"

    -- Pass link only if showBagCount is enabled
    local passLink = mod.showBagCount and itemLink or nil

    LootEnh_ShowSoloBanner("loot", texture, displayName, itemCount, passLink, isQuest, mod.duration or 5)
end

function LootEnh_OnSoloMoney()
    if not MonLootDB.solo or not MonLootDB.solo.enabled then return end
    local mod = MonLootDB.solo.gold
    if not mod or not mod.enabled then return end

    local current = GetMoney()
    local diff = current - previousMoney
    previousMoney = current
    if diff <= 0 then return end

    local duration = mod.duration or 4
    soloGoldSession = soloGoldSession + diff

    -- Cumulate into existing gold bar if enabled and present
    if mod.cumulate then
        local existing = soloLookup["gold:total"]
        if existing and existing:IsShown() then
            existing.goldRaw = (existing.goldRaw or 0) + diff
            local txt = FormatGold(existing.goldRaw)
            if mod.showSessionTotal then
                txt = txt .. " |cff888888[" .. FormatGold(soloGoldSession) .. "]|r"
            end
            existing.t:SetText(txt)
            existing.i:SetTexture(GetGoldIcon(existing.goldRaw))
            existing.endT = GetTime() + duration
            return
        end
    end

    -- New bar
    local txt = FormatGold(diff)
    if mod.showSessionTotal then
        txt = txt .. " |cff888888[" .. FormatGold(soloGoldSession) .. "]|r"
    end
    LootEnh_ShowSoloBanner("gold", GetGoldIcon(diff), txt, nil, nil, false, duration)
    local frame = soloLookup["gold:total"]
    if frame then frame.goldRaw = diff end
end

function LootEnh_OnSoloXP(msg)
    if not MonLootDB.solo or not MonLootDB.solo.enabled then return end
    local mod = MonLootDB.solo.xp
    if not mod or not mod.enabled then return end
    if not msg then return end

    local xp = tonumber(msg:match("(%d+)"))
    if not xp then return end

    local duration = mod.duration or 4

    -- Cumulate into existing XP bar if enabled and present
    if mod.cumulate then
        local existing = soloLookup["xp:total"]
        if existing and existing:IsShown() then
            existing.xpRaw = (existing.xpRaw or 0) + xp
            existing.t:SetText("|cff8080ff+" .. existing.xpRaw .. " XP|r")
            existing.endT = GetTime() + duration
            return
        end
    end

    LootEnh_ShowSoloBanner("xp", SOLO_XP_ICON, "|cff8080ff+" .. xp .. " XP|r", nil, nil, false, duration)
    if mod.cumulate then
        local frame = soloLookup["xp:total"]
        if frame then frame.xpRaw = xp end
    end
end

function LootEnh_OnSoloRep(msg)
    if not MonLootDB.solo or not MonLootDB.solo.enabled then return end
    local mod = MonLootDB.solo.rep
    if not mod or not mod.enabled then return end
    if not msg then return end

    -- "Reputation with <Faction> increased by <amount>."
    local m = msg:lower()
    if not m:find("increased") and not m:find("augment") then return end

    local amount = tonumber(msg:match("(%d+)"))
    if not amount then return end

    local faction = msg:match("with (.+) increased") or msg:match("aupres de (.+) augment")
    if not faction then
        faction = "Reputation"
    end

    local duration = mod.duration or 5

    -- Cumulate per faction if enabled and present
    if mod.cumulate then
        local lookupKey = "rep:" .. faction
        local existing = soloLookup[lookupKey]
        if existing and existing:IsShown() then
            existing.repRaw = (existing.repRaw or 0) + amount
            existing.t:SetText("|cff40c040+" .. existing.repRaw .. " " .. faction .. "|r")
            existing.endT = GetTime() + duration
            return
        end
    end

    LootEnh_ShowSoloBanner("rep", SOLO_REP_ICON, "|cff40c040+" .. amount .. " " .. faction .. "|r", nil, nil, false, duration)
    if mod.cumulate then
        local frame = soloLookup["rep:" .. faction]
        if frame then frame.repRaw = amount end
    end
end

-- Test function for the panel
function LootEnh_TestSoloBars()
    local s = MonLootDB.solo or {}
    local ld = (s.loot or {}).duration or 5
    local gd = (s.gold or {}).duration or 4
    local xd = (s.xp or {}).duration or 4
    local rd = (s.rep or {}).duration or 5
    LootEnh_ShowSoloBanner("loot", "Interface\\Icons\\inv_sword_39", "|cff0070dd[Blade of Test]|r", 2, nil, false, ld)
    LootEnh_ShowSoloBanner("loot", "Interface\\Icons\\inv_misc_rune_01", "|cffe6cc80[Quest Scroll]|r", 1, nil, true, ld)
    LootEnh_ShowSoloBanner("gold", SOLO_GOLD_ICONS.gold, FormatGold(12345), nil, nil, false, gd)
    LootEnh_ShowSoloBanner("xp", SOLO_XP_ICON, "|cff8080ff+150 XP|r", nil, nil, false, xd)
    LootEnh_ShowSoloBanner("rep", SOLO_REP_ICON, "|cff40c040+75 Stormwind|r", nil, nil, false, rd)
end

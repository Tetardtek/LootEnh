local soloPool, soloLookup = {}, {}

-- Deux flux distincts, chacun avec son ancre et son plafond de barres.
--
-- Le butin (objets) et la progression (or, XP, réputation) partageaient la même
-- liste et le même maxBars : un simple gain d'XP pouvait donc évincer un objet
-- épique de l'écran. Ils n'ont pourtant rien à s'échanger — l'un est fait
-- d'événements identifiables, l'autre de quantités cumulatives.
--
-- Le pool de frames reste commun : une frame est entièrement reconfigurée à
-- chaque affichage (hauteur, icône, opacité), elle peut donc servir aux deux.
local channels = {
    loot = {
        active = {}, anchorName = "LootEnhSoloAnchor",
        maxKey = "maxBars", maxDefault = 4,
    },
    progress = {
        active = {}, anchorName = "LootEnhProgressAnchor",
        maxKey = "progressMaxBars", maxDefault = 3,
    },
}

local function ChannelOf(entryType)
    return (entryType == "loot") and channels.loot or channels.progress
end
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

-- Coût visuel d'un objet selon sa rareté. Trois paliers seulement : régler sept
-- raretés à la main serait ingérable, et le but n'est pas la nuance mais le
-- CONTRASTE — qu'un objet commun se lise du coin de l'œil et qu'un objet rare
-- arrête le regard.
--   discret   : fin, bref, effacé, sans liseré de qualité
--   normal    : le rendu historique de l'addon
--   événement : haut, tenu plus longtemps, opaque, liseré vif
function LootEnh_LootTier(quality)
    local mod = (MonLootDB.solo or {}).loot or {}
    if mod.graded == false or not quality then
        return { height = 32, durMul = 1, alphaMul = 1, border = true }
    end
    if quality < (mod.tierMuted or 2) then
        return { height = 20, durMul = 0.5, alphaMul = 0.55, border = false }
    elseif quality >= (mod.tierEvent or 3) then
        return { height = 44, durMul = 1.6, alphaMul = 1, border = true, event = true }
    end
    return { height = 32, durMul = 1, alphaMul = 1, border = true }
end

local function RestackChannel(ch)
    local anchor = _G[ch.anchorName]
    if not anchor then return end
    local cfg = MonLootDB.solo or {}
    local spacing = cfg.spacing or 5
    local growUp = (cfg.growDir or "up") == "up"

    -- Les hauteurs varient d'une barre à l'autre depuis la gradation : on cumule
    -- les hauteurs RÉELLES au lieu de multiplier un pas fixe, sinon les barres
    -- discrètes laissent des trous et les barres d'événement se chevauchent.
    local offset = 0
    for _, f in ipairs(ch.active) do
        f:ClearAllPoints()
        local animOff = f.leOffY or 0
        if growUp then
            f:SetPoint("BOTTOM", anchor, "TOP", 0, offset + animOff)
        else
            f:SetPoint("TOP", anchor, "BOTTOM", 0, -offset + animOff)
        end
        offset = offset + (f:GetHeight() or 32) + spacing
    end
end

-- Sans argument : c'est aussi le rappel passé aux animations, qui ne savent pas
-- quel canal a bougé. Repositionner les deux coûte quelques SetPoint.
local function RestackSoloFrames()
    RestackChannel(channels.loot)
    RestackChannel(channels.progress)
end

local function DismissSoloBar(f)
    LootEnh_AnimReset(f)
    f:Hide()
    if f.soloKey and soloLookup[f.soloKey] == f then
        soloLookup[f.soloKey] = nil
    end
    local ch = f.channel
    if ch then
        for i, fr in ipairs(ch.active) do
            if fr == f then
                table.remove(ch.active, i)
                break
            end
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
        LootEnh_Backdrop(f):SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10
        })
        f:SetBackdropColor(0, 0, 0, 0.8)

        f.i = f:CreateTexture(nil, "ARTWORK")
        f.i:SetSize(24, 24)
        f.i:SetPoint("LEFT", 4, 0)
        f.i:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.ib = LootEnh_CreateIconBorder(f, f.i, 1)

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
        f.x:SetScript("OnClick", function()
            local style = (MonLootDB.solo or {}).animStyle or "fade"
            if not LootEnh_BeginExit(f, style, DismissSoloBar) then
                DismissSoloBar(f)
            end
        end)

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

function LootEnh_ShowSoloBanner(entryType, icon, text, count, link, isQuest, duration, quality)
    if not MonLootDB.solo or not MonLootDB.solo.enabled then return end

    local cfg = MonLootDB.solo or {}
    duration = duration or 5

    -- Chaque canal a son propre plafond : le butin ne se fait plus chasser de
    -- l'écran par un gain d'XP, et inversement.
    local ch = ChannelOf(entryType)
    local maxBars = cfg[ch.maxKey] or ch.maxDefault

    -- La gradation ne concerne que les objets : l'or, l'XP et la réputation
    -- n'ont pas de rareté, ils gardent le rendu normal.
    local tier = ((entryType == "loot") and LootEnh_LootTier(quality))
                 or { height = 32, durMul = 1, alphaMul = 1, border = true }
    duration = duration * tier.durMul

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
    if #ch.active >= maxBars then
        DismissSoloBar(ch.active[1])
    end

    local f = GetSoloFrame()
    f.channel = ch

    -- Toujours réappliquer : les frames sont recyclées par le pool, celle-ci a
    -- pu servir de barre d'événement (44 px) au butin précédent.
    f:SetHeight(tier.height)
    local iconSize = math.max(14, tier.height - 8)
    f.i:SetSize(iconSize, iconSize)   -- le liseré est ancré dessus, il suit
    f.baseAlpha = tier.alphaMul

    f.i:SetTexture(icon)
    f.t:SetText(text)

    -- Quality icon border (loot entries only) — jamais sur le palier discret :
    -- un liseré coloré sur un objet commun est précisément le bruit qu'on veut
    -- retirer.
    local qc = quality and LootEnh_QUALITY_COLORS[quality]
    if qc and tier.border and (cfg.loot or {}).qualityIconBorder ~= false then
        f.ib:SetVertexColor(qc[1], qc[2], qc[3], 0.9)
        f.ib:Show()
    else
        f.ib:Hide()
    end
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
    f:SetBackdropColor(0, 0, 0, (cfg.alpha or 0.8) * tier.alphaMul)

    -- Le palier événement s'entend autant qu'il se voit. Désactivé par défaut :
    -- un son sur chaque objet rare devient vite fatigant en donjon, c'est à
    -- essayer avant d'adopter.
    if tier.event and (cfg.loot or {}).tierSound then
        PlaySound("LOOTWINDOWCOINSOUND")
    end

    f.endT = GetTime() + duration
    f:SetScript("OnUpdate", function(s)
        if LootEnh_AnimStep(s, RestackSoloFrames) then return end
        local r = s.endT - GetTime()
        local base = s.baseAlpha or 1
        if r <= 0 then
            DismissSoloBar(s)
        elseif r < 1 then
            s:SetAlpha(r * base)      -- le fondu part de l'opacité du palier
        elseif not s.leStyle then
            s:SetAlpha(base)
        end
    end)

    -- Entry animation
    LootEnh_BeginEntry(f, cfg.animStyle or "fade", (cfg.growDir or "up") == "up", quality, cfg.scale or 1.0)

    table.insert(ch.active, f)
    f:Show()
    RestackSoloFrames()
end

function LootEnh_RefreshActiveSoloFrames()
    local cfg = MonLootDB.solo or {}
    for _, c in pairs(channels) do
        for _, f in ipairs(c.active) do
            f:SetFrameStrata(cfg.strata or "MEDIUM")
            f:SetScale(cfg.scale or 1.0)
            -- L'opacité du palier est conservée : la réappliquer telle quelle
            -- effacerait la mise en retrait des objets communs.
            f:SetBackdropColor(0, 0, 0, (cfg.alpha or 0.8) * (f.baseAlpha or 1))
        end
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

    LootEnh_ShowSoloBanner("loot", texture, displayName, itemCount, passLink, isQuest, mod.duration or 5, quality)
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

-- Aperçu des trois paliers de gradation, côte à côte (/lt). Trois barres pour
-- un maxBars de 4 par défaut : elles tiennent toutes, contrairement au test
-- général ci-dessous qui en envoie cinq et perd les premières.
-- Le but est de juger le CONTRASTE, pas le contenu : mêmes mots, seule la
-- rareté change.
function LootEnh_TestLootTiers()
    local ld = ((MonLootDB.solo or {}).loot or {}).duration or 5
    LootEnh_ShowSoloBanner("loot", "Interface\\Icons\\inv_fabric_linen_01",
        "|cffffffff[Lin brut]|r", 12, nil, false, ld, 1)              -- discret
    LootEnh_ShowSoloBanner("loot", "Interface\\Icons\\inv_gauntlets_04",
        "|cff1eff00[Gantelets de mailles]|r", 1, nil, false, ld, 2)   -- normal
    LootEnh_ShowSoloBanner("loot", "Interface\\Icons\\inv_sword_39",
        "|cffa335ee[Lame de Sombrelune]|r", 1, nil, false, ld, 4)     -- événement
end

-- Test function for the panel
function LootEnh_TestSoloBars()
    local s = MonLootDB.solo or {}
    local ld = (s.loot or {}).duration or 5
    local gd = (s.gold or {}).duration or 4
    local xd = (s.xp or {}).duration or 4
    local rd = (s.rep or {}).duration or 5
    LootEnh_ShowSoloBanner("loot", "Interface\\Icons\\inv_sword_39", "|cff0070dd[Blade of Test]|r", 2, nil, false, ld, 3)
    LootEnh_ShowSoloBanner("loot", "Interface\\Icons\\inv_misc_rune_01", "|cffe6cc80[Quest Scroll]|r", 1, nil, true, ld, 6)
    LootEnh_ShowSoloBanner("gold", SOLO_GOLD_ICONS.gold, FormatGold(12345), nil, nil, false, gd)
    LootEnh_ShowSoloBanner("xp", SOLO_XP_ICON, "|cff8080ff+150 XP|r", nil, nil, false, xd)
    LootEnh_ShowSoloBanner("rep", SOLO_REP_ICON, "|cff40c040+75 Stormwind|r", nil, nil, false, rd)
end

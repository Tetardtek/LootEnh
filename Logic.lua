local framePool, activeFrames, historyLines, lootQueue = {}, {}, {}, {}

function LootEnh_RestackLootFrames()
    if not LootAnchor then return end
    local cfg = MonLootDB.lootFrame or {}
    local spacing = cfg.spacing or 5
    local growUp = (cfg.growDir or "up") == "up"

    for i, f in ipairs(activeFrames) do
        f:ClearAllPoints()
        local offset = (i - 1) * (70 + spacing)
        local animOff = f.leOffY or 0
        if growUp then
            f:SetPoint("BOTTOM", LootAnchor, "TOP", 0, offset + animOff)
        else
            f:SetPoint("TOP", LootAnchor, "BOTTOM", 0, -offset + animOff)
        end
    end
end

local function ShowNextFromQueue()
    local cfg = MonLootDB.lootFrame or {}
    local maxBars = cfg.maxBars or 4
    while #lootQueue > 0 and #activeFrames < maxBars do
        local item = table.remove(lootQueue, 1)
        -- For queued items with a real rid, recalculate remaining time
        local remaining = item.endT - GetTime()
        if remaining > 0 then
            LootEnh_ShowLootBar(item.rid, item.name, item.tex, item.link, remaining)
        end
        -- If expired, silently skip it
    end
end

local function DismissLootBar(f)
    LootEnh_AnimReset(f)
    f:Hide()
    for i, fr in ipairs(activeFrames) do
        if fr == f then
            table.remove(activeFrames, i)
            break
        end
    end
    table.insert(framePool, f)
    LootEnh_RestackLootFrames()
    ShowNextFromQueue()
end

-- Fade out then dismiss (falls back to instant when animations are off)
local function FadeOutLootBar(f)
    local style = (MonLootDB.lootFrame or {}).animStyle or "slide"
    if not LootEnh_BeginExit(f, style, DismissLootBar) then
        DismissLootBar(f)
    end
end

function LootEnh_AddToHistory(line)
    if not LootHistory then
        return
    end
    table.insert(historyLines, 1, "|cff888888[" .. date("%H:%M") .. "]|r " .. line)
    if #historyLines > 15 then
        table.remove(historyLines)
    end
    LootHistory.txt:SetText(table.concat(historyLines, "\n"))
end

function LootEnh_LootFilter(self, event, msg)
    if MonLootDB.filterMode == 1 or not msg then
        return false
    end
    local ld = L()
    local clean = msg:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local m = clean:lower()

    local isRoll = clean:find("Roll %-")
    local isWinner = m:find("won:")

    if isRoll or isWinner then
        local rItem = msg:match("for%s+(|Hitem.-|h%[.-%h%]|r)") or msg:match("won:%s+(|Hitem.-|h%[.-%h%]|r)") or ld.ITEM
        if isRoll then
            local name = clean:match("by%s+([^%s%]]+)") or clean:match("^([^%s]+)") or "???"
            local score = clean:match("(%d+)")
            local type = m:find("need") and "|cff00ff00Need|r" or "|cff00ccffGreed|r"
            LootEnh_AddToHistory(rItem .. " " .. name .. " : " .. score .. " (" .. type .. ")")
            if MonLootDB.filterMode >= 2 then
                if name:find("You") or name:find("vous") or name == UnitName("player") then
                    return false
                end
                return true
            end
        else
            local winner = clean:match("^([^%s]+)")
            local name = (winner:lower() == "you") and "|cff00ff00YOU|r" or winner
            LootEnh_AddToHistory(ld.WINNER .. " " .. name .. " " .. rItem)
            if MonLootDB.filterMode == 3 then
                return true
            end
        end
    end
    if m:find("selected") then
        return true
    end
    return false
end

-- Solo chat filters — per-module chatMode ("all" | "hideGray" | "hideAll")
local function SoloChatMode(modKey)
    local mod = MonLootDB.solo and MonLootDB.solo[modKey]
    return (mod and mod.chatMode) or "all"
end

function LootEnh_SoloLootFilter(self, event, msg)
    if not msg then return false end
    local m = msg:lower()

    -- Solo loot messages ("You receive loot:" / "Vous recevez")
    if m:find("^you receive loot") or m:find("^vous recevez") then
        local mode = SoloChatMode("loot")
        if mode == "hideAll" then
            return true
        end
        if mode == "hideGray" and msg:find("|cff9d9d9d") then
            return true
        end
    end

    -- Money messages ("You loot X Gold Y Silver Z Copper")
    if m:find("^you loot") and (m:find("gold") or m:find("silver") or m:find("copper")) then
        if SoloChatMode("gold") == "hideAll" then
            return true
        end
    end

    return false
end

function LootEnh_SoloMoneyFilter(self, event, msg)
    return SoloChatMode("gold") == "hideAll"
end

function LootEnh_SoloXPFilter(self, event, msg)
    return SoloChatMode("xp") == "hideAll"
end

function LootEnh_SoloRepFilter(self, event, msg)
    return SoloChatMode("rep") == "hideAll"
end

local function GetLootFrame()
    local f = table.remove(framePool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent);
        f:SetSize(280, 70)
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12
        });
        f:SetBackdropColor(0, 0, 0, 0.95)
        f.i = f:CreateTexture(nil, "ARTWORK");
        f.i:SetSize(40, 40);
        f.i:SetPoint("LEFT", 10, 0)
        f.i:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.ib = LootEnh_CreateIconBorder(f, f.i)
        -- Tooltip hover zone over icon
        f.tipZone = CreateFrame("Frame", nil, f)
        f.tipZone:SetSize(40, 40)
        f.tipZone:SetPoint("LEFT", 10, 0)
        f.tipZone:EnableMouse(true)
        f.tipZone:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if f.link and f.link:find("|Hitem:") then
                GameTooltip:SetHyperlink(f.link:match("(item:[%d:]+)"))
            else
                GameTooltip:SetText(f.itemName or "Unknown", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        f.tipZone:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        f.t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
        f.t:SetPoint("TOPLEFT", 60, -10);
        f.t:SetPoint("RIGHT", -10, 0);
        f.t:SetJustifyH("LEFT")
        f.s = CreateFrame("StatusBar", nil, f);
        f.s:SetSize(130, 8);
        f.s:SetPoint("TOPLEFT", 60, -25);
        f.s:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        f.s.bg = f.s:CreateTexture(nil, "BACKGROUND")
        f.s.bg:SetAllPoints()
        f.s.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        f.s.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
        local function B(rt, tx, p)
            local b = CreateFrame("Button", nil, f);
            b:SetSize(25, 25);
            b:SetNormalTexture(tx);
            b:SetPoint("BOTTOMRIGHT", -10 - (p * 30), 5)
            b:SetScript("OnClick", function()
                if f.rid then
                    RollOnLoot(f.rid, rt)
                end
                FadeOutLootBar(f)
            end);
            return b
        end
        f.b1 = B(0, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", 0);
        f.b2 = B(2, "Interface\\Buttons\\UI-GroupLoot-Coin-Up", 1);
        f.b3 = B(1, "Interface\\Buttons\\UI-GroupLoot-Dice-Up", 2)
    end
    return f
end

function LootEnh_RefreshActiveLootFrames()
    local cfg = MonLootDB.lootFrame or {}
    for _, f in ipairs(activeFrames) do
        f:SetFrameStrata(cfg.strata or "MEDIUM")
        f:SetScale(cfg.scale or 1.0)
        f:SetBackdropColor(0, 0, 0, cfg.alpha or 0.95)
    end
    LootEnh_RestackLootFrames()
end

function LootEnh_ShowLootBar(rid, name, tex, link, time)
    local cfg = MonLootDB.lootFrame or {}
    local maxBars = cfg.maxBars or 4

    -- Queue if at capacity
    if #activeFrames >= maxBars then
        table.insert(lootQueue, {
            rid = rid, name = name, tex = tex, link = link,
            endT = GetTime() + time
        })
        return
    end

    local f = GetLootFrame();
    f.rid = rid;
    f.link = link;
    f.itemName = name;
    f.i:SetTexture(tex);
    f.t:SetText(link or name)
    f.s:SetMinMaxValues(0, time);
    f.s:SetValue(time);
    f.endT = GetTime() + time

    -- Quality theming (icon border + timer bar tint)
    local quality = LootEnh_GetQualityFromLink(link or name)
    local qc = quality and LootEnh_QUALITY_COLORS[quality]
    f.quality = quality
    if qc and cfg.qualityIconBorder ~= false then
        f.ib:SetVertexColor(qc[1], qc[2], qc[3], 0.9)
        f.ib:Show()
    else
        f.ib:Hide()
    end
    if qc and cfg.qualityBar ~= false then
        f.s:SetStatusBarColor(qc[1], qc[2], qc[3])
    else
        f.s:SetStatusBarColor(0, 1, 0)
    end

    -- Apply loot frame settings
    f:SetFrameStrata(cfg.strata or "MEDIUM")
    f:SetScale(cfg.scale or 1.0)
    f:SetBackdropColor(0, 0, 0, cfg.alpha or 0.95)

    f:SetScript("OnUpdate", function(s)
        if LootEnh_AnimStep(s, LootEnh_RestackLootFrames) then return end
        local r = s.endT - GetTime()
        if r <= 0 then
            FadeOutLootBar(s)
        else
            s.s:SetValue(r)
        end
    end)

    -- Entry animation
    LootEnh_BeginEntry(f, cfg.animStyle or "slide", (cfg.growDir or "up") == "up", quality, cfg.scale or 1.0)

    table.insert(activeFrames, f);
    f:Show()
    LootEnh_RestackLootFrames()
end

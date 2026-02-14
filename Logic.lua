local framePool, activeFrames, historyLines, lootQueue = {}, {}, {}, {}

function RestackLootFrames()
    if not LootAnchor then return end
    local cfg = MonLootDB.lootFrame or {}
    local spacing = cfg.spacing or 5
    local growUp = (cfg.growDir or "up") == "up"

    for i, f in ipairs(activeFrames) do
        f:ClearAllPoints()
        local offset = (i - 1) * (70 + spacing)
        if growUp then
            f:SetPoint("BOTTOM", LootAnchor, "TOP", 0, offset)
        else
            f:SetPoint("TOP", LootAnchor, "BOTTOM", 0, -offset)
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
            ShowLootBar(item.rid, item.name, item.tex, item.link, remaining)
        end
        -- If expired, silently skip it
    end
end

local function DismissLootBar(f)
    f:Hide()
    for i, fr in ipairs(activeFrames) do
        if fr == f then
            table.remove(activeFrames, i)
            break
        end
    end
    table.insert(framePool, f)
    RestackLootFrames()
    ShowNextFromQueue()
end

function AddToHistory(line)
    if not LootHistory then
        return
    end
    table.insert(historyLines, 1, "|cff888888[" .. date("%H:%M") .. "]|r " .. line)
    if #historyLines > 15 then
        table.remove(historyLines)
    end
    LootHistory.txt:SetText(table.concat(historyLines, "\n"))
end

function LootFilter(self, event, msg)
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
            AddToHistory(rItem .. " " .. name .. " : " .. score .. " (" .. type .. ")")
            if MonLootDB.filterMode >= 2 then
                if name:find("You") or name:find("vous") or name == UnitName("player") then
                    return false
                end
                return true
            end
        else
            local winner = clean:match("^([^%s]+)")
            local name = (winner:lower() == "you") and "|cff00ff00YOU|r" or winner
            AddToHistory(ld.WINNER .. " " .. name .. " " .. rItem)
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

-- Solo chat filters
function SoloLootFilter(self, event, msg)
    if MonLootDB.soloFilterMode == 1 or not msg then return false end
    local m = msg:lower()

    -- Solo loot messages ("You receive loot:" / "Vous recevez")
    if m:find("^you receive loot") or m:find("^vous recevez") then
        if MonLootDB.soloFilterMode == 3 then
            return true
        end
        if MonLootDB.soloFilterMode == 2 then
            -- Clean: hide gray items (quality 0 = |cff9d9d9d)
            if msg:find("|cff9d9d9d") then
                return true
            end
        end
    end

    -- Money messages ("You loot X Gold Y Silver Z Copper")
    if m:find("^you loot") and (m:find("gold") or m:find("silver") or m:find("copper")) then
        if MonLootDB.soloFilterMode >= 2 then
            return true
        end
    end

    return false
end

function SoloXPFilter(self, event, msg)
    if MonLootDB.soloFilterMode == 3 then return true end
    return false
end

function SoloRepFilter(self, event, msg)
    if MonLootDB.soloFilterMode == 3 then return true end
    return false
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
        local function B(rt, tx, p)
            local b = CreateFrame("Button", nil, f);
            b:SetSize(25, 25);
            b:SetNormalTexture(tx);
            b:SetPoint("BOTTOMRIGHT", -10 - (p * 30), 5)
            b:SetScript("OnClick", function()
                if f.rid then
                    RollOnLoot(f.rid, rt)
                end
                DismissLootBar(f)
            end);
            return b
        end
        f.b1 = B(0, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", 0);
        f.b2 = B(2, "Interface\\Buttons\\UI-GroupLoot-Coin-Up", 1);
        f.b3 = B(1, "Interface\\Buttons\\UI-GroupLoot-Dice-Up", 2)
    end
    return f
end

function RefreshActiveLootFrames()
    local cfg = MonLootDB.lootFrame or {}
    for _, f in ipairs(activeFrames) do
        f:SetFrameStrata(cfg.strata or "MEDIUM")
        f:SetScale(cfg.scale or 1.0)
        f:SetBackdropColor(0, 0, 0, cfg.alpha or 0.95)
    end
    RestackLootFrames()
end

function ShowLootBar(rid, name, tex, link, time)
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
    f.s:SetStatusBarColor(0, 1, 0);
    f.endT = GetTime() + time

    -- Apply loot frame settings
    f:SetFrameStrata(cfg.strata or "MEDIUM")
    f:SetScale(cfg.scale or 1.0)
    f:SetBackdropColor(0, 0, 0, cfg.alpha or 0.95)

    f:SetScript("OnUpdate", function(s)
        local r = s.endT - GetTime()
        if r <= 0 then
            DismissLootBar(s)
        else
            s.s:SetValue(r)
        end
    end)
    table.insert(activeFrames, f);
    f:Show()
    RestackLootFrames()
end

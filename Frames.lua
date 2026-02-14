local function UpdateMinimapPos(btn, angle)
    local rad = math.rad(angle)
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(rad)), (80 * math.sin(rad)) - 52)
end

function CreateAddonFrames()
    LootAnchor = CreateFrame("Frame", "LootEnhAnchor", UIParent)
    LootAnchor:SetSize(200, 25);
    LootAnchor:SetPoint("CENTER", MonLootDB.anchorX, MonLootDB.anchorY)
    LootAnchor:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12
    })
    LootAnchor:SetBackdropColor(0, 0.4, 0.8, 0.6);
    LootAnchor:SetMovable(true);
    LootAnchor:EnableMouse(true)
    LootAnchor:RegisterForDrag("LeftButton")

    local ld = L()
    local anchorText = LootAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchorText:SetPoint("CENTER", 0, 0)
    anchorText:SetText(ld.ANCHOR_TEXT)

    LootAnchor:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("LootEnh", 0, 0.8, 1)
        GameTooltip:AddLine(ld.ANCHOR_TIP1, 1, 1, 1)
        GameTooltip:AddLine(ld.ANCHOR_TIP2, 1, 1, 1)
        GameTooltip:AddLine(ld.ANCHOR_TIP_SHIFT_HIDE, 1, 1, 1)
        GameTooltip:AddLine(ld.ANCHOR_TIP3, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    LootAnchor:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    LootAnchor:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            MonLootDB.showAnchor = false
            LootAnchor:Hide()
            SoloAnchor:Hide()
        end
    end)
    LootAnchor:SetScript("OnDragStart", LootAnchor.StartMoving)
    LootAnchor:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local cx, cy = s:GetCenter()
        local px, py = UIParent:GetCenter()
        local x, y = cx - px, cy - py
        s:ClearAllPoints()
        s:SetPoint("CENTER", x, y)
        MonLootDB.anchorX, MonLootDB.anchorY = x, y
    end)
    if not MonLootDB.showAnchor then
        LootAnchor:Hide()
    end

    -- Solo Anchor (green)
    SoloAnchor = CreateFrame("Frame", "LootEnhSoloAnchor", UIParent)
    SoloAnchor:SetSize(200, 25)
    SoloAnchor:SetPoint("CENTER", MonLootDB.soloAnchorX, MonLootDB.soloAnchorY)
    SoloAnchor:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12
    })
    SoloAnchor:SetBackdropColor(0, 0.6, 0.2, 0.6)
    SoloAnchor:SetMovable(true)
    SoloAnchor:EnableMouse(true)
    SoloAnchor:RegisterForDrag("LeftButton")

    local soloAnchorText = SoloAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soloAnchorText:SetPoint("CENTER", 0, 0)
    soloAnchorText:SetText(ld.SOLO_ANCHOR_TEXT)

    SoloAnchor:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("LootEnh Solo", 0, 0.8, 0.3)
        GameTooltip:AddLine(ld.ANCHOR_TIP1, 1, 1, 1)
        GameTooltip:AddLine(ld.ANCHOR_TIP_SHIFT_HIDE, 1, 1, 1)
        GameTooltip:AddLine(ld.SOLO_ANCHOR_TIP, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    SoloAnchor:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    SoloAnchor:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            MonLootDB.showAnchor = false
            LootAnchor:Hide()
            SoloAnchor:Hide()
        end
    end)
    SoloAnchor:SetScript("OnDragStart", SoloAnchor.StartMoving)
    SoloAnchor:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local cx, cy = s:GetCenter()
        local px, py = UIParent:GetCenter()
        local x, y = cx - px, cy - py
        s:ClearAllPoints()
        s:SetPoint("CENTER", x, y)
        MonLootDB.soloAnchorX, MonLootDB.soloAnchorY = x, y
    end)
    if not MonLootDB.showAnchor then
        SoloAnchor:Hide()
    end

    LootHistory = CreateFrame("Frame", "LootEnhHistory", UIParent)
    LootHistory:SetSize(300, 180);
    LootHistory:SetPoint("RIGHT", MonLootDB.histX, MonLootDB.histY)
    LootHistory:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12
    })
    LootHistory:SetBackdropColor(0, 0, 0, MonLootDB.histAlpha);
    LootHistory:SetMovable(true);
    LootHistory:EnableMouse(true)
    LootHistory:RegisterForDrag("LeftButton")
    LootHistory:SetScript("OnDragStart", LootHistory.StartMoving)
    LootHistory:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local cx, cy = s:GetCenter()
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        local x = cx - sw
        local y = cy - sh / 2
        s:ClearAllPoints()
        s:SetPoint("RIGHT", x, y)
        MonLootDB.histX, MonLootDB.histY = x, y
    end)
    LootHistory.txt = LootHistory:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    LootHistory.txt:SetPoint("TOPLEFT", 10, -10);
    LootHistory.txt:SetPoint("BOTTOMRIGHT", -10, 10);
    LootHistory.txt:SetJustifyH("LEFT");
    LootHistory.txt:SetJustifyV("TOP")
    if MonLootDB.hideHistory then
        LootHistory:Hide()
    end

    local btn = CreateFrame("Button", "LootEnhMinimapBtn", Minimap)
    btn:SetSize(31, 31);
    btn:SetFrameLevel(10);
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = btn:CreateTexture(nil, "BACKGROUND");
    bg:SetSize(20, 20);
    bg:SetTexture("Interface\\Icons\\inv_misc_dice_01");
    bg:SetPoint("CENTER")
    local bdr = btn:CreateTexture(nil, "OVERLAY");
    bdr:SetSize(53, 53);
    bdr:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
    bdr:SetPoint("TOPLEFT")

    btn:RegisterForDrag("LeftButton");
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnEnter", function(self)
        local ld = L()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ld.TIP_TITLE, 0, 0.8, 1)
        GameTooltip:AddDoubleLine(ld.TIP_LEFT, ld.TIP_LEFT_DESC, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(ld.TIP_SHIFT_LEFT, ld.TIP_SHIFT_LEFT_DESC, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(ld.TIP_RIGHT, ld.TIP_RIGHT_DESC, 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition();
            local xc, yc = Minimap:GetCenter();
            local s = Minimap:GetEffectiveScale()
            MonLootDB.minimapPos = math.deg(math.atan2(y / s - yc, xc - x / s))
            UpdateMinimapPos(self, MonLootDB.minimapPos)
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    btn:SetScript("OnClick", function(self, b)
        if b == "LeftButton" and IsShiftKeyDown() then
            MonLootDB.showAnchor = not MonLootDB.showAnchor
            if MonLootDB.showAnchor then
                LootAnchor:Show()
                SoloAnchor:Show()
            else
                LootAnchor:Hide()
                SoloAnchor:Hide()
            end
        elseif b == "LeftButton" then
            MonLootDB.hideHistory = not MonLootDB.hideHistory
            if MonLootDB.hideHistory then
                LootHistory:Hide()
            else
                LootHistory:Show()
            end
        else
            InterfaceOptionsFrame_OpenToCategory(LootEnhOptionsPanel);
            InterfaceOptionsFrame_OpenToCategory(LootEnhOptionsPanel)
        end
    end)
    UpdateMinimapPos(btn, MonLootDB.minimapPos)
end

local function UpdateMinimapPos(btn, angle)
    local rad = math.rad(angle)
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(rad)), (80 * math.sin(rad)) - 52)
end

-- Toutes les ancres se montrent et se cachent ENSEMBLE : c'est un mode
-- « placement », pas un réglage par ancre. Passer par cette liste plutôt que
-- de nommer les ancres une par une évite d'en oublier une lors d'un ajout —
-- il y a trois points d'appel (Shift+clic sur une ancre, bouton minimap, /ll).
local anchors = {}

function LootEnh_SetAnchorsShown(shown)
    MonLootDB.showAnchor = (shown and true) or false
    for _, a in ipairs(anchors) do
        if shown then a:Show() else a:Hide() end
    end
end

-- Fabrique d'ancre : les trois ne diffèrent que par leur couleur, leur clé de
-- position et leur infobulle. `tip` est une liste de { texte, r, g, b }.
local function CreateAnchor(frameName, xKey, yKey, color, label, tipTitle, tipColor, tip)
    local a = CreateFrame("Frame", frameName, UIParent)
    a:SetSize(200, 25)
    a:SetPoint("CENTER", MonLootDB[xKey], MonLootDB[yKey])
    a:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12
    })
    a:SetBackdropColor(color[1], color[2], color[3], 0.6)
    a:SetMovable(true)
    a:EnableMouse(true)
    a:RegisterForDrag("LeftButton")

    local txt = a:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("CENTER", 0, 0)
    txt:SetText(label)

    a:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tipTitle, tipColor[1], tipColor[2], tipColor[3])
        for _, line in ipairs(tip) do
            GameTooltip:AddLine(line[1], line[2] or 1, line[3] or 1, line[4] or 1)
        end
        GameTooltip:Show()
    end)
    a:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    a:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            LootEnh_SetAnchorsShown(false)
        end
    end)
    a:SetScript("OnDragStart", a.StartMoving)
    a:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local cx, cy = s:GetCenter()
        local px, py = UIParent:GetCenter()
        local x, y = cx - px, cy - py
        s:ClearAllPoints()
        s:SetPoint("CENTER", x, y)
        MonLootDB[xKey], MonLootDB[yKey] = x, y
    end)

    anchors[#anchors + 1] = a
    return a
end

function LootEnh_CreateAddonFrames()
    local ld = L()

    LootAnchor = CreateAnchor("LootEnhAnchor", "anchorX", "anchorY",
        { 0, 0.4, 0.8 }, ld.ANCHOR_TEXT, "LootEnh", { 0, 0.8, 1 }, {
            { ld.ANCHOR_TIP1 },
            { ld.ANCHOR_TIP2 },
            { ld.ANCHOR_TIP_SHIFT_HIDE },
            { ld.ANCHOR_TIP3, 0.7, 0.7, 0.7 },
        })

    SoloAnchor = CreateAnchor("LootEnhSoloAnchor", "soloAnchorX", "soloAnchorY",
        { 0, 0.6, 0.2 }, ld.SOLO_ANCHOR_TEXT, "LootEnh Solo", { 0, 0.8, 0.3 }, {
            { ld.ANCHOR_TIP1 },
            { ld.ANCHOR_TIP_SHIFT_HIDE },
            { ld.SOLO_ANCHOR_TIP, 0.7, 0.7, 0.7 },
        })

    -- Ancre de progression (or / XP / réputation). Séparée du butin parce que
    -- ces flux se disputaient le même plafond de barres : un gain d'XP pouvait
    -- chasser un objet épique de l'écran. La globale est créée par CreateFrame
    -- sous le nom passé ici — préfixée, contrairement aux deux ci-dessus qui
    -- restent à renommer.
    CreateAnchor("LootEnhProgressAnchor", "progressAnchorX", "progressAnchorY",
        { 0.7, 0.5, 0 }, ld.PROGRESS_ANCHOR_TEXT, "LootEnh Progression", { 1, 0.8, 0.2 }, {
            { ld.ANCHOR_TIP1 },
            { ld.ANCHOR_TIP_SHIFT_HIDE },
            { ld.PROGRESS_ANCHOR_TIP, 0.7, 0.7, 0.7 },
        })

    if not MonLootDB.showAnchor then
        LootEnh_SetAnchorsShown(false)
    end

    -- La fenêtre des jets vit dans HistoryFrame.lua : elle a désormais des
    -- onglets, du défilement et un modèle de données, ce qui n'avait plus rien
    -- à faire au milieu de la fabrique d'ancres.
    LootEnh_CreateHistoryFrame()

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
            LootEnh_SetAnchorsShown(not MonLootDB.showAnchor)
        elseif b == "LeftButton" then
            LootEnh_ToggleHistory()
        else
            InterfaceOptionsFrame_OpenToCategory(LootEnhOptionsPanel);
            InterfaceOptionsFrame_OpenToCategory(LootEnhOptionsPanel)
        end
    end)
    UpdateMinimapPos(btn, MonLootDB.minimapPos)
end

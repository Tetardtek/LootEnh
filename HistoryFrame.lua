-- HistoryFrame — la fenêtre des jets, en deux onglets.
--
--   « En cours »  : les jets ouverts, avec le décompte des votes qui se remplit
--                   en direct. Survol d'une ligne → qui a voté quoi.
--   « Historique » : les jets clos, du plus récent au plus ancien, avec le
--                   gagnant. Persisté dans MonLootDB.rollHistory.
--
-- Remplace l'ancien panneau : une unique FontString de 15 lignes concaténées,
-- sans défilement (le README promettait « scrollable » — ce ne l'était pas) et
-- sans structure exploitable. Le nom global `LootHistory` et les clés de
-- position histX / histY sont conservés : Profiles.lua et Panel_Display.lua les
-- manipulent déjà, les renommer aurait débordé du périmètre.
--
-- Les données viennent toutes de RollTracker.lua — cette fenêtre ne parse rien.

local FRAME_W, FRAME_H = 360, 330
local PAD = 10
local SCROLL_W = 312
-- 40 px et pas 34 : les boutons de jet font 20 px ancrés en bas, le décompte du
-- temps est en haut à droite — sous 40 px les deux se chevauchaient dans la
-- même colonne, ce qui rendait le temps illisible.
local ROW_H, ROWS = 40, 6

local rows = {}
local activeTab = 1
local scroll

local function FmtCountdown(s)
    if s < 0 then s = 0 end
    return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

local function CurrentList()
    if activeTab == 1 then
        return LootEnh_GetActiveRolls()
    end
    return LootEnh_GetRollHistory()
end

-- ---------------------------------------------------------------------------
-- Lignes
-- ---------------------------------------------------------------------------

local function ShowVoterTooltip(row)
    local data = row.data
    if not data then return end
    local ld = L()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(data.link or data.name or ld.ITEM, 1, 1, 1)
    local lines = LootEnh_RollVoterLines(data)
    if #lines == 0 then
        GameTooltip:AddLine(ld.HIST_NO_VOTE, 0.6, 0.6, 0.6)
    else
        for _, l in ipairs(lines) do
            GameTooltip:AddLine(l[1], l[2], l[3], l[4])
        end
    end
    if data.groupSize then
        GameTooltip:AddLine(" ")
        local _, total = LootEnh_RollTally(data)
        GameTooltip:AddLine(string.format(ld.HIST_VOTED, total, data.groupSize), 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(SCROLL_W, ROW_H)
    row:EnableMouse(true)

    -- Voile de résultat, sous le survol : vert si on gagne, rouge sinon, gris si
    -- tout le monde a passé. Son opacité décroît sur LootEnh_ROLL_LINGER, ce qui
    -- fait de la disparition de la ligne une fin, et non un escamotage.
    row.flash = row:CreateTexture(nil, "BACKGROUND")
    row.flash:SetAllPoints()
    row.flash:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.flash:Hide()

    row.hl = row:CreateTexture(nil, "BORDER")
    row.hl:SetAllPoints()
    row.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.hl:SetVertexColor(1, 1, 1, 0.07)
    row.hl:Hide()

    -- Icône centrée sur la hauteur : elle porte les deux lignes de texte plutôt
    -- que de s'aligner sur la première.
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", 36, -5)
    row.name:SetPoint("RIGHT", -58, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetHeight(12)

    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.right:SetPoint("TOPRIGHT", -4, -5)
    row.right:SetJustifyH("RIGHT")

    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.sub:SetPoint("TOPLEFT", 38, -22)
    -- La droite de la seconde ligne est réservée aux boutons de jet : le
    -- décompte doit s'arrêter avant, sinon il passerait dessous.
    row.sub:SetPoint("RIGHT", -96, 0)
    row.sub:SetJustifyH("LEFT")

    -- Jeter depuis la fenêtre. Ce n'est pas qu'un raccourci : au-delà du plafond
    -- de barres, les jets partent en file d'attente SANS barre — il n'existait
    -- aucun autre endroit où voter dessus.
    --
    -- Les boutons ne disparaissent PAS une fois qu'on a voté, volontairement.
    -- Sur un objet lié-au-ramassage, RollOnLoot n'enregistre rien : il ouvre une
    -- confirmation. Refuser cette confirmation laisserait un joueur convaincu
    -- d'avoir voté, sans recours — c'est exactement le défaut corrigé sur la
    -- barre le 02/08. Recliquer après un vote effectif est sans conséquence :
    -- le serveur ignore le second.
    row.rollBtns = {}
    for _, rt in ipairs({ 0, 3, 2, 1 }) do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(20, 20)
        b:SetNormalTexture(LootEnh_ROLL_ICON[rt])
        b:Hide()
        b:SetScript("OnClick", function()
            local data = row.data
            if not data or not data.rid then return end
            -- Relu au clic, jamais mémorisé : entre le dessin de la ligne et le
            -- clic, le jet a pu être annulé ou l'objet ramassé par le maître du
            -- butin.
            local allowed = LootEnh_RollAllowed(data.rid)
            if not allowed or not allowed[rt] then
                LootEnh_RefreshHistoryFrame()
                return
            end
            -- Le marquage est fait par l'accroche sur RollOnLoot (RollTracker).
            RollOnLoot(data.rid, rt)
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LootEnh_RollLabel(rt), 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.rollBtns[rt] = b
    end

    -- Survol de l'objet lui-même — icône et nom — pour son infobulle de jeu.
    -- Distinct du survol de la ligne, qui liste les votants : ce sont deux
    -- questions différentes (« c'est quoi, cet objet ? » contre « qui l'a
    -- demandé ? »), et les mélanger obligeait à choisir laquelle sacrifier.
    -- La zone épouse la largeur réelle du texte, ajustée à chaque rendu.
    row.itemZone = CreateFrame("Frame", nil, row)
    row.itemZone:SetPoint("TOPLEFT", 0, -2)
    row.itemZone:SetHeight(22)
    row.itemZone:SetWidth(36)
    row.itemZone:EnableMouse(true)
    row.itemZone:SetScript("OnEnter", function(self)
        local d = row.data
        if not d then return end
        row.hl:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local itemString = d.link and d.link:match("(item:[%d:%-]+)")
        if itemString then
            GameTooltip:SetHyperlink(itemString)
        else
            GameTooltip:SetText(d.name or L().ITEM, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    row.itemZone:SetScript("OnLeave", function()
        row.hl:Hide()
        GameTooltip:Hide()
    end)

    row:SetScript("OnEnter", function(self)
        self.hl:Show()
        ShowVoterTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hl:Hide()
        GameTooltip:Hide()
    end)

    row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(index - 1) * ROW_H)
    return row
end

-- Même règle que sur la barre : n'afficher que les jets réellement permis, et
-- les resserrer sans trou. Un emplacement vide ferait cliquer à côté ; un bouton
-- affiché alors qu'il est refusé fait perdre le jet.
local function LayoutRowButtons(row, allowed, myVote)
    local p = 0
    for _, rt in ipairs({ 0, 3, 2, 1 }) do
        local b = row.rollBtns[rt]
        if allowed and allowed[rt] then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMRIGHT", -4 - (p * 22), 4)
            -- Notre propre choix reste lisible d'un coup d'œil : les autres
            -- s'effacent sans disparaître, donc restent cliquables.
            b:SetAlpha(myVote == nil and 1 or (rt == myVote and 1 or 0.35))
            b:Show()
            p = p + 1
        else
            b:Hide()
        end
    end
end

-- Rendu du résultat d'un jet tranché. Partagé par les deux onglets : le même
-- jet est décrit de la même façon selon qu'on le voit s'achever ou qu'on le
-- relit plus tard.
local function ResultText(e, ld)
    if e.allPassed then
        return "|cff888888" .. ld.HIST_ALL_PASSED .. "|r"
    end
    local winner, rt, sc = LootEnh_RollWinnerInfo(e)
    if not winner then
        if e.auto and e.myVote then
            return "|cff00ccff" .. string.format(ld.HIST_AUTO_ROLL, LootEnh_RollLabel(e.myVote)) .. "|r"
        end
        local tally = LootEnh_RollTallyText(e, 12)
        return tally ~= "" and tally or ("|cff777777" .. ld.HIST_UNKNOWN .. "|r")
    end
    -- L'icône se place contre le nom, pas en tête de ligne : elle qualifie le
    -- jet du gagnant, elle ne décrit pas la ligne entière.
    local icon = rt and string.format("|T%s:14:14|t ", LootEnh_ROLL_ICON[rt]) or ""
    local score = sc and (" |cff777777(" .. sc .. ")|r") or ""
    -- Le préfixe « Gagnant : » lève une ambiguïté réelle : sans lui, un nom
    -- précédé d'une icône de jet se lit comme un votant parmi d'autres.
    return "|cff999999" .. ld.WINNER .. "|r " .. icon .. "|cffffd100" .. winner .. "|r" .. score
end

-- La zone de survol de l'objet doit suivre la longueur du nom : figée, elle
-- couvrirait du vide à droite des noms courts et manquerait la fin des longs.
local function SyncItemZone(row)
    row.itemZone:SetWidth(36 + (row.name:GetStringWidth() or 0) + 4)
end

local function FillActive(row, r)
    local ld = L()
    row.icon:SetTexture(r.tex)
    row.name:SetText(r.link or r.name or ld.ITEM)
    SyncItemZone(row)

    if r.resolved then
        -- Le jet est tranché : plus de décompte à afficher, plus rien à cliquer.
        local k = 1 - ((GetTime() - r.resolvedT) / LootEnh_ROLL_LINGER)
        if k < 0 then k = 0 end
        if r.allPassed then
            row.flash:SetVertexColor(0.55, 0.55, 0.55, 0.30 * k)
        elseif r.winner == UnitName("player") then
            row.flash:SetVertexColor(0.10, 1.00, 0.20, 0.38 * k)
        else
            row.flash:SetVertexColor(1.00, 0.20, 0.20, 0.30 * k)
        end
        row.flash:Show()
        row.right:SetText("")
        row.sub:SetText(ResultText(r, ld))
        LayoutRowButtons(row, nil, nil)
        return
    end

    row.flash:Hide()
    row.right:SetText(FmtCountdown(r.endT - GetTime()))
    row.right:SetTextColor(0.8, 0.8, 0.8)

    local tally = LootEnh_RollTallyText(r, 12)
    local _, total = LootEnh_RollTally(r)
    local myVote = LootEnh_RollMyVote(r)
    local mine = myVote and ("   |cffffd100"
        .. string.format(r.auto and ld.HIST_AUTO_ROLL or ld.HIST_YOUR_ROLL, LootEnh_RollLabel(myVote))
        .. "|r") or ""
    if tally == "" then
        row.sub:SetText("|cff777777" .. ld.HIST_NO_VOTE .. "|r" .. mine)
    else
        row.sub:SetText(string.format("%s   |cff777777%d/%d|r%s", tally, total, r.groupSize or 1, mine))
    end

    LayoutRowButtons(row, LootEnh_RollAllowed(r.rid), myVote)
end

local function FillHistory(row, e)
    local ld = L()
    -- Un jet clos ne se joue plus : aucun bouton dans cet onglet.
    LayoutRowButtons(row, nil, nil)
    row.flash:Hide()
    row.icon:SetTexture(e.tex)
    row.name:SetText(e.link or e.name or ld.ITEM)
    SyncItemZone(row)
    row.right:SetText(date("%H:%M", e.t))
    row.right:SetTextColor(0.55, 0.55, 0.55)
    row.sub:SetText(ResultText(e, ld))
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------

function LootEnh_RefreshHistoryFrame()
    if not LootHistory or not LootHistory:IsShown() then return end
    local ld = L()
    local list = CurrentList()

    FauxScrollFrame_Update(scroll, #list, ROWS, ROW_H)
    local offset = FauxScrollFrame_GetOffset(scroll)

    for i = 1, ROWS do
        local row = rows[i]
        local item = list[i + offset]
        if item then
            row.data = item
            if activeTab == 1 then FillActive(row, item) else FillHistory(row, item) end
            row:Show()
        else
            row.data = nil
            row:Hide()
        end
    end

    if #list == 0 then
        LootHistory.empty:SetText(activeTab == 1 and ld.HIST_EMPTY_ACTIVE or ld.HIST_EMPTY_LOG)
        LootHistory.empty:Show()
    else
        LootHistory.empty:Hide()
    end

    LootHistory.tab1:SetLabel(string.format("%s (%d)", ld.HIST_TAB_ACTIVE, #LootEnh_GetActiveRolls()))
    LootHistory.footer:SetText(string.format(ld.HIST_FOOTER, #LootEnh_GetRollHistory()))
end

local function SelectTab(index)
    activeTab = index
    if MonLootDB then MonLootDB.histTab = index end
    LootHistory.tab1:SetActive(index == 1)
    LootHistory.tab2:SetActive(index == 2)
    -- Les deux onglets ne partagent pas leur longueur : rester à l'offset de
    -- l'un en basculant sur l'autre afficherait une liste vide alors qu'elle ne
    -- l'est pas.
    local bar = _G[scroll:GetName() .. "ScrollBar"]
    if bar then bar:SetValue(0) end
    if FauxScrollFrame_SetOffset then FauxScrollFrame_SetOffset(scroll, 0) end
    LootEnh_RefreshHistoryFrame()
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

local function CreateTab(parent, index, x, onClick)
    local b = CreateFrame("Button", "LootEnhHistoryTab" .. index, parent)
    b:SetSize(120, 22)
    b:SetPoint("TOPLEFT", PAD + x, -32)
    LootEnh_Backdrop(b):SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    b.label = fs
    -- SetLabel, pas SetText : Button:SetText existe déjà côté Blizzard et
    -- l'écraser sur un widget natif est le genre de collision que cet addon a
    -- déjà payé une fois (widgets des deux sections d'affichage, e6ffe75).
    b.SetLabel = function(self, t) self.label:SetText(t) end
    b.SetActive = function(self, on)
        if on then
            self:SetBackdropColor(0.25, 0.25, 0.28, 0.95)
            self.label:SetTextColor(1, 0.82, 0)
        else
            self:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
            self.label:SetTextColor(0.55, 0.55, 0.55)
        end
    end
    b:SetScript("OnClick", onClick)
    return b
end

function LootEnh_CreateHistoryFrame()
    local ld = L()

    local f = CreateFrame("Frame", "LootEnhHistory", UIParent)
    LootHistory = f
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("RIGHT", MonLootDB.histX, MonLootDB.histY)
    LootEnh_Backdrop(f):SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, MonLootDB.histAlpha)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local cx, cy = s:GetCenter()
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        s:ClearAllPoints()
        local x, y = cx - sw, cy - sh / 2
        s:SetPoint("RIGHT", x, y)
        MonLootDB.histX, MonLootDB.histY = x, y
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -11)
    title:SetText(ld.HIST_TITLE)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() LootEnh_ToggleHistory(true) end)

    scroll = CreateFrame("ScrollFrame", "LootEnhHistoryScroll", f, "FauxScrollFrameTemplate")
    scroll:SetSize(SCROLL_W, ROWS * ROW_H)
    scroll:SetPoint("TOPLEFT", PAD, -60)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, LootEnh_RefreshHistoryFrame)
    end)

    for i = 1, ROWS do
        rows[i] = CreateRow(f, i)
    end

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)

    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.footer:SetPoint("BOTTOMLEFT", PAD + 2, 8)

    f.tab1 = CreateTab(f, 1, 0, function() SelectTab(1) end)
    f.tab2 = CreateTab(f, 2, 124, function() SelectTab(2) end)
    f.tab2:SetLabel(ld.HIST_TAB_LOG)

    -- Le décompte des jets en cours doit s'écouler seul : aucun événement n'est
    -- émis entre deux votes. Le pas est volontairement lâche — la seconde
    -- affichée n'a pas besoin d'être rafraîchie 60 fois par seconde.
    f.elapsed = 0
    f:SetScript("OnUpdate", function(s, e)
        s.elapsed = s.elapsed + e
        -- 0.1 s et non 0.2 : le voile de résultat s'estompe sur ces images-là,
        -- et un fondu à 5 images par seconde se voit saccader.
        if s.elapsed < 0.1 then return end
        s.elapsed = 0
        local swept = LootEnh_RollSweep()
        if activeTab == 1 or swept then
            LootEnh_RefreshHistoryFrame()
        end
    end)

    f:SetScript("OnShow", LootEnh_RefreshHistoryFrame)

    SelectTab(MonLootDB.histTab == 2 and 2 or 1)

    if MonLootDB.hideHistory then
        f:Hide()
    end
end

-- Bascule unique. Le toggle était écrit trois fois (bouton minimap, /lh, et le
-- bouton de fermeture n'existait pas) — trois occasions de désynchroniser
-- l'état enregistré et l'état affiché.
function LootEnh_ToggleHistory(forceHide)
    if not LootHistory then return end
    if forceHide then
        MonLootDB.hideHistory = true
    else
        MonLootDB.hideHistory = not MonLootDB.hideHistory
    end
    if MonLootDB.hideHistory then
        LootHistory:Hide()
    else
        LootHistory:Show()
        LootEnh_RefreshHistoryFrame()
    end
end

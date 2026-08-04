local framePool, activeFrames, lootQueue = {}, {}, {}

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

-- Décompte des votes porté par la barre : « deux Besoin, une Cupidité » se lit
-- sans quitter des yeux l'objet sur lequel on hésite. Appelé par RollTracker à
-- chaque vote reçu, donc potentiellement pour un jet qui n'a pas de barre
-- (auto-roll, file d'attente, barres désactivées) — d'où la recherche silencieuse.
function LootEnh_UpdateBarTally(rid)
    if not rid then return end
    for _, f in ipairs(activeFrames) do
        if f.rid == rid then
            local roll = LootEnh_GetRoll(rid)
            f.tally:SetText(roll and LootEnh_RollTallyText(roll, 12) or "")
            return
        end
    end
end

function LootEnh_LootFilter(self, event, msg)
    -- Alimente le modèle AVANT toute décision d'affichage : un message masqué
    -- du chat doit malgré tout être compté. C'était le défaut de la version
    -- précédente — les « a choisi Besoin » étaient filtrés sans être lus.
    if LootEnh_RollParse then LootEnh_RollParse(msg) end

    if MonLootDB.filterMode == 1 or not msg then
        return false
    end
    -- Ce bloc ne décide QUE de la visibilité dans le chat. Il n'extrait plus le
    -- contenu du message : c'est RollTracker qui le fait, à partir des formats
    -- de locale plutôt que de mots anglais en dur. Les heuristiques ci-dessous
    -- restent volontairement telles quelles — le filtrage est un réglage éprouvé
    -- du joueur, pas le périmètre de ce chantier.
    local clean = msg:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local m = clean:lower()

    if clean:find("Roll %-") then
        if MonLootDB.filterMode >= 2 then
            local name = clean:match("by%s+([^%s%]]+)") or clean:match("^([^%s]+)") or "???"
            if name:find("You") or name:find("vous") or name == UnitName("player") then
                return false
            end
            return true
        end
    elseif m:find("won:") and MonLootDB.filterMode == 3 then
        return true
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

-- Ordre de placement, de la DROITE vers la gauche. Lu de gauche à droite ça
-- donne Besoin, Cupidité, Désenchanter, Passer : exactement l'ordre de la
-- fenêtre native de WoW. Le geste appris ne change pas quand LootEnh la
-- remplace.
local ROLL_ORDER = { 0, 3, 2, 1 }

-- Affiche les seuls jets que le serveur autorise sur cet objet, resserrés sans
-- trou. Un emplacement laissé vide ferait cliquer à côté ; un bouton affiché
-- alors qu'il est refusé fait perdre le jet (c'était le cas de Besoin).
local function LayoutRollButtons(f)
    local p = 0
    for _, rt in ipairs(ROLL_ORDER) do
        local b = f.rollBtns[rt]
        if f.allowed and f.allowed[rt] then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMRIGHT", -10 - (p * 30), 5)
            b:Show()
            p = p + 1
        else
            b:Hide()
        end
    end
end

local function GetLootFrame()
    local f = table.remove(framePool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent);
        f:SetSize(280, 70)
        LootEnh_Backdrop(f):SetBackdrop({
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
        -- Décompte des votes des autres joueurs, sous la barre de temps. Placé
        -- à gauche : les boutons occupent la droite (jusqu'à 4 × 30 px), et
        -- empiéter dessus ferait cliquer à côté sur un objet à quatre choix.
        f.tally = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.tally:SetPoint("BOTTOMLEFT", 60, 9)
        f.tally:SetJustifyH("LEFT")
        -- Zone de survol dédiée : le détail nominatif ne tient pas sur la barre,
        -- mais « qui a pris Besoin » est justement ce qu'on veut savoir avant de
        -- cliquer.
        f.tallyZone = CreateFrame("Frame", nil, f)
        f.tallyZone:SetSize(92, 18)
        f.tallyZone:SetPoint("BOTTOMLEFT", 58, 5)
        f.tallyZone:EnableMouse(true)
        f.tallyZone:SetScript("OnEnter", function(self)
            local roll = f.rid and LootEnh_GetRoll(f.rid)
            local lines = roll and LootEnh_RollVoterLines(roll)
            if not lines or #lines == 0 then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(f.itemName or "", 1, 1, 1)
            for _, l in ipairs(lines) do
                GameTooltip:AddLine(l[1], l[2], l[3], l[4])
            end
            GameTooltip:Show()
        end)
        f.tallyZone:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        -- Un bouton par type de jet. Le placement est fait plus tard par
        -- LayoutRollButtons : il dépend de ce que le serveur autorise sur CET
        -- objet, donc il ne peut pas être figé à la création.
        local function B(rt, tx)
            local b = CreateFrame("Button", nil, f);
            b:SetSize(25, 25);
            b:SetNormalTexture(tx);
            b:SetScript("OnClick", function()
                if not f.rid then return end

                -- Le jet est relu au moment du clic, pas à l'affichage : entre
                -- les deux, il a pu être annulé (objet parti, groupe dissous)
                -- ou l'action refusée. Sans cette relecture, on fermait la
                -- barre sur un RollOnLoot que le serveur ignorait — et comme
                -- la fenêtre native est désenregistrée quand LootEnh prend la
                -- main, il ne restait AUCUN moyen de jeter autrement : plus de
                -- boutons, et le décompte à attendre pour rien.
                local alive, _, _, _, _, cN, cG, cD = GetLootRollItemInfo(f.rid)
                if not alive then
                    FadeOutLootBar(f)   -- le jet n'existe plus : la barre ment
                    return
                end
                local allowed = (rt == 0)                 -- Passer : toujours permis
                             or (rt == 1 and cN)
                             or (rt == 2 and cG)
                             or (rt == 3 and cD)
                if not allowed then return end   -- on NE ferme PAS : les autres choix restent

                -- Le suivi n'est pas notifié ici : RollTracker accroche
                -- RollOnLoot elle-même, donc ce chemin est déjà couvert, au même
                -- titre que la fenêtre native ou une macro.
                RollOnLoot(f.rid, rt)

                -- La barre n'est volontairement PAS fermée ici. Sur un objet
                -- lié-au-ramassage, RollOnLoot n'enregistre rien : il ouvre une
                -- confirmation (CONFIRM_LOOT_ROLL). Refuser cette confirmation
                -- laissait le joueur sans barre ET sans jet — impossible de
                -- revoter, décompte à attendre pour rien.
                -- On attend donc CANCEL_LOOT_ROLL, que le serveur envoie quand
                -- le jet est réellement clos : c'est exactement ce que fait la
                -- fenêtre native de WoW, qui ne se cache pas non plus au clic.
                -- Filet de sécurité si le serveur ne l'envoie pas : le minuteur
                -- de la barre la retire de toute façon à expiration.
            end);
            return b
        end
        -- Indexés par rollType, l'entier attendu par RollOnLoot.
        f.rollBtns = {
            [0] = B(0, "Interface\\Buttons\\UI-GroupLoot-Pass-Up"),
            [1] = B(1, "Interface\\Buttons\\UI-GroupLoot-Dice-Up"),
            [2] = B(2, "Interface\\Buttons\\UI-GroupLoot-Coin-Up"),
            [3] = B(3, "Interface\\Buttons\\UI-GroupLoot-DE-Up"),
        }
    end
    return f
end

-- Retire la barre d'un jet annulé côté serveur (objet ramassé par le maître du
-- butin, groupe dissous, expiration). Sans ça la barre finissait son décompte
-- dans le vide et proposait des boutons qui ne menaient plus nulle part.
-- La file d'attente est purgée aussi : un jet annulé ne doit pas remonter.
function LootEnh_CancelLootBar(rid)
    if not rid then return end
    for i = #lootQueue, 1, -1 do
        if lootQueue[i].rid == rid then
            table.remove(lootQueue, i)
        end
    end
    for _, f in ipairs(activeFrames) do
        if f.rid == rid then
            f.rid = nil          -- coupe l'action avant l'animation de sortie
            FadeOutLootBar(f)
            return
        end
    end
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

    -- Les capacités sont relues ICI plutôt que transmises depuis Core : c'est
    -- la seule façon qu'elles décrivent l'état du jet au moment où la barre
    -- s'affiche. Une barre sortie de la file d'attente peut l'être plusieurs
    -- secondes après l'événement, et un paramètre transporté serait périmé.
    local _, _, _, _, _, canNeed, canGreed, canDE = GetLootRollItemInfo(rid)
    f.allowed = { [0] = true, [1] = canNeed, [2] = canGreed, [3] = canDE }
    LayoutRollButtons(f)

    -- Une barre sortie de la file d'attente peut arriver alors que des joueurs
    -- ont déjà voté : on repart de l'état du modèle, jamais de zéro.
    local roll = LootEnh_GetRoll(rid)
    f.tally:SetText(roll and LootEnh_RollTallyText(roll, 12) or "")

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

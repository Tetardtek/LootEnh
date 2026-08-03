-- RollTracker — modèle unique des jets de groupe : QUI a voté QUOI sur QUEL objet.
--
-- Deux surfaces le consomment, et c'est la raison d'être du fichier :
--   • la barre de jet (Logic.lua)  → le décompte Besoin / Cupidité / … en cours
--   • la fenêtre à onglets (HistoryFrame.lua) → le détail par joueur, puis le bilan
-- Sans modèle partagé, les deux auraient parsé le chat chacune de leur côté et
-- auraient divergé à la première correction.
--
-- Le client 3.3.5 n'expose AUCUNE API pour connaître le vote des autres joueurs :
-- GetLootRollItemInfo ne décrit que ce que *nous* avons le droit de faire. La
-- seule source est le chat système. C'est fragile par nature, donc :
--   • les motifs sont construits à partir des globales de locale (LOOT_ROLL_*),
--     jamais écrits en anglais en dur — sinon rien ne fonctionne sur client FR ;
--   • une globale absente désactive proprement son motif au lieu de casser ;
--   • `/lt roll` affiche les messages bruts et ce qui a été reconnu, pour vérifier
--     sur du réel plutôt que sur une hypothèse.

local active = {}      -- jets en cours, du plus ancien au plus récent
local byRid = {}       -- rid → jet
local recent = {}      -- itemKey → { entry, t } : entrées archivées enrichissables
local debugOn = false

-- Ordre d'affichage : Besoin, Cupidité, Désenchanter, Passer — celui de la
-- fenêtre native, déjà retenu pour les boutons de la barre (Logic.lua).
LootEnh_ROLL_ORDER_DISPLAY = { 1, 2, 3, 0 }

LootEnh_ROLL_ICON = {
    [0] = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
    [1] = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    [2] = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    [3] = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
}

LootEnh_ROLL_COLOR = {
    [0] = { 0.55, 0.55, 0.55 },
    [1] = { 0.10, 1.00, 0.10 },
    [2] = { 0.20, 0.80, 1.00 },
    [3] = { 1.00, 0.55, 0.10 },
}

local function Hex(rt)
    local c = LootEnh_ROLL_COLOR[rt] or { 1, 1, 1 }
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

function LootEnh_RollLabel(rt)
    local ld = L()
    if rt == 1 then return ld.ROLL_NEED end
    if rt == 2 then return ld.ROLL_GREED end
    if rt == 3 then return ld.ROLL_DE end
    if rt == 0 then return ld.ROLL_PASS end
    return "?"
end

-- ---------------------------------------------------------------------------
-- Construction des motifs depuis les formats de locale
-- ---------------------------------------------------------------------------

local P_TEXT, P_NUM = "\1", "\2"
local MAGIC = "([%^%$%(%)%.%[%]%*%+%-%?%%])"

-- Transforme un format Blizzard ("%s a choisi Besoin pour : %s") en motif Lua
-- capturant. Les %s / %d d'un format sont des marqueurs printf, PAS des classes
-- Lua : les laisser tels quels donnerait « espace » et « chiffre ». D'où le
-- passage par des sentinelles avant l'échappement des caractères magiques.
--
-- Retourne aussi `order` : la capture n° i correspond à l'argument n° order[i].
-- Certaines locales réordonnent les arguments via la forme positionnelle %1$s —
-- l'ordre d'apparition dans la phrase n'est alors plus l'ordre des paramètres.
local function BuildPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local order, n = {}, 0
    local body = fmt:gsub("%%(%d+)%$([sd])", function(pos, kind)
        n = n + 1
        order[n] = tonumber(pos)
        return (kind == "d") and P_NUM or P_TEXT
    end)
    if n == 0 then
        body = fmt:gsub("%%([sd])", function(kind)
            n = n + 1
            order[n] = n
            return (kind == "d") and P_NUM or P_TEXT
        end)
    end
    if n == 0 then return nil end
    body = body:gsub(MAGIC, "%%%1")
    body = body:gsub(P_TEXT, "(.-)"):gsub(P_NUM, "(%%d+)")
    return "^" .. body .. "$", order
end

-- `args` est indexé par numéro d'argument printf : le rôle de la capture i est
-- donc args[order[i]], et non args[i].
local MATCHER_DEFS = {
    -- Temps réel : diffusés dès qu'un joueur clique, AVANT la fin du jet.
    -- C'est la seule famille qui répond à « quelqu'un a-t-il besoin de cet
    -- objet que j'hésite à prendre ». Les « Roll - N » plus bas n'arrivent
    -- qu'à la clôture, trop tard pour décider.
    { g = "LOOT_ROLL_NEED",         kind = "vote",  rt = 1, args = { "player", "item" } },
    { g = "LOOT_ROLL_GREED",        kind = "vote",  rt = 2, args = { "player", "item" } },
    { g = "LOOT_ROLL_DISENCHANT",   kind = "vote",  rt = 3, args = { "player", "item" } },
    { g = "LOOT_ROLL_PASSED",       kind = "vote",  rt = 0, args = { "player", "item" } },
    -- Clôture : le score tiré par chacun.
    { g = "LOOT_ROLL_ROLLED_NEED",  kind = "score", rt = 1, args = { "score", "item", "player" } },
    { g = "LOOT_ROLL_ROLLED_GREED", kind = "score", rt = 2, args = { "score", "item", "player" } },
    { g = "LOOT_ROLL_ROLLED_DE",    kind = "score", rt = 3, args = { "score", "item", "player" } },
    -- Résultat.
    { g = "LOOT_ROLL_WON",          kind = "won",   args = { "player", "item" } },
    { g = "LOOT_ROLL_YOU_WON",      kind = "won",   args = { "item" }, isYou = true },
    { g = "LOOT_ROLL_ALL_PASSED",   kind = "passed", args = { "item" } },
}

local matchers
local function Matchers()
    if matchers then return matchers end
    matchers = {}
    for _, def in ipairs(MATCHER_DEFS) do
        local fmt = _G[def.g]
        local pat, order = BuildPattern(fmt)
        if pat then
            matchers[#matchers + 1] = {
                pat = pat, order = order, args = def.args,
                kind = def.kind, rt = def.rt, isYou = def.isYou, g = def.g,
                -- Poids = longueur du texte fixe, placeholders retirés.
                weight = #(fmt:gsub("%%%d*%$?[sd]", "")),
            }
        end
    end
    -- Du plus spécifique au plus permissif. Certains formats en contiennent
    -- syntaxiquement un autre : « Everyone passed on: %s » satisfait aussi
    -- « %s passed on: %s », qui capturerait alors un votant nommé « Everyone ».
    -- Le même piège existe en français (« Tout le monde a passé son tour… »)
    -- et pour « You won: %s » face à « %s won: %s ». Plus un format porte de
    -- texte fixe, moins il peut être satisfait par hasard : c'est un critère
    -- qui vaut pour toutes les locales, pas un cas particulier codé en dur.
    table.sort(matchers, function(a, b) return a.weight > b.weight end)
    return matchers
end

-- ---------------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------------

local function ItemKey(link)
    if type(link) ~= "string" then return nil end
    return link:match("|Hitem:(%d+)") or link:match("item:(%d+)")
end

local function GroupSize()
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    if n and n > 0 then return n end
    n = GetNumPartyMembers and GetNumPartyMembers() or 0
    if n and n > 0 then return n + 1 end
    return 1
end

local function CountVotes(r)
    local n = 0
    for _ in pairs(r.votes) do n = n + 1 end
    return n
end

-- Un ChatFrame_AddMessageEventFilter est appelé UNE FOIS PAR FENÊTRE DE CHAT
-- recevant l'événement. Deux onglets abonnés à CHAT_MSG_SYSTEM = le même message
-- parsé deux fois. Les votes sont stockés en table joueur → type (écrasement, pas
-- accumulation), donc doublement immunisés ; mais le rattachement d'un vote au
-- bon exemplaire d'un objet en double, lui, ne l'est pas. D'où cette garde.
local seenMsg, lastPurge = {}, 0
local function AlreadyHandled(msg)
    local now = GetTime()
    if now - lastPurge > 30 then
        for k, t in pairs(seenMsg) do
            if now - t > 5 then seenMsg[k] = nil end
        end
        lastPurge = now
    end
    local prev = seenMsg[msg]
    seenMsg[msg] = now
    return prev ~= nil and (now - prev) < 1
end

local function Notify(rid)
    if LootEnh_UpdateBarTally then LootEnh_UpdateBarTally(rid) end
    if LootEnh_RefreshHistoryFrame then LootEnh_RefreshHistoryFrame() end
end

-- ---------------------------------------------------------------------------
-- Cycle de vie d'un jet
-- ---------------------------------------------------------------------------

-- START_LOOT_ROLL annonce la durée du jet en MILLISECONDES. Le décompte affiché
-- ici est en secondes ; une valeur au-delà de la minute ne peut être que des
-- millisecondes (aucun jet ne dure plus de 2 min), donc on convertit.
-- Voir la note sur la barre de jet : Logic.lua consomme la même valeur sans
-- conversion, ce qui vaut d'être vérifié en jeu.
local function Seconds(duration)
    duration = tonumber(duration) or 60
    if duration > 300 then return duration / 1000 end
    return duration
end

function LootEnh_RollBegin(rid, name, tex, link, duration)
    if not rid then return end
    if byRid[rid] then return byRid[rid] end
    -- Le balayage est aussi déclenché ici : l'OnUpdate qui le porte ne tourne
    -- que fenêtre ouverte, or les jets fantômes s'accumulent surtout quand elle
    -- est fermée. Chaque nouveau jet fait donc le ménage des précédents.
    LootEnh_RollSweep()
    local r = {
        rid = rid,
        name = name,
        tex = tex,
        link = link,
        itemKey = ItemKey(link),
        quality = LootEnh_GetQualityFromLink(link),
        startT = GetTime(),
        endT = GetTime() + Seconds(duration),
        votes = {},
        scores = {},
        groupSize = GroupSize(),
    }
    active[#active + 1] = r
    byRid[rid] = r
    Notify(rid)
    return r
end

local function Archive(r)
    local hist = MonLootDB and MonLootDB.rollHistory
    if not hist then return end
    local entry = {
        t = time(),
        link = r.link,
        name = r.name,
        tex = r.tex,
        quality = r.quality,
        winner = r.winner,
        winnerType = r.winnerType,
        winnerScore = r.winnerScore,
        allPassed = r.allPassed,
        groupSize = r.groupSize,
        myVote = r.myVote,
        auto = r.auto,
        votes = r.votes,
        scores = r.scores,
    }
    table.insert(hist, 1, entry)
    local cap = MonLootDB.histMaxEntries or 50
    for i = #hist, cap + 1, -1 do
        table.remove(hist, i)
    end
    -- Le gagnant et les scores arrivent souvent APRÈS la clôture serveur du jet.
    -- On garde donc un pointeur vers l'entrée pour l'enrichir a posteriori,
    -- sinon l'historique afficherait « gagnant inconnu » sur des jets réglés.
    if r.itemKey then
        recent[r.itemKey] = { entry = entry, t = GetTime() }
    end
end

-- CANCEL_LOOT_ROLL ne signifie PAS « le jet est terminé » : il signifie « ta
-- participation est terminée ». Le serveur l'envoie dès qu'on a voté — c'est ce
-- qui fait disparaître la fenêtre native pendant que le reste du groupe
-- continue de choisir.
--
-- Confondre les deux archivait le jet à la seconde où l'auto-roll répondait,
-- donc un objet auto-rollé ne traversait jamais « En cours » : il y entrait et
-- en sortait dans le même souffle, alors que les autres joueurs votaient encore.
-- Le jet reste donc suivi ; seuls nos boutons disparaissent, parce que
-- GetLootRollItemInfo ne renvoie plus rien pour nous.
function LootEnh_RollCloseForMe(rid)
    local r = byRid[rid]
    if not r then return end
    r.closedForMe = true
    Notify(rid)
end

-- Clôture réelle : le jet quitte « En cours » pour l'historique. Déclenchée par
-- l'annonce du gagnant (ou du « tout le monde a passé »), et à défaut par le
-- balayage d'expiration — jamais par CANCEL_LOOT_ROLL.
function LootEnh_RollEnd(rid)
    local r = byRid[rid]
    if not r then return end
    byRid[rid] = nil
    for i, v in ipairs(active) do
        if v == r then
            table.remove(active, i)
            break
        end
    end
    Archive(r)
    Notify(rid)
end

-- Filet contre les jets fantômes : si le serveur n'envoie pas CANCEL_LOOT_ROLL
-- (déconnexion, groupe dissous), un jet resterait indéfiniment dans « En cours ».
-- Appelé par le rafraîchissement de la fenêtre.
-- Durée pendant laquelle un jet tranché reste affiché dans « En cours », le
-- temps de lire qui a gagné.
LootEnh_ROLL_LINGER = 4

function LootEnh_RollSweep()
    local now = GetTime()
    local changed = false
    for i = #active, 1, -1 do
        local r = active[i]
        local expired = now > r.endT + 10
        local lingered = r.resolved and (now - r.resolvedT) > LootEnh_ROLL_LINGER
        if expired or lingered then
            -- Passe par RollEnd plutôt que de refaire le retrait et l'archivage
            -- ici : deux chemins d'archivage, c'est un des deux qu'on oubliera
            -- de corriger. Sûr pendant l'itération, qui remonte la liste.
            LootEnh_RollEnd(r.rid)
            changed = true
        end
    end
    for k, v in pairs(recent) do
        if now - v.t > 120 then recent[k] = nil end
    end
    return changed
end

-- ---------------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------------

function LootEnh_GetActiveRolls()
    return active
end

function LootEnh_GetRoll(rid)
    return byRid[rid]
end

function LootEnh_GetRollHistory()
    return (MonLootDB and MonLootDB.rollHistory) or {}
end

-- Notre propre vote, su de source sûre : enregistré au moment où NOUS cliquons,
-- sans dépendre du parsing du chat. Les deux sources sont conservées — le chat
-- couvre le cas où le vote a été émis avant que la fenêtre existe, le marquage
-- local couvre le cas où le serveur n'annonce pas les votes au format attendu.
function LootEnh_RollMarkMyVote(rid, rt, isAuto)
    local r = byRid[rid]
    if not r then return end
    r.myVote = rt
    -- Un jet réglé par l'auto-roll se clôt souvent dans la seconde : il traverse
    -- « En cours » trop vite pour être lu. Le marquer permet au moins de savoir,
    -- dans l'historique, que l'addon a répondu et ce qu'il a choisi — sinon
    -- l'auto-roll travaille sans jamais rendre de comptes.
    if isAuto then r.auto = true end
    r.votes[UnitName("player")] = rt
    Notify(rid)
end

function LootEnh_RollMyVote(r)
    if not r then return nil end
    if r.myVote ~= nil then return r.myVote end
    return r.votes and r.votes[UnitName("player")]
end

-- TOUT vote passe par RollOnLoot, quelle qu'en soit l'origine : nos barres, la
-- fenêtre native de WoW quand elle est laissée visible, la fenêtre des jets,
-- l'auto-roll, une macro, un autre addon. C'est le seul point de passage
-- garanti — n'instrumenter que nos propres boutons laissait un jet fait dans la
-- fenêtre Blizzard totalement invisible côté suivi.
--
-- hooksecurefunc, et non un remplacement de la globale : l'originale reste
-- intacte, notre fonction s'exécute après, et aucun taint n'entre dans un
-- chemin sécurisé. Remplacer RollOnLoot aurait fait passer un clic Blizzard par
-- du code d'addon.
if hooksecurefunc then
    hooksecurefunc("RollOnLoot", function(rid, rt)
        LootEnh_RollMarkMyVote(rid, rt)
    end)
end

-- Ce que le serveur autorise ENCORE sur ce jet, relu à l'instant. Retourne nil
-- si le jet n'existe plus. Comme sur la barre (Logic.lua), la question est posée
-- au moment d'agir et jamais mémorisée : entre l'affichage et le clic, le jet a
-- pu être annulé ou l'objet ramassé par le maître du butin.
function LootEnh_RollAllowed(rid)
    if type(rid) ~= "number" or rid < 0 then return nil end   -- jets factices de /lt hist
    local alive, _, _, _, _, cN, cG, cD = GetLootRollItemInfo(rid)
    if not alive then return nil end
    return { [0] = true, [1] = cN, [2] = cG, [3] = cD }
end

-- Gagnant, type de jet, score — recalculés à la lecture.
--
-- ApplyWon fige ces trois valeurs à l'instant où « X won: » arrive, mais les
-- lignes « Need Roll - 100 … by X » qui portent le type et le score peuvent
-- tomber APRÈS, et l'ordre d'arrivée des messages n'est garanti nulle part. Un
-- instantané pris trop tôt laissait l'icône du jet et le score absents pour
-- toujours. On repart donc des tables de votes, qui, elles, continuent d'être
-- enrichies même après archivage.
function LootEnh_RollWinnerInfo(e)
    if not e or not e.winner then return nil end
    local rt = e.winnerType
    if rt == nil and e.votes then rt = e.votes[e.winner] end
    local score = e.winnerScore
    if score == nil and e.scores then score = e.scores[e.winner] end
    return e.winner, rt, score
end

function LootEnh_RollTally(r)
    local t = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }
    if not r or not r.votes then return t, 0 end
    local total = 0
    for _, rt in pairs(r.votes) do
        if t[rt] then
            t[rt] = t[rt] + 1
            total = total + 1
        end
    end
    return t, total
end

-- Ligne compacte « icône + nombre », types non votés omis. Afficher les zéros
-- serait du bruit : le signal utile est « quelqu'un a pris Besoin », pas
-- « trois personnes n'ont rien fait ».
function LootEnh_RollTallyText(r, size)
    size = size or 12
    local t = LootEnh_RollTally(r)
    local out = {}
    for _, rt in ipairs(LootEnh_ROLL_ORDER_DISPLAY) do
        if t[rt] > 0 then
            out[#out + 1] = string.format("|T%s:%d:%d|t%s%d|r",
                LootEnh_ROLL_ICON[rt], size, size, Hex(rt), t[rt])
        end
    end
    return table.concat(out, "  ")
end

-- Détail « qui a voté quoi », groupé par type dans l'ordre d'affichage.
-- Retourne une liste de { texte, r, g, b } prête pour GameTooltip.
function LootEnh_RollVoterLines(r)
    local lines = {}
    if not r or not r.votes then return lines end
    for _, rt in ipairs(LootEnh_ROLL_ORDER_DISPLAY) do
        local names = {}
        for player, prt in pairs(r.votes) do
            if prt == rt then names[#names + 1] = player end
        end
        table.sort(names)
        local c = LootEnh_ROLL_COLOR[rt]
        for _, player in ipairs(names) do
            local score = r.scores and r.scores[player]
            local text = LootEnh_RollLabel(rt) .. "  " .. player
            if score then text = text .. "  (" .. score .. ")" end
            lines[#lines + 1] = { text, c[1], c[2], c[3] }
        end
    end
    return lines
end

-- ---------------------------------------------------------------------------
-- Parsing du chat
-- ---------------------------------------------------------------------------

-- Deux exemplaires du même objet peuvent être en jeu simultanément, et le message
-- ne porte que l'objet — jamais l'identifiant du jet. On rattache donc au plus
-- ancien jet encore ouvert pour cet objet où ce joueur n'a pas déjà voté : un
-- joueur ne vote qu'une fois par jet.
local function FindActive(key, player)
    if not key then return nil end
    local fallback
    for _, r in ipairs(active) do
        if r.itemKey == key then
            if not player or r.votes[player] == nil then return r end
            fallback = fallback or r
        end
    end
    return fallback
end

local function ResolveSelf(name)
    if not name then return nil end
    local me = UnitName("player")
    local lower = name:lower()
    if lower == "you" or lower == "vous" then return me end
    return name
end

local function ApplyVote(link, player, rt, score)
    local key = ItemKey(link)
    player = ResolveSelf(player)
    if not player then return nil end
    local r = FindActive(key, player)
    if r then
        r.votes[player] = rt
        if score then r.scores[player] = tonumber(score) end
        Notify(r.rid)
        return r
    end
    -- Jet déjà clos : les « Roll - N » tombent souvent après CANCEL_LOOT_ROLL.
    local rec = key and recent[key]
    if rec then
        rec.entry.votes[player] = rt
        if score then rec.entry.scores[player] = tonumber(score) end
        Notify(nil)
    end
    return nil
end

local function ApplyWon(link, player, allPassed)
    local key = ItemKey(link)
    player = ResolveSelf(player)
    local r = FindActive(key, nil)
    local target = r
    if not target then
        local rec = key and recent[key]
        target = rec and rec.entry
    end
    if not target then return end
    if allPassed then
        target.allPassed = true
    else
        target.winner = player
        target.winnerType = player and target.votes and target.votes[player] or nil
        target.winnerScore = player and target.scores and target.scores[player] or nil
    end
    -- Le jet est tranché, mais il ne disparaît pas encore : il reste quelques
    -- secondes dans « En cours » pour qu'on voie le résultat. Basculer
    -- instantanément vers l'historique faisait s'évanouir la ligne au moment
    -- précis où elle devenait intéressante.
    if r then
        r.resolved = true
        r.resolvedT = GetTime()
    end
    Notify(r and r.rid or nil)
end

-- Appelé par le filtre de chat. Ne décide RIEN de l'affichage du message : le
-- filtrage reste la responsabilité de LootEnh_LootFilter. Retourne le type
-- reconnu (ou nil), uniquement pour le mode debug.
function LootEnh_RollParse(msg)
    if type(msg) ~= "string" then return nil end
    if AlreadyHandled(msg) then return nil end

    for _, m in ipairs(Matchers()) do
        local caps = { msg:match(m.pat) }
        if caps[1] ~= nil then
            local a = {}
            for i, v in ipairs(caps) do
                a[m.args[m.order[i]] or i] = v
            end
            local player = m.isYou and UnitName("player") or a.player
            if m.kind == "vote" then
                ApplyVote(a.item, player, m.rt)
            elseif m.kind == "score" then
                ApplyVote(a.item, player, m.rt, a.score)
            elseif m.kind == "won" then
                ApplyWon(a.item, player, false)
            elseif m.kind == "passed" then
                ApplyWon(a.item, nil, true)
            end
            if debugOn then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[LootEnh ✓ " .. m.g .. "]|r " .. msg)
            end
            return m.kind
        end
    end

    if debugOn then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[LootEnh ✗]|r " .. msg)
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Debug & test
-- ---------------------------------------------------------------------------

-- `/lt roll` — affiche chaque message système avec le motif qui l'a reconnu, ou
-- une croix s'il est passé au travers. C'est la seule façon de vérifier que les
-- formats d'Ascension correspondent bien aux globales du client, plutôt que de
-- le supposer.
function LootEnh_RollDebugActive()
    return debugOn
end

function LootEnh_ToggleRollDebug()
    debugOn = not debugOn
    if debugOn then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffLootEnh:|r suivi des jets — |cff00ff00actif|r")
        local built, missing = 0, {}
        for _, def in ipairs(MATCHER_DEFS) do
            if BuildPattern(_G[def.g]) then
                built = built + 1
            else
                missing[#missing + 1] = def.g
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  motifs construits : %d / %d", built, #MATCHER_DEFS))
        if #missing > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  |cffff5555absents :|r " .. table.concat(missing, ", "))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffLootEnh:|r suivi des jets — |cffff5555coupé|r")
    end
end

-- `/lt hist` — fabrique des jets et un historique factices. Les deux onglets
-- sont autrement invisibles hors groupe, ce qui rend toute vérification de mise
-- en page impossible en solo.
function LootEnh_TestRolls()
    local samples = {
        { 6948, "Pierre de foyer" },
        { 7073, "Fragment brisé" },
        { 2589, "Étoffe de lin" },
    }
    local names = { "Tetardtek", "Gorlok", "Mylenn", "Draak", "Ysha" }
    for i, s in ipairs(samples) do
        local name, link, quality, _, _, _, _, _, _, tex = GetItemInfo(s[1])
        local r = LootEnh_RollBegin(-1000 - i, name or s[2], tex or "Interface\\Icons\\INV_Misc_QuestionMark",
            link or ("|cffffffff|Hitem:" .. s[1] .. ":0:0:0:0:0:0:0|h[" .. s[2] .. "]|h|r"), 30 + i * 7)
        if r then
            for j = 1, i + 1 do
                r.votes[names[j]] = ({ 1, 2, 0, 3, 2 })[j]
            end
            r.groupSize = 5
        end
    end
    if LootEnh_RefreshHistoryFrame then LootEnh_RefreshHistoryFrame() end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffLootEnh:|r 3 jets factices — ils expireront seuls.")
end

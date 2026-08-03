local core = CreateFrame("Frame")
core:RegisterEvent("START_LOOT_ROLL")
core:RegisterEvent("CANCEL_LOOT_ROLL")
core:RegisterEvent("CONFIRM_LOOT_ROLL")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("CHAT_MSG_LOOT")
core:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
core:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
core:RegisterEvent("PLAYER_MONEY")

function LootEnh_ToggleNativeLoot(hide)
    if hide then
        UIParent:UnregisterEvent("START_LOOT_ROLL")
        UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")
        for i = 1, NUM_GROUP_LOOT_FRAMES do
            local f = _G["GroupLootFrame" .. i]
            if f then
                f:UnregisterAllEvents()
                f:Hide()
            end
        end
    else
        UIParent:RegisterEvent("START_LOOT_ROLL")
        UIParent:RegisterEvent("CANCEL_LOOT_ROLL")
        for i = 1, NUM_GROUP_LOOT_FRAMES do
            local f = _G["GroupLootFrame" .. i]
            if f then
                f:RegisterEvent("CANCEL_LOOT_ROLL")
            end
        end
    end
end

core:SetScript("OnEvent", function(s, e, id, t)
    if e == "PLAYER_LOGIN" then
        LootEnh_InitializeDB()
        -- Declaration au hub AllEnh, sans dependance : s'il est absent, la
        -- ligne ne fait rien. C'est lui qui decouvre les addons Enh presents et
        -- porte le controle de version pour toute la suite — un seul
        -- verificateur, une seule annonce, au lieu de trois.
        if AllEnh_Register then
            -- `actions` : ce que le hub peut proposer en acces rapide. Il ne
            -- connait aucune de nos fonctions — c'est nous qui les lui tendons,
            -- au meme titre que l'URL. Un hub plus ancien ignore simplement le
            -- champ, la declaration reste valide.
            AllEnh_Register("LootEnh", {
                addon = "LootEnh",
                url = "https://github.com/Tetardtek/LootEnh/releases/latest",
                actions = {
                    {
                        key = "rolls",
                        label = L().SUITE_ROLLS,
                        icon = "Interface\\Icons\\inv_misc_dice_01",
                        run = function() LootEnh_ToggleHistory() end,
                    },
                },
            })
        end
        LootEnh_CreateMainPanel()
        LootEnh_CreateAutoRollPanel()
        LootEnh_CreateCustomRulesPanel()
        LootEnh_CreateDisplayPanel()
        LootEnh_CreateChatPanel()
        LootEnh_CreateProfilesPanel()
        LootEnh_CreateAddonFrames()
        LootEnh_InitSoloMoney()
        LootEnh_ToggleNativeLoot(MonLootDB.hideNative)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", LootEnh_LootFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", LootEnh_LootFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", LootEnh_SoloLootFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", LootEnh_SoloMoneyFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", LootEnh_SoloXPFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", LootEnh_SoloRepFilter)
        LootEnh_AutoLoadProfiles()

    elseif e == "START_LOOT_ROLL" then
        local tex, name, _, quality, bop, canNeed, canGreed, canDE = GetLootRollItemInfo(id)

        -- Le suivi commence AVANT toute condition d'affichage. Observer ce que
        -- les autres votent garde son sens quand l'auto-roll répond à notre
        -- place, et même quand les barres sont désactivées : c'est la fenêtre
        -- des jets qui consomme ces données, pas la barre.
        LootEnh_RollBegin(id, name, tex, GetLootRollItemLink(id), t)

        -- Tracé AVANT toute sortie anticipée : un jet qui n'apparaît pas dans la
        -- fenêtre a soit manqué cet événement, soit été clos aussitôt. La ligne
        -- ci-dessous distingue les deux, ce qu'aucune lecture du code ne peut faire.
        if LootEnh_RollDebugActive and LootEnh_RollDebugActive() then
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cff00ccff[LootEnh] START id=%s duree=%s barres=%s autoRoll=%s en_cours=%d|r",
                tostring(id), tostring(t), tostring(MonLootDB.enableLootFrame),
                tostring(MonLootDB.autoRoll), #LootEnh_GetActiveRolls()))
        end

        if not MonLootDB.enableLootFrame then return end

        -- ANALYSE AUTO
        local autoAction = MonLootDB.autoRoll and LootEnh_GetAutoRollAction(name, quality, bop, canNeed, canGreed, canDE)

        if autoAction then
            RollOnLoot(id, autoAction)
            -- Seul appel explicite qui subsiste : l'accroche sur RollOnLoot a
            -- déjà enregistré le vote, mais elle ne peut pas savoir qu'il vient
            -- de l'auto-roll. Ce marquage n'ajoute que cette origine.
            LootEnh_RollMarkMyVote(id, autoAction, true)
        else
            -- MANUEL : On affiche nos barres personnalisées
            LootEnh_ShowLootBar(id, name, tex, GetLootRollItemLink(id), t)
        end

    elseif e == "CANCEL_LOOT_ROLL" then
        -- Le serveur clôt le jet : la barre correspondante n'a plus de sens.
        -- LootEnh désenregistre CANCEL_LOOT_ROLL d'UIParent quand il masque la
        -- fenêtre native — plus personne n'écoutait cet événement.
        if LootEnh_RollDebugActive and LootEnh_RollDebugActive() then
            local r = LootEnh_GetRoll(id)
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cffff9900[LootEnh] CANCEL id=%s apres %.1fs|r",
                tostring(id), r and (GetTime() - r.startT) or -1))
        end
        if LootEnh_CancelLootBar then LootEnh_CancelLootBar(id) end
        -- Notre participation s'arrête, PAS le jet : les autres joueurs votent
        -- encore. Le suivi continue jusqu'à l'annonce du gagnant.
        if LootEnh_RollCloseForMe then LootEnh_RollCloseForMe(id) end

    elseif e == "CONFIRM_LOOT_ROLL" then
        if MonLootDB.skipBopDialog then
            ConfirmLootRoll(id, t)
            StaticPopup_Hide("CONFIRM_LOOT_ROLL")
        end

    elseif e == "CHAT_MSG_LOOT" then
        LootEnh_OnSoloLoot(id)
        -- Enh bridge: tell BagsEnh about looted items (if installed)
        if BagsEnh_OnNewLoot and id then
            local m = id:lower()
            if m:find("^you receive loot") or m:find("^vous recevez") then
                local link = id:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
                if link then
                    BagsEnh_OnNewLoot(link, tonumber(id:match("x(%d+)")) or 1)
                end
            end
        end

    elseif e == "PLAYER_MONEY" then
        LootEnh_OnSoloMoney()

    elseif e == "CHAT_MSG_COMBAT_XP_GAIN" then
        LootEnh_OnSoloXP(id)

    elseif e == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        LootEnh_OnSoloRep(id)
    end
end)

SLASH_LL1 = "/ll";
SlashCmdList["LL"] = function()
    LootEnh_SetAnchorsShown(not MonLootDB.showAnchor)
end
SLASH_LT1 = "/lt";
SlashCmdList["LT"] = function(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)") or ""
    if arg == "roll" then
        LootEnh_ToggleRollDebug()
    elseif arg == "hist" then
        LootEnh_TestRolls()
    else
        LootEnh_TestLootTiers()
    end
end
SLASH_LH1 = "/lh";
SlashCmdList["LH"] = function()
    LootEnh_ToggleHistory()
end

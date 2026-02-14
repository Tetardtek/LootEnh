local core = CreateFrame("Frame")
core:RegisterEvent("START_LOOT_ROLL")
core:RegisterEvent("CONFIRM_LOOT_ROLL")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("CHAT_MSG_LOOT")
core:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
core:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
core:RegisterEvent("PLAYER_MONEY")

function ToggleNativeLoot(hide)
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
        InitializeDB()
        LootEnh_CreateMainPanel()
        LootEnh_CreateAutoRollPanel()
        LootEnh_CreateLootFramePanel()
        LootEnh_CreateCustomRulesPanel()
        LootEnh_CreateProfilesPanel()
        LootEnh_CreateSoloPanel()
        CreateAddonFrames()
        LootEnh_InitSoloMoney()
        ToggleNativeLoot(MonLootDB.hideNative)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", LootFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", LootFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", SoloLootFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", SoloXPFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", SoloRepFilter)
        LootEnh_AutoLoadProfiles()

    elseif e == "START_LOOT_ROLL" then
        if not MonLootDB.enableLootFrame then return end

        local _, name, _, quality, bop, canNeed, canGreed, canDE = GetLootRollItemInfo(id)

        -- ANALYSE AUTO
        local autoAction = MonLootDB.autoRoll and GetAutoRollAction(name, quality, bop, canNeed, canGreed, canDE)

        if autoAction then
            RollOnLoot(id, autoAction)
        else
            -- MANUEL : On affiche nos barres personnalisées
            local tex = GetLootRollItemInfo(id)
            ShowLootBar(id, name, tex, GetLootRollItemLink(id), t)
        end

    elseif e == "CONFIRM_LOOT_ROLL" then
        if MonLootDB.skipBopDialog then
            ConfirmLootRoll(id, t)
            StaticPopup_Hide("CONFIRM_LOOT_ROLL")
        end

    elseif e == "CHAT_MSG_LOOT" then
        LootEnh_OnSoloLoot(id)

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
    MonLootDB.showAnchor = not MonLootDB.showAnchor
    if MonLootDB.showAnchor then
        LootAnchor:Show()
        SoloAnchor:Show()
    else
        LootAnchor:Hide()
        SoloAnchor:Hide()
    end
end
SLASH_LH1 = "/lh";
SlashCmdList["LH"] = function()
    MonLootDB.hideHistory = not MonLootDB.hideHistory
    if MonLootDB.hideHistory then
        LootHistory:Hide()
    else
        LootHistory:Show()
    end
end

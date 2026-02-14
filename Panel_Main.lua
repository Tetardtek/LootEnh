LootEnh_PanelState = { autoRollControls = {}, lootFrameControls = {} }

function LootEnh_CreateMainPanel()
    local ld = L()

    LootEnhOptionsPanel = CreateFrame("Frame", "LootEnhMainPanel", UIParent)
    LootEnhOptionsPanel.name = "LootEnh"
    local t = LootEnhOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16);
    t:SetText("LootEnh - Configuration")

    -- Boutons Langue
    local ltitle = LootEnhOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ltitle:SetPoint("TOPLEFT", 16, -55);
    ltitle:SetText(ld.LANG_LABEL)

    local function CreateLangBtn(text, lang, x)
        local btn = CreateFrame("Button", nil, LootEnhOptionsPanel, "UIPanelButtonTemplate")
        btn:SetSize(100, 24);
        btn:SetPoint("TOPLEFT", x, -80);
        btn:SetText(text)
        btn:SetScript("OnClick", function()
            MonLootDB.lang = lang;
            StaticPopup_Show("RELOAD_UI")
        end)
    end
    CreateLangBtn("Français", "frFR", 20)
    CreateLangBtn("English", "enUS", 130)

    -- Group Frame toggles
    local lfTitle = LootEnhOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lfTitle:SetPoint("TOPLEFT", 16, -130)
    lfTitle:SetText("Group Frame:")

    local cbHideNative = CreateFrame("CheckButton", "LootEnhCBHideNative", LootEnhOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cbHideNative:SetPoint("TOPLEFT", 16, -153)
    _G[cbHideNative:GetName() .. "Text"]:SetText(ld.OPT_HIDE_NATIVE)
    cbHideNative:SetChecked(MonLootDB.hideNative)
    cbHideNative:SetScript("OnClick", function(self)
        MonLootDB.hideNative = self:GetChecked()
        ToggleNativeLoot(MonLootDB.hideNative)
    end)

    local cbEnableLF = CreateFrame("CheckButton", "LootEnhCBEnableLF", LootEnhOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cbEnableLF:SetPoint("TOPLEFT", 16, -178)
    _G[cbEnableLF:GetName() .. "Text"]:SetText(ld.OPT_ENABLE_LOOTFRAME)
    cbEnableLF:SetChecked(MonLootDB.enableLootFrame)

    -- Solo Display toggle
    local soloTitle = LootEnhOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soloTitle:SetPoint("TOPLEFT", 16, -215)
    soloTitle:SetText("Solo Display:")

    local cbEnableSolo = CreateFrame("CheckButton", "LootEnhCBEnableSolo", LootEnhOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cbEnableSolo:SetPoint("TOPLEFT", 16, -238)
    _G[cbEnableSolo:GetName() .. "Text"]:SetText(ld.SOLO_ENABLE)
    cbEnableSolo:SetChecked(MonLootDB.solo and MonLootDB.solo.enabled)
    cbEnableSolo:SetScript("OnClick", function(self)
        MonLootDB.solo.enabled = self:GetChecked()
        -- Gray-out solo panel controls if wired
        if LootEnh_PanelState.soloControls then
            LootEnh_SetControlsEnabled(LootEnh_PanelState.soloControls, MonLootDB.solo.enabled)
        end
    end)

    InterfaceOptions_AddCategory(LootEnhOptionsPanel)
end

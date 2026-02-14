LootEnh_PanelState = { autoRollControls = {}, lootFrameControls = {} }

function LootEnh_CreateMainPanel()
    local ld = L()

    LootEnhOptionsPanel = CreateFrame("Frame", "LootEnhMainPanel", UIParent)
    LootEnhOptionsPanel.name = "LootEnh"
    local t = LootEnhOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16);
    t:SetText(ld.OPTIONS_TITLE)

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
    lfTitle:SetText(ld.GROUP_FRAME_LABEL)

    local cbHideNative = CreateFrame("CheckButton", "LootEnhCBHideNative", LootEnhOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cbHideNative:SetPoint("TOPLEFT", 16, -153)
    _G[cbHideNative:GetName() .. "Text"]:SetText(ld.OPT_HIDE_NATIVE)
    cbHideNative:SetChecked(MonLootDB.hideNative)
    cbHideNative:SetScript("OnClick", function(self)
        MonLootDB.hideNative = self:GetChecked()
        LootEnh_ToggleNativeLoot(MonLootDB.hideNative)
    end)

    local cbEnableLF = CreateFrame("CheckButton", "LootEnhCBEnableLF", LootEnhOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cbEnableLF:SetPoint("TOPLEFT", 16, -178)
    _G[cbEnableLF:GetName() .. "Text"]:SetText(ld.OPT_ENABLE_LOOTFRAME)
    cbEnableLF:SetChecked(MonLootDB.enableLootFrame)

    -- Solo Frame toggle
    local soloTitle = LootEnhOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soloTitle:SetPoint("TOPLEFT", 16, -215)
    soloTitle:SetText(ld.SOLO_FRAME_LABEL)

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

    -- Profile Quick-Select
    local profTitle = LootEnhOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profTitle:SetPoint("TOPLEFT", 16, -280)
    profTitle:SetText(ld.PROF_QUICK_TITLE)

    local function CreateProfileQuickDD(parent, ptype, label, x, y)
        local ddName = "LootEnhMainProfDD_" .. ptype
        local frame = CreateFrame("Frame", ddName, parent, "UIDropDownMenuTemplate")
        frame:SetPoint("TOPLEFT", x, y)
        UIDropDownMenu_SetWidth(frame, 140)

        local ddLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ddLabel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 20, 0)
        ddLabel:SetText(label)

        local function RefreshDD()
            local charKey = LootEnh_GetCharKey()
            local assoc = MonLootDB.charProfiles and MonLootDB.charProfiles[charKey]
            local active = assoc and assoc[ptype] or nil
            if active and not (MonLootDB.profiles[ptype] and MonLootDB.profiles[ptype][active]) then
                active = nil
            end

            local hasDefaultProfile = MonLootDB.profiles[ptype] and MonLootDB.profiles[ptype]["Default"]

            LootEnh_SafeDropDownInit(frame, function()
                local info = UIDropDownMenu_CreateInfo()
                info.text = "Default"
                info.checked = (active == nil or active == "Default")
                if hasDefaultProfile then
                    info.value = "Default"
                    info.func = function(btn)
                        LootEnh_LoadProfile(ptype, "Default")
                        UIDropDownMenu_SetText(frame, "Default")
                        DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_LOADED, "Default"))
                    end
                else
                    info.value = nil
                    info.func = function()
                        local ck = LootEnh_GetCharKey()
                        if MonLootDB.charProfiles[ck] then
                            MonLootDB.charProfiles[ck][ptype] = nil
                        end
                        UIDropDownMenu_SetText(frame, "Default")
                        LootEnh_RefreshAllPanels()
                    end
                end
                UIDropDownMenu_AddButton(info)

                local names = {}
                if MonLootDB.profiles[ptype] then
                    for n in pairs(MonLootDB.profiles[ptype]) do
                        if n ~= "Default" then
                            names[#names + 1] = n
                        end
                    end
                end
                table.sort(names)
                for _, n in ipairs(names) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = n
                    info.value = n
                    info.checked = (n == active)
                    info.func = function(btn)
                        LootEnh_LoadProfile(ptype, btn.value)
                        UIDropDownMenu_SetText(frame, btn.value)
                        DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_LOADED, btn.value))
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            UIDropDownMenu_SetText(frame, active or "Default")
        end

        frame.Refresh = RefreshDD
        RefreshDD()
        return frame
    end

    local ddAutoRoll = CreateProfileQuickDD(LootEnhOptionsPanel, "autoRoll", ld.PROF_QUICK_AUTOROLL, 0, -310)
    local ddUI = CreateProfileQuickDD(LootEnhOptionsPanel, "ui", ld.PROF_QUICK_UI, 210, -310)

    LootEnh_PanelState.mainProfileDD = { ddAutoRoll, ddUI }

    LootEnhOptionsPanel:SetScript("OnShow", function()
        if LootEnh_PanelState.mainProfileDD then
            for _, dd in ipairs(LootEnh_PanelState.mainProfileDD) do
                if dd.Refresh then dd.Refresh() end
            end
        end
    end)

    InterfaceOptions_AddCategory(LootEnhOptionsPanel)
end

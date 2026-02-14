function LootEnh_CreateLootFramePanel()
    local ld = L()

    local LFPanel = CreateFrame("Frame", "LootEnhLootFramePanel", UIParent)
    LFPanel.name = "Group Frame"
    LFPanel.parent = "LootEnh"

    local lft = LFPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    lft:SetPoint("TOPLEFT", 16, -16)
    lft:SetText(ld.CAT_LOOT_FRAME)

    -- Test buttons: spawn real loot bars to preview settings live
    local testIcons = {
        "Interface\\Icons\\inv_sword_39",
        "Interface\\Icons\\inv_helmet_04",
        "Interface\\Icons\\inv_shield_04",
    }
    local testNames = {
        "|cff0070dd[Blade of Test]|r",
        "|cffa335ee[Helm of Preview]|r",
        "|cff1eff00[Shield of Trying]|r",
    }

    local btn1 = CreateFrame("Button", "LootEnhTestOne", LFPanel, "UIPanelButtonTemplate")
    btn1:SetSize(90, 24)
    btn1:SetPoint("TOPLEFT", 16, -48)
    btn1:SetText(ld.LOOT_TEST_ONE)
    btn1:SetScript("OnClick", function()
        LootEnh_ShowLootBar(nil, "Test Item", testIcons[1], testNames[1], 10)
    end)

    local btn3 = CreateFrame("Button", "LootEnhTestThree", LFPanel, "UIPanelButtonTemplate")
    btn3:SetSize(90, 24)
    btn3:SetPoint("LEFT", btn1, "RIGHT", 8, 0)
    btn3:SetText(ld.LOOT_TEST_THREE)
    btn3:SetScript("OnClick", function()
        for i = 1, 3 do
            LootEnh_ShowLootBar(nil, "Test Item " .. i, testIcons[i], testNames[i], 10 + i * 2)
        end
    end)

    local btnReset = CreateFrame("Button", "LootEnhResetAnchors", LFPanel, "UIPanelButtonTemplate")
    btnReset:SetSize(120, 24)
    btnReset:SetPoint("LEFT", btn3, "RIGHT", 8, 0)
    btnReset:SetText(ld.ANCHOR_RESET)
    btnReset:SetScript("OnClick", function()
        MonLootDB.anchorX = 0;      MonLootDB.anchorY = 100
        MonLootDB.soloAnchorX = 0;   MonLootDB.soloAnchorY = -100
        MonLootDB.histX = -50;       MonLootDB.histY = 0
        if LootAnchor then
            LootAnchor:ClearAllPoints()
            LootAnchor:SetPoint("CENTER", 0, 100)
        end
        if SoloAnchor then
            SoloAnchor:ClearAllPoints()
            SoloAnchor:SetPoint("CENTER", 0, -100)
        end
        if LootHistory then
            LootHistory:ClearAllPoints()
            LootHistory:SetPoint("RIGHT", -50, 0)
        end
    end)

    -- Controls zone
    local ctrlAnchorY = -80
    local function OnSettingChanged() LootEnh_RefreshActiveLootFrames() end

    -- Row 1: Strata + Growth Direction dropdowns
    local strataOptions = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG"}
    local ddStrata = LootEnh_CreateGenericDropdown(LFPanel, 0, ctrlAnchorY, 110, ld.LOOT_STRATA, "lootFrame", "strata", strataOptions, strataOptions, OnSettingChanged)

    local growOptions = {ld.LOOT_GROW_UP, ld.LOOT_GROW_DOWN}
    local growValues = {"up", "down"}
    local ddGrow = LootEnh_CreateGenericDropdown(LFPanel, 230, ctrlAnchorY, 110, ld.LOOT_GROWTH, "lootFrame", "growDir", growOptions, growValues, OnSettingChanged)

    -- Row 2: Scale + Opacity sliders
    local slScale = LootEnh_CreateSlider(LFPanel, 16, ctrlAnchorY - 75, 180, ld.LOOT_SCALE, "lootFrame", "scale", 0.5, 2.0, 0.05, true, OnSettingChanged)
    local slAlpha = LootEnh_CreateSlider(LFPanel, 250, ctrlAnchorY - 75, 180, ld.LOOT_ALPHA, "lootFrame", "alpha", 0.1, 1.0, 0.05, true, OnSettingChanged)

    -- Row 3: Spacing + Max Bars sliders
    local slSpacing = LootEnh_CreateSlider(LFPanel, 16, ctrlAnchorY - 125, 180, ld.LOOT_SPACING, "lootFrame", "spacing", 0, 20, 1, false, OnSettingChanged)
    local slMaxBars = LootEnh_CreateSlider(LFPanel, 250, ctrlAnchorY - 125, 180, ld.LOOT_MAX_BARS, "lootFrame", "maxBars", 1, 10, 1, false, OnSettingChanged)

    -- Separator
    local sep = LFPanel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 16, ctrlAnchorY - 175)
    sep:SetPoint("TOPRIGHT", -16, ctrlAnchorY - 175)
    sep:SetTexture(0.4, 0.4, 0.4, 0.6)

    -- Group Chat Filtering radios
    local ftitle = LFPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ftitle:SetPoint("TOPLEFT", 16, ctrlAnchorY - 190)
    ftitle:SetText(ld.GROUP_FILTER_TITLE)

    local function CreateRadio(id, label, y)
        local rb = CreateFrame("CheckButton", "LootEnhRadio" .. id, LFPanel, "UIRadioButtonTemplate")
        rb:SetPoint("TOPLEFT", 20, y)
        _G[rb:GetName() .. "Text"]:SetText(label)
        rb:SetChecked(MonLootDB.filterMode == id)
        rb:SetScript("OnClick", function()
            MonLootDB.filterMode = id
            for i = 1, 3 do
                _G["LootEnhRadio" .. i]:SetChecked(i == id)
            end
        end)
        return rb
    end
    local rb1 = CreateRadio(1, ld.MODE_NORMAL, ctrlAnchorY - 215)
    local rb2 = CreateRadio(2, ld.MODE_FILTERED, ctrlAnchorY - 240)
    local rb3 = CreateRadio(3, ld.MODE_SILENCE, ctrlAnchorY - 265)

    local lootFrameControls = {btn1, btn3, ddStrata, ddGrow, slScale, slAlpha, slSpacing, slMaxBars, rb1, rb2, rb3}
    LootEnh_PanelState.lootFrameControls = lootFrameControls

    local function RefreshLootFrameGray()
        LootEnh_SetControlsEnabled(lootFrameControls, MonLootDB.enableLootFrame)
    end

    -- Wire the Enable Loot Frame checkbox from Panel_Main
    local cbEnableLF = _G["LootEnhCBEnableLF"]
    if cbEnableLF then
        cbEnableLF:SetScript("OnClick", function(self)
            MonLootDB.enableLootFrame = self:GetChecked()
            RefreshLootFrameGray()
        end)
    end

    LFPanel:SetScript("OnShow", RefreshLootFrameGray)

    InterfaceOptions_AddCategory(LFPanel)
end

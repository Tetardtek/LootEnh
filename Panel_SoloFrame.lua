function LootEnh_CreateSoloPanel()
    local ld = L()

    local SPanel = CreateFrame("Frame", "LootEnhSoloPanel", UIParent)
    SPanel.name = "Solo Display"
    SPanel.parent = "LootEnh"

    local title = SPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ld.SOLO_TITLE)

    local soloControls = {}

    -- Test button
    local btnTest = CreateFrame("Button", "LootEnhSoloTest", SPanel, "UIPanelButtonTemplate")
    btnTest:SetSize(80, 24)
    btnTest:SetPoint("TOPLEFT", 16, -48)
    btnTest:SetText(ld.SOLO_TEST)
    btnTest:SetScript("OnClick", function()
        LootEnh_TestSoloBars()
    end)
    soloControls[#soloControls + 1] = btnTest

    -- ============================================================
    -- Local helpers for 3-level settings (MonLootDB.solo[modKey][settingKey])
    -- ============================================================

    local moduleCheckCounter = 0
    local moduleSliderCounter = 0
    local moduleDropdownCounter = 0

    local function ModuleCheck(parent, modKey, settingKey, label, x, y)
        moduleCheckCounter = moduleCheckCounter + 1
        local cbName = "LootEnhSoloMod" .. moduleCheckCounter
        local cb = CreateFrame("CheckButton", cbName, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        _G[cbName .. "Text"]:SetText(label)
        local mod = MonLootDB.solo and MonLootDB.solo[modKey]
        cb:SetChecked(mod and mod[settingKey])
        cb:SetScript("OnClick", function(self)
            if MonLootDB.solo and MonLootDB.solo[modKey] then
                MonLootDB.solo[modKey][settingKey] = self:GetChecked()
            end
        end)
        cb.Refresh = function()
            local m = MonLootDB.solo and MonLootDB.solo[modKey]
            cb:SetChecked(m and m[settingKey])
        end
        table.insert(LootEnh_AllControls, cb)
        soloControls[#soloControls + 1] = cb
        return cb
    end

    local function ModuleSlider(parent, modKey, settingKey, label, x, y, w, min, max, step, isFloat, onChange)
        moduleSliderCounter = moduleSliderCounter + 1
        local slName = "LootEnhSoloModSl" .. moduleSliderCounter
        local slider = CreateFrame("Slider", slName, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", x, y)
        slider:SetWidth(w)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        if slider.SetObeyStepOnDrag then
            slider:SetObeyStepOnDrag(true)
        end

        _G[slName .. "Low"]:SetText(isFloat and string.format("%.1f", min) or min)
        _G[slName .. "High"]:SetText(isFloat and string.format("%.1f", max) or max)
        _G[slName .. "Text"]:SetText(label)

        local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valText:SetPoint("TOP", slider, "BOTTOM", 0, -10)

        local mod = MonLootDB.solo and MonLootDB.solo[modKey]
        local current = (mod and mod[settingKey]) or min
        slider:SetValue(current)
        valText:SetText(isFloat and string.format("%.2f", current) or current)

        slider:SetScript("OnValueChanged", function(self, value)
            local snapped = math.floor(value / step + 0.5) * step
            if isFloat then
                snapped = tonumber(string.format("%.2f", snapped))
            end
            if snapped ~= value then
                self:SetValue(snapped)
                return
            end
            valText:SetText(isFloat and string.format("%.2f", snapped) or snapped)
            if MonLootDB.solo and MonLootDB.solo[modKey] then
                MonLootDB.solo[modKey][settingKey] = snapped
            end
            if onChange then onChange(snapped) end
        end)
        slider.Refresh = function()
            local m = MonLootDB.solo and MonLootDB.solo[modKey]
            local val = (m and m[settingKey]) or min
            slider:SetValue(val)
            valText:SetText(isFloat and string.format("%.2f", val) or val)
        end
        table.insert(LootEnh_AllControls, slider)
        soloControls[#soloControls + 1] = slider
        return slider
    end

    local function ModuleDropdown(parent, modKey, settingKey, label, x, y, w, options, valueMap, onChange)
        moduleDropdownCounter = moduleDropdownCounter + 1
        local ddName = "LootEnhSoloModDD" .. moduleDropdownCounter
        local frame = CreateFrame("Frame", ddName, parent, "UIDropDownMenuTemplate")
        frame:SetPoint("TOPLEFT", x, y)
        UIDropDownMenu_SetWidth(frame, w)

        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 20, 0)
        text:SetText(label)

        LootEnh_SafeDropDownInit(frame, function(self)
            local info = UIDropDownMenu_CreateInfo()
            for i, v in ipairs(options) do
                info.text = v
                info.value = i
                info.func = function(btn)
                    UIDropDownMenu_SetSelectedID(frame, btn.value)
                    local stored = valueMap and valueMap[btn.value] or btn.value
                    if MonLootDB.solo and MonLootDB.solo[modKey] then
                        MonLootDB.solo[modKey][settingKey] = stored
                    end
                    if onChange then onChange(stored) end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        -- Find current selected index
        local mod = MonLootDB.solo and MonLootDB.solo[modKey]
        local current = mod and mod[settingKey]
        if valueMap then
            for i, v in ipairs(valueMap) do
                if v == current then
                    UIDropDownMenu_SetSelectedID(frame, i)
                    break
                end
            end
        else
            UIDropDownMenu_SetSelectedID(frame, current or 1)
        end

        frame.Refresh = function()
            local m = MonLootDB.solo and MonLootDB.solo[modKey]
            local val = m and m[settingKey]
            LootEnh_SafeDropDownInit(frame, function(self)
                local info = UIDropDownMenu_CreateInfo()
                for i, v in ipairs(options) do
                    info.text = v
                    info.value = i
                    info.func = function(btn)
                        UIDropDownMenu_SetSelectedID(frame, btn.value)
                        local stored = valueMap and valueMap[btn.value] or btn.value
                        if MonLootDB.solo and MonLootDB.solo[modKey] then
                            MonLootDB.solo[modKey][settingKey] = stored
                        end
                        if onChange then onChange(stored) end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            if valueMap then
                for i, v in ipairs(valueMap) do
                    if v == val then
                        UIDropDownMenu_SetSelectedID(frame, i)
                        break
                    end
                end
            else
                UIDropDownMenu_SetSelectedID(frame, val or 1)
            end
        end
        table.insert(LootEnh_AllControls, frame)
        soloControls[#soloControls + 1] = frame
        return frame
    end

    -- ============================================================
    -- Module header helper
    -- ============================================================

    local function CreateModuleHeader(parent, y, text, color)
        local h = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 16, y)
        h:SetText(color .. text .. "|r")
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", h, "RIGHT", 6, 0)
        line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
        line:SetTexture(0.4, 0.4, 0.4, 0.6)
        return h
    end

    -- ============================================================
    -- Module: Items (loot)
    -- ============================================================
    local y = -80
    CreateModuleHeader(SPanel, y, ld.SOLO_MOD_LOOT, "|cff1eff00")

    ModuleCheck(SPanel, "loot", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(SPanel, "loot", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    local rarityLabels = {
        ld.RARITY_POOR, ld.RARITY_COMMON, ld.RARITY_UNCOMMON,
        ld.RARITY_RARE, ld.RARITY_EPIC, ld.RARITY_LEGENDARY,
    }
    local rarityValues = {0, 1, 2, 3, 4, 5}
    ModuleDropdown(SPanel, "loot", "minRarity", ld.SOLO_LOOT_MIN_RARITY, 0, y - 72, 120, rarityLabels, rarityValues)

    ModuleCheck(SPanel, "loot", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 110)
    ModuleCheck(SPanel, "loot", "showBagCount", ld.SOLO_LOOT_SHOW_BAG, 200, y - 110)
    ModuleCheck(SPanel, "loot", "questHighlight", ld.SOLO_LOOT_QUEST_HL, 16, y - 135)

    -- ============================================================
    -- Module: Gold
    -- ============================================================
    y = -240
    CreateModuleHeader(SPanel, y, ld.SOLO_MOD_GOLD, "|cffffd700")

    ModuleCheck(SPanel, "gold", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(SPanel, "gold", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    ModuleCheck(SPanel, "gold", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 70)
    ModuleCheck(SPanel, "gold", "showSessionTotal", ld.SOLO_GOLD_SESSION, 200, y - 70)

    -- ============================================================
    -- Module: Experience (xp)
    -- ============================================================
    y = -340
    CreateModuleHeader(SPanel, y, ld.SOLO_MOD_XP, "|cff8080ff")

    ModuleCheck(SPanel, "xp", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(SPanel, "xp", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    ModuleCheck(SPanel, "xp", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 70)

    -- ============================================================
    -- Module: Reputation (rep)
    -- ============================================================
    y = -420
    CreateModuleHeader(SPanel, y, ld.SOLO_MOD_REP, "|cff40c040")

    ModuleCheck(SPanel, "rep", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(SPanel, "rep", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    ModuleCheck(SPanel, "rep", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 70)

    -- ============================================================
    -- Shared Solo Bar Appearance section
    -- ============================================================
    local function OnSoloSettingChanged() RefreshActiveSoloFrames() end

    local appearY = -520

    local sepAppear = SPanel:CreateTexture(nil, "ARTWORK")
    sepAppear:SetHeight(1)
    sepAppear:SetPoint("TOPLEFT", 16, appearY)
    sepAppear:SetPoint("TOPRIGHT", -16, appearY)
    sepAppear:SetTexture(0.4, 0.4, 0.4, 0.6)

    local appearTitle = SPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearTitle:SetPoint("TOPLEFT", 16, appearY - 15)
    appearTitle:SetText(ld.SOLO_APPEARANCE_TITLE)

    -- Row 1: Strata + Growth Direction dropdowns
    local strataOptions = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG"}
    local ddStrata = LootEnh_CreateGenericDropdown(
        SPanel, 0, appearY - 40, 110, ld.SOLO_STRATA,
        "solo", "strata", strataOptions, strataOptions, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = ddStrata

    local growOptions = {ld.SOLO_GROW_UP, ld.SOLO_GROW_DOWN}
    local growValues = {"up", "down"}
    local ddGrow = LootEnh_CreateGenericDropdown(
        SPanel, 230, appearY - 40, 110, ld.SOLO_GROWTH,
        "solo", "growDir", growOptions, growValues, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = ddGrow

    -- Row 2: Scale + Alpha sliders
    local slScale = LootEnh_CreateSlider(
        SPanel, 16, appearY - 115, 180, ld.SOLO_SCALE,
        "solo", "scale", 0.5, 2.0, 0.05, true, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slScale

    local slAlpha = LootEnh_CreateSlider(
        SPanel, 250, appearY - 115, 180, ld.SOLO_ALPHA,
        "solo", "alpha", 0.1, 1.0, 0.05, true, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slAlpha

    -- Row 3: Spacing + MaxBars sliders
    local slSpacing = LootEnh_CreateSlider(
        SPanel, 16, appearY - 165, 180, ld.SOLO_SPACING,
        "solo", "spacing", 0, 20, 1, false, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slSpacing

    local slMaxBars = LootEnh_CreateSlider(
        SPanel, 250, appearY - 165, 180, ld.SOLO_MAX_BARS,
        "solo", "maxBars", 1, 10, 1, false, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slMaxBars

    -- ============================================================
    -- Separator + Solo Chat Filtering
    -- ============================================================
    local sepY = appearY - 210

    local sep = SPanel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 16, sepY)
    sep:SetPoint("TOPRIGHT", -16, sepY)
    sep:SetTexture(0.4, 0.4, 0.4, 0.6)

    -- Solo Chat Filtering radio buttons
    local filterTitle = SPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    filterTitle:SetPoint("TOPLEFT", 16, sepY - 15)
    filterTitle:SetText(ld.SOLO_FILTER_TITLE)

    local function CreateSoloRadio(id, label, ry)
        local rb = CreateFrame("CheckButton", "LootEnhSoloRadio" .. id, SPanel, "UIRadioButtonTemplate")
        rb:SetPoint("TOPLEFT", 20, ry)
        _G[rb:GetName() .. "Text"]:SetText(label)
        rb:SetChecked(MonLootDB.soloFilterMode == id)
        rb:SetScript("OnClick", function()
            MonLootDB.soloFilterMode = id
            for i = 1, 3 do
                _G["LootEnhSoloRadio" .. i]:SetChecked(i == id)
            end
        end)
        soloControls[#soloControls + 1] = rb
    end

    CreateSoloRadio(1, ld.SOLO_MODE_NORMAL, sepY - 40)
    CreateSoloRadio(2, ld.SOLO_MODE_CLEAN, sepY - 65)
    CreateSoloRadio(3, ld.SOLO_MODE_SILENCE, sepY - 90)

    -- Store controls for gray-out
    LootEnh_PanelState.soloControls = soloControls

    local function RefreshSoloGray()
        LootEnh_SetControlsEnabled(soloControls, MonLootDB.solo and MonLootDB.solo.enabled)
    end

    -- Wire the Enable Solo checkbox from Panel_Main
    local cbEnableSolo = _G["LootEnhCBEnableSolo"]
    if cbEnableSolo then
        cbEnableSolo:SetScript("OnClick", function(self)
            MonLootDB.solo.enabled = self:GetChecked()
            RefreshSoloGray()
        end)
    end

    SPanel:SetScript("OnShow", RefreshSoloGray)

    InterfaceOptions_AddCategory(SPanel)
end

-- ============================================================
-- Display Frames panel — appearance settings for Group + Solo
-- loot bars, merged in one scrollable page. Chat filtering
-- lives in its own Chat panel (Panel_Chat.lua).
-- ============================================================

function LootEnh_CreateDisplayPanel()
    local ld = L()

    local DPanel = CreateFrame("Frame", "LootEnhDisplayPanel", UIParent)
    DPanel.name = ld.CAT_DISPLAY
    DPanel.parent = "LootEnh"

    local title = DPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ld.CAT_DISPLAY_TITLE)

    local groupControls = {}
    local soloControls = {}

    -- ============================================================
    -- ScrollFrame: everything below the title goes inside
    -- ============================================================
    local scrollFrame = CreateFrame("ScrollFrame", "LootEnhDisplayScroll", DPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -44)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)

    local scrollChild = CreateFrame("Frame", "LootEnhDisplayScrollChild", scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 460)
    scrollChild:SetHeight(1150)
    scrollFrame:SetScrollChild(scrollChild)

    DPanel:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w - 26)
    end)

    local C = scrollChild

    local function SectionHeader(y, text, color)
        local h = C:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 16, y)
        h:SetText(color .. text .. "|r")
        local line = C:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", h, "RIGHT", 6, 0)
        line:SetPoint("RIGHT", C, "RIGHT", -16, 0)
        line:SetTexture(0.4, 0.4, 0.4, 0.6)
        return h
    end

    -- ============================================================
    -- Section: Group Loot Bars
    -- ============================================================
    SectionHeader(-5, ld.DISPLAY_GROUP_SECTION, "|cff00ccff")

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

    local btn1 = CreateFrame("Button", "LootEnhTestOne", C, "UIPanelButtonTemplate")
    btn1:SetSize(90, 24)
    btn1:SetPoint("TOPLEFT", 16, -30)
    btn1:SetText(ld.LOOT_TEST_ONE)
    btn1:SetScript("OnClick", function()
        LootEnh_ShowLootBar(nil, "Test Item", testIcons[1], testNames[1], 10)
    end)

    local btn3 = CreateFrame("Button", "LootEnhTestThree", C, "UIPanelButtonTemplate")
    btn3:SetSize(90, 24)
    btn3:SetPoint("LEFT", btn1, "RIGHT", 8, 0)
    btn3:SetText(ld.LOOT_TEST_THREE)
    btn3:SetScript("OnClick", function()
        for i = 1, 3 do
            LootEnh_ShowLootBar(nil, "Test Item " .. i, testIcons[i], testNames[i], 10 + i * 2)
        end
    end)

    local btnReset = CreateFrame("Button", "LootEnhResetAnchors", C, "UIPanelButtonTemplate")
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

    local gy = -65
    local function OnGroupSettingChanged() LootEnh_RefreshActiveLootFrames() end

    -- Row 1: Strata + Growth Direction
    local strataOptions = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG"}
    local ddStrata = LootEnh_CreateGenericDropdown(C, 0, gy, 110, ld.LOOT_STRATA, "lootFrame", "strata", strataOptions, strataOptions, OnGroupSettingChanged)

    local growOptions = {ld.LOOT_GROW_UP, ld.LOOT_GROW_DOWN}
    local growValues = {"up", "down"}
    local ddGrow = LootEnh_CreateGenericDropdown(C, 230, gy, 110, ld.LOOT_GROWTH, "lootFrame", "growDir", growOptions, growValues, OnGroupSettingChanged)

    -- Row 2: Scale + Opacity
    local slScale = LootEnh_CreateSlider(C, 16, gy - 75, 180, ld.LOOT_SCALE, "lootFrame", "scale", 0.5, 2.0, 0.05, true, OnGroupSettingChanged)
    local slAlpha = LootEnh_CreateSlider(C, 250, gy - 75, 180, ld.LOOT_ALPHA, "lootFrame", "alpha", 0.1, 1.0, 0.05, true, OnGroupSettingChanged)

    -- Row 3: Spacing + Max Bars
    local slSpacing = LootEnh_CreateSlider(C, 16, gy - 125, 180, ld.LOOT_SPACING, "lootFrame", "spacing", 0, 20, 1, false, OnGroupSettingChanged)
    local slMaxBars = LootEnh_CreateSlider(C, 250, gy - 125, 180, ld.LOOT_MAX_BARS, "lootFrame", "maxBars", 1, 10, 1, false, OnGroupSettingChanged)

    -- Row 4: Quality theming
    local cbQualBar = LootEnh_CreateCheckSub(C, "lootFrame", "qualityBar", ld.LOOT_QUALITY_BAR, 16, gy - 170)
    local cbQualBorder = LootEnh_CreateCheckSub(C, "lootFrame", "qualityIconBorder", ld.LOOT_QUALITY_BORDER, 250, gy - 170)

    -- Row 5: Entry animation
    local animOptions = {ld.ANIM_NONE, ld.ANIM_FADE, ld.ANIM_SLIDE, ld.ANIM_POP}
    local animValues = {"none", "fade", "slide", "pop"}
    local ddGroupAnim = LootEnh_CreateGenericDropdown(C, 0, gy - 215, 110, ld.LOOT_ANIM_STYLE, "lootFrame", "animStyle", animOptions, animValues)

    groupControls = {btn1, btn3, ddStrata, ddGrow, slScale, slAlpha, slSpacing, slMaxBars, cbQualBar, cbQualBorder, ddGroupAnim}

    -- ============================================================
    -- Section: Solo Loot Bars
    -- ============================================================
    local SB = -330
    SectionHeader(SB, ld.DISPLAY_SOLO_SECTION, "|cff00ff88")

    local btnTest = CreateFrame("Button", "LootEnhSoloTest", C, "UIPanelButtonTemplate")
    btnTest:SetSize(80, 24)
    btnTest:SetPoint("TOPLEFT", 16, SB - 25)
    btnTest:SetText(ld.SOLO_TEST)
    btnTest:SetScript("OnClick", function()
        LootEnh_TestSoloBars()
    end)
    soloControls[#soloControls + 1] = btnTest

    -- Local helpers for 3-level settings (MonLootDB.solo[modKey][settingKey])
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

        local function Init(self)
            local info = UIDropDownMenu_CreateInfo()
            for i, v in ipairs(options) do
                info.text = v
                info.value = i
                info.func = function(btn)
                    UIDropDownMenu_SetSelectedID(frame, btn.value)
                    UIDropDownMenu_SetText(frame, options[btn.value])
                    local stored = valueMap and valueMap[btn.value] or btn.value
                    if MonLootDB.solo and MonLootDB.solo[modKey] then
                        MonLootDB.solo[modKey][settingKey] = stored
                    end
                    if onChange then onChange(stored) end
                end
                UIDropDownMenu_AddButton(info)
            end
        end

        local function SetFromDB()
            local mod = MonLootDB.solo and MonLootDB.solo[modKey]
            local current = mod and mod[settingKey]
            if valueMap then
                for i, v in ipairs(valueMap) do
                    if v == current then
                        UIDropDownMenu_SetSelectedID(frame, i)
                        UIDropDownMenu_SetText(frame, options[i])
                        break
                    end
                end
            else
                local idx = current or 1
                UIDropDownMenu_SetSelectedID(frame, idx)
                UIDropDownMenu_SetText(frame, options[idx])
            end
        end

        LootEnh_SafeDropDownInit(frame, Init)
        SetFromDB()
        frame.Refresh = function()
            LootEnh_SafeDropDownInit(frame, Init)
            SetFromDB()
        end
        table.insert(LootEnh_AllControls, frame)
        soloControls[#soloControls + 1] = frame
        return frame
    end

    local function ModuleHeader(y, text, color)
        local h = C:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 16, y)
        h:SetText(color .. text .. "|r")
        local line = C:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", h, "RIGHT", 6, 0)
        line:SetPoint("RIGHT", C, "RIGHT", -16, 0)
        line:SetTexture(0.4, 0.4, 0.4, 0.6)
        return h
    end

    -- ============================================================
    -- Module: Items (loot)
    -- ============================================================
    local y = SB - 60
    ModuleHeader(y, ld.SOLO_MOD_LOOT, "|cff1eff00")

    ModuleCheck(C, "loot", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(C, "loot", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    local rarityLabels = {
        ld.RARITY_POOR, ld.RARITY_COMMON, ld.RARITY_UNCOMMON,
        ld.RARITY_RARE, ld.RARITY_EPIC, ld.RARITY_LEGENDARY,
    }
    local rarityValues = {0, 1, 2, 3, 4, 5}
    ModuleDropdown(C, "loot", "minRarity", ld.SOLO_LOOT_MIN_RARITY, 0, y - 72, 120, rarityLabels, rarityValues)

    ModuleCheck(C, "loot", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 110)
    ModuleCheck(C, "loot", "showBagCount", ld.SOLO_LOOT_SHOW_BAG, 200, y - 110)
    ModuleCheck(C, "loot", "questHighlight", ld.SOLO_LOOT_QUEST_HL, 16, y - 135)
    ModuleCheck(C, "loot", "qualityIconBorder", ld.LOOT_QUALITY_BORDER, 200, y - 135)

    -- ============================================================
    -- Module: Gold
    -- ============================================================
    y = SB - 220
    ModuleHeader(y, ld.SOLO_MOD_GOLD, "|cffffd700")

    ModuleCheck(C, "gold", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(C, "gold", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    ModuleCheck(C, "gold", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 70)
    ModuleCheck(C, "gold", "showSessionTotal", ld.SOLO_GOLD_SESSION, 200, y - 70)

    -- ============================================================
    -- Module: Experience (xp)
    -- ============================================================
    y = SB - 320
    ModuleHeader(y, ld.SOLO_MOD_XP, "|cff8080ff")

    ModuleCheck(C, "xp", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(C, "xp", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    ModuleCheck(C, "xp", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 70)

    -- ============================================================
    -- Module: Reputation (rep)
    -- ============================================================
    y = SB - 400
    ModuleHeader(y, ld.SOLO_MOD_REP, "|cff40c040")

    ModuleCheck(C, "rep", "enabled", ld.SOLO_MOD_ENABLE, 16, y - 22)
    ModuleSlider(C, "rep", "duration", ld.SOLO_MOD_DURATION, 200, y - 28, 160, 1, 15, 1, false)

    ModuleCheck(C, "rep", "cumulate", ld.SOLO_MOD_CUMULATE, 16, y - 70)

    -- ============================================================
    -- Solo Bar Appearance (shared visuals)
    -- ============================================================
    local function OnSoloSettingChanged() LootEnh_RefreshActiveSoloFrames() end

    local appearY = SB - 500
    ModuleHeader(appearY, ld.SOLO_APPEARANCE_TITLE, "|cffffffff")

    local ddSoloStrata = LootEnh_CreateGenericDropdown(
        C, 0, appearY - 40, 110, ld.SOLO_STRATA,
        "solo", "strata", strataOptions, strataOptions, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = ddSoloStrata

    local soloGrowOptions = {ld.SOLO_GROW_UP, ld.SOLO_GROW_DOWN}
    local ddSoloGrow = LootEnh_CreateGenericDropdown(
        C, 230, appearY - 40, 110, ld.SOLO_GROWTH,
        "solo", "growDir", soloGrowOptions, growValues, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = ddSoloGrow

    local slSoloScale = LootEnh_CreateSlider(
        C, 16, appearY - 115, 180, ld.SOLO_SCALE,
        "solo", "scale", 0.5, 2.0, 0.05, true, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slSoloScale

    local slSoloAlpha = LootEnh_CreateSlider(
        C, 250, appearY - 115, 180, ld.SOLO_ALPHA,
        "solo", "alpha", 0.1, 1.0, 0.05, true, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slSoloAlpha

    local slSoloSpacing = LootEnh_CreateSlider(
        C, 16, appearY - 165, 180, ld.SOLO_SPACING,
        "solo", "spacing", 0, 20, 1, false, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slSoloSpacing

    local slSoloMaxBars = LootEnh_CreateSlider(
        C, 250, appearY - 165, 180, ld.SOLO_MAX_BARS,
        "solo", "maxBars", 1, 10, 1, false, OnSoloSettingChanged
    )
    soloControls[#soloControls + 1] = slSoloMaxBars

    local ddSoloAnim = LootEnh_CreateGenericDropdown(
        C, 0, appearY - 220, 110, ld.LOOT_ANIM_STYLE,
        "solo", "animStyle", animOptions, animValues
    )
    soloControls[#soloControls + 1] = ddSoloAnim

    -- Fit scroll height (last control: solo anim dropdown at appearY - 220)
    scrollChild:SetHeight(math.abs(appearY - 260) + 30)

    -- ============================================================
    -- Gray-out wiring (Enable checkboxes live on the main panel)
    -- ============================================================
    LootEnh_PanelState.lootFrameControls = groupControls
    LootEnh_PanelState.soloControls = soloControls

    local function RefreshGroupGray()
        LootEnh_SetControlsEnabled(groupControls, MonLootDB.enableLootFrame)
    end
    local function RefreshSoloGray()
        LootEnh_SetControlsEnabled(soloControls, MonLootDB.solo and MonLootDB.solo.enabled)
    end

    local cbEnableLF = _G["LootEnhCBEnableLF"]
    if cbEnableLF then
        cbEnableLF:SetScript("OnClick", function(self)
            MonLootDB.enableLootFrame = self:GetChecked()
            RefreshGroupGray()
        end)
    end
    local cbEnableSolo = _G["LootEnhCBEnableSolo"]
    if cbEnableSolo then
        cbEnableSolo:SetScript("OnClick", function(self)
            MonLootDB.solo.enabled = self:GetChecked()
            RefreshSoloGray()
        end)
    end

    DPanel:SetScript("OnShow", function()
        RefreshGroupGray()
        RefreshSoloGray()
    end)

    InterfaceOptions_AddCategory(DPanel)
end

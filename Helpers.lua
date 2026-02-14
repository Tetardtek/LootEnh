local dropdownCounter = 0
local sliderCounter = 0

function LootEnh_CreateCheck(parent, key, label, y)
    local cb = CreateFrame("CheckButton", parent:GetName() .. key, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetChecked(MonLootDB[key])
    cb:SetScript("OnClick", function(self)
        MonLootDB[key] = self:GetChecked()
    end)
    cb.Refresh = function()
        cb:SetChecked(MonLootDB[key])
    end
    table.insert(LootEnh_AllControls, cb)
    return cb
end

function LootEnh_CreateDropdown(parent, x, y, width, label, dbKey, subKey, itemID, fallbackIcon)
    dropdownCounter = dropdownCounter + 1
    local parentName = parent:GetName() or ("LootEnhDD" .. dropdownCounter)
    local frame = CreateFrame("Frame", parentName .. dbKey .. (subKey or ""), parent, "UIDropDownMenuTemplate")
    frame:SetPoint("TOPLEFT", x, y)
    UIDropDownMenu_SetWidth(frame, width)

    -- Infos de l'objet (Cache-safe)
    local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID or 0)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 36, 0)
    text:SetText(itemName or label)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("RIGHT", text, "LEFT", -5, -2)
    icon:SetTexture(itemTexture or fallbackIcon or "Interface\\Icons\\inv_misc_questionmark")

    -- Tooltip Interactive
    local tipArea = CreateFrame("Frame", nil, frame)
    tipArea:SetSize(width + 20, 25)
    tipArea:SetPoint("LEFT", icon, "LEFT")
    tipArea:EnableMouse(true)

    tipArea:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if itemID then
            GameTooltip:SetHyperlink("item:" .. itemID)
        else
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine("General rule for this category.", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    tipArea:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    LootEnh_SafeDropDownInit(frame, function(self)
        local ld = L()
        local info = UIDropDownMenu_CreateInfo()
        local opts = {ld.ROLL_NEED, ld.ROLL_GREED, ld.ROLL_PASS, ld.ROLL_MANUAL}
        for i, v in ipairs(opts) do
            info.text = v;
            info.value = i;
            info.func = function(btn)
                UIDropDownMenu_SetSelectedID(frame, btn.value)
                if subKey then
                    MonLootDB[dbKey][subKey] = btn.value
                else
                    MonLootDB[dbKey] = btn.value
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local current = subKey and MonLootDB[dbKey][subKey] or MonLootDB[dbKey]
    UIDropDownMenu_SetSelectedID(frame, current or 4)
    frame.Refresh = function()
        local val = subKey and MonLootDB[dbKey][subKey] or MonLootDB[dbKey]
        LootEnh_SafeDropDownInit(frame, function(self)
            local ld = L()
            local info = UIDropDownMenu_CreateInfo()
            local opts = {ld.ROLL_NEED, ld.ROLL_GREED, ld.ROLL_PASS, ld.ROLL_MANUAL}
            for i, v in ipairs(opts) do
                info.text = v; info.value = i
                info.func = function(btn)
                    UIDropDownMenu_SetSelectedID(frame, btn.value)
                    if subKey then
                        MonLootDB[dbKey][subKey] = btn.value
                    else
                        MonLootDB[dbKey] = btn.value
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedID(frame, val or 4)
    end
    table.insert(LootEnh_AllControls, frame)
    return frame
end

function LootEnh_CreateSlider(parent, x, y, width, label, dbKey, subKey, min, max, step, isFloat, onChange)
    sliderCounter = sliderCounter + 1
    local parentName = parent:GetName() or ("LootEnhSL" .. sliderCounter)
    local slider = CreateFrame("Slider", parentName .. (subKey or dbKey), parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(width)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    _G[slider:GetName() .. "Low"]:SetText(isFloat and string.format("%.1f", min) or min)
    _G[slider:GetName() .. "High"]:SetText(isFloat and string.format("%.1f", max) or max)
    _G[slider:GetName() .. "Text"]:SetText(label)

    local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("TOP", slider, "BOTTOM", 0, -10)

    local db = MonLootDB[dbKey]
    local current
    if subKey and db then
        current = db[subKey]
    else
        current = db
    end
    slider:SetValue(current or min)
    valText:SetText(isFloat and string.format("%.2f", current or min) or (current or min))

    slider:SetScript("OnValueChanged", function(self, value)
        -- Manual snap for 3.3.0 compat
        local snapped = math.floor(value / step + 0.5) * step
        if isFloat then
            snapped = tonumber(string.format("%.2f", snapped))
        end
        if snapped ~= value then
            self:SetValue(snapped)
            return
        end
        valText:SetText(isFloat and string.format("%.2f", snapped) or snapped)
        if subKey then
            if not MonLootDB[dbKey] then MonLootDB[dbKey] = {} end
            MonLootDB[dbKey][subKey] = snapped
        else
            MonLootDB[dbKey] = snapped
        end
        if onChange then onChange(snapped) end
    end)
    slider.Refresh = function()
        local val
        if subKey and MonLootDB[dbKey] then
            val = MonLootDB[dbKey][subKey]
        else
            val = MonLootDB[dbKey]
        end
        slider:SetValue(val or min)
        valText:SetText(isFloat and string.format("%.2f", val or min) or (val or min))
    end
    table.insert(LootEnh_AllControls, slider)
    return slider
end

function LootEnh_CreateGenericDropdown(parent, x, y, width, label, dbKey, subKey, options, valueMap, onChange)
    dropdownCounter = dropdownCounter + 1
    local parentName = parent:GetName() or ("LootEnhGDD" .. dropdownCounter)
    local frame = CreateFrame("Frame", parentName .. (subKey or dbKey), parent, "UIDropDownMenuTemplate")
    frame:SetPoint("TOPLEFT", x, y)
    UIDropDownMenu_SetWidth(frame, width)

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
                local stored
                if valueMap then
                    stored = valueMap[btn.value]
                else
                    stored = btn.value
                end
                if subKey then
                    if not MonLootDB[dbKey] then MonLootDB[dbKey] = {} end
                    MonLootDB[dbKey][subKey] = stored
                else
                    MonLootDB[dbKey] = stored
                end
                if onChange then onChange(stored) end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Find current selected index
    local db = MonLootDB[dbKey]
    local current
    if subKey and db then
        current = db[subKey]
    else
        current = db
    end
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
        local val
        if subKey and MonLootDB[dbKey] then
            val = MonLootDB[dbKey][subKey]
        else
            val = MonLootDB[dbKey]
        end
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
    return frame
end

function LootEnh_SetControlsEnabled(controls, enabled)
    for _, c in ipairs(controls) do
        if c.Enable and c.Disable then
            if enabled then c:Enable() else c:Disable() end
        end
        if c.EnableMouse then
            c:EnableMouse(enabled)
        end
        if c:GetObjectType() == "Slider" then
            local name = c:GetName()
            if name then
                local low = _G[name .. "Low"]
                local high = _G[name .. "High"]
                local text = _G[name .. "Text"]
                local color = enabled and 1 or 0.5
                if low then low:SetAlpha(color) end
                if high then high:SetAlpha(color) end
                if text then text:SetAlpha(color) end
            end
        end
        c:SetAlpha(enabled and 1 or 0.35)
    end
end

function LootEnh_LayoutSections(sections, scrollChild)
    local y = 0
    for _, sec in ipairs(sections) do
        sec.header:SetPoint("TOPLEFT", 16, y)
        sec.header:Show()
        y = y - 22
        if sec.expanded then
            sec.body:SetPoint("TOPLEFT", 0, y)
            sec.body:Show()
            y = y - sec.bodyHeight
        else
            sec.body:Hide()
        end
        y = y - 5
    end
    scrollChild:SetHeight(math.abs(y) + 20)
end

function LootEnh_CreateSection(scrollChild, sections, title, color, bodyHeight, buildFunc, toggleKey)
    local sec = {}
    sec.bodyHeight = bodyHeight
    sec.expanded = true

    -- Header (clickable)
    sec.header = CreateFrame("Button", nil, scrollChild)
    sec.header:SetSize(470, 20)

    local headerOffset = 0

    -- Toggle checkbox (optional)
    if toggleKey then
        local cb = CreateFrame("CheckButton", nil, sec.header, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("LEFT", 0, 0)
        cb:SetChecked(MonLootDB.sectionToggles[toggleKey] ~= false)
        cb:SetScript("OnClick", function(self)
            MonLootDB.sectionToggles[toggleKey] = self:GetChecked()
            sec.body:SetAlpha(self:GetChecked() and 1 or 0.35)
            sec.body:EnableMouse(not self:GetChecked() == false)
        end)
        sec.toggle = cb
        cb.Refresh = function()
            cb:SetChecked(MonLootDB.sectionToggles[toggleKey] ~= false)
            sec.body:SetAlpha(cb:GetChecked() and 1 or 0.35)
        end
        table.insert(LootEnh_AllControls, cb)
        headerOffset = 22
    end

    local arrow = sec.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("LEFT", headerOffset, 0)
    arrow:SetText("|cffffd100v|r")
    sec.arrow = arrow

    local hText = sec.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hText:SetPoint("LEFT", headerOffset + 14, 0)
    hText:SetText(color .. title .. "|r")

    local line = sec.header:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", hText, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", sec.header, "RIGHT", 0, 0)
    line:SetTexture(0.4, 0.4, 0.4, 0.6)

    sec.header:SetScript("OnClick", function()
        sec.expanded = not sec.expanded
        arrow:SetText(sec.expanded and "|cffffd100v|r" or "|cffffd100>|r")
        LootEnh_LayoutSections(sections, scrollChild)
    end)

    -- Body container
    sec.body = CreateFrame("Frame", nil, scrollChild)
    sec.body:SetSize(490, bodyHeight)

    buildFunc(sec.body)

    -- Apply initial gray state
    if toggleKey and MonLootDB.sectionToggles[toggleKey] == false then
        sec.body:SetAlpha(0.35)
    end

    sections[#sections + 1] = sec
    return sec
end

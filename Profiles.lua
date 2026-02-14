function LootEnh_GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

function LootEnh_RefreshAllPanels()
    -- Refresh all registered controls
    for _, ctrl in ipairs(LootEnh_AllControls) do
        if ctrl.Refresh then ctrl.Refresh() end
    end
    -- Refresh radio buttons on main panel
    for i = 1, 3 do
        local rb = _G["LootEnhRadio" .. i]
        if rb then rb:SetChecked(MonLootDB.filterMode == i) end
    end
    -- Refresh main panel checkboxes
    local cbHN = _G["LootEnhCBHideNative"]
    if cbHN then cbHN:SetChecked(MonLootDB.hideNative) end
    local cbLF = _G["LootEnhCBEnableLF"]
    if cbLF then cbLF:SetChecked(MonLootDB.enableLootFrame) end
    -- Refresh active loot frames visuals
    LootEnh_RefreshActiveLootFrames()
    -- Refresh solo frames visuals
    LootEnh_RefreshActiveSoloFrames()
    -- Refresh solo enable checkbox
    local cbSolo = _G["LootEnhCBEnableSolo"]
    if cbSolo then cbSolo:SetChecked(MonLootDB.solo and MonLootDB.solo.enabled) end
    -- Refresh solo radio buttons
    for i = 1, 3 do
        local rb = _G["LootEnhSoloRadio" .. i]
        if rb then rb:SetChecked(MonLootDB.soloFilterMode == i) end
    end
    -- Refresh main panel profile quick-select dropdowns
    if LootEnh_PanelState.mainProfileDD then
        for _, dd in ipairs(LootEnh_PanelState.mainProfileDD) do
            if dd.Refresh then dd.Refresh() end
        end
    end
    -- Refresh history panel opacity
    if LootHistory then
        LootHistory:SetBackdropColor(0, 0, 0, MonLootDB.histAlpha)
    end
    -- Refresh native loot toggle
    LootEnh_ToggleNativeLoot(MonLootDB.hideNative)
    -- Reposition anchors after profile load
    if LootAnchor then
        LootAnchor:ClearAllPoints()
        LootAnchor:SetPoint("CENTER", MonLootDB.anchorX, MonLootDB.anchorY)
    end
    if SoloAnchor then
        SoloAnchor:ClearAllPoints()
        SoloAnchor:SetPoint("CENTER", MonLootDB.soloAnchorX, MonLootDB.soloAnchorY)
    end
    if LootHistory then
        LootHistory:ClearAllPoints()
        LootHistory:SetPoint("RIGHT", MonLootDB.histX, MonLootDB.histY)
    end
end

function LootEnh_SaveProfile(ptype, name)
    local keys = LootEnh_PROFILE_KEYS[ptype]
    if not keys then return end
    local data = {}
    for _, k in ipairs(keys) do
        data[k] = LootEnh_DeepCopy(MonLootDB[k])
    end
    MonLootDB.profiles[ptype][name] = data
end

function LootEnh_LoadProfile(ptype, name)
    local keys = LootEnh_PROFILE_KEYS[ptype]
    local data = MonLootDB.profiles[ptype] and MonLootDB.profiles[ptype][name]
    if not keys or not data then return false end
    for _, k in ipairs(keys) do
        if data[k] ~= nil then
            MonLootDB[k] = LootEnh_DeepCopy(data[k])
        end
    end
    -- Memorize char → profile association
    local charKey = LootEnh_GetCharKey()
    MonLootDB.charProfiles[charKey] = MonLootDB.charProfiles[charKey] or {}
    MonLootDB.charProfiles[charKey][ptype] = name
    LootEnh_RefreshAllPanels()
    return true
end

function LootEnh_DeleteProfile(ptype, name)
    if MonLootDB.profiles[ptype] then
        MonLootDB.profiles[ptype][name] = nil
    end
    -- Clear char associations pointing to this deleted profile
    if MonLootDB.charProfiles then
        for charKey, assoc in pairs(MonLootDB.charProfiles) do
            if assoc[ptype] == name then
                assoc[ptype] = nil
            end
        end
    end
end

function LootEnh_ExportProfile(ptype, name)
    local data = MonLootDB.profiles[ptype] and MonLootDB.profiles[ptype][name]
    if not data then return nil end
    local prefix = ptype == "autoRoll" and "AR:" or "UI:"
    local serialized = LootEnh_SerializeTable(data)
    return prefix .. LootEnh_Base64Encode(serialized)
end

function LootEnh_ImportProfile(str)
    if type(str) ~= "string" or #str < 4 then return nil, nil end
    local prefix = str:sub(1, 3)
    local ptype
    if prefix == "AR:" then
        ptype = "autoRoll"
    elseif prefix == "UI:" then
        ptype = "ui"
    else
        return nil, nil
    end
    local encoded = str:sub(4)
    local decoded = LootEnh_Base64Decode(encoded)
    if not decoded then return nil, nil end
    local data = LootEnh_DeserializeTable(decoded)
    if not data then return nil, nil end
    return ptype, data
end

local PROFILE_TYPE_LABELS = {
    autoRoll = "Auto-Roll",
    ui = "UI",
}

function LootEnh_AutoLoadProfiles()
    local charKey = LootEnh_GetCharKey()
    local assoc = MonLootDB.charProfiles and MonLootDB.charProfiles[charKey]
    local ld = L()
    for _, ptype in ipairs({"autoRoll", "ui"}) do
        local label = PROFILE_TYPE_LABELS[ptype] or ptype
        local name = assoc and assoc[ptype]
        if name and MonLootDB.profiles[ptype] and MonLootDB.profiles[ptype][name] then
            LootEnh_LoadProfile(ptype, name)
            DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_AUTOLOADED, label, name))
        else
            DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_AUTOLOADED, label, "Default"))
        end
    end
end

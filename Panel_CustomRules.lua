function LootEnh_CreateCustomRulesPanel()
    local ld = L()

    local CRPanel = CreateFrame("Frame", "LootEnhCustomPanel", UIParent)
    CRPanel.name = "Custom Rules"
    CRPanel.parent = "LootEnh"

    local crt = CRPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    crt:SetPoint("TOPLEFT", 16, -16)
    crt:SetText(ld.CUSTOM_TITLE)

    local hint = CRPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -40)
    hint:SetText(ld.CUSTOM_HINT)

    -- Item Name label + EditBox
    local nameLabel = CRPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 16, -65)
    nameLabel:SetText(ld.CUSTOM_ITEM_NAME)

    local editBox = CreateFrame("EditBox", "LootEnhCustomEditBox", CRPanel, "InputBoxTemplate")
    editBox:SetSize(200, 22)
    editBox:SetPoint("TOPLEFT", 16, -80)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(100)

    -- Action label + Dropdown
    local actLabel = CRPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actLabel:SetPoint("TOPLEFT", 235, -65)
    actLabel:SetText(ld.CUSTOM_ACTION)

    local actionDropdown = CreateFrame("Frame", "LootEnhCustomActionDD", CRPanel, "UIDropDownMenuTemplate")
    actionDropdown:SetPoint("TOPLEFT", 220, -80)
    UIDropDownMenu_SetWidth(actionDropdown, 80)

    local selectedAction = 1
    LootEnh_SafeDropDownInit(actionDropdown, function()
        local info = UIDropDownMenu_CreateInfo()
        local opts = { ld.ROLL_NEED, ld.ROLL_GREED, ld.ROLL_PASS }
        for i, v in ipairs(opts) do
            info.text = v
            info.value = i
            info.func = function(btn)
                selectedAction = btn.value
                UIDropDownMenu_SetSelectedID(actionDropdown, btn.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedID(actionDropdown, 1)

    -- Add Button
    local addBtn = CreateFrame("Button", "LootEnhCustomAddBtn", CRPanel, "UIPanelButtonTemplate")
    addBtn:SetSize(70, 22)
    addBtn:SetPoint("TOPLEFT", 345, -83)
    addBtn:SetText(ld.CUSTOM_ADD)

    -- Separator
    local sep = CRPanel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 16, -112)
    sep:SetPoint("TOPRIGHT", -16, -112)
    sep:SetTexture(1, 1, 1, 0.3)

    -- Header row
    local hdrName = CRPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hdrName:SetPoint("TOPLEFT", 20, -118)
    hdrName:SetText(ld.CUSTOM_ITEM_NAME:gsub(":", ""))

    local hdrAction = CRPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hdrAction:SetPoint("TOPLEFT", 270, -118)
    hdrAction:SetText(ld.CUSTOM_ACTION:gsub(":", ""))

    -- "No rules" text
    local noRulesText = CRPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    noRulesText:SetPoint("TOPLEFT", 20, -145)
    noRulesText:SetText(ld.CUSTOM_NO_RULES)

    -- ScrollFrame for rule list
    local ROW_HEIGHT = 24
    local VISIBLE_ROWS = 10
    local scrollFrame = CreateFrame("ScrollFrame", "LootEnhCustomScrollFrame", CRPanel, "FauxScrollFrameTemplate")
    scrollFrame:SetSize(380, VISIBLE_ROWS * ROW_HEIGHT)
    scrollFrame:SetPoint("TOPLEFT", 16, -135)

    -- Create row pool
    local rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", "LootEnhCustomRow" .. i, CRPanel)
        row:SetSize(380, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 20, -135 - (i - 1) * ROW_HEIGHT)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.nameText:SetPoint("LEFT", 0, 0)
        row.nameText:SetWidth(240)
        row.nameText:SetJustifyH("LEFT")

        row.actionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.actionText:SetPoint("LEFT", 250, 0)
        row.actionText:SetWidth(70)
        row.actionText:SetJustifyH("LEFT")

        row.delBtn = CreateFrame("Button", "LootEnhCustomDel" .. i, row, "UIPanelButtonTemplate")
        row.delBtn:SetSize(22, 22)
        row.delBtn:SetPoint("LEFT", 330, 0)
        row.delBtn:SetText("X")

        rows[i] = row
    end

    -- Sorted keys cache and refresh function
    local sortedKeys = {}

    local function RefreshList()
        MonLootDB.customRules = MonLootDB.customRules or {}
        -- Rebuild sorted keys
        wipe(sortedKeys)
        for k in pairs(MonLootDB.customRules) do
            sortedKeys[#sortedKeys + 1] = k
        end
        table.sort(sortedKeys)

        local total = #sortedKeys
        noRulesText:SetShown(total == 0)
        scrollFrame:SetShown(total > 0)
        for _, r in ipairs(rows) do
            r:Hide()
        end
        if total == 0 then return end

        FauxScrollFrame_Update(scrollFrame, total, VISIBLE_ROWS, ROW_HEIGHT)
        local offset = FauxScrollFrame_GetOffset(scrollFrame)

        local actionNames = { ld.ROLL_NEED, ld.ROLL_GREED, ld.ROLL_PASS }
        for i = 1, VISIBLE_ROWS do
            local idx = offset + i
            if idx <= total then
                local itemName = sortedKeys[idx]
                local actionVal = MonLootDB.customRules[itemName]
                rows[i].nameText:SetText(itemName)
                rows[i].actionText:SetText(actionNames[actionVal] or "?")
                rows[i].delBtn:SetScript("OnClick", function()
                    local removed = itemName
                    MonLootDB.customRules[removed] = nil
                    DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.CUSTOM_REMOVED, removed))
                    RefreshList()
                end)
                rows[i]:Show()
            end
        end
    end

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, RefreshList)
    end)

    -- Add button logic
    addBtn:SetScript("OnClick", function()
        local raw = editBox:GetText()
        -- Strip color codes, brackets, and trim whitespace
        local cleaned = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""):gsub("[%[%]]", "")
        cleaned = cleaned:match("^%s*(.-)%s*$") or ""
        if cleaned == "" then return end

        MonLootDB.customRules[cleaned] = selectedAction
        editBox:SetText("")

        local actionNames = { ld.ROLL_NEED, ld.ROLL_GREED, ld.ROLL_PASS }
        DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.CUSTOM_ADDED, cleaned, actionNames[selectedAction] or "?"))
        RefreshList()
    end)

    -- Refresh when the panel is shown
    CRPanel:SetScript("OnShow", RefreshList)

    -- Shift-click interception to fill the edit box
    if not LootEnh_InsertLinkHooked then
        LootEnh_InsertLinkHooked = true
        local origInsertLink = ChatEdit_InsertLink
        ChatEdit_InsertLink = function(link, ...)
            if editBox and editBox:HasFocus() and link then
                local itemName = link:match("%[(.-)%]")
                if itemName then
                    editBox:SetText(itemName)
                    return true
                end
            end
            return origInsertLink(link, ...)
        end
    end

    LootEnh_AddOptionsCategory(CRPanel)
end

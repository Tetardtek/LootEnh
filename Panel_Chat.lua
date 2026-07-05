-- ============================================================
-- Chat panel — all chat filtering in one place, one uniform
-- control shape: a "Chat" dropdown per message source.
-- Sections: Group rolls / Solo messages.
-- Designed to grow: future channels get their own section.
-- ============================================================

function LootEnh_CreateChatPanel()
    local ld = L()

    local CPanel = CreateFrame("Frame", "LootEnhChatPanel", UIParent)
    CPanel.name = ld.CAT_CHAT
    CPanel.parent = "LootEnh"

    local title = CPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ld.CAT_CHAT_TITLE)

    local subtitle = CPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 16, -40)
    subtitle:SetText(ld.CHAT_SUBTITLE)

    local function SectionHeader(y, text, color)
        local h = CPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 16, y)
        h:SetText(color .. text .. "|r")
        local line = CPanel:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", h, "RIGHT", 6, 0)
        line:SetPoint("RIGHT", CPanel, "RIGHT", -16, 0)
        line:SetTexture(0.4, 0.4, 0.4, 0.6)
        return h
    end

    -- Row label at the left of each dropdown, same grid everywhere
    local function RowLabel(y, text)
        local l = CPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        l:SetPoint("TOPLEFT", 20, y - 12)
        l:SetText(text)
        return l
    end

    -- Dropdown bound to MonLootDB.solo[modKey].chatMode
    local chatDDCounter = 0
    local function SoloChatDropdown(modKey, y, options, valueMap)
        chatDDCounter = chatDDCounter + 1
        local ddName = "LootEnhChatDD" .. chatDDCounter
        local frame = CreateFrame("Frame", ddName, CPanel, "UIDropDownMenuTemplate")
        frame:SetPoint("TOPLEFT", 140, y)
        UIDropDownMenu_SetWidth(frame, 140)

        local function Init(self)
            local info = UIDropDownMenu_CreateInfo()
            for i, v in ipairs(options) do
                info.text = v
                info.value = i
                info.func = function(btn)
                    UIDropDownMenu_SetSelectedID(frame, btn.value)
                    UIDropDownMenu_SetText(frame, options[btn.value])
                    if MonLootDB.solo and MonLootDB.solo[modKey] then
                        MonLootDB.solo[modKey].chatMode = valueMap[btn.value]
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end

        local function SetFromDB()
            local mod = MonLootDB.solo and MonLootDB.solo[modKey]
            local current = (mod and mod.chatMode) or "all"
            for i, v in ipairs(valueMap) do
                if v == current then
                    UIDropDownMenu_SetSelectedID(frame, i)
                    UIDropDownMenu_SetText(frame, options[i])
                    break
                end
            end
        end

        LootEnh_SafeDropDownInit(frame, Init)
        SetFromDB()
        frame.Refresh = function()
            LootEnh_SafeDropDownInit(frame, Init)
            SetFromDB()
        end
        table.insert(LootEnh_AllControls, frame)
        return frame
    end

    local chatModes3 = {ld.SOLO_CHAT_ALL, ld.SOLO_CHAT_HIDE_GRAY, ld.SOLO_CHAT_HIDE_ALL}
    local chatValues3 = {"all", "hideGray", "hideAll"}
    local chatModes2 = {ld.SOLO_CHAT_ALL, ld.SOLO_CHAT_HIDE_ALL}
    local chatValues2 = {"all", "hideAll"}

    -- ============================================================
    -- Section: Group rolls
    -- ============================================================
    SectionHeader(-70, ld.CHAT_GROUP_SECTION, "|cff00ccff")

    RowLabel(-95, ld.CHAT_GROUP_ROLLS)
    local groupOptions = {ld.SOLO_CHAT_ALL, ld.GROUP_CHAT_FILTERED, ld.SOLO_CHAT_HIDE_ALL}
    local groupValues = {1, 2, 3}
    local ddGroup = LootEnh_CreateGenericDropdown(CPanel, 124, -95, 140, "", "filterMode", nil, groupOptions, groupValues)

    -- ============================================================
    -- Section: Solo messages
    -- ============================================================
    SectionHeader(-160, ld.CHAT_SOLO_SECTION, "|cff00ff88")

    RowLabel(-185, ld.SOLO_MOD_LOOT)
    SoloChatDropdown("loot", -185, chatModes3, chatValues3)

    RowLabel(-235, ld.SOLO_MOD_GOLD)
    SoloChatDropdown("gold", -235, chatModes2, chatValues2)

    RowLabel(-285, ld.SOLO_MOD_XP)
    SoloChatDropdown("xp", -285, chatModes2, chatValues2)

    RowLabel(-335, ld.SOLO_MOD_REP)
    SoloChatDropdown("rep", -335, chatModes2, chatValues2)

    InterfaceOptions_AddCategory(CPanel)
end

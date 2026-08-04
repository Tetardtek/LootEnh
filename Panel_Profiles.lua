-- Demande confirmation avant d'écraser un profil existant, puis exécute `write`.
--
-- Les trois chemins de sauvegarde (Sauvegarder sans sélection, Sauvegarder
-- sous, Importer) allaient droit à l'écriture : saisir un nom déjà pris
-- écrasait l'ancien sans un mot, et le message annonçait « sauvegardé » plutôt
-- qu'« écrasé ». La suppression, elle, demandait confirmation depuis toujours —
-- et le libellé PROF_CONFIRM_OVERWRITE était traduit dans les deux langues sans
-- avoir jamais été branché.
--
-- Envelopper l'écriture plutôt que patcher chaque site : les trois n'écrivent
-- pas de la même façon (deux passent par LootEnh_SaveProfile, l'import écrit
-- directement), et un quatrième chemin ajouté plus tard doit être obligé de
-- passer par ici.
local function WithOverwriteGuard(ptype, name, write)
    local profiles = MonLootDB.profiles and MonLootDB.profiles[ptype]
    if not profiles or profiles[name] == nil then
        write()
        return
    end
    local dialog = StaticPopup_Show("LOOTENH_CONFIRM_OVERWRITE",
        string.format(L().PROF_CONFIRM_OVERWRITE, name))
    if dialog then
        dialog.data = { callback = write }
    end
end

function LootEnh_CreateProfilesPanel()
    local ld = L()

    StaticPopupDialogs["LOOTENH_PROFILE_NAME"] = {
        text = "%s",
        button1 = OKAY,
        button2 = CANCEL,
        hasEditBox = true,
        editBoxWidth = 200,
        OnAccept = function(self)
            local name = self.editBox:GetText():match("^%s*(.-)%s*$") or ""
            if name == "" then
                DEFAULT_CHAT_FRAME:AddMessage(L().PROF_ERR_EMPTY_NAME)
                return
            end
            if self.data and self.data.callback then
                self.data.callback(name)
            end
        end,
        OnShow = function(self)
            self.editBox:SetText("")
            self.editBox:SetFocus()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["LOOTENH_EXPORT"] = {
        text = L().PROF_COPY_HINT,
        button1 = OKAY,
        hasEditBox = true,
        editBoxWidth = 350,
        OnShow = function(self)
            self.editBox:SetText(self.data or "")
            self.editBox:HighlightText()
            self.editBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["LOOTENH_CONFIRM_OVERWRITE"] = {
        text = "%s",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self)
            if self.data and self.data.callback then
                self.data.callback()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["LOOTENH_CONFIRM_DELETE"] = {
        text = "%s",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self)
            if self.data and self.data.callback then
                self.data.callback()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local ProfPanel = CreateFrame("Frame", "LootEnhProfilesPanel", UIParent)
    ProfPanel.name = "Profiles"
    ProfPanel.parent = "LootEnh"

    local pt = ProfPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pt:SetPoint("TOPLEFT", 16, -16)
    pt:SetText(ld.PROF_TITLE)

    -- Helper to build one profile section (Auto-Roll or UI)
    local function BuildProfileSection(parent, ptype, sectionLabel, startY)
        local selectedProfile = nil

        -- Section header
        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", 16, startY)
        header:SetText("|cffffd100" .. sectionLabel .. "|r")

        local sep = parent:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
        sep:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
        sep:SetTexture(0.4, 0.4, 0.4, 0.6)

        -- Dropdown label
        local ddLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        ddLabel:SetPoint("TOPLEFT", 16, startY - 22)
        ddLabel:SetText(ld.PROF_SELECT)

        -- Profile dropdown
        local dd = CreateFrame("Frame", "LootEnhProfDD_" .. ptype, parent, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", 70, startY - 18)
        UIDropDownMenu_SetWidth(dd, 160)

        local function RefreshProfileDropdown()
            -- Pre-select the character's active profile if one exists
            local charKey = LootEnh_GetCharKey()
            local assoc = MonLootDB.charProfiles and MonLootDB.charProfiles[charKey]
            local activeProfile = assoc and assoc[ptype] or nil
            -- Verify the profile still exists
            if activeProfile and not (MonLootDB.profiles[ptype] and MonLootDB.profiles[ptype][activeProfile]) then
                activeProfile = nil
            end
            -- Fall back to "Default" if no profile is associated
            if not activeProfile and MonLootDB.profiles[ptype] and MonLootDB.profiles[ptype]["Default"] then
                activeProfile = "Default"
            end
            selectedProfile = activeProfile
            LootEnh_SafeDropDownInit(dd, function()
                local info = UIDropDownMenu_CreateInfo()
                -- (none) entry
                info.text = ld.PROF_NONE
                info.value = nil
                info.checked = (selectedProfile == nil)
                info.func = function()
                    selectedProfile = nil
                    UIDropDownMenu_SetText(dd, ld.PROF_NONE)
                end
                UIDropDownMenu_AddButton(info)
                -- Sorted profile names
                local names = {}
                if MonLootDB.profiles[ptype] then
                    for n in pairs(MonLootDB.profiles[ptype]) do
                        names[#names + 1] = n
                    end
                end
                table.sort(names)
                for _, n in ipairs(names) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = n
                    info.value = n
                    info.checked = (n == selectedProfile)
                    info.func = function(btn)
                        selectedProfile = btn.value
                        UIDropDownMenu_SetText(dd, btn.value)
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            UIDropDownMenu_SetText(dd, selectedProfile or ld.PROF_NONE)
        end

        RefreshProfileDropdown()

        -- Buttons row
        local btnY = startY - 52
        local btnW, btnH, btnGap = 55, 22, 5

        -- Save (quick-save to selected profile, or popup if none selected)
        local btnSave = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnSave:SetSize(btnW, btnH)
        btnSave:SetPoint("TOPLEFT", 16, btnY)
        btnSave:SetText(ld.PROF_SAVE)
        btnSave:SetScript("OnClick", function()
            if selectedProfile then
                LootEnh_SaveProfile(ptype, selectedProfile)
                DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_OVERWRITTEN, selectedProfile))
                RefreshProfileDropdown()
            else
                -- No profile selected: behave like Save As
                local dialog = StaticPopup_Show("LOOTENH_PROFILE_NAME", ld.PROF_NAME_PROMPT)
                if dialog then
                    dialog.data = {
                        callback = function(name)
                            WithOverwriteGuard(ptype, name, function()
                                LootEnh_SaveProfile(ptype, name)
                                DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_SAVED, name))
                                selectedProfile = name
                                RefreshProfileDropdown()
                            end)
                        end
                    }
                end
            end
        end)

        -- Save As (always ask for name)
        local btnSaveAs = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnSaveAs:SetSize(btnW, btnH)
        btnSaveAs:SetPoint("LEFT", btnSave, "RIGHT", btnGap, 0)
        btnSaveAs:SetText(ld.PROF_SAVE_AS)
        btnSaveAs:SetScript("OnClick", function()
            local dialog = StaticPopup_Show("LOOTENH_PROFILE_NAME", ld.PROF_NAME_PROMPT)
            if dialog then
                dialog.data = {
                    callback = function(name)
                        WithOverwriteGuard(ptype, name, function()
                            LootEnh_SaveProfile(ptype, name)
                            DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_SAVED, name))
                            selectedProfile = name
                            RefreshProfileDropdown()
                        end)
                    end
                }
            end
        end)

        -- Load
        local btnLoad = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnLoad:SetSize(btnW, btnH)
        btnLoad:SetPoint("LEFT", btnSaveAs, "RIGHT", btnGap, 0)
        btnLoad:SetText(ld.PROF_LOAD)
        btnLoad:SetScript("OnClick", function()
            if not selectedProfile then
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_NO_SELECT)
                return
            end
            if LootEnh_LoadProfile(ptype, selectedProfile) then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_LOADED, selectedProfile))
            else
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_NO_DATA)
            end
        end)

        -- Delete
        local btnDel = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnDel:SetSize(btnW, btnH)
        btnDel:SetPoint("LEFT", btnLoad, "RIGHT", btnGap, 0)
        btnDel:SetText(ld.PROF_DELETE)
        btnDel:SetScript("OnClick", function()
            if not selectedProfile then
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_NO_SELECT)
                return
            end
            local profName = selectedProfile
            local dialog = StaticPopup_Show("LOOTENH_CONFIRM_DELETE", string.format(ld.PROF_CONFIRM_DELETE, profName))
            if dialog then
                dialog.data = {
                    callback = function()
                        LootEnh_DeleteProfile(ptype, profName)
                        DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_DELETED, profName))
                        RefreshProfileDropdown()
                    end
                }
            end
        end)

        -- Export
        local btnExport = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnExport:SetSize(btnW, btnH)
        btnExport:SetPoint("LEFT", btnDel, "RIGHT", btnGap, 0)
        btnExport:SetText(ld.PROF_EXPORT)
        btnExport:SetScript("OnClick", function()
            if not selectedProfile then
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_NO_SELECT)
                return
            end
            local str = LootEnh_ExportProfile(ptype, selectedProfile)
            if str then
                local dialog = StaticPopup_Show("LOOTENH_EXPORT")
                if dialog then
                    dialog.data = str
                    dialog.editBox:SetText(str)
                    dialog.editBox:HighlightText()
                end
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_EXPORTED)
            else
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_NO_DATA)
            end
        end)

        -- Import row
        local impLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        impLabel:SetPoint("TOPLEFT", 16, btnY - 30)
        impLabel:SetText(ld.PROF_IMPORT_LABEL)

        local impBox = CreateFrame("EditBox", "LootEnhProfImp_" .. ptype, parent, "InputBoxTemplate")
        impBox:SetSize(250, 22)
        impBox:SetPoint("TOPLEFT", 16, btnY - 45)
        impBox:SetAutoFocus(false)
        impBox:SetMaxLetters(5000)

        local btnImport = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnImport:SetSize(btnW, btnH)
        btnImport:SetPoint("LEFT", impBox, "RIGHT", btnGap, 0)
        btnImport:SetText(ld.PROF_IMPORT)
        btnImport:SetScript("OnClick", function()
            local raw = impBox:GetText()
            if not raw or raw == "" then
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_IMPORT)
                return
            end
            local impType, data = LootEnh_ImportProfile(raw)
            if not impType or not data then
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_IMPORT)
                return
            end
            if impType ~= ptype then
                DEFAULT_CHAT_FRAME:AddMessage(ld.PROF_ERR_IMPORT)
                return
            end
            -- Ask for name then save
            local dialog = StaticPopup_Show("LOOTENH_PROFILE_NAME", ld.PROF_NAME_PROMPT)
            if dialog then
                dialog.data = {
                    callback = function(name)
                        WithOverwriteGuard(ptype, name, function()
                            MonLootDB.profiles[ptype][name] = LootEnh_DeepCopy(data)
                            DEFAULT_CHAT_FRAME:AddMessage(string.format(ld.PROF_IMPORTED, name))
                            impBox:SetText("")
                            RefreshProfileDropdown()
                        end)
                    end
                }
            end
        end)

        -- Return total height consumed by this section
        return 110
    end

    local y = -45
    local h1 = BuildProfileSection(ProfPanel, "autoRoll", ld.PROF_AUTOROLL_SECTION, y)
    y = y - h1 - 15
    BuildProfileSection(ProfPanel, "ui", ld.PROF_UI_SECTION, y)

    LootEnh_AddOptionsCategory(ProfPanel)
end

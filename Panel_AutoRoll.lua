function LootEnh_CreateAutoRollPanel()
    local ld = L()

    local AutoPanel = CreateFrame("Frame", "LootEnhAutoPanel", UIParent)
    AutoPanel.name = "Auto-Roll";
    AutoPanel.parent = "LootEnh"
    local at = AutoPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    at:SetPoint("TOPLEFT", 16, -16)
    at:SetText(ld.AUTO_TITLE)

    -- Settings Generaux (fixed at top, outside scroll)
    local cbAutoRoll = LootEnh_CreateCheck(AutoPanel, "autoRoll", "|cff00ff00" .. ld.OPT_ENABLE_AUTO .. "|r", -50)
    local cbSkipBop = LootEnh_CreateCheck(AutoPanel, "skipBopDialog", ld.OPT_SKIP_BOP, -75)
    local cbBopProtect = LootEnh_CreateCheck(AutoPanel, "bopProtection", ld.OPT_BOP_PROTECT, -100)
    local autoRollControls = {cbSkipBop, cbBopProtect}
    LootEnh_PanelState.autoRollControls = autoRollControls

    local function RefreshAutoRollGray()
        LootEnh_SetControlsEnabled(autoRollControls, MonLootDB.autoRoll)
    end

    local origAutoRollClick = cbAutoRoll:GetScript("OnClick")
    cbAutoRoll:SetScript("OnClick", function(self)
        origAutoRollClick(self)
        RefreshAutoRollGray()
    end)

    AutoPanel:SetScript("OnShow", RefreshAutoRollGray)

    -- ScrollFrame pour le contenu des sections
    local scrollFrame = CreateFrame("ScrollFrame", "LootEnhAutoScroll", AutoPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -125)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)
    autoRollControls[#autoRollControls + 1] = scrollFrame

    local scrollChild = CreateFrame("Frame", "LootEnhAutoScrollChild", scrollFrame)
    scrollChild:SetWidth(490)
    scrollChild:SetHeight(1) -- sera recalcule dynamiquement
    scrollFrame:SetScrollChild(scrollChild)

    -- Fix z-order: dropdown menus must render above the ScrollFrame
    if DropDownList1 then DropDownList1:SetFrameStrata("TOOLTIP") end
    if DropDownList2 then DropDownList2:SetFrameStrata("TOOLTIP") end

    -- Collapsible sections
    local sections = {}

    -- SECTION : General Rules (Quality)
    LootEnh_CreateSection(scrollChild, sections, ld.CAT_GENERAL, "|cffffffff", 65, function(body)
        LootEnh_CreateDropdown(body, 0,   -10, 85, "Uncommon",  "qualityRules", "green",  nil, "Interface\\Icons\\inv_misc_coin_01")
        LootEnh_CreateDropdown(body, 100, -10, 85, "Rare",      "qualityRules", "blue",   nil, "Interface\\Icons\\inv_misc_coin_02")
        LootEnh_CreateDropdown(body, 200, -10, 85, "Epic",      "qualityRules", "purple", nil, "Interface\\Icons\\inv_misc_coin_03")
        LootEnh_CreateDropdown(body, 300, -10, 85, "Legendary", "qualityRules", "orange", nil, "Interface\\Icons\\inv_misc_coin_04")
        LootEnh_CreateDropdown(body, 400, -10, 85, "Vanity",    "qualityRules", "gold",   nil, "Interface\\Icons\\inv_misc_coin_05")
    end, "general")

    -- SECTION : Worldforged
    LootEnh_CreateSection(scrollChild, sections, ld.CAT_WORLDFORGED, "|cffffd100", 65, function(body)
        LootEnh_CreateDropdown(body, 0,   -10, 100, "WF Keys",  "itemRules", "wfKeyFrags",  nil --[[ ID unknown ]], "Interface\\Icons\\inv_misc_key_13")
        LootEnh_CreateDropdown(body, 140, -10, 100, "Doomshot", "itemRules", "doomshot",    nil --[[ ID unknown ]], "Interface\\Icons\\inv_ammo_bullet_02")
        LootEnh_CreateDropdown(body, 280, -10, 100, "Cannons",  "itemRules", "cannonballs", nil --[[ ID unknown ]], "Interface\\Icons\\inv_misc_ammo_gunpowder_a")
    end, "worldforged")

    -- SECTION : Scrolls (WF & Mystic)
    LootEnh_CreateSection(scrollChild, sections, ld.CAT_SCROLLS, "|cff00ccff", 120, function(body)
        -- Ligne 1 : WF scrolls
        LootEnh_CreateDropdown(body, 0,   -10, 85, "WF Blue", "scrollRules", "wfblue",   nil --[[ ID unknown ]], "Interface\\Icons\\inv_scroll_11")
        LootEnh_CreateDropdown(body, 100, -10, 85, "WF Epic", "scrollRules", "wfpurple", nil --[[ ID unknown ]], "Interface\\Icons\\inv_scroll_12")
        LootEnh_CreateDropdown(body, 200, -10, 85, "WF Leg",  "scrollRules", "wforange", nil --[[ ID unknown ]], "Interface\\Icons\\inv_scroll_13")
        -- Ligne 2 : ME scrolls
        LootEnh_CreateDropdown(body, 0,   -60, 85, "ME Green", "scrollRules", "megreen",  nil --[[ ID unknown ]], "Interface\\Icons\\inv_scroll_06")
        LootEnh_CreateDropdown(body, 100, -60, 85, "ME Blue",  "scrollRules", "meblue",   nil --[[ ID unknown ]], "Interface\\Icons\\inv_scroll_08")
        LootEnh_CreateDropdown(body, 200, -60, 85, "ME Epic",  "scrollRules", "mepurple", nil --[[ ID unknown ]], "Interface\\Icons\\inv_scroll_12")
        LootEnh_CreateDropdown(body, 300, -60, 85, "ME Leg",   "scrollRules", "meorange", nil --[[ ID unknown ]], "Interface\\Icons\\inv_scroll_13")
    end, "scrolls")

    -- SECTION : Zul'Gurub
    LootEnh_CreateSection(scrollChild, sections, ld.CAT_ZG, "|cff00ff00", 65, function(body)
        LootEnh_CreateDropdown(body, 0,   -10, 100, "All Coins",  "itemRules", "zgCoins",  nil, "Interface\\Icons\\inv_misc_coin_02")
        LootEnh_CreateDropdown(body, 140, -10, 100, "All Bijous", "itemRules", "zgBijous", nil, "Interface\\Icons\\inv_bijou_green")
        LootEnh_CreateDropdown(body, 280, -10, 100, "ZG Idols",  "itemRules", "zgIdols",  22637, "Interface\\Icons\\inv_misc_idol_02")
    end, "zg")

    -- SECTION : Molten Core
    LootEnh_CreateSection(scrollChild, sections, ld.CAT_MC, "|cffff8000", 65, function(body)
        LootEnh_CreateDropdown(body, 0,   -10, 100, "Fiery Core",     "itemRules", "mcFC",   17010, "Interface\\Icons\\inv_misc_gem_pearl_06")
        LootEnh_CreateDropdown(body, 140, -10, 100, "Lava Core",      "itemRules", "mcLC",   17011, "Interface\\Icons\\inv_misc_gem_pearl_05")
        LootEnh_CreateDropdown(body, 280, -10, 100, "Sulfuron Ingot", "itemRules", "mcSulf", 17203, "Interface\\Icons\\inv_ingot_mithril")
    end, "mc")

    -- SECTION : Blackwing Lair
    LootEnh_CreateSection(scrollChild, sections, ld.CAT_BWL, "|cffff4444", 65, function(body)
        LootEnh_CreateDropdown(body, 0,   -10, 110, "Hourglass Sand", "itemRules", "bwlSand", nil --[[ ID unknown ]], "Interface\\Icons\\inv_misc_dust_02")
        LootEnh_CreateDropdown(body, 150, -10, 110, "Elementium Ore", "itemRules", "bwlOre",  18562, "Interface\\Icons\\inv_ore_arcanite_02")
    end, "bwl")

    -- Layout initial
    LootEnh_LayoutSections(sections, scrollChild)

    InterfaceOptions_AddCategory(AutoPanel)
end

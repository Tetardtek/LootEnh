local AutoItems = {
    -- Worldforged
    ["Worldforged Key Fragment"] = { key = "wfKeyFrags", section = "worldforged" },
    ["Doomshot"]                 = { key = "doomshot",   section = "worldforged" },
    ["Miniature Cannon Balls"]   = { key = "cannonballs", section = "worldforged" },

    -- Zul'Gurub — Coins
    ["Bloodscalp Coin"]    = { key = "zgCoins",  section = "zg" },
    ["Gurubashi Coin"]     = { key = "zgCoins",  section = "zg" },
    ["Hakkari Coin"]       = { key = "zgCoins",  section = "zg" },
    ["Razzashi Coin"]      = { key = "zgCoins",  section = "zg" },
    ["Sandfury Coin"]      = { key = "zgCoins",  section = "zg" },
    ["Skullsplitter Coin"] = { key = "zgCoins",  section = "zg" },
    ["Vilebranch Coin"]    = { key = "zgCoins",  section = "zg" },
    ["Witherbark Coin"]    = { key = "zgCoins",  section = "zg" },
    ["Zulian Coin"]        = { key = "zgCoins",  section = "zg" },
    -- Zul'Gurub — Bijous
    ["Blue Hakkari Bijou"]   = { key = "zgBijous", section = "zg" },
    ["Bronze Hakkari Bijou"] = { key = "zgBijous", section = "zg" },
    ["Gold Hakkari Bijou"]   = { key = "zgBijous", section = "zg" },
    ["Green Hakkari Bijou"]  = { key = "zgBijous", section = "zg" },
    ["Orange Hakkari Bijou"] = { key = "zgBijous", section = "zg" },
    ["Purple Hakkari Bijou"] = { key = "zgBijous", section = "zg" },
    ["Red Hakkari Bijou"]    = { key = "zgBijous", section = "zg" },
    ["Silver Hakkari Bijou"] = { key = "zgBijous", section = "zg" },
    ["Yellow Hakkari Bijou"] = { key = "zgBijous", section = "zg" },
    -- Zul'Gurub — Idols
    ["Primal Hakkari Idol"] = { key = "zgIdols", section = "zg" },

    -- Molten Core
    ["Fiery Core"]     = { key = "mcFC",   section = "mc" },
    ["Lava Core"]      = { key = "mcLC",   section = "mc" },
    ["Sulfuron Ingot"] = { key = "mcSulf", section = "mc" },

    -- Blackwing Lair
    ["Hourglass Sand"] = { key = "bwlSand", section = "bwl" },
    ["Elementium Ore"] = { key = "bwlOre",  section = "bwl" },
}

local function IsSectionEnabled(sectionKey)
    local toggles = MonLootDB.sectionToggles
    if not toggles then return true end
    if toggles[sectionKey] == false then return false end
    return true
end

function GetAutoRollAction(name, quality, bop, canNeed, canGreed, canDE)
    if not MonLootDB.autoRoll then
        return nil
    end

    -- 1. Règles Personnalisées (Custom Rules) — priorité absolue
    if MonLootDB.customRules then
        local customAction = MonLootDB.customRules[name]
        if customAction then
            if customAction == 1 and canNeed then return 1
            elseif customAction == 2 and canGreed then return 2
            elseif customAction == 3 then return 0
            else return nil end
        end
    end

    -- 2. Protection BoP (ne s'applique qu'aux items sans custom rule)
    if bop == 1 and MonLootDB.bopProtection then
        return nil
    end

    -- 3. Objets Spécifiques (Farm)
    for itemName, info in pairs(AutoItems) do
        if name:find(itemName) then
            if not IsSectionEnabled(info.section) then return nil end
            local choice = MonLootDB.itemRules[info.key]
            if choice == 1 and canNeed then
                return 1
            elseif choice == 2 and canGreed then
                return 2
            elseif choice == 3 then
                return 0 -- Pass
            else
                return nil
            end -- Manual
        end
    end

    -- 4. Parchemins (Scrolls)
    if name:find("Worldforged Scroll") or name:find("Mystic Scroll") then
        if not IsSectionEnabled("scrolls") then return nil end
        local scrollType = name:find("Worldforged") and "wf" or "me"
        local qStr = (quality == 5 and "orange") or (quality == 4 and "purple") or (quality == 3 and "blue") or
                         (quality == 2 and "green")

        if qStr then
            local choice = MonLootDB.scrollRules[scrollType .. qStr]
            if choice == 1 and canNeed then
                return 1
            elseif choice == 2 and canGreed then
                return 2
            elseif choice == 3 then
                return 0
            else
                return nil
            end
        end
    end

    -- 5. Qualité (Règles Générales)
    if not IsSectionEnabled("general") then return nil end
    local qKey = (quality == 2 and "green") or (quality == 3 and "blue") or (quality == 4 and "purple") or
                     (quality == 5 and "orange") or (quality == 6 and "gold")
    if qKey then
        local choice = MonLootDB.qualityRules[qKey]
        if choice == 1 and canNeed then
            return 1
        elseif choice == 2 and canGreed then
            return 2
        elseif choice == 3 then
            return 0
        else
            return nil
        end
    end

    return nil
end

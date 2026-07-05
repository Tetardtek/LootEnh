local defaults = {
    anchorX = 0,
    anchorY = 100,
    histX = -50,
    histY = 0,
    showAnchor = false,
    hideHistory = true,
    histAlpha = 0.8,
    filterMode = 2,
    minimapPos = 45,
    lang = "enUS",
    hideNative = true,
    enableLootFrame = true,
    autoRoll = false,
    bopProtection = true,
    skipBopDialog = false,
    itemRules = {
        wfKeyFrags = 4,
        doomshot = 4,
        cannonballs = 4,
        zgCoins = 4,
        zgBijous = 4,
        zgIdols = 4,
        mcFC = 4,
        mcLC = 4,
        mcSulf = 4,
        bwlSand = 4,
        bwlOre = 4,
    },
    scrollRules = {
        wforange = 4,
        wfpurple = 4,
        wfblue = 4,
        meorange = 4,
        mepurple = 4,
        meblue = 4,
        megreen = 4,
    },
    qualityRules = {
        green = 4,
        blue = 4,
        purple = 4,
        orange = 4,
        gold = 4,
    },
    sectionToggles = {
        general = true,
        worldforged = true,
        scrolls = true,
        zg = true,
        mc = true,
        bwl = true,
    },
    customRules = {},
    lootFrame = {
        strata = "MEDIUM",
        scale = 1.0,
        alpha = 0.95,
        growDir = "up",
        spacing = 5,
        maxBars = 4,
        qualityBar = true,
        qualityIconBorder = true,
        animStyle = "slide",
    },
    solo = {
        enabled = true,
        -- Shared visuals
        scale = 1.0,
        alpha = 0.8,
        spacing = 5,
        strata = "MEDIUM",
        maxBars = 4,
        growDir = "up",
        animStyle = "fade",
        -- Module: Items
        loot = {
            enabled = true,
            duration = 5,
            minRarity = 2,
            cumulate = true,
            showBagCount = true,
            questHighlight = true,
            qualityIconBorder = true,
            chatMode = "all", -- "all" | "hideGray" | "hideAll"
        },
        -- Module: Gold
        gold = {
            enabled = true,
            duration = 4,
            cumulate = true,
            showSessionTotal = false,
            chatMode = "all", -- "all" | "hideAll"
        },
        -- Module: XP
        xp = {
            enabled = true,
            duration = 4,
            cumulate = true,
            chatMode = "all",
        },
        -- Module: Reputation
        rep = {
            enabled = true,
            duration = 5,
            cumulate = true,
            chatMode = "all",
        },
    },
    soloAnchorX = 0,
    soloAnchorY = -100,
}

LootEnh_AllControls = {}

-- Converts the legacy 3-mode soloFilterMode into per-module chatMode.
-- Runs at init and after loading/importing an old profile.
function LootEnh_MigrateSoloChat()
    local mode = MonLootDB and MonLootDB.soloFilterMode
    if mode == nil then return end
    local s = MonLootDB.solo or {}
    if s.loot then
        s.loot.chatMode = (mode == 3) and "hideAll" or (mode == 2) and "hideGray" or "all"
    end
    if s.gold then s.gold.chatMode = (mode >= 2) and "hideAll" or "all" end
    if s.xp then s.xp.chatMode = (mode == 3) and "hideAll" or "all" end
    if s.rep then s.rep.chatMode = (mode == 3) and "hideAll" or "all" end
    MonLootDB.soloFilterMode = nil
end

function LootEnh_InitializeDB()
    MonLootDB = MonLootDB or {}
    for k, v in pairs(defaults) do
        if MonLootDB[k] == nil then
            -- Deep copy: never hand the defaults table itself to the DB,
            -- later mutations (migrations, user settings) would poison it
            MonLootDB[k] = LootEnh_DeepCopy(v)
        elseif type(v) == "table" then
            for sk, sv in pairs(v) do
                if MonLootDB[k][sk] == nil then
                    MonLootDB[k][sk] = sv
                end
            end
        end
    end
    -- WoW SavedVariables drops empty tables on reload, ensure they exist
    MonLootDB.customRules = MonLootDB.customRules or {}
    MonLootDB.lootFrame = MonLootDB.lootFrame or {}
    MonLootDB.sectionToggles = MonLootDB.sectionToggles or {}
    MonLootDB.solo = MonLootDB.solo or {}

    -- Migration: old flat solo format → new modular format
    if MonLootDB.solo.showLoot ~= nil then
        local old = MonLootDB.solo
        old.loot = {
            enabled = old.showLoot ~= false,
            duration = old.duration or 5,
            minRarity = old.minRarity or 2,
            cumulate = true,
            showBagCount = true,
            questHighlight = old.questHighlight ~= false,
        }
        old.gold = {
            enabled = old.showGold ~= false,
            duration = old.duration or 5,
            cumulate = true,
            showSessionTotal = false,
        }
        old.xp = {
            enabled = old.showXP ~= false,
            duration = old.duration or 5,
            cumulate = true,
        }
        old.rep = {
            enabled = old.showRep ~= false,
            duration = old.duration or 5,
            cumulate = true,
        }
        -- Clean old keys
        old.showLoot = nil
        old.showGold = nil
        old.showXP = nil
        old.showRep = nil
        old.duration = nil
        old.minRarity = nil
        old.questHighlight = nil
    end

    -- Ensure solo sub-tables exist (WoW drops empty tables on reload)
    for _, mod in ipairs({"loot", "gold", "xp", "rep"}) do
        if not MonLootDB.solo[mod] then
            MonLootDB.solo[mod] = LootEnh_DeepCopy(defaults.solo[mod])
        else
            -- 3-level merge: fill missing keys within each module
            for mk, mv in pairs(defaults.solo[mod]) do
                if MonLootDB.solo[mod][mk] == nil then
                    MonLootDB.solo[mod][mk] = mv
                end
            end
        end
    end
    -- Migration: legacy global soloFilterMode → per-module chatMode
    LootEnh_MigrateSoloChat()

    -- Profiles storage
    MonLootDB.profiles = MonLootDB.profiles or {}
    MonLootDB.profiles.autoRoll = MonLootDB.profiles.autoRoll or {}
    MonLootDB.profiles.ui = MonLootDB.profiles.ui or {}

    -- Character → profile associations
    MonLootDB.charProfiles = MonLootDB.charProfiles or {}

    -- Create "Default" profiles once (snapshot of addon defaults)
    if not MonLootDB.profiles.autoRoll["Default"] then
        MonLootDB.profiles.autoRoll["Default"] = {
            itemRules = LootEnh_DeepCopy(defaults.itemRules),
            scrollRules = LootEnh_DeepCopy(defaults.scrollRules),
            qualityRules = LootEnh_DeepCopy(defaults.qualityRules),
            sectionToggles = LootEnh_DeepCopy(defaults.sectionToggles),
            autoRoll = defaults.autoRoll,
            bopProtection = defaults.bopProtection,
            skipBopDialog = defaults.skipBopDialog,
        }
    end
    if not MonLootDB.profiles.ui["Default"] then
        MonLootDB.profiles.ui["Default"] = {
            lootFrame = LootEnh_DeepCopy(defaults.lootFrame),
            filterMode = defaults.filterMode,
            hideNative = defaults.hideNative,
            enableLootFrame = defaults.enableLootFrame,
            histAlpha = defaults.histAlpha,
            solo = LootEnh_DeepCopy(defaults.solo),
            anchorX = defaults.anchorX,
            anchorY = defaults.anchorY,
            soloAnchorX = defaults.soloAnchorX,
            soloAnchorY = defaults.soloAnchorY,
            histX = defaults.histX,
            histY = defaults.histY,
        }
    end
end

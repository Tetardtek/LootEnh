-- Taint-safe dropdown init: prevents addon taint from leaking to Blizzard secure frames
function LootEnh_SafeDropDownInit(frame, initFunc, displayMode, level)
    local old = UIDROPDOWNMENU_INIT_MENU
    securecall(UIDropDownMenu_Initialize, frame, initFunc, displayMode, level)
    UIDROPDOWNMENU_INIT_MENU = old
end

-- Item quality colors (rarity 0-6), shared by group and solo bars
LootEnh_QUALITY_COLORS = {
    [0] = {0.62, 0.62, 0.62}, -- Poor
    [1] = {1.00, 1.00, 1.00}, -- Common
    [2] = {0.12, 1.00, 0.00}, -- Uncommon
    [3] = {0.00, 0.44, 0.87}, -- Rare
    [4] = {0.64, 0.21, 0.93}, -- Epic
    [5] = {1.00, 0.50, 0.00}, -- Legendary
    [6] = {0.90, 0.80, 0.50}, -- Artifact
}

local HEX_TO_QUALITY = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2,
    ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6,
}

-- Cache-safe: GetItemInfo first, fallback to the link's embedded color code
function LootEnh_GetQualityFromLink(link)
    if not link then return nil end
    local _, _, quality = GetItemInfo(link)
    if quality then return quality end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    return hex and HEX_TO_QUALITY[hex:lower()] or nil
end

-- Thin colored frame around an icon texture (BORDER layer, under the ARTWORK icon)
function LootEnh_CreateIconBorder(f, icon, inset)
    inset = inset or 2
    local b = f:CreateTexture(nil, "BORDER")
    b:SetTexture("Interface\\Buttons\\WHITE8X8")
    b:SetPoint("TOPLEFT", icon, "TOPLEFT", -inset, inset)
    b:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", inset, -inset)
    b:Hide()
    return b
end

function LootEnh_DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = LootEnh_DeepCopy(v)
    end
    return copy
end

local AUTO_ROLL_KEYS = {
    "itemRules", "scrollRules", "qualityRules",
    "sectionToggles", "autoRoll", "bopProtection", "skipBopDialog",
}

local UI_KEYS = {
    "lootFrame", "filterMode", "hideNative", "enableLootFrame", "histAlpha",
    "solo", "soloFilterMode",
    "anchorX", "anchorY", "soloAnchorX", "soloAnchorY", "histX", "histY",
}

LootEnh_PROFILE_KEYS = { autoRoll = AUTO_ROLL_KEYS, ui = UI_KEYS }

function LootEnh_SerializeTable(t)
    local function ser(v)
        local vt = type(v)
        if vt == "string" then
            return string.format("%q", v)
        elseif vt == "number" then
            return tostring(v)
        elseif vt == "boolean" then
            return v and "true" or "false"
        elseif vt == "table" then
            local parts = {}
            -- array part
            local n = #v
            for i = 1, n do
                parts[#parts + 1] = ser(v[i])
            end
            -- hash part
            for k, val in pairs(v) do
                if type(k) == "number" and k >= 1 and k <= n and math.floor(k) == k then
                    -- skip, already in array part
                else
                    local key
                    if type(k) == "string" then
                        key = "[" .. string.format("%q", k) .. "]"
                    else
                        key = "[" .. tostring(k) .. "]"
                    end
                    parts[#parts + 1] = key .. "=" .. ser(val)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return "nil"
    end
    return ser(t)
end

function LootEnh_DeserializeTable(s)
    if type(s) ~= "string" or s == "" then return nil end
    local fn, err = loadstring("return " .. s)
    if not fn then return nil end
    setfenv(fn, {})
    local ok, result = pcall(fn)
    if not ok or type(result) ~= "table" then return nil end
    return result
end

-- Base64 encode/decode (pure Lua 5.1)
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function LootEnh_Base64Encode(data)
    local out = {}
    local len = #data
    for i = 1, len, 3 do
        local a = string.byte(data, i)
        local b = i + 1 <= len and string.byte(data, i + 1) or 0
        local c = i + 2 <= len and string.byte(data, i + 2) or 0
        local n = a * 65536 + b * 256 + c
        out[#out + 1] = string.sub(b64chars, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = string.sub(b64chars, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = i + 1 <= len and string.sub(b64chars, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = i + 2 <= len and string.sub(b64chars, n % 64 + 1, n % 64 + 1) or "="
    end
    return table.concat(out)
end

function LootEnh_Base64Decode(data)
    if type(data) ~= "string" then return nil end
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local out = {}
    for i = 1, #data, 4 do
        local a, b, c, d =
            (string.find(b64chars, string.sub(data, i, i), 1, true) or 1) - 1,
            (string.find(b64chars, string.sub(data, i + 1, i + 1), 1, true) or 1) - 1,
            (string.find(b64chars, string.sub(data, i + 2, i + 2), 1, true) or 1) - 1,
            (string.find(b64chars, string.sub(data, i + 3, i + 3), 1, true) or 1) - 1
        local n = a * 262144 + b * 4096 + c * 64 + d
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if string.sub(data, i + 2, i + 2) ~= "=" then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if string.sub(data, i + 3, i + 3) ~= "=" then
            out[#out + 1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end

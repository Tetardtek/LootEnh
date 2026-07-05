-- ============================================================
-- LootEnh Animations — entry/exit animations for loot bars
-- OnUpdate-driven (no AnimationGroup): plays nice with frame
-- pooling and restacking, works on any 3.3-based client.
-- ============================================================

local ANIM_IN_DUR = 0.25
local ANIM_OUT_DUR = 0.18
local SLIDE_DIST = 18
local POP_SCALE = 1.10
local EPIC_POP_SCALE = 1.14

-- Ease-out cubic: fast start, soft landing
local function EaseOut(p)
    local q = 1 - p
    return 1 - q * q * q
end

-- Starts the entry animation. Call right before f:Show().
-- style: "none" | "fade" | "slide" | "pop"
-- growUp: bars stack upward (slide comes from below) or downward
-- quality: item quality — epic+ (4+) gets a scale punch on any style
-- baseScale: the frame's configured scale (punch returns to it)
function LootEnh_BeginEntry(f, style, growUp, quality, baseScale)
    style = style or "none"
    f.leExiting = nil
    f.leExitCb = nil
    if style == "none" then
        f.leStyle = nil
        f.leOffY = 0
        f:SetAlpha(1)
        return
    end
    f.leStyle = style
    f.leT0 = GetTime()
    f.leBaseScale = baseScale or 1.0
    f.lePunch = (style == "pop" and POP_SCALE)
        or (quality and quality >= 4 and EPIC_POP_SCALE)
        or nil
    if style == "slide" then
        f.leSlideDist = growUp and -SLIDE_DIST or SLIDE_DIST
        f.leOffY = f.leSlideDist
    else
        f.leSlideDist = nil
        f.leOffY = 0
    end
    f:SetAlpha(0)
end

-- Starts the exit animation; onDone(f) fires when it completes.
-- Returns false if animations are off (caller should dismiss directly).
function LootEnh_BeginExit(f, style, onDone)
    if not style or style == "none" then return false end
    if f.leExiting then return true end
    f.leExiting = true
    f.leExitT0 = GetTime()
    f.leExitCb = onDone
    f.leExitFrom = f:GetAlpha()
    return true
end

-- Steps the animation state; call from the frame's OnUpdate.
-- restack: function repositioning active bars (applies leOffY)
-- Returns true while an exit animation owns the frame (caller must
-- skip its timer/dismiss logic for this tick).
function LootEnh_AnimStep(f, restack)
    local now = GetTime()

    -- Exit animation
    if f.leExiting then
        local p = (now - f.leExitT0) / ANIM_OUT_DUR
        if p >= 1 then
            local cb = f.leExitCb
            f.leExiting = nil
            f.leExitCb = nil
            f:SetAlpha(1)
            if cb then cb(f) end
        else
            f:SetAlpha((f.leExitFrom or 1) * (1 - p))
        end
        return true
    end

    -- Entry animation
    if f.leStyle and f.leT0 then
        local p = (now - f.leT0) / ANIM_IN_DUR
        if p >= 1 then
            f:SetAlpha(1)
            if f.leOffY and f.leOffY ~= 0 then
                f.leOffY = 0
                if restack then restack() end
            end
            if f.lePunch then
                f:SetScale(f.leBaseScale)
                f.lePunch = nil
            end
            f.leStyle = nil
            f.leT0 = nil
        else
            local e = EaseOut(p)
            f:SetAlpha(e)
            if f.leStyle == "slide" and f.leSlideDist then
                f.leOffY = f.leSlideDist * (1 - e)
                if restack then restack() end
            end
            if f.lePunch then
                -- overshoot then settle: peak at p=0.6
                local s
                if p < 0.6 then
                    s = 1 + (f.lePunch - 1) * (p / 0.6)
                else
                    s = f.lePunch - (f.lePunch - 1) * ((p - 0.6) / 0.4)
                end
                f:SetScale(f.leBaseScale * s)
            end
        end
    end
    return false
end

-- Clears any animation state (frame going back to the pool)
function LootEnh_AnimReset(f)
    f.leStyle = nil
    f.leT0 = nil
    f.leOffY = 0
    f.leSlideDist = nil
    f.lePunch = nil
    f.leExiting = nil
    f.leExitCb = nil
    f:SetAlpha(1)
end

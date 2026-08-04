-- LootEnh / Compat.lua
--
-- Couche de compatibilite entre le client 3.3.5 (Ascension / CoA) et le client
-- moderne (Classic Era 1.15+). Chargee EN PREMIER : tout le reste du code
-- l'utilise sans jamais savoir sur quel client il tourne.
--
-- Pourquoi une couche et pas deux branches : LootEnh continue d'evoluer sur CoA.
-- Deux branches divergentes obligeraient a tout ecrire deux fois, et le drift
-- serait structurel.
--
-- Pourquoi ca ne rejoue pas l'erreur du 02/08 (le protocole de version recopie
-- dans trois depots, refuse a juste titre) : ce protocole-la EVOLUE, donc chaque
-- changement doit etre repercute et le drift est certain. Cette couche est FIGEE
-- — ecrite une fois, jamais retouchee ensuite. Ce qui derive, c'est ce qui bouge.
--
-- Principe de degradation : quand une API n'existe nulle part, on ne plante pas,
-- on renonce a la fonction. Les barres de butin doivent marcher meme si le
-- panneau d'options ne s'enregistre pas.
--
-- Releve en jeu sur Classic Era 1.15.9 (04/08) :
--   C_Container ....................... table
--   GetContainerNumSlots .............. nil     <- les globales conteneurs sont mortes
--   JoinChannelByName / SendChatMessage function
--   Settings .......................... table
--   InterfaceOptions_AddCategory ...... nil

LootEnh_Compat = {}
local C = LootEnh_Compat

-- Client moderne = celui qui expose le systeme de reglages introduit apres 3.3.5.
C.modern = (Settings ~= nil and Settings.RegisterCanvasLayoutCategory ~= nil)

---------------------------------------------------------------------------
-- Backdrop
---------------------------------------------------------------------------
-- Depuis Shadowlands, SetBackdrop n'existe plus sur une frame ordinaire : il
-- faut le gabarit "BackdropTemplate", ou appliquer le mixin apres coup.
--
-- On applique le mixin plutot que de toucher chaque CreateFrame : un seul point
-- d'entree, et les appels a SetBackdropColor qui suivent fonctionnent aussi.
--
-- Retourne la frame, pour s'inserer sans rien deranger :
--     LootEnh_Backdrop(f):SetBackdrop({ ... })

function LootEnh_Backdrop(frame)
    if frame and not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        -- Le mixin attend cet evenement pour se redessiner correctement.
        if frame.HasScript and frame:HasScript("OnSizeChanged") then
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
    end
    return frame
end

---------------------------------------------------------------------------
-- Cases a cocher
---------------------------------------------------------------------------
-- `InterfaceOptionsCheckButtonTemplate` a disparu des clients recents. On ne
-- devine pas lequel existe : on tente, ce qui est la seule methode fiable —
-- aucune API ne permet d'interroger la presence d'un gabarit.

local checkTemplate

function LootEnh_CheckTemplate()
    if checkTemplate ~= nil then return checkTemplate end
    local candidates = {
        "InterfaceOptionsCheckButtonTemplate",  -- 3.3.5 et clients anciens
        "UICheckButtonTemplate",                -- repli moderne
        "OptionsBaseCheckButtonTemplate",
    }
    for i = 1, table.getn(candidates) do
        local ok, f = pcall(CreateFrame, "CheckButton", nil, UIParent, candidates[i])
        if ok and f then
            f:Hide()
            checkTemplate = candidates[i]
            return checkTemplate
        end
    end
    checkTemplate = false          -- aucun : l'appelant devra se debrouiller
    return checkTemplate
end

---------------------------------------------------------------------------
-- Panneaux d'options
---------------------------------------------------------------------------
-- 3.3.5 : InterfaceOptions_AddCategory(panel), avec panel.name et panel.parent.
-- Moderne : Settings.RegisterCanvasLayoutCategory / ...Subcategory, puis
--           Settings.RegisterAddOnCategory.
--
-- On memorise les identifiants pour pouvoir rouvrir : le systeme moderne ouvre
-- par identifiant de categorie, pas par frame.

local categories = {}          -- panel.name -> categorie moderne
local rootCategory

function LootEnh_AddOptionsCategory(panel)
    if not panel or not panel.name then return end

    if C.modern then
        local cat
        if panel.parent and categories[panel.parent] then
            cat = Settings.RegisterCanvasLayoutSubcategory(
                categories[panel.parent], panel, panel.name)
        else
            cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
            if Settings.RegisterAddOnCategory then
                Settings.RegisterAddOnCategory(cat)
            end
            rootCategory = rootCategory or cat
        end
        categories[panel.name] = cat
        return cat
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        categories[panel.name] = panel
        rootCategory = rootCategory or panel
        return panel
    end

    -- Ni l'un ni l'autre : on renonce au panneau, pas a l'addon.
end

function LootEnh_OpenOptions(panel)
    local key = panel and panel.name
    local cat = (key and categories[key]) or rootCategory
    if not cat then return end

    if C.modern then
        if Settings.OpenToCategory then
            Settings.OpenToCategory(cat.GetID and cat:GetID() or cat)
        end
        return
    end

    if InterfaceOptionsFrame_OpenToCategory then
        -- Le double appel est un contournement communautaire vieux de quinze ans :
        -- le premier ouvre la fenetre sur la mauvaise page, le second corrige.
        -- Il ne concerne QUE le client ancien.
        InterfaceOptionsFrame_OpenToCategory(cat)
        InterfaceOptionsFrame_OpenToCategory(cat)
    end
end

---------------------------------------------------------------------------
-- Metadonnees d'addon
---------------------------------------------------------------------------
-- Passees sous C_AddOns sur les clients recents. La version vit dans le .toc et
-- nulle part ailleurs : cette lecture ne doit jamais echouer silencieusement.

function LootEnh_GetAddOnMetadata(addon, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addon, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addon, field)
    end
    return nil
end

function LootEnh_IsAddOnLoaded(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addon)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(addon)
    end
    return false
end

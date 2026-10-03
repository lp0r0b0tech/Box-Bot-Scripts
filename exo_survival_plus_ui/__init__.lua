-- Exo Survival Plus — native armory shop injector (s1x LUI script)
--
-- Install: <AW folder>/s1x/ui_scripts/exo_survival_plus/__init__.lua
-- Pair with: <AW folder>/s1x/scripts/s1x_exo_survival_plus.gsc
--
-- Adds all missing base weapons and all base DLC weapons as real buy
-- buttons inside the NATIVE Exo Survival weapon armory category menus
-- (Pistols / SMGs / Assault / Shotguns / Snipers / Heavy / Launchers).
--
-- How it works:
--  * The native armory menu (mp_hud/hordearmory.lua) builds each weapon
--    category with upgradeFeeder( firstIndex, lastIndex ), reading row
--    data per index from the string table mp/hordeMenus.csv through
--    Engine.TableLookup.
--  * This script wraps Engine.TableLookup to serve extra virtual rows
--    (indexes 600+) that don't exist in the CSV, and wraps the global
--    upgradeFeeder so each weapon category also iterates its extra
--    index range.
--  * The buttons use the native purchase pipeline: ButtonMenuActionUpgrade
--    sends Engine.NotifyServer( "esp_weapon_upgrade", index ), which the
--    GSC script receives via waittill( "luinotifyserver" ), charges
--    armory points and gives the weapon. The native GSC armory handler
--    ignores the unknown "esp_weapon_upgrade" type, so nothing is
--    double-handled.
--
-- The index -> weapon/cost table MUST stay in sync with
-- esp_build_shop_table() in s1x_exo_survival_plus.gsc.

local HORDE_MENU_FILE = "mp/hordeMenus.csv"

-- index = { name, desc, icon, cost, unlock }
local ESP_WEAPONS = {
    -- pistols (native 220-223)
    [600] = { name = "M1 Irons", desc = "DLC pistol. High damage revolver.", icon = "weapon_dlcgun3", cost = 2, unlock = 0 },
    [601] = { name = "1911", desc = "DLC pistol. Classic semi-auto sidearm.", icon = "weapon_dlcgun13", cost = 2, unlock = 0 },
    [602] = { name = "Combat Knife", desc = "Melee only. One-hit kills up close.", icon = "weapon_combatknife", cost = 1, unlock = 0 },

    -- smgs (native 230-235)
    [610] = { name = "MP40", desc = "DLC SMG. Classic full-auto.", icon = "weapon_dlcgun18", cost = 3, unlock = 0 },
    [611] = { name = "Sten", desc = "DLC SMG. Fast handling, low recoil.", icon = "weapon_dlcgun28", cost = 3, unlock = 0 },

    -- assault rifles (native 240-246)
    [620] = { name = "STG-44", desc = "DLC assault rifle. Classic full-auto.", icon = "weapon_dlcgun6", cost = 3, unlock = 0 },
    [621] = { name = "AK-47", desc = "DLC assault rifle. Hard hitting full-auto.", icon = "weapon_dlcgun7", cost = 3, unlock = 0 },
    [622] = { name = "M16", desc = "DLC assault rifle. Burst fire.", icon = "weapon_dlcgun8", cost = 3, unlock = 0 },
    [623] = { name = "M1 Garand", desc = "DLC rifle. Semi-auto, high damage.", icon = "weapon_dlcgun23", cost = 3, unlock = 0 },
    [624] = { name = "AE4", desc = "DLC energy assault rifle.", icon = "weapon_dlcgun1", cost = 3, unlock = 0 },

    -- shotguns (native 250-252)
    [630] = { name = "Blunderbuss", desc = "DLC shotgun. Devastating at close range.", icon = "weapon_dlcgun4", cost = 3, unlock = 0 },
    [631] = { name = "CEL-3 Cauterizer", desc = "DLC energy shotgun.", icon = "weapon_dlcgun8", cost = 4, unlock = 0 },
    [632] = { name = "Lever Action", desc = "DLC shotgun. Lever action repeater.", icon = "weapon_dlcgun33", cost = 3, unlock = 0 },

    -- snipers (native 260-263)
    [640] = { name = "SVO", desc = "DLC sniper rifle. Fast semi-auto.", icon = "weapon_dlcgun7", cost = 3, unlock = 0 },

    -- heavy weapons (native 270-274)
    [650] = { name = "Ohm", desc = "DLC hybrid heavy weapon.", icon = "weapon_dlcgun2", cost = 4, unlock = 0 },
    [651] = { name = "Repulsor", desc = "DLC heavy weapon. Pushes enemies back.", icon = "weapon_dlcgun38", cost = 4, unlock = 0 },
    [652] = { name = "Riot Shield", desc = "Portable cover. Blocks damage.", icon = "weapon_riotshieldt6", cost = 2, unlock = 0 },

    -- launchers (native 280-283)
    [660] = { name = "Crossbow", desc = "Explosive bolt launcher.", icon = "weapon_exocrossbow", cost = 3, unlock = 0 },
}

-- native category feeder range -> extra index range to append
local ESP_EXTRA_RANGES = {
    ["220_223"] = { 600, 602 }, -- pistols
    ["230_235"] = { 610, 611 }, -- smgs
    ["240_246"] = { 620, 624 }, -- assault rifles
    ["250_252"] = { 630, 632 }, -- shotguns
    ["260_263"] = { 640, 640 }, -- snipers
    ["270_274"] = { 650, 652 }, -- heavy weapons
    ["280_283"] = { 660, 660 }, -- launchers
}

-- column layout of mp/hordeMenus.csv:
-- 0 index, 1 type, 2 ref, 3 icon, 4 text, 5 desc, 6 cost, 7 unlock, 8 modules
local function esp_row_column( index, col )
    local entry = ESP_WEAPONS[index]
    if not entry then
        return nil
    end
    if col == 0 then
        return tostring( index )
    elseif col == 1 then
        return "esp_weapon_upgrade"
    elseif col == 2 then
        -- must not contain "dlcgun": the native feeder hides dlcgun refs
        -- unless the DLC entitlement is unlocked. The GSC maps the index
        -- back to the real weapon, so the ref is just an identifier here.
        return "esp" .. index
    elseif col == 3 then
        return entry.icon
    elseif col == 4 then
        return "ESP:" .. entry.name
    elseif col == 5 then
        return "ESP:" .. entry.desc
    elseif col == 6 then
        return tostring( entry.cost )
    elseif col == 7 then
        return tostring( entry.unlock )
    elseif col == 8 then
        return ""
    end
    return ""
end

-- serve the virtual rows through Engine.TableLookup
local esp_orig_tablelookup = Engine.TableLookup
Engine.TableLookup = function ( file, col, value, retCol )
    if file == HORDE_MENU_FILE and col == 0 then
        local index = tonumber( value )
        if index and ESP_WEAPONS[index] then
            local result = esp_row_column( index, tonumber( retCol ) or -1 )
            if result ~= nil then
                return result
            end
        end
    end
    return esp_orig_tablelookup( file, col, value, retCol )
end

-- plain-text names: the native menu displays Engine.Localize( "@" .. text )
local esp_orig_localize = Engine.Localize
Engine.Localize = function ( key, ... )
    if type( key ) == "string" then
        if key:sub( 1, 5 ) == "@ESP:" then
            return key:sub( 6 )
        elseif key:sub( 1, 4 ) == "ESP:" then
            return key:sub( 5 )
        end
    end
    return esp_orig_localize( key, ... )
end

-- extend the native weapon category feeders.
-- hordearmory.lua defines the global function upgradeFeeder when it loads,
-- which can happen after this script runs, so the patch is (re)applied
-- lazily from an Engine.GetOmnvar wrapper (called every frame by the HUD).
local esp_patched_feeder = nil

local function esp_try_patch_feeder()
    local current = rawget( _G, "upgradeFeeder" )
    if type( current ) ~= "function" or current == esp_patched_feeder then
        return
    end
    local original = current
    esp_patched_feeder = function ( first, last )
        local list = original( first, last )
        local extra = ESP_EXTRA_RANGES[tostring( first ) .. "_" .. tostring( last )]
        if extra then
            local more = original( extra[1], extra[2] )
            for i = 1, #more do
                list[#list + 1] = more[i]
            end
        end
        return list
    end
    rawset( _G, "upgradeFeeder", esp_patched_feeder )
end

esp_try_patch_feeder()

local esp_orig_getomnvar = Engine.GetOmnvar
Engine.GetOmnvar = function ( name, ... )
    if name == "ui_horde_armory_type" then
        esp_try_patch_feeder()
    end
    return esp_orig_getomnvar( name, ... )
end

/*
    Exo Zombies and Multiplayer weapon shop for S1x / S1-Mod

    Place this file at:
        s1/scripts/zm/exo_zombies_dlc_weapon_shop.gsc

    Purpose:
        - Offer only the explicitly listed Exo Zombies and Multiplayer
          weapons for purchase, without other pack weapons or Royalty variants
          and without requiring any map-specific trigger or Radiant placement.
        - Uses the map's default fastfiles. No custom weapon pack
          (mods/exo_weapons_*) needs to be selected or mounted; each
          weapon is offered only when the default fastfiles loaded it.
        - Always offer the selected roster: Thor, Microwave,
          Line Gun, Trident, DLC Weapon I, Ohm, DLC Weapon III,
          Blunderbuss, 1911, AK-47, EPM3, Riot Shield, Lever Action,
          M1 Garand, M16, MAAWS, M990, MP40, Repulsor, STG-44, SVO,
          Stinger M7, Sten, MORS, XMG Dual, MP443, and MDL.
          It does not sell magic-box weapons.
        - No console command is required. A purchase is given only after the
          base weapon def is registered. One missing upgrade does not hide a
          loaded weapon. An unregistered def is never given.
        - Ark, BRG, and H2O use native on-screen messages instead of custom HUD
          text.
        - Every purchase costs 1000 credits through the native Zombies
          currency system and uses the native weapon/inventory handler.
        - Base loadouts use native sniper scopes. XMG is sold only as
          a dual-wield weapon and stays dual-wield when upgraded.
          Compatible attachment upgrades follow the native Mk4/Mk7/Mk10
          thresholds and remain equipped through Mk20 and Mk25.
        - The animated Toxic Tiger (Mk2) and Infected (Mk15) camos reach
          the imported roster without changing the native Mk camo
          progression: the pack defines the materials the stock camo
          tables name, and the thirteen weapons whose table cells are
          blank get them as the camo01 and camo04 rows (see
          dlcws_mk_camo). The Riot Shield has no camo table row.
        - The Ohm's alt-fire toggle (action slot 3) is set again after the
          Ohm is bought or upgraded.

    Controls (per player, once connected and spawned):
        Hold  [Aim] + tap [Melee]  to open the shop.
        With a variable-zoom scope, hold [Melee] for 0.6 seconds instead;
        a quick tap keeps the scope's native zoom control.
        Tap   [Attack]  to move to the next weapon in the list.
        Tap   [Melee]   to move to the previous weapon in the list.
        Tap   [Use]     to purchase the highlighted weapon for 1000 points.
        Tap   [Frag]    to close the shop without buying.

    Toggles:
        set scr_zm_dlc_shop_enabled 1
        set scr_zm_dlc_shop_debug   0
        set scr_zm_dlc_shop_awd_compat 1
            (adds the roster weapons to all_weapon_damage.gsc when that
            script is installed; 0 keeps native damage for them)
*/

#define DLCWS_DEFAULT_ENABLED        1
#define DLCWS_DEFAULT_DEBUG          0
#define DLCWS_DEFAULT_AWD_COMPAT     1
#define DLCWS_AWD_WAIT_STEPS         600

#define DLCWS_WEAPON_COST            1000
#define DLCWS_POLL_INTERVAL          0.05
#define DLCWS_IDLE_TIMEOUT_SECONDS   20
#define DLCWS_PACK_COUNT             7
#define DLCWS_ALL_PACK_NUMBER        8
#define DLCWS_MESSAGE_REFRESH_SECONDS 2
#define DLCWS_SCOPE_OPEN_HOLD_MS      600

main()
{
    dlcws_init();
}

init()
{
    dlcws_init();
    if ( getdvar( "g_gametype" ) != "zombies" ||
         isdefined( level.dlcws_loadoutInitHooked ) )
    {
        return;
    }

    // Custom init runs before native gametype initialization in S1-Mod.
    level.dlcws_previousGametypeInit = level.onstartgametypelevelfunc;
    level.onstartgametypelevelfunc = ::dlcws_loadout_init;
    level.dlcws_loadoutInitHooked = true;
}

dlcws_loadout_init()
{
    if ( isdefined( level.dlcws_previousGametypeInit ) )
    {
        [[ level.dlcws_previousGametypeInit ]]();
    }

    dlcws_refresh_pack_state();
    // The pack's marker weapon says its camo materials are loaded.
    level.dlcws_nativeCamosReady = level.dlcws_packReady &&
        dlcws_base_registered( "iw5_dlcwscamo41_mp" );
    dlcws_write_runtime_status( "gametype_init" );
    dlcws_log_camo_status();

    if ( !level.dlcws_packReady )
    {
        println( "DLCWeaponShop: no roster weapon is loaded by this map's default fastfiles. The roster stays visible, but nothing can be purchased here." );
        return;
    }

    if ( !isdefined( level.attachmentmap_basetounique ) ||
         !isdefined( level.camolevel ) )
    {
        println( "DLCWeaponShop: upgrade tables are not ready. The roster stays visible, but purchases stay closed." );
        return;
    }

    if ( !dlcws_register_weapon_list() )
    {
        println( "DLCWeaponShop: no selected weapon could be registered. Purchases stay closed." );
        return;
    }

    dlcws_init_weapon_upgrades();
    level.dlcws_loadoutsReady = true;
    if ( !level.dlcws_nativeCamosReady )
    {
        println( "DLCWeaponShop: the pack's Mk2/Mk15 camo materials are not loaded. Imported weapons keep the plain camo of the previous level." );
    }
    println( "DLCWeaponShop: selected roster ready. " + level.dlcws_registeredCount +
        " of " + level.dlcws_weapons.size + " weapons can be purchased." );
}

dlcws_init()
{
    if ( getdvar( "g_gametype" ) != "zombies" )
    {
        return;
    }

    if ( isdefined( level.dlcwsInitStarted ) && level.dlcwsInitStarted )
    {
        return;
    }

    level.dlcwsInitStarted = true;
    level.dlcws_loadoutsReady = false;
    level.dlcws_nativeCamosReady = false;
    mapName = getdvar( "mapname" );
    level.dlcws_messageMode = mapName == "mp_zombie_ark" ||
        mapName == "mp_zombie_brg" || mapName == "mp_zombie_h2o";

    dlcws_init_dvars();
    dlcws_try_mount_pack();
    dlcws_build_weapon_list();
    dlcws_refresh_pack_state();
    dlcws_write_runtime_status( "map_init" );

    if ( level.dlcws_packReady )
    {
        if ( level.dlcws_messageMode )
        {
            println( "DLCWeaponShop: " + mapName + " uses native on-screen messages." );
        }
    }
    else
    {
        println( "DLCWeaponShop: no roster weapon is loaded by this map's default fastfiles. The roster stays visible, but nothing can be purchased here." );
    }

    level thread dlcws_watch_players();
    level thread dlcws_game_end_cleanup();
    level thread dlcws_awd_compat();
}

dlcws_init_dvars()
{
    setdvarifuninitialized( "scr_zm_dlc_shop_enabled", DLCWS_DEFAULT_ENABLED );
    setdvarifuninitialized( "scr_zm_dlc_shop_debug", DLCWS_DEFAULT_DEBUG );
    setdvarifuninitialized( "scr_zm_dlc_shop_awd_compat", DLCWS_DEFAULT_AWD_COMPAT );
}

/*
    The optional all_weapon_damage.gsc script only configures stock Zombies
    weapon names. Give the roster weapons it does not know the same default
    Mk damage table, so they scale like the stock weapons. Nothing happens
    when that script is not loaded.
*/
dlcws_awd_compat()
{
    level endon( "game_ended" );

    if ( getdvarint( "scr_zm_dlc_shop_awd_compat" ) == 0 )
    {
        return;
    }

    waited = 0;
    while ( !isdefined( level.awd_weapon_list ) || !isdefined( level.awd_weapon_damage ) )
    {
        if ( waited >= DLCWS_AWD_WAIT_STEPS )
        {
            return;
        }

        waited++;
        wait DLCWS_POLL_INTERVAL;
    }

    if ( !isdefined( level.awd_default_mark_damage ) ||
         !isdefined( level.awd_default_mark_damage[2] ) ||
         !isdefined( level.awd_default_mark_damage[25] ) )
    {
        return;
    }

    added = 0;
    foreach ( entry in level.dlcws_weapons )
    {
        weaponName = entry.weaponName;
        if ( isdefined( level.awd_weapon_damage[weaponName] ) )
        {
            continue;
        }

        level.awd_weapon_list[level.awd_weapon_list.size] = weaponName;
        level.awd_weapon_damage[weaponName] = [];
        level.awd_weapon_damage[weaponName]["mk2"] = level.awd_default_mark_damage[2];
        level.awd_weapon_damage[weaponName]["mk25"] = level.awd_default_mark_damage[25];
        added++;
    }

    println( "DLCWeaponShop: " + added + " roster weapons added to all_weapon_damage." );
}

dlcws_selected_pack()
{
    modPath = tolower( getdvar( "fs_game" ) );

    if ( modPath == "mods/exo_weapons_all" ||
         modPath == "mods\\exo_weapons_all" )
    {
        return DLCWS_ALL_PACK_NUMBER;
    }

    for ( number = 1; number <= DLCWS_PACK_COUNT; number++ )
    {
        if ( modPath == "mods/exo_weapons_0" + number ||
             modPath == "mods\\exo_weapons_0" + number )
        {
            return number;
        }
    }

    return 0;
}

dlcws_selected_pack_fastfile()
{
    if ( level.dlcws_packNumber == DLCWS_ALL_PACK_NUMBER )
    {
        return "mods/exo_weapons_all/mod.ff";
    }

    return "mods/exo_weapons_0" + level.dlcws_packNumber + "/mod.ff";
}

/*
    Only the weapons listed here are offered for purchase. Native base IDs
    for AK-47, SVO, M16 and CEL-3 contain "loot"; they are base weapons,
    not loot variants, in the game's native tables.
*/
dlcws_build_weapon_list()
{
    level.dlcws_weapons = [];
    level.dlcws_weaponEntries = [];

    dlcws_add_weapon( "iw5_thor_mp", "Thor", 6 );
    dlcws_add_weapon( "iw5_microwavezm_mp", "Microwave", 5 );
    dlcws_add_weapon( "iw5_linegunzm_mp", "Line Gun", 6 );
    dlcws_add_weapon( "iw5_tridentzm_mp", "Trident", 7 );
    dlcws_add_weapon( "iw5_dlcgun1zm_mp", "DLC Weapon I", 5 );
    dlcws_add_weapon( "iw5_dlcgun2zm_mp", "Ohm", 2 );
    dlcws_add_weapon( "iw5_dlcgun3zm_mp", "DLC Weapon III", 1 );
    dlcws_add_weapon( "iw5_dlcgun4zm_mp", "Blunderbuss (Zombies)", 6 );
    dlcws_add_weapon( "iw5_dlcgun13_mp", "1911", 2 );
    dlcws_add_weapon( "iw5_pbw_mp", "MP443", 2 );
    dlcws_add_weapon( "iw5_dlcgun7loot0_mp", "AK-47", 1 );
    dlcws_add_weapon( "iw5_epm3_mp", "EPM3", 6 );
    dlcws_add_weapon( "iw5_riotshieldt6_mp", "Riot Shield", 7 );
    dlcws_add_weapon( "iw5_dlcgun33_mp", "Lever Action", 3 );
    dlcws_add_weapon( "iw5_dlcgun23_mp", "M1 Garand", 4 );
    dlcws_add_weapon( "iw5_dlcgun7loot6_mp", "M16", 1 );
    dlcws_add_weapon( "iw5_maaws_mp", "MAAWS", 7 );
    dlcws_add_weapon( "iw5_microdronelauncher_mp", "MDL", 7 );
    dlcws_add_weapon( "iw5_m990_mp", "M990", 6 );
    dlcws_add_weapon( "iw5_dlcgun18_mp", "MP40", 5 );
    dlcws_add_weapon( "iw5_dlcgun38_mp", "Repulsor", 5 );
    dlcws_add_weapon( "iw5_dlcgun6_mp", "STG-44", 1 );
    dlcws_add_weapon( "iw5_dlcgun6loot5_mp", "SVO", 1 );
    dlcws_add_weapon( "iw5_stingerm7_mp", "Stinger M7", 7 );
    dlcws_add_weapon( "iw5_dlcgun28_mp", "Sten", 4 );
    dlcws_add_weapon( "iw5_mors_mp", "MORS", 6 );
    dlcws_add_weapon( "iw5_exoxmg_mp", "XMG (Dual)", 4, 1 );
}

dlcws_entry_in_mounted_pack( entry )
{
    if ( !level.dlcws_packReady )
    {
        return false;
    }

    if ( level.dlcws_packNumber == DLCWS_ALL_PACK_NUMBER )
    {
        return true;
    }

    return isdefined( entry.packNumber ) && entry.packNumber == level.dlcws_packNumber;
}

dlcws_register_entry( entry )
{
    // A missing Mk attachment must not hide a weapon whose base def loaded.
    return dlcws_base_registered( entry.weaponName );
}

dlcws_register_weapon_list()
{
    registered = 0;
    foreach ( entry in level.dlcws_weapons )
    {
        entry.grantReady = dlcws_register_entry( entry );
        if ( !entry.grantReady )
        {
            println( "DLCWeaponShop: " + entry.displayName + " is not loaded. It stays listed but cannot be purchased." );
            continue;
        }

        entry.grantReady = true;
        registered++;
    }

    level.dlcws_registeredCount = registered;
    return registered > 0;
}

dlcws_register_loadout( entry, weaponLevel )
{
    weaponName = dlcws_weapon_name_for_level( entry.weaponName, weaponLevel, entry.dualWield );
    baseName = getweaponbasename( weaponName );
    if ( !isdefined( baseName ) || baseName != entry.weaponName )
    {
        println( "DLCWeaponShop: loadout registration failed: " + weaponName );
        return false;
    }
    return true;
}

dlcws_add_weapon( weaponName, displayName, packNumber, dualWield )
{
    entry = spawnstruct();
    entry.weaponName = weaponName;
    entry.displayName = displayName;
    entry.packNumber = packNumber;
    entry.grantReady = false;
    entry.dualWield = isdefined( dualWield ) && dualWield;
    entry.shopKey = weaponName;
    if ( entry.dualWield )
    {
        entry.shopKey += "_dual";
    }

    level.dlcws_weapons[ level.dlcws_weapons.size ] = entry;
    if ( !isdefined( level.dlcws_weaponEntries[weaponName] ) )
    {
        level.dlcws_weaponEntries[weaponName] = entry;
    }
}

dlcws_init_weapon_upgrades()
{
    replacefunc( maps\mp\zombies\_wall_buys::getupgradeweaponname, ::dlcws_upgrade_weapon_name );
    replacefunc( maps\mp\zombies\_wall_buys::setweaponlevel, ::dlcws_set_weapon_level );
    replacefunc( maps\mp\zombies\_wall_buys::findholomodel, ::dlcws_find_holo_model );
    dlcws_init_launcher_targets();
    foreach ( entry in level.dlcws_weapons )
    {
        if ( entry.weaponName == "iw5_combatknife_mp" ||
             entry.weaponName == "iw5_maaws_mp" ||
             entry.weaponName == "iw5_microdronelauncher_mp" ||
             entry.weaponName == "iw5_stingerm7_mp" ||
             entry.weaponName == "iw5_mahem_mp" )
        {
            println( "DLCWeaponShop: " + entry.weaponName +
                " has no compatible progressive attachment slots; native Mk levels and camo are retained." );
        }
    }
}

dlcws_init_launcher_targets()
{
    // Imported launchers still query MP aerial-target tables on Zombies maps.
    if ( !isdefined( level.uavmodels ) )
    {
        level.uavmodels = [];
    }
    foreach ( team in [ "allies", "axis" ] )
    {
        if ( !isdefined( level.uavmodels[team] ) )
        {
            level.uavmodels[team] = [];
        }
    }
    if ( !isdefined( level.planes ) )
    {
        level.planes = [];
    }
    if ( !isdefined( level.stingerlockonentsfunc ) )
    {
        level.stingerlockonentsfunc = ::dlcws_zombie_lockon_targets;
    }
}

dlcws_zombie_lockon_targets( player )
{
    targets = [];
    if ( !isdefined( level.agentarray ) )
    {
        return targets;
    }
    foreach ( agent in level.agentarray )
    {
        if ( isdefined( agent ) && isalive( agent ) && isdefined( agent.team ) &&
             agent.team != player.team )
        {
            targets[targets.size] = agent;
        }
    }
    return targets;
}

dlcws_stock_holo_model( baseName )
{
    if ( isdefined( level.magicboxweapons ) )
    {
        foreach ( boxWeapon in level.magicboxweapons )
        {
            if ( boxWeapon["baseName"] == baseName )
            {
                return boxWeapon["displayModel"];
            }
        }
    }

    if ( isdefined( level.wallbuyweapons ) )
    {
        foreach ( wallWeapon in level.wallbuyweapons )
        {
            if ( wallWeapon["baseName"] == baseName )
            {
                return wallWeapon["displayModel"];
            }
        }
    }

    return undefined;
}

// Weapons that have no hologram of their own borrow the hologram of a similar stock weapon.
// World models are not usable here: the upgrade station only renders the stock hologram models.
dlcws_holo_stand_in( weaponName )
{
    switch ( weaponName )
    {
        case "iw5_microwavezm_mp":
        case "iw5_linegunzm_mp":
        case "iw5_tridentzm_mp":
            return "iw5_em1zm_mp";
        case "iw5_dlcgun2zm_mp":
            return "iw5_lsatzm_mp";
        case "iw5_dlcgun3zm_mp":
            return "iw5_m182sprzm_mp";
        case "iw5_dlcgun4zm_mp":
            return "iw5_fusionzm_mp";
        case "iw5_maaws_mp":
        case "iw5_microdronelauncher_mp":
        case "iw5_stingerm7_mp":
            return "iw5_mahemzm_mp";
    }

    return weaponName;
}

// The stock lookup falls back to the small Titan 45 hologram for every weapon that is not in the
// current map's box or wall list, so look through the stock weapon it pairs with first.
dlcws_find_holo_model( baseName )
{
    candidates = [
        baseName,
        maps\mp\_utility::strip_suffix( baseName, "_mp" ) + "zm_mp",
        dlcws_upgrade_donor( baseName ),
        dlcws_holo_stand_in( baseName )
    ];

    foreach ( candidate in candidates )
    {
        model = dlcws_stock_holo_model( candidate );
        if ( isdefined( model ) )
        {
            return model;
        }
    }

    return "npc_titan45_base_static_holo";
}

dlcws_upgrade_donor( weaponName )
{
    paired = maps\mp\_utility::strip_suffix( weaponName, "_mp" ) + "zm_mp";
    if ( isdefined( level.dlcws_weaponEntries[paired] ) )
    {
        return paired;
    }

    switch ( weaponName )
    {
        case "iw5_dlcgun6loot5_mp":
        case "iw5_m990_mp":
        case "iw5_mors_mp":
        case "iw5_thor_mp":
            return "iw5_gm6zm_mp";
        case "iw5_dlcgun23_mp":
        case "iw5_dlcgun33_mp":
        case "iw5_dlcgun6_mp":
        case "iw5_dlcgun7loot0_mp":
        case "iw5_dlcgun7loot6_mp":
            return "iw5_m182sprzm_mp";
        case "iw5_dlcgun13_mp":
        case "iw5_pbw_mp":
            return "iw5_titan45zm_mp";
        case "iw5_dlcgun18_mp":
        case "iw5_dlcgun28_mp":
        case "iw5_dlcgun38_mp":
        case "iw5_kf5_mp":
            return "iw5_asm1zm_mp";
        case "iw5_dlcgun8loot1_mp":
            return "iw5_fusionzm_mp";
        case "iw5_epm3_mp":
            return "iw5_em1zm_mp";
        case "iw5_exoxmg_mp":
            return "iw5_sac3zm_mp";
    }

    return weaponName;
}

dlcws_default_sniper_scope( weaponName )
{
    switch ( weaponName )
    {
        case "iw5_dlcgun6loot5_mp":
            return "dragunovdlcscope";
        case "iw5_gm6_mp":
        case "iw5_gm6zm_mp":
            return "gm6scope";
        case "iw5_m990_mp":
            return "m990scope";
        case "iw5_mors_mp":
            return "morsscope";
        case "iw5_thor_mp":
            return "thorscope";
    }

    return "none";
}

dlcws_upgrade_attachments( weaponName, weaponLevel )
{
    donor = weaponName;
    selected = isdefined( level.dlcws_weaponEntries[weaponName] );
    if ( selected )
    {
        donor = dlcws_upgrade_donor( weaponName );
    }
    attachments = [
        maps\mp\zombies\_wall_buys::getattachment1forweaponlevel( donor, weaponLevel ),
        maps\mp\zombies\_wall_buys::getattachment2forweaponlevel( donor, weaponLevel ),
        maps\mp\zombies\_wall_buys::getattachment3forweaponlevel( donor, weaponLevel )
    ];
    if ( !selected )
    {
        return attachments;
    }

    scope = dlcws_default_sniper_scope( weaponName );
    if ( weaponLevel < 4 && scope != "none" )
    {
        // MP snipers get their stock optic automatically; adding it again duplicates it.
        attachments[0] = "none";
        if ( weaponName == "iw5_gm6zm_mp" )
        {
            attachments[0] = scope;
        }
    }
    if ( weaponName == "iw5_mahem_mp" )
    {
        return [ "none", "none", "none" ];
    }
    if ( weaponName == "iw5_dlcgun13_mp" && attachments[0] == "opticstargetenhancer" )
    {
        // The 1911 has no mount for the Titan 45 target enhancer; it renders as a screen-wide dark bar.
        attachments[0] = "none";
    }
    if ( weaponName == "iw5_exocrossbow_mp" )
    {
        attachments[1] = "none";
        attachments[2] = "none";
    }
    if ( weaponLevel >= 4 && weaponName == "iw5_thor_mp" )
    {
        attachments[0] = "thorscopevz";
    }
    if ( weaponLevel >= 4 && weaponName == "iw5_m990_mp" )
    {
        attachments[0] = "opticsacog2";
    }
    if ( weaponName == "iw5_riotshieldt6_mp" )
    {
        attachments[0] = "none";
        if ( weaponLevel >= 4 )
        {
            attachments[0] = "shieldfastmelee";
        }
    }
    if ( weaponLevel >= 7 )
    {
        switch ( weaponName )
        {
            case "iw5_m990_mp":
            case "iw5_thor_mp":
                attachments[1] = "stock";
                break;
            case "iw5_rw1_mp":
                attachments[1] = "tactical";
                break;
            case "iw5_microwavezm_mp":
                attachments[1] = "quickdraw";
                break;
            case "iw5_riotshieldt6_mp":
                attachments[1] = "shieldfastplant";
                break;
        }
    }
    if ( weaponLevel >= 10 )
    {
        switch ( weaponName )
        {
            case "iw5_dlcgun1_mp":
                attachments[2] = "heatsink";
                break;
            case "iw5_mors_mp":
            case "iw5_microwavezm_mp":
                attachments[2] = "stock";
                break;
            case "iw5_m990_mp":
                // The stabilizer is a complete scope, not an accessory for the ACOG.
                attachments[0] = "m990stabilizer";
                attachments[2] = "none";
                break;
            case "iw5_rw1_mp":
                attachments[2] = "longrange";
                break;
            case "iw5_riotshieldt6_mp":
                attachments[2] = "shieldshockplant";
                break;
        }
    }

    return attachments;
}

dlcws_replace_attachment_token( weaponName, attachment, replacement )
{
    result = "";
    foreach ( token in strtok( weaponName, "_" ) )
    {
        if ( token == attachment )
        {
            token = replacement;
        }
        if ( token == "" )
        {
            continue;
        }
        if ( result != "" )
        {
            result += "_";
        }
        result += token;
    }
    return result;
}

dlcws_camo_table_key( weaponName )
{
    // mp/camomaterialtable.csv lists weapons without the _mp and zm suffixes.
    key = maps\mp\_utility::strip_suffix( weaponName, "_mp" );
    return maps\mp\_utility::strip_suffix( key, "zm" );
}

dlcws_camo_cell( weaponName, camo )
{
    // The column of mp/camomaterialtable.csv that names the material of a
    // camo: camo01 (19) 1, camo04 (22) 4, toxictiger (23) 5, infected (24) 6.
    column = 5;
    if ( camo == 19 )
    {
        column = 1;
    }
    else if ( camo == 22 )
    {
        column = 4;
    }
    else if ( camo == 24 )
    {
        column = 6;
    }

    cell = tablelookup( "mp/camomaterialtable.csv", 0, dlcws_camo_table_key( weaponName ), column );
    if ( !isdefined( cell ) )
    {
        return "";
    }

    return cell;
}

dlcws_camo_swaps_rows( weaponName )
{
    // Weapons whose Mk2 and Mk15 cells in the stock camo table are blank and
    // whose camo01 and camo04 cells name a material that only the pack defines.
    switch ( weaponName )
    {
        case "iw5_thor_mp":
        case "iw5_pbw_mp":
        case "iw5_epm3_mp":
        case "iw5_dlcgun33_mp":
        case "iw5_dlcgun23_mp":
        case "iw5_maaws_mp":
        case "iw5_microdronelauncher_mp":
        case "iw5_m990_mp":
        case "iw5_dlcgun38_mp":
        case "iw5_stingerm7_mp":
        case "iw5_dlcgun28_mp":
        case "iw5_mors_mp":
        case "iw5_exoxmg_mp":
            return true;
    }

    return false;
}

dlcws_mk_camo( weaponName, camo )
{
    // Camo 23 is the Mk2 (Toxic Tiger) and camo 24 the Mk15 (Infected) camo.
    // The pack cannot replace the stock camo tables, so the imported weapons
    // whose Mk2/Mk15 cells are blank wear the same two looks as camo 19 and
    // camo 22; the others use 23 and 24 with the materials the pack defines
    // under the names the table already gives them.
    if ( !dlcws_camo_swaps_rows( weaponName ) )
    {
        return camo;
    }

    if ( camo == 23 )
    {
        return 19;
    }

    return 22;
}

dlcws_log_camo_status()
{
    ready = "no";
    if ( level.dlcws_nativeCamosReady )
    {
        ready = "yes";
    }

    blank = "";
    foreach ( entry in level.dlcws_weapons )
    {
        if ( entry.weaponName == "iw5_riotshieldt6_mp" )
        {
            continue;
        }

        if ( dlcws_camo_cell( entry.weaponName, dlcws_mk_camo( entry.weaponName, 23 ) ) == "" ||
             dlcws_camo_cell( entry.weaponName, dlcws_mk_camo( entry.weaponName, 24 ) ) == "" )
        {
            blank += " " + entry.weaponName;
        }
    }

    if ( blank == "" )
    {
        blank = " none";
    }

    dlcws_log( "camo pack_materials=" + ready + " weapons_without_a_camo_material_in_the_table:" + blank );
}

dlcws_camo_has_variants( weaponName )
{
    // The Zombies guns: the stock Zombies zones define their Mk2/Mk15 materials.
    switch ( weaponName )
    {
        case "iw5_microwavezm_mp":
        case "iw5_linegunzm_mp":
        case "iw5_tridentzm_mp":
        case "iw5_dlcgun1zm_mp":
        case "iw5_dlcgun2zm_mp":
        case "iw5_dlcgun3zm_mp":
        case "iw5_dlcgun4zm_mp":
            return true;
    }

    return false;
}

dlcws_camo_for_level( weaponName, weaponLevel, plainOnly )
{
    camo = maps\mp\zombies\_wall_buys::getcamoforweaponlevel( weaponName, weaponLevel );

    if ( !isdefined( level.dlcws_weaponEntries[weaponName] ) )
    {
        return camo;
    }

    if ( weaponName == "iw5_riotshieldt6_mp" )
    {
        return 0;
    }

    if ( camo != 23 && camo != 24 )
    {
        return camo;
    }

    if ( !isdefined( plainOnly ) || !plainOnly )
    {
        if ( dlcws_camo_has_variants( weaponName ) )
        {
            return camo;
        }

        if ( isdefined( level.dlcws_nativeCamosReady ) && level.dlcws_nativeCamosReady )
        {
            return dlcws_mk_camo( weaponName, camo );
        }
    }

    // Without the pack's materials a table cell would name a missing material
    // and the weapon would be invisible, so take the plain camo of an earlier level.
    for ( previousLevel = int( weaponLevel ) - 1; previousLevel >= 0; previousLevel-- )
    {
        fallback = maps\mp\zombies\_wall_buys::getcamoforweaponlevel( weaponName, previousLevel );
        if ( fallback != 23 && fallback != 24 )
        {
            return fallback;
        }
    }

    return 1;
}

dlcws_weapon_name_for_level( weaponName, weaponLevel, dualWield )
{
    result = dlcws_build_weapon_name( weaponName, weaponLevel, dualWield, false );
    if ( !isdefined( level.dlcws_weaponEntries[weaponName] ) )
    {
        return result;
    }

    camo = maps\mp\zombies\_wall_buys::getcamoforweaponlevel( weaponName, weaponLevel );
    if ( camo != 23 && camo != 24 )
    {
        return result;
    }

    baseName = getweaponbasename( result );
    if ( isdefined( baseName ) && baseName == weaponName )
    {
        dlcws_log_once( "camo_" + weaponName + "_" + camo, "camo " + camo + " loadout " + result );
        return result;
    }

    // The game refused the Mk camo variant; a refused name would not be given at all.
    plain = dlcws_build_weapon_name( weaponName, weaponLevel, dualWield, true );
    plainBase = getweaponbasename( plain );
    if ( plain != result && isdefined( plainBase ) && plainBase == weaponName )
    {
        shownBase = "";
        if ( isdefined( baseName ) )
        {
            shownBase = baseName;
        }
        dlcws_log_once( "camo_refused_" + weaponName, "camo variant " + result + " resolved to base '" +
            shownBase + "', using " + plain );
        return plain;
    }

    return result;
}

dlcws_build_weapon_name( weaponName, weaponLevel, dualWield, plainCamo )
{
    attachments = dlcws_upgrade_attachments( weaponName, weaponLevel );
    camo = dlcws_camo_for_level( weaponName, weaponLevel, plainCamo );
    baseName = maps\mp\_utility::strip_suffix( weaponName, "_mp" );
    result = maps\mp\gametypes\_class::buildweaponname(
        baseName, attachments[0], attachments[1], attachments[2], camo, 0 );
    if ( weaponName == "iw5_dlcgun2_mp" )
    {
        // The MP Ohm supports sensorheartbeat, not the Zombies-only automatic alias.
        result = dlcws_replace_attachment_token( result, "sensorheartbeatzm", "sensorheartbeat" );
    }
    if ( weaponName == "iw5_dlcgun33_mp" || weaponName == "iw5_dlcgun38_mp" )
    {
        // Native M1 Irons matching also catches these later, non-akimbo DLC bases.
        result = dlcws_replace_attachment_token( result, "akimbo", "" );
    }
    dualToken = dlcws_dual_token( weaponName );
    if ( isdefined( dualToken ) && isdefined( dualWield ) && !dualWield )
    {
        // buildweaponname always appends the akimbo attachment for these bases.
        result = dlcws_replace_attachment_token( result, dualToken, "" );
    }
    return result;
}

dlcws_dual_token( baseName )
{
    switch ( baseName )
    {
        case "iw5_exoxmg_mp":
            return "akimboxmg";
        case "iw5_sac3_mp":
            return "akimbosac3";
    }

    return undefined;
}

dlcws_remember_dual( player, baseName, isDual )
{
    if ( !isdefined( player.dlcws_dualChoice ) )
    {
        player.dlcws_dualChoice = [];
    }
    player.dlcws_dualChoice[baseName] = isDual;
}

dlcws_upgrade_weapon_name( player, weaponName )
{
    baseName = getweaponbasename( weaponName );
    weaponLevel = maps\mp\zombies\_util::getzombieweaponlevel( player, baseName );
    if ( weaponLevel <= 0 )
    {
        if ( !isdefined( level.dlcws_weaponEntries[baseName] ) )
        {
            return weaponName;
        }
        weaponLevel = 1;
    }
    dualWield = undefined;
    dualToken = dlcws_dual_token( baseName );
    if ( isdefined( dualToken ) )
    {
        dualWield = true;
        if ( isdefined( player.dlcws_dualChoice ) && isdefined( player.dlcws_dualChoice[baseName] ) )
        {
            dualWield = player.dlcws_dualChoice[baseName];
        }
        if ( weaponName != baseName )
        {
            dualWield = issubstr( weaponName, dualToken );
        }
    }
    return dlcws_weapon_name_for_level( baseName, min( weaponLevel, 25 ), dualWield );
}

dlcws_refresh_alt_mode( player, baseName )
{
    // The class loadout binds the alt-fire toggle to action slot 3 at spawn;
    // bind it again after the Ohm is granted so it cannot be left unset.
    if ( baseName != "iw5_dlcgun2zm_mp" || !isdefined( player.saved_actionslotdata ) ||
         !isdefined( player.saved_actionslotdata[3] ) )
    {
        return;
    }

    player maps\mp\_utility::_setactionslot( 3, "altMode" );
}

dlcws_set_weapon_level( player, weaponName, weaponLevel )
{
    baseName = getweaponbasename( weaponName );
    dualToken = dlcws_dual_token( baseName );
    if ( isdefined( dualToken ) )
    {
        dlcws_remember_dual( player, baseName, issubstr( weaponName, dualToken ) );
    }
    player takeweapon( weaponName );
    player.weaponstate[baseName]["level"] = weaponLevel;
    upgraded = maps\mp\zombies\_wall_buys::getupgradeweaponname( player, baseName );
    maps\mp\zombies\_wall_buys::givezombieweapon( player, upgraded, 0 );
    if ( issubstr( upgraded, "iw5_em1zm_mp" ) )
    {
        player maps\mp\gametypes\zombies::playersetem1maxammo();
    }
    if ( isdefined( level.setweaponlevelfunc ) )
    {
        player [[ level.setweaponlevelfunc ]]( weaponName, weaponLevel );
    }
    dlcws_refresh_alt_mode( player, baseName );
    player playsoundtoplayer( "mp_s1_earn_medal", player );
}

dlcws_watch_players()
{
    level endon( "game_ended" );

    foreach ( player in getentarray( "player", "classname" ) )
    {
        player thread dlcws_player_init();
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread dlcws_player_init();
    }
}

dlcws_player_init()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    if ( isdefined( self.dlcws_playerStarted ) && self.dlcws_playerStarted )
    {
        return;
    }

    self.dlcws_playerStarted = true;
    self.dlcws_shopOpen = false;
    self.dlcws_controlsOwned = false;
    self thread dlcws_death_cleanup();
    self thread dlcws_disconnect_cleanup();

    if ( isalive( self ) )
    {
        self dlcws_player_spawned();
    }

    for ( ;; )
    {
        self waittill( "spawned_player" );
        self dlcws_player_spawned();
    }
}

dlcws_player_spawned()
{
    dlcws_close_shop( self );
    self thread dlcws_player_monitor();
}

dlcws_death_cleanup()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for ( ;; )
    {
        self waittill( "death" );
        dlcws_close_shop( self );
    }
}

dlcws_disconnect_cleanup()
{
    level endon( "game_ended" );
    self waittill( "disconnect" );
    dlcws_close_shop( self, false );
}

dlcws_game_end_cleanup()
{
    level waittill( "game_ended" );

    foreach ( player in getentarray( "player", "classname" ) )
    {
        dlcws_close_shop( player );
    }
}

dlcws_player_can_shop( player )
{
    shopReady = isdefined( level.dlcws_weapons ) && level.dlcws_weapons.size > 0;

    return shopReady &&
        getdvarint( "scr_zm_dlc_shop_enabled" ) > 0 &&
        isdefined( level.zombieinitialcountdownover ) && level.zombieinitialcountdownover &&
        isdefined( player ) && isalive( player ) &&
        isdefined( player.sessionstate ) && player.sessionstate == "playing" &&
        isdefined( player.moneycurrent ) &&
        isdefined( player.weaponstate ) && isdefined( player.pointnotifylua ) &&
        !( isdefined( player.laststand ) && player.laststand ) &&
        !( isdefined( player.inlaststand ) && player.inlaststand ) &&
        !( isdefined( player.isreviving ) && player.isreviving ) &&
        !( isdefined( player.playingweaponflourish ) && player.playingweaponflourish );
}

dlcws_open_gesture_ready( player )
{
    if ( !issubstr( player getcurrentweapon(), "scopevz" ) )
    {
        return true;
    }

    startTime = gettime();
    while ( dlcws_player_can_shop( player ) &&
            ( player adsbuttonpressed() || player adsbuttonpressed( 1 ) ) &&
            player meleebuttonpressed() )
    {
        if ( gettime() - startTime >= DLCWS_SCOPE_OPEN_HOLD_MS )
        {
            return true;
        }
        wait DLCWS_POLL_INTERVAL;
    }

    return false;
}

/*
    Watches for the open gesture (Aim + Melee together), then runs the
    shop menu loop until the player buys, cancels, idles out, or
    disconnects.
*/
dlcws_player_monitor()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "spawned_player" );
    level endon( "game_ended" );

    for ( ;; )
    {
        wait DLCWS_POLL_INTERVAL;

        if ( !dlcws_player_can_shop( self ) )
        {
            continue;
        }

        if ( !isdefined( self.dlcws_readyNotified ) )
        {
            dlcws_refresh_pack_state();
            self.dlcws_readyNotified = true;
            if ( level.dlcws_packReady )
            {
                self iprintlnbold( "Weapon shop ready. Hold Aim and Melee." );
            }
            else
            {
                self dlcws_notify_pack_missing();
            }
        }

        if ( !isdefined( self.dlcws_shopOpen ) )
        {
            self.dlcws_shopOpen = false;
        }

        if ( self.dlcws_shopOpen )
        {
            continue;
        }

        // Toggle/throw aim bindings use the alternate native ADS flag.
        if ( ( self adsbuttonpressed() || self adsbuttonpressed( 1 ) ) && self meleebuttonpressed() )
        {
            if ( !dlcws_open_gesture_ready( self ) )
            {
                continue;
            }
            // Wait for melee release so the menu doesn't immediately
            // register it as a "previous weapon" press.
            dlcws_wait_for_release( self, "melee" );

            self thread dlcws_open_shop();
        }
    }
}

dlcws_open_shop()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "spawned_player" );
    self endon( "dlcws_shop_closed" );
    level endon( "game_ended" );

    if ( !dlcws_player_can_shop( self ) )
    {
        return;
    }

    if ( isdefined( self.dlcws_shopOpen ) && self.dlcws_shopOpen )
    {
        return;
    }

    if ( !level.dlcws_packReady )
    {
        // Nothing can be bought, so don't freeze the player to browse the list.
        self dlcws_notify_pack_missing();
        return;
    }

    if ( isdefined( self.controlsfrozen ) && self.controlsfrozen )
    {
        self iprintlnbold( "Wait until your controls are unlocked to open the shop." );
        return;
    }

    self.dlcws_shopOpen = true;
    self.dlcws_shopIndex = 0;
    self.dlcws_lastInputTime = gettime();
    self.dlcws_controlsOwned = true;

    self maps\mp\_utility::freezecontrolswrapper( 1 );

    controlsText = "[Attack] Next   [Melee] Prev   [Use] Buy (" + DLCWS_WEAPON_COST + " credits)   [Frag] Cancel";
    if ( level.dlcws_messageMode )
    {
        self iprintln( controlsText );
    }
    else
    {
        self.dlcws_hud = newclienthudelem( self );
        self.dlcws_hud.alignx = "center";
        self.dlcws_hud.aligny = "middle";
        self.dlcws_hud.horzalign = "center";
        self.dlcws_hud.vertalign = "middle";
        self.dlcws_hud.y = -40;
        self.dlcws_hud.fontscale = 1.8;
        self.dlcws_hud.foreground = true;
        self.dlcws_hud.sort = 10;

        self.dlcws_hint = newclienthudelem( self );
        self.dlcws_hint.alignx = "center";
        self.dlcws_hint.aligny = "middle";
        self.dlcws_hint.horzalign = "center";
        self.dlcws_hint.vertalign = "middle";
        self.dlcws_hint.y = 0;
        self.dlcws_hint.fontscale = 1.1;
        self.dlcws_hint.foreground = true;
        self.dlcws_hint.sort = 10;
        self.dlcws_hint settext( controlsText );
    }

    dlcws_refresh_hud( self );
    dlcws_debug( self.name + " opened the shop." );

    while ( self.dlcws_shopOpen )
    {
        wait DLCWS_POLL_INTERVAL;

        if ( !dlcws_player_can_shop( self ) ||
             ( gettime() - self.dlcws_lastInputTime ) >= ( DLCWS_IDLE_TIMEOUT_SECONDS * 1000 ) )
        {
            break;
        }

        if ( self fragbuttonpressed() )
        {
            break;
        }

        if ( level.dlcws_messageMode &&
             ( gettime() - self.dlcws_lastDisplayTime ) >= ( DLCWS_MESSAGE_REFRESH_SECONDS * 1000 ) )
        {
            dlcws_refresh_hud( self );
        }

        if ( self attackbuttonpressed() )
        {
            self.dlcws_lastInputTime = gettime();
            self.dlcws_shopIndex = ( self.dlcws_shopIndex + 1 ) % level.dlcws_weapons.size;
            dlcws_refresh_hud( self );
            dlcws_wait_for_release( self, "attack" );
        }
        else if ( self meleebuttonpressed() )
        {
            self.dlcws_lastInputTime = gettime();
            self.dlcws_shopIndex = self.dlcws_shopIndex - 1;
            if ( self.dlcws_shopIndex < 0 )
            {
                self.dlcws_shopIndex = level.dlcws_weapons.size - 1;
            }
            dlcws_refresh_hud( self );
            dlcws_wait_for_release( self, "melee" );
        }
        else if ( self usebuttonpressed() )
        {
            self.dlcws_lastInputTime = gettime();
            dlcws_try_purchase( self );
            dlcws_wait_for_release( self, "use" );
        }
    }

    dlcws_close_shop( self );
}

dlcws_wait_for_release( player, buttonName )
{
    while ( isdefined( player ) && dlcws_button_pressed( player, buttonName ) )
    {
        if ( !dlcws_player_can_shop( player ) ||
             ( player.dlcws_shopOpen &&
               ( player fragbuttonpressed() ||
                 ( gettime() - player.dlcws_lastInputTime ) >= ( DLCWS_IDLE_TIMEOUT_SECONDS * 1000 ) ) ) )
        {
            return;
        }

        wait DLCWS_POLL_INTERVAL;
    }
}

dlcws_button_pressed( player, buttonName )
{
    if ( buttonName == "attack" )
    {
        return player attackbuttonpressed();
    }

    if ( buttonName == "melee" )
    {
        return player meleebuttonpressed();
    }

    if ( buttonName == "use" )
    {
        return player usebuttonpressed();
    }

    return false;
}

dlcws_refresh_hud( player )
{
    if ( !isdefined( player.dlcws_shopOpen ) || !player.dlcws_shopOpen )
    {
        return;
    }

    entry = level.dlcws_weapons[ player.dlcws_shopIndex ];
    titleText = "Weapon " + ( player.dlcws_shopIndex + 1 ) + "/" +
        level.dlcws_weapons.size + " - " + entry.displayName + " (" + DLCWS_WEAPON_COST + " credits)";
    if ( !isdefined( entry.grantReady ) || !entry.grantReady )
    {
        titleText += " - not loaded";
    }

    if ( level.dlcws_messageMode )
    {
        player iprintlnbold( titleText );
        player.dlcws_lastDisplayTime = gettime();
    }
    else if ( isdefined( player.dlcws_hud ) )
    {
        player.dlcws_hud settext( titleText );
    }
}

dlcws_pack_missing_text()
{
    return "Weapon shop: no weapons are loaded by this map's default fastfiles.";
}

dlcws_notify_pack_missing()
{
    // Repeated Aim+Melee taps must not spam the screen.
    now = gettime();
    if ( isdefined( self.dlcws_lastPackNotice ) && ( now - self.dlcws_lastPackNotice ) < 4000 )
    {
        return;
    }

    self.dlcws_lastPackNotice = now;
    self iprintlnbold( dlcws_pack_missing_text() );
}

dlcws_not_loaded_message( entry )
{
    return entry.displayName + " is not loaded by this map's default fastfiles.";
}

dlcws_try_purchase( player )
{
    if ( !dlcws_player_can_shop( player ) )
    {
        player iprintlnbold( "The weapon shop is unavailable while downed, busy, or disabled." );
        dlcws_close_shop( player );
        return false;
    }

    entry = level.dlcws_weapons[ player.dlcws_shopIndex ];
    weaponName = dlcws_grant_name( player, entry );
    if ( !isdefined( weaponName ) )
    {
        player iprintlnbold( dlcws_not_loaded_message( entry ) );
        return false;
    }

    if ( !player maps\mp\gametypes\zombies::attempttobuy( DLCWS_WEAPON_COST ) )
    {
        player iprintlnbold( "Not enough credits for the " + entry.displayName + "." );
        return false;
    }

    probedName = getweaponbasename( weaponName );
    if ( !isdefined( probedName ) || probedName != entry.weaponName )
    {
        player maps\mp\gametypes\zombies::spendmoney( 0 - DLCWS_WEAPON_COST );
        println( "DLCWeaponShop: refused unregistered grant " + weaponName + "; purchase refunded." );
        player iprintlnbold( "Weapon purchase failed; " + DLCWS_WEAPON_COST + " credits refunded." );
        dlcws_close_shop( player );
        return false;
    }

    hadWeapon = player hasweapon( weaponName ) || dlcws_player_has_base( player, weaponName );
    maps\mp\zombies\_wall_buys::givezombieweapon( player, weaponName, 0, 1 );

    gotWeapon = player hasweapon( weaponName ) ||
        ( !hadWeapon && dlcws_player_has_base( player, weaponName ) );
    if ( !gotWeapon )
    {
        // Reverse the spend without counting the refund as newly earned money.
        player maps\mp\gametypes\zombies::spendmoney( 0 - DLCWS_WEAPON_COST );
        println( "DLCWeaponShop: failed to grant " + entry.weaponName + "; purchase refunded." );
        player iprintlnbold( "Weapon purchase failed; " + DLCWS_WEAPON_COST + " credits refunded." );
        dlcws_close_shop( player );
        return false;
    }

    if ( isdefined( dlcws_dual_token( entry.weaponName ) ) )
    {
        dlcws_remember_dual( player, entry.weaponName, entry.dualWield );
    }
    dlcws_refresh_alt_mode( player, entry.weaponName );
    player iprintln( "Purchased " + entry.displayName + " for " + DLCWS_WEAPON_COST + " credits." );
    dlcws_debug( player.name + " bought " + entry.weaponName );

    dlcws_close_shop( player );
    return true;
}

dlcws_debug( message )
{
    if ( getdvarint( "scr_zm_dlc_shop_debug" ) > 0 )
    {
        println( "DLCWeaponShop: " + message );
    }
}

dlcws_close_shop( player, restoreControls )
{
    if ( !isdefined( player ) )
    {
        return;
    }

    wasOpen = isdefined( player.dlcws_shopOpen ) && player.dlcws_shopOpen;
    player.dlcws_shopOpen = false;

    if ( isdefined( player.dlcws_hud ) )
    {
        player.dlcws_hud destroy();
        player.dlcws_hud = undefined;
    }

    if ( isdefined( player.dlcws_hint ) )
    {
        player.dlcws_hint destroy();
        player.dlcws_hint = undefined;
    }

    if ( !isdefined( restoreControls ) )
    {
        restoreControls = true;
    }

    if ( restoreControls && isdefined( player.dlcws_controlsOwned ) && player.dlcws_controlsOwned )
    {
        player maps\mp\_utility::freezecontrolswrapper( 0 );
    }

    player.dlcws_controlsOwned = false;
    player.dlcws_lastInputTime = undefined;
    player.dlcws_lastDisplayTime = undefined;
    if ( restoreControls && wasOpen && level.dlcws_messageMode && isalive( player ) )
    {
        player iprintlnbold( "Weapon shop closed." );
    }
    player notify( "dlcws_shop_closed" );
}

dlcws_base_registered( weaponName )
{
    if ( !isdefined( weaponName ) || weaponName == "" )
    {
        return false;
    }

    baseName = getweaponbasename( weaponName );
    return isdefined( baseName ) && baseName == weaponName;
}

dlcws_pack_assets_loaded()
{
    // Default-fastfile mode: the shop no longer requires the custom
    // mods/exo_weapons_* pack. Weapons are treated as available when the
    // active fastfiles (the map's own default content, or a custom pack if
    // one happens to be mounted) have registered at least one roster
    // weapon. Per-weapon availability is still enforced at grant time by
    // dlcws_base_registered(), so a weapon the default fastfiles did not
    // load stays listed as "not loaded" and is never given.
    if ( !isdefined( level.dlcws_weapons ) )
    {
        return false;
    }

    foreach ( entry in level.dlcws_weapons )
    {
        if ( dlcws_base_registered( entry.weaponName ) )
        {
            return true;
        }
    }

    return false;
}

dlcws_refresh_pack_state()
{
    level.dlcws_packNumber = dlcws_selected_pack();
    if ( level.dlcws_packNumber == 0 && dlcws_pack_assets_loaded() )
    {
        level.dlcws_packNumber = DLCWS_ALL_PACK_NUMBER;
    }
    level.dlcws_packReady = dlcws_pack_assets_loaded();
    dlcws_mark_grant_ready();
}

dlcws_write_runtime_status( phase )
{
    packState = "not_loaded";
    if ( level.dlcws_packReady )
    {
        packState = "loaded";
    }

    writefile( "s1/dlcws_runtime_status.log",
        "phase=" + phase + " map=" + getdvar( "mapname" ) +
        " gametype=" + getdvar( "g_gametype" ) +
        " fs_game=" + getdvar( "fs_game" ) +
        " pack=" + packState + "\n", 1 );

    if ( !isdefined( level.dlcws_weapons ) )
    {
        return;
    }

    foreach ( entry in level.dlcws_weapons )
    {
        weaponState = "not_registered";
        if ( dlcws_base_registered( entry.weaponName ) )
        {
            weaponState = "registered";
        }
        writefile( "s1/dlcws_runtime_status.log",
            "weapon=" + entry.weaponName + " " + weaponState + "\n", 1 );
    }
}

dlcws_log( text )
{
    writefile( "s1/dlcws_runtime_status.log", text + "\n", 1 );
}

dlcws_log_once( key, text )
{
    if ( !isdefined( level.dlcws_logged ) )
    {
        level.dlcws_logged = [];
    }

    if ( isdefined( level.dlcws_logged[key] ) )
    {
        return;
    }

    level.dlcws_logged[key] = true;
    dlcws_log( text );
}

dlcws_mark_grant_ready()
{
    if ( !isdefined( level.dlcws_weapons ) )
    {
        return;
    }

    foreach ( entry in level.dlcws_weapons )
    {
        entry.grantReady = dlcws_base_registered( entry.weaponName );
    }
}

dlcws_grant_name( player, entry )
{
    if ( !isdefined( entry ) || !dlcws_base_registered( entry.weaponName ) )
    {
        return undefined;
    }

    if ( !isdefined( level.dlcws_loadoutsReady ) || !level.dlcws_loadoutsReady )
    {
        if ( isdefined( entry.dualWield ) && entry.dualWield )
        {
            return undefined;
        }

        return entry.weaponName;
    }

    weaponLevel = maps\mp\zombies\_util::getzombieweaponlevel( player, entry.weaponName );
    if ( !isdefined( weaponLevel ) || weaponLevel < 1 )
    {
        weaponLevel = 1;
    }
    if ( weaponLevel > 25 )
    {
        weaponLevel = 25;
    }

    weaponName = dlcws_weapon_name_for_level( entry.weaponName, weaponLevel, entry.dualWield );
    baseName = getweaponbasename( weaponName );
    if ( isdefined( baseName ) && baseName == entry.weaponName )
    {
        dualToken = dlcws_dual_token( entry.weaponName );
        if ( isdefined( entry.dualWield ) && entry.dualWield &&
             ( !isdefined( dualToken ) || !issubstr( weaponName, dualToken ) ) )
        {
            return undefined;
        }

        return weaponName;
    }

    shownBase = "";
    if ( isdefined( baseName ) )
    {
        shownBase = baseName;
    }
    dlcws_log_once( "grant_" + entry.weaponName, "grant fallback: " + weaponName +
        " resolved to base '" + shownBase + "', giving " + entry.weaponName );

    if ( isdefined( entry.dualWield ) && entry.dualWield )
    {
        return undefined;
    }

    return entry.weaponName;
}

dlcws_try_mount_pack()
{
    // Default-fastfile mode: there is no custom pack to mount, so the pack
    // mount/guard logic is retired. Weapons come from the map's default
    // fastfiles and are validated per weapon at registration/grant time.
    level.dlcws_mountBlocked = false;
    level.dlcws_mountStuck = false;

    if ( fileexists( "s1/dlcws_mount_guard.txt" ) )
    {
        removefile( "s1/dlcws_mount_guard.txt" );
    }
}

dlcws_build_native_shop()
{
    level.dlcws_weapons = [];
    level.dlcws_weaponEntries = [];
    level.dlcws_nativeShop = false;
    level.dlcws_loadoutsReady = false;

    if ( !isdefined( level.magicboxweapons ) )
    {
        println( "DLCWeaponShop: map weapon list is not ready. Shop stays closed." );
        return;
    }

    foreach ( boxWeapon in level.magicboxweapons )
    {
        if ( !isdefined( boxWeapon ) || !isdefined( boxWeapon["baseName"] ) )
        {
            continue;
        }

        if ( maps\mp\zombies\_util::iszombieequipment( boxWeapon["baseName"] ) )
        {
            continue;
        }

        grantName = boxWeapon["fullName"];
        if ( !isdefined( grantName ) || grantName == "" )
        {
            grantName = boxWeapon["baseName"];
        }

        if ( isdefined( level.dlcws_weaponEntries[grantName] ) )
        {
            continue;
        }

        entry = spawnstruct();
        entry.weaponName = boxWeapon["baseName"];
        entry.grantName = grantName;
        entry.displayName = dlcws_native_display( boxWeapon );
        entry.dualWield = false;
        entry.nativeGrant = true;
        entry.shopKey = grantName;
        level.dlcws_weapons[ level.dlcws_weapons.size ] = entry;
        level.dlcws_weaponEntries[grantName] = entry;
    }

    if ( !level.dlcws_weapons.size )
    {
        println( "DLCWeaponShop: no loaded map weapons were available to sell." );
        return;
    }

    level.dlcws_nativeShop = true;
    println( "DLCWeaponShop: selling " + level.dlcws_weapons.size + " loaded map weapons for " + DLCWS_WEAPON_COST + " credits." );
}

dlcws_native_display( boxWeapon )
{
    name = boxWeapon["baseNameNoMP"];
    if ( !isdefined( name ) || name == "" )
    {
        name = boxWeapon["baseName"];
    }

    if ( getsubstr( name, 0, 4 ) == "iw5_" )
    {
        name = getsubstr( name, 4, name.size );
    }

    if ( name.size > 2 && getsubstr( name, name.size - 2, name.size ) == "zm" )
    {
        name = getsubstr( name, 0, name.size - 2 );
    }

    return name;
}

dlcws_player_has_base( player, weaponName )
{
    if ( !isdefined( player ) || !isdefined( weaponName ) )
    {
        return false;
    }

    baseName = getweaponbasename( weaponName );
    if ( !isdefined( baseName ) || baseName == "" )
    {
        baseName = weaponName;
    }

    weapons = player getweaponslistall();
    if ( !isdefined( weapons ) )
    {
        return false;
    }

    foreach ( owned in weapons )
    {
        ownedBase = getweaponbasename( owned );
        if ( owned == weaponName || ( isdefined( ownedBase ) && ownedBase == baseName ) )
        {
            return true;
        }
    }

    return false;
}
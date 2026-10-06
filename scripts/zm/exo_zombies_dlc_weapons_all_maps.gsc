/*
    Shared Exo Zombies DLC weapon pool for S1x / H1-Mod.

    Place this file at:
        s1/scripts/zm/exo_zombies_dlc_weapons_all_maps.gsc

    Maps:
        Outbreak mp_zombie_lab (1), Infection mp_zombie_brg (2),
        Carrier mp_zombie_ark (3), Descent mp_zombie_h2o (4).

    Toggles (set before loading the map):
        set scr_zm_dlc_weapons_enabled 1
        set scr_zm_dlc_weapons_debug   0

    Uses the native _wall_buys level.magicboxweapons pool and waits for
    its persistent magic_box_init flag, not an invented initialization
    notify. Existing entries, attachments and limits are left untouched.
    Added entries use weapon world models instead of DLC-only holograms.

    IMPORTANT: This script does not link assets into a map's fastfile.
    All roster weapons, models and upgrade variants must already be loaded
    by the installed mod. precacheitem() cannot supply missing assets.
    The shop's iw5_blunderbusszm_mp is retained as requested, but the
    stock DLC4 Blunderbuss is iw5_dlcgun4zm_mp; the former needs a mod asset.
    Exo Minigun normally belongs to the Goliath killstreak. Cross-map
    Microwave, Line Gun and Trident also need their native behavior/FX
    callbacks supplied by the mod; pool registration alone cannot port them.

    If printer initialization times out, no guessed pool is created.
    get_map_weapons(dlc), get_dlc_roster() and the player give helper
    remain available to other scripts. The give helper grants one selected
    roster weapon, not the entire inventory, using native Zombies state.
*/

#define EZDLC_DEFAULT_ENABLED 1
#define EZDLC_DEFAULT_DEBUG   0

main()
{
    init();
}

init()
{
    if ( isdefined( level.ezdlcInitStarted ) && level.ezdlcInitStarted )
    {
        return;
    }

    level.ezdlcInitStarted = true;
    setdvarifuninitialized( "scr_zm_dlc_weapons_enabled", EZDLC_DEFAULT_ENABLED );
    setdvarifuninitialized( "scr_zm_dlc_weapons_debug", EZDLC_DEFAULT_DEBUG );

    dlc = get_map_dlc();
    if ( dlc == 0 )
    {
        println( "DLCWeapons: skipping unsupported map " + getdvar( "mapname" ) );
        return;
    }

    if ( getdvar( "g_gametype" ) != "zombies" ||
         getdvarint( "scr_zm_dlc_weapons_enabled" ) <= 0 )
    {
        return;
    }

    // Precache in the loading entrypoint, before the startup thread yields.
    weapons = get_dlc_roster();
    level.ezdlc_models = [];
    foreach ( weapon in weapons )
    {
        precacheitem( weapon );
        level.ezdlc_models[weapon] = getweaponmodel( weapon );
        precachemodel( level.ezdlc_models[weapon] );
    }

    level thread ezdlc_add_to_printer( dlc );
}

get_map_dlc()
{
    switch ( tolower( getdvar( "mapname" ) ) )
    {
        case "mp_zombie_lab":
            return 1;
        case "mp_zombie_brg":
            return 2;
        case "mp_zombie_ark":
            return 3;
        case "mp_zombie_h2o":
            return 4;
    }

    return 0;
}

get_map_weapons( dlc )
{
    weapons = [];
    if ( dlc < 1 || dlc > 4 )
    {
        return weapons;
    }

    // These three shop weapons are not native printer entries on any map.
    weapons = [ "iw5_exominigunzm_mp", "iw5_blunderbusszm_mp", "iw5_titan45zm_mp" ];

    switch ( dlc )
    {
        case 1:
            missing = [ "iw5_dlcgun2zm_mp", "iw5_dlcgun3zm_mp", "iw5_dlcgun4zm_mp",
                        "iw5_microwavezm_mp", "iw5_linegunzm_mp", "iw5_tridentzm_mp" ];
            break;
        case 2:
            missing = [ "iw5_dlcgun2zm_mp", "iw5_dlcgun3zm_mp", "iw5_dlcgun4zm_mp",
                        "iw5_linegunzm_mp", "iw5_tridentzm_mp" ];
            break;
        case 3:
            missing = [ "iw5_dlcgun4zm_mp", "iw5_microwavezm_mp", "iw5_tridentzm_mp" ];
            break;
        case 4:
            missing = [ "iw5_microwavezm_mp", "iw5_linegunzm_mp" ];
            break;
    }

    return common_scripts\utility::array_combine( weapons, missing );
}

get_dlc_roster()
{
    weapons = [];
    weapons[weapons.size] = "iw5_dlcgun1zm_mp";
    weapons[weapons.size] = "iw5_dlcgun2zm_mp";
    weapons[weapons.size] = "iw5_dlcgun3zm_mp";
    weapons[weapons.size] = "iw5_dlcgun4zm_mp";
    weapons[weapons.size] = "iw5_exominigunzm_mp";
    weapons[weapons.size] = "iw5_blunderbusszm_mp";
    weapons[weapons.size] = "iw5_fusionzm_mp";
    weapons[weapons.size] = "iw5_microwavezm_mp";
    weapons[weapons.size] = "iw5_linegunzm_mp";
    weapons[weapons.size] = "iw5_tridentzm_mp";
    weapons[weapons.size] = "iw5_exocrossbowzm_mp";
    weapons[weapons.size] = "iw5_mahemzm_mp";
    weapons[weapons.size] = "iw5_titan45zm_mp";
    weapons[weapons.size] = "iw5_em1zm_mp";

    return weapons;
}

ezdlc_add_to_printer( dlc )
{
    level endon( "game_ended" );

    for ( attempt = 0; attempt < 600; attempt++ )
    {
        if ( isdefined( level.magicboxweapons ) &&
             isdefined( level.flag ) &&
             isdefined( level.flag["magic_box_init"] ) &&
             level.flag["magic_box_init"] )
        {
            break;
        }
        wait 0.05;
    }

    if ( attempt == 600 )
    {
        println( "DLCWeapons: printer initialization timed out; no weapons added. Shared table/give helper only." );
        return;
    }

    // Prioritize the per-map missing table, then reconcile the full target
    // roster in case native entries were removed or DLC4 assets were gated.
    weapons = common_scripts\utility::array_combine( get_map_weapons( dlc ), get_dlc_roster() );
    added = 0;
    foreach ( weapon in weapons )
    {
        if ( ezdlc_pool_contains( weapon ) )
        {
            continue;
        }

        limit = undefined;
        if ( weapon == "iw5_microwavezm_mp" )
        {
            limit = 1;
        }
        else if ( weapon == "iw5_fusionzm_mp" || weapon == "iw5_linegunzm_mp" ||
                  weapon == "iw5_tridentzm_mp" || weapon == "iw5_dlcgun4zm_mp" )
        {
            limit = 2;
        }

        // Native registration appends "_mp" and builds attachment metadata.
        baseName = getsubstr( weapon, 0, weapon.size - 3 );
        maps\mp\zombies\_wall_buys::addmagicboxweapon(
            baseName, level.ezdlc_models[weapon], getweapondisplayname( weapon ),
            "none", "none", "none", limit );
        added++;

        if ( getdvarint( "scr_zm_dlc_weapons_debug" ) > 0 )
        {
            println( "DLCWeapons: added " + weapon );
        }
    }

    println( "DLCWeapons: " + getdvar( "mapname" ) + " added " + added +
             " weapons; printer pool size " + level.magicboxweapons.size );
}

ezdlc_pool_contains( weapon )
{
    foreach ( entry in level.magicboxweapons )
    {
        if ( ( isdefined( entry["baseName"] ) && entry["baseName"] == weapon ) ||
             ( isdefined( entry["fullName"] ) && getweaponbasename( entry["fullName"] ) == weapon ) ||
             ( isdefined( entry["baseNameNoMP"] ) && entry["baseNameNoMP"] + "_mp" == weapon ) )
        {
            return true;
        }
    }

    return false;
}

give_dlc_weapons_to_player( weaponName )
{
    if ( !isdefined( weaponName ) || !isplayer( self ) || !isalive( self ) || get_map_dlc() == 0 ||
         getdvar( "g_gametype" ) != "zombies" ||
         getdvarint( "scr_zm_dlc_weapons_enabled" ) <= 0 ||
         !isdefined( level.ezdlc_models ) || !isdefined( level.ezdlc_models[weaponName] ) ||
         !isdefined( self.weaponstate ) )
    {
        return false;
    }

    maps\mp\zombies\_wall_buys::givezombieweapon( self, weaponName, 0, 1 );
    self switchtoweapon( weaponName );
    return true;
}

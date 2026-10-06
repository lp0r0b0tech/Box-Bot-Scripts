/*
    Missing regular and DLC multiplayer weapons for Exo Zombies.

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
    All MP weapons, models and native Zombies upgrade camo combinations
    must already be loaded by the installed mod. precacheitem() cannot
    supply missing assets. MP upgrade support is mod-dependent, not a
    claim that these weapons have stock Zombies Mk2-Mk25 variants.
    Native Zombies pickups and upgrade bookkeeping remain in control.

    Uses the regular/DLC MP catalog from the repository's Gun Game script,
    not the Zombies shop roster. One registered representative per weapon
    family is used, not every cosmetic loot variant. MP and zm versions
    already in the printer count as the same family. Wonder weapons,
    grenades and Goliath weapons are not added by this script.

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
    weapons = ezdlc_registered_mp_weapons();
    level.ezdlc_weapons = weapons;
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

    // All four maps target the MP catalog; the runtime pool determines
    // which families are missing, including differences introduced by mods.
    return get_mp_roster();
}

get_dlc_roster()
{
    // Keep the original public helper name available to existing callers.
    return get_mp_roster();
}

get_mp_roster()
{
    weapons = [
        "iw5_ak12_mp", "iw5_arx160_mp", "iw5_bal27_mp", "iw5_hbra3_mp",
        "iw5_himar_mp", "iw5_m182spr_mp", "iw5_asm1_mp", "iw5_hmr9_mp",
        "iw5_kf5_mp", "iw5_mp11_mp", "iw5_sac3_mp", "iw5_sn6_mp",
        "iw5_asaw_mp", "iw5_em1_mp", "iw5_epm3_mp", "iw5_exoxmg_mp",
        "iw5_lsat_mp", "iw5_rhino_mp", "iw5_gm6_mp", "iw5_m990_mp",
        "iw5_mors_mp", "iw5_maul_mp", "iw5_uts19_mp", "iw5_rw1_mp",
        "iw5_titan45_mp", "iw5_vbr_mp", "iw5_pbw_mp", "iw5_maaws_mp",
        "iw5_mahem_mp", "iw5_stingerm7_mp", "iw5_exocrossbow_mp",
        "iw5_microdronelauncher_mp", "iw5_combatknife_mp", "iw5_riotshieldt6_mp",
        "iw5_thor_mp",
        "iw5_dlcgun1_mp", "iw5_dlcgun2_mp", "iw5_dlcgun3_mp", "iw5_dlcgun4_mp",
        "iw5_dlcgun6_mp", "iw5_dlcgun7_mp", "iw5_dlcgun8_mp",
        "iw5_dlcgun13_mp", "iw5_dlcgun18_mp", "iw5_dlcgun23_mp",
        "iw5_dlcgun28_mp", "iw5_dlcgun33_mp", "iw5_dlcgun38_mp"
    ];
    return weapons;
}

ezdlc_registered_mp_weapons()
{
    registered = [];
    representatives = [];
    table = "mp/statstable.csv";
    for ( row = 0; row < tablegetrowcount( table ); row++ )
    {
        name = tablelookupbyrow( table, row, 4 );
        category = tablelookupbyrow( table, row, 2 );
        if ( !isdefined( name ) || name == "" ||
             getsubstr( name, 0, 4 ) != "iw5_" ||
             !isdefined( category ) || !issubstr( category, "weapon_" ) ||
             tablelookupbyrow( table, row, 51 ) != "" ||
             issubstr( name, "zm_mp" ) )
        {
            continue;
        }

        family = maps\mp\_utility::getbaseweaponname( name, 1 );
        registered[name] = true;
        if ( !isdefined( representatives[family] ) )
        {
            representatives[family] = name;
        }
    }

    weapons = [];
    foreach ( candidate in get_mp_roster() )
    {
        family = maps\mp\_utility::getbaseweaponname( candidate, 1 );
        if ( isdefined( registered[candidate] ) )
        {
            weapons[weapons.size] = candidate;
        }
        else if ( isdefined( representatives[family] ) )
        {
            weapons[weapons.size] = representatives[family];
        }
        else
        {
            println( "DLCWeapons: skipping unregistered MP family " + family );
        }
    }

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

    weapons = level.ezdlc_weapons;
    added = 0;
    foreach ( weapon in weapons )
    {
        if ( ezdlc_pool_contains( weapon ) )
        {
            continue;
        }

        // Native registration appends "_mp" and builds attachment metadata.
        baseName = getsubstr( weapon, 0, weapon.size - 3 );
        maps\mp\zombies\_wall_buys::addmagicboxweapon(
            baseName, level.ezdlc_models[weapon], getweapondisplayname( weapon ),
            "none", "none", "none", undefined );
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
    family = ezdlc_weapon_family( weapon );
    foreach ( entry in level.magicboxweapons )
    {
        if ( ( isdefined( entry["baseName"] ) && ezdlc_weapon_family( entry["baseName"] ) == family ) ||
             ( isdefined( entry["fullName"] ) && ezdlc_weapon_family( getweaponbasename( entry["fullName"] ) ) == family ) ||
             ( isdefined( entry["baseNameNoMP"] ) && ezdlc_weapon_family( entry["baseNameNoMP"] + "_mp" ) == family ) )
        {
            return true;
        }
    }

    return false;
}

ezdlc_weapon_family( weapon )
{
    if ( weapon.size > 5 && getsubstr( weapon, weapon.size - 5 ) == "zm_mp" )
    {
        weapon = getsubstr( weapon, 0, weapon.size - 5 ) + "_mp";
    }
    return maps\mp\_utility::getbaseweaponname( weapon, 1 );
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

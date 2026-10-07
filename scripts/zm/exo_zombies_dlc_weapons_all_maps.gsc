/*
    Exo Zombies DLC Weapons - All Maps - S1x (Call of Duty: Advanced Warfare)
    Gametype: Exo Zombies ("zclassic" / "zteam" etc.)

    Purpose:
        The native Mystery Box (level.magicboxweapons) only ever contains the
        base Exo Zombies weapon roster plus whatever each specific DLC map's
        own script adds through level.initmagicboxweaponsfunc:
            - the "H2O" map (mp_zombie_h2o) adds Repulsor, DLC Gun II, DLC Gun III,
              Trident, and (on nextgen) DLC Gun IV / Blunderbuss
            - the "Ark" map (mp_zombie_ark) adds Line Gun, Repulsor, DLC Gun II, DLC Gun III
            - the "Burgertown" map (mp_zombie_brg) adds Microwave
            - the "Lab" map (mp_zombie_lab) adds nothing extra (base roster only)
        So a weapon that is "native" to one DLC map's box (e.g. the Line Gun on
        Ark) simply never appears in the box on any other map. This script
        makes every one of those per-map native box weapons available in the
        box on every Exo Zombies map, using the same native
        maps\mp\zombies\_wall_buys::addmagicboxweapon() call and the same
        display model / display string / forceSelect arguments each original
        map's own script uses, so the entries behave identically to a weapon
        that map always had.

        This only touches the Mystery Box pool (level.magicboxweapons), which
        is pure data (no Radiant/world placement needed) and is already
        populated this same way by every DLC map's own script. It does NOT
        attempt to add the physical wall-buy-only DLC weapons (ARX-160, MP11,
        HBRa3, HMR9, Maul, M182 SPR, UTS-19, Titan 45, Exo Minigun, the 4 DLC
        Gun slots used as wall buys, etc.) -- those are tied to a Radiant
        trigger + world model physically placed in each map's geometry and
        cannot be added by a loose script.

    Install (s1x):
        Place this file at:
            s1x > data > scripts > zm > exo_zombies_dlc_weapons_all_maps.gsc
        The gametype guard below disables it automatically outside Exo
        Zombies, and it is a no-op on any map that already natively has a
        given weapon in its box.
*/

main()
{
    println( "[EZDW] main loaded." );
    init();
}


init()
{
    if ( isdefined( level.ezdw_started ) )
    {
        return;
    }

    level.ezdw_started = 1;
    level thread ezdw_start();
}


/*
    Mirrors the defer/guard pattern already used by
    exo_zombies_teambot_max.gsc and s1x_exo_zombies_wonder_shop.gsc: wait a
    tick, bail outside Exo Zombies, then poll until the native
    maps\mp\zombies\_wall_buys::init() has finished populating
    level.magicboxweapons (and, on DLC maps, running that map's own
    level.initmagicboxweaponsfunc) before touching it. That native routine
    runs synchronously with no wait statements, so the instant
    level.magicboxweapons is defined, every map-specific addition it was
    going to make has already happened.
*/
ezdw_start()
{
    level endon( "game_ended" );

    wait 0.05;

    if ( getdvar( "g_gametype" ) != "zombies" )
    {
        println( "[EZDW] Disabled outside Exo Zombies." );
        return;
    }

    for ( attempt = 0; attempt < 600; attempt++ )
    {
        if ( isdefined( level.magicboxweapons ) && isdefined( level.weaponnamemap ) )
        {
            break;
        }

        wait 0.05;
    }

    if ( !isdefined( level.magicboxweapons ) || !isdefined( level.weaponnamemap ) )
    {
        println( "[EZDW] ERROR: Magic box initialization timed out." );
        return;
    }

    ezdw_add_missing_weapons();

    println( "[EZDW] Exo Zombies DLC weapons (all maps) applied on " + getdvar( "mapname" ) );
}


/*
    Every known per-map-exclusive native magic box weapon, with the exact
    display model / display string / attachment / forceSelect arguments the
    owning map's own script passes to addmagicboxweapon(). Skips any weapon
    already present (i.e. the current map is the one that natively owns it).
*/
ezdw_add_missing_weapons()
{
    // limit (7th arg) matches each owning map's own addmagicboxweapon() call
    // exactly; omitted entirely (left undefined) where the owning map also
    // omits it.
    ezdw_add_if_missing( "repulsor_zombie", "dlc3_repulsor_device_01_holo", &"ZOMBIE_DLC3_REPULSOR", "none", "none", "none", 2 );
    ezdw_add_if_missing( "iw5_dlcgun2zm", "npc_lmg_shotgun_base_static_holo", &"ZOMBIE_WEAPONDLC2_GUN", "none", "none", "none" );
    ezdw_add_if_missing( "iw5_dlcgun3zm", "npc_m1_irons_base_static_holo", &"ZOMBIE_WEAPONDLC3_GUN", "none", "none", "none" );
    ezdw_add_if_missing( "iw5_linegunzm", "npc_zom_line_gun_holo", &"ZOMBIE_WEAPON_LINEGUN_PICKUP", "none", "none", "none", 2 );
    ezdw_add_if_missing( "iw5_microwavezm", "dlc_npc_microwave_gun_holo", &"ZOMBIES_MWG", "none", "none", "none", 1 );
    ezdw_add_if_missing( "iw5_tridentzm", "npc_zom_trident_base_holo", &"ZOMBIE_WEAPON_TRIDENT_PICKUP", "none", "none", "none", 2 );
    ezdw_add_if_missing( "iw5_dlcgun4zm", "npc_blunderbuss_base_holo", &"ZOMBIE_WEAPONDLC4_GUN", "none", "none", "none", 2 );
}


ezdw_add_if_missing( baseNameNoMP, displayModel, displayString, attachment1, attachment2, attachment3, limit )
{
    foreach ( entry in level.magicboxweapons )
    {
        if ( isdefined( entry["baseNameNoMP"] ) && entry["baseNameNoMP"] == baseNameNoMP )
        {
            return;
        }
    }

    maps\mp\zombies\_wall_buys::addmagicboxweapon( baseNameNoMP, displayModel, displayString, attachment1, attachment2, attachment3, limit );

    println( "[EZDW] Added " + baseNameNoMP + " to this map's magic box." );
}

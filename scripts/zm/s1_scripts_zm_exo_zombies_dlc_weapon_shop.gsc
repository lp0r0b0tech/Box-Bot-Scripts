/*
    Exo Zombies base DLC weapon shop for S1x v0.0.5

    Place this file at:
        s1/scripts/zm/exo_zombies_dlc_weapon_shop.gsc

    Purpose:
        - Give players a self-contained points shop that sells every base
          Exo Zombies DLC weapon (the same roster used by the Mk2-Mk25
          damage system), without requiring any map-specific trigger or
          Radiant placement.
        - Every purchase costs a flat 1000 points, deducted from
          self.score, and the chosen weapon/attachment set is handed to
          the player immediately.

    Controls (per player, once connected and spawned):
        Hold  [Aim] + tap [Melee]  to open the shop.
        Tap   [Attack]  to move to the next weapon in the list.
        Tap   [Melee]   to move to the previous weapon in the list.
        Tap   [Use]     to purchase the highlighted weapon for 1000 points.
        Tap   [Frag]    to close the shop without buying.

    Toggles:
        set scr_zm_dlc_shop_enabled 1
        set scr_zm_dlc_shop_debug   0
*/

#define DLCWS_DEFAULT_ENABLED        1
#define DLCWS_DEFAULT_DEBUG          0

#define DLCWS_WEAPON_COST            1000
#define DLCWS_POLL_INTERVAL          0.05
#define DLCWS_IDLE_TIMEOUT_SECONDS   20

main()
{
    dlcws_init();
}

init()
{
    dlcws_init();
}

dlcws_init()
{
    if ( isdefined( level.dlcwsInitStarted ) && level.dlcwsInitStarted )
    {
        return;
    }

    level.dlcwsInitStarted = true;

    dlcws_init_dvars();
    dlcws_build_weapon_list();
    dlcws_precache_weapon_list();

    level thread dlcws_watch_players();

    println( "DLCWeaponShop: initialized." );
}

dlcws_init_dvars()
{
    setdvarifuninitialized( "scr_zm_dlc_shop_enabled", DLCWS_DEFAULT_ENABLED );
    setdvarifuninitialized( "scr_zm_dlc_shop_debug", DLCWS_DEFAULT_DEBUG );
}

/*
    Same base Exo Zombies weapon roster used by the Mk2-Mk25 damage
    system, minus melee / knife / last-stand entries which are not
    sold in the shop.
*/
dlcws_build_weapon_list()
{
    level.dlcws_weapons = [];

    dlcws_add_weapon( "iw5_rw1zm_mp", "RW1" );
    dlcws_add_weapon( "iw5_vbrzm_mp", "VBR" );
    dlcws_add_weapon( "iw5_gm6zm_mp", "GM6" );

    dlcws_add_weapon( "iw5_rhinozm_mp", "Rhino" );
    dlcws_add_weapon( "iw5_lsatzm_mp", "LSAT" );
    dlcws_add_weapon( "iw5_asawzm_mp", "ASAW" );

    dlcws_add_weapon( "iw5_ak12zm_mp", "AK12" );
    dlcws_add_weapon( "iw5_bal27zm_mp", "BAL-27" );
    dlcws_add_weapon( "iw5_himarzm_mp", "Himar" );
    dlcws_add_weapon( "iw5_arx160zm_mp", "ARX-160" );
    dlcws_add_weapon( "iw5_hbra3zm_mp", "HBRa3" );
    dlcws_add_weapon( "iw5_m182sprzm_mp", "M182 SPR" );

    dlcws_add_weapon( "iw5_mp11zm_mp", "MP11" );
    dlcws_add_weapon( "iw5_asm1zm_mp", "ASM1" );
    dlcws_add_weapon( "iw5_sn6zm_mp", "SN6" );
    dlcws_add_weapon( "iw5_sac3zm_mp", "SAC3" );
    dlcws_add_weapon( "iw5_hmr9zm_mp", "HMR9" );

    dlcws_add_weapon( "iw5_maulzm_mp", "Maul" );
    dlcws_add_weapon( "iw5_uts19zm_mp", "UTS-19" );

    dlcws_add_weapon( "iw5_em1zm_mp", "EM1" );

    dlcws_add_weapon( "iw5_titan45zm_mp", "Titan 45" );

    dlcws_add_weapon( "iw5_exocrossbowzm_mp", "Exo Crossbow" );
    dlcws_add_weapon( "iw5_mahemzm_mp", "MAHEM" );

    dlcws_add_weapon( "iw5_fusionzm_mp", "CEL-3 Cauterizer" );
    dlcws_add_weapon( "iw5_microwavezm_mp", "Microwave" );
    dlcws_add_weapon( "iw5_linegunzm_mp", "Line Gun" );
    dlcws_add_weapon( "iw5_tridentzm_mp", "Trident" );

    dlcws_add_weapon( "iw5_dlcgun1zm_mp", "DLC Weapon I" );
    dlcws_add_weapon( "iw5_dlcgun2zm_mp", "DLC Weapon II" );
    dlcws_add_weapon( "iw5_dlcgun3zm_mp", "DLC Weapon III" );
    dlcws_add_weapon( "iw5_dlcgun4zm_mp", "DLC Weapon IV" );

    dlcws_add_weapon( "iw5_exominigunzm_mp", "Exo Minigun" );
    dlcws_add_weapon( "iw5_blunderbusszm_mp", "Blunderbuss" );

    dlcws_add_weapon( "iw5_dlcgun13_mp", "1911" );
    dlcws_add_weapon( "iw5_dlcgun1_mp", "AE4" );
    dlcws_add_weapon( "iw5_dlcgun7loot0_mp", "AK-47" );
    dlcws_add_weapon( "iw5_ak12_mp", "AK-12" );
    dlcws_add_weapon( "iw5_hmr9_mp", "HMR9" );
    dlcws_add_weapon( "iw5_arx160_mp", "ARX-160" );
    dlcws_add_weapon( "iw5_asaw_mp", "ASAW" );
    dlcws_add_weapon( "iw5_titan45_mp", "Titan 45" );
    dlcws_add_weapon( "iw5_dlcgun4_mp", "Blunderbuss" );
    dlcws_add_weapon( "iw5_pbw_mp", "PBW" );
    dlcws_add_weapon( "iw5_vbr_mp", "VBR" );
    dlcws_add_weapon( "iw5_uts19_mp", "UTS-19" );
    dlcws_add_weapon( "iw5_maul_mp", "Maul" );
    dlcws_add_weapon( "iw5_dlcgun8loot0_mp", "CEL-3 Cauterizer" );
    dlcws_add_weapon( "iw5_combatknife_mp", "Combat Knife" );
    dlcws_add_weapon( "iw5_exocrossbow_mp", "Crossbow" );
    dlcws_add_weapon( "iw5_em1_mp", "EM1" );
    dlcws_add_weapon( "iw5_epm3_mp", "EPM3" );
    dlcws_add_weapon( "iw5_hbra3_mp", "HBRa3" );
    dlcws_add_weapon( "iw5_riotshieldt6_mp", "Riot Shield" );
    dlcws_add_weapon( "iw5_himar_mp", "Himar" );
    dlcws_add_weapon( "iw5_kf5_mp", "KF5" );
    dlcws_add_weapon( "iw5_dlcgun33_mp", "Lever Action" );
    dlcws_add_weapon( "iw5_gm6_mp", "GM6" );
    dlcws_add_weapon( "iw5_dlcgun23_mp", "M1 Garand" );
    dlcws_add_weapon( "iw5_dlcgun3_mp", "M1 Irons" );
    dlcws_add_weapon( "iw5_dlcgun8_mp", "DLC Weapon 8" );
    dlcws_add_weapon( "iw5_maaws_mp", "MAAWS" );
    dlcws_add_weapon( "iw5_mahem_mp", "MAHEM" );
    dlcws_add_weapon( "iw5_microdronelauncher_mp", "Micro Drone Launcher" );
    dlcws_add_weapon( "iw5_m990_mp", "M990" );
    dlcws_add_weapon( "iw5_mp11_mp", "MP11" );
    dlcws_add_weapon( "iw5_dlcgun18_mp", "MP40" );
    dlcws_add_weapon( "iw5_dlcgun2_mp", "Ohm" );
    dlcws_add_weapon( "iw5_lsat_mp", "LSAT" );
    dlcws_add_weapon( "iw5_dlcgun38_mp", "Repulsor" );
    dlcws_add_weapon( "iw5_rhino_mp", "Rhino" );
    dlcws_add_weapon( "iw5_dlcgun5loot0_mp", "SAC3 Single-Hand" );
    dlcws_add_weapon( "iw5_sn6_mp", "SN6" );
    dlcws_add_weapon( "iw5_dlcgun6_mp", "STG-44" );
    dlcws_add_weapon( "iw5_dlcgun7_mp", "DLC Weapon 7" );
    dlcws_add_weapon( "iw5_stingerm7_mp", "Stinger M7" );
    dlcws_add_weapon( "iw5_dlcgun28_mp", "Sten" );
    dlcws_add_weapon( "iw5_asm1_mp", "ASM1" );
    dlcws_add_weapon( "iw5_m182spr_mp", "M182 SPR" );
    dlcws_add_weapon( "iw5_mors_mp", "MORS" );
    dlcws_add_weapon( "iw5_bal27_mp", "BAL-27" );
    dlcws_add_weapon( "iw5_rw1_mp", "RW1" );
    dlcws_add_weapon( "iw5_exoxmg_mp", "XMG" );
    dlcws_add_weapon( "iw5_thor_mp", "Thor" );
}

dlcws_precache_weapon_list()
{
    foreach ( entry in level.dlcws_weapons )
    {
        precacheitem( entry.weaponName );
    }
}

dlcws_add_weapon( weaponName, displayName )
{
    entry = spawnstruct();
    entry.weaponName = weaponName;
    entry.displayName = displayName;

    level.dlcws_weapons[ level.dlcws_weapons.size ] = entry;
}

dlcws_watch_players()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread dlcws_player_init();
    }
}

dlcws_player_init()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "spawned_player" );
        self thread dlcws_player_monitor();
    }
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

    for ( ;; )
    {
        wait DLCWS_POLL_INTERVAL;

        if ( getdvarint( "scr_zm_dlc_shop_enabled" ) <= 0 )
        {
            continue;
        }

        if ( !isdefined( self.dlcws_shopOpen ) )
        {
            self.dlcws_shopOpen = false;
        }

        if ( self.dlcws_shopOpen )
        {
            continue;
        }

        if ( self adsbuttonpressed() && self meleebuttonpressed() )
        {
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

    if ( isdefined( self.dlcws_shopOpen ) && self.dlcws_shopOpen )
    {
        return;
    }

    self.dlcws_shopOpen = true;
    self.dlcws_shopIndex = 0;

    self freezecontrols( true );

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
    self.dlcws_hint settext( "[Attack] Next   [Melee] Prev   [Use] Buy (" + DLCWS_WEAPON_COST + ")   [Frag] Cancel" );

    dlcws_refresh_hud( self );

    idleStart = gettime();

    while ( self.dlcws_shopOpen )
    {
        wait DLCWS_POLL_INTERVAL;

        if ( ( gettime() - idleStart ) >= ( DLCWS_IDLE_TIMEOUT_SECONDS * 1000 ) )
        {
            break;
        }

        if ( self fragbuttonpressed() )
        {
            break;
        }

        if ( self attackbuttonpressed() )
        {
            idleStart = gettime();
            self.dlcws_shopIndex = ( self.dlcws_shopIndex + 1 ) % level.dlcws_weapons.size;
            dlcws_refresh_hud( self );
            dlcws_wait_for_release( self, "attack" );
        }
        else if ( self meleebuttonpressed() )
        {
            idleStart = gettime();
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
            idleStart = gettime();
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
    if ( !isdefined( player.dlcws_hud ) )
    {
        return;
    }

    entry = level.dlcws_weapons[ player.dlcws_shopIndex ];

    player.dlcws_hud settext( "DLC Weapon Shop - " + entry.displayName + " (" + DLCWS_WEAPON_COST + " pts)" );
}

dlcws_try_purchase( player )
{
    entry = level.dlcws_weapons[ player.dlcws_shopIndex ];

    if ( !isdefined( player.score ) )
    {
        player.score = 0;
    }

    if ( player.score < DLCWS_WEAPON_COST )
    {
        player iprintlnbold( "Not enough points for the " + entry.displayName + "." );
        return;
    }

    player.score -= DLCWS_WEAPON_COST;

    player giveweapon( entry.weaponName );
    player switchtoweapon( entry.weaponName );

    player iprintln( "Purchased " + entry.displayName + " for " + DLCWS_WEAPON_COST + " points." );

    if ( getdvarint( "scr_zm_dlc_shop_debug" ) > 0 )
    {
        println( "DLCWeaponShop: " + player.name + " bought " + entry.weaponName );
    }

    dlcws_close_shop( player );
}

dlcws_close_shop( player )
{
    if ( !isdefined( player ) )
    {
        return;
    }

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

    player freezecontrols( false );
}
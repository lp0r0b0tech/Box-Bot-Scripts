/*
    Exo Zombies DLC-exclusive weapon shop for S1x v0.0.4

    Place this file at:
        s1/scripts/zm/exo_zombies_dlc_weapon_shop.gsc

    Purpose:
        - Give players a self-contained points shop that sells only the
          Exo Zombies DLC-exclusive weapons (the wonder-weapon-style guns
          added by the Exo Zombies map packs — not the standard Advanced
          Warfare multiplayer weapons also usable in zombies), without
          requiring any map-specific trigger or Radiant placement.
        - Every purchase costs a flat 1000 points, deducted from
          self.score, and the chosen weapon/attachment set is handed to
          the player immediately.

    Controls (per player, once connected and spawned):
        Hold  [ADS] + [Melee] together for DLCWS_OPEN_HOLD_SECONDS to open the shop.
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
#define DLCWS_OPEN_HOLD_SECONDS      1.0
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

    level thread dlcws_watch_players();

    println( "DLCWeaponShop: initialized." );
}

dlcws_init_dvars()
{
    setdvarifuninitialized( "scr_zm_dlc_shop_enabled", DLCWS_DEFAULT_ENABLED );
    setdvarifuninitialized( "scr_zm_dlc_shop_debug", DLCWS_DEFAULT_DEBUG );
}

/*
    Only the Exo Zombies DLC-exclusive weapons from the Mk2-Mk25 damage
    system roster. Standard Advanced Warfare multiplayer weapons (AK12,
    BAL-27, ASM1, etc.) are intentionally excluded — they are not DLC
    weapons, just base-game guns also usable in zombies.
*/
dlcws_build_weapon_list()
{
    level.dlcws_weapons = [];

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
    Watches for the open/close hold gesture, then runs the shop menu
    loop until the player buys, cancels, idles out, or disconnects.
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

        if ( !self adsbuttonpressed() || !self meleebuttonpressed() )
        {
            continue;
        }

        holdStart = gettime();

        while ( self adsbuttonpressed() && self meleebuttonpressed() )
        {
            if ( ( gettime() - holdStart ) >= int( DLCWS_OPEN_HOLD_SECONDS * 1000 ) )
            {
                self thread dlcws_open_shop();
                break;
            }

            wait DLCWS_POLL_INTERVAL;
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

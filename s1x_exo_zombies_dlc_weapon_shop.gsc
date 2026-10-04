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

    Weapon precaching - REQUIRED, one line per map:
        precacheitem() can only legally run during the engine's
        precache phase (inside a precache() function called before
        players connect). Calling it at runtime from this script's
        main()/init() throws a script error and breaks the entire shop
        for every player, so this file no longer attempts it.

        Instead, add this single line inside every map's own precache()
        function (e.g. maps/zm/<mapname>.gsc or the map's zombies mod
        precache() callback):

            maps\zm\exo_zombies_dlc_weapon_shop::precache();

        If that line is missing from a map's precache(), purchases of
        weapons not already used elsewhere on that map will fail and
        automatically refund the player with an on-screen message
        naming the weapon that needs to be added.
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

/*
    Call this from every map's own precache() function, e.g.:
        maps\zm\exo_zombies_dlc_weapon_shop::precache();

    This is the only place precacheitem() is legal - it must run
    during the engine's precache phase, before players connect.
*/
precache()
{
    dlcws_build_weapon_list();

    for ( i = 0; i < level.dlcws_weapons.size; i++ )
    {
        precacheitem( level.dlcws_weapons[i].weaponName );
    }
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
    Exo Zombies DLC-exclusive weapon roster, using the exact DLC gun IDs
    (plus Microwave, Line Gun, and Trident wonder weapons alongside them).
*/
dlcws_build_weapon_list()
{
    level.dlcws_weapons = [];

    dlcws_add_weapon( "iw5_dlcgun1_mp", "AE4" );
    dlcws_add_weapon( "iw5_dlcgun2_mp", "Ohm" );
    dlcws_add_weapon( "iw5_dlcgun3_mp", "M1 Irons" );
    dlcws_add_weapon( "iw5_dlcgun4_mp", "Blunderbuss" );
    dlcws_add_weapon( "iw5_dlcgun6_mp", "STG-44" );
    dlcws_add_weapon( "iw5_dlcgun6loot5_mp", "SVO" );
    dlcws_add_weapon( "iw5_dlcgun7loot0_mp", "AK-47" );
    dlcws_add_weapon( "iw5_dlcgun7loot6_mp", "M16" );
    dlcws_add_weapon( "iw5_dlcgun8loot1_mp", "CEL-3 Cauterizer" );
    dlcws_add_weapon( "iw5_dlcgun13_mp", "1911" );
    dlcws_add_weapon( "iw5_dlcgun18_mp", "MP40" );
    dlcws_add_weapon( "iw5_dlcgun23_mp", "M1 Garand" );
    dlcws_add_weapon( "iw5_dlcgun28_mp", "Sten" );
    dlcws_add_weapon( "iw5_dlcgun33_mp", "Lever Action" );
    dlcws_add_weapon( "iw5_dlcgun38_mp", "Repulsor" );

    dlcws_add_weapon( "iw5_microwavezm_mp", "Microwave" );
    dlcws_add_weapon( "iw5_linegunzm_mp", "Line Gun" );
    dlcws_add_weapon( "iw5_tridentzm_mp", "Trident" );
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

    /*
        Zombies players can only hold a limited number of weapons.
        If their slots are already full, giveweapon() silently does
        nothing, so clear every weapon slot first to guarantee room
        for the purchased weapon.
    */
    player takeallweapons();

    player giveweapon( entry.weaponName );
    player givemaxammo( entry.weaponName );
    player switchtoweapon( entry.weaponName );

    if ( getdvarint( "scr_zm_dlc_shop_debug" ) > 0 )
    {
        println( "DLCWeaponShop: " + player.name + " bought " + entry.weaponName + " - hasweapon=" + player hasweapon( entry.weaponName ) );
    }

    if ( !( player hasweapon( entry.weaponName ) ) )
    {
        /*
            giveweapon() failed (most likely because the weapon asset
            is not loaded on this map's zone). Refund the points so the
            player is not charged for nothing, and surface the problem.
        */
        player.score += DLCWS_WEAPON_COST;
        player iprintlnbold( "Failed to give " + entry.displayName + " - refunded. Ask the map owner to precache this weapon." );
        dlcws_close_shop( player );
        return;
    }

    player iprintln( "Purchased " + entry.displayName + " for " + DLCWS_WEAPON_COST + " points." );

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

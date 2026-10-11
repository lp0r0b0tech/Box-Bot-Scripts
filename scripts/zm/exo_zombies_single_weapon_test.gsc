/*
    Single-weapon Exo Zombies diagnostic: multiplayer MORS (iw5_mors_mp).

    Install in the same auto-loaded scripts directory as a working Zombies
    script on your client. Run ONLY this diagnostic in a private test match.
    Temporarily move other custom scripts out of the loader directory.

    Toggle (set before loading the map):
        set scr_zm_single_weapon_test_enabled 1

    Grants once per human player connection, after the first live spawn.
    The native Zombies giver may replace the equipped primary if slots are full.
    No precaching, asset loading, printer changes or upgrade hooks are used.
    Assets must already be loaded; missing assets can cause errors or crashes.
    Do not upgrade the test weapon. Ownership/equip logs do not prove firing,
    animation or upgrade compatibility. This is not a multiplayer asset pack.

    Console stages: MAIN -> INIT -> READY -> PLAYER -> GIVE_BEGIN ->
    GIVE_RETURNED -> OWNED (or NOT_OWNED) -> EQUIPPED (or NOT_EQUIPPED).
    A missing marker identifies the last completed stage, not the root cause.
*/

#define EZWT_WEAPON "iw5_mors_mp"

main()
{
    println( "[EZWT] MAIN: single-weapon test loaded." );
    init();
}

init()
{
    println( "[EZWT] INIT: entered." );
    if ( isdefined( level.ezwt_started ) )
    {
        println( "[EZWT] INIT: already started; skipping duplicate." );
        return;
    }

    level.ezwt_started = true;
    setdvarifuninitialized( "scr_zm_single_weapon_test_enabled", 1 );
    level thread ezwt_start();
}

ezwt_start()
{
    level endon( "game_ended" );
    wait 0.05;

    map = tolower( getdvar( "mapname" ) );
    if ( getdvar( "g_gametype" ) != "zombies" ||
         ( map != "mp_zombie_lab" && map != "mp_zombie_brg" &&
           map != "mp_zombie_ark" && map != "mp_zombie_h2o" ) )
    {
        println( "[EZWT] SKIP: unsupported mode/map: " + getdvar( "g_gametype" ) + "/" + map );
        return;
    }

    if ( getdvarint( "scr_zm_single_weapon_test_enabled" ) <= 0 )
    {
        println( "[EZWT] DISABLED: scr_zm_single_weapon_test_enabled is 0." );
        return;
    }

    println( "[EZWT] READY: map=" + map + "; weapon=" + EZWT_WEAPON + "; waiting for humans." );
    for ( ;; )
    {
        players = getentarray( "player", "classname" );
        foreach ( player in players )
        {
            if ( !isplayer( player ) || isbot( player ) || isdefined( player.ezwt_started ) )
                continue;

            player.ezwt_started = true;
            player thread ezwt_test_player();
        }
        wait 0.25;
    }
}

ezwt_test_player()
{
    self endon( "disconnect" );
    level endon( "game_ended" );
    println( "[EZWT] PLAYER: " + self.name + "; waiting for live spawn and Zombies weapon state." );

    for ( attempt = 0; attempt < 480; attempt++ )
    {
        if ( ezwt_player_ready() )
        {
            wait 2;
            if ( ezwt_player_ready() )
                break;
        }
        wait 0.25;
    }

    if ( !ezwt_player_ready() || attempt == 480 )
    {
        println( "[EZWT] TIMEOUT: player did not become ready: " + self.name );
        return;
    }

    self iprintlnbold( "^3EZWT: testing multiplayer MORS. Check console." );
    println( "[EZWT] GIVE_BEGIN: " + self.name + "; " + EZWT_WEAPON );
    maps\mp\zombies\_wall_buys::givezombieweapon( self, EZWT_WEAPON, 0, 1 );
    println( "[EZWT] GIVE_RETURNED: native giver returned for " + self.name );

    if ( !self hasweapon( EZWT_WEAPON ) )
    {
        println( "[EZWT] NOT_OWNED: MORS absent from inventory for " + self.name );
        self iprintlnbold( "^1EZWT: MORS not owned. Send console output." );
        return;
    }

    println( "[EZWT] OWNED: MORS present in inventory for " + self.name );
    wait 0.5;
    current = self getcurrentweapon();
    if ( current == EZWT_WEAPON )
    {
        println( "[EZWT] EQUIPPED: MORS selected for " + self.name );
        self iprintlnbold( "^2EZWT: MORS owned and selected. Test firing; do not upgrade." );
    }
    else
    {
        println( "[EZWT] NOT_EQUIPPED: " + self.name + "; current=" + current );
        self iprintlnbold( "^3EZWT: MORS owned but not selected. Check console." );
    }
}

ezwt_player_ready()
{
    return isalive( self ) && isdefined( self.sessionstate ) &&
        self.sessionstate == "playing" && isdefined( self.weaponstate ) &&
        !( isdefined( self.inlaststand ) && self.inlaststand );
}

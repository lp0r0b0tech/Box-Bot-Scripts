/*
    Exo Zombies riot shield support

    Stock Zombies never starts the code that lets a player plant the riot
    shield on the ground: _weapons.gsc only calls maps\mp\_riotshield::init()
    and watchriotshielduse() outside of Zombies. This script starts both on
    every zombies map, so iw5_riotshieldt6_mp from the weapon shop can be
    planted as a free-standing barricade the same way as in multiplayer, and
    picked up again.

    The planted shield needs assets that Zombies does not load. The
    mods/exo_weapons_all pack supplies them: the deploy, destroyed, shot and
    melee animations and the smoke, light and stun effects. Every zombies
    map already contains the riot_shield_collision brush the shield uses.

    It does nothing when:
        - mods/exo_weapons_all is not loaded (the shield weapon is missing),
        - the map already starts the shield code,
        - the map does not contain exactly one riot_shield_collision brush.

    Stock multiplayer behaviour that comes with it: while a player carries a
    shield, zombies cannot melee that player from the shielded side (front
    while it is held, back while it is stowed).

    Nothing in Zombies sets the riotshield_* dvars the planted shield reads
    (health, damage scales, cleanup time). Unset they read 0, which would
    destroy the shield on its first hit, so every one that is still 0 gets
    a default here. Set the dvar before the map loads to change it.

    Toggles:
        set scr_zm_riotshield_enabled 1

    The first occurrence of every engine event the planting relies on is
    written to s1/exo_zombies_support.log.
*/

#define RSS_SHIELD_NAME         "iw5_riotshieldt6_mp"
#define RSS_COLLISION_NAME      "riot_shield_collision"
#define RSS_LOG_FILE            "s1/exo_zombies_support.log"
#define RSS_DEFAULT_HEALTH      1000
#define RSS_DEFAULT_CLEANUP     4

main()
{
}

init()
{
    if ( getdvar( "g_gametype" ) != "zombies" ||
         isdefined( level.rss_startHooked ) )
    {
        return;
    }

    // Wrap the native hook so this runs right after the map's own weapon init.
    level.rss_previousStartFunc = level.onstartgametypelevelfunc;
    level.onstartgametypelevelfunc = ::rss_start_gametype;
    level.rss_startHooked = true;
}

rss_start_gametype()
{
    if ( isdefined( level.rss_previousStartFunc ) )
    {
        [[ level.rss_previousStartFunc ]]();
    }

    // A separate thread keeps a script error here from stopping game start.
    level thread rss_setup();
}

rss_setup()
{
    setdvarifuninitialized( "scr_zm_riotshield_enabled", 1 );

    if ( isdefined( level.rss ) )
    {
        return;
    }

    if ( getdvarint( "scr_zm_riotshield_enabled" ) <= 0 )
    {
        return;
    }

    if ( isdefined( level.riot_shield_names ) )
    {
        rss_log( "the map already starts the riot shield code; support stays off." );
        return;
    }

    if ( !rss_weapon_registered( RSS_SHIELD_NAME ) )
    {
        rss_log( RSS_SHIELD_NAME + " is not registered (mods/exo_weapons_all is not loaded); support stays off." );
        return;
    }

    // The stock init looks the brush up with getent(), which errors on a duplicate.
    collision = getentarray( RSS_COLLISION_NAME, "targetname" );
    if ( collision.size != 1 )
    {
        rss_log( "found " + collision.size + " " + RSS_COLLISION_NAME + " brushes instead of 1; support stays off." );
        return;
    }

    level.rss = spawnstruct();
    level.rss.seen = [];

    // The stock init precaches animations and loads effects, so it has to run
    // here, before this thread waits for anything.
    rss_log( "calling the stock riot shield init" );
    maps\mp\_riotshield::init();
    rss_log( "stock init finished" );

    rss_default_dvar( "riotshield_deployed_health", RSS_DEFAULT_HEALTH );
    rss_default_dvar( "riotshield_melee_damage_scale", 1 );
    rss_default_dvar( "riotshield_bullet_damage_scale", 1 );
    rss_default_dvar( "riotshield_explosive_damage_scale", 1 );
    rss_default_dvar( "riotshield_projectile_damage_scale", 1 );
    rss_default_dvar( "riotshield_destroyed_cleanup_time", RSS_DEFAULT_CLEANUP );

    level thread rss_watch_players();
    level thread rss_log_planted();
    rss_log( "ready" );
}

rss_weapon_registered( weaponName )
{
    baseName = getweaponbasename( weaponName );
    return isdefined( baseName ) && baseName == weaponName;
}

rss_default_dvar( dvarName, value )
{
    if ( getdvarfloat( dvarName ) <= 0 )
    {
        setdvar( dvarName, value );
    }
}

rss_log( text )
{
    writefile( RSS_LOG_FILE,
        "[riotshield] map=" + getdvar( "mapname" ) + " " + text + "\n", 1 );
}

rss_log_once( text )
{
    if ( isdefined( level.rss.seen[ text ] ) )
    {
        return;
    }

    level.rss.seen[ text ] = true;
    rss_log( text );
}

rss_watch_players()
{
    level endon( "game_ended" );

    foreach ( player in getentarray( "player", "classname" ) )
    {
        player thread rss_player_loop();
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread rss_player_loop();
    }
}

rss_player_loop()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    if ( isdefined( self.rss_started ) )
    {
        return;
    }

    self.rss_started = true;

    // The stock watcher ends on death and on faux_spawn, so it is started
    // again after every spawn, as multiplayer does.
    for ( ;; )
    {
        if ( isalive( self ) && self.sessionstate == "playing" )
        {
            self rss_start_watch();
        }

        common_scripts\utility::waittill_any( "spawned_player", "faux_spawn" );
        waitframe();
    }
}

rss_start_watch()
{
    // A second watcher would plant two shields per use.
    if ( isdefined( self.rss_watching ) )
    {
        return;
    }

    self.rss_watching = true;
    self thread rss_watch_end();
    self thread maps\mp\_riotshield::watchriotshielduse();
    self thread rss_log_event( "raise_riotshield" );
    self thread rss_log_event( "startdeploy_riotshield" );
    self thread rss_log_event( "pickup_riotshield" );
    self thread rss_log_deploy();
    rss_log_once( "watchriotshielduse started" );
}

rss_watch_end()
{
    self endon( "disconnect" );

    // Same events that end the stock watcher.
    common_scripts\utility::waittill_any( "death", "faux_spawn" );
    self.rss_watching = undefined;
}

rss_log_event( eventName )
{
    self endon( "death" );
    self endon( "disconnect" );
    self endon( "faux_spawn" );

    text = "engine event " + eventName;

    while ( !isdefined( level.rss.seen[ text ] ) )
    {
        self waittill( eventName );
        rss_log_once( text );
    }
}

rss_log_deploy()
{
    self endon( "death" );
    self endon( "disconnect" );
    self endon( "faux_spawn" );

    for ( ;; )
    {
        self waittill( "deploy_riotshield", placed );

        state = "refused";
        if ( isdefined( placed ) && placed )
        {
            state = "ok";
        }

        rss_log_once( "engine event deploy_riotshield, placement " + state );
    }
}

rss_log_planted()
{
    level endon( "game_ended" );

    level waittill( "riotshield_planted" );
    rss_log_once( "riotshield_planted: a shield was placed" );
}

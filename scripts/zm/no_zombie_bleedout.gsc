/*
    Exo Zombies / S1x: prevent zombies from dying of old age.
    Install at s1/scripts/zm/no_zombie_bleedout.gsc.

    Disables the native ~240-second lifetime expiry for normal zombies,
    hosts and dogs. Normal damage deaths and stuck-AI cleanup remain enabled.
*/

main()
{
    init();
}

init()
{
    if ( getdvar( "g_gametype" ) != "zombies" )
        return;

    if ( isdefined( level.nzbInitStarted ) )
        return;

    level.nzbInitStarted = true;
    level thread nzbInstall();
}

nzbInstall()
{
    level endon( "game_ended" );

    while ( !isdefined( level.enemyteam ) || !isdefined( level.agentarray ) )
        wait 0.05;

    if ( !isdefined( level.onzombiespawnfuncs ) )
        level.onzombiespawnfuncs = [];

    level.onzombiespawnfuncs[level.onzombiespawnfuncs.size] = ::nzbDisableExpiry;

    foreach ( agent in level.agentarray )
    {
        if ( !isdefined( agent ) || !isalive( agent ) )
            continue;

        if ( isdefined( agent.isactive ) && !agent.isactive )
            continue;

        agent nzbDisableExpiry();
    }

    println( "[NZB] Zombie lifetime expiry disabled; stuck-AI cleanup remains enabled." );
}

nzbDisableExpiry()
{
    if ( !isdefined( self.team ) || self.team != level.enemyteam )
        return;

    if ( !isdefined( self.agent_type ) )
        return;

    if ( self.agent_type != "zombie_generic" &&
         self.agent_type != "zombie_host" &&
         self.agent_type != "zombie_dog" )
        return;

    // Native checkexpiretime() honors this without changing damage or health.
    self.ignoreexpiretime = 1;
}

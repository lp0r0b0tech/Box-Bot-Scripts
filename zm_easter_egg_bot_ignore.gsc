/*
    Exo Zombies easter egg bot exclusion for S1x v0.0.4

    Place this file at:
        s1/scripts/zm/easter_egg_bot_ignore.gsc

    Purpose:
        - Keep bots from counting toward easter egg step player checks.
        - Maintain human-only easter egg player arrays and counts.
        - Mark bots with common ignore flags for map scripts.

    Toggles:
        set scr_zm_ee_ignore_bots 1
        set scr_zm_ee_ignore_bots_debug 0
*/

#define EEBI_DEFAULT_ENABLED                    1
#define EEBI_DEFAULT_DEBUG                      0
#define EEBI_REFRESH_INTERVAL                   0.25

main()
{
    init();
}

init()
{
    if ( isdefined( level.eebiInitStarted ) && level.eebiInitStarted )
    {
        return;
    }

    if ( isdefined( level.eebiInitPending ) && level.eebiInitPending )
    {
        return;
    }

    level.eebiInitPending = true;
    level thread eebiDeferredInit();
}

eebiDeferredInit()
{
    wait EEBI_REFRESH_INTERVAL;

    if ( !eebiIsZombieContext() )
    {
        level.eebiInitPending = false;
        return;
    }

    eebiInitDvars();

    if ( getdvarint( "scr_zm_ee_ignore_bots" ) <= 0 )
    {
        level.eebiInitPending = false;
        return;
    }

    eebiEnsureState();
    eebiRefreshState();

    level thread eebiRefreshLoop();

    level.eebiInitStarted = true;
    level.eebiInitPending = false;
    println( "EEBotIgnore: initialized." );
}

eebiInitDvars()
{
    setdvarifuninitialized( "scr_zm_ee_ignore_bots", EEBI_DEFAULT_ENABLED );
    setdvarifuninitialized( "scr_zm_ee_ignore_bots_debug", EEBI_DEFAULT_DEBUG );
}

eebiRefreshLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( getdvarint( "scr_zm_ee_ignore_bots" ) > 0 )
        {
            eebiRefreshState();
        }

        wait EEBI_REFRESH_INTERVAL;
    }
}

eebiRefreshState()
{
    eebiEnsureState();

    allPlayers = getplayers();
    humanPlayers = [];
    botPlayers = [];
    eligiblePlayers = [];

    if ( !isdefined( allPlayers ) )
    {
        allPlayers = [];
    }

    if ( isdefined( level.eebi.taggedPlayers ) )
    {
        for ( i = 0; i < level.eebi.taggedPlayers.size; i++ )
        {
            previousPlayer = level.eebi.taggedPlayers[i];
            if ( isdefined( previousPlayer ) && !eebiArrayContainsEntity( allPlayers, previousPlayer ) )
            {
                eebiClearPlayerTags( previousPlayer );
            }
        }
    }

    for ( i = 0; i < allPlayers.size; i++ )
    {
        player = allPlayers[i];
        if ( !isdefined( player ) )
        {
            continue;
        }

        isBot = eebiIsBotEntity( player );
        eebiTagPlayer( player, isBot );

        if ( isBot )
        {
            botPlayers[botPlayers.size] = player;
            continue;
        }

        humanPlayers[humanPlayers.size] = player;

        if ( eebiIsPlayerCountable( player ) )
        {
            eligiblePlayers[eligiblePlayers.size] = player;
        }
    }

    level.eebi.allPlayers = allPlayers;
    level.eebi.humanPlayers = humanPlayers;
    level.eebi.botPlayers = botPlayers;
    level.eebi.eligiblePlayers = eligiblePlayers;
    level.eebi.taggedPlayers = allPlayers;

    level.eebi.humanCount = humanPlayers.size;
    level.eebi.botCount = botPlayers.size;
    level.eebi.eligibleCount = eligiblePlayers.size;

    eebiWriteAliases();
    eebiMaybeDebugCounts();
}

eebiEnsureState()
{
    if ( isdefined( level.eebi ) )
    {
        return;
    }

    level.eebi = spawnstruct();
    level.eebi.lastHumanCount = -1;
    level.eebi.lastBotCount = -1;
    level.eebi.lastEligibleCount = -1;
}

eebiWriteAliases()
{
    level.eebiAllPlayers = level.eebi.allPlayers;
    level.eebiHumanPlayers = level.eebi.humanPlayers;
    level.eebiEligiblePlayers = level.eebi.eligiblePlayers;
    level.eebiBotPlayers = level.eebi.botPlayers;

    level.eebiHumanPlayerCount = level.eebi.humanCount;
    level.eebiEligiblePlayerCount = level.eebi.eligibleCount;
    level.eebiBotPlayerCount = level.eebi.botCount;
}

eebiArrayContainsEntity( entities, target )
{
    if ( !isdefined( entities ) || !isdefined( target ) )
    {
        return false;
    }

    for ( i = 0; i < entities.size; i++ )
    {
        if ( isdefined( entities[i] ) && entities[i] == target )
        {
            return true;
        }
    }

    return false;
}

eebiMaybeDebugCounts()
{
    if ( getdvarint( "scr_zm_ee_ignore_bots_debug" ) <= 0 )
    {
        return;
    }

    if ( level.eebi.lastHumanCount == level.eebi.humanCount &&
         level.eebi.lastBotCount == level.eebi.botCount &&
         level.eebi.lastEligibleCount == level.eebi.eligibleCount )
    {
        return;
    }

    level.eebi.lastHumanCount = level.eebi.humanCount;
    level.eebi.lastBotCount = level.eebi.botCount;
    level.eebi.lastEligibleCount = level.eebi.eligibleCount;

    println(
        "EEBotIgnore: humans=" + level.eebi.humanCount +
        " eligible=" + level.eebi.eligibleCount +
        " bots=" + level.eebi.botCount
    );
}

eebiTagPlayer( player, isBot )
{
    if ( !isdefined( player ) )
    {
        return;
    }

    if ( isdefined( player.pers ) )
    {
        player.pers["eebi_is_bot"] = isBot;
        player.pers["eebi_counts_for_easter_egg"] = !isBot;
        player.pers["eebi_ignore_easter_egg"] = isBot;
    }

    player.eebiCountsForEasterEgg = !isBot;
    player.eebiIgnoreEasterEgg = isBot;
    player.eebiIsBot = isBot;
    player.eebiIsRealPlayer = !isBot;
}

eebiClearPlayerTags( player )
{
    if ( !isdefined( player ) )
    {
        return;
    }

    if ( isdefined( player.pers ) )
    {
        player.pers["eebi_is_bot"] = false;
        player.pers["eebi_counts_for_easter_egg"] = false;
        player.pers["eebi_ignore_easter_egg"] = false;
    }

    player.eebiCountsForEasterEgg = false;
    player.eebiIgnoreEasterEgg = false;
    player.eebiIsBot = false;
    player.eebiIsRealPlayer = false;
}

eebiIsPlayerCountable( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( isdefined( player.sessionstate ) )
    {
        sessionState = toLower( player.sessionstate + "" );

        if ( sessionState == "spectator" || sessionState == "intermission" )
        {
            return false;
        }
    }

    if ( isdefined( player.pers ) && isdefined( player.pers["connected"] ) )
    {
        connectedState = toLower( player.pers["connected"] + "" );

        if ( connectedState != "connected" )
        {
            return false;
        }
    }

    return true;
}

eebiIsBotEntity( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( isdefined( player.isBot ) )
    {
        return eebiValueIsTrue( player.isBot );
    }

    if ( isdefined( player.pers ) && isdefined( player.pers["isBot"] ) )
    {
        return eebiValueIsTrue( player.pers["isBot"] );
    }

    if ( isdefined( player.eebiIsBot ) )
    {
        return eebiValueIsTrue( player.eebiIsBot );
    }

    return false;
}

eebiValueIsTrue( value )
{
    if ( !isdefined( value ) )
    {
        return false;
    }

    stringValue = toLower( value + "" );
    return stringValue == "1" || stringValue == "true" || stringValue == "yes" || stringValue == "bot";
}

eebiIsZombieContext()
{
    if ( isdefined( level.zombiemode ) && level.zombiemode )
    {
        return true;
    }

    if ( isdefined( level.zombieMap ) && level.zombieMap )
    {
        return true;
    }

    return eebiIsKnownZombieMap( getdvar( "mapname" ) );
}

eebiIsKnownZombieMap( mapname )
{
    if ( !isdefined( mapname ) )
    {
        return false;
    }

    lowerMap = toLower( mapname + "" );

    if ( ( strlen( lowerMap ) >= 3 && getsubstr( lowerMap, 0, 3 ) == "zm_" ) ||
         ( strlen( lowerMap ) >= 6 && getsubstr( lowerMap, 0, 6 ) == "mp_zm_" ) ||
         ( strlen( lowerMap ) >= 10 && getsubstr( lowerMap, 0, 10 ) == "mp_zombie_" ) )
    {
        return true;
    }

    if ( lowerMap == "mp_zombie_lab" ||
         lowerMap == "mp_zombie_school" ||
         lowerMap == "mp_zombie_carrier" ||
         lowerMap == "mp_zombie_descent" )
    {
        return true;
    }

    return false;
}

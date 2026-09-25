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

    level.eebiInitStarted = true;
    level thread eebiDeferredInit();
}

eebiDeferredInit()
{
    wait EEBI_REFRESH_INTERVAL;

    if ( !eebiIsZombieContext() )
    {
        return;
    }

    eebiInitDvars();

    if ( getdvarint( "scr_zm_ee_ignore_bots" ) <= 0 )
    {
        return;
    }

    eebiEnsureState();
    eebiRefreshState();

    level thread eebiRefreshLoop();
    level thread eebiConnectedMonitor();

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

eebiConnectedMonitor()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );

        if ( isdefined( player ) )
        {
            wait 0.05;
            eebiTagPlayer( player, eebiIsBotEntity( player ) );
            eebiRefreshState();
        }
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

    level.eebi.allPlayers = eebiCloneArray( allPlayers );
    level.eebi.humanPlayers = eebiCloneArray( humanPlayers );
    level.eebi.botPlayers = eebiCloneArray( botPlayers );
    level.eebi.eligiblePlayers = eebiCloneArray( eligiblePlayers );

    level.eebi.humanCount = humanPlayers.size;
    level.eebi.botCount = botPlayers.size;
    level.eebi.eligibleCount = eligiblePlayers.size;

    eebiWriteAliases( allPlayers, humanPlayers, botPlayers, eligiblePlayers );
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

eebiWriteAliases( allPlayers, humanPlayers, botPlayers, eligiblePlayers )
{
    level.eebiAllPlayers = eebiCloneArray( allPlayers );
    level.eebiHumanPlayers = eebiCloneArray( humanPlayers );
    level.eebiEligiblePlayers = eebiCloneArray( eligiblePlayers );
    level.eebiBotPlayers = eebiCloneArray( botPlayers );

    level.eebiHumanPlayerCount = humanPlayers.size;
    level.eebiEligiblePlayerCount = eligiblePlayers.size;
    level.eebiBotPlayerCount = botPlayers.size;
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

eebiCloneArray( source )
{
    result = [];

    if ( !isdefined( source ) )
    {
        return result;
    }

    for ( i = 0; i < source.size; i++ )
    {
        result[result.size] = source[i];
    }

    return result;
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

    if ( isdefined( player.pers ) && isdefined( player.pers["eebi_is_bot"] ) )
    {
        return player.pers["eebi_is_bot"];
    }

    if ( isdefined( player.eebiIsBot ) )
    {
        return player.eebiIsBot;
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

    if ( isdefined( level.gametype ) && eebiStringContainsToken( level.gametype, "zom" ) )
    {
        return true;
    }

    if ( eebiDvarContainsToken( "ui_gametype", "zom" ) || eebiDvarContainsToken( "g_gametype", "zom" ) )
    {
        return true;
    }

    return eebiIsKnownZombieMap( getdvar( "mapname" ) );
}

eebiDvarContainsToken( dvarName, token )
{
    return eebiStringContainsToken( getdvar( dvarName ), token );
}

eebiStringContainsToken( value, token )
{
    if ( !isdefined( value ) || !isdefined( token ) )
    {
        return false;
    }

    return issubstr( toLower( value + "" ), toLower( token + "" ) );
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

    return issubstr( lowerMap, "zombie" );
}

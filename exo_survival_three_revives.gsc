/*
    Solo three-revive limit for S1x Advanced Warfare Exo Survival

    Place this file at:
        s1/scripts/sv/exo_survival_three_revives.gsc

    Behavior:
        - Only runs in Exo Survival / Horde contexts.
        - Only enforces when exactly one active player is present.
        - The solo player gets exactly three successful revives.
        - Any later down is converted into a clean game-over.
*/

#define ES3R_MAX_REVIVES 3

main()
{
    init();
}

init()
{
    if ( isdefined( level.es3rInitStarted ) && level.es3rInitStarted )
    {
        return;
    }

    level.es3rInitStarted = true;
    level thread es3rDeferredInit();
}

es3rDeferredInit()
{
    wait 0.25;

    if ( !es3rIsExoSurvivalContext() )
    {
        return;
    }

    level.es3r = spawnstruct();
    level thread es3rMonitorPlayerConnections();
    es3rStartExistingPlayerMonitors();
}

es3rMonitorPlayerConnections()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );
        es3rStartPlayerMonitor( player );
    }
}

es3rStartExistingPlayerMonitors()
{
    players = es3rGetPlayers();

    for ( i = 0; i < players.size; i++ )
    {
        es3rStartPlayerMonitor( players[i] );
    }
}

es3rStartPlayerMonitor( player )
{
    if ( !isdefined( player ) )
    {
        return;
    }

    if ( isdefined( player.es3rMonitorStarted ) && player.es3rMonitorStarted )
    {
        return;
    }

    player.es3rMonitorStarted = true;

    if ( !isdefined( player.es3rRevivesUsed ) )
    {
        player.es3rRevivesUsed = 0;
    }

    player thread es3rMonitorSoloRevives();
}

es3rMonitorSoloRevives()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for ( ;; )
    {
        self waittill( "player_start_last_stand" );

        if ( !es3rShouldEnforceForPlayer( self ) )
        {
            es3rWaitForLastStandOutcome();
            continue;
        }

        if ( self.es3rRevivesUsed >= ES3R_MAX_REVIVES )
        {
            es3rHandlePostCapLastStand();
            continue;
        }

        outcome = es3rWaitForLastStandOutcome();
        if ( isdefined( outcome ) && outcome == "revive" )
        {
            self.es3rRevivesUsed++;
        }
    }
}

es3rWaitForLastStandOutcome()
{
    // Stock Horde last-stand uses "player_start_last_stand" on entry
    // and "revive" when the downed player is brought back up.
    return self common_scripts\utility::waittill_any_return( "revive", "death", "disconnect", "becameSpectator" );
}

es3rHandlePostCapLastStand()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    if ( !es3rShouldEnforceForPlayer( self ) )
    {
        return;
    }

    originalUseTime = undefined;
    if ( isdefined( self.usetime ) )
    {
        originalUseTime = self.usetime;
    }

    originalCurProgress = undefined;
    if ( isdefined( self.curprogress ) )
    {
        originalCurProgress = self.curprogress;
    }

    originalUseRate = undefined;
    if ( isdefined( self.userate ) )
    {
        originalUseRate = self.userate;
    }

    originalUseBarEndTime = self getclientomnvar( "ui_use_bar_end_time" );

    bleedoutSeconds = 8.0;
    if ( isdefined( originalUseTime ) && originalUseTime > 0 )
    {
        bleedoutSeconds = originalUseTime / 1000.0;
    }

    if ( isdefined( self.curprogress ) )
    {
        self.curprogress = 0;
    }

    if ( isdefined( self.userate ) )
    {
        self.userate = 0;
    }

    if ( isdefined( self.usetime ) )
    {
        self.usetime = 0;
    }

    self setclientomnvar( "ui_use_bar_end_time", 0 );

    elapsed = 0.0;
    while ( elapsed < bleedoutSeconds )
    {
        if ( !isdefined( self.laststand ) || !self.laststand )
        {
            break;
        }

        wait 0.05;
        elapsed = elapsed + 0.05;
    }

    if ( !isdefined( self.laststand ) || !self.laststand )
    {
        es3rRestorePostCapReviveState( originalUseTime, originalCurProgress, originalUseRate, originalUseBarEndTime );
        return;
    }

    es3rRestorePostCapReviveState( originalUseTime, originalCurProgress, originalUseRate, originalUseBarEndTime );
    es3rForceSoloGameOver();
}

es3rRestorePostCapReviveState( originalUseTime, originalCurProgress, originalUseRate, originalUseBarEndTime )
{
    if ( !isdefined( self ) )
    {
        return;
    }

    if ( isdefined( originalUseTime ) )
    {
        self.usetime = originalUseTime;
    }

    if ( isdefined( originalCurProgress ) )
    {
        self.curprogress = originalCurProgress;
    }

    if ( isdefined( originalUseRate ) )
    {
        self.userate = originalUseRate;
    }

    if ( isdefined( originalUseBarEndTime ) )
    {
        self setclientomnvar( "ui_use_bar_end_time", originalUseBarEndTime );
    }
}

es3rForceSoloGameOver()
{
    level endon( "game_ended" );
    self endon( "disconnect" );

    if ( !es3rShouldEnforceForPlayer( self ) )
    {
        return;
    }

    if ( !isdefined( self.laststand ) || !self.laststand )
    {
        return;
    }

    self maps\mp\_utility::_suicide();
    waittillframeend;

    if ( ( isdefined( self.laststand ) && self.laststand ) || maps\mp\_utility::isreallyalive( self ) )
    {
        return;
    }

    hordeGameEnded = getomnvar( "horde_game_ended" );
    if ( !es3rIsTruthyValue( hordeGameEnded ) )
    {
        maps\mp\gametypes\_horde_util::hordeupdatescore( self, 0 );
        maps\mp\gametypes\_horde_laststand::hordeendgame();
    }
}

es3rShouldEnforceForPlayer( player )
{
    if ( !es3rIsExoSurvivalContext() || !es3rIsCountablePlayer( player ) )
    {
        return false;
    }

    return es3rCountActivePlayers() == 1;
}

es3rCountActivePlayers()
{
    players = es3rGetPlayers();
    count = 0;

    for ( i = 0; i < players.size; i++ )
    {
        if ( es3rIsCountablePlayer( players[i] ) )
        {
            count++;
        }
    }

    return count;
}

es3rGetPlayers()
{
    if ( isdefined( level.players ) )
    {
        return level.players;
    }

    players = getplayers();
    if ( isdefined( players ) )
    {
        return players;
    }

    return [];
}

es3rIsCountablePlayer( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( isdefined( player.sessionstate ) )
    {
        state = toLower( player.sessionstate );
        if ( state == "spectator" || state == "intermission" )
        {
            return false;
        }
    }

    if ( !isdefined( player.pers ) || !isdefined( player.pers["connected"] ) )
    {
        return false;
    }

    if ( isdefined( player.pers ) && isdefined( player.pers["connected"] ) )
    {
        connected = es3rGetLowerValue( player.pers["connected"] + "" );
        if ( connected != "connected" && connected != "1" && connected != "true" )
        {
            return false;
        }
    }

    if ( !maps\mp\_utility::isreallyalive( player ) && ( !isdefined( player.laststand ) || !player.laststand ) )
    {
        return false;
    }

    return true;
}

es3rIsExoSurvivalContext()
{
    gt = es3rGetLowerValue( level.gametype );
    if ( gt == "" )
    {
        gt = es3rGetLowerValue( getdvar( "g_gametype" ) );
    }

    if ( gt != "" && es3rStringContains( gt, "horde" ) )
    {
        return true;
    }

    if ( es3rLooksLikeZombieContext() )
    {
        return false;
    }

    pl = es3rGetLowerValue( level.playlist );
    mn = es3rGetLowerValue( level.mapname );
    if ( mn == "" )
    {
        mn = es3rGetLowerValue( getdvar( "mapname" ) );
    }

    return es3rStringContains( gt, "exo survival" ) ||
           es3rStringContains( gt, "exo_survival" ) ||
           es3rStringContains( gt, "exosurvival" ) ||
           es3rStringContains( pl, "exo survival" ) ||
           es3rStringContains( pl, "exo_survival" ) ||
           es3rStringContains( pl, "exosurvival" ) ||
           es3rStringContains( mn, "exo survival" ) ||
           es3rStringContains( mn, "exo_survival" ) ||
           es3rStringContains( mn, "exosurvival" );
}

es3rLooksLikeZombieContext()
{
    if ( isdefined( level.zombiemode ) && level.zombiemode )
    {
        return true;
    }

    gt = es3rGetLowerValue( level.gametype );
    mn = es3rGetLowerValue( level.mapname );
    pl = es3rGetLowerValue( level.playlist );

    return es3rStringContains( gt, "zom" ) ||
           es3rStringContains( gt, "infect" ) ||
           es3rStringContains( mn, "zm_" ) ||
           es3rStringContains( mn, "zombie" ) ||
           es3rStringContains( pl, "zombie" );
}

es3rGetLowerValue( value )
{
    if ( !isdefined( value ) )
    {
        return "";
    }

    return toLower( value );
}

es3rStringContains( haystack, needle )
{
    if ( !isdefined( haystack ) || !isdefined( needle ) || haystack == "" || needle == "" )
    {
        return false;
    }

    return issubstr( haystack, needle );
}

es3rIsTruthyValue( value )
{
    if ( !isdefined( value ) )
    {
        return false;
    }

    normalized = es3rGetLowerValue( value + "" );
    return normalized != "" &&
           normalized != "0" &&
           normalized != "false" &&
           normalized != "undefined";
}

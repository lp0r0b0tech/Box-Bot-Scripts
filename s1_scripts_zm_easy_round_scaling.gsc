/*
    Easy round scaling for S1x Advanced Warfare Exo Zombies

    Place this file at:
        s1/scripts/zm/easy_round_scaling.gsc

    Behavior:
        - Rounds 1-55 stretch the original round-1-through-45 health curve
          across 55 rounds so the early game stays easier for longer.
        - Rounds 56-100 replay the original round-1-through-45 scaling.
        - Rounds 101+ continue forward from original round 46+ scaling.

    Toggle:
        set scr_zm_easy_round_scaling_enable 1
*/

#define EZRS_DEFAULT_ENABLED                   1

#define EZRS_BASE_HEALTH                       150
#define EZRS_HEALTH_INCREMENT                  100
#define EZRS_HEALTH_CURVE_ROUND                10
#define EZRS_HEALTH_CURVE_MULTIPLIER           1.10
#define EZRS_HEALTH_CAP                        35000

#define EZRS_EASY_PHASE_END_ROUND              55
#define EZRS_EASY_PHASE_TARGET_LEGACY_ROUND    45
#define EZRS_REPLAY_PHASE_START_ROUND          56
#define EZRS_REPLAY_PHASE_END_ROUND            100
#define EZRS_REPLAY_PHASE_LEGACY_START_ROUND   1
#define EZRS_REPLAY_PHASE_LEGACY_END_ROUND     45

main()
{
    init();
}

init()
{
    if ( isdefined( level.ezrsInitStarted ) && level.ezrsInitStarted )
    {
        return;
    }

    level.ezrsInitStarted = true;
    level thread ezrsDeferredInit();
}

ezrsDeferredInit()
{
    wait 0.25;

    if ( !ezrsIsZombieContext() )
    {
        return;
    }

    initEasyRoundScalingDvars();

    if ( getdvarint( "scr_zm_easy_round_scaling_enable" ) <= 0 )
    {
        return;
    }

    level.ezrs = buildEasyRoundScalingState();
    level thread monitorEasyRoundScalingRounds();
    level thread monitorEasyRoundScalingSpawns();
    level thread periodicEasyRoundScalingRefresh();
}

initEasyRoundScalingDvars()
{
    setdvarifuninitialized( "scr_zm_easy_round_scaling_enable", EZRS_DEFAULT_ENABLED );
}

buildEasyRoundScalingState()
{
    state = spawnstruct();
    state.round = readLiveEasyRoundScalingRound();
    state.trackedZombies = [];
    return state;
}

monitorEasyRoundScalingRounds()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "round_start", roundNumber );

        if ( !isdefined( level.ezrs ) )
        {
            continue;
        }

        level.ezrs.round = max( 1, int( roundNumber ) );
        retuneTrackedEasyRoundScalingZombies();
    }
}

monitorEasyRoundScalingSpawns()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "zombie_spawned", zombie );

        if ( getdvarint( "scr_zm_easy_round_scaling_enable" ) <= 0 || !isdefined( zombie ) )
        {
            continue;
        }

        trackEasyRoundScalingZombie( zombie );
    }
}

periodicEasyRoundScalingRefresh()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( getdvarint( "scr_zm_easy_round_scaling_enable" ) > 0 )
        {
            scanForEasyRoundScalingZombies();
        }

        wait 0.5;
    }
}

scanForEasyRoundScalingZombies()
{
    zombies = [];
    appendEasyRoundScalingEntArray( zombies, getentarray( "actor", "classname" ) );
    appendEasyRoundScalingEntArray( zombies, getentarray( "agent", "classname" ) );
    appendEasyRoundScalingEntArray( zombies, getentarray( "zombie", "classname" ) );

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( isEasyRoundScalingZombieEntity( zombie ) )
        {
            trackEasyRoundScalingZombie( zombie );
        }
    }
}

trackEasyRoundScalingZombie( zombie )
{
    if ( !isEasyRoundScalingZombieEntity( zombie ) )
    {
        return;
    }

    if ( rememberEasyRoundScalingZombie( zombie ) )
    {
        zombie thread tuneZombieForEasyRoundScaling();
    }
}

rememberEasyRoundScalingZombie( zombie )
{
    if ( !isdefined( zombie ) )
    {
        return false;
    }

    if ( isdefined( zombie.ezrsTracked ) && zombie.ezrsTracked )
    {
        return false;
    }

    zombie.ezrsTracked = true;
    level.ezrs.trackedZombies[level.ezrs.trackedZombies.size] = zombie;
    return true;
}

retuneTrackedEasyRoundScalingZombies()
{
    zombies = getTrackedEasyRoundScalingZombies();

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( isdefined( zombie ) && isalive( zombie ) && ( !isdefined( zombie.ezrsRetunePending ) || !zombie.ezrsRetunePending ) )
        {
            zombie.ezrsRetunePending = true;
            zombie thread retuneActiveEasyRoundScalingZombie();
        }
    }
}

retuneActiveEasyRoundScalingZombie()
{
    self endon( "death" );

    wait 0.05;
    tuneZombieForEasyRoundScaling();
    self.ezrsRetunePending = false;
}

tuneZombieForEasyRoundScaling()
{
    self endon( "death" );

    roundNumber = getCurrentEasyRoundScalingRound();
    health = calculateEasyRoundScalingHealth( roundNumber );

    previousHealth = health;
    if ( isdefined( self.health ) )
    {
        previousHealth = self.health;
    }

    self.maxhealth = health;
    if ( !isdefined( self.ezrsZombieTuned ) || !self.ezrsZombieTuned )
    {
        self.health = health;
    }
    else
    {
        self.health = min( previousHealth, health );
    }

    self.ezrsZombieTuned = true;
}

getCurrentEasyRoundScalingRound()
{
    if ( isdefined( level.ezrs ) && isdefined( level.ezrs.round ) )
    {
        return max( int( level.ezrs.round ), readLiveEasyRoundScalingRound() );
    }

    return readLiveEasyRoundScalingRound();
}

readLiveEasyRoundScalingRound()
{
    if ( isdefined( level.round_number ) )
    {
        return max( 1, int( level.round_number ) );
    }

    if ( isdefined( level.survival_round ) )
    {
        return max( 1, int( level.survival_round ) );
    }

    return max( 1, getdvarint( "survival_round" ) );
}

calculateEasyRoundScalingHealth( roundNumber )
{
    if ( roundNumber <= EZRS_EASY_PHASE_END_ROUND )
    {
        return calculateEasyRoundScalingPhaseHealth( roundNumber );
    }

    replayLegacyRound = calculateReplayEasyRoundScalingLegacyRound( roundNumber );
    if ( roundNumber > EZRS_REPLAY_PHASE_END_ROUND )
    {
        return calculateLegacyEasyRoundScalingHealth( int( replayLegacyRound ) );
    }

    return calculateInterpolatedLegacyEasyRoundScalingHealth( replayLegacyRound, EZRS_REPLAY_PHASE_LEGACY_END_ROUND );
}

calculateEasyRoundScalingPhaseHealth( roundNumber )
{
    if ( roundNumber <= 1 )
    {
        return calculateLegacyEasyRoundScalingHealth( 1 );
    }

    easyLegacyRound = remapEasyRoundScalingRangeFloat(
        roundNumber,
        1,
        EZRS_EASY_PHASE_END_ROUND,
        1,
        EZRS_EASY_PHASE_TARGET_LEGACY_ROUND
    );

    return calculateInterpolatedLegacyEasyRoundScalingHealth( easyLegacyRound, EZRS_EASY_PHASE_TARGET_LEGACY_ROUND );
}

calculateReplayEasyRoundScalingLegacyRound( roundNumber )
{
    if ( roundNumber < EZRS_REPLAY_PHASE_START_ROUND )
    {
        return EZRS_REPLAY_PHASE_LEGACY_START_ROUND;
    }

    if ( roundNumber <= EZRS_REPLAY_PHASE_END_ROUND )
    {
        return remapEasyRoundScalingRangeFloat(
            roundNumber,
            EZRS_REPLAY_PHASE_START_ROUND,
            EZRS_REPLAY_PHASE_END_ROUND,
            EZRS_REPLAY_PHASE_LEGACY_START_ROUND,
            EZRS_REPLAY_PHASE_LEGACY_END_ROUND
        );
    }

    return EZRS_REPLAY_PHASE_LEGACY_END_ROUND + (roundNumber - EZRS_REPLAY_PHASE_END_ROUND);
}

calculateInterpolatedLegacyEasyRoundScalingHealth( legacyRoundFloat, maximumLegacyRound )
{
    clampedLegacyRound = easyRoundScalingClamp( legacyRoundFloat, 1.0, maximumLegacyRound );
    lowerLegacyRound = int( clampedLegacyRound );

    if ( lowerLegacyRound < 1 )
    {
        lowerLegacyRound = 1;
    }

    legacyBlend = clampedLegacyRound - lowerLegacyRound;
    if ( legacyBlend >= 0.9999 )
    {
        lowerLegacyRound++;
        if ( lowerLegacyRound > maximumLegacyRound )
        {
            lowerLegacyRound = maximumLegacyRound;
        }

        legacyBlend = 0;
    }

    upperLegacyRound = lowerLegacyRound + 1;
    if ( upperLegacyRound > maximumLegacyRound )
    {
        upperLegacyRound = maximumLegacyRound;
    }

    lowerLegacyHealth = calculateLegacyEasyRoundScalingHealth( lowerLegacyRound );
    upperLegacyHealth = calculateLegacyEasyRoundScalingHealth( upperLegacyRound );

    return int( lowerLegacyHealth + ((upperLegacyHealth - lowerLegacyHealth) * legacyBlend) );
}

calculateLegacyEasyRoundScalingHealth( roundNumber )
{
    if ( roundNumber <= 1 )
    {
        return EZRS_BASE_HEALTH;
    }

    if ( roundNumber <= EZRS_HEALTH_CURVE_ROUND )
    {
        return min( EZRS_HEALTH_CAP, EZRS_BASE_HEALTH + ((roundNumber - 1) * EZRS_HEALTH_INCREMENT) );
    }

    health = EZRS_BASE_HEALTH + ((EZRS_HEALTH_CURVE_ROUND - 1) * EZRS_HEALTH_INCREMENT);

    for ( i = EZRS_HEALTH_CURVE_ROUND + 1; i <= roundNumber; i++ )
    {
        health = min( EZRS_HEALTH_CAP, int( health * EZRS_HEALTH_CURVE_MULTIPLIER ) );
        if ( health >= EZRS_HEALTH_CAP )
        {
            return EZRS_HEALTH_CAP;
        }
    }

    return health;
}

remapEasyRoundScalingRangeFloat( sourceRound, sourceStart, sourceEnd, targetStart, targetEnd )
{
    if ( sourceEnd <= sourceStart )
    {
        return targetEnd;
    }

    if ( sourceRound <= sourceStart )
    {
        return targetStart;
    }

    if ( sourceRound >= sourceEnd )
    {
        return targetEnd;
    }

    sourceProgress = (sourceRound - sourceStart) / ((sourceEnd - sourceStart) * 1.0);
    if ( sourceProgress < 0 )
    {
        sourceProgress = 0;
    }
    else if ( sourceProgress > 1 )
    {
        sourceProgress = 1;
    }

    return targetStart + ((targetEnd - targetStart) * sourceProgress);
}

easyRoundScalingClamp( value, minimum, maximum )
{
    if ( value < minimum )
    {
        return minimum;
    }

    if ( value > maximum )
    {
        return maximum;
    }

    return value;
}

getTrackedEasyRoundScalingZombies()
{
    liveZombies = [];

    for ( i = 0; i < level.ezrs.trackedZombies.size; i++ )
    {
        zombie = level.ezrs.trackedZombies[i];
        if ( isdefined( zombie ) && isalive( zombie ) )
        {
            liveZombies[liveZombies.size] = zombie;
        }
    }

    level.ezrs.trackedZombies = liveZombies;
    return liveZombies;
}

appendEasyRoundScalingEntArray( destination, source )
{
    if ( !isdefined( source ) )
    {
        return;
    }

    for ( i = 0; i < source.size; i++ )
    {
        if ( isdefined( source[i] ) )
        {
            destination[destination.size] = source[i];
        }
    }
}

isEasyRoundScalingZombieEntity( entity )
{
    if ( !isdefined( entity ) )
    {
        return false;
    }

    if ( isdefined( entity.classname ) && entity.classname == "actor" && ( entityMatchesEasyRoundScalingToken( entity, "zombie" ) || entityMatchesEasyRoundScalingToken( entity, "exo_zm" ) || entityMatchesEasyRoundScalingToken( entity, "infected" ) ) )
    {
        return true;
    }

    return entityMatchesEasyRoundScalingToken( entity, "zombie" ) || entityMatchesEasyRoundScalingToken( entity, "exo_zm" ) || entityMatchesEasyRoundScalingToken( entity, "infected" );
}

entityMatchesEasyRoundScalingToken( entity, token )
{
    if ( !isdefined( entity ) || !isdefined( token ) )
    {
        return false;
    }

    if ( isdefined( entity.targetname ) && easyRoundScalingStringContainsToken( entity.targetname, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_noteworthy ) && easyRoundScalingStringContainsToken( entity.script_noteworthy, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_linkname ) && easyRoundScalingStringContainsToken( entity.script_linkname, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_string ) && easyRoundScalingStringContainsToken( entity.script_string, token ) )
    {
        return true;
    }

    if ( isdefined( entity.model ) && easyRoundScalingStringContainsToken( entity.model, token ) )
    {
        return true;
    }

    return false;
}

easyRoundScalingStringContainsToken( value, token )
{
    if ( !isdefined( value ) || !isdefined( token ) )
    {
        return false;
    }

    return issubstr( value, token );
}

ezrsIsZombieContext()
{
    if ( isdefined( level.zombiemode ) && level.zombiemode )
    {
        return true;
    }

    if ( isdefined( level.zombieMap ) && level.zombieMap )
    {
        return true;
    }

    if ( isdefined( level.gametype ) && easyRoundScalingStringContainsToken( level.gametype, "zom" ) )
    {
        return true;
    }

    if ( easyRoundScalingDvarContainsToken( "ui_gametype", "zom" ) || easyRoundScalingDvarContainsToken( "g_gametype", "zom" ) )
    {
        return true;
    }

    return isEasyRoundScalingKnownZombieMap( getdvar( "mapname" ) );
}

easyRoundScalingDvarContainsToken( dvarName, token )
{
    value = getdvar( dvarName );
    return easyRoundScalingStringContainsToken( value, token );
}

isEasyRoundScalingKnownZombieMap( mapname )
{
    if ( !isdefined( mapname ) )
    {
        return false;
    }

    if ( strlen( mapname ) >= 3 && getsubstr( mapname, 0, 3 ) == "zm_" )
    {
        return true;
    }

    return mapname == "zombie_outbreak" || mapname == "zombie_infection" || mapname == "zombie_carrier" || mapname == "zombie_descent";
}

/*
    Map-agnostic Advanced Warfare Exo Zombies teammate bots for S1x.

    Suggested placement:
        s1/scripts/zm/auto_bots_zombies.gsc

    Notes:
        - Runs only in zombie / Exo Zombies contexts.
        - Uses its own scr_zm_autobots_* dvars and does not modify MP autobots.
        - Real revive, perk, and exo-ability interactions are map-specific in AW,
          so those hooks are isolated and disabled safely by default.
*/

#define ABZM_DEFAULT_ENABLE                    1
#define ABZM_DEFAULT_COUNT                     3
#define ABZM_DEFAULT_DEBUG                     0
#define ABZM_DEFAULT_AUTO_AMMO                1
#define ABZM_DEFAULT_AUTO_PROGRESS            1
#define ABZM_DEFAULT_AUTO_PERKS               1
#define ABZM_DEFAULT_AUTO_REVIVE              1
#define ABZM_DEFAULT_MAP_HOOKS                0
#define ABZM_DEFAULT_START_POINTS             5000
#define ABZM_DEFAULT_INCOME_TICK              150
#define ABZM_DEFAULT_WEAPON_COST              1200
#define ABZM_DEFAULT_AMMO_COST                250
#define ABZM_DEFAULT_PERK_COST                500
#define ABZM_DEFAULT_REVIVE_REWARD            300
#define ABZM_DEFAULT_SCAN_INTERVAL_MS         1000
#define ABZM_DEFAULT_THINK_INTERVAL           0.35
#define ABZM_DEFAULT_SUPPORT_INTERVAL         1.00
#define ABZM_DEFAULT_DEBUG_LOG_SECONDS        1.00
#define ABZM_MAX_BOTS                         3

main()
{
    init();
}

init()
{
    if ( isdefined( level.abzmInitStarted ) && level.abzmInitStarted )
    {
        return;
    }

    level.abzmInitStarted = true;
    level thread abzmDeferredInit();
}

abzmDeferredInit()
{
    level endon( "game_ended" );

    wait 0.25;

    if ( !abzmShouldRunHere() )
    {
        return;
    }

    abzmInitDvars();

    if ( getdvarint( "scr_zm_autobots_enable" ) <= 0 )
    {
        return;
    }

    level.abzmBots = [];
    level.abzmWarned = [];
    level.abzmLastLogTime = 0;
    level.abzmLastScanTime = 0;

    abzmInitWeaponProgression();
    abzmInitPerkPriority();
    abzmInitSpecialKeywords();

    abzmLog( "init: enabled" );

    level thread abzmManagerLoop();
    level thread abzmSpecialScannerLoop();
}

abzmInitDvars()
{
    setdvarifuninitialized( "scr_zm_autobots_enable", ABZM_DEFAULT_ENABLE );
    setdvarifuninitialized( "scr_zm_autobots_count", ABZM_DEFAULT_COUNT );
    setdvarifuninitialized( "scr_zm_autobots_debug", ABZM_DEFAULT_DEBUG );
    setdvarifuninitialized( "scr_zm_autobots_auto_ammo", ABZM_DEFAULT_AUTO_AMMO );
    setdvarifuninitialized( "scr_zm_autobots_auto_progress", ABZM_DEFAULT_AUTO_PROGRESS );
    setdvarifuninitialized( "scr_zm_autobots_auto_perks", ABZM_DEFAULT_AUTO_PERKS );
    setdvarifuninitialized( "scr_zm_autobots_auto_revive", ABZM_DEFAULT_AUTO_REVIVE );
    setdvarifuninitialized( "scr_zm_autobots_map_hooks", ABZM_DEFAULT_MAP_HOOKS );
    setdvarifuninitialized( "scr_zm_autobots_start_points", ABZM_DEFAULT_START_POINTS );
    setdvarifuninitialized( "scr_zm_autobots_income_tick", ABZM_DEFAULT_INCOME_TICK );
    setdvarifuninitialized( "scr_zm_autobots_weapon_cost", ABZM_DEFAULT_WEAPON_COST );
    setdvarifuninitialized( "scr_zm_autobots_ammo_cost", ABZM_DEFAULT_AMMO_COST );
    setdvarifuninitialized( "scr_zm_autobots_perk_cost", ABZM_DEFAULT_PERK_COST );
    setdvarifuninitialized( "scr_zm_autobots_revive_reward", ABZM_DEFAULT_REVIVE_REWARD );
    setdvarifuninitialized( "scr_zm_autobots_scan_interval_ms", ABZM_DEFAULT_SCAN_INTERVAL_MS );
    setdvarifuninitialized( "scr_zm_autobots_debug_log_seconds", ABZM_DEFAULT_DEBUG_LOG_SECONDS );
}

abzmInitWeaponProgression()
{
    level.abzmWeaponProgression = [];

    level.abzmWeaponProgression[level.abzmWeaponProgression.size] = "iw5_ak12zm_mp";
    level.abzmWeaponProgression[level.abzmWeaponProgression.size] = "iw5_bal27zm_mp";
    level.abzmWeaponProgression[level.abzmWeaponProgression.size] = "iw5_hbra3zm_mp";
    level.abzmWeaponProgression[level.abzmWeaponProgression.size] = "iw5_titan45zm_mp";
    level.abzmWeaponProgression[level.abzmWeaponProgression.size] = "iw5_gm6zm_mp";
    level.abzmWeaponProgression[level.abzmWeaponProgression.size] = "iw5_microwavezm_mp";
    level.abzmWeaponProgression[level.abzmWeaponProgression.size] = "iw5_tridentzm_mp";
}

abzmInitPerkPriority()
{
    level.abzmPerkPriority = [];

    level.abzmPerkPriority[level.abzmPerkPriority.size] = "exo_health";
    level.abzmPerkPriority[level.abzmPerkPriority.size] = "quick_revive";
    level.abzmPerkPriority[level.abzmPerkPriority.size] = "fast_hands";
    level.abzmPerkPriority[level.abzmPerkPriority.size] = "staminup";
}

abzmInitSpecialKeywords()
{
    level.abzmSpecialKeywordGroups = spawnstruct();

    level.abzmSpecialKeywordGroups.emp = [];
    level.abzmSpecialKeywordGroups.emp[level.abzmSpecialKeywordGroups.emp.size] = "emz";
    level.abzmSpecialKeywordGroups.emp[level.abzmSpecialKeywordGroups.emp.size] = "emp";
    level.abzmSpecialKeywordGroups.emp[level.abzmSpecialKeywordGroups.emp.size] = "electric";

    level.abzmSpecialKeywordGroups.heavy = [];
    level.abzmSpecialKeywordGroups.heavy[level.abzmSpecialKeywordGroups.heavy.size] = "goliath";
    level.abzmSpecialKeywordGroups.heavy[level.abzmSpecialKeywordGroups.heavy.size] = "heavy";
    level.abzmSpecialKeywordGroups.heavy[level.abzmSpecialKeywordGroups.heavy.size] = "mech";

    level.abzmSpecialKeywordGroups.breacher = [];
    level.abzmSpecialKeywordGroups.breacher[level.abzmSpecialKeywordGroups.breacher.size] = "breacher";
    level.abzmSpecialKeywordGroups.breacher[level.abzmSpecialKeywordGroups.breacher.size] = "bomber";
    level.abzmSpecialKeywordGroups.breacher[level.abzmSpecialKeywordGroups.breacher.size] = "exploder";

    level.abzmSpecialKeywordGroups.other = [];
    level.abzmSpecialKeywordGroups.other[level.abzmSpecialKeywordGroups.other.size] = "infected";
    level.abzmSpecialKeywordGroups.other[level.abzmSpecialKeywordGroups.other.size] = "spitter";
    level.abzmSpecialKeywordGroups.other[level.abzmSpecialKeywordGroups.other.size] = "special";
}

abzmManagerLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( !abzmShouldRunHere() )
        {
            wait 1.0;
            continue;
        }

        abzmRefreshBotRoster();

        if ( getdvarint( "scr_zm_autobots_enable" ) <= 0 )
        {
            abzmTrimBotsToCount( 0 );
            wait 1.0;
            continue;
        }

        abzmTrimBotsToTarget();
        abzmFillBotsToTarget();

        wait 1.0;
    }
}

abzmSpecialScannerLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( getdvarint( "scr_zm_autobots_enable" ) > 0 )
        {
            level.abzmKnownZombies = abzmBuildZombieArray();
            level.abzmKnownSpecials = abzmFilterSpecialZombies( level.abzmKnownZombies );
        }

        wait abzmReadScanInterval();
    }
}

abzmRefreshBotRoster()
{
    players = getplayers();
    fresh = [];

    if ( !isdefined( players ) )
    {
        level.abzmBots = fresh;
        return;
    }

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( abzmIsManagedBot( player ) && ( !isdefined( player.abzmPendingDrop ) || !player.abzmPendingDrop ) )
        {
            fresh[fresh.size] = player;
        }
    }

    level.abzmBots = fresh;
}

abzmFillBotsToTarget()
{
    if ( !isdefined( level.abzmBots ) )
    {
        level.abzmBots = [];
    }

    targetCount = getdvarint( "scr_zm_autobots_count" );
    if ( targetCount < 0 )
    {
        targetCount = 0;
    }
    if ( targetCount > ABZM_MAX_BOTS )
    {
        targetCount = ABZM_MAX_BOTS;
    }

    activeCount = level.abzmBots.size + abzmCountPendingDropBots();

    while ( activeCount < targetCount )
    {
        bot = addtestclient();
        if ( !isdefined( bot ) )
        {
            abzmWarnOnce( "spawn_failed", "addtestclient returned undefined" );
            return;
        }

        wait 0.25;

        bot.abzmManaged = true;
        bot.abzmPendingDrop = false;
        bot.abzmSlot = level.abzmBots.size;

        if ( isdefined( bot.pers ) )
        {
            bot.pers["isBot"] = true;
        }

        abzmInitBotState( bot );
        abzmGiveProgressionWeapon( bot, 0, true );

        level.abzmBots[level.abzmBots.size] = bot;
        activeCount++;

        bot thread abzmBotMainLoop();
        bot thread abzmBotSupportLoop();

        abzmLog( "spawned teammate bot slot " + bot.abzmSlot );
        wait 0.25;
    }
}

abzmInitBotState( bot )
{
    if ( !isdefined( bot ) )
    {
        return;
    }

    bot.abzmPoints = getdvarint( "scr_zm_autobots_start_points" );
    bot.abzmWeaponIndex = 0;
    bot.abzmOwnedWeapons = [];
    bot.abzmPerks = [];
    bot.abzmSimulatedPerks = [];
    bot.abzmLastSupportTime = 0;
    bot.abzmLastReviveAttempt = 0;
    bot.abzmLastExoHookAttempt = 0;
    bot.abzmLastWeaponBuyTime = 0;
    bot.abzmLastAmmoFillTime = 0;
    bot.abzmLastPerkTime = 0;
}

abzmBotMainLoop()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( !getdvarint( "scr_zm_autobots_enable" ) )
        {
            wait 1.0;
            continue;
        }

        if ( !isalive( self ) )
        {
            wait 1.0;
            continue;
        }

        leader = abzmGetFollowLeader();

        reviveTarget = undefined;
        if ( getdvarint( "scr_zm_autobots_auto_revive" ) > 0 )
        {
            reviveTarget = abzmFindNearestDownedHuman( self.origin );
        }

        if ( isdefined( reviveTarget ) )
        {
            abzmHandleReviveBehavior( self, reviveTarget );
            wait ABZM_DEFAULT_THINK_INTERVAL;
            continue;
        }

        if ( abzmTooManyZombiesNearby( self.origin, 220, 6 ) )
        {
            abzmHandleEscapeBehavior( self, leader );
            wait ABZM_DEFAULT_THINK_INTERVAL;
            continue;
        }

        threat = abzmFindBestThreatForBot( self );
        if ( isdefined( threat ) )
        {
            abzmHandleThreatBehavior( self, threat, leader );
            wait ABZM_DEFAULT_THINK_INTERVAL;
            continue;
        }

        if ( isdefined( leader ) )
        {
            abzmHandleFollowBehavior( self, leader );
        }
        wait ABZM_DEFAULT_THINK_INTERVAL;
    }
}

abzmBotSupportLoop()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( !getdvarint( "scr_zm_autobots_enable" ) )
        {
            wait 1.0;
            continue;
        }

        if ( isalive( self ) )
        {
            abzmTickBotPoints( self );

            if ( getdvarint( "scr_zm_autobots_auto_progress" ) > 0 )
            {
                abzmTryAdvanceWeapon( self );
            }

            if ( getdvarint( "scr_zm_autobots_auto_ammo" ) > 0 )
            {
                abzmTryRefillAmmo( self );
            }

            if ( getdvarint( "scr_zm_autobots_auto_perks" ) > 0 )
            {
                abzmTryApplyPerks( self );
            }
        }

        wait ABZM_DEFAULT_SUPPORT_INTERVAL;
    }
}

abzmTickBotPoints( bot )
{
    if ( !isdefined( bot ) )
    {
        return;
    }

    bot.abzmPoints += getdvarint( "scr_zm_autobots_income_tick" );
}

abzmTryAdvanceWeapon( bot )
{
    if ( !isdefined( bot ) )
    {
        return;
    }

    if ( isdefined( level.time ) && isdefined( bot.abzmLastWeaponBuyTime ) && level.time - bot.abzmLastWeaponBuyTime < 5000 )
    {
        return;
    }

    nextIndex = bot.abzmWeaponIndex + 1;
    if ( nextIndex >= level.abzmWeaponProgression.size )
    {
        return;
    }

    if ( !abzmSpendPoints( bot, getdvarint( "scr_zm_autobots_weapon_cost" ) ) )
    {
        return;
    }

    abzmGiveProgressionWeapon( bot, nextIndex, false );
    if ( isdefined( level.time ) )
    {
        bot.abzmLastWeaponBuyTime = level.time;
    }
}

abzmGiveProgressionWeapon( bot, weaponIndex, isInitialGive )
{
    if ( !isdefined( bot ) )
    {
        return;
    }

    if ( weaponIndex < 0 )
    {
        weaponIndex = 0;
    }

    if ( weaponIndex >= level.abzmWeaponProgression.size )
    {
        weaponIndex = level.abzmWeaponProgression.size - 1;
    }

    weaponName = level.abzmWeaponProgression[weaponIndex];
    fallbackWeapon = level.abzmWeaponProgression[0];

    bot takeallweapons();
    bot.abzmOwnedWeapons = [];
    bot giveweapon( fallbackWeapon );
    bot givemaxammo( fallbackWeapon );

    bot giveweapon( weaponName );
    bot givemaxammo( weaponName );
    bot switchtoweapon( weaponName );

    if ( weaponName != fallbackWeapon )
    {
        abzmRememberOwnedWeapon( bot, fallbackWeapon );
    }

    abzmRememberOwnedWeapon( bot, weaponName );

    bot.abzmWeaponIndex = weaponIndex;

    if ( isInitialGive )
    {
        abzmLog( "bot initial weapon: " + weaponName );
    }
    else
    {
        abzmLog( "bot upgraded weapon: " + weaponName );
    }
}

abzmTryRefillAmmo( bot )
{
    if ( !isdefined( bot ) )
    {
        return;
    }

    if ( isdefined( level.time ) && isdefined( bot.abzmLastAmmoFillTime ) && level.time - bot.abzmLastAmmoFillTime < 3000 )
    {
        return;
    }

    if ( !abzmNeedsAmmo( bot ) )
    {
        return;
    }

    if ( !abzmSpendPoints( bot, getdvarint( "scr_zm_autobots_ammo_cost" ) ) )
    {
        return;
    }

    weaponName = abzmGetCurrentWeaponName( bot );
    bot givemaxammo( weaponName );
    bot switchtoweapon( weaponName );

    if ( isdefined( level.time ) )
    {
        bot.abzmLastAmmoFillTime = level.time;
    }

    abzmLog( "bot refilled ammo: " + weaponName );
}

abzmNeedsAmmo( bot )
{
    if ( !isdefined( bot ) )
    {
        return false;
    }

    weaponName = abzmGetCurrentWeaponName( bot );
    clipAmmo = bot getweaponammoclip( weaponName );
    stockAmmo = bot getweaponammostock( weaponName );

    if ( isdefined( clipAmmo ) && clipAmmo <= 4 )
    {
        return true;
    }

    if ( isdefined( stockAmmo ) && stockAmmo <= 24 )
    {
        return true;
    }

    if ( isdefined( bot.clipammo ) && bot.clipammo <= 4 )
    {
        return true;
    }

    if ( isdefined( bot.ammocount ) && bot.ammocount <= 24 )
    {
        return true;
    }

    return false;
}

abzmTryApplyPerks( bot )
{
    if ( !isdefined( bot ) )
    {
        return;
    }

    if ( isdefined( level.time ) && isdefined( bot.abzmLastPerkTime ) && level.time - bot.abzmLastPerkTime < 4000 )
    {
        return;
    }

    for ( i = 0; i < level.abzmPerkPriority.size; i++ )
    {
        perkName = level.abzmPerkPriority[i];

        if ( abzmHasPerk( bot, perkName ) )
        {
            continue;
        }

        if ( !abzmSpendPoints( bot, getdvarint( "scr_zm_autobots_perk_cost" ) ) )
        {
            return;
        }

        if ( !abzmRunMapPerkHook( bot, perkName ) )
        {
            bot.abzmSimulatedPerks[perkName] = true;
            abzmLog( "perk bookkeeping only: " + perkName );
        }
        else
        {
            bot.abzmPerks[perkName] = true;
        }

        if ( isdefined( level.time ) )
        {
            bot.abzmLastPerkTime = level.time;
        }

        wait 0.05;
    }
}

abzmRunMapPerkHook( bot, perkName )
{
    if ( getdvarint( "scr_zm_autobots_map_hooks" ) <= 0 )
    {
        return false;
    }

    /*
        Map-specific customization point.
        Replace this safe no-op with real perk trigger logic for a known map.
    */
    return false;
}

abzmRunMapReviveHook( bot, downedPlayer )
{
    if ( getdvarint( "scr_zm_autobots_map_hooks" ) <= 0 )
    {
        return false;
    }

    /*
        Map-specific customization point.
        Replace this safe no-op with the correct revive logic for a known map.
    */
    return false;
}

abzmRunMapExoEscapeHook( bot, escapeGoal )
{
    if ( getdvarint( "scr_zm_autobots_map_hooks" ) <= 0 )
    {
        return false;
    }

    /*
        Map-specific customization point.
        Replace this safe no-op with the correct exo boost / jump logic.
    */
    return false;
}

abzmHandleReviveBehavior( bot, reviveTarget )
{
    if ( !isdefined( bot ) || !isdefined( reviveTarget ) )
    {
        return;
    }

    abzmSetBotGoal( bot, reviveTarget.origin );

    if ( distance( bot.origin, reviveTarget.origin ) <= 100 )
    {
        if ( isdefined( level.time ) && isdefined( bot.abzmLastReviveAttempt ) && level.time - bot.abzmLastReviveAttempt < 4000 )
        {
            return;
        }

        if ( isdefined( level.time ) )
        {
            bot.abzmLastReviveAttempt = level.time;
        }

        if ( abzmRunMapReviveHook( bot, reviveTarget ) )
        {
            abzmLog( "bot started revive hook" );
        }
        else
        {
            abzmWarnOnce( "revive_hook_" + bot.abzmSlot, "revive hook is map-specific and disabled by default for bot slot " + bot.abzmSlot );
        }
    }
}

abzmHandleEscapeBehavior( bot, leader )
{
    if ( !isdefined( bot ) )
    {
        return;
    }

    anchorOrigin = undefined;
    if ( isdefined( leader ) )
    {
        anchorOrigin = leader.origin;
    }
    else
    {
        nearestZombie = abzmFindNearestZombie( bot.origin );
        if ( isdefined( nearestZombie ) )
        {
            anchorOrigin = nearestZombie.origin;
        }
    }

    if ( !isdefined( anchorOrigin ) )
    {
        anchorOrigin = bot.origin - ( 160, 0, 0 );
    }

    escapeGoal = abzmBuildEscapeGoal( bot.origin, anchorOrigin );
    abzmSetBotGoal( bot, escapeGoal );

    if ( !abzmRunMapExoEscapeHook( bot, escapeGoal ) )
    {
        abzmWarnOnce( "exo_hook_" + bot.abzmSlot, "exo movement hook is map-specific and disabled by default for bot slot " + bot.abzmSlot );
    }
}

abzmHandleThreatBehavior( bot, threat, leader )
{
    if ( !isdefined( bot ) || !isdefined( threat ) )
    {
        return;
    }

    preferredWeapon = abzmGetPreferredWeaponForThreat( bot, threat );
    if ( abzmHasRememberedWeapon( bot, preferredWeapon ) )
    {
        bot switchtoweapon( preferredWeapon );
    }
    else
    {
        bot switchtoweapon( abzmGetCurrentWeaponName( bot ) );
    }

    threatDistance = distance( bot.origin, threat.origin );
    if ( threatDistance > 110 )
    {
        abzmSetBotGoal( bot, threat.origin );
    }
    else if ( isdefined( leader ) )
    {
        abzmSetBotGoal( bot, abzmBuildEscapeGoal( bot.origin, leader.origin ) );
    }
}

abzmHandleFollowBehavior( bot, leader )
{
    if ( !isdefined( bot ) || !isdefined( leader ) )
    {
        return;
    }

    desiredGoal = abzmGetFormationGoal( leader, bot.abzmSlot );

    if ( distance( bot.origin, leader.origin ) > 900 )
    {
        desiredGoal = leader.origin;
    }

    abzmSetBotGoal( bot, desiredGoal );
}

abzmSetBotGoal( bot, goalOrigin )
{
    if ( !isdefined( bot ) || !isdefined( goalOrigin ) )
    {
        return;
    }

    bot botsetgoal( goalOrigin, 96 );
}

abzmGetFollowLeader()
{
    players = getplayers();

    if ( !isdefined( players ) )
    {
        return undefined;
    }

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( isdefined( player ) && isalive( player ) && !abzmIsBotEntity( player ) )
        {
            return player;
        }
    }

    return undefined;
}

abzmFindNearestDownedHuman( origin )
{
    players = getplayers();
    best = undefined;
    bestDistance = 999999;

    if ( !isdefined( players ) )
    {
        return undefined;
    }

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( !isdefined( player ) || abzmIsBotEntity( player ) )
        {
            continue;
        }

        if ( !abzmIsDownedPlayer( player ) )
        {
            continue;
        }

        currentDistance = distance( origin, player.origin );
        if ( currentDistance < bestDistance )
        {
            best = player;
            bestDistance = currentDistance;
        }
    }

    return best;
}

abzmIsDownedPlayer( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( isdefined( player.sessionstate ) && abzmStringContainsToken( player.sessionstate, "laststand" ) )
    {
        return true;
    }

    if ( isdefined( player.pers ) && isdefined( player.pers["isDown"] ) && player.pers["isDown"] )
    {
        return true;
    }

    if ( isdefined( player.revivetrigger ) || isdefined( player.revive ) || isdefined( player.laststand ) )
    {
        return true;
    }

    return false;
}

abzmFindBestThreatForBot( bot )
{
    special = abzmFindNearestSpecialZombie( bot.origin );
    if ( isdefined( special ) )
    {
        return special;
    }

    return abzmFindNearestZombie( bot.origin );
}

abzmFindNearestZombie( origin )
{
    zombies = abzmGetCachedZombieArray();
    best = undefined;
    bestDistance = 999999;

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( !abzmIsZombieEntity( zombie ) )
        {
            continue;
        }

        currentDistance = distance( origin, zombie.origin );
        if ( currentDistance < bestDistance )
        {
            best = zombie;
            bestDistance = currentDistance;
        }
    }

    return best;
}

abzmFindNearestSpecialZombie( origin )
{
    specials = abzmGetCachedSpecialArray();
    best = undefined;
    bestDistance = 999999;
    bestScore = -999999;

    for ( i = 0; i < specials.size; i++ )
    {
        zombie = specials[i];
        if ( !abzmIsZombieEntity( zombie ) )
        {
            continue;
        }

        score = abzmScoreSpecialThreat( zombie );
        currentDistance = distance( origin, zombie.origin );
        weightedScore = score * 1000 - currentDistance;

        if ( weightedScore > bestScore )
        {
            best = zombie;
            bestDistance = currentDistance;
            bestScore = weightedScore;
        }
    }

    return best;
}

abzmBuildZombieArray()
{
    zombies = [];

    abzmAppendEntArray( zombies, getentarray( "actor", "classname" ) );
    abzmAppendEntArray( zombies, getentarray( "agent", "classname" ) );
    abzmAppendEntArray( zombies, getentarray( "zombie", "classname" ) );

    return zombies;
}

abzmFilterSpecialZombies( zombies )
{
    filtered = [];

    if ( !isdefined( zombies ) )
    {
        return filtered;
    }

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( abzmIsZombieEntity( zombie ) && abzmIsSpecialZombie( zombie ) )
        {
            filtered[filtered.size] = zombie;
        }
    }

    return filtered;
}

abzmAppendEntArray( destination, source )
{
    if ( !isdefined( source ) )
    {
        return;
    }

    for ( i = 0; i < source.size; i++ )
    {
        if ( isdefined( source[i] ) && !abzmArrayContainsEntity( destination, source[i] ) )
        {
            destination[destination.size] = source[i];
        }
    }
}

abzmArrayContainsEntity( entities, target )
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

abzmGetCachedZombieArray()
{
    if ( !isdefined( level.abzmKnownZombies ) )
    {
        level.abzmKnownZombies = [];
    }

    return level.abzmKnownZombies;
}

abzmGetCachedSpecialArray()
{
    if ( !isdefined( level.abzmKnownSpecials ) )
    {
        level.abzmKnownSpecials = [];
    }

    return level.abzmKnownSpecials;
}

abzmIsZombieEntity( entity )
{
    if ( !isdefined( entity ) || !isalive( entity ) || !isdefined( entity.origin ) )
    {
        return false;
    }

    if ( isdefined( entity.classname ) && entity.classname == "actor" && ( abzmEntityMatchesToken( entity, "zombie" ) || abzmEntityMatchesToken( entity, "exo_zm" ) || abzmEntityMatchesToken( entity, "infected" ) ) )
    {
        return true;
    }

    return abzmEntityMatchesToken( entity, "zombie" ) || abzmEntityMatchesToken( entity, "exo_zm" ) || abzmEntityMatchesToken( entity, "infected" );
}

abzmIsSpecialZombie( entity )
{
    if ( !abzmIsZombieEntity( entity ) )
    {
        return false;
    }

    return abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.emp ) ||
           abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.heavy ) ||
           abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.breacher ) ||
           abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.other );
}

abzmZombieMatchesKeywordGroup( entity, keywordGroup )
{
    if ( !isdefined( entity ) || !isdefined( keywordGroup ) )
    {
        return false;
    }

    for ( i = 0; i < keywordGroup.size; i++ )
    {
        if ( abzmEntityMatchesToken( entity, keywordGroup[i] ) )
        {
            return true;
        }
    }

    return false;
}

abzmScoreSpecialThreat( entity )
{
    if ( abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.emp ) )
    {
        return 5;
    }

    if ( abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.heavy ) )
    {
        return 4;
    }

    if ( abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.breacher ) )
    {
        return 3;
    }

    return 2;
}

abzmGetPreferredWeaponForThreat( bot, entity )
{
    if ( abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.heavy ) )
    {
        return "iw5_gm6zm_mp";
    }

    if ( abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.breacher ) )
    {
        return "iw5_tridentzm_mp";
    }

    if ( abzmZombieMatchesKeywordGroup( entity, level.abzmSpecialKeywordGroups.emp ) )
    {
        return "iw5_bal27zm_mp";
    }

    return abzmGetCurrentWeaponName( bot );
}

abzmEntityMatchesToken( entity, token )
{
    if ( !isdefined( entity ) || !isdefined( token ) )
    {
        return false;
    }

    if ( isdefined( entity.targetname ) && abzmStringContainsToken( entity.targetname, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_noteworthy ) && abzmStringContainsToken( entity.script_noteworthy, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_linkname ) && abzmStringContainsToken( entity.script_linkname, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_string ) && abzmStringContainsToken( entity.script_string, token ) )
    {
        return true;
    }

    if ( isdefined( entity.model ) && abzmStringContainsToken( entity.model, token ) )
    {
        return true;
    }

    if ( isdefined( entity.classname ) && abzmStringContainsToken( entity.classname, token ) )
    {
        return true;
    }

    return false;
}

abzmTooManyZombiesNearby( origin, radius, threshold )
{
    zombies = abzmGetCachedZombieArray();
    count = 0;

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( abzmIsZombieEntity( zombie ) && distance( origin, zombie.origin ) <= radius )
        {
            count++;
            if ( count >= threshold )
            {
                return true;
            }
        }
    }

    return false;
}

abzmBuildEscapeGoal( origin, anchorOrigin )
{
    direction = vectornormalize( origin - anchorOrigin );

    if ( !isdefined( direction ) || length( direction ) <= 0 )
    {
        return origin + ( 160, 0, 0 );
    }

    return origin + ( direction * 220 );
}

abzmGetFormationGoal( leader, slotIndex )
{
    offset = ( 0, 0, 0 );

    if ( slotIndex == 0 )
    {
        offset = ( 96, 96, 0 );
    }
    else if ( slotIndex == 1 )
    {
        offset = ( -96, 96, 0 );
    }
    else
    {
        offset = ( 0, -128, 0 );
    }

    return leader.origin + offset;
}

abzmRememberOwnedWeapon( bot, weaponName )
{
    if ( !isdefined( bot ) || !isdefined( weaponName ) )
    {
        return;
    }

    if ( abzmHasRememberedWeapon( bot, weaponName ) )
    {
        return;
    }

    bot.abzmOwnedWeapons[bot.abzmOwnedWeapons.size] = weaponName;
}

abzmTrimBotsToTarget()
{
    targetCount = getdvarint( "scr_zm_autobots_count" );
    if ( targetCount < 0 )
    {
        targetCount = 0;
    }
    if ( targetCount > ABZM_MAX_BOTS )
    {
        targetCount = ABZM_MAX_BOTS;
    }

    abzmTrimBotsToCount( targetCount );
}

abzmTrimBotsToCount( targetCount )
{
    if ( !isdefined( level.abzmBots ) )
    {
        return;
    }

    trimmed = [];

    for ( i = 0; i < level.abzmBots.size; i++ )
    {
        if ( i < targetCount && isdefined( level.abzmBots[i] ) )
        {
            trimmed[trimmed.size] = level.abzmBots[i];
            continue;
        }

        extraBot = level.abzmBots[i];
        if ( isdefined( extraBot ) )
        {
            extraBot.abzmManaged = false;
            extraBot.abzmPendingDrop = true;
            extraBot bot_drop();
            abzmLog( "trimmed teammate bot slot " + extraBot.abzmSlot );
        }
    }

    level.abzmBots = trimmed;
}

abzmCountPendingDropBots()
{
    players = getplayers();
    count = 0;

    if ( !isdefined( players ) )
    {
        return 0;
    }

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( isdefined( player ) && isdefined( player.abzmPendingDrop ) && player.abzmPendingDrop )
        {
            count++;
        }
    }

    return count;
}

abzmHasRememberedWeapon( bot, weaponName )
{
    if ( !isdefined( bot ) || !isdefined( bot.abzmOwnedWeapons ) || !isdefined( weaponName ) )
    {
        return false;
    }

    for ( i = 0; i < bot.abzmOwnedWeapons.size; i++ )
    {
        if ( bot.abzmOwnedWeapons[i] == weaponName )
        {
            return true;
        }
    }

    return false;
}

abzmHasPerk( bot, perkName )
{
    if ( !isdefined( bot ) || !isdefined( perkName ) )
    {
        return false;
    }

    if ( !isdefined( bot.abzmPerks ) )
    {
        return false;
    }

    if ( isdefined( bot.abzmPerks[perkName] ) && bot.abzmPerks[perkName] )
    {
        return true;
    }

    if ( getdvarint( "scr_zm_autobots_map_hooks" ) <= 0 && isdefined( bot.abzmSimulatedPerks ) && isdefined( bot.abzmSimulatedPerks[perkName] ) && bot.abzmSimulatedPerks[perkName] )
    {
        return true;
    }

    return false;
}

abzmGetCurrentWeaponName( bot )
{
    if ( !isdefined( bot ) || !isdefined( bot.abzmWeaponIndex ) )
    {
        return level.abzmWeaponProgression[0];
    }

    if ( bot.abzmWeaponIndex < 0 || bot.abzmWeaponIndex >= level.abzmWeaponProgression.size )
    {
        return level.abzmWeaponProgression[0];
    }

    return level.abzmWeaponProgression[bot.abzmWeaponIndex];
}

abzmSpendPoints( bot, cost )
{
    if ( !isdefined( bot ) )
    {
        return false;
    }

    if ( cost < 0 )
    {
        cost = 0;
    }

    if ( !isdefined( bot.abzmPoints ) )
    {
        bot.abzmPoints = 0;
    }

    if ( bot.abzmPoints < cost )
    {
        return false;
    }

    bot.abzmPoints -= cost;
    return true;
}

abzmIsManagedBot( entity )
{
    return isdefined( entity ) && isdefined( entity.abzmManaged ) && entity.abzmManaged;
}

abzmIsBotEntity( entity )
{
    if ( !isdefined( entity ) )
    {
        return false;
    }

    if ( abzmIsManagedBot( entity ) )
    {
        return true;
    }

    if ( isdefined( entity.pers ) && isdefined( entity.pers["isBot"] ) )
    {
        return entity.pers["isBot"];
    }

    return false;
}

abzmShouldRunHere()
{
    if ( isdefined( level.zombiemode ) && level.zombiemode )
    {
        return true;
    }

    if ( isdefined( level.zombieMap ) && level.zombieMap )
    {
        return true;
    }

    if ( isdefined( level.gametype ) && abzmStringContainsToken( level.gametype, "zom" ) )
    {
        return true;
    }

    if ( abzmDvarContainsToken( "ui_gametype", "zom" ) || abzmDvarContainsToken( "g_gametype", "zom" ) )
    {
        return true;
    }

    if ( isdefined( level.playlist ) && abzmStringContainsToken( level.playlist, "zombie" ) )
    {
        return true;
    }

    mapname = getdvar( "mapname" );
    if ( !isdefined( mapname ) && isdefined( level.mapname ) )
    {
        mapname = level.mapname;
    }

    return abzmIsKnownZombieMap( mapname );
}

abzmDvarContainsToken( dvarName, token )
{
    return abzmStringContainsToken( getdvar( dvarName ), token );
}

abzmIsKnownZombieMap( mapname )
{
    if ( !isdefined( mapname ) )
    {
        return false;
    }

    lowered = tolower( mapname + "" );

    if ( strlen( lowered ) >= 3 && getsubstr( lowered, 0, 3 ) == "zm_" )
    {
        return true;
    }

    return lowered == "zombie_outbreak" || lowered == "zombie_infection" || lowered == "zombie_carrier" || lowered == "zombie_descent";
}

abzmStringContainsToken( value, token )
{
    if ( !isdefined( value ) || !isdefined( token ) )
    {
        return false;
    }

    return issubstr( tolower( value + "" ), tolower( token + "" ) );
}

abzmReadScanInterval()
{
    intervalMs = getdvarint( "scr_zm_autobots_scan_interval_ms" );
    if ( intervalMs < 100 )
    {
        intervalMs = 100;
    }

    return intervalMs / 1000.0;
}

abzmLog( message )
{
    if ( getdvarint( "scr_zm_autobots_debug" ) <= 0 )
    {
        return;
    }

    if ( !isdefined( message ) )
    {
        message = "undefined";
    }

    now = 0;
    if ( isdefined( level.time ) )
    {
        now = level.time;
    }

    minGapMs = int( getdvarint( "scr_zm_autobots_debug_log_seconds" ) * 1000.0 );
    if ( minGapMs < 0 )
    {
        minGapMs = 0;
    }

    if ( isdefined( level.abzmLastLogTime ) && now - level.abzmLastLogTime < minGapMs )
    {
        return;
    }

    level.abzmLastLogTime = now;
    println( "[ABZM] " + message );
}

abzmWarnOnce( key, message )
{
    if ( getdvarint( "scr_zm_autobots_debug" ) <= 0 )
    {
        return;
    }

    if ( !isdefined( level.abzmWarned ) )
    {
        level.abzmWarned = [];
    }

    if ( isdefined( level.abzmWarned[key] ) )
    {
        return;
    }

    level.abzmWarned[key] = true;
    println( "[ABZM] " + message );
}

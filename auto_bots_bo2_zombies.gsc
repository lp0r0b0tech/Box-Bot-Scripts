// Auto Bots + BO2 Feel Zombies Mod for Advanced Warfare Exo Zombies (S1x)
//
// Self-contained S1x entry script. Keep the constants grouped at the top so the
// package can be tuned quickly without hunting through the logic below.
//
// Compatibility notes:
// - Avoid relying on a custom GetMode() helper; use local zombies-context checks.
// - Use polling fallbacks for zombies/power-ups because notify names can vary by build.
// - Keep interactable matching token-driven so AW/S1x map trigger names are easy to retune.

#define ABZM_DEFAULT_AUTOBOTS_ENABLED         0
#define ABZM_DEFAULT_BOT_COUNT                3
#define ABZM_DEFAULT_BOT_SKILL                1.0
#define ABZM_DEFAULT_BOTS_CAN_REVIVE          1
#define ABZM_DEFAULT_BOTS_AUTO_BUY_PERKS      1
#define ABZM_DEFAULT_BOTS_AUTO_BUY_UPGRADES   1
#define ABZM_DEFAULT_BOTS_USE_EQUIPMENT       1
#define ABZM_DEFAULT_BO2_TUNING_ENABLED       1
#define ABZM_DEFAULT_BOT_ACCURACY             9.99
#define ABZM_DEFAULT_BOT_REACTION_TIME        0.0
#define ABZM_DEFAULT_BOT_MAX_HEALTH           2500
#define ABZM_DEFAULT_BOT_AGGRESSION           9.99
#define ABZM_DEFAULT_PERK_COST                2000
#define ABZM_DEFAULT_WEAPON_COST              1500
#define ABZM_DEFAULT_MYSTERY_COST             950
#define ABZM_DEFAULT_PACKAPUNCH_COST          5000
#define ABZM_DEFAULT_DOOR_COST                1250
#define ABZM_DEFAULT_EXO_COST                 2000
#define ABZM_DEFAULT_PERK_LIMIT               6
#define ABZM_REVIVE_STATUS_FAILED             0
#define ABZM_REVIVE_STATUS_FALLBACK           -1
#define ABZM_REVIVE_STATUS_SUCCESS            1
#define ABZM_WEAK_WEAPON_TOKEN_ATLAS45        "atlas45"
#define ABZM_WEAK_WEAPON_TOKEN_PISTOL         "pistol"
#define ABZM_WEAK_WEAPON_TOKEN_STARTER        "starter"
#define ABZM_WEAK_WEAPON_TOKEN_MP11           "mp11"
#define ABZM_WEAK_WEAPON_TOKEN_RW1            "rw1"
#define ABZM_PERK_PRIORITY_QUICK_REVIVE       10
#define ABZM_PERK_PRIORITY_HEALTH             9
#define ABZM_PERK_PRIORITY_SPEED              8
#define ABZM_PERK_PRIORITY_DAMAGE             7
#define ABZM_PERK_PRIORITY_STAMINA            6
#define ABZM_PERK_PRIORITY_DEFAULT            5
#define ABZM_DEFAULT_SPRINT_ROUND             6
#define ABZM_DEFAULT_CRAWLER_CHANCE           0.10
#define ABZM_DEFAULT_SPECIAL_ROUND_INTERVAL   5
#define ABZM_DEFAULT_SPECIAL_ROUND_OFFSET     5
#define ABZM_DEFAULT_DROPS_ENABLED            1

#define ABZM_BO2_BASE_HEALTH                  150
#define ABZM_BO2_HEALTH_INCREMENT             100
#define ABZM_BO2_HEALTH_CURVE_ROUND           10
#define ABZM_BO2_HEALTH_CURVE_MULTIPLIER      1.10
#define ABZM_BO2_HEALTH_CAP                   35000
#define ABZM_BO2_EASY_PHASE_END_ROUND         55
#define ABZM_BO2_EASY_PHASE_TARGET_LEGACY_ROUND 20
#define ABZM_BO2_REPLAY_PHASE_START_ROUND     56
#define ABZM_BO2_REPLAY_PHASE_END_ROUND       100
#define ABZM_BO2_REPLAY_PHASE_LEGACY_START_ROUND 2
#define ABZM_BO2_REPLAY_PHASE_LEGACY_END_ROUND 55

#define ABZM_BO2_WALK_SPEED                   110
#define ABZM_BO2_RUN_SPEED                    150
#define ABZM_BO2_SPRINT_SPEED                 190
#define ABZM_BO2_CRAWLER_SPEED                65

#define ABZM_BO2_KILL_POINTS                  60
#define ABZM_BO2_HEADSHOT_BONUS               40
#define ABZM_BO2_MELEE_POINTS                 130
#define ABZM_BO2_REVIVE_POINTS                250
#define ABZM_BO2_BLEEDOUT_TIME                45
#define ABZM_BO2_REVIVE_TIME                  5
#define ABZM_BO2_REVIVE_RANGE                 96
#define ABZM_INTERACT_RANGE                   96
#define ABZM_SHARED_PURCHASE_COOLDOWN_MS      15000
#define ABZM_SHARED_PURCHASE_RETRY_COOLDOWN_MS 2000
#define ABZM_SHARED_PURCHASE_RESERVATION_MS   1500
#define ABZM_PACKAPUNCH_CONFIRMATION_FALLBACK_MS 3000
#define ABZM_MAX_PACKAPUNCH_LEVEL             25
#define ABZM_PURCHASE_COOLDOWN_SEC            1.5
#define ABZM_PERK_PURCHASE_COOLDOWN_SEC       5.0
#define ABZM_BO2_RUN_ROUND                    3
#define ABZM_BO2_SPECIAL_HEALTH_SCALE          0.75
#define ABZM_BO2_SPECIAL_SPEED_BONUS           20

#define ABZM_BO2_INSTAKILL_DURATION           30
#define ABZM_BO2_DOUBLEPOINTS_DURATION        30
#define ABZM_BO2_NUKE_DELAY                   3
#define ABZM_BO2_DROP_WEIGHT_INSTAKILL        10
#define ABZM_BO2_DROP_WEIGHT_DOUBLEPOINTS     10
#define ABZM_BO2_DROP_WEIGHT_NUKE             8
#define ABZM_BO2_DROP_WEIGHT_MAXAMMO          6
#define ABZM_BO2_DROP_WEIGHT_CARPENTER        6
#define ABZM_BO2_DROP_WEIGHT_2XP              0

main()
{
    init();
}

resolveTrackedPackAPunchLevel( existingTrackedUpgradeLevel, previousUpgradeLevel, observedUpgradeLevel )
{
    if ( isdefined( observedUpgradeLevel ) && observedUpgradeLevel > 0 )
    {
        return observedUpgradeLevel;
    }

    if ( isdefined( existingTrackedUpgradeLevel ) && existingTrackedUpgradeLevel > 0 )
    {
        return existingTrackedUpgradeLevel;
    }

    return max( 1, previousUpgradeLevel + 1 );
}

doesPackAPunchConfirmationSequenceSucceed( previousWeaponKey, previousUpgradeLevel, weaponKeys, upgradeLevels )
{
    if ( !isdefined( weaponKeys ) || !isdefined( upgradeLevels ) )
    {
        return false;
    }

    steps = weaponKeys.size;
    if ( upgradeLevels.size < steps )
    {
        steps = upgradeLevels.size;
    }

    for ( i = 0; i < steps; i++ )
    {
        if ( isPackAPunchUpgradeConfirmedForState( previousWeaponKey, previousUpgradeLevel, weaponKeys[i], upgradeLevels[i] ) )
        {
            return true;
        }
    }

    return false;
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
    wait 0.25;

    if ( !abzmIsZombieContext() )
    {
        return;
    }

    level.abzm = buildModState();
    initDvars();
    level thread abzmBoot();
}

abzmIsZombieContext()
{
    if ( isdefined( level.zombiemode ) && level.zombiemode )
    {
        return true;
    }

    if ( isdefined( level.zombieMap ) && level.zombieMap )
    {
        return true;
    }

    if ( isdefined( level.gametype ) && stringContainsToken( level.gametype, "zom" ) )
    {
        return true;
    }

    if ( dvarContainsToken( "ui_gametype", "zom" ) || dvarContainsToken( "g_gametype", "zom" ) )
    {
        return true;
    }

    return isKnownZombieMap( getdvar( "mapname" ) );
}

dvarContainsToken( dvarName, token )
{
    value = getdvar( dvarName );
    return stringContainsToken( value, token );
}

stringContainsToken( value, token )
{
    if ( !isdefined( value ) || !isdefined( token ) )
    {
        return false;
    }

    return issubstr( value, token );
}

isKnownZombieMap( mapname )
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

buildModState()
{
    state = spawnstruct();
    state.enabled = false;
    state.round = 1;
    state.lastSpecialRound = 0;
    state.forceSpecialRound = false;
    state.trackedZombies = [];
    state.interactableCandidates = [];
    state.interactableCacheTime = 0;
    state.purchaseItemCandidates = [];
    state.purchaseItemCacheTime = -999999;
    state.purchaseItemSourceCacheTime = -999999;
    state.sharedPurchasedNodes = [];
    state.weakWeaponTokens = [];
    state.weakWeaponTokens[0] = ABZM_WEAK_WEAPON_TOKEN_ATLAS45;
    state.weakWeaponTokens[1] = ABZM_WEAK_WEAPON_TOKEN_PISTOL;
    state.weakWeaponTokens[2] = ABZM_WEAK_WEAPON_TOKEN_STARTER;
    state.weakWeaponTokens[3] = ABZM_WEAK_WEAPON_TOKEN_MP11;
    state.weakWeaponTokens[4] = ABZM_WEAK_WEAPON_TOKEN_RW1;
    state.botNames = [];
    state.botNames[0] = "Atlas-1";
    state.botNames[1] = "Atlas-2";
    state.botNames[2] = "Atlas-3";
    state.botNames[3] = "Atlas-4";
    return state;
}

initDvars()
{
    setdvarifuninitialized( "scr_zm_autobots_enable", ABZM_DEFAULT_AUTOBOTS_ENABLED );
    setdvarifuninitialized( "scr_zm_autobots_count", ABZM_DEFAULT_BOT_COUNT );
    setdvarifuninitialized( "scr_zm_autobots_skill", ABZM_DEFAULT_BOT_SKILL );
    setdvarifuninitialized( "scr_zm_autobots_revive", ABZM_DEFAULT_BOTS_CAN_REVIVE );
    setdvarifuninitialized( "scr_zm_autobots_auto_buy_perks", ABZM_DEFAULT_BOTS_AUTO_BUY_PERKS );
    setdvarifuninitialized( "scr_zm_autobots_auto_buy_upgrades", ABZM_DEFAULT_BOTS_AUTO_BUY_UPGRADES );
    setdvarifuninitialized( "scr_zm_autobots_use_equipment", ABZM_DEFAULT_BOTS_USE_EQUIPMENT );
    // Teammate-only combat profile overrides. Difficulty accepts engine strings such as recruit/regular/hardened/veteran/ultra.
    // Accuracy and aggression are scalar multipliers, reaction_time is the bot think delay in seconds, and max_health is applied per spawn.
    setdvarifuninitialized( "scr_zm_autobots_difficulty", "ultra" );
    setdvarifuninitialized( "scr_zm_autobots_accuracy", ABZM_DEFAULT_BOT_ACCURACY );
    setdvarifuninitialized( "scr_zm_autobots_reaction_time", ABZM_DEFAULT_BOT_REACTION_TIME );
    setdvarifuninitialized( "scr_zm_autobots_max_health", ABZM_DEFAULT_BOT_MAX_HEALTH );
    setdvarifuninitialized( "scr_zm_autobots_aggression", ABZM_DEFAULT_BOT_AGGRESSION );
    // Purchase thresholds are point requirements checked before bots attempt each buy type; max_perks caps unique perk keys per bot.
    setdvarifuninitialized( "scr_zm_autobots_perk_cost", ABZM_DEFAULT_PERK_COST );
    setdvarifuninitialized( "scr_zm_autobots_weapon_cost", ABZM_DEFAULT_WEAPON_COST );
    setdvarifuninitialized( "scr_zm_autobots_mystery_cost", ABZM_DEFAULT_MYSTERY_COST );
    setdvarifuninitialized( "scr_zm_autobots_packapunch_cost", ABZM_DEFAULT_PACKAPUNCH_COST );
    setdvarifuninitialized( "scr_zm_autobots_door_cost", ABZM_DEFAULT_DOOR_COST );
    setdvarifuninitialized( "scr_zm_autobots_exo_cost", ABZM_DEFAULT_EXO_COST );
    setdvarifuninitialized( "scr_zm_autobots_max_perks", ABZM_DEFAULT_PERK_LIMIT );
    setdvarifuninitialized( "scr_zm_autobots_run_self_tests", 0 );

    setdvarifuninitialized( "scr_zm_bo2_enable", ABZM_DEFAULT_BO2_TUNING_ENABLED );
    setdvarifuninitialized( "scr_zm_bo2_sprint_round", ABZM_DEFAULT_SPRINT_ROUND );
    setdvarifuninitialized( "scr_zm_bo2_crawler_chance", ABZM_DEFAULT_CRAWLER_CHANCE );
    setdvarifuninitialized( "scr_zm_bo2_special_round_interval", ABZM_DEFAULT_SPECIAL_ROUND_INTERVAL );
    setdvarifuninitialized( "scr_zm_bo2_special_round_offset", ABZM_DEFAULT_SPECIAL_ROUND_OFFSET );
    setdvarifuninitialized( "scr_zm_bo2_powerups_enable", ABZM_DEFAULT_DROPS_ENABLED );
}

runSelfTestsIfEnabled()
{
    if ( getdvarint( "scr_zm_autobots_run_self_tests" ) <= 0 || !isDevelopmentModeEnabled() )
    {
        return;
    }

    runReviveOutcomeSelfTests();
    runBotLifecycleSelfTests();
    runSharedPurchaseSelfTests();
    runPerkPurchaseSelfTests();
    runCombatProfileSelfTests();
    runWeaponPurchaseRoutingSelfTests();
    runPurchaseConfirmationSelfTests();
}

isDevelopmentModeEnabled()
{
    return getdvarint( "developer" ) > 0 || getdvarint( "developer_script" ) > 0;
}

runReviveOutcomeSelfTests()
{
    downed = spawnstruct();
    downed.abzmDowned = false;
    reportSelfTestResult( "revive_interaction_cleared_downed", getReviveInteractionCompletionStatus( downed ) == ABZM_REVIVE_STATUS_SUCCESS );
    reportSelfTestResult( "revive_interaction_missing_entity", getReviveInteractionCompletionStatus( undefined ) == ABZM_REVIVE_STATUS_FALLBACK );

    downed = spawnstruct();
    downed.abzmDowned = true;
    reportSelfTestResult( "revive_interaction_still_downed", getReviveInteractionCompletionStatus( downed ) == ABZM_REVIVE_STATUS_FAILED );
}

reportSelfTestResult( testName, passed )
{
    result = "passed";
    if ( !passed )
    {
        result = "FAILED";
    }

    println( "[ABZM][SELFTEST] " + testName + ": " + result );
}

runBotLifecycleSelfTests()
{
    bot = spawnstruct();
    bot initializeBotPurchaseState();
    reportSelfTestResult( "bot_lifecycle_purchase_state_init", bot.abzmPerkPurchases == 0 && bot.abzmPurchasedPerkNodes.size == 0 && bot.abzmLastWeaponPurchaseStateKey == "" && bot.abzmLastPackAPunchWeaponKey == "" && bot.abzmLastPackAPunchUpgradeLevel == 0 && bot.abzmPackAPunchWeaponEntries.size == 0 );

    bot.abzmPerkPurchases = 3;
    bot.abzmPurchasedPerkNodes[0] = "health|test";
    bot.abzmLastPerkPurchaseTime = 1;
    bot.abzmLastPurchaseTime = 2;
    bot.abzmLastWeaponPurchaseStateKey = "starter|true|true";
    bot.abzmLastPackAPunchWeaponKey = "test_weapon";
    bot.abzmLastPackAPunchUpgradeLevel = 1;
    entry = spawnstruct();
    entry.weaponKey = "test_weapon";
    entry.upgradeLevel = 1;
    bot.abzmPackAPunchWeaponEntries[0] = entry;
    bot clearBotPurchaseState();
    reportSelfTestResult( "bot_lifecycle_purchase_state_reset", bot.abzmPerkPurchases == 0 && bot.abzmPurchasedPerkNodes.size == 0 && !isdefined( bot.abzmLastPerkPurchaseTime ) && !isdefined( bot.abzmLastPurchaseTime ) && bot.abzmLastWeaponPurchaseStateKey == "" && bot.abzmLastPackAPunchWeaponKey == "" && bot.abzmLastPackAPunchUpgradeLevel == 0 && bot.abzmPackAPunchWeaponEntries.size == 0 );

    reportSelfTestResult( "bot_lifecycle_difficulty_mapping", resolveBotSkillDifficulty( "ultra" ) == "veteran" );
}

runSharedPurchaseSelfTests()
{
    bot = spawnstruct();
    node = spawnstruct();
    node.target = "abzm_test_door";

    previousSharedNodes = level.abzm.sharedPurchasedNodes;
    level.abzm.sharedPurchasedNodes = [];
    bot markSharedPurchase( node, "door", false );
    sharedPurchaseBlocksActiveNode = alreadyBoughtSharedNode( node, "door" );
    level.abzm.sharedPurchasedNodes = previousSharedNodes;
    reportSelfTestResult( "shared_purchase_blocks_active_node", sharedPurchaseBlocksActiveNode );

    previousSharedNodes = level.abzm.sharedPurchasedNodes;
    level.abzm.sharedPurchasedNodes = [];
    bot markSharedPurchase( node, "door", false );
    level.abzm.sharedPurchasedNodes[0].expiresAt = gettime() - 1;
    sharedPurchaseExpiresAndCompacts = !alreadyBoughtSharedNode( node, "door" ) && level.abzm.sharedPurchasedNodes.size == 0;
    level.abzm.sharedPurchasedNodes = previousSharedNodes;
    reportSelfTestResult( "shared_purchase_expires_and_compacts", sharedPurchaseExpiresAndCompacts );

    previousSharedNodes = level.abzm.sharedPurchasedNodes;
    level.abzm.sharedPurchasedNodes = [];
    bot markSharedPurchase( node, "door", true );
    fallbackSharedCooldownMs = level.abzm.sharedPurchasedNodes[0].expiresAt - gettime();
    level.abzm.sharedPurchasedNodes = previousSharedNodes;
    reportSelfTestResult( "shared_purchase_fallback_uses_retry_cooldown", fallbackSharedCooldownMs <= ABZM_SHARED_PURCHASE_RETRY_COOLDOWN_MS && fallbackSharedCooldownMs > 0 );

    previousSharedNodes = level.abzm.sharedPurchasedNodes;
    level.abzm.sharedPurchasedNodes = [];
    reserveSharedPurchase( node, "door" );
    reservationBlocksButIsNotBought = isSharedPurchaseBlocked( node, "door" ) && !alreadyBoughtSharedNode( node, "door" );
    level.abzm.sharedPurchasedNodes = previousSharedNodes;
    reportSelfTestResult( "shared_purchase_reservation_stays_separate", reservationBlocksButIsNotBought );

    previousSharedNodes = level.abzm.sharedPurchasedNodes;
    level.abzm.sharedPurchasedNodes = [];
    reserveSharedPurchase( node, "packapunch" );
    bot markSharedPurchase( node, "packapunch", false );
    clearSharedPurchaseReservation( node, "packapunch" );
    packAPunchPurchaseSurvivesReservationCleanup = alreadyBoughtSharedNode( node, "packapunch" );
    level.abzm.sharedPurchasedNodes = previousSharedNodes;
    reportSelfTestResult( "shared_purchase_packapunch_cleanup_preserves_confirmed_entry", packAPunchPurchaseSurvivesReservationCleanup );

    previousSharedNodes = level.abzm.sharedPurchasedNodes;
    level.abzm.sharedPurchasedNodes = [];
    reserveSharedPurchase( node, "mystery" );
    clearSharedPurchaseReservation( node, "mystery" );
    fallbackMysteryStaysUnconfirmed = !alreadyBoughtSharedNode( node, "mystery" );
    level.abzm.sharedPurchasedNodes = previousSharedNodes;
    reportSelfTestResult( "shared_purchase_mystery_fallback_stays_unconfirmed", fallbackMysteryStaysUnconfirmed );

    previousSharedNodes = level.abzm.sharedPurchasedNodes;
    level.abzm.sharedPurchasedNodes = [];
    reserveSharedPurchase( node, "packapunch" );
    clearSharedPurchaseReservation( node, "packapunch" );
    fallbackPackAPunchStaysUnconfirmed = !alreadyBoughtSharedNode( node, "packapunch" );
    level.abzm.sharedPurchasedNodes = previousSharedNodes;
    reportSelfTestResult( "shared_purchase_packapunch_fallback_stays_unconfirmed", fallbackPackAPunchStaysUnconfirmed );
}

runPerkPurchaseSelfTests()
{
    bot = spawnstruct();
    bot initializeBotPurchaseState();

    perkNode = spawnstruct();
    perkNode.targetname = "health_perk_test";
    bot markPerkPurchase( perkNode );
    firstPerkCount = bot.abzmPerkPurchases;
    firstPerkOwned = bot alreadyBoughtPerkNode( perkNode );

    bot markPerkPurchase( perkNode );
    duplicatePerkCount = bot.abzmPerkPurchases;

    reportSelfTestResult( "perk_purchase_tracks_unique_node", firstPerkCount == 1 && firstPerkOwned );
    reportSelfTestResult( "perk_purchase_suppresses_duplicates", duplicatePerkCount == 1 );
}

runCombatProfileSelfTests()
{
    if ( !isdefined( level.abzm ) )
    {
        return;
    }

    previousBotDifficulty = level.abzm.botDifficulty;
    previousBotAccuracy = level.abzm.botAccuracy;
    previousBotReactionTime = level.abzm.botReactionTime;
    previousBotMaxHealth = level.abzm.botMaxHealth;
    previousBotAggression = level.abzm.botAggression;

    bot = spawnstruct();
    bot.abzmIsBot = true;
    bot.pers["isBot"] = true;
    bot.maxhealth = 1000;
    bot.health = 500;
    level.abzm.botDifficulty = "ultra";
    level.abzm.botAccuracy = 9.99;
    level.abzm.botReactionTime = 0.0;
    level.abzm.botMaxHealth = 2000;
    level.abzm.botAggression = 9.99;

    bot applyBotCombatProfile();
    preservesHealthRatio = bot.health == 1000;

    level.abzm.botDifficulty = previousBotDifficulty;
    level.abzm.botAccuracy = previousBotAccuracy;
    level.abzm.botReactionTime = previousBotReactionTime;
    level.abzm.botMaxHealth = previousBotMaxHealth;
    level.abzm.botAggression = previousBotAggression;
    reportSelfTestResult( "combat_profile_preserves_health_ratio", preservesHealthRatio );
}

runWeaponPurchaseRoutingSelfTests()
{
    explicitWeaponNode = spawnstruct();
    explicitWeaponNode.targetname = "weapon_wallbuy_test";

    genericWeaponNode = spawnstruct();
    genericWeaponNode.targetname = "buy_weapon_fallback_test";

    reportSelfTestResult( "weapon_routing_explicit_marker_stays_weapon", isDesiredInteractable( explicitWeaponNode, "weapon" ) && !isDesiredInteractable( explicitWeaponNode, "generic_weapon_buy" ) );
    reportSelfTestResult( "weapon_routing_generic_marker_stays_generic", !isDesiredInteractable( genericWeaponNode, "weapon" ) && isDesiredInteractable( genericWeaponNode, "generic_weapon_buy" ) );
    reportSelfTestResult( "weapon_routing_state_change_reopens_purchase", shouldResetWeaponPurchaseStateKey( "starter|true|true", "starter|false|false" ) );
    reportSelfTestResult( "weapon_routing_weak_weapon_token_matches", isWeakWeaponName( "atlas45_pistol_mp" ) );
    reportSelfTestResult( "weapon_routing_strong_weapon_stays_strong", !isWeakWeaponName( "bal27_ar" ) );
}

runPurchaseConfirmationSelfTests()
{
    reportSelfTestResult( "mystery_confirmation_requires_change", !isMysteryBoxRewardConfirmedForState( "weapon_a", 0, "weapon_a", 0 ) );
    reportSelfTestResult( "pap_confirmation_requires_same_weapon_upgrade", !isPackAPunchUpgradeConfirmedForState( "weapon_a", 0, "weapon_b", 1 ) && isPackAPunchUpgradeConfirmedForState( "weapon_a", 0, "weapon_a", 1 ) );
    reportSelfTestResult( "pap_wait_confirmation_rejects_weapon_swap", !doesPackAPunchConfirmationSequenceSucceed( "weapon_a", 0, [ "weapon_b", "weapon_b" ], [ 1, 1 ] ) );
    reportSelfTestResult( "pap_tracking_requires_live_upgrade_increase", resolveTrackedPackAPunchLevel( 1, 1, 0 ) == 1 );
    reportSelfTestResult( "pap_level_cap_supports_requested_ceiling", min( 30, ABZM_MAX_PACKAPUNCH_LEVEL ) == 25 );
}

runDeferredSelfTests()
{
    wait 1.0;
    runSelfTestsIfEnabled();
}

abzmBoot()
{
    level endon( "game_ended" );

    wait 0.25;
    refreshRuntimeConfig();

    if ( !level.abzm.enabled )
    {
        return;
    }

    level thread monitorPlayerConnections();
    level thread monitorRoundState();
    level thread maintainAutoBots();
    level thread monitorZombieSpawns();
    level thread monitorPowerupSpawns();
    level thread periodicZombieRefresh();
    level thread periodicPowerupRefresh();
    if ( getdvarint( "scr_zm_autobots_run_self_tests" ) > 0 && isDevelopmentModeEnabled() )
    {
        level thread runDeferredSelfTests();
    }
}

refreshRuntimeConfig()
{
    level.abzm.autoBotsEnabled = getdvarint( "scr_zm_autobots_enable" ) > 0;
    level.abzm.botCount = abzmClamp( getdvarint( "scr_zm_autobots_count" ), 0, 4 );
    level.abzm.botSkill = abzmClamp( getdvarfloat( "scr_zm_autobots_skill" ), 0.25, 3.0 );
    level.abzm.botsCanRevive = getdvarint( "scr_zm_autobots_revive" ) > 0;
    level.abzm.botsAutoBuyPerks = getdvarint( "scr_zm_autobots_auto_buy_perks" ) > 0;
    level.abzm.botsAutoBuyUpgrades = getdvarint( "scr_zm_autobots_auto_buy_upgrades" ) > 0;
    level.abzm.botsUseEquipment = getdvarint( "scr_zm_autobots_use_equipment" ) > 0;
    level.abzm.botDifficulty = normalizeBotDifficulty( getdvar( "scr_zm_autobots_difficulty" ) );
    level.abzm.botAccuracy = abzmClamp( getdvarfloat( "scr_zm_autobots_accuracy" ), 0.0, 9.99 );
    level.abzm.botReactionTime = abzmClamp( getdvarfloat( "scr_zm_autobots_reaction_time" ), 0.0, 1.0 );
    level.abzm.botMaxHealth = max( 100, min( 2500, getdvarint( "scr_zm_autobots_max_health" ) ) );
    level.abzm.botAggression = abzmClamp( getdvarfloat( "scr_zm_autobots_aggression" ), 0.0, 9.99 );
    level.abzm.perkCost = max( 0, getdvarint( "scr_zm_autobots_perk_cost" ) );
    level.abzm.weaponCost = max( 0, getdvarint( "scr_zm_autobots_weapon_cost" ) );
    level.abzm.mysteryCost = max( 0, getdvarint( "scr_zm_autobots_mystery_cost" ) );
    level.abzm.packapunchCost = max( 0, getdvarint( "scr_zm_autobots_packapunch_cost" ) );
    level.abzm.doorCost = max( 0, getdvarint( "scr_zm_autobots_door_cost" ) );
    level.abzm.exoCost = max( 0, getdvarint( "scr_zm_autobots_exo_cost" ) );
    level.abzm.maxPerks = max( 1, getdvarint( "scr_zm_autobots_max_perks" ) );

    level.abzm.bo2Enabled = getdvarint( "scr_zm_bo2_enable" ) > 0;
    level.abzm.sprintRound = max( 1, getdvarint( "scr_zm_bo2_sprint_round" ) );
    level.abzm.crawlerChance = abzmClamp( getdvarfloat( "scr_zm_bo2_crawler_chance" ), 0.0, 1.0 );
    level.abzm.specialRoundInterval = max( 0, getdvarint( "scr_zm_bo2_special_round_interval" ) );
    level.abzm.specialRoundOffset = max( 1, getdvarint( "scr_zm_bo2_special_round_offset" ) );
    level.abzm.bo2PowerupsEnabled = getdvarint( "scr_zm_bo2_powerups_enable" ) > 0;

    level.abzm.enabled = level.abzm.autoBotsEnabled || level.abzm.bo2Enabled;
}

normalizeBotDifficulty( difficulty )
{
    if ( !isdefined( difficulty ) )
    {
        return "ultra";
    }

    difficulty = toLower( difficulty );

    if ( difficulty == "recruit" || difficulty == "regular" || difficulty == "hardened" || difficulty == "veteran" || difficulty == "ultra" )
    {
        return difficulty;
    }

    return "ultra";
}

resolveBotSkillDifficulty( difficulty )
{
    difficulty = normalizeBotDifficulty( difficulty );

    if ( difficulty == "ultra" )
    {
        return "veteran";
    }

    return difficulty;
}

applyBotCombatProfile()
{
    if ( !isBotEntity( self ) || !isdefined( level.abzm ) )
    {
        return;
    }

    previousMaxHealth = 0;
    if ( isdefined( self.maxhealth ) )
    {
        previousMaxHealth = self.maxhealth;
    }

    desiredDifficulty = resolveBotSkillDifficulty( level.abzm.botDifficulty );
    currentDifficulty = self botgetdifficulty();

    if ( !isdefined( currentDifficulty ) || currentDifficulty != desiredDifficulty )
    {
        self botsetdifficulty( desiredDifficulty );
    }

    self.abzmSkill = desiredDifficulty;
    self.botAccuracy = level.abzm.botAccuracy;
    self.reactionTime = level.abzm.botReactionTime;
    self.maxhealth = level.abzm.botMaxHealth;
    self.botAggression = level.abzm.botAggression;

    if ( !isdefined( self.health ) )
    {
        self.health = self.maxhealth;
    }
    else if ( previousMaxHealth > 0 && previousMaxHealth != self.maxhealth )
    {
        healthRatio = self.health / previousMaxHealth;
        healthRatio = abzmClamp( healthRatio, 0.0, 1.0 );
        self.health = max( 1, int( self.maxhealth * healthRatio ) );
    }
    else if ( self.health > self.maxhealth )
    {
        self.health = self.maxhealth;
    }
}

initializeBotPurchaseState()
{
    if ( !isdefined( self.abzmPerkPurchases ) )
    {
        self.abzmPerkPurchases = 0;
    }

    if ( !isdefined( self.abzmPurchasedPerkNodes ) )
    {
        self.abzmPurchasedPerkNodes = [];
    }

    if ( !isdefined( self.abzmLastWeaponPurchaseStateKey ) )
    {
        self.abzmLastWeaponPurchaseStateKey = "";
    }

    if ( !isdefined( self.abzmLastPackAPunchWeaponKey ) )
    {
        self.abzmLastPackAPunchWeaponKey = "";
    }

    if ( !isdefined( self.abzmLastPackAPunchUpgradeLevel ) )
    {
        self.abzmLastPackAPunchUpgradeLevel = 0;
    }

    if ( !isdefined( self.abzmPackAPunchWeaponEntries ) )
    {
        self.abzmPackAPunchWeaponEntries = [];
    }

}

clearBotPurchaseState()
{
    self.abzmPerkPurchases = 0;
    self.abzmPurchasedPerkNodes = [];
    self.abzmLastPerkPurchaseTime = undefined;
    self.abzmLastPurchaseTime = undefined;
    self.abzmLastWeaponPurchaseStateKey = "";
    self.abzmLastPackAPunchWeaponKey = "";
    self.abzmLastPackAPunchUpgradeLevel = 0;
    self.abzmPackAPunchWeaponEntries = [];
}

monitorPlayerConnections()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread onPlayerConnected();
    }
}

onPlayerConnected()
{
    self endon( "disconnect" );

    if ( isdefined( self.abzmConnectedHandlerStarted ) && self.abzmConnectedHandlerStarted )
    {
        return;
    }

    self.abzmConnectedHandlerStarted = true;

    if ( !isdefined( self.abzmDownedTrackerStarted ) || !self.abzmDownedTrackerStarted )
    {
        self.abzmDownedTrackerStarted = true;
        self thread trackDownedState();
    }

    for ( ;; )
    {
        self waittill( "spawned_player" );

        if ( !isdefined( self.abzmWallet ) )
        {
            self.abzmWallet = 0;
            if ( isdefined( self.score ) )
            {
                self.abzmWallet = self.score;
            }
        }

        if ( self.abzmIsBot )
        {
            initializeBotPurchaseState();
            applyBotCombatProfile();
        }

        if ( self.abzmIsBot && ( !isdefined( self.abzmLifeLoopStarted ) || !self.abzmLifeLoopStarted ) )
        {
            self.abzmLifeLoopStarted = true;
            self thread botLifeLoop();
        }
    }
}

trackDownedState()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill_any( "downed", "laststand", "bleed_out" );
        self.abzmDowned = true;
        self.abzmDownedAt = gettime();
        clearActiveReviveClaim();
        if ( self.abzmIsBot )
        {
            clearBotPurchaseState();
        }

        if ( isdefined( level.abzm ) && level.abzm.bo2Enabled )
        {
            self.abzmBleedoutTime = ABZM_BO2_BLEEDOUT_TIME;
            self notify( "abzm_cancel_bleedout" );
            self thread enforceBo2Bleedout();
        }

        self waittill_any( "revived", "spawned_player" );
        self.abzmDowned = false;
        self.abzmDownedAt = undefined;
        self.abzmBleedoutTime = ABZM_BO2_BLEEDOUT_TIME;
    }
}

enforceBo2Bleedout()
{
    self endon( "disconnect" );
    self endon( "revived" );
    self endon( "spawned_player" );
    self endon( "abzm_cancel_bleedout" );

    bleedoutTime = ABZM_BO2_BLEEDOUT_TIME;
    if ( isdefined( self.abzmBleedoutTime ) )
    {
        bleedoutTime = self.abzmBleedoutTime;
    }

    wait bleedoutTime;

    if ( self.abzmDowned )
    {
        self notify( "bleed_out" );
    }
}

monitorRoundState()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "round_start", roundNumber );
        level.abzm.round = roundNumber;
        refreshRuntimeConfig();

        if ( level.abzm.bo2Enabled )
        {
            level thread applyRoundTuning( roundNumber );
        }
    }
}

applyRoundTuning( roundNumber )
{
    level.abzm.forceSpecialRound = shouldRunSpecialRound( roundNumber );
    if ( level.abzm.forceSpecialRound )
    {
        level.abzm.lastSpecialRound = roundNumber;
    }

    retuneTrackedZombies();
}

shouldRunSpecialRound( roundNumber )
{
    if ( level.abzm.specialRoundInterval <= 0 )
    {
        return false;
    }

    return roundNumber >= level.abzm.specialRoundOffset && ((roundNumber - level.abzm.specialRoundOffset) % level.abzm.specialRoundInterval) == 0;
}

maintainAutoBots()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        refreshRuntimeConfig();

        targetBotCount = 0;
        if ( level.abzm.autoBotsEnabled )
        {
            targetBotCount = level.abzm.botCount;
        }

        trimAutoBots( targetBotCount );
        currentBots = getActiveBotCount();

        while ( currentBots < targetBotCount )
        {
            if ( spawnAutoBot( currentBots ) )
            {
                currentBots++;
            }
            else
            {
                wait 1.0;
            }

            wait 0.25;
        }

        wait 2.0;
    }
}

spawnAutoBot( botIndex )
{
    bot = addtestclient();
    if ( !isdefined( bot ) )
    {
        return false;
    }

    nameIndex = botIndex % level.abzm.botNames.size;
    bot.abzmIsBot = true;
    bot.pers["isBot"] = true;
    bot.name = level.abzm.botNames[nameIndex];
    bot.abzmSkill = resolveBotSkillDifficulty( level.abzm.botDifficulty );
    bot thread applyBotPostSpawnSetup();
    bot thread onPlayerConnected();
    return true;
}

applyBotPostSpawnSetup()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "spawned_player" );
        if ( !isBotEntity( self ) )
        {
            continue;
        }

        initializeBotPurchaseState();
        applyBotCombatProfile();
    }
}

trimAutoBots( targetBotCount )
{
    bots = getBotPlayers();

    while ( bots.size > targetBotCount )
    {
        bot = bots[bots.size - 1];
        if ( isdefined( bot ) )
        {
            bot kick();
        }

        bots = getBotPlayers();
    }
}

getBotPlayers()
{
    players = getentarray( "player", "classname" );
    bots = [];

    for ( i = 0; i < players.size; i++ )
    {
        if ( isBotEntity( players[i] ) )
        {
            bots[bots.size] = players[i];
        }
    }

    return bots;
}

botLifeLoop()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        if ( self.abzmDowned )
        {
            self waittill_any( "revived", "spawned_player", "disconnect" );
            continue;
        }

        if ( !isdefined( self.abzmBrainRunning ) || !self.abzmBrainRunning )
        {
            self.abzmBrainRunning = true;
            self thread botBrainLoop();
        }

        self waittill_any( "death", "downed", "disconnect" );
        clearActiveReviveClaim();
        self notify( "abzm_stop_brain" );
        self.abzmBrainRunning = false;
        wait 0.25;
    }
}

botBrainLoop()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "downed" );
    self endon( "abzm_stop_brain" );

    for ( ;; )
    {
        refreshRuntimeConfig();
        applyBotCombatProfile();

        if ( level.abzm.botsCanRevive && attemptBotRevive() )
        {
            wait 0.1;
            continue;
        }

        if ( shouldRetreat() )
        {
            moveToRetreatAnchor();
        }
        else
        {
            runTrainingMovement();
        }

        attemptWeaponPurchase();

        if ( level.abzm.botsAutoBuyPerks )
        {
            attemptPerkPurchase();
        }

        if ( level.abzm.botsAutoBuyUpgrades )
        {
            attemptUtilityPurchase();
        }

        if ( level.abzm.botsUseEquipment )
        {
            useEquipmentIfNeeded();
        }

        wait 0.25;
    }
}

attemptBotRevive()
{
    downed = getClosestDownedTeammate();
    if ( !isdefined( downed ) )
    {
        return false;
    }

    if ( isdefined( downed.abzmReviver ) && downed.abzmReviver != self )
    {
        return false;
    }

    downed.abzmReviver = self;
    self.abzmReviveTarget = downed;
    self.abzmState = "reviving";
    self setlookatpos( downed.origin );
    self moveto( downed.origin, 0.35 );

    reviveMoveStart = gettime();
    while ( distance( self.origin, downed.origin ) > ABZM_BO2_REVIVE_RANGE )
    {
        if ( gettime() - reviveMoveStart >= 1000 )
        {
            downed.abzmReviver = undefined;
            self.abzmReviveTarget = undefined;
            return false;
        }

        wait 0.05;
    }

    reviveProgress = 0.0;
    while ( reviveProgress < ABZM_BO2_REVIVE_TIME )
    {
        if ( !isdefined( downed ) || !downed.abzmDowned )
        {
            if ( isdefined( downed ) )
            {
                downed.abzmReviver = undefined;
            }
            self.abzmReviveTarget = undefined;
            return false;
        }

        if ( !isalive( self ) || self.abzmDowned )
        {
            downed.abzmReviver = undefined;
            self.abzmReviveTarget = undefined;
            return false;
        }

        if ( distance( self.origin, downed.origin ) > ABZM_BO2_REVIVE_RANGE )
        {
            downed.abzmReviver = undefined;
            self.abzmReviveTarget = undefined;
            return false;
        }

        wait 0.05;
        reviveProgress += 0.05;
    }

    if ( downed.abzmDowned )
    {
        reviveResult = tryUseReviveInteraction( downed );
        if ( reviveResult == ABZM_REVIVE_STATUS_SUCCESS )
        {
            downed.abzmReviver = undefined;
            self.abzmReviveTarget = undefined;
            awardPlayerPoints( self, ABZM_BO2_REVIVE_POINTS );
            return true;
        }

        if ( reviveResult == ABZM_REVIVE_STATUS_FALLBACK )
        {
            if ( !isdefined( downed ) )
            {
                self.abzmReviveTarget = undefined;
                return false;
            }

            downed.abzmBleedoutTime = ABZM_BO2_BLEEDOUT_TIME;
            signalReviveSuccess( downed, self );
        }
        else if ( reviveResult == ABZM_REVIVE_STATUS_FAILED )
        {
            downed.abzmReviver = undefined;
            self.abzmReviveTarget = undefined;
            return false;
        }

        downed.abzmReviver = undefined;
        self.abzmReviveTarget = undefined;
        awardPlayerPoints( self, ABZM_BO2_REVIVE_POINTS );
        return true;
    }

    downed.abzmReviver = undefined;
    self.abzmReviveTarget = undefined;
    return false;
}

tryUseReviveInteraction( downed )
{
    if ( !isdefined( downed ) || !downed.abzmDowned )
    {
        return ABZM_REVIVE_STATUS_FALLBACK;
    }

    reviveNode = getReviveInteractableForPlayer( downed );
    if ( !isdefined( reviveNode ) )
    {
        return ABZM_REVIVE_STATUS_FALLBACK;
    }

    if ( !moveToAndUse( reviveNode ) )
    {
        return ABZM_REVIVE_STATUS_FAILED;
    }

    start = gettime();
    maxWaitMs = int( (ABZM_BO2_REVIVE_TIME + 0.5) * 1000 );
    while ( isdefined( downed ) && downed.abzmDowned && (gettime() - start) < maxWaitMs )
    {
        wait 0.05;
    }

    return getReviveInteractionCompletionStatus( downed );
}

getReviveInteractionCompletionStatus( downed )
{
    if ( !isdefined( downed ) )
    {
        return ABZM_REVIVE_STATUS_FALLBACK;
    }

    if ( !downed.abzmDowned )
    {
        return ABZM_REVIVE_STATUS_SUCCESS;
    }

    return ABZM_REVIVE_STATUS_FAILED;
}

getReviveInteractableForPlayer( downed )
{
    if ( !isdefined( downed ) )
    {
        return undefined;
    }

    nodes = getInteractableCandidates();
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < nodes.size; i++ )
    {
        node = nodes[i];
        if ( !isDesiredInteractable( node, "revive" ) )
        {
            continue;
        }

        targetDist = distance( downed.origin, node.origin );
        botDist = distance( self.origin, node.origin );
        if ( targetDist <= ABZM_BO2_REVIVE_RANGE && botDist < bestDist )
        {
            best = node;
            bestDist = botDist;
        }
    }

    return best;
}

runTrainingMovement()
{
    target = chooseTrainingAnchor();
    if ( !isdefined( target ) )
    {
        return;
    }

    self.abzmState = "training";
    self setlookatpos( target );
    self moveto( target, 0.2 );
}

moveToRetreatAnchor()
{
    retreat = chooseRetreatAnchor();
    if ( !isdefined( retreat ) )
    {
        return;
    }

    self.abzmState = "retreat";
    self setlookatpos( retreat );
    self moveto( retreat, 0.25 );
}

attemptPerkPurchase()
{
    if ( !botCanAttemptPurchase( ABZM_PURCHASE_COOLDOWN_SEC ) || !botCanAttemptPerkPurchase( ABZM_PERK_PURCHASE_COOLDOWN_SEC ) )
    {
        return false;
    }

    if ( !hasEnoughPoints( self, level.abzm.perkCost ) )
    {
        return false;
    }

    if ( isdefined( self.abzmPurchasedPerkNodes ) && self.abzmPurchasedPerkNodes.size >= level.abzm.maxPerks )
    {
        return false;
    }

    perkNode = getBestPerkInteractable();
    if ( !isdefined( perkNode ) )
    {
        return false;
    }

    if ( !attemptPurchase( perkNode, level.abzm.perkCost ) )
    {
        return false;
    }

    if ( isdefined( self.abzmLastPurchaseUsedFallback ) && self.abzmLastPurchaseUsedFallback )
    {
        markGenericPurchase();
        return false;
    }

    markPerkPurchase( perkNode );
    return true;
}

attemptWeaponPurchase()
{
    roundNumber = max( 1, level.abzm.round );
    confirmedWeaponPurchase = false;
    weaponNode = getClosestPurchaseItemInteractable( "weapon" );
    if ( !isdefined( weaponNode ) )
    {
        weaponNode = getClosestPurchaseItemInteractable( "generic_weapon_buy" );
    }
    needsStandardWeaponPurchase = isCurrentWeaponWeak() || currentWeaponNeedsAmmo();

    if ( !botCanAttemptPurchase( ABZM_PURCHASE_COOLDOWN_SEC ) )
    {
        return false;
    }

    if ( shouldSkipWeaponRepurchase() )
    {
        return false;
    }

    if ( roundNumber >= 7 && !needsStandardWeaponPurchase )
    {
        mysteryNode = getClosestAvailableSharedInteractable( "mystery" );
        if ( isdefined( mysteryNode ) && hasEnoughPoints( self, level.abzm.mysteryCost ) && reserveSharedPurchase( mysteryNode, "mystery" ) )
        {
            previousMysteryWeaponKey = getCurrentWeaponIdentityKey();
            previousMysteryUpgradeLevel = getCurrentWeaponUpgradeLevel();
            if ( attemptPurchase( mysteryNode, level.abzm.mysteryCost ) )
            {
                if ( !self.abzmLastPurchaseUsedFallback )
                {
                    if ( waitForMysteryBoxConfirmation( previousMysteryWeaponKey, previousMysteryUpgradeLevel, 1000 ) )
                    {
                        markSharedPurchase( mysteryNode, "mystery", self.abzmLastPurchaseUsedFallback );
                        self.abzmLastWeaponPurchaseStateKey = "";
                        confirmedWeaponPurchase = true;
                    }
                    else
                    {
                        clearSharedPurchaseReservation( mysteryNode, "mystery" );
                        markGenericPurchase();
                    }
                }
                else
                {
                    clearSharedPurchaseReservation( mysteryNode, "mystery" );
                    markGenericPurchase();
                }
            }
            else
            {
                clearSharedPurchaseReservation( mysteryNode, "mystery" );
            }
        }
    }

    if ( !needsStandardWeaponPurchase )
    {
        return confirmedWeaponPurchase;
    }

    prePurchaseStateKey = getWeaponPurchaseStateKey();
    if ( isdefined( weaponNode ) && hasEnoughPoints( self, level.abzm.weaponCost ) && attemptPurchase( weaponNode, level.abzm.weaponCost ) )
    {
        if ( self.abzmLastPurchaseUsedFallback )
        {
            markGenericPurchase();
            return false;
        }

        if ( waitForWeaponPurchaseStateChange( prePurchaseStateKey, 250 ) )
        {
            markWeaponPurchase( prePurchaseStateKey );
            return true;
        }
    }

    return false;
}

attemptUtilityPurchase()
{
    if ( !botCanAttemptPurchase( ABZM_PURCHASE_COOLDOWN_SEC ) )
    {
        return false;
    }

    if ( level.abzm.botsAutoBuyUpgrades && !isCurrentWeaponWeak() && !alreadyPackAPunchedCurrentWeapon() && hasEnoughPoints( self, level.abzm.packapunchCost ) )
    {
        papNode = getClosestAvailableSharedInteractable( "packapunch" );
        if ( isdefined( papNode ) && reserveSharedPurchase( papNode, "packapunch" ) )
        {
            previousPapWeaponKey = getCurrentWeaponIdentityKey();
            previousPapUpgradeLevel = getCurrentWeaponUpgradeLevel();
            if ( attemptPurchase( papNode, level.abzm.packapunchCost ) )
            {
                if ( !isdefined( self.abzmLastPurchaseUsedFallback ) || !self.abzmLastPurchaseUsedFallback )
                {
                    if ( waitForPackAPunchConfirmation( previousPapWeaponKey, previousPapUpgradeLevel, 1000 ) )
                    {
                        markSharedPurchase( papNode, "packapunch", self.abzmLastPurchaseUsedFallback );
                        self.abzmLastWeaponPurchaseStateKey = "";
                        markPackAPunchPurchase( previousPapWeaponKey, previousPapUpgradeLevel );
                        return true;
                    }
                }

                clearSharedPurchaseReservation( papNode, "packapunch" );
                markGenericPurchase();
                if ( isdefined( self.abzmLastPurchaseUsedFallback ) && self.abzmLastPurchaseUsedFallback )
                {
                    return false;
                }
                return false;
            }

            clearSharedPurchaseReservation( papNode, "packapunch" );
        }
    }

    if ( hasEnoughPoints( self, level.abzm.doorCost ) )
    {
        doorNode = getClosestAvailableSharedInteractable( "door" );
        if ( isdefined( doorNode ) && reserveSharedPurchase( doorNode, "door" ) )
        {
            if ( attemptPurchase( doorNode, level.abzm.doorCost ) )
            {
                if ( !isdefined( self.abzmLastPurchaseUsedFallback ) || !self.abzmLastPurchaseUsedFallback )
                {
                    markSharedPurchase( doorNode, "door", self.abzmLastPurchaseUsedFallback );
                    return true;
                }

                clearSharedPurchaseReservation( doorNode, "door" );
                markGenericPurchase();
                return false;
            }

            clearSharedPurchaseReservation( doorNode, "door" );
        }
    }

    if ( hasEnoughPoints( self, level.abzm.exoCost ) )
    {
        exoNode = getClosestAvailableSharedInteractable( "exo" );
        if ( isdefined( exoNode ) && reserveSharedPurchase( exoNode, "exo" ) )
        {
            if ( attemptPurchase( exoNode, level.abzm.exoCost ) )
            {
                if ( !isdefined( self.abzmLastPurchaseUsedFallback ) || !self.abzmLastPurchaseUsedFallback )
                {
                    markSharedPurchase( exoNode, "exo", self.abzmLastPurchaseUsedFallback );
                    return true;
                }

                clearSharedPurchaseReservation( exoNode, "exo" );
                markGenericPurchase();
                return false;
            }

            clearSharedPurchaseReservation( exoNode, "exo" );
        }
    }

    return false;
}

botCanAttemptPurchase( cooldownSec )
{
    if ( !isdefined( self.abzmLastPurchaseTime ) )
    {
        return true;
    }

    return ((gettime() - self.abzmLastPurchaseTime) / 1000.0) >= cooldownSec;
}

botCanAttemptPerkPurchase( cooldownSec )
{
    if ( !isdefined( self.abzmLastPerkPurchaseTime ) )
    {
        return true;
    }

    return ((gettime() - self.abzmLastPerkPurchaseTime) / 1000.0) >= cooldownSec;
}

markGenericPurchase()
{
    self.abzmLastPurchaseTime = gettime();
}

markWeaponPurchase( previousStateKey )
{
    currentStateKey = getWeaponPurchaseStateKey();
    self.abzmLastWeaponPurchaseStateKey = "";
    if ( currentStateKey != previousStateKey )
    {
        self.abzmLastWeaponPurchaseStateKey = currentStateKey;
    }

    markGenericPurchase();
}

shouldSkipWeaponRepurchase()
{
    if ( !isdefined( self.abzmLastWeaponPurchaseStateKey ) || self.abzmLastWeaponPurchaseStateKey == "" )
    {
        return false;
    }

    currentStateKey = getWeaponPurchaseStateKey();
    if ( shouldResetWeaponPurchaseStateKey( self.abzmLastWeaponPurchaseStateKey, currentStateKey ) )
    {
        self.abzmLastWeaponPurchaseStateKey = "";
        return false;
    }

    return true;
}

shouldResetWeaponPurchaseStateKey( previousStateKey, currentStateKey )
{
    return previousStateKey != currentStateKey;
}

waitForWeaponPurchaseStateChange( previousStateKey, maxWaitMs )
{
    start = gettime();
    while ( (gettime() - start) < maxWaitMs )
    {
        if ( shouldResetWeaponPurchaseStateKey( previousStateKey, getWeaponPurchaseStateKey() ) )
        {
            return true;
        }

        wait 0.05;
    }

    return shouldResetWeaponPurchaseStateKey( previousStateKey, getWeaponPurchaseStateKey() );
}

waitForMysteryBoxConfirmation( previousWeaponKey, previousUpgradeLevel, maxWaitMs )
{
    start = gettime();
    while ( (gettime() - start) < maxWaitMs )
    {
        if ( isMysteryBoxRewardConfirmed( previousWeaponKey, previousUpgradeLevel ) )
        {
            return true;
        }

        wait 0.05;
    }

    return isMysteryBoxRewardConfirmed( previousWeaponKey, previousUpgradeLevel );
}

markPackAPunchPurchase( weaponKey, previousUpgradeLevel )
{
    self initializeBotPurchaseState();
    currentWeaponKey = weaponKey;
    if ( !isdefined( currentWeaponKey ) || currentWeaponKey == "" )
    {
        return;
    }

    observedUpgradeLevel = 0;
    if ( getCurrentWeaponIdentityKey() == currentWeaponKey )
    {
        observedUpgradeLevel = getCurrentWeaponUpgradeLevel();
    }

    entryIndex = findPackAPunchWeaponEntryIndex( currentWeaponKey );
    existingTrackedUpgradeLevel = 0;
    if ( entryIndex >= 0 && isdefined( self.abzmPackAPunchWeaponEntries[entryIndex].upgradeLevel ) )
    {
        existingTrackedUpgradeLevel = self.abzmPackAPunchWeaponEntries[entryIndex].upgradeLevel;
    }

    trackedUpgradeLevel = resolveTrackedPackAPunchLevel( existingTrackedUpgradeLevel, previousUpgradeLevel, observedUpgradeLevel );

    trackedUpgradeLevel = min( trackedUpgradeLevel, ABZM_MAX_PACKAPUNCH_LEVEL );

    if ( entryIndex >= 0 )
    {
        self.abzmPackAPunchWeaponEntries[entryIndex].upgradeLevel = trackedUpgradeLevel;
        self.abzmPackAPunchWeaponEntries[entryIndex].confirmedStateKey = getPackAPunchConfirmationKey( currentWeaponKey, trackedUpgradeLevel );
        self.abzmPackAPunchWeaponEntries[entryIndex].confirmedAt = gettime();
    }
    else
    {
        entry = spawnstruct();
        entry.weaponKey = currentWeaponKey;
        entry.upgradeLevel = trackedUpgradeLevel;
        entry.confirmedStateKey = getPackAPunchConfirmationKey( currentWeaponKey, trackedUpgradeLevel );
        entry.confirmedAt = gettime();
        self.abzmPackAPunchWeaponEntries[self.abzmPackAPunchWeaponEntries.size] = entry;
    }

    self.abzmLastPackAPunchWeaponKey = currentWeaponKey;
    self.abzmLastPackAPunchUpgradeLevel = trackedUpgradeLevel;
}

alreadyPackAPunchedCurrentWeapon()
{
    currentWeaponKey = getCurrentWeaponIdentityKey();
    if ( !isdefined( currentWeaponKey ) || currentWeaponKey == "" )
    {
        return false;
    }

    entryIndex = findPackAPunchWeaponEntryIndex( currentWeaponKey );
    if ( entryIndex < 0 )
    {
        return false;
    }

    trackedUpgradeLevel = self.abzmPackAPunchWeaponEntries[entryIndex].upgradeLevel;
    if ( !isdefined( trackedUpgradeLevel ) || trackedUpgradeLevel <= 0 )
    {
        return false;
    }

    confirmationActive = isdefined( self.abzmPackAPunchWeaponEntries[entryIndex].confirmedAt ) && (gettime() - self.abzmPackAPunchWeaponEntries[entryIndex].confirmedAt) <= ABZM_PACKAPUNCH_CONFIRMATION_FALLBACK_MS;
    confirmationKeyMatches = isdefined( self.abzmPackAPunchWeaponEntries[entryIndex].confirmedStateKey ) && self.abzmPackAPunchWeaponEntries[entryIndex].confirmedStateKey == getPackAPunchConfirmationKey( currentWeaponKey, trackedUpgradeLevel );
    currentUpgradeLevel = getCurrentWeaponUpgradeLevel();
    if ( currentUpgradeLevel > 0 )
    {
        liveWeaponKey = getCurrentWeaponIdentityKey();
        return liveWeaponKey == self.abzmPackAPunchWeaponEntries[entryIndex].weaponKey && currentUpgradeLevel >= trackedUpgradeLevel;
    }

    if ( !confirmationKeyMatches )
    {
        return false;
    }

    if ( !confirmationActive )
    {
        return false;
    }

    return getCurrentWeaponIdentityKey() == self.abzmPackAPunchWeaponEntries[entryIndex].weaponKey;
}

isMysteryBoxRewardConfirmedForState( previousWeaponKey, previousUpgradeLevel, currentWeaponKey, currentUpgradeLevel )
{
    if ( !isdefined( currentWeaponKey ) || currentWeaponKey == "" )
    {
        return false;
    }

    if ( currentWeaponKey != previousWeaponKey )
    {
        return true;
    }

    return currentUpgradeLevel > previousUpgradeLevel;
}

isMysteryBoxRewardConfirmed( previousWeaponKey, previousUpgradeLevel )
{
    currentWeaponKey = getCurrentWeaponIdentityKey();
    currentUpgradeLevel = getCurrentWeaponUpgradeLevel();
    return isMysteryBoxRewardConfirmedForState( previousWeaponKey, previousUpgradeLevel, currentWeaponKey, currentUpgradeLevel );
}

isPackAPunchUpgradeConfirmedForState( previousWeaponKey, previousUpgradeLevel, currentWeaponKey, currentUpgradeLevel )
{
    if ( currentWeaponKey == "" )
    {
        return false;
    }

    if ( currentWeaponKey != previousWeaponKey )
    {
        return false;
    }

    return currentUpgradeLevel > previousUpgradeLevel;
}

isPackAPunchUpgradeConfirmed( previousWeaponKey, previousUpgradeLevel )
{
    currentWeaponKey = getCurrentWeaponIdentityKey();
    currentUpgradeLevel = getCurrentWeaponUpgradeLevel();
    return isPackAPunchUpgradeConfirmedForState( previousWeaponKey, previousUpgradeLevel, currentWeaponKey, currentUpgradeLevel );
}

getPackAPunchConfirmationKey( weaponKey, upgradeLevel )
{
    return weaponKey + "|" + upgradeLevel;
}

waitForPackAPunchConfirmation( previousWeaponKey, previousUpgradeLevel, maxWaitMs )
{
    start = gettime();
    while ( (gettime() - start) < maxWaitMs )
    {
        if ( isPackAPunchUpgradeConfirmed( previousWeaponKey, previousUpgradeLevel ) )
        {
            return true;
        }

        wait 0.05;
    }

    return isPackAPunchUpgradeConfirmed( previousWeaponKey, previousUpgradeLevel );
}

findPackAPunchWeaponEntryIndex( weaponKey )
{
    if ( !isdefined( weaponKey ) || weaponKey == "" || !isdefined( self.abzmPackAPunchWeaponEntries ) )
    {
        return -1;
    }

    for ( i = 0; i < self.abzmPackAPunchWeaponEntries.size; i++ )
    {
        entry = self.abzmPackAPunchWeaponEntries[i];
        if ( isdefined( entry ) && isdefined( entry.weaponKey ) && entry.weaponKey == weaponKey )
        {
            return i;
        }
    }

    return -1;
}

markPerkPurchase( node )
{
    self initializeBotPurchaseState();
    perkKey = getPerkPurchaseKey( node );
    addedNewPerk = false;
    if ( isdefined( perkKey ) && perkKey != "" && !nodeArrayContains( self.abzmPurchasedPerkNodes, perkKey ) )
    {
        self.abzmPurchasedPerkNodes[self.abzmPurchasedPerkNodes.size] = perkKey;
        addedNewPerk = true;
    }

    shouldCountPerk = addedNewPerk;
    if ( shouldCountPerk && !isdefined( self.abzmPerkPurchases ) )
    {
        self.abzmPerkPurchases = 0;
    }

    if ( shouldCountPerk )
    {
        self.abzmPerkPurchases++;
        self.abzmLastPerkPurchaseTime = gettime();
        markGenericPurchase();
    }
}

markSharedPurchase( node, kind, usedFallback )
{
    if ( !isdefined( level.abzm ) )
    {
        markGenericPurchase();
        return;
    }

    purchaseKey = getSharedPurchaseKey( node, kind );
    if ( !isdefined( purchaseKey ) || purchaseKey == "" )
    {
        markGenericPurchase();
        return;
    }

    sharedIndex = findSharedPurchaseIndex( purchaseKey );
    sharedEntry = spawnstruct();
    sharedEntry.key = purchaseKey;
    sharedEntry.kind = kind;
    sharedEntry.expiresAt = gettime() + ABZM_SHARED_PURCHASE_RETRY_COOLDOWN_MS;
    sharedEntry.isReservation = false;
    if ( isTimedSharedPurchaseKind( kind ) )
    {
        sharedCooldown = ABZM_SHARED_PURCHASE_COOLDOWN_MS;
        if ( isdefined( usedFallback ) && usedFallback )
        {
            sharedCooldown = ABZM_SHARED_PURCHASE_RETRY_COOLDOWN_MS;
        }

        sharedEntry.expiresAt = gettime() + sharedCooldown;
    }

    if ( sharedIndex >= 0 )
    {
        level.abzm.sharedPurchasedNodes[sharedIndex] = sharedEntry;
    }
    else
    {
        level.abzm.sharedPurchasedNodes[level.abzm.sharedPurchasedNodes.size] = sharedEntry;
    }

    markGenericPurchase();
}

reserveSharedPurchase( node, kind )
{
    if ( !isdefined( level.abzm ) )
    {
        return true;
    }

    purchaseKey = getSharedPurchaseKey( node, kind );
    if ( !isdefined( purchaseKey ) || purchaseKey == "" )
    {
        return true;
    }

    claimedIndex = -1;
    for ( i = 0; i < level.abzm.sharedPurchasedNodes.size; i++ )
    {
        sharedEntry = level.abzm.sharedPurchasedNodes[i];
        if ( !isdefined( sharedEntry ) || !isdefined( sharedEntry.key ) || sharedEntry.key == "" )
        {
            if ( claimedIndex < 0 )
            {
                claimedIndex = i;
            }
            continue;
        }

        if ( sharedEntry.key != purchaseKey )
        {
            continue;
        }

        if ( !isdefined( sharedEntry.expiresAt ) )
        {
            claimedIndex = i;
            break;
        }

        if ( gettime() < sharedEntry.expiresAt )
        {
            return false;
        }

        claimedIndex = i;
        break;
    }

    sharedEntry = spawnstruct();
    sharedEntry.key = purchaseKey;
    sharedEntry.kind = kind;
    sharedEntry.expiresAt = gettime() + ABZM_SHARED_PURCHASE_RESERVATION_MS;
    sharedEntry.isReservation = true;

    finalIndex = findSharedPurchaseIndex( purchaseKey );
    if ( finalIndex >= 0 )
    {
        finalEntry = level.abzm.sharedPurchasedNodes[finalIndex];
        if ( isdefined( finalEntry ) && isdefined( finalEntry.expiresAt ) && gettime() < finalEntry.expiresAt )
        {
            return false;
        }

        claimedIndex = finalIndex;
    }

    if ( claimedIndex >= 0 )
    {
        level.abzm.sharedPurchasedNodes[claimedIndex] = sharedEntry;
    }
    else
    {
        level.abzm.sharedPurchasedNodes[level.abzm.sharedPurchasedNodes.size] = sharedEntry;
    }

    return true;
}

clearSharedPurchaseReservation( node, kind )
{
    if ( !isdefined( level.abzm ) )
    {
        return;
    }

    purchaseKey = getSharedPurchaseKey( node, kind );
    if ( !isdefined( purchaseKey ) || purchaseKey == "" )
    {
        return;
    }

    sharedIndex = findSharedPurchaseIndex( purchaseKey );
    if ( sharedIndex >= 0 )
    {
        sharedEntry = level.abzm.sharedPurchasedNodes[sharedIndex];
        if ( isdefined( sharedEntry ) && isdefined( sharedEntry.isReservation ) && sharedEntry.isReservation )
        {
            compactSharedPurchaseArray( sharedIndex );
        }
    }
}

isTimedSharedPurchaseKind( kind )
{
    return kind == "exo" || kind == "door" || kind == "mystery" || kind == "packapunch";
}

alreadyBoughtPerkNode( node )
{
    if ( !isdefined( self.abzmPurchasedPerkNodes ) )
    {
        return false;
    }

    perkKey = getPerkPurchaseKey( node );
    if ( !isdefined( perkKey ) || perkKey == "" )
    {
        return false;
    }

    return nodeArrayContains( self.abzmPurchasedPerkNodes, perkKey );
}

alreadyBoughtSharedNode( node, kind )
{
    if ( !isdefined( level.abzm ) || !isdefined( level.abzm.sharedPurchasedNodes ) )
    {
        return false;
    }

    purchaseKey = getSharedPurchaseKey( node, kind );
    if ( !isdefined( purchaseKey ) || purchaseKey == "" )
    {
        return false;
    }

    sharedIndex = findSharedPurchaseIndex( purchaseKey );
    if ( sharedIndex < 0 )
    {
        return false;
    }

    sharedEntry = level.abzm.sharedPurchasedNodes[sharedIndex];
    if ( !isdefined( sharedEntry ) )
    {
        return invalidateSharedPurchaseEntry( sharedIndex );
    }

    if ( !isdefined( sharedEntry.expiresAt ) )
    {
        return invalidateSharedPurchaseEntry( sharedIndex );
    }

    if ( sharedEntry.expiresAt < 0 || gettime() < sharedEntry.expiresAt )
    {
        return !isdefined( sharedEntry.isReservation ) || !sharedEntry.isReservation;
    }

    return invalidateSharedPurchaseEntry( sharedIndex );
}

isSharedPurchaseBlocked( node, kind )
{
    if ( alreadyBoughtSharedNode( node, kind ) )
    {
        return true;
    }

    if ( !isdefined( level.abzm ) || !isdefined( level.abzm.sharedPurchasedNodes ) )
    {
        return false;
    }

    purchaseKey = getSharedPurchaseKey( node, kind );
    if ( !isdefined( purchaseKey ) || purchaseKey == "" )
    {
        return false;
    }

    sharedIndex = findSharedPurchaseIndex( purchaseKey );
    if ( sharedIndex < 0 )
    {
        return false;
    }

    sharedEntry = level.abzm.sharedPurchasedNodes[sharedIndex];
    if ( !isdefined( sharedEntry ) || !isdefined( sharedEntry.isReservation ) || !sharedEntry.isReservation )
    {
        return false;
    }

    if ( !isdefined( sharedEntry.expiresAt ) )
    {
        return invalidateSharedPurchaseEntry( sharedIndex );
    }

    if ( sharedEntry.expiresAt < 0 || gettime() < sharedEntry.expiresAt )
    {
        return true;
    }

    return invalidateSharedPurchaseEntry( sharedIndex );
}

findSharedPurchaseIndex( purchaseKey )
{
    if ( !isdefined( level.abzm ) || !isdefined( level.abzm.sharedPurchasedNodes ) || !isdefined( purchaseKey ) || purchaseKey == "" )
    {
        return -1;
    }

    for ( i = 0; i < level.abzm.sharedPurchasedNodes.size; i++ )
    {
        entry = level.abzm.sharedPurchasedNodes[i];
        if ( isdefined( entry ) && isdefined( entry.key ) && entry.key == purchaseKey )
        {
            return i;
        }
    }

    return -1;
}

compactSharedPurchaseArray( purchaseIndex )
{
    if ( !isdefined( level.abzm ) || !isdefined( level.abzm.sharedPurchasedNodes ) )
    {
        return;
    }

    newArray = [];
    for ( i = 0; i < level.abzm.sharedPurchasedNodes.size; i++ )
    {
        if ( i == purchaseIndex )
        {
            continue;
        }

        entry = level.abzm.sharedPurchasedNodes[i];
        if ( !isdefined( entry ) || !isdefined( entry.key ) || entry.key == "" )
        {
            continue;
        }

        newArray[newArray.size] = entry;
    }

    level.abzm.sharedPurchasedNodes = newArray;
}

invalidateSharedPurchaseEntry( purchaseIndex )
{
    compactSharedPurchaseArray( purchaseIndex );
    return false;
}

getStableInteractableKey( node, fallbackPrefix )
{
    if ( !isdefined( node ) )
    {
        return "";
    }

    uniquePart = getStableInteractableIdentityPart( node );
    keyPart = "";
    if ( isdefined( node.targetname ) && node.targetname != "" )
    {
        keyPart = toLower( node.targetname + "" );
    }
    else if ( isdefined( node.script_noteworthy ) && node.script_noteworthy != "" )
    {
        keyPart = toLower( node.script_noteworthy + "" );
    }
    else if ( isdefined( node.script_linkname ) && node.script_linkname != "" )
    {
        keyPart = toLower( node.script_linkname + "" );
    }
    else if ( isdefined( node.script_string ) && node.script_string != "" )
    {
        keyPart = toLower( node.script_string + "" );
    }
    else if ( isdefined( node.model ) && node.model != "" )
    {
        keyPart = toLower( node.model + "" );
    }
    else if ( isdefined( node.classname ) && node.classname != "" )
    {
        keyPart = toLower( node.classname + "" );
    }

    if ( keyPart == "" )
    {
        keyPart = toLower( fallbackPrefix + "" );
    }

    originKey = "0_0_0";
    if ( isdefined( node.origin ) )
    {
        originKey = int( node.origin[0] ) + "_" + int( node.origin[1] ) + "_" + int( node.origin[2] );
    }

    if ( uniquePart != "" )
    {
        return uniquePart + "|" + keyPart + "|" + originKey;
    }

    return keyPart + "|" + originKey;
}

getStableInteractableIdentityPart( node )
{
    if ( !isdefined( node ) )
    {
        return "";
    }

    if ( isdefined( node.target ) && node.target != "" )
    {
        return "target_" + toLower( node.target + "" );
    }

    if ( isdefined( node.script_targetname ) && node.script_targetname != "" )
    {
        return "script_targetname_" + toLower( node.script_targetname + "" );
    }

    if ( isdefined( node.script_target ) && node.script_target != "" )
    {
        return "script_target_" + toLower( node.script_target + "" );
    }

    if ( isdefined( node.script_id ) )
    {
        return "script_id_" + toLower( node.script_id + "" );
    }

    if ( isdefined( node.script_index ) )
    {
        return "script_index_" + toLower( node.script_index + "" );
    }

    if ( isdefined( node.name ) && node.name != "" )
    {
        return "name_" + toLower( node.name + "" );
    }

    return "";
}

getSharedPurchaseKey( node, kind )
{
    if ( !isdefined( node ) )
    {
        return "";
    }

    return toLower( kind + "" ) + "|" + getStableInteractableKey( node, "generic_" + toLower( kind + "" ) );
}

getBestPerkInteractable()
{
    nodes = getInteractableCandidates();
    best = undefined;
    bestPriority = -999999;
    bestDist = 999999;

    for ( i = 0; i < nodes.size; i++ )
    {
        node = nodes[i];
        if ( !isDesiredInteractable( node, "perk" ) || alreadyBoughtPerkNode( node ) )
        {
            continue;
        }

        priority = perkPriorityForEntity( node );
        dist = int( distance( self.origin, node.origin ) );

        if ( priority > bestPriority || ( priority == bestPriority && dist < bestDist ) )
        {
            best = node;
            bestPriority = priority;
            bestDist = dist;
        }
    }

    return best;
}

perkPriorityForEntity( node )
{
    perkType = classifyPerkType( node );
    switch ( perkType )
    {
        case "quick_revive":
            return ABZM_PERK_PRIORITY_QUICK_REVIVE;
        case "health":
            return ABZM_PERK_PRIORITY_HEALTH;
        case "speed":
            return ABZM_PERK_PRIORITY_SPEED;
        case "damage":
            return ABZM_PERK_PRIORITY_DAMAGE;
        case "stamina":
            return ABZM_PERK_PRIORITY_STAMINA;
    }

    return ABZM_PERK_PRIORITY_DEFAULT;
}

classifyPerkType( node )
{
    if ( !isdefined( node ) )
    {
        return "";
    }

    if ( isQuickRevivePerkNode( node ) )
    {
        return "quick_revive";
    }

    if ( entityMatchesToken( node, "health" ) || entityMatchesToken( node, "jug" ) || entityMatchesToken( node, "tough" ) )
    {
        return "health";
    }

    if ( entityMatchesToken( node, "speed" ) || entityMatchesToken( node, "reload" ) )
    {
        return "speed";
    }

    if ( entityMatchesToken( node, "damage" ) || entityMatchesToken( node, "tap" ) || entityMatchesToken( node, "multishot" ) )
    {
        return "damage";
    }

    if ( entityMatchesToken( node, "stamina" ) || entityMatchesToken( node, "sprint" ) )
    {
        return "stamina";
    }

    if ( entityMatchesToken( node, "perk" ) || entityMatchesToken( node, "vending" ) || entityMatchesToken( node, "perkacola" ) )
    {
        return "generic_perk";
    }

    return "";
}

isQuickRevivePerkNode( node )
{
    if ( !isdefined( node ) )
    {
        return false;
    }

    if ( entityMatchesToken( node, "quick" ) )
    {
        return true;
    }

    return hasReviveInteractableToken( node ) && isPerkInteractable( node );
}

getPerkPurchaseKey( node )
{
    if ( !isdefined( node ) )
    {
        return "";
    }

    perkType = classifyPerkType( node );
    stablePerkKey = getStableInteractableKey( node, "perk" );
    if ( perkType != "" )
    {
        return perkType + "|" + stablePerkKey;
    }

    return stablePerkKey;
}

useEquipmentIfNeeded()
{
    crowdCount = countNearbyZombies( self.origin, 180 );
    if ( crowdCount >= 8 )
    {
        self notify( "frag_grenade" );
    }
    else if ( crowdCount >= 5 )
    {
        self notify( "tactical_grenade" );
    }
}

monitorZombieSpawns()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "zombie_spawned", zombie );

        if ( !level.abzm.bo2Enabled || !isdefined( zombie ) )
        {
            continue;
        }

        trackZombieEntity( zombie );
    }
}

periodicZombieRefresh()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( level.abzm.bo2Enabled )
        {
            scanForZombieEntities();
        }

        wait 0.5;
    }
}

scanForZombieEntities()
{
    zombies = [];
    appendEntArray( zombies, getentarray( "actor", "classname" ) );
    appendEntArray( zombies, getentarray( "agent", "classname" ) );
    appendEntArray( zombies, getentarray( "zombie", "classname" ) );

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( isZombieEntity( zombie ) )
        {
            trackZombieEntity( zombie );
        }
    }
}

trackZombieEntity( zombie )
{
    if ( !isdefined( zombie ) || !isZombieEntity( zombie ) )
    {
        return;
    }

    if ( rememberZombie( zombie ) )
    {
        zombie thread tuneZombieForCurrentRound();
        zombie thread awardZombieDeathPoints();
    }
}

rememberZombie( zombie )
{
    if ( !isdefined( zombie ) )
    {
        return false;
    }

    if ( isdefined( zombie.abzmTracked ) && zombie.abzmTracked )
    {
        return false;
    }

    zombie.abzmTracked = true;
    level.abzm.trackedZombies[level.abzm.trackedZombies.size] = zombie;
    return true;
}

retuneTrackedZombies()
{
    zombies = getTrackedZombies();

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( isdefined( zombie ) && isalive( zombie ) && ( !isdefined( zombie.abzmRetunePending ) || !zombie.abzmRetunePending ) )
        {
            zombie.abzmRetunePending = true;
            zombie thread retuneActiveZombie();
        }
    }
}

retuneActiveZombie()
{
    self endon( "death" );

    wait 0.05;
    tuneZombieForCurrentRound();
    self.abzmRetunePending = false;
}

awardZombieDeathPoints()
{
    self waittill( "death", attacker, inflictor, meansOfDeath, weapon, hitLoc );

    if ( !isdefined( attacker ) || !isplayer( attacker ) )
    {
        return;
    }

    isHeadshot = isdefined( hitLoc ) && hitLoc == "head";
    isMelee = isdefined( meansOfDeath ) && meansOfDeath == "MOD_MELEE";

    if ( isMelee )
    {
        awardPlayerPoints( attacker, ABZM_BO2_MELEE_POINTS );
        return;
    }

    awardPlayerPoints( attacker, ABZM_BO2_KILL_POINTS );
    if ( isHeadshot )
    {
        awardPlayerPoints( attacker, ABZM_BO2_HEADSHOT_BONUS );
    }
}

tuneZombieForCurrentRound()
{
    self endon( "death" );

    roundNumber = max( 1, level.abzm.round );
    health = calculateBo2ZombieHealth( roundNumber );
    speed = calculateBo2ZombieSpeed( roundNumber );

    if ( level.abzm.forceSpecialRound )
    {
        self.abzmCrawler = false;
        self.abzmSpecialEnemy = true;
        health = int( health * ABZM_BO2_SPECIAL_HEALTH_SCALE );
        speed += ABZM_BO2_SPECIAL_SPEED_BONUS;
    }
    else if ( shouldMakeCrawler( roundNumber ) )
    {
        self.abzmSpecialEnemy = false;
        speed = ABZM_BO2_CRAWLER_SPEED;
        self.abzmCrawler = true;
    }
    else
    {
        self.abzmSpecialEnemy = false;
        self.abzmCrawler = false;
    }

    if ( isdefined( level.abzmInstakillActive ) && level.abzmInstakillActive )
    {
        health = 1;
    }

    previousHealth = health;
    if ( isdefined( self.health ) )
    {
        previousHealth = self.health;
    }

    self.maxhealth = health;
    if ( !isdefined( self.abzmZombieTuned ) || !self.abzmZombieTuned )
    {
        self.health = health;
    }
    else
    {
        self.health = min( previousHealth, health );
    }

    self.abzmZombieTuned = true;
    self.abzmDesiredSpeed = speed;
    self.abzmDesiredWalkSpeed = speed;
    self.abzmDesiredRunSpeed = speed;
    self.runspeed = speed;
    self.walkspeed = speed;

    if ( roundNumber >= level.abzm.sprintRound )
    {
        self.abzmCanSprint = true;
        self.abzmDesiredRunSpeed = speed;
        self.runspeed = speed;
    }
}

monitorPowerupSpawns()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "powerup_spawned", powerup );

        if ( !level.abzm.bo2Enabled || !level.abzm.bo2PowerupsEnabled || !isdefined( powerup ) )
        {
            continue;
        }

        tunePowerupDrop( powerup );
    }
}

periodicPowerupRefresh()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( level.abzm.bo2Enabled && level.abzm.bo2PowerupsEnabled )
        {
            scanForPowerupEntities();
        }

        wait 0.5;
    }
}

scanForPowerupEntities()
{
    powerups = [];
    appendEntArray( powerups, getentarray( "item", "classname" ) );
    appendEntArray( powerups, getentarray( "trigger", "classname" ) );
    appendEntArray( powerups, getentarray( "script_model", "classname" ) );

    for ( i = 0; i < powerups.size; i++ )
    {
        powerup = powerups[i];
        if ( isPotentialPowerup( powerup ) )
        {
            tunePowerupDrop( powerup );
        }
    }
}

tunePowerupDrop( powerup )
{
    if ( isdefined( powerup.abzmPowerupTracked ) && powerup.abzmPowerupTracked )
    {
        return;
    }

    type = canonicalPowerupType( powerup );
    powerup.abzmDropType = type;
    powerup.abzmPowerupTracked = true;

    switch ( type )
    {
        case "instakill":
            powerup.abzmDuration = ABZM_BO2_INSTAKILL_DURATION;
            break;

        case "doublepoints":
            powerup.abzmDuration = ABZM_BO2_DOUBLEPOINTS_DURATION;
            break;

        case "nuke":
            powerup.abzmDelay = ABZM_BO2_NUKE_DELAY;
            break;
    }

}

calculateBo2ZombieHealth( roundNumber )
{
    // Stretch the old early-game health ramp across rounds 1-55, then replay the
    // original round-1-through-55 growth profile during the later game without
    // ever letting the curve drop between phases.
    if ( roundNumber <= ABZM_BO2_EASY_PHASE_END_ROUND )
    {
        return calculateBo2EasyPhaseZombieHealth( roundNumber );
    }

    easyPhaseBaseHealth = calculateBo2EasyPhaseZombieHealth( ABZM_BO2_EASY_PHASE_END_ROUND );
    replayLegacyRound = calculateBo2ReplayLegacyRound( roundNumber );
    if ( roundNumber > ABZM_BO2_REPLAY_PHASE_END_ROUND )
    {
        replayHealth = calculateLegacyBo2ZombieHealth( int( replayLegacyRound ) );
    }
    else
    {
        replayHealth = calculateInterpolatedLegacyBo2ZombieHealth( replayLegacyRound, ABZM_BO2_REPLAY_PHASE_LEGACY_END_ROUND );
    }
    replayBaseHealth = calculateLegacyBo2ZombieHealth( ABZM_BO2_REPLAY_PHASE_LEGACY_START_ROUND );
    replayDelta = replayHealth - replayBaseHealth;
    return min( ABZM_BO2_HEALTH_CAP, easyPhaseBaseHealth + replayDelta );
}

calculateBo2EasyPhaseZombieHealth( roundNumber )
{
    if ( roundNumber <= 1 )
    {
        return calculateLegacyBo2ZombieHealth( 1 );
    }

    easyLegacyRound = remapRoundRangeFloat(
        roundNumber,
        1,
        ABZM_BO2_EASY_PHASE_END_ROUND,
        1,
        ABZM_BO2_EASY_PHASE_TARGET_LEGACY_ROUND
    );

    return calculateInterpolatedLegacyBo2ZombieHealth( easyLegacyRound, ABZM_BO2_EASY_PHASE_TARGET_LEGACY_ROUND );
}

calculateBo2ReplayLegacyRound( roundNumber )
{
    if ( roundNumber < ABZM_BO2_REPLAY_PHASE_START_ROUND )
    {
        return ABZM_BO2_REPLAY_PHASE_LEGACY_START_ROUND;
    }

    if ( roundNumber <= ABZM_BO2_REPLAY_PHASE_END_ROUND )
    {
        return remapRoundRangeFloat(
            roundNumber,
            ABZM_BO2_REPLAY_PHASE_START_ROUND,
            ABZM_BO2_REPLAY_PHASE_END_ROUND,
            ABZM_BO2_REPLAY_PHASE_LEGACY_START_ROUND,
            ABZM_BO2_REPLAY_PHASE_LEGACY_END_ROUND
        );
    }

    return ABZM_BO2_REPLAY_PHASE_LEGACY_END_ROUND + (roundNumber - ABZM_BO2_REPLAY_PHASE_END_ROUND);
}

calculateInterpolatedLegacyBo2ZombieHealth( legacyRoundFloat, maximumLegacyRound )
{
    clampedLegacyRound = abzmClamp( legacyRoundFloat, 1.0, maximumLegacyRound );
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

    lowerLegacyHealth = calculateLegacyBo2ZombieHealth( lowerLegacyRound );
    upperLegacyHealth = calculateLegacyBo2ZombieHealth( upperLegacyRound );

    return int( lowerLegacyHealth + ((upperLegacyHealth - lowerLegacyHealth) * legacyBlend) );
}

calculateLegacyBo2ZombieHealth( roundNumber )
{
    if ( roundNumber <= 1 )
    {
        return ABZM_BO2_BASE_HEALTH;
    }

    if ( roundNumber <= ABZM_BO2_HEALTH_CURVE_ROUND )
    {
        return min( ABZM_BO2_HEALTH_CAP, ABZM_BO2_BASE_HEALTH + ((roundNumber - 1) * ABZM_BO2_HEALTH_INCREMENT) );
    }

    health = ABZM_BO2_BASE_HEALTH + ((ABZM_BO2_HEALTH_CURVE_ROUND - 1) * ABZM_BO2_HEALTH_INCREMENT);

    for ( i = ABZM_BO2_HEALTH_CURVE_ROUND + 1; i <= roundNumber; i++ )
    {
        health = min( ABZM_BO2_HEALTH_CAP, int( health * ABZM_BO2_HEALTH_CURVE_MULTIPLIER ) );
        if ( health >= ABZM_BO2_HEALTH_CAP )
        {
            return ABZM_BO2_HEALTH_CAP;
        }
    }

    return health;
}

remapRoundRangeFloat( sourceRound, sourceStart, sourceEnd, targetStart, targetEnd )
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

calculateBo2ZombieSpeed( roundNumber )
{
    if ( roundNumber < ABZM_BO2_RUN_ROUND )
    {
        return ABZM_BO2_WALK_SPEED;
    }

    if ( roundNumber < level.abzm.sprintRound )
    {
        return ABZM_BO2_RUN_SPEED;
    }

    return ABZM_BO2_SPRINT_SPEED;
}

shouldMakeCrawler( roundNumber )
{
    if ( roundNumber < 8 )
    {
        return false;
    }

    return randomfloat( 1.0 ) <= level.abzm.crawlerChance;
}

shouldRetreat()
{
    if ( !isalive( self ) )
    {
        return false;
    }

    if ( self.health <= int( self.maxhealth * 0.35 ) )
    {
        return true;
    }

    if ( currentWeaponNeedsAmmo() )
    {
        return true;
    }

    return countNearbyZombies( self.origin, 120 ) >= 10;
}

currentWeaponNeedsAmmo()
{
    weapon = self getcurrentweapon();
    if ( !isdefined( weapon ) )
    {
        return false;
    }

    return self getweaponammoclip( weapon ) <= 5;
}

getWeaponPurchaseStateKey()
{
    weapon = self getcurrentweapon();
    if ( !isdefined( weapon ) )
    {
        weapon = "none";
    }

    weapon = toLower( weapon + "" );
    return weapon + "|" + currentWeaponNeedsAmmo() + "|" + isCurrentWeaponWeak();
}

getCurrentWeaponIdentityKey()
{
    weapon = self getcurrentweapon();
    if ( !isdefined( weapon ) )
    {
        return "";
    }

    return toLower( weapon + "" );
}

getCurrentWeaponUpgradeLevel()
{
    weapon = self getcurrentweapon();
    if ( !isdefined( weapon ) || !isdefined( self.weaponstate ) || !isdefined( self.weaponstate[weapon] ) )
    {
        return 0;
    }

    state = self.weaponstate[weapon];
    if ( isdefined( state["pap_level"] ) )
    {
        return int( state["pap_level"] );
    }

    if ( isdefined( state["upgrade_level"] ) )
    {
        return int( state["upgrade_level"] );
    }

    if ( isdefined( state["weapon_level_increase"] ) )
    {
        return int( state["weapon_level_increase"] );
    }

    if ( isdefined( state["is_upgraded"] ) && state["is_upgraded"] )
    {
        return 1;
    }

    return 0;
}

isCurrentWeaponWeak()
{
    weapon = self getcurrentweapon();
    if ( !isdefined( weapon ) )
    {
        return true;
    }

    weapon = toLower( weapon + "" );
    return isWeakWeaponName( weapon );
}

isWeakWeaponName( weapon )
{
    if ( !isdefined( weapon ) )
    {
        return true;
    }

    weapon = toLower( weapon + "" );
    if ( !isdefined( level.abzm ) || !isdefined( level.abzm.weakWeaponTokens ) )
    {
        return false;
    }

    for ( i = 0; i < level.abzm.weakWeaponTokens.size; i++ )
    {
        weakToken = level.abzm.weakWeaponTokens[i];
        if ( isdefined( weakToken ) && weakToken != "" && stringContainsToken( weapon, weakToken ) )
        {
            return true;
        }
    }

    return false;
}

getClosestDownedTeammate()
{
    players = getentarray( "player", "classname" );
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( player == self || !isdefined( player ) )
        {
            continue;
        }

        if ( !isdefined( player.abzmDowned ) || !player.abzmDowned )
        {
            continue;
        }

        dist = distance( self.origin, player.origin );
        if ( dist < bestDist )
        {
            best = player;
            bestDist = dist;
        }
    }

    return best;
}

getClosestInteractable( kind )
{
    return getClosestInteractableFromCandidates( getInteractableCandidates(), kind, false );
}

getClosestPurchaseItemInteractable( kind )
{
    return getClosestInteractableFromCandidates( getPurchaseItemCandidates(), kind, false );
}

getClosestAvailableSharedInteractable( kind )
{
    return getClosestInteractableFromCandidates( getInteractableCandidates(), kind, true );
}

getClosestInteractableFromCandidates( nodes, kind, skipSharedPurchases )
{
    if ( !isdefined( nodes ) )
    {
        return undefined;
    }

    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < nodes.size; i++ )
    {
        node = nodes[i];
        if ( !isDesiredInteractable( node, kind ) )
        {
            continue;
        }

        if ( skipSharedPurchases && isSharedPurchaseBlocked( node, kind ) )
        {
            continue;
        }

        dist = distance( self.origin, node.origin );
        if ( dist < bestDist )
        {
            best = node;
            bestDist = dist;
        }
    }

    return best;
}

moveToAndUse( node )
{
    if ( !isdefined( node ) )
    {
        return false;
    }

    if ( isdefined( self.abzmLastInteractTarget ) && self.abzmLastInteractTarget == node && isdefined( self.abzmLastInteractTime ) && (gettime() - self.abzmLastInteractTime) < 500 )
    {
        return false;
    }

    self setlookatpos( node.origin );
    self moveto( node.origin, 0.25 );

    interactStartTime = gettime();
    while ( distance( self.origin, node.origin ) > ABZM_INTERACT_RANGE )
    {
        if ( gettime() - interactStartTime >= 1000 )
        {
            return false;
        }

        wait 0.05;
    }

    self.abzmLastInteractTarget = node;
    self.abzmLastInteractTime = gettime();
    node notify( "trigger", self );
    return true;
}

attemptPurchase( node, cost )
{
    self.abzmLastPurchaseUsedFallback = false;

    if ( !hasEnoughPoints( self, cost ) )
    {
        return false;
    }

    pointsBefore = getTrackedPlayerPoints( self );
    if ( isdefined( self.score ) )
    {
        pointsBefore = self.score;
    }

    if ( !isdefined( node ) || !moveToAndUse( node ) )
    {
        return false;
    }

    wait 0.05;

    if ( isdefined( self.score ) && self.score < pointsBefore )
    {
        self.abzmWallet = self.score;
        return true;
    }

    self.abzmLastPurchaseUsedFallback = true;
    spendPlayerPoints( self, cost );
    return true;
}

getInteractableCandidates()
{
    if ( !isdefined( level.abzm ) )
    {
        nodes = [];
        return nodes;
    }

    if ( (gettime() - level.abzm.interactableCacheTime) < 2000 && level.abzm.interactableCandidates.size > 0 )
    {
        return level.abzm.interactableCandidates;
    }

    nodes = [];
    appendEntArray( nodes, getentarray( "trigger", "classname" ) );
    appendEntArray( nodes, getentarray( "trigger_use", "classname" ) );
    appendEntArray( nodes, getentarray( "script_model", "classname" ) );
    appendEntArray( nodes, getentarray( "script_brushmodel", "classname" ) );

    level.abzm.interactableCandidates = nodes;
    level.abzm.interactableCacheTime = gettime();
    return level.abzm.interactableCandidates;
}

getPurchaseItemCandidates()
{
    if ( !isdefined( level.abzm ) )
    {
        nodes = [];
        return nodes;
    }

    if ( (gettime() - level.abzm.purchaseItemCacheTime) < 2000 && level.abzm.purchaseItemSourceCacheTime == level.abzm.interactableCacheTime )
    {
        return level.abzm.purchaseItemCandidates;
    }

    nodes = getInteractableCandidates();
    purchaseNodes = [];
    for ( i = 0; i < nodes.size; i++ )
    {
        node = nodes[i];
        if ( isDesiredInteractable( node, "weapon" ) || isDesiredInteractable( node, "mystery" ) || isGenericWeaponPurchaseMarker( node ) )
        {
            purchaseNodes[purchaseNodes.size] = node;
        }
    }

    level.abzm.purchaseItemCandidates = purchaseNodes;
    level.abzm.purchaseItemCacheTime = gettime();
    level.abzm.purchaseItemSourceCacheTime = level.abzm.interactableCacheTime;
    return level.abzm.purchaseItemCandidates;
}
isGenericWeaponPurchaseMarker( entity )
{
    if ( !isdefined( entity ) || !entityMatchesToken( entity, "buy" ) )
    {
        return false;
    }

    return !isDesiredInteractable( entity, "door" ) && !isDesiredInteractable( entity, "perk" ) && !isDesiredInteractable( entity, "exo" ) && !isDesiredInteractable( entity, "packapunch" ) && !isDesiredInteractable( entity, "mystery" ) && !isDesiredInteractable( entity, "revive" );
}

chooseTrainingAnchor()
{
    closestZombie = getClosestZombie();
    if ( isdefined( closestZombie ) )
    {
        offset = anglesToForward( self.angles + (0, 90, 0) ) * 160;
        return self.origin + offset;
    }

    return self.origin + (64, 0, 0);
}

chooseRetreatAnchor()
{
    closestZombie = getClosestZombie();
    if ( !isdefined( closestZombie ) )
    {
        return self.origin + (-96, 0, 0);
    }

    away = vectornormalize( self.origin - closestZombie.origin );
    return self.origin + (away * 220);
}

getTrackedZombies()
{
    liveZombies = [];

    for ( i = 0; i < level.abzm.trackedZombies.size; i++ )
    {
        zombie = level.abzm.trackedZombies[i];
        if ( isdefined( zombie ) && isalive( zombie ) )
        {
            liveZombies[liveZombies.size] = zombie;
        }
    }

    level.abzm.trackedZombies = liveZombies;
    return liveZombies;
}

getClosestZombie()
{
    zombies = getTrackedZombies();
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        dist = distance( self.origin, zombie.origin );
        if ( dist < bestDist )
        {
            best = zombie;
            bestDist = dist;
        }
    }

    return best;
}

countNearbyZombies( origin, radius )
{
    zombies = getTrackedZombies();
    count = 0;

    for ( i = 0; i < zombies.size; i++ )
    {
        zombie = zombies[i];
        if ( distance( origin, zombie.origin ) <= radius )
        {
            count++;
        }
    }

    return count;
}

getActiveBotCount()
{
    players = getentarray( "player", "classname" );
    count = 0;

    for ( i = 0; i < players.size; i++ )
    {
        if ( isBotEntity( players[i] ) )
        {
            count++;
        }
    }

    return count;
}

getTrackedPlayerPoints( player )
{
    if ( !isdefined( player.abzmWallet ) )
    {
        player.abzmWallet = 0;
        if ( isdefined( player.score ) )
        {
            player.abzmWallet = player.score;
        }
    }

    return player.abzmWallet;
}

hasEnoughPoints( player, amount )
{
    return getTrackedPlayerPoints( player ) >= amount;
}

spendPlayerPoints( player, amount )
{
    current = getTrackedPlayerPoints( player );
    player.abzmWallet = max( 0, current - amount );
    if ( isdefined( player.score ) )
    {
        player.score = player.abzmWallet;
    }
}

awardPlayerPoints( player, amount )
{
    current = getTrackedPlayerPoints( player );

    if ( isdefined( level.abzmDoublePointsActive ) && level.abzmDoublePointsActive )
    {
        amount *= 2;
    }

    player.abzmWallet = current + amount;
    if ( isdefined( player.score ) )
    {
        player.score = player.abzmWallet;
    }
}

abzmClamp( value, minimum, maximum )
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

clearActiveReviveClaim()
{
    if ( !isdefined( self.abzmReviveTarget ) )
    {
        return;
    }

    if ( isdefined( self.abzmReviveTarget.abzmReviver ) && self.abzmReviveTarget.abzmReviver == self )
    {
        self.abzmReviveTarget.abzmReviver = undefined;
    }

    self.abzmReviveTarget = undefined;
}

signalReviveSuccess( downed, reviver )
{
    downed notify( "revived", reviver );
    level notify( "player_revived", downed, reviver );
}

isBotEntity( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( isdefined( player.pers["isBot"] ) && player.pers["isBot"] )
    {
        return true;
    }

    if ( isdefined( player.abzmIsBot ) && player.abzmIsBot )
    {
        return true;
    }

    return false;
}

appendEntArray( destination, source )
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

nodeArrayContains( source, target )
{
    if ( !isdefined( source ) || !isdefined( target ) )
    {
        return false;
    }

    for ( i = 0; i < source.size; i++ )
    {
        if ( isdefined( source[i] ) && source[i] == target )
        {
            return true;
        }
    }

    return false;
}

isZombieEntity( entity )
{
    if ( !isdefined( entity ) )
    {
        return false;
    }

    if ( isdefined( entity.classname ) && entity.classname == "actor" && ( entityMatchesToken( entity, "zombie" ) || entityMatchesToken( entity, "exo_zm" ) || entityMatchesToken( entity, "infected" ) ) )
    {
        return true;
    }

    return entityMatchesToken( entity, "zombie" ) || entityMatchesToken( entity, "exo_zm" ) || entityMatchesToken( entity, "infected" );
}

isPotentialPowerup( entity )
{
    if ( !isdefined( entity ) )
    {
        return false;
    }

    return entityMatchesToken( entity, "instakill" ) || entityMatchesToken( entity, "doublepoints" ) || entityMatchesToken( entity, "double_points" ) || entityMatchesToken( entity, "nuke" ) || entityMatchesToken( entity, "maxammo" ) || entityMatchesToken( entity, "carpenter" ) || entityMatchesToken( entity, "powerup" );
}

canonicalPowerupType( powerup )
{
    if ( entityMatchesToken( powerup, "instakill" ) )
    {
        return "instakill";
    }

    if ( entityMatchesToken( powerup, "doublepoints" ) || entityMatchesToken( powerup, "double_points" ) )
    {
        return "doublepoints";
    }

    if ( entityMatchesToken( powerup, "nuke" ) )
    {
        return "nuke";
    }

    if ( entityMatchesToken( powerup, "maxammo" ) || entityMatchesToken( powerup, "max_ammo" ) )
    {
        return "maxammo";
    }

    if ( entityMatchesToken( powerup, "carpenter" ) )
    {
        return "carpenter";
    }

    return "unknown";
}

isDesiredInteractable( entity, kind )
{
    if ( !isdefined( entity ) )
    {
        return false;
    }

    switch ( kind )
    {
        case "weapon":
            return !isGenericWeaponPurchaseMarker( entity ) && ( entityMatchesToken( entity, "weapon" ) || entityMatchesToken( entity, "wallbuy" ) || entityMatchesToken( entity, "armory" ) );

        case "generic_weapon_buy":
            return isGenericWeaponPurchaseMarker( entity );

        case "mystery":
            return entityMatchesToken( entity, "mystery" ) || entityMatchesToken( entity, "printer" );

        case "revive":
            return hasReviveInteractableToken( entity ) && !isPerkInteractable( entity );

        case "perk":
            return isPerkInteractable( entity );

        case "packapunch":
            return entityMatchesToken( entity, "pack" ) || entityMatchesToken( entity, "pap" ) || entityMatchesToken( entity, "upgrade" );

        case "door":
            return entityMatchesToken( entity, "door" ) || entityMatchesToken( entity, "debris" ) || entityMatchesToken( entity, "gate" );

        case "exo":
            return entityMatchesToken( entity, "exo" ) || entityMatchesToken( entity, "ability" ) || entityMatchesToken( entity, "boost" );
    }

    return false;
}

hasReviveInteractableToken( entity )
{
    return entityMatchesToken( entity, "revive" ) || entityMatchesToken( entity, "laststand" ) || entityMatchesToken( entity, "downed" );
}

isPerkInteractable( entity )
{
    return entityMatchesToken( entity, "perk" ) || entityMatchesToken( entity, "vending" ) || entityMatchesToken( entity, "perkacola" );
}

entityMatchesToken( entity, token )
{
    if ( !isdefined( entity ) || !isdefined( token ) )
    {
        return false;
    }

    if ( isdefined( entity.targetname ) && stringContainsToken( entity.targetname, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_noteworthy ) && stringContainsToken( entity.script_noteworthy, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_linkname ) && stringContainsToken( entity.script_linkname, token ) )
    {
        return true;
    }

    if ( isdefined( entity.script_string ) && stringContainsToken( entity.script_string, token ) )
    {
        return true;
    }

    if ( isdefined( entity.model ) && stringContainsToken( entity.model, token ) )
    {
        return true;
    }

    return false;
}

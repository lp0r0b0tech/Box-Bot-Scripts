// Auto Bots + BO2 Feel Zombies Mod for Advanced Warfare Exo Zombies (S1x)
//
// Self-contained S1x entry script. Keep the constants grouped at the top so the
// package can be tuned quickly without hunting through the logic below.
//
// Compatibility notes:
// - Avoid relying on a custom GetMode() helper; use local zombies-context checks.
// - Use polling fallbacks for zombies/power-ups because notify names can vary by build.
// - Keep interactable matching token-driven so AW/S1x map trigger names are easy to retune.

#define ABZM_DEFAULT_AUTOBOTS_ENABLED         1
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
    state.botDifficulty = "ultra";
    state.botAccuracy = ABZM_DEFAULT_BOT_ACCURACY;
    state.botReactionTime = ABZM_DEFAULT_BOT_REACTION_TIME;
    state.botMaxHealth = ABZM_DEFAULT_BOT_MAX_HEALTH;
    state.botAggression = ABZM_DEFAULT_BOT_AGGRESSION;
    state.trackedZombies = [];
    state.interactableCandidates = [];
    state.interactableCacheTime = 0;
    state.purchaseItemCandidates = [];
    state.purchaseItemCacheTime = -999999;
    state.sharedPurchaseKeys = [];
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
    setdvarifuninitialized( "scr_zm_autobots_difficulty", "ultra" );
    setdvarifuninitialized( "scr_zm_autobots_accuracy", ABZM_DEFAULT_BOT_ACCURACY );
    setdvarifuninitialized( "scr_zm_autobots_reaction_time", ABZM_DEFAULT_BOT_REACTION_TIME );
    setdvarifuninitialized( "scr_zm_autobots_max_health", ABZM_DEFAULT_BOT_MAX_HEALTH );
    setdvarifuninitialized( "scr_zm_autobots_aggression", ABZM_DEFAULT_BOT_AGGRESSION );
    setdvarifuninitialized( "scr_zm_autobots_perk_cost", ABZM_DEFAULT_PERK_COST );
    setdvarifuninitialized( "scr_zm_autobots_weapon_cost", ABZM_DEFAULT_WEAPON_COST );
    setdvarifuninitialized( "scr_zm_autobots_mystery_cost", ABZM_DEFAULT_MYSTERY_COST );
    setdvarifuninitialized( "scr_zm_autobots_packapunch_cost", ABZM_DEFAULT_PACKAPUNCH_COST );
    setdvarifuninitialized( "scr_zm_autobots_door_cost", ABZM_DEFAULT_DOOR_COST );
    setdvarifuninitialized( "scr_zm_autobots_exo_cost", ABZM_DEFAULT_EXO_COST );
    setdvarifuninitialized( "scr_zm_autobots_max_perks", ABZM_DEFAULT_PERK_LIMIT );

    setdvarifuninitialized( "scr_zm_bo2_enable", ABZM_DEFAULT_BO2_TUNING_ENABLED );
    setdvarifuninitialized( "scr_zm_bo2_sprint_round", ABZM_DEFAULT_SPRINT_ROUND );
    setdvarifuninitialized( "scr_zm_bo2_crawler_chance", ABZM_DEFAULT_CRAWLER_CHANCE );
    setdvarifuninitialized( "scr_zm_bo2_special_round_interval", ABZM_DEFAULT_SPECIAL_ROUND_INTERVAL );
    setdvarifuninitialized( "scr_zm_bo2_special_round_offset", ABZM_DEFAULT_SPECIAL_ROUND_OFFSET );
    setdvarifuninitialized( "scr_zm_bo2_powerups_enable", ABZM_DEFAULT_DROPS_ENABLED );
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

    previousMaxHealth = level.abzm.botMaxHealth;
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

    self.abzmSkill = level.abzm.botSkill;
    self.botAccuracy = level.abzm.botAccuracy;
    self.reactionTime = level.abzm.botReactionTime;
    self.maxhealth = level.abzm.botMaxHealth;
    self.maxHealth = level.abzm.botMaxHealth;
    self.botAggression = level.abzm.botAggression;

    if ( !isdefined( self.health ) || level.abzm.botMaxHealth > previousMaxHealth )
    {
        self.health = self.maxhealth;
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

    if ( !isdefined( self.abzmPurchasedPerkKeys ) )
    {
        self.abzmPurchasedPerkKeys = [];
    }

    if ( !isdefined( self.abzmPurchasedUpgradeKeys ) )
    {
        self.abzmPurchasedUpgradeKeys = [];
    }
}

resetBotPerkPurchaseState()
{
    self.abzmPerkPurchases = 0;
    self.abzmPurchasedPerkKeys = [];
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
            resetBotPerkPurchaseState();
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
    bot.abzmSkill = level.abzm.botSkill;
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
        resetBotPerkPurchaseState();
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

        if ( level.abzm.botsAutoBuyUpgrades )
        {
            attemptWeaponPurchase();
        }

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
        if ( reviveResult < 0 )
        {
            if ( !isdefined( downed ) )
            {
                self.abzmReviveTarget = undefined;
                return false;
            }

            downed.abzmBleedoutTime = ABZM_BO2_BLEEDOUT_TIME;
            signalReviveSuccess( downed, self );

            fallbackStart = gettime();
            fallbackMaxWaitMs = int( (ABZM_BO2_REVIVE_TIME + 0.5) * 1000 );
            while ( isdefined( downed ) && downed.abzmDowned && (gettime() - fallbackStart) < fallbackMaxWaitMs )
            {
                wait 0.05;
            }

            if ( !isdefined( downed ) || downed.abzmDowned )
            {
                if ( isdefined( downed ) )
                {
                    downed.abzmReviver = undefined;
                }

                self.abzmReviveTarget = undefined;
                return false;
            }
        }
        else if ( reviveResult == 0 )
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
        return 0;
    }

    reviveNode = getReviveInteractableForPlayer( downed );
    if ( !isdefined( reviveNode ) )
    {
        return -1;
    }

    reviveNode notify( "trigger", self );
    reviveNode notify( "use", self );

    start = gettime();
    maxWaitMs = int( (ABZM_BO2_REVIVE_TIME + 0.5) * 1000 );
    while ( isdefined( downed ) && downed.abzmDowned && (gettime() - start) < maxWaitMs )
    {
        wait 0.05;
    }

    if ( isdefined( downed ) && !downed.abzmDowned )
    {
        return 1;
    }

    return 0;
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

        dist = distance( downed.origin, node.origin );
        if ( dist < bestDist && dist <= ABZM_BO2_REVIVE_RANGE )
        {
            best = node;
            bestDist = dist;
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

    if ( isdefined( self.abzmPerkPurchases ) && self.abzmPerkPurchases >= level.abzm.maxPerks )
    {
        return false;
    }

    perkNode = getBestPerkInteractable();
    if ( !attemptPurchase( perkNode, level.abzm.perkCost ) )
    {
        return false;
    }

    markPerkPurchase( perkNode );
    return true;
}

attemptWeaponPurchase()
{
    roundNumber = max( 1, level.abzm.round );
    weaponNode = getClosestInteractable( "weapon" );

    if ( roundNumber < 5 && !currentWeaponNeedsAmmo() && !isCurrentWeaponWeak() )
    {
        return false;
    }

    if ( roundNumber >= 8 && !isCurrentWeaponWeak() && !currentWeaponNeedsAmmo() )
    {
        return false;
    }

    if ( !botCanAttemptPurchase( ABZM_PURCHASE_COOLDOWN_SEC ) )
    {
        return false;
    }

    if ( roundNumber >= 7 )
    {
        mysteryNode = getClosestInteractable( "mystery" );
        canCoverMysteryFallback = isdefined( weaponNode ) && hasEnoughPoints( self, level.abzm.mysteryCost + level.abzm.weaponCost );
        if ( isdefined( mysteryNode ) && ( canCoverMysteryFallback || ( !isdefined( weaponNode ) && hasEnoughPoints( self, level.abzm.mysteryCost ) ) ) && attemptPurchase( mysteryNode, level.abzm.mysteryCost ) )
        {
            markGenericPurchase();
            return true;
        }
    }

    if ( !hasEnoughPoints( self, level.abzm.weaponCost ) )
    {
        return false;
    }

    if ( attemptPurchase( weaponNode, level.abzm.weaponCost ) )
    {
        markGenericPurchase();
        return true;
    }

    return false;
}

attemptUtilityPurchase()
{
    if ( !botCanAttemptPurchase( ABZM_PURCHASE_COOLDOWN_SEC ) )
    {
        return false;
    }

    if ( hasEnoughPoints( self, level.abzm.packapunchCost ) )
    {
        papNode = getClosestInteractable( "packapunch" );
        if ( attemptPurchase( papNode, level.abzm.packapunchCost ) )
        {
            markGenericPurchase();
            return true;
        }
    }

    if ( hasEnoughPoints( self, level.abzm.exoCost ) )
    {
        exoNode = getClosestInteractable( "exo" );
        if ( !alreadyBoughtBotUpgradeNode( exoNode ) && attemptPurchase( exoNode, level.abzm.exoCost ) )
        {
            markBotUpgradePurchase( exoNode );
            return true;
        }
    }

    if ( hasEnoughPoints( self, level.abzm.doorCost ) )
    {
        doorNode = getClosestInteractable( "door" );
        if ( !alreadyBoughtSharedNode( doorNode ) && attemptPurchase( doorNode, level.abzm.doorCost ) )
        {
            markSharedPurchase( doorNode );
            return true;
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

markPerkPurchase( node )
{
    key = getInteractableKey( node );
    if ( isdefined( key ) && key != "" )
    {
        self.abzmPurchasedPerkKeys[key] = true;
    }

    if ( !isdefined( self.abzmPerkPurchases ) )
    {
        self.abzmPerkPurchases = 0;
    }

    self.abzmPerkPurchases++;
    self.abzmLastPerkPurchaseTime = gettime();
    markGenericPurchase();
}

markSharedPurchase( node )
{
    if ( !isdefined( level.abzm ) )
    {
        return;
    }

    key = getInteractableKey( node );
    if ( isdefined( key ) && key != "" )
    {
        level.abzm.sharedPurchaseKeys[key] = true;
    }

    markGenericPurchase();
}

markBotUpgradePurchase( node )
{
    key = getInteractableKey( node );
    if ( isdefined( key ) && key != "" )
    {
        self.abzmPurchasedUpgradeKeys[key] = true;
    }

    markGenericPurchase();
}

alreadyBoughtPerkNode( node )
{
    key = getInteractableKey( node );
    if ( !isdefined( key ) || key == "" )
    {
        return false;
    }

    return isdefined( self.abzmPurchasedPerkKeys[key] ) && self.abzmPurchasedPerkKeys[key];
}

alreadyBoughtSharedNode( node )
{
    if ( !isdefined( level.abzm ) )
    {
        return false;
    }

    key = getInteractableKey( node );
    if ( !isdefined( key ) || key == "" )
    {
        return false;
    }

    return isdefined( level.abzm.sharedPurchaseKeys[key] ) && level.abzm.sharedPurchaseKeys[key];
}

alreadyBoughtBotUpgradeNode( node )
{
    key = getInteractableKey( node );
    if ( !isdefined( key ) || key == "" )
    {
        return false;
    }

    return isdefined( self.abzmPurchasedUpgradeKeys[key] ) && self.abzmPurchasedUpgradeKeys[key];
}


getBestPerkInteractable()
{
    nodes = getInteractableCandidates();
    best = undefined;
    bestScore = -999999;

    for ( i = 0; i < nodes.size; i++ )
    {
        node = nodes[i];
        if ( !isDesiredInteractable( node, "perk" ) || alreadyBoughtPerkNode( node ) )
        {
            continue;
        }

        score = perkPriorityForEntity( node ) * 1000;
        score -= int( distance( self.origin, node.origin ) );

        if ( score > bestScore )
        {
            best = node;
            bestScore = score;
        }
    }

    return best;
}

perkPriorityForEntity( node )
{
    if ( entityMatchesToken( node, "quick" ) || entityMatchesToken( node, "revive" ) )
    {
        return 10;
    }

    if ( entityMatchesToken( node, "health" ) || entityMatchesToken( node, "jug" ) || entityMatchesToken( node, "tough" ) )
    {
        return 9;
    }

    if ( entityMatchesToken( node, "speed" ) || entityMatchesToken( node, "reload" ) )
    {
        return 8;
    }

    if ( entityMatchesToken( node, "damage" ) || entityMatchesToken( node, "tap" ) || entityMatchesToken( node, "multishot" ) )
    {
        return 7;
    }

    if ( entityMatchesToken( node, "stamina" ) || entityMatchesToken( node, "move" ) || entityMatchesToken( node, "sprint" ) )
    {
        return 6;
    }

    return 5;
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

isCurrentWeaponWeak()
{
    weapon = self getcurrentweapon();
    if ( !isdefined( weapon ) )
    {
        return true;
    }

    weapon = toLower( weapon + "" );
    return stringContainsToken( weapon, "atlas45" ) || stringContainsToken( weapon, "pistol" ) || stringContainsToken( weapon, "starter" ) || stringContainsToken( weapon, "mp11" ) || stringContainsToken( weapon, "rw1" );
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
    if ( kind == "weapon" || kind == "mystery" )
    {
        nodes = getWeaponPurchaseCandidates();
    }
    else
    {
        nodes = getInteractableCandidates();
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
    node notify( "use", self );
    return true;
}

attemptPurchase( node, cost )
{
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

    purchaseNodes = [];
    for ( i = 0; i < nodes.size; i++ )
    {
        node = nodes[i];
        if ( isDesiredInteractable( node, "weapon" ) || isDesiredInteractable( node, "mystery" ) )
        {
            purchaseNodes[purchaseNodes.size] = node;
        }
    }

    level.abzm.interactableCandidates = nodes;
    level.abzm.purchaseItemCandidates = purchaseNodes;
    level.abzm.interactableCacheTime = gettime();
    level.abzm.purchaseItemCacheTime = level.abzm.interactableCacheTime;
    return level.abzm.interactableCandidates;
}

getWeaponPurchaseCandidates()
{
    if ( !isdefined( level.abzm ) )
    {
        nodes = [];
        return nodes;
    }

    if ( (gettime() - level.abzm.purchaseItemCacheTime) < 2000 )
    {
        return level.abzm.purchaseItemCandidates;
    }

    getInteractableCandidates();
    return level.abzm.purchaseItemCandidates;
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
            return entityMatchesToken( entity, "weapon" ) || entityMatchesToken( entity, "wallbuy" ) || entityMatchesToken( entity, "armory" );

        case "mystery":
            return entityMatchesToken( entity, "mystery" ) || entityMatchesToken( entity, "box" ) || entityMatchesToken( entity, "printer" );

        case "revive":
            return entityMatchesToken( entity, "revive" ) || entityMatchesToken( entity, "laststand" ) || entityMatchesToken( entity, "downed" );

        case "perk":
            return entityMatchesToken( entity, "perk" ) || entityMatchesToken( entity, "vending" ) || entityMatchesToken( entity, "perkacola" );

        case "packapunch":
            return entityMatchesToken( entity, "pack" ) || entityMatchesToken( entity, "pap" ) || entityMatchesToken( entity, "upgrade" );

        case "door":
            return entityMatchesToken( entity, "door" ) || entityMatchesToken( entity, "debris" ) || entityMatchesToken( entity, "gate" );

        case "exo":
            return entityMatchesToken( entity, "exo" ) || entityMatchesToken( entity, "ability" ) || entityMatchesToken( entity, "boost" );
    }

    return false;
}

getInteractableKey( entity )
{
    if ( !isdefined( entity ) )
    {
        return "";
    }

    key = "";

    if ( isdefined( entity.targetname ) && entity.targetname != "" )
    {
        key = entity.targetname;
    }
    else if ( isdefined( entity.script_noteworthy ) && entity.script_noteworthy != "" )
    {
        key = entity.script_noteworthy;
    }
    else if ( isdefined( entity.script_linkname ) && entity.script_linkname != "" )
    {
        key = entity.script_linkname;
    }
    else if ( isdefined( entity.script_string ) && entity.script_string != "" )
    {
        key = entity.script_string;
    }
    if ( key == "" )
    {
        if ( isdefined( entity.origin ) )
        {
            prefix = "origin";
            if ( isdefined( entity.classname ) && entity.classname != "" )
            {
                prefix = entity.classname;
            }

            return prefix + "_" + int( entity.origin[0] * 100 ) + "_" + int( entity.origin[1] * 100 ) + "_" + int( entity.origin[2] * 100 );
        }

        return "";
    }

    if ( isdefined( entity.origin ) )
    {
        key += "_" + int( entity.origin[0] * 100 ) + "_" + int( entity.origin[1] * 100 ) + "_" + int( entity.origin[2] * 100 );
    }

    return key;
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

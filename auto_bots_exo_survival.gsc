// Auto Bots for Advanced Warfare Exo Survival (S1x)
//
// Teammate-focused bot package for Exo Survival only.
// This script intentionally does not enable in Exo Zombies contexts.

#define ABES_DEFAULT_AUTOBOTS_ENABLED           1
#define ABES_DEFAULT_BOT_COUNT                  3
#define ABES_DEFAULT_BOT_SKILL                  1.0
#define ABES_DEFAULT_BOTS_CAN_REVIVE            1
#define ABES_DEFAULT_BOTS_AUTO_BUY              1
#define ABES_DEFAULT_BOTS_AUTO_UPGRADE          1
#define ABES_DEFAULT_BOTS_AUTO_RESTOCK          1
#define ABES_DEFAULT_BOTS_USE_EQUIPMENT         1
#define ABES_DEFAULT_BOTS_USE_SCORESTREAKS      1
#define ABES_DEFAULT_BOTS_USE_EXO_ABILITIES     1
#define ABES_DEFAULT_BOTS_FOLLOW_TEAM           1
#define ABES_DEFAULT_FORCE_LOADOUT              1
#define ABES_DEFAULT_FORCE_WEAPON_PROFICIENCY   10
#define ABES_DEFAULT_FORCE_ARMOR_LEVEL          10
#define ABES_DEFAULT_FORCE_EXO_BATTERY_LEVEL    5
#define ABES_FORCE_WEAPON_PROFICIENCY_MAX       10
#define ABES_FORCE_ARMOR_LEVEL_MAX              10
#define ABES_FORCE_EXO_BATTERY_LEVEL_MAX        5
#define ABES_FORCE_WEAPON_PROFICIENCY_UNLOCK_ROUND 5
#define ABES_FORCE_ARMOR_UNLOCK_ROUND           10
#define ABES_FORCE_EXO_BATTERY_UNLOCK_ROUND     15

#define ABES_MAX_BOTS                            4
#define ABES_INTERACT_RANGE                      96
#define ABES_INTERACT_MOVE_TIMEOUT_MS            1200
#define ABES_REVIVE_RANGE                         96
#define ABES_REVIVE_TIME                          4.0
#define ABES_REVIVE_CLAIM_TIMEOUT_SEC             2.5
#define ABES_REVIVE_MOVE_TIMEOUT_MS             1500
#define ABES_THINK_INTERVAL                       0.25
#define ABES_EQUIPMENT_COOLDOWN_SEC              12.0
#define ABES_SCORESTREAK_COOLDOWN_SEC            20.0
#define ABES_EXO_COOLDOWN_SEC                    15.0
#define ABES_STUCK_DISTANCE                       18
#define ABES_STUCK_TIME_SEC                        2.5

#define ABES_FORCE_LOADOUT_PRIMARY               "ameli_mp"
#define ABES_FORCE_LOADOUT_SECONDARY             "pytaek_mp"
#define ABES_FORCE_LOADOUT_LETHAL                "contact_grenade_mp"

main()
{
    init();
}

tryUseReviveInteraction( downed )
{
    if ( !isdefined( downed ) || !downed.abesDowned )
    {
        return false;
    }

    downed notify( "trigger", self );
    downed notify( "use", self );
    self notify( "+activate" );

    start = gettime();
    while ( isdefined( downed ) && downed.abesDowned && (gettime() - start) < 1000 )
    {
        wait 0.05;
    }

    return isdefined( downed ) && !downed.abesDowned;
}

init()
{
    if ( isdefined( level.abesInitStarted ) && level.abesInitStarted )
    {
        return;
    }

    level.abesInitStarted = true;
    level thread abesDeferredInit();
}

abesDeferredInit()
{
    wait 0.25;

    if ( !abesIsExoSurvivalContext() )
    {
        return;
    }

    level.abes = buildModState();
    initDvars();
    level thread abesBoot();
}

abesBoot()
{
    level endon( "game_ended" );

    wait 0.25;
    refreshRuntimeConfig();
    if ( !level.abes.enabled )
    {
        return;
    }

    initializeExistingPlayers();
    level thread monitorPlayerConnections();
    level thread maintainAutoBots();
    level thread periodicEnemyRefresh();
}

buildModState()
{
    state = spawnstruct();
    state.enabled = false;
    state.autoBotsEnabled = false;
    state.botCount = 0;
    state.botSkill = 1.0;
    state.interactableCandidates = [];
    state.interactableCacheTime = 0;
    state.trackedEnemies = [];
    return state;
}

initDvars()
{
    setdvarifuninitialized( "scr_es_autobots_enabled", ABES_DEFAULT_AUTOBOTS_ENABLED );
    setdvarifuninitialized( "scr_es_autobots_enable", ABES_DEFAULT_AUTOBOTS_ENABLED );
    setdvarifuninitialized( "scr_es_autobots_count", ABES_DEFAULT_BOT_COUNT );
    setdvarifuninitialized( "scr_es_autobots_skill", ABES_DEFAULT_BOT_SKILL );
    setdvarifuninitialized( "scr_es_autobots_revive", ABES_DEFAULT_BOTS_CAN_REVIVE );
    setdvarifuninitialized( "scr_es_autobots_buy", ABES_DEFAULT_BOTS_AUTO_BUY );
    setdvarifuninitialized( "scr_es_autobots_upgrade", ABES_DEFAULT_BOTS_AUTO_UPGRADE );
    setdvarifuninitialized( "scr_es_autobots_restock", ABES_DEFAULT_BOTS_AUTO_RESTOCK );
    setdvarifuninitialized( "scr_es_autobots_equipment", ABES_DEFAULT_BOTS_USE_EQUIPMENT );
    setdvarifuninitialized( "scr_es_autobots_scorestreaks", ABES_DEFAULT_BOTS_USE_SCORESTREAKS );
    setdvarifuninitialized( "scr_es_autobots_exo", ABES_DEFAULT_BOTS_USE_EXO_ABILITIES );
    setdvarifuninitialized( "scr_es_autobots_follow", ABES_DEFAULT_BOTS_FOLLOW_TEAM );
    setdvarifuninitialized( "scr_es_autobots_force_loadout", ABES_DEFAULT_FORCE_LOADOUT );
    setdvarifuninitialized( "scr_es_autobots_force_weapon_proficiency", ABES_DEFAULT_FORCE_WEAPON_PROFICIENCY );
    setdvarifuninitialized( "scr_es_autobots_force_armor_level", ABES_DEFAULT_FORCE_ARMOR_LEVEL );
    setdvarifuninitialized( "scr_es_autobots_force_exo_battery", ABES_DEFAULT_FORCE_EXO_BATTERY_LEVEL );

    setdvarifuninitialized( "scr_es_autobots_weapon_cost", 2000 );
    setdvarifuninitialized( "scr_es_autobots_mystery_cost", 950 );
    setdvarifuninitialized( "scr_es_autobots_ammo_cost", 750 );
    setdvarifuninitialized( "scr_es_autobots_upgrade_cost", 1500 );
    setdvarifuninitialized( "scr_es_autobots_armor_cost", 1200 );
    setdvarifuninitialized( "scr_es_autobots_support_cost", 800 );
    setdvarifuninitialized( "scr_es_autobots_equipment_cost", 600 );
}

refreshRuntimeConfig()
{
    level.abes.autoBotsEnabled = getdvarint( "scr_es_autobots_enable" ) > 0 || getdvarint( "scr_es_autobots_enabled" ) > 0;
    level.abes.botCount = abesClamp( getdvarint( "scr_es_autobots_count" ), 0, ABES_MAX_BOTS );
    level.abes.botSkill = abesClamp( getdvarfloat( "scr_es_autobots_skill" ), 0.25, 3.0 );

    level.abes.botsCanRevive = getdvarint( "scr_es_autobots_revive" ) > 0;
    level.abes.botsAutoBuy = getdvarint( "scr_es_autobots_buy" ) > 0;
    level.abes.botsAutoUpgrade = getdvarint( "scr_es_autobots_upgrade" ) > 0;
    level.abes.botsAutoRestock = getdvarint( "scr_es_autobots_restock" ) > 0;
    level.abes.botsUseEquipment = getdvarint( "scr_es_autobots_equipment" ) > 0;
    level.abes.botsUseScorestreaks = getdvarint( "scr_es_autobots_scorestreaks" ) > 0;
    level.abes.botsUseExoAbilities = getdvarint( "scr_es_autobots_exo" ) > 0;
    level.abes.botsFollowTeam = getdvarint( "scr_es_autobots_follow" ) > 0;
    level.abes.forceLoadoutEnabled = getdvarint( "scr_es_autobots_force_loadout" ) > 0;
    level.abes.forceWeaponProficiency = abesClamp( getdvarint( "scr_es_autobots_force_weapon_proficiency" ), 0, ABES_FORCE_WEAPON_PROFICIENCY_MAX );
    level.abes.forceArmorLevel = abesClamp( getdvarint( "scr_es_autobots_force_armor_level" ), 0, ABES_FORCE_ARMOR_LEVEL_MAX );
    level.abes.forceExoBatteryLevel = abesClamp( getdvarint( "scr_es_autobots_force_exo_battery" ), 0, ABES_FORCE_EXO_BATTERY_LEVEL_MAX );

    level.abes.weaponCost = max( 0, getdvarint( "scr_es_autobots_weapon_cost" ) );
    level.abes.mysteryCost = max( 0, getdvarint( "scr_es_autobots_mystery_cost" ) );
    level.abes.ammoCost = max( 0, getdvarint( "scr_es_autobots_ammo_cost" ) );
    level.abes.upgradeCost = max( 0, getdvarint( "scr_es_autobots_upgrade_cost" ) );
    level.abes.armorCost = max( 0, getdvarint( "scr_es_autobots_armor_cost" ) );
    level.abes.supportCost = max( 0, getdvarint( "scr_es_autobots_support_cost" ) );
    level.abes.equipmentCost = max( 0, getdvarint( "scr_es_autobots_equipment_cost" ) );

    if ( level.abes.forceLoadoutEnabled )
    {
        level.abes.botsAutoBuy = false;
        level.abes.botsAutoUpgrade = false;
        level.abes.botsAutoRestock = false;
    }

    level.abes.enabled = level.abes.autoBotsEnabled;
}

abesIsExoSurvivalContext()
{
    if ( isdefined( level.zombiemode ) && level.zombiemode )
    {
        return false;
    }

    if ( isdefined( level.zombieMap ) && level.zombieMap )
    {
        return false;
    }

    gt = safeLower( level.gametype );
    mn = safeLower( level.mapname );
    pl = safeLower( level.playlist );

    if ( containsAny2( gt, "zom", "zombie" ) || containsAny2( mn, "zm_", "zombie" ) || containsAny2( pl, "zom", "zombie" ) )
    {
        return false;
    }

    if ( hasExoSurvivalToken( gt ) || hasExoSurvivalToken( pl ) || hasExoSurvivalToken( mn ) )
    {
        return true;
    }

    if ( isdefined( level.survivalMode ) && level.survivalMode )
    {
        return true;
    }

    if ( hasExoSurvivalToken( getdvar( "ui_gametype" ) ) || hasExoSurvivalToken( getdvar( "g_gametype" ) ) || hasExoSurvivalToken( getdvar( "ui_mapname" ) ) )
    {
        return true;
    }

    if ( isdefined( level.survivalMode ) && level.survivalMode && hasExoSurvivalToken( getdvar( "ui_gametype" ) ) )
    {
        return true;
    }

    return false;
}

hasExoSurvivalToken( value )
{
    return stringContainsToken( value, "exo survival" ) || stringContainsToken( value, "exo_survival" ) || stringContainsToken( value, "survival_exo" );
}

monitorPlayerConnections()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );
        registerPlayerConnectionHandler( player );
    }
}

initializeExistingPlayers()
{
    players = getentarray( "player", "classname" );

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( isdefined( player ) )
        {
            registerPlayerConnectionHandler( player );
        }
    }
}

registerPlayerConnectionHandler( player )
{
    if ( !isdefined( player ) )
    {
        return;
    }

    if ( isdefined( player.abesConnectedHandlerStarted ) && player.abesConnectedHandlerStarted )
    {
        return;
    }

    player.abesConnectedHandlerStarted = true;
    player thread onPlayerConnected();
}

onPlayerConnected()
{
    self endon( "disconnect" );

    if ( !isdefined( self.abesDownedTrackerStarted ) || !self.abesDownedTrackerStarted )
    {
        self.abesDownedTrackerStarted = true;
        self thread trackDownedState();
    }

    for ( ;; )
    {
        self waittill( "spawned_player" );

        if ( isBotEntity( self ) )
        {
            self.abesIsBot = true;
            self.abesSkill = level.abes.botSkill;
            grantForcedBotLoadout();
            if ( !isdefined( self.abesLifeLoopStarted ) || !self.abesLifeLoopStarted )
            {
                self.abesLifeLoopStarted = true;
                self thread botLifeLoop();
            }
        }
    }
}

trackDownedState()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill_any( "downed", "laststand", "bleed_out" );
        self.abesDowned = true;
        self.abesDownedAt = gettime();
        clearActiveReviveClaim();

        self waittill_any( "revived", "spawned_player" );
        self.abesDowned = false;
        self.abesDownedAt = undefined;
        self.abesReviveClaimant = undefined;
        self.abesReviveClaimTime = undefined;
    }
}

maintainAutoBots()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        refreshRuntimeConfig();

        targetBotCount = 0;
        if ( level.abes.autoBotsEnabled )
        {
            targetBotCount = level.abes.botCount;
        }

        trimAutoBots( targetBotCount );
        while ( getActiveBotCount() < targetBotCount )
        {
            if ( !spawnAutoBot() )
            {
                wait 1.0;
            }

            wait 0.25;
        }

        wait 2.0;
    }
}

spawnAutoBot()
{
    bot = addtestclient();
    if ( !isdefined( bot ) )
    {
        return false;
    }

    bot.abesIsBot = true;
    bot.pers["isBot"] = true;
    bot.abesSkill = level.abes.botSkill;
    registerPlayerConnectionHandler( bot );
    return true;
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

botLifeLoop()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        if ( self.abesDowned )
        {
            self waittill_any( "revived", "spawned_player", "disconnect" );
            continue;
        }

        if ( !isdefined( self.abesBrainRunning ) || !self.abesBrainRunning )
        {
            self.abesBrainRunning = true;
            self thread botBrainLoop();
        }

        self waittill_any( "death", "downed", "disconnect" );
        clearActiveReviveClaim();
        self notify( "abes_stop_brain" );
        self.abesBrainRunning = false;
        wait 0.25;
    }
}

botBrainLoop()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "downed" );
    self endon( "abes_stop_brain" );

    for ( ;; )
    {
        refreshRuntimeConfig();

        if ( level.abes.botsCanRevive && attemptBotRevive() )
        {
            wait 0.1;
            continue;
        }

        maintainForcedBotLoadout();

        if ( shouldRetreat() )
        {
            moveToRetreatAnchor();
        }
        else
        {
            runRegroupMovement();
        }

        if ( shouldAttemptUnstick() )
        {
            performUnstickMove();
        }

        if ( level.abes.botsAutoRestock )
        {
            attemptAmmoRestock();
        }

        if ( level.abes.botsAutoBuy )
        {
            attemptWeaponPurchase();
        }

        if ( level.abes.botsAutoUpgrade )
        {
            attemptUpgradePurchase();
        }

        if ( level.abes.botsUseEquipment )
        {
            useEquipmentIfNeeded();
        }

        if ( level.abes.botsUseScorestreaks )
        {
            useScorestreakIfNeeded();
        }

        if ( level.abes.botsUseExoAbilities )
        {
            useExoAbilityIfNeeded();
        }

        wait ABES_THINK_INTERVAL;
    }
}

grantForcedBotLoadout()
{
    if ( !isBotEntity( self ) || !isdefined( level.abes ) || !level.abes.forceLoadoutEnabled )
    {
        return false;
    }

    currentWeapon = self getcurrentweapon();
    if ( isdefined( currentWeapon ) && currentWeapon != "" && currentWeapon != ABES_FORCE_LOADOUT_PRIMARY && currentWeapon != ABES_FORCE_LOADOUT_SECONDARY && currentWeapon != ABES_FORCE_LOADOUT_LETHAL )
    {
        self takeweapon( currentWeapon );
    }

    self giveweapon( ABES_FORCE_LOADOUT_PRIMARY );
    self giveweapon( ABES_FORCE_LOADOUT_SECONDARY );
    self giveweapon( ABES_FORCE_LOADOUT_LETHAL );
    self givemaxammo( ABES_FORCE_LOADOUT_PRIMARY );
    self givemaxammo( ABES_FORCE_LOADOUT_SECONDARY );
    self switchtoweapon( ABES_FORCE_LOADOUT_PRIMARY );
    applyForcedBotEnhancements();
    self.abesForcedLoadoutGrantedAt = gettime();
    self.abesForcedLoadoutMaintainedAt = self.abesForcedLoadoutGrantedAt;
    return true;
}

maintainForcedBotLoadout()
{
    if ( !isBotEntity( self ) || !isdefined( level.abes ) || !level.abes.forceLoadoutEnabled )
    {
        return false;
    }

    if ( !isdefined( self.abesForcedLoadoutGrantedAt ) )
    {
        return grantForcedBotLoadout();
    }

    if ( isdefined( self.abesForcedLoadoutMaintainedAt ) && (gettime() - self.abesForcedLoadoutMaintainedAt) < 5000 )
    {
        return false;
    }

    previousWeapon = self getcurrentweapon();
    self giveweapon( ABES_FORCE_LOADOUT_PRIMARY );
    self giveweapon( ABES_FORCE_LOADOUT_SECONDARY );
    self giveweapon( ABES_FORCE_LOADOUT_LETHAL );
    self givemaxammo( ABES_FORCE_LOADOUT_PRIMARY );
    self givemaxammo( ABES_FORCE_LOADOUT_SECONDARY );

    if ( isdefined( previousWeapon ) && (previousWeapon == ABES_FORCE_LOADOUT_PRIMARY || previousWeapon == ABES_FORCE_LOADOUT_SECONDARY) )
    {
        self switchtoweapon( previousWeapon );
    }
    else
    {
        self switchtoweapon( ABES_FORCE_LOADOUT_PRIMARY );
    }

    applyForcedBotEnhancements();
    self.abesForcedLoadoutMaintainedAt = gettime();
    return true;
}

applyForcedBotEnhancements()
{
    if ( !isBotEntity( self ) || !isdefined( level.abes ) || !level.abes.forceLoadoutEnabled )
    {
        return;
    }

    forcedWeaponProficiencyLevel = getForcedWeaponProficiencyLevel();
    forcedArmorLevel = getForcedArmorLevel();
    forcedExoBatteryLevel = getForcedExoBatteryLevel();

    applyForcedBotUpgradeAlias( "weaponProficiency", forcedWeaponProficiencyLevel );
    applyForcedBotUpgradeAlias( "weaponProficiencyLevel", forcedWeaponProficiencyLevel );
    applyForcedBotUpgradeAlias( "weapon_proficiency", forcedWeaponProficiencyLevel );
    applyForcedBotUpgradeAlias( "armorLevel", forcedArmorLevel );
    applyForcedBotUpgradeAlias( "armourLevel", forcedArmorLevel );
    applyForcedBotUpgradeAlias( "armor", forcedArmorLevel );
    applyForcedBotUpgradeAlias( "armour", forcedArmorLevel );
    applyForcedBotUpgradeAlias( "exoBattery", forcedExoBatteryLevel );
    applyForcedBotUpgradeAlias( "exoBatteryLevel", forcedExoBatteryLevel );
    applyForcedBotUpgradeAlias( "exobattery", forcedExoBatteryLevel );
    applyForcedBotUpgradeAlias( "exo_battery", forcedExoBatteryLevel );

    if ( !isdefined( self.pers ) )
    {
        self.pers = [];
    }

    self.pers["abes_force_weapon_proficiency"] = forcedWeaponProficiencyLevel;
    self.pers["abes_force_armor_level"] = forcedArmorLevel;
    self.pers["abes_force_exo_battery"] = forcedExoBatteryLevel;
    self.pers["weaponProficiency"] = forcedWeaponProficiencyLevel;
    self.pers["weapon_proficiency"] = forcedWeaponProficiencyLevel;
    self.pers["armorLevel"] = forcedArmorLevel;
    self.pers["armourLevel"] = forcedArmorLevel;
    self.pers["exoBattery"] = forcedExoBatteryLevel;
    self.pers["exo_battery"] = forcedExoBatteryLevel;

    if ( isdefined( self.maxhealth ) && isdefined( self.health ) && self.health < self.maxhealth )
    {
        self.health = self.maxhealth;
    }
}

getForcedWeaponProficiencyLevel()
{
    roundNumber = getCurrentSurvivalRound();
    if ( roundNumber < ABES_FORCE_WEAPON_PROFICIENCY_UNLOCK_ROUND )
    {
        return 0;
    }

    return min( level.abes.forceWeaponProficiency, ABES_FORCE_WEAPON_PROFICIENCY_MAX );
}

getForcedArmorLevel()
{
    roundNumber = getCurrentSurvivalRound();
    if ( roundNumber < ABES_FORCE_ARMOR_UNLOCK_ROUND )
    {
        return 0;
    }

    return min( level.abes.forceArmorLevel, ABES_FORCE_ARMOR_LEVEL_MAX );
}

getForcedExoBatteryLevel()
{
    roundNumber = getCurrentSurvivalRound();
    if ( roundNumber < ABES_FORCE_EXO_BATTERY_UNLOCK_ROUND )
    {
        return 0;
    }

    return min( level.abes.forceExoBatteryLevel, ABES_FORCE_EXO_BATTERY_LEVEL_MAX );
}

applyForcedBotUpgradeAlias( key, value )
{
    if ( !isdefined( key ) || key == "" || !isdefined( value ) )
    {
        return;
    }

    existingValue = 0;
    if ( isdefined( self[key] ) )
    {
        existingValue = int( self[key] );
    }

    if ( value > existingValue )
    {
        self[key] = value;
    }
}

attemptBotRevive()
{
    downed = getClosestDownedTeammate();
    if ( !isdefined( downed ) )
    {
        return false;
    }

    if ( !claimReviveTarget( downed ) )
    {
        return false;
    }

    self.abesReviveTarget = downed;
    self.abesState = "reviving";
    self setlookatpos( downed.origin );
    self moveto( downed.origin, 0.35 );

    reviveMoveStart = gettime();
    while ( true )
    {
        if ( !isdefined( downed ) || !downed.abesDowned || !reviveClaimStillValid( downed ) )
        {
            releaseReviveClaim( downed );
            return false;
        }

        if ( distance( self.origin, downed.origin ) <= ABES_REVIVE_RANGE )
        {
            break;
        }

        if ( gettime() - reviveMoveStart >= ABES_REVIVE_MOVE_TIMEOUT_MS )
        {
            releaseReviveClaim( downed );
            return false;
        }

        wait 0.05;
    }

    reviveProgress = 0.0;
    while ( reviveProgress < ABES_REVIVE_TIME )
    {
        if ( !isdefined( downed ) || !downed.abesDowned || !reviveClaimStillValid( downed ) )
        {
            if ( isdefined( downed ) )
            {
                releaseReviveClaim( downed );
            }
            return false;
        }

        if ( !isalive( self ) || self.abesDowned )
        {
            releaseReviveClaim( downed );
            return false;
        }

        if ( distance( self.origin, downed.origin ) > ABES_REVIVE_RANGE )
        {
            releaseReviveClaim( downed );
            return false;
        }

        wait 0.05;
        reviveProgress += 0.05;
    }

    if ( !downed.abesDowned )
    {
        releaseReviveClaim( downed );
        return true;
    }

    if ( downed.abesDowned )
    {
        if ( tryUseReviveInteraction( downed ) )
        {
            releaseReviveClaim( downed );
            return true;
        }

        releaseReviveClaim( downed );
        return false;
    }

    releaseReviveClaim( downed );
    return false;
}

claimReviveTarget( downed )
{
    if ( !isdefined( downed ) || !downed.abesDowned )
    {
        return false;
    }

    if ( isdefined( downed.abesClaimLock ) && downed.abesClaimLock )
    {
        return false;
    }

    downed.abesClaimLock = true;

    if ( isdefined( downed.abesReviveClaimant ) && downed.abesReviveClaimant != self )
    {
        claimAge = 999999;
        if ( isdefined( downed.abesReviveClaimTime ) )
        {
            claimAge = (gettime() - downed.abesReviveClaimTime) / 1000.0;
        }

        if ( claimAge < ABES_REVIVE_CLAIM_TIMEOUT_SEC )
        {
            downed.abesClaimLock = false;
            return false;
        }
    }

    downed.abesReviveClaimant = self;
    downed.abesReviveClaimTime = gettime();
    if ( !isdefined( downed.abesReviveClaimant ) || downed.abesReviveClaimant != self )
    {
        downed.abesClaimLock = false;
        return false;
    }
    downed.abesClaimLock = false;
    return true;
}

reviveClaimStillValid( downed )
{
    if ( !isdefined( downed ) )
    {
        return false;
    }

    return isdefined( downed.abesReviveClaimant ) && downed.abesReviveClaimant == self;
}

releaseReviveClaim( downed )
{
    if ( isdefined( downed ) && isdefined( downed.abesReviveClaimant ) && downed.abesReviveClaimant == self )
    {
        downed.abesReviveClaimant = undefined;
        downed.abesReviveClaimTime = undefined;
    }

    self.abesReviveTarget = undefined;
}

runRegroupMovement()
{
    if ( !level.abes.botsFollowTeam )
    {
        return;
    }

    target = chooseRegroupAnchor();
    if ( !isdefined( target ) )
    {
        return;
    }

    self.abesState = "regroup";
    self setlookatpos( target );
    self moveto( target, 0.2 );
}

shouldRetreat()
{
    if ( !isalive( self ) )
    {
        return false;
    }

    if ( isdefined( self.maxhealth ) && self.maxhealth > 0 && self.health <= int( self.maxhealth * 0.4 ) )
    {
        return true;
    }

    if ( currentWeaponNeedsAmmo() )
    {
        return true;
    }

    return countNearbyEnemies( self.origin, 180 ) >= 8;
}

moveToRetreatAnchor()
{
    retreat = chooseRetreatAnchor();
    if ( !isdefined( retreat ) )
    {
        return;
    }

    self.abesState = "retreat";
    self setlookatpos( retreat );
    self moveto( retreat, 0.25 );
}

shouldAttemptUnstick()
{
    if ( !isdefined( self.abesLastStuckOrigin ) )
    {
        self.abesLastStuckOrigin = self.origin;
        self.abesLastStuckCheck = gettime();
        return false;
    }

    elapsed = (gettime() - self.abesLastStuckCheck) / 1000.0;
    if ( elapsed < ABES_STUCK_TIME_SEC )
    {
        return false;
    }

    moved = distance( self.origin, self.abesLastStuckOrigin );
    self.abesLastStuckOrigin = self.origin;
    self.abesLastStuckCheck = gettime();

    return moved <= ABES_STUCK_DISTANCE;
}

performUnstickMove()
{
    self.abesState = "unstick";
    offset = (randomint( 160 ) - 80, randomint( 160 ) - 80, 24);
    self setlookatpos( self.origin + offset );
    self moveto( self.origin + offset, 0.2 );
    self jump();
}

attemptAmmoRestock()
{
    if ( isdefined( level.abes.forceLoadoutEnabled ) && level.abes.forceLoadoutEnabled )
    {
        return false;
    }

    if ( !currentWeaponNeedsAmmo() )
    {
        return false;
    }

    if ( !hasEnoughScore( self, level.abes.ammoCost ) )
    {
        return false;
    }

    ammoNode = getClosestInteractable( "ammo" );
    return attemptPurchase( ammoNode, level.abes.ammoCost );
}

attemptWeaponPurchase()
{
    if ( isdefined( level.abes.forceLoadoutEnabled ) && level.abes.forceLoadoutEnabled )
    {
        return false;
    }

    roundNumber = getCurrentSurvivalRound();
    if ( roundNumber < 10 && !currentWeaponNeedsAmmo() )
    {
        return false;
    }

    if ( roundNumber >= 10 && !isCurrentWeaponWeak() && !currentWeaponNeedsAmmo() )
    {
        return false;
    }

    if ( roundNumber >= 15 && hasEnoughScore( self, level.abes.mysteryCost ) )
    {
        mystery = getClosestInteractable( "mystery" );
        if ( attemptPurchase( mystery, level.abes.mysteryCost ) )
        {
            return true;
        }
    }

    if ( !hasEnoughScore( self, level.abes.weaponCost ) )
    {
        return false;
    }

    weaponNode = getClosestInteractable( "weapon" );
    return attemptPurchase( weaponNode, level.abes.weaponCost );
}

attemptUpgradePurchase()
{
    if ( isdefined( level.abes.forceLoadoutEnabled ) && level.abes.forceLoadoutEnabled )
    {
        applyForcedBotEnhancements();
        return false;
    }

    if ( hasEnoughScore( self, level.abes.upgradeCost ) )
    {
        exoNode = getClosestInteractable( "exo_upgrade" );
        if ( attemptPurchase( exoNode, level.abes.upgradeCost ) )
        {
            return true;
        }
    }

    if ( hasEnoughScore( self, level.abes.armorCost ) )
    {
        armorNode = getClosestInteractable( "armor" );
        if ( attemptPurchase( armorNode, level.abes.armorCost ) )
        {
            return true;
        }
    }

    if ( hasEnoughScore( self, level.abes.supportCost ) )
    {
        supportNode = getClosestInteractable( "support" );
        if ( attemptPurchase( supportNode, level.abes.supportCost ) )
        {
            return true;
        }
    }

    if ( hasEnoughScore( self, level.abes.equipmentCost ) )
    {
        equipNode = getClosestInteractable( "equipment" );
        if ( attemptPurchase( equipNode, level.abes.equipmentCost ) )
        {
            return true;
        }
    }

    return false;
}

useEquipmentIfNeeded()
{
    nearby = countNearbyEnemies( self.origin, 140 );
    if ( nearby < 4 )
    {
        return;
    }

    if ( isdefined( self.abesLastEquipmentUse ) && ((gettime() - self.abesLastEquipmentUse) / 1000.0) < ABES_EQUIPMENT_COOLDOWN_SEC )
    {
        return;
    }

    if ( nearby >= 8 )
    {
        self notify( "frag_grenade" );
    }
    else
    {
        self notify( "tactical_grenade" );
    }

    self.abesLastEquipmentUse = gettime();
}

useScorestreakIfNeeded()
{
    nearby = countNearbyEnemies( self.origin, 180 );
    if ( nearby < 10 )
    {
        return;
    }

    if ( isdefined( self.abesLastScorestreakUse ) && ((gettime() - self.abesLastScorestreakUse) / 1000.0) < ABES_SCORESTREAK_COOLDOWN_SEC )
    {
        return;
    }

    self notify( "use_scorestreak" );
    self notify( "activate_streak" );
    self.abesLastScorestreakUse = gettime();
}

useExoAbilityIfNeeded()
{
    lowHealth = isdefined( self.maxhealth ) && self.maxhealth > 0 && self.health <= int( self.maxhealth * 0.45 );
    crowded = countNearbyEnemies( self.origin, 120 ) >= 7;

    if ( !lowHealth && !crowded )
    {
        return;
    }

    if ( isdefined( self.abesLastExoUse ) && ((gettime() - self.abesLastExoUse) / 1000.0) < ABES_EXO_COOLDOWN_SEC )
    {
        return;
    }

    self notify( "exo_ability" );
    self notify( "exo_boost" );
    self.abesLastExoUse = gettime();
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

    return containsAny5( safeLower( weapon ), "atlas45", "pistol", "starter", "pdw", "mp11" );
}

getCurrentSurvivalRound()
{
    if ( isdefined( level.currentRound ) )
    {
        return max( 1, int( level.currentRound ) );
    }

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

getClosestDownedTeammate()
{
    players = getentarray( "player", "classname" );
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( !isdefined( player ) || player == self || !isTeammateEntity( player, self ) )
        {
            continue;
        }

        if ( !isdefined( player.abesDowned ) || !player.abesDowned )
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

chooseRegroupAnchor()
{
    targetPlayer = getClosestAliveHumanTeammate();
    if ( !isdefined( targetPlayer ) )
    {
        targetPlayer = getClosestAliveTeammate();
    }

    if ( isdefined( targetPlayer ) )
    {
        return targetPlayer.origin;
    }

    return self.origin + (64, 0, 0);
}

chooseRetreatAnchor()
{
    enemy = getClosestEnemy();
    if ( !isdefined( enemy ) )
    {
        return self.origin + (-96, 0, 0);
    }

    away = vectornormalize( self.origin - enemy.origin );
    return self.origin + (away * 220);
}

getClosestAliveHumanTeammate()
{
    players = getentarray( "player", "classname" );
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( !isdefined( player ) || player == self || isBotEntity( player ) || !isTeammateEntity( player, self ) )
        {
            continue;
        }

        if ( !isalive( player ) || (isdefined( player.abesDowned ) && player.abesDowned) )
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

getClosestAliveTeammate()
{
    players = getentarray( "player", "classname" );
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];
        if ( !isdefined( player ) || player == self || !isTeammateEntity( player, self ) )
        {
            continue;
        }

        if ( !isalive( player ) || (isdefined( player.abesDowned ) && player.abesDowned) )
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
    nodes = getInteractableCandidates();

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

attemptPurchase( node, cost )
{
    scoreBefore = undefined;
    weaponBefore = undefined;
    clipBefore = -1;

    if ( !isdefined( node ) )
    {
        return false;
    }

    if ( interactionOnCooldown( node ) )
    {
        return false;
    }

    if ( cost > 0 && !hasEnoughScore( self, cost ) )
    {
        return false;
    }

    if ( isdefined( self.score ) )
    {
        scoreBefore = self.score;
    }

    weaponBefore = self getcurrentweapon();
    if ( isdefined( weaponBefore ) )
    {
        clipBefore = self getweaponammoclip( weaponBefore );
    }

    if ( !moveToAndUse( node ) )
    {
        return false;
    }

    if ( cost <= 0 )
    {
        markInteractionSuccess( node );
        return true;
    }

    for ( elapsed = 0.0; elapsed < 1.0; elapsed += 0.1 )
    {
        wait 0.1;

        if ( isdefined( scoreBefore ) && isdefined( self.score ) && self.score < scoreBefore )
        {
            markInteractionSuccess( node );
            return true;
        }

        weaponNow = self getcurrentweapon();
        if ( isdefined( weaponBefore ) && isdefined( weaponNow ) && weaponNow != weaponBefore )
        {
            markInteractionSuccess( node );
            return true;
        }

        if ( isdefined( weaponNow ) && clipBefore >= 0 && self getweaponammoclip( weaponNow ) > clipBefore )
        {
            markInteractionSuccess( node );
            return true;
        }
    }

    markInteractionSuccess( node );
    return true;
}

moveToAndUse( node )
{
    if ( !isdefined( node ) )
    {
        return false;
    }

    self setlookatpos( node.origin );
    moveTarget = node.origin;
    distToNode = distance( self.origin, node.origin );
    if ( distToNode > ABES_INTERACT_RANGE )
    {
        towardNode = vectornormalize( node.origin - self.origin );
        moveTarget = node.origin - (towardNode * (ABES_INTERACT_RANGE - 24));
    }
    self moveto( moveTarget, 0.25 );
    markInteractionAttempt( node );

    startTime = gettime();
    while ( distance( self.origin, node.origin ) > ABES_INTERACT_RANGE )
    {
        if ( gettime() - startTime >= ABES_INTERACT_MOVE_TIMEOUT_MS )
        {
            return false;
        }

        wait 0.05;
    }

    node notify( "trigger", self );
    node notify( "use", self );
    self notify( "+activate" );
    return true;
}

interactionOnCooldown( node )
{
    return isdefined( self.abesLastInteractTarget ) && self.abesLastInteractTarget == node && isdefined( self.abesLastInteractTime ) && (gettime() - self.abesLastInteractTime) < 700;
}

markInteractionAttempt( node )
{
    self.abesLastInteractTarget = node;
    self.abesLastInteractTime = gettime();
}

markInteractionSuccess( node )
{
    markInteractionAttempt( node );
    self.abesLastPurchaseSuccessTime = gettime();
}

getInteractableCandidates()
{
    if ( (gettime() - level.abes.interactableCacheTime) < 2000 && level.abes.interactableCandidates.size > 0 )
    {
        return level.abes.interactableCandidates;
    }

    rawNodes = [];
    appendEntArray( rawNodes, getentarray( "trigger", "classname" ) );
    appendEntArray( rawNodes, getentarray( "trigger_use", "classname" ) );
    appendEntArray( rawNodes, getentarray( "script_model", "classname" ) );
    appendEntArray( rawNodes, getentarray( "script_brushmodel", "classname" ) );
    appendEntArray( rawNodes, getentarray( "weapon", "classname" ) );
    appendEntArray( rawNodes, getentarray( "item", "classname" ) );

    nodes = [];
    for ( i = 0; i < rawNodes.size; i++ )
    {
        node = rawNodes[i];
        if ( isPotentialInteractable( node ) )
        {
            nodes[nodes.size] = node;
        }
    }

    level.abes.interactableCandidates = nodes;
    level.abes.interactableCacheTime = gettime();
    return level.abes.interactableCandidates;
}

isPotentialInteractable( entity )
{
    return isDesiredInteractable( entity, "weapon" )
        || isDesiredInteractable( entity, "mystery" )
        || isDesiredInteractable( entity, "ammo" )
        || isDesiredInteractable( entity, "exo_upgrade" )
        || isDesiredInteractable( entity, "armor" )
        || isDesiredInteractable( entity, "support" )
        || isDesiredInteractable( entity, "equipment" );
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

        case "ammo":
            return entityMatchesToken( entity, "ammo" ) || entityMatchesToken( entity, "resupply" ) || entityMatchesToken( entity, "cache" );

        case "exo_upgrade":
            return entityMatchesToken( entity, "exo_upgrade" ) || entityMatchesToken( entity, "exo_station" ) || entityMatchesToken( entity, "ability_upgrade" ) || entityMatchesToken( entity, "boost_upgrade" );

        case "armor":
            return entityMatchesToken( entity, "armor" ) || entityMatchesToken( entity, "armour" ) || entityMatchesToken( entity, "health" ) || entityMatchesToken( entity, "med" );

        case "support":
            return entityMatchesToken( entity, "support" ) || entityMatchesToken( entity, "scorestreak" ) || entityMatchesToken( entity, "killstreak" );

        case "equipment":
            return entityMatchesToken( entity, "equipment" ) || entityMatchesToken( entity, "grenade" ) || entityMatchesToken( entity, "tactical" ) || entityMatchesToken( entity, "lethal" );
    }

    return false;
}

periodicEnemyRefresh()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        scanForEnemyEntities();
        wait 0.4;
    }
}

scanForEnemyEntities()
{
    enemies = [];
    appendEntArray( enemies, getentarray( "actor", "classname" ) );
    appendEntArray( enemies, getentarray( "agent", "classname" ) );
    appendEntArray( enemies, getentarray( "ai", "classname" ) );

    liveEnemies = [];

    for ( i = 0; i < enemies.size; i++ )
    {
        enemy = enemies[i];
        if ( isEnemyEntity( enemy ) )
        {
            liveEnemies[liveEnemies.size] = enemy;
        }
    }

    level.abes.trackedEnemies = liveEnemies;
}

getTrackedEnemies()
{
    liveEnemies = [];

    for ( i = 0; i < level.abes.trackedEnemies.size; i++ )
    {
        enemy = level.abes.trackedEnemies[i];
        if ( isEnemyEntity( enemy ) )
        {
            liveEnemies[liveEnemies.size] = enemy;
        }
    }

    level.abes.trackedEnemies = liveEnemies;
    return liveEnemies;
}

getClosestEnemy()
{
    enemies = getTrackedEnemies();
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < enemies.size; i++ )
    {
        enemy = enemies[i];
        if ( !isEnemyThreatForBot( enemy, self ) )
        {
            continue;
        }

        dist = distance( self.origin, enemy.origin );
        if ( dist < bestDist )
        {
            best = enemy;
            bestDist = dist;
        }
    }

    return best;
}

countNearbyEnemies( origin, radius )
{
    enemies = getTrackedEnemies();
    count = 0;

    for ( i = 0; i < enemies.size; i++ )
    {
        enemy = enemies[i];
        if ( !isEnemyThreatForBot( enemy, self ) )
        {
            continue;
        }

        if ( distance( origin, enemy.origin ) <= radius )
        {
            count++;
        }
    }

    return count;
}

isEnemyEntity( entity )
{
    if ( !isdefined( entity ) || !isalive( entity ) )
    {
        return false;
    }

    if ( isplayer( entity ) )
    {
        return false;
    }

    if ( isdefined( entity.classname ) && (entity.classname == "actor" || entity.classname == "agent" || entity.classname == "ai") )
    {
        return true;
    }

    return entityMatchesToken( entity, "enemy" ) || entityMatchesToken( entity, "soldier" ) || entityMatchesToken( entity, "kva" ) || entityMatchesToken( entity, "hostile" );
}

isEnemyThreatForBot( entity, bot )
{
    if ( !isdefined( entity ) || !isdefined( bot ) || !isalive( entity ) )
    {
        return false;
    }

    if ( entity == bot )
    {
        return false;
    }

    return isEnemyEntity( entity );
}

hasEnoughScore( player, amount )
{
    if ( !isdefined( player ) || !isdefined( player.score ) )
    {
        return false;
    }

    return player.score >= amount;
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

isBotEntity( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( isdefined( player.pers ) && isdefined( player.pers["isBot"] ) && player.pers["isBot"] )
    {
        return true;
    }

    if ( isdefined( player.abesIsBot ) && player.abesIsBot )
    {
        return true;
    }

    return false;
}

isTeammateEntity( player, other )
{
    if ( !isdefined( player ) || !isdefined( other ) )
    {
        return false;
    }

    if ( isdefined( player.team ) && isdefined( other.team ) )
    {
        return player.team == other.team;
    }

    if ( isplayer( player ) && isplayer( other ) && isdefined( level.abes ) )
    {
        return true;
    }

    return false;
}

clearActiveReviveClaim()
{
    if ( !isdefined( self.abesReviveTarget ) )
    {
        return;
    }

    releaseReviveClaim( self.abesReviveTarget );
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

dvarContainsToken( dvarName, token )
{
    value = getdvar( dvarName );
    return stringContainsToken( value, token );
}

containsAny2( value, a, b )
{
    if ( stringContainsToken( value, a ) )
    {
        return true;
    }

    return stringContainsToken( value, b );
}

containsAny3( value, a, b, c )
{
    return stringContainsToken( value, a ) || stringContainsToken( value, b ) || stringContainsToken( value, c );
}

containsAny4( value, a, b, c, d )
{
    return stringContainsToken( value, a ) || stringContainsToken( value, b ) || stringContainsToken( value, c ) || stringContainsToken( value, d );
}

containsAny5( value, a, b, c, d, e )
{
    return stringContainsToken( value, a ) || stringContainsToken( value, b ) || stringContainsToken( value, c ) || stringContainsToken( value, d ) || stringContainsToken( value, e );
}

stringContainsToken( value, token )
{
    if ( !isdefined( value ) || !isdefined( token ) )
    {
        return false;
    }

    return issubstr( safeLower( value ), safeLower( token ) );
}

safeLower( value )
{
    if ( !isdefined( value ) )
    {
        return "";
    }

    return toLower( value + "" );
}

abesClamp( value, minimum, maximum )
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

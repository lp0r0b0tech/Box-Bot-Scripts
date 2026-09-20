// Auto Bots + BO2 Feel Zombies Mod for Advanced Warfare Exo Zombies (S1x)
//
// Self-contained S1x entry script. Keep the constants grouped at the top so the
// package can be tuned quickly without hunting through the logic below.

#define ABZM_DEFAULT_AUTOBOTS_ENABLED         0
#define ABZM_DEFAULT_BOT_COUNT                3
#define ABZM_DEFAULT_BOT_SKILL                1.0
#define ABZM_DEFAULT_BOTS_CAN_REVIVE          1
#define ABZM_DEFAULT_BOTS_AUTO_BUY_PERKS      1
#define ABZM_DEFAULT_BOTS_AUTO_BUY_UPGRADES   1
#define ABZM_DEFAULT_BOTS_USE_EQUIPMENT       1
#define ABZM_DEFAULT_BO2_TUNING_ENABLED       1
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
#define ABZM_BO2_RUN_ROUND                    3

#define ABZM_BO2_INSTAKILL_DURATION           30
#define ABZM_BO2_DOUBLEPOINTS_DURATION        30
#define ABZM_BO2_NUKE_DELAY                   3
#define ABZM_BO2_DROP_WEIGHT_INSTAKILL        10
#define ABZM_BO2_DROP_WEIGHT_DOUBLEPOINTS     10
#define ABZM_BO2_DROP_WEIGHT_NUKE             8
#define ABZM_BO2_DROP_WEIGHT_MAXAMMO          6
#define ABZM_BO2_DROP_WEIGHT_CARPENTER        6
#define ABZM_BO2_DROP_WEIGHT_2XP              0

init()
{
    if ( GetMode() != "zombies" )
    {
        return;
    }

    level.abzm = buildModState();
    initDvars();
    level thread abzmBoot();
}

buildModState()
{
    state = spawnstruct();
    state.enabled = false;
    state.round = 1;
    state.lastSpecialRound = 0;
    state.forceSpecialRound = false;
    state.trackedZombies = [];
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
}

refreshRuntimeConfig()
{
    level.abzm.autoBotsEnabled = getdvarint( "scr_zm_autobots_enable" ) > 0;
    level.abzm.botCount = clamp( getdvarint( "scr_zm_autobots_count" ), 0, 4 );
    level.abzm.botSkill = clamp( getdvarfloat( "scr_zm_autobots_skill" ), 0.25, 3.0 );
    level.abzm.botsCanRevive = getdvarint( "scr_zm_autobots_revive" ) > 0;
    level.abzm.botsAutoBuyPerks = getdvarint( "scr_zm_autobots_auto_buy_perks" ) > 0;
    level.abzm.botsAutoBuyUpgrades = getdvarint( "scr_zm_autobots_auto_buy_upgrades" ) > 0;
    level.abzm.botsUseEquipment = getdvarint( "scr_zm_autobots_use_equipment" ) > 0;

    level.abzm.bo2Enabled = getdvarint( "scr_zm_bo2_enable" ) > 0;
    level.abzm.sprintRound = max( 1, getdvarint( "scr_zm_bo2_sprint_round" ) );
    level.abzm.crawlerChance = clamp( getdvarfloat( "scr_zm_bo2_crawler_chance" ), 0.0, 1.0 );
    level.abzm.specialRoundInterval = max( 0, getdvarint( "scr_zm_bo2_special_round_interval" ) );
    level.abzm.specialRoundOffset = max( 1, getdvarint( "scr_zm_bo2_special_round_offset" ) );
    level.abzm.bo2PowerupsEnabled = getdvarint( "scr_zm_bo2_powerups_enable" ) > 0;

    level.abzm.enabled = level.abzm.autoBotsEnabled || level.abzm.bo2Enabled;
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
        self.abzmIsBot = isBotEntity( self );

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

        if ( level.abzm.bo2Enabled )
        {
            self.abzmBleedoutTime = ABZM_BO2_BLEEDOUT_TIME;
        }

        self waittill_any( "revived", "spawned_player" );
        self.abzmDowned = false;
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

        if ( level.abzm.autoBotsEnabled )
        {
            currentBots = getActiveBotCount();
            while ( currentBots < level.abzm.botCount )
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
    bot thread onPlayerConnected();
    return true;
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

    self.abzmState = "reviving";
    self setlookatpos( downed.origin );
    self moveto( downed.origin, 0.35 );
    wait ABZM_BO2_REVIVE_TIME;

    if ( isdefined( downed ) && isplayer( downed ) && downed.abzmDowned && distance( self.origin, downed.origin ) <= ABZM_BO2_REVIVE_RANGE )
    {
        downed notify( "revived" );
        awardPlayerPoints( self, ABZM_BO2_REVIVE_POINTS );
    }

    return true;
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
    if ( !hasEnoughPoints( self, 2000 ) )
    {
        return;
    }

    perkNode = getClosestInteractable( "perk" );
    if ( isdefined( perkNode ) )
    {
        moveToAndUse( perkNode );
    }
}

attemptUtilityPurchase()
{
    if ( hasEnoughPoints( self, 5000 ) )
    {
        papNode = getClosestInteractable( "packapunch" );
        if ( isdefined( papNode ) )
        {
            moveToAndUse( papNode );
            return;
        }
    }

    if ( hasEnoughPoints( self, 1250 ) )
    {
        doorNode = getClosestInteractable( "door" );
        if ( isdefined( doorNode ) )
        {
            moveToAndUse( doorNode );
            return;
        }
    }

    if ( hasEnoughPoints( self, 2000 ) )
    {
        exoNode = getClosestInteractable( "exo" );
        if ( isdefined( exoNode ) )
        {
            moveToAndUse( exoNode );
        }
    }
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

        rememberZombie( zombie );
        zombie thread tuneZombieForCurrentRound();
    }
}

rememberZombie( zombie )
{
    if ( !isdefined( zombie ) )
    {
        return;
    }

    level.abzm.trackedZombies[level.abzm.trackedZombies.size] = zombie;
}

tuneZombieForCurrentRound()
{
    self endon( "death" );

    roundNumber = max( 1, level.abzm.round );
    health = calculateBo2ZombieHealth( roundNumber );
    speed = calculateBo2ZombieSpeed( roundNumber );

    if ( shouldMakeCrawler( roundNumber ) )
    {
        speed = ABZM_BO2_CRAWLER_SPEED;
        self.abzmCrawler = true;
    }

    self.maxhealth = health;
    self.health = health;
    self walkspeed( speed );

    if ( roundNumber >= level.abzm.sprintRound )
    {
        self.abzmCanSprint = true;
        self runspeed( speed );
    }

    if ( level.abzm.forceSpecialRound )
    {
        self.abzmSpecialEnemy = true;
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

tunePowerupDrop( powerup )
{
    type = chooseWeightedPowerup();
    powerup.abzmDropType = type;

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

chooseWeightedPowerup()
{
    weights = [];
    weights[0] = spawnWeightedEntry( "instakill", ABZM_BO2_DROP_WEIGHT_INSTAKILL );
    weights[1] = spawnWeightedEntry( "doublepoints", ABZM_BO2_DROP_WEIGHT_DOUBLEPOINTS );
    weights[2] = spawnWeightedEntry( "nuke", ABZM_BO2_DROP_WEIGHT_NUKE );
    weights[3] = spawnWeightedEntry( "maxammo", ABZM_BO2_DROP_WEIGHT_MAXAMMO );
    weights[4] = spawnWeightedEntry( "carpenter", ABZM_BO2_DROP_WEIGHT_CARPENTER );
    weights[5] = spawnWeightedEntry( "2xp", ABZM_BO2_DROP_WEIGHT_2XP );

    total = 0;
    for ( i = 0; i < weights.size; i++ )
    {
        total += weights[i].weight;
    }

    if ( total <= 0 )
    {
        return "maxammo";
    }

    roll = randomint( total );
    running = 0;

    for ( i = 0; i < weights.size; i++ )
    {
        running += weights[i].weight;
        if ( roll < running )
        {
            return weights[i].name;
        }
    }

    return "maxammo";
}

spawnWeightedEntry( name, weight )
{
    entry = spawnstruct();
    entry.name = name;
    entry.weight = weight;
    return entry;
}

calculateBo2ZombieHealth( roundNumber )
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
        health = int( health * ABZM_BO2_HEALTH_CURVE_MULTIPLIER );
        if ( health >= ABZM_BO2_HEALTH_CAP )
        {
            return ABZM_BO2_HEALTH_CAP;
        }
    }

    return health;
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
    nodes = getentarray( kind, "targetname" );
    best = undefined;
    bestDist = 999999;

    for ( i = 0; i < nodes.size; i++ )
    {
        node = nodes[i];
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
        return;
    }

    self setlookatpos( node.origin );
    self moveto( node.origin, 0.25 );
    node notify( "trigger", self );
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

hasEnoughPoints( player, amount )
{
    if ( !isdefined( player.score ) )
    {
        return false;
    }

    return player.score >= amount;
}

awardPlayerPoints( player, amount )
{
    if ( !isdefined( player.score ) )
    {
        player.score = 0;
    }

    player.score += amount;
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

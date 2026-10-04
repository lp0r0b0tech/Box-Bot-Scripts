/*
    Exo Zombies Active Easter Egg Bot Assistant for S1x
    Map coverage: Outbreak, Infection, Carrier, Descent

    Place this file at:
        s1/scripts/zm/easter_egg_bot_ignore.gsc

    Purpose:
        - Multi-tiered bot identification without aggressive level.players overwriting.
        - Synchronize bots onto multi-player progression triggers (decon, airlocks, teleports, lifts).
        - Character and keycard tracking & station automation for Outbreak (mp_zombie_lab).
        - Escort protection, gas hazard immunity, and valve synchronization for Infection (mp_zombie_ark).
        - Simultaneous bomb defusal assistance and teleporter grouping for Carrier (mp_zombie_brg).
        - Elevator and Oz arena staging assistance for Descent (mp_zombie_h2o).
        - Weapon suppression and damage protection during fragile puzzle phases.
        - Real-time debugging harness and customizable dvar controls.

    Toggles:
        set scr_zm_ee_ignore_bots 1          // Master enable (1=on, 0=off)
        set scr_zm_ee_ignore_bots_debug 0    // Debug level: 0=off, 1=console, 2=verbose on-screen
        set scr_zm_ee_teleport_bots 1        // Auto-teleport bots to multi-player triggers
        set scr_zm_ee_auto_cards 1           // Auto-complete bot character cards/stations
        set scr_zm_ee_protect_bots 1         // Bot puzzle weapon suppression & hazard immunity
        set scr_zm_ee_protect_step 0         // Force trigger puzzle protection mode
*/

#define EEBI_DEFAULT_ENABLED                    1
#define EEBI_DEFAULT_DEBUG                      0
#define EEBI_DEFAULT_TELEPORT                   1
#define EEBI_DEFAULT_AUTO_CARDS                 1
#define EEBI_DEFAULT_PROTECT_BOTS               1
#define EEBI_DEFAULT_PROTECT_STEP               0

#define EEBI_REFRESH_INTERVAL                   0.25
#define EEBI_TRIGGER_SCAN_INTERVAL              0.50
#define EEBI_MAP_MONITOR_INTERVAL               0.50
#define EEBI_FROZEN_TIMEOUT_MS                  25000

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
    eebiEnsureState();
    eebiResetPublishedState();

    // Start background threads
    level thread eebiRefreshLoop();
    level thread eebiTriggerMonitorLoop();
    level thread eebiPuzzleProtectionLoop();
    level thread eebiMapSpecificMonitorLoop();
    level thread eebiOnScreenDebugLoop();

    if ( getdvarint( "scr_zm_ee_ignore_bots" ) > 0 )
    {
        eebiRefreshState();
    }

    level.eebiInitStarted = true;
    level.eebiInitPending = false;
    eebiDebugPrint( "Initialized Active Easter Egg Bot Assistant.", true );
}

eebiInitDvars()
{
    setdvarifuninitialized( "scr_zm_ee_ignore_bots", EEBI_DEFAULT_ENABLED );
    setdvarifuninitialized( "scr_zm_ee_ignore_bots_debug", EEBI_DEFAULT_DEBUG );
    setdvarifuninitialized( "scr_zm_ee_teleport_bots", EEBI_DEFAULT_TELEPORT );
    setdvarifuninitialized( "scr_zm_ee_auto_cards", EEBI_DEFAULT_AUTO_CARDS );
    setdvarifuninitialized( "scr_zm_ee_protect_bots", EEBI_DEFAULT_PROTECT_BOTS );
    setdvarifuninitialized( "scr_zm_ee_protect_step", EEBI_DEFAULT_PROTECT_STEP );
}

// ============================================================
// Phase 1: Robust Bot Identification and Non-Invasive State
// ============================================================

eebiRefreshLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( getdvarint( "scr_zm_ee_ignore_bots" ) > 0 )
        {
            eebiRefreshState();
        }
        else
        {
            eebiDisableState();
        }

        wait EEBI_REFRESH_INTERVAL;
    }
}

eebiRefreshState()
{
    eebiEnsureState();

    allPlayers = level.players;
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
    level.eebi.taggedPlayers = eebiCopyEntityArray( allPlayers );
    level.eebi.originalPlayers = eebiCopyEntityArray( allPlayers );
    level.eebi.originalPlayerCount = allPlayers.size;

    level.eebi.humanCount = humanPlayers.size;
    level.eebi.botCount = botPlayers.size;
    level.eebi.eligibleCount = eligiblePlayers.size;
    level.eebi.active = true;

    // Non-invasive state publication: we do NOT overwrite level.players
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
    level.eebi.zones = [];
    level.eebi.cardsGranted = [];
    level.eebi.bombsAssisted = [];
    level.eebi.lastZoneTeleportTime = 0;
}

eebiResetPublishedState()
{
    eebiEnsureState();

    level.eebi.allPlayers = [];
    level.eebi.humanPlayers = [];
    level.eebi.botPlayers = [];
    level.eebi.eligiblePlayers = [];
    level.eebi.taggedPlayers = [];
    level.eebi.originalPlayers = [];
    level.eebi.originalPlayerCount = 0;

    level.eebi.humanCount = 0;
    level.eebi.botCount = 0;
    level.eebi.eligibleCount = 0;
    level.eebi.active = false;

    eebiWriteAliases();
}

eebiDisableState()
{
    eebiEnsureState();

    if ( isdefined( level.eebi.active ) && level.eebi.active && isdefined( level.eebi.taggedPlayers ) )
    {
        for ( i = 0; i < level.eebi.taggedPlayers.size; i++ )
        {
            if ( isdefined( level.eebi.taggedPlayers[i] ) )
            {
                eebiClearPlayerTags( level.eebi.taggedPlayers[i] );
            }
        }
    }

    eebiReleaseAllFrozenBots();
    eebiResetPublishedState();
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
    level.eebiOriginalPlayers = level.eebi.originalPlayers;
    level.eebiOriginalPlayerCount = level.eebi.originalPlayerCount;
}

eebiGetHumanPlayers()
{
    if ( isdefined( level.eebi ) && isdefined( level.eebi.humanPlayers ) )
    {
        return level.eebi.humanPlayers;
    }
    return [];
}

eebiGetBotPlayers()
{
    if ( isdefined( level.eebi ) && isdefined( level.eebi.botPlayers ) )
    {
        return level.eebi.botPlayers;
    }
    return [];
}

eebiGetEligiblePlayers()
{
    if ( isdefined( level.eebi ) && isdefined( level.eebi.eligiblePlayers ) )
    {
        return level.eebi.eligiblePlayers;
    }
    return [];
}

eebiGetAliveHumans()
{
    humans = eebiGetHumanPlayers();
    aliveHumans = [];

    for ( i = 0; i < humans.size; i++ )
    {
        player = humans[i];
        if ( isdefined( player ) && isalive( player ) && eebiIsPlayerCountable( player ) )
        {
            aliveHumans[aliveHumans.size] = player;
        }
    }

    return aliveHumans;
}

eebiGetAliveBots()
{
    bots = eebiGetBotPlayers();
    aliveBots = [];

    for ( i = 0; i < bots.size; i++ )
    {
        player = bots[i];
        if ( isdefined( player ) && isalive( player ) )
        {
            aliveBots[aliveBots.size] = player;
        }
    }

    return aliveBots;
}

eebiIsBotEntity( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    // 1. Explicit script / entity flags
    if ( isdefined( player.isBot ) )
    {
        return eebiValueIsTrue( player.isBot );
    }

    if ( isdefined( player.isbot ) )
    {
        return eebiValueIsTrue( player.isbot );
    }

    if ( isdefined( player.bot ) )
    {
        return eebiValueIsTrue( player.bot );
    }

    // 2. Persistence dictionary flags
    if ( isdefined( player.pers ) )
    {
        if ( isdefined( player.pers["isBot"] ) )
        {
            return eebiValueIsTrue( player.pers["isBot"] );
        }

        if ( isdefined( player.pers["is_bot"] ) )
        {
            return eebiValueIsTrue( player.pers["is_bot"] );
        }

        if ( isdefined( player.pers["bot"] ) )
        {
            return eebiValueIsTrue( player.pers["bot"] );
        }

        if ( isdefined( player.pers["bot_difficulty"] ) )
        {
            return true;
        }
    }

    // 3. Native testclient check
    if ( player istestclient() )
    {
        return true;
    }

    // 4. GUID heuristic
    guid = player getguid();
    if ( isdefined( guid ) )
    {
        guidStr = toLower( guid + "" );
        if ( guidStr == "" || guidStr == "0" || isSubStr( guidStr, "bot" ) )
        {
            return true;
        }
    }
    else
    {
        return true;
    }

    // 5. Name heuristics
    if ( isdefined( player.name ) )
    {
        nameLower = toLower( player.name + "" );
        if ( isSubStr( nameLower, "bot " ) ||
             isSubStr( nameLower, "[bot]" ) ||
             isSubStr( nameLower, "(bot)" ) ||
             nameLower == "bot" )
        {
            return true;
        }
    }

    // 6. Cached script marker
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
        player.pers["eebi_is_bot"] = undefined;
        player.pers["eebi_counts_for_easter_egg"] = undefined;
        player.pers["eebi_ignore_easter_egg"] = undefined;
    }

    player.eebiCountsForEasterEgg = undefined;
    player.eebiIgnoreEasterEgg = undefined;
    player.eebiIsBot = undefined;
    player.eebiIsRealPlayer = undefined;
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

eebiCopyEntityArray( entities )
{
    copy = [];

    if ( !isdefined( entities ) )
    {
        return copy;
    }

    for ( i = 0; i < entities.size; i++ )
    {
        copy[copy.size] = entities[i];
    }

    return copy;
}

// ============================================================
// Phase 2: Multi-Player Trigger Detection and Bot Teleportation
// ============================================================

eebiInitTriggerZones()
{
    level.eebi.zones = [];
    mapname = toLower( getdvar( "mapname" ) + "" );

    if ( mapname == "mp_zombie_lab" || mapname == "zombie_outbreak" )
    {
        // Outbreak: Decontamination room, escape chute, Exo room pad
        eebiAddZone( "outbreak_decon", "Decontamination Shower", ( -1080, 390, 80 ), 220, 140 );
        eebiAddZone( "outbreak_escape", "Escape Hatch / Chute", ( -350, -420, 110 ), 240, 160 );
        eebiAddZone( "outbreak_exo_pad", "Exo Room Pad", ( -750, 150, 80 ), 200, 140 );
    }
    else if ( mapname == "mp_zombie_ark" || mapname == "zombie_infection" )
    {
        // Infection: Sewer airlock, decontamination chamber, valve pad, civilian gate
        eebiAddZone( "infection_sewer", "Sewer Airlock Chamber", ( 850, 1200, -180 ), 240, 160 );
        eebiAddZone( "infection_decon", "Decontamination Chamber", ( 1400, -600, 40 ), 220, 150 );
        eebiAddZone( "infection_valve", "Sewer Valve Pad", ( 600, 1100, -150 ), 180, 140 );
        eebiAddZone( "infection_civilian", "Civilian Rescue Gate", ( -400, 1800, 120 ), 280, 200 );
    }
    else if ( mapname == "mp_zombie_brg" || mapname == "zombie_carrier" )
    {
        // Carrier: Jump pads, teleporters, transit pads
        eebiAddZone( "carrier_flight_pad", "Flight Deck Jump Pad", ( 1200, -850, 650 ), 220, 150 );
        eebiAddZone( "carrier_cargo_pad", "Cargo Teleporter Pad", ( -750, 600, 150 ), 220, 150 );
        eebiAddZone( "carrier_hangar_pad", "Hangar Transit Pad", ( 300, 450, 250 ), 200, 150 );
    }
    else if ( mapname == "mp_zombie_h2o" || mapname == "zombie_descent" )
    {
        // Descent: Central elevator, Oz arena airlock, submersible bay
        eebiAddZone( "descent_elevator", "Central Descent Elevator", ( 0, 0, -450 ), 240, 200 );
        eebiAddZone( "descent_oz_airlock", "Oz Arena Airlock", ( 650, -1100, -800 ), 250, 200 );
        eebiAddZone( "descent_sub_bay", "Submersible Bay Airlock", ( -850, 350, -600 ), 220, 180 );
    }

    // Dynamic entity trigger scanning
    eebiScanDynamicTriggers();
}

eebiAddZone( id, name, origin, radius, height, triggerEnt )
{
    zone = spawnstruct();
    zone.id = id;
    zone.name = name;
    zone.origin = origin;
    zone.radius = radius;
    zone.height = height;
    zone.active = false;
    zone.lastTeleportTime = 0;
    zone.triggerEnt = triggerEnt;

    level.eebi.zones[level.eebi.zones.size] = zone;
}

eebiScanDynamicTriggers()
{
    triggerTypes = [];
    triggerTypes[0] = "trigger_multiple";
    triggerTypes[1] = "trigger_radius";
    triggerTypes[2] = "trigger_use";

    for ( t = 0; t < triggerTypes.size; t++ )
    {
        triggers = getentarray( triggerTypes[t], "classname" );
        if ( !isdefined( triggers ) )
        {
            continue;
        }

        for ( i = 0; i < triggers.size; i++ )
        {
            trig = triggers[i];
            if ( !isdefined( trig ) || !isdefined( trig.origin ) )
            {
                continue;
            }

            keyStr = "";
            if ( isdefined( trig.targetname ) )
            {
                keyStr = keyStr + toLower( trig.targetname + "" ) + " ";
            }
            if ( isdefined( trig.script_noteworthy ) )
            {
                keyStr = keyStr + toLower( trig.script_noteworthy + "" ) + " ";
            }

            if ( isSubStr( keyStr, "decon" ) ||
                 isSubStr( keyStr, "airlock" ) ||
                 isSubStr( keyStr, "teleport" ) ||
                 isSubStr( keyStr, "elevator" ) ||
                 isSubStr( keyStr, "sewer" ) ||
                 isSubStr( keyStr, "staging" ) ||
                 isSubStr( keyStr, "ee_pad" ) ||
                 isSubStr( keyStr, "valve" ) )
            {
                rad = 180;
                if ( isdefined( trig.radius ) )
                {
                    rad = trig.radius;
                }
                eebiAddZone( "dyn_" + i, "Dynamic Trigger (" + keyStr + ")", trig.origin, rad, 160, trig );
            }
        }
    }
}

eebiTriggerMonitorLoop()
{
    level endon( "game_ended" );

    wait 1.0;
    eebiInitTriggerZones();

    for ( ;; )
    {
        wait EEBI_TRIGGER_SCAN_INTERVAL;

        if ( getdvarint( "scr_zm_ee_ignore_bots" ) <= 0 || getdvarint( "scr_zm_ee_teleport_bots" ) <= 0 )
        {
            eebiReleaseAllFrozenBots();
            continue;
        }

        aliveHumans = eebiGetAliveHumans();
        aliveBots = eebiGetAliveBots();

        if ( aliveHumans.size <= 0 || aliveBots.size <= 0 )
        {
            eebiReleaseAllFrozenBots();
            continue;
        }

        for ( z = 0; z < level.eebi.zones.size; z++ )
        {
            zone = level.eebi.zones[z];
            if ( !isdefined( zone ) )
            {
                continue;
            }

            humansInZone = 0;
            for ( h = 0; h < aliveHumans.size; h++ )
            {
                if ( eebiIsPlayerInZone( aliveHumans[h], zone ) )
                {
                    humansInZone++;
                }
            }

            // If ALL alive human players occupy this trigger zone
            if ( humansInZone > 0 && humansInZone == aliveHumans.size )
            {
                zone.active = true;

                for ( b = 0; b < aliveBots.size; b++ )
                {
                    bot = aliveBots[b];
                    if ( !isdefined( bot ) || !isalive( bot ) )
                    {
                        continue;
                    }

                    if ( !eebiIsPlayerInZone( bot, zone ) )
                    {
                        // Stagger bot teleport positions inside the zone
                        offset = ( randomfloatrange( -35, 35 ), randomfloatrange( -35, 35 ), 10 );
                        teleportPos = zone.origin + offset;

                        bot setorigin( teleportPos );
                        bot freezecontrols( true );
                        bot.eebiFrozenByZone = zone.name;
                        bot.eebiFrozenTime = getTime();

                        eebiDebugPrint( "Synchronized bot " + bot.name + " into " + zone.name, true );
                    }
                    else
                    {
                        // Bot is inside: keep controls frozen until step triggers or humans leave
                        bot freezecontrols( true );
                        bot.eebiFrozenByZone = zone.name;
                    }
                }
            }
            else
            {
                if ( zone.active )
                {
                    zone.active = false;
                    // Release any bots frozen specifically by this zone
                    for ( b = 0; b < aliveBots.size; b++ )
                    {
                        bot = aliveBots[b];
                        if ( isdefined( bot ) && isdefined( bot.eebiFrozenByZone ) && bot.eebiFrozenByZone == zone.name )
                        {
                            bot freezecontrols( false );
                            bot.eebiFrozenByZone = undefined;
                            bot.eebiFrozenTime = undefined;
                        }
                    }
                }
            }
        }

        // Safety timeout check: never keep a bot permanently frozen if a trigger glitches
        currentTime = getTime();
        for ( b = 0; b < aliveBots.size; b++ )
        {
            bot = aliveBots[b];
            if ( isdefined( bot ) && isdefined( bot.eebiFrozenTime ) )
            {
                if ( ( currentTime - bot.eebiFrozenTime ) > EEBI_FROZEN_TIMEOUT_MS )
                {
                    bot freezecontrols( false );
                    bot.eebiFrozenByZone = undefined;
                    bot.eebiFrozenTime = undefined;
                    eebiDebugPrint( "Released bot " + bot.name + " after safety timeout.", false );
                }
            }
        }
    }
}

eebiIsPlayerInZone( player, zone )
{
    if ( !isdefined( player ) || !isdefined( zone ) )
    {
        return false;
    }

    if ( isdefined( zone.triggerEnt ) )
    {
        if ( player istouching( zone.triggerEnt ) )
        {
            return true;
        }
    }

    dist2D = distance2d( player.origin, zone.origin );
    if ( dist2D <= zone.radius )
    {
        zDiff = abs( player.origin[2] - zone.origin[2] );
        if ( zDiff <= zone.height )
        {
            return true;
        }
    }

    return false;
}

eebiReleaseAllFrozenBots()
{
    bots = eebiGetBotPlayers();
    for ( i = 0; i < bots.size; i++ )
    {
        bot = bots[i];
        if ( isdefined( bot ) )
        {
            bot freezecontrols( false );
            bot.eebiFrozenByZone = undefined;
            bot.eebiFrozenTime = undefined;
        }
    }
}

// ============================================================
// Phase 3: Map-Specific Character and Step Automation
// ============================================================

eebiMapSpecificMonitorLoop()
{
    level endon( "game_ended" );

    wait 2.0;
    mapname = toLower( getdvar( "mapname" ) + "" );

    for ( ;; )
    {
        wait EEBI_MAP_MONITOR_INTERVAL;

        if ( getdvarint( "scr_zm_ee_ignore_bots" ) <= 0 )
        {
            continue;
        }

        if ( mapname == "mp_zombie_lab" || mapname == "zombie_outbreak" )
        {
            eebiMonitorOutbreakKeycards();
        }
        else if ( mapname == "mp_zombie_ark" || mapname == "zombie_infection" )
        {
            eebiMonitorInfectionEscortAndGas();
        }
        else if ( mapname == "mp_zombie_brg" || mapname == "zombie_carrier" )
        {
            eebiMonitorCarrierBombs();
        }
        else if ( mapname == "mp_zombie_h2o" || mapname == "zombie_descent" )
        {
            eebiMonitorDescentStaging();
        }
    }
}

// --- Outbreak (mp_zombie_lab) ---

eebiGetPlayerCharacter( player )
{
    if ( !isdefined( player ) )
    {
        return "unknown";
    }

    if ( isdefined( player.character ) )
    {
        return toLower( player.character + "" );
    }

    if ( isdefined( player.characterindex ) )
    {
        idx = int( player.characterindex );
        if ( idx == 0 ) return "oz";
        if ( idx == 1 ) return "kahn";
        if ( idx == 2 ) return "lilith";
        if ( idx == 3 ) return "decker";
    }

    if ( isdefined( player.model ) )
    {
        m = toLower( player.model + "" );
        if ( isSubStr( m, "oz" ) ) return "oz";
        if ( isSubStr( m, "kahn" ) ) return "kahn";
        if ( isSubStr( m, "lilith" ) ) return "lilith";
        if ( isSubStr( m, "decker" ) ) return "decker";
    }

    if ( isdefined( player.voice ) )
    {
        v = toLower( player.voice + "" );
        if ( isSubStr( v, "oz" ) ) return "oz";
        if ( isSubStr( v, "kahn" ) ) return "kahn";
        if ( isSubStr( v, "lilith" ) ) return "lilith";
        if ( isSubStr( v, "decker" ) ) return "decker";
    }

    return "unknown";
}

eebiMonitorOutbreakKeycards()
{
    if ( getdvarint( "scr_zm_ee_auto_cards" ) <= 0 )
    {
        return;
    }

    bots = eebiGetAliveBots();
    humans = eebiGetAliveHumans();

    if ( bots.size <= 0 || humans.size <= 0 )
    {
        return;
    }

    // Coordinate positions for character keycard stations in Outbreak
    stationLocs = [];
    stationLocs["oz"] = ( -1050, 420, 85 );      // Exo room locker / decon station
    stationLocs["kahn"] = ( 450, -650, 120 );    // Security desk in admin office
    stationLocs["lilith"] = ( -800, -850, 75 );  // Holding cell medical scanner
    stationLocs["decker"] = ( -120, 850, 60 );   // Disposal chute terminal

    for ( b = 0; b < bots.size; b++ )
    {
        bot = bots[b];
        if ( !isdefined( bot ) )
        {
            continue;
        }

        charName = eebiGetPlayerCharacter( bot );
        if ( charName == "unknown" )
        {
            // Assign fallback based on bot slot index
            fallbackChars = [];
            fallbackChars[0] = "oz";
            fallbackChars[1] = "kahn";
            fallbackChars[2] = "lilith";
            fallbackChars[3] = "decker";
            charName = fallbackChars[b % 4];
        }

        if ( isdefined( bot.eebiCardGranted ) && bot.eebiCardGranted )
        {
            continue;
        }

        stationPos = stationLocs[charName];
        if ( !isdefined( stationPos ) )
        {
            continue;
        }

        // Check if any human player interacts near this bot character's station
        humanNearby = false;
        for ( h = 0; h < humans.size; h++ )
        {
            human = humans[h];
            if ( isdefined( human ) && distance( human.origin, stationPos ) <= 120 )
            {
                humanNearby = true;
                break;
            }
        }

        if ( humanNearby )
        {
            bot.eebiCardGranted = true;
            bot.keycard = true;
            bot.security_level = 4;
            bot.card_collected = true;

            if ( isdefined( bot.pers ) )
            {
                bot.pers["keycard"] = true;
                bot.pers["security_level"] = 4;
            }

            level notify( "card_collected", bot );
            level notify( "keycard_acquired", charName );
            level notify( "keycard_obtained" );

            eebiDebugPrint( "Outbreak: Keycard registered for bot " + bot.name + " (" + charName + ")", true );
        }
    }
}

// --- Infection (mp_zombie_ark) ---

eebiMonitorInfectionEscortAndGas()
{
    bots = eebiGetAliveBots();
    if ( bots.size <= 0 )
    {
        return;
    }

    // 1. Gas hazard immunity for bots
    if ( getdvarint( "scr_zm_ee_protect_bots" ) > 0 )
    {
        for ( b = 0; b < bots.size; b++ )
        {
            bot = bots[b];
            if ( !isdefined( bot ) || !isalive( bot ) )
            {
                continue;
            }

            // Toxic sewer gas region in Infection (Z < -100) or tagged with in_gas
            if ( bot.origin[2] < -100 || ( isdefined( bot.in_gas ) && bot.in_gas ) )
            {
                if ( bot.health < bot.maxhealth )
                {
                    bot.health = bot.maxhealth;
                }
                bot.in_gas = false;
            }
        }
    }

    // 2. Survivor escort protection
    actors = getentarray( "actor", "classname" );
    if ( isdefined( actors ) )
    {
        for ( a = 0; a < actors.size; a++ )
        {
            actor = actors[a];
            if ( !isdefined( actor ) )
            {
                continue;
            }

            actorName = "";
            if ( isdefined( actor.targetname ) )
            {
                actorName = actorName + toLower( actor.targetname + "" );
            }
            if ( isdefined( actor.script_noteworthy ) )
            {
                actorName = actorName + toLower( actor.script_noteworthy + "" );
            }

            if ( isSubStr( actorName, "survivor" ) || isSubStr( actorName, "civilian" ) || isSubStr( actorName, "escort" ) )
            {
                // Active survivor escort detected: keep bots from clustering into survivor
                for ( b = 0; b < bots.size; b++ )
                {
                    bot = bots[b];
                    if ( isdefined( bot ) && distance( bot.origin, actor.origin ) < 100 )
                    {
                        // Gently nudge bot back so survivor path is never blocked
                        nudgeDir = vectornormalize( bot.origin - actor.origin );
                        bot setorigin( bot.origin + ( nudgeDir[0] * 60, nudgeDir[1] * 60, 0 ) );
                    }
                }
            }
        }
    }
}

// --- Carrier (mp_zombie_brg) ---

eebiMonitorCarrierBombs()
{
    humans = eebiGetAliveHumans();
    bots = eebiGetAliveBots();

    if ( humans.size <= 0 || bots.size <= 0 )
    {
        return;
    }

    // Find active bomb entities or triggers on Carrier
    triggers = getentarray( "trigger_use", "classname" );
    if ( !isdefined( triggers ) )
    {
        return;
    }

    for ( t = 0; t < triggers.size; t++ )
    {
        trig = triggers[t];
        if ( !isdefined( trig ) || !isdefined( trig.origin ) )
        {
            continue;
        }

        trigName = "";
        if ( isdefined( trig.targetname ) )
        {
            trigName = trigName + toLower( trig.targetname + "" );
        }
        if ( isdefined( trig.script_noteworthy ) )
        {
            trigName = trigName + toLower( trig.script_noteworthy + "" );
        }

        if ( isSubStr( trigName, "bomb" ) || isSubStr( trigName, "defuse" ) )
        {
            for ( h = 0; h < humans.size; h++ )
            {
                human = humans[h];
                if ( isdefined( human ) && distance( human.origin, trig.origin ) <= 90 )
                {
                    // Human is actively defusing bomb: trigger assistant defusal
                    trigId = "" + trig.origin[0] + "_" + trig.origin[1];
                    if ( !isdefined( level.eebi.bombsAssisted[trigId] ) )
                    {
                        level.eebi.bombsAssisted[trigId] = true;
                        trig notify( "trigger", bots[0] );
                        trig notify( "use", bots[0] );
                        level notify( "bomb_defused" );
                        eebiDebugPrint( "Carrier: Assisted bomb defusal near " + trig.origin, true );
                    }
                }
            }
        }
    }
}

// --- Descent (mp_zombie_h2o) ---

eebiMonitorDescentStaging()
{
    humans = eebiGetAliveHumans();
    bots = eebiGetAliveBots();

    if ( humans.size <= 0 || bots.size <= 0 )
    {
        return;
    }

    // Oz arena coordinates in Descent: Z < -700
    humansInArena = 0;
    for ( h = 0; h < humans.size; h++ )
    {
        if ( humans[h].origin[2] < -700 )
        {
            humansInArena++;
        }
    }

    // If human players entered Oz boss arena, transport trailing bots into arena
    if ( humansInArena > 0 && humansInArena == humans.size )
    {
        for ( b = 0; b < bots.size; b++ )
        {
            bot = bots[b];
            if ( isdefined( bot ) && isalive( bot ) && bot.origin[2] >= -700 )
            {
                arenaCenter = ( 650, -1100, -800 );
                bot setorigin( arenaCenter + ( randomfloatrange( -50, 50 ), randomfloatrange( -50, 50 ), 10 ) );
                eebiDebugPrint( "Descent: Teleported bot " + bot.name + " into Oz Boss Arena.", true );
            }
        }
    }
}

// ============================================================
// Phase 4: Bot Protection and Behavior Control During Critical Steps
// ============================================================

eebiIsPuzzlePhaseActive()
{
    if ( getdvarint( "scr_zm_ee_protect_step" ) > 0 )
    {
        return true;
    }

    if ( isdefined( level.ee_puzzle_active ) && level.ee_puzzle_active )
    {
        return true;
    }

    if ( isdefined( level.simon_says_active ) && level.simon_says_active )
    {
        return true;
    }

    if ( isdefined( level.memory_game_active ) && level.memory_game_active )
    {
        return true;
    }

    if ( isdefined( level.capture_zombie_active ) && level.capture_zombie_active )
    {
        return true;
    }

    if ( isdefined( level.holding_special_zombie ) && level.holding_special_zombie )
    {
        return true;
    }

    return false;
}

eebiPuzzleProtectionLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        wait EEBI_REFRESH_INTERVAL;

        if ( getdvarint( "scr_zm_ee_ignore_bots" ) <= 0 || getdvarint( "scr_zm_ee_protect_bots" ) <= 0 )
        {
            continue;
        }

        bots = eebiGetAliveBots();
        puzzleActive = eebiIsPuzzlePhaseActive();

        for ( i = 0; i < bots.size; i++ )
        {
            bot = bots[i];
            if ( !isdefined( bot ) || !isalive( bot ) )
            {
                continue;
            }

            if ( puzzleActive )
            {
                if ( !isdefined( bot.eebiWeaponsSuppressed ) || !bot.eebiWeaponsSuppressed )
                {
                    bot.eebiWeaponsSuppressed = true;
                    bot disableweapons();
                    eebiDebugPrint( "Bot " + bot.name + ": weapons suppressed for Easter Egg puzzle.", false );
                }

                // Temporary damage protection so bot does not bleed out during puzzle
                if ( bot.health < bot.maxhealth )
                {
                    bot.health = bot.maxhealth;
                }
            }
            else
            {
                if ( isdefined( bot.eebiWeaponsSuppressed ) && bot.eebiWeaponsSuppressed )
                {
                    bot.eebiWeaponsSuppressed = undefined;
                    bot enableweapons();
                    eebiDebugPrint( "Bot " + bot.name + ": weapons restored.", false );
                }
            }
        }
    }
}

// ============================================================
// Phase 5: Verification and Debugging Harness
// ============================================================

eebiDebugPrint( msg, isPriority )
{
    debugLevel = getdvarint( "scr_zm_ee_ignore_bots_debug" );

    if ( debugLevel <= 0 && ( !isdefined( isPriority ) || !isPriority ) )
    {
        return;
    }

    formatted = "[EEBotIgnore] " + msg;
    println( formatted );

    if ( debugLevel >= 2 || ( isdefined( isPriority ) && isPriority && debugLevel >= 1 ) )
    {
        iprintln( "^2" + formatted );
    }
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

    eebiDebugPrint(
        "Humans=" + level.eebi.humanCount +
        " Eligible=" + level.eebi.eligibleCount +
        " Bots=" + level.eebi.botCount,
        false
    );
}

eebiOnScreenDebugLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        wait 3.0;

        if ( getdvarint( "scr_zm_ee_ignore_bots_debug" ) < 2 )
        {
            continue;
        }

        humans = eebiGetAliveHumans();
        bots = eebiGetAliveBots();
        puzzleStr = "Inactive";
        if ( eebiIsPuzzlePhaseActive() )
        {
            puzzleStr = "Active";
        }

        iprintln( "^5[EEBot] Humans: " + humans.size + " | Bots: " + bots.size + " | PuzzleProtect: " + puzzleStr );
    }
}

// ============================================================
// Context and Map Check Helpers
// ============================================================

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
    return eebiIsKnownEeQuestMap( lowerMap );
}

eebiIsKnownEeQuestMap( mapname )
{
    if ( !isdefined( mapname ) )
    {
        return false;
    }

    lowerMap = toLower( mapname + "" );

    return lowerMap == "mp_zombie_lab" ||
        lowerMap == "mp_zombie_ark" ||
        lowerMap == "mp_zombie_brg" ||
        lowerMap == "mp_zombie_h2o" ||
        lowerMap == "zombie_outbreak" ||
        lowerMap == "zombie_infection" ||
        lowerMap == "zombie_carrier" ||
        lowerMap == "zombie_descent";
}

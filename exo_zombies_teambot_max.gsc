/*
    Exo Zombies teammate bot max settings.

    Install in s1/scripts/zm.
    Bot health: 30000
    Bot weapon damage: enough to kill the target in one hit
    Native bot difficulty: Veteran
*/

#define EZTB_BOT_HEALTH             30000
#define EZTB_BOT_DAMAGE              30000
#define EZTB_CEL3                    "iw5_fusionzm_mp"
#define EZTB_CEL3_LEVEL              25
#define EZTB_INFINITE_AMMO           999
#define EZTB_REFRESH_INTERVAL        0.25
#define EZTB_HOOK_INTERVAL           0.5
#define EZTB_REVIVE_DISTANCE         128
#define EZTB_DOOR_GOAL_RADIUS        16

main()
{
    init();
}

init()
{
    if ( isdefined( level.eztbStarted ) && level.eztbStarted )
    {
        return;
    }

    level.eztbStarted = true;
    level.eztbOriginalDamage = [];

    eztbEnforceDvars();
    level thread eztbPlayerLoop();
    level thread eztbDamageHookLoop();
}

eztbEnforceDvars()
{
    setdvar( "bot_difficulty", "veteran" );
    setdvar( "scr_zm_teambot_health", EZTB_BOT_HEALTH );
    setdvar( "scr_zm_teambot_damage", EZTB_BOT_DAMAGE );
}

eztbPlayerLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        eztbEnforceDvars();

        players = getplayers();
        if ( isdefined( players ) )
        {
            foreach ( player in players )
            {
                if ( !eztbIsTeammateBot( player ) )
                {
                    continue;
                }

                if ( !isAlive( player ) )
                {
                    if ( isdefined( player.pers ) )
                    {
                        player.pers["eztbLoadoutGiven"] = false;
                    }

                    player.eztbExoHealthGranted = false;
                    continue;
                }

                eztbEnsureExoSuitAndPerks( player );
                player.maxhealth = EZTB_BOT_HEALTH;
                player.maxHealth = EZTB_BOT_HEALTH;
                player.health = EZTB_BOT_HEALTH;
                eztbReviveNearbyPlayers( player, players );

                if ( !isdefined( player.pers ) )
                {
                    player.pers = [];
                }

                if ( !isdefined( player.pers["eztbLoadoutGiven"] ) ||
                     !player.pers["eztbLoadoutGiven"] )
                {
                    player.pers["eztbLoadoutGiven"] = true;
                    player thread eztbApplyBotLoadout();
                }

                eztbKeepCel3Ammo( player );
                eztbTryOpenNearestDoor( player );

                if ( eztbIsDescentMap() )
                {
                    eztbTryUseDescentTube( player );
                }
            }
        }

        wait EZTB_REFRESH_INTERVAL;
    }
}

eztbIsTeammateBot( player )
{
    if ( !isdefined( player ) )
    {
        return false;
    }

    if ( isdefined( player.sessionstate ) )
    {
        state = toLower( player.sessionstate + "" );
        if ( state == "spectator" || state == "intermission" )
        {
            return false;
        }
    }

    if ( isdefined( player.isBot ) && eztbValueIsTrue( player.isBot ) )
    {
        return true;
    }

    if ( isdefined( player.pers ) &&
         isdefined( player.pers["isBot"] ) &&
         eztbValueIsTrue( player.pers["isBot"] ) )
    {
        return true;
    }

    if ( isdefined( player.pers ) &&
         isdefined( player.pers["eebi_is_bot"] ) &&
         eztbValueIsTrue( player.pers["eebi_is_bot"] ) )
    {
        return true;
    }

    if ( isdefined( player.eebiIsBot ) &&
         eztbValueIsTrue( player.eebiIsBot ) )
    {
        return true;
    }

    guid = player getguid();
    return isdefined( guid ) && issubstr( toLower( guid + "" ), "bot" );
}

eztbValueIsTrue( value )
{
    if ( !isdefined( value ) )
    {
        return false;
    }

    stringValue = toLower( value + "" );
    return stringValue == "1" ||
           stringValue == "true" ||
           stringValue == "yes" ||
           stringValue == "bot";
}

eztbApplyBotLoadout()
{
    self endon( "disconnect" );
    self endon( "death" );

    wait 0.5;
    if ( !isdefined( self ) || !isAlive( self ) )
    {
        return;
    }

    weapon = eztbFindCel3( self );
    if ( weapon == "" )
    {
        maps\mp\zombies\_wall_buys::givezombieweapon(
            self,
            EZTB_CEL3,
            0,
            1
        );
        weapon = EZTB_CEL3;
    }

    maps\mp\zombies\_wall_buys::setweaponlevel(
        self,
        weapon,
        EZTB_CEL3_LEVEL
    );

    self.maxhealth = EZTB_BOT_HEALTH;
    self.maxHealth = EZTB_BOT_HEALTH;
    self.health = EZTB_BOT_HEALTH;
}

eztbEnsureExoSuitAndPerks( player )
{
    if ( !player hasexosuit() )
    {
        player maps\mp\zombies\_terminals::perkterminalsetexosuit(
            "exo_suit",
            undefined
        );
    }

    player.exosuitonline = 1;

    if ( !isdefined( player.eztbExoHealthGranted ) ||
         !player.eztbExoHealthGranted )
    {
        player maps\mp\zombies\_terminals::perkterminalsetexohealth(
            "exo_health",
            undefined
        );
        player.eztbExoHealthGranted = true;
    }

    if ( !player hasperk( "specialty_fastreload", 1 ) ||
         !player hasperk( "specialty_sprintreload", 1 ) )
    {
        player maps\mp\zombies\_terminals::perkterminalsetexofastreload(
            "specialty_fastreload",
            undefined
        );
    }

    if ( !isdefined( player.isexostimactive ) ||
         !player.isexostimactive )
    {
        player maps\mp\zombies\_terminals::perkterminalsetexorevive(
            "exo_revive",
            undefined
        );
    }

    if ( !player hasperk( "specialty_bulletaccuracy", 1 ) ||
         !player hasperk( "specialty_sprintfire", 1 ) ||
         !player hasperk( "specialty_quickswap", 1 ) ||
         !player hasperk( "specialty_fastoffhand", 1 ) )
    {
        player maps\mp\zombies\_terminals::perkterminalsetexostabilizer(
            "exo_stabilizer",
            undefined
        );
    }

    if ( !isdefined( player.isexoslamactive ) ||
         !player.isexoslamactive )
    {
        player maps\mp\zombies\_terminals::perkterminalsetexoslam(
            "exo_slam",
            undefined
        );
    }

    if ( !player hasperk( "specialty_stockpile", 1 ) ||
         !player hasperk( "specialty_extralethal", 1 ) ||
         !player hasperk( "specialty_extratactical", 1 ) )
    {
        player maps\mp\zombies\_terminals::perkterminalsetexotacticalarmor(
            "exo_tacticalArmor",
            undefined
        );
    }
}

eztbFindCel3( player )
{
    weapons = player getweaponslistprimariesminusalts();
    if ( !isdefined( weapons ) )
    {
        return "";
    }

    foreach ( weapon in weapons )
    {
        if ( getweaponbasename( weapon ) == EZTB_CEL3 )
        {
            return weapon;
        }
    }

    return "";
}

eztbKeepCel3Ammo( player )
{
    weapons = player getweaponslistall();
    if ( !isdefined( weapons ) )
    {
        return;
    }

    foreach ( weapon in weapons )
    {
        if ( getweaponbasename( weapon ) != EZTB_CEL3 )
        {
            continue;
        }

        player setweaponammoclip( weapon, EZTB_INFINITE_AMMO );
        player setweaponammostock( weapon, EZTB_INFINITE_AMMO );
    }
}

eztbReviveNearbyPlayers( bot, players )
{
    if ( isdefined( bot.eztbReviveActive ) && bot.eztbReviveActive )
    {
        return;
    }

    foreach ( player in players )
    {
        if ( !isdefined( player ) ||
             player == bot ||
             !isdefined( player.inlaststand ) ||
             !player.inlaststand ||
             !isdefined( player.revivetrigger ) ||
             ( isdefined( player.beingrevived ) && player.beingrevived ) ||
             !isdefined( player.origin ) ||
             distance( bot.origin, player.origin ) > EZTB_REVIVE_DISTANCE )
        {
            continue;
        }

        bot.eztbReviveActive = true;
        player notify( "revive_trigger", bot );
        bot thread eztbClearReviveCooldown();
        return;
    }
}

eztbClearReviveCooldown()
{
    self endon( "disconnect" );
    wait 1;
    self.eztbReviveActive = false;
}

eztbIsDescentMap()
{
    mapName = toLower( getdvar( "mapname" ) + "" );
    return mapName == "zombie_descent" ||
           mapName == "mp_zombie_descent" ||
           mapName == "mp_zombie_h2o" ||
           mapName == "zombie_h2o";
}

eztbTryUseDescentTube( player )
{
    if ( isdefined( player.eztbTubeUseActive ) &&
         player.eztbTubeUseActive )
    {
        return;
    }

    if ( !isdefined( level.eztbDescentTubes ) )
    {
        level.eztbDescentTubes =
            common_scripts\utility::getStructArray(
                "zombie_tube",
                "targetname"
            );
    }

    if ( !isdefined( level.eztbDescentTubes ) ||
         level.eztbDescentTubes.size == 0 )
    {
        return;
    }

    foreach ( tube in level.eztbDescentTubes )
    {
        if ( !isdefined( tube ) ||
             !isdefined( tube.trigger ) ||
             !player istouching( tube.trigger ) )
        {
            continue;
        }

        player.eztbTubeUseActive = true;
        tube.trigger notify( "trigger", player );
        player thread eztbClearTubeCooldown();
        return;
    }
}

eztbClearTubeCooldown()
{
    self endon( "disconnect" );
    wait 3;
    self.eztbTubeUseActive = false;
}

eztbTryOpenNearestDoor( player )
{
    if ( isdefined( player.eztbDoorBuyActive ) &&
         player.eztbDoorBuyActive )
    {
        return;
    }

    if ( !isdefined( level.zombiedoors ) )
    {
        eztbClearDoorGoal( player );
        return;
    }

    closestTrigger = undefined;
    closestDistance = 999999;

    foreach ( door in level.zombiedoors )
    {
        if ( !isdefined( door ) ||
             ( isdefined( door.open ) && door.open ) ||
             !isdefined( door.triggers ) )
        {
            continue;
        }

        foreach ( trigger in door.triggers )
        {
            if ( !isdefined( trigger ) ||
                 !isdefined( trigger.origin ) )
            {
                continue;
            }

            doorDistance = distance( player.origin, trigger.origin );
            if ( doorDistance < closestDistance )
            {
                closestDistance = doorDistance;
                closestTrigger = trigger;
            }
        }
    }

    if ( !isdefined( closestTrigger ) )
    {
        eztbClearDoorGoal( player );
        return;
    }

    if ( !isdefined( player.eztbDoorGoal ) ||
         player.eztbDoorGoal != closestTrigger )
    {
        eztbClearDoorGoal( player );
        if ( player botsetscriptgoal(
                closestTrigger.origin,
                EZTB_DOOR_GOAL_RADIUS,
                "objective"
            ) )
        {
            player.eztbDoorGoal = closestTrigger;
        }
    }

    if ( player istouching( closestTrigger ) )
    {
        player.eztbDoorBuyActive = true;
        closestTrigger notify( "trigger", player );
        player thread eztbClearDoorBuyCooldown();
    }
}

eztbClearDoorGoal( player )
{
    if ( isdefined( player.eztbDoorGoal ) )
    {
        player botclearscriptgoal();
        player.eztbDoorGoal = undefined;
    }
}

eztbClearDoorBuyCooldown()
{
    self endon( "disconnect" );
    wait 1;
    self.eztbDoorBuyActive = false;
}

eztbDamageHookLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( isdefined( level.modifyweapondamage ) )
        {
            weaponNames = getArrayKeys( level.modifyweapondamage );

            foreach ( weaponName in weaponNames )
            {
                currentCallback = level.modifyweapondamage[weaponName];
                if ( !isdefined( currentCallback ) ||
                     currentCallback == ::eztbModifyWeaponDamage )
                {
                    continue;
                }

                level.eztbOriginalDamage[weaponName] = currentCallback;
                level.modifyweapondamage[weaponName] =
                    ::eztbModifyWeaponDamage;
            }

            if ( !isdefined(
                    level.modifyweapondamage[EZTB_CEL3]
                ) )
            {
                level.modifyweapondamage[EZTB_CEL3] =
                    ::eztbModifyWeaponDamage;
            }
        }

        wait EZTB_HOOK_INTERVAL;
    }
}

eztbModifyWeaponDamage(
    victim,
    attacker,
    damage,
    meansOfDeath,
    weapon,
    point,
    direction,
    hitLocation
)
{
    weaponName = "";
    if ( isdefined( weapon ) && weapon != "" )
    {
        weaponName = getweaponbasename( weapon );
    }

    if ( weaponName != "" &&
         isdefined( level.eztbOriginalDamage[weaponName] ) )
    {
        originalCallback = level.eztbOriginalDamage[weaponName];
        damage = [[ originalCallback ]](
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            point,
            direction,
            hitLocation
        );
    }

    if ( !eztbIsTeammateBot( attacker ) ||
         !isdefined( victim ) ||
         !isdefined( victim.health ) ||
         victim.health <= 0 ||
         isplayer( victim ) )
    {
        return damage;
    }

    lethalDamage = getdvarint( "scr_zm_teambot_damage" );
    if ( lethalDamage < EZTB_BOT_DAMAGE )
    {
        lethalDamage = EZTB_BOT_DAMAGE;
    }

    if ( lethalDamage <= victim.health )
    {
        lethalDamage = victim.health + 1;
    }

    return lethalDamage;
}

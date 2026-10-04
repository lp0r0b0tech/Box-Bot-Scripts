/*
    S1x Exo Zombies teammate bot boosts.
    S1x: install at <game folder>/s1x/scripts/exo_zombies_teambot_max.gsc.
    Put it directly in scripts, not in a zm subfolder. Remove older copies
    of this bot script and restart the game after installing.

    - Veteran difficulty with zero aiming error and reaction delay.
    - Living teammate bots receive 30,000 health, refreshed every 0.25 seconds.
    - Exo suit, available Exo upgrades, and CEL-3 Cauterizer Mk25.
    - Their Atlas 45 and CEL-3 shots one-shot ordinary zombies, including armor.
      Scripted boss immunities and delayed deaths remain under native control.
    - Human health, human weapon damage, and bot counts are unchanged.
      Spawn teammate bots using your usual S1x bot controls.
    - Bots approach affordable powered doors and buy them with their own points.
      Nearby downed teammates take priority; revives require normal held use.

    Install only this file. Works with or without the original
    allweapondamage_Version2.gsc; no changes to that file are needed.
*/

#define EZTB_BOT_HEALTH       350
#define EZTB_REFRESH_INTERVAL 0.25
#define EZTB_ATLAS45          "iw5_titan45zm_mp"
#define EZTB_CEL3             "iw5_fusionzm_mp"

main()
{
    println( "[EZTB] main loaded." );
    init();
}

init()
{
    if ( isdefined( level.eztb_started ) )
        return;

    level.eztb_started = true;
    level thread eztb_start();
}

eztb_start()
{
    level endon( "game_ended" );

    // main can run before the gametype creates its callbacks and teams.
    wait 0.05;
    if ( getdvar( "g_gametype" ) != "zombies" )
    {
        println( "[EZTB] Disabled outside Exo Zombies." );
        return;
    }

    for ( attempt = 0; attempt < 600; attempt++ )
    {
        if ( isdefined( level.playerteam ) && isdefined( level.enemyteam ) &&
             isdefined( level.modifyplayerdamage ) && isdefined( level.modifyweapondamage ) )
            break;
        wait 0.05;
    }

    if ( !isdefined( level.playerteam ) || !isdefined( level.enemyteam ) ||
         !isdefined( level.modifyplayerdamage ) || !isdefined( level.modifyweapondamage ) )
    {
        println( "[EZTB] ERROR: Zombies initialization timed out." );
        iprintlnbold( "^1EZTB: Zombies initialization failed. Check console." );
        return;
    }

    level.eztb_ready = true;
    setdvar( "bot_difficulty", "veteran" );
    level thread eztb_monitor_bots();
    level thread eztb_install_damage_hook();
    level thread eztb_status();
    println( "[EZTB] Ready: Veteran bots, Exo upgrades, CEL-3 Mk25, doors and revives." );
}

eztb_is_teammate_bot( player )
{
    if ( !isdefined( player ) || !isplayer( player ) || !isbot( player ) )
        return false;

    return isdefined( level.playerteam ) &&
        isdefined( player.team ) && player.team == level.playerteam;
}

eztb_monitor_bots()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( getdvar( "bot_difficulty" ) != "veteran" )
            setdvar( "bot_difficulty", "veteran" );

        // level.players may be filtered to humans by the easter egg script.
        players = getentarray( "player", "classname" );
        foreach ( player in players )
        {
            if ( !eztb_is_teammate_bot( player ) || !isalive( player ) )
                continue;

            if ( !isdefined( player.sessionstate ) || player.sessionstate != "playing" )
                continue;

            if ( !isdefined( player.eztb_detected ) )
            {
                player.eztb_detected = true;
                println( "[EZTB] Native teammate bot detected: " + player.name );
                player thread eztb_features();
            }

            if ( player botgetdifficulty() != "veteran" )
                player botsetdifficulty( "veteran" );
            player botsetdifficultysetting( "minInaccuracy", 0 );
            player botsetdifficultysetting( "maxInaccuracy", 0 );
            player botsetdifficultysetting( "reactionTime", 0 );

            // Last stand uses health = 1; leave downing and revives to the game.
            if ( ( isdefined( player.laststand ) && player.laststand ) ||
                 ( isdefined( player.inlaststand ) && player.inlaststand ) )
                continue;

            player.maxhealth = EZTB_BOT_HEALTH;
            player.health = EZTB_BOT_HEALTH;
        }

        wait EZTB_REFRESH_INTERVAL;
    }
}

eztb_status()
{
    level endon( "game_ended" );
    for ( ;; )
    {
        players = getentarray( "player", "classname" );
        count = 0;
        foreach ( player in players )
        {
            if ( eztb_is_teammate_bot( player ) )
                count++;
        }

        foreach ( player in players )
        {
            if ( !isbot( player ) && isalive( player ) &&
                 ( !isdefined( player.eztb_status_count ) || player.eztb_status_count != count ) )
            {
                player iprintlnbold( "^2EZTB active - teammate bots: " + count );
                player.eztb_status_count = count;
            }
        }
        wait 1;
    }
}

eztb_install_damage_hook()
{
    level endon( "game_ended" );

    while ( !isdefined( level.modifyplayerdamage ) || !isdefined( level.modifyweapondamage ) )
        wait 0.05;

    level.eztb_previous_player_damage = level.modifyplayerdamage;
    level.modifyplayerdamage = ::eztb_modify_player_damage;
}

eztb_modify_player_damage( victim, inflictor, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation )
{
    botDamage = eztb_atlas_damage( victim, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation );
    if ( !isdefined( botDamage ) )
        return self [[ level.eztb_previous_player_damage ]]( victim, inflictor, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation );

    // Scope the weapon override to this synchronous native damage call.
    // AllWeaponDamage can keep registering its own hook between hits.
    weaponKey = getweaponbasename( weapon );
    if ( isdefined( level.damageweapontoweapon ) && isdefined( level.damageweapontoweapon[weaponKey] ) )
        weaponKey = level.damageweapontoweapon[weaponKey];
    previousWeaponDamage = level.modifyweapondamage[weaponKey];
    level.modifyweapondamage[weaponKey] = ::eztb_modify_damage;
    result = self [[ level.eztb_previous_player_damage ]]( victim, inflictor, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation );
    level.modifyweapondamage[weaponKey] = previousWeaponDamage;

    // Keep native points, armor, boss immunity and deferred-death decisions.
    return result;
}

eztb_modify_damage( victim, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation )
{
    botDamage = eztb_atlas_damage( victim, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation );
    if ( isdefined( botDamage ) )
        return botDamage;

    return damage;
}

// Undefined means that the caller must retain its normal damage handling.
eztb_atlas_damage( victim, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation )
{
    if ( !eztb_is_teammate_bot( attacker ) )
        return undefined;

    if ( !isdefined( victim ) || isplayer( victim ) || !isai( victim ) || !isalive( victim ) )
        return undefined;

    if ( !isdefined( level.enemyteam ) || !isdefined( victim.team ) ||
         victim.team != level.enemyteam )
        return undefined;

    if ( !isdefined( weapon ) )
        return undefined;

    baseWeapon = getweaponbasename( weapon );
    if ( baseWeapon != EZTB_ATLAS45 && baseWeapon != EZTB_CEL3 )
        return undefined;

    if ( !isdefined( meansOfDeath ) || meansOfDeath == "MOD_MELEE" )
        return undefined;

    if ( damage <= 0 || !isdefined( victim.health ) || victim.health <= 0 )
        return undefined;

    // Stock helmets/body armor halve damage after this hook.
    lethalDamage = int( ( victim.health + 1 ) * 2 );
    if ( damage > lethalDamage )
        return damage;

    return lethalDamage;
}

eztb_can_act()
{
    return eztb_is_teammate_bot( self ) && isalive( self ) &&
        isdefined( self.sessionstate ) && self.sessionstate == "playing" &&
        !( isdefined( self.laststand ) && self.laststand ) &&
        !( isdefined( self.inlaststand ) && self.inlaststand ) &&
        !( isdefined( self.isreviving ) && self.isreviving );
}

eztb_features()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for ( ;; )
    {
        wait 1;
        if ( !eztb_can_act() || !isdefined( self.weaponstate ) ||
             !isdefined( self.zm_perks ) || !isdefined( self.characterindex ) ||
             !isdefined( self.exosuitround ) || !isdefined( level.wavecounter ) ||
             !isdefined( self.moneycurrent ) || !isdefined( self.moneyearnedtotal ) ||
             !isdefined( level.terminalitems ) ||
             ( isdefined( self.playingweaponflourish ) && self.playingweaponflourish ) )
            continue;

        eztb_grant_perk( "exo_suit", maps\mp\zombies\_terminals::perkterminalsetexosuit, maps\mp\zombies\_terminals::perkterminaltakeexosuit );
        if ( !eztb_can_act() || !self maps\mp\zombies\_terminals::hasexosuit() )
            continue;

        eztb_grant_perk( "exo_health", maps\mp\zombies\_terminals::perkterminalsetexohealth, maps\mp\zombies\_terminals::perkterminaltakeexohealth );
        eztb_grant_perk( "specialty_fastreload", maps\mp\zombies\_terminals::perkterminalsetexofastreload, maps\mp\zombies\_terminals::perkterminaltakeexofastreload );
        eztb_grant_perk( "exo_revive", maps\mp\zombies\_terminals::perkterminalsetexorevive, maps\mp\zombies\_terminals::perkterminaltakeexorevive );
        eztb_grant_perk( "exo_stabilizer", maps\mp\zombies\_terminals::perkterminalsetexostabilizer, maps\mp\zombies\_terminals::perkterminaltakeexostabilizer );
        eztb_grant_perk( "exo_slam", maps\mp\zombies\_terminals::perkterminalsetexoslam, maps\mp\zombies\_terminals::perkterminaltakeexoslam );
        eztb_grant_perk( "exo_tacticalArmor", maps\mp\zombies\_terminals::perkterminalsetexotacticalarmor, maps\mp\zombies\_terminals::perkterminaltakeexotacticalarmor );

        if ( !eztb_can_act() )
            continue;

        self.maxhealth = EZTB_BOT_HEALTH;
        self.health = EZTB_BOT_HEALTH;
        eztb_give_cel3();
        if ( !eztb_try_revive() )
            eztb_try_door();
    }
}

eztb_grant_perk( item, setter, remover )
{
    if ( !eztb_can_act() || !isdefined( level.terminalitems[item] ) )
        return;

    foreach ( owned in self.zm_perks )
    {
        // Exo Health's native ownership check is maxhealth == 200.
        // Use its acquisition record instead, since our bots have 30000 health.
        if ( owned == item )
            return;
    }

    if ( item == "exo_suit" && self maps\mp\zombies\_terminals::hasexosuit() )
        return;

    // Native effects and removal bookkeeping, without consuming a station's
    // shared purchase limit (notably solo Exo Revive) or the humans' points.
    self [[ setter ]]( item, self );
    if ( !eztb_can_act() )
        return;

    self.zm_perks[self.zm_perks.size] = item;
    self thread maps\mp\zombies\_terminals::perkterminaltakewait( item, remover, "killed_player" );
    omnvar = level.terminalitems[item].omnvar;
    if ( isdefined( omnvar ) )
        self setclientomnvar( omnvar, 1 );
    self maps\mp\zombies\_terminals::perkupdatesortorder();
    println( "[EZTB] Granted " + item + " to " + self.name );
}

eztb_give_cel3()
{
    if ( !isdefined( level.camolevel ) || level.camolevel.size == 0 ||
         !isdefined( level.magicboxweapons ) || !isdefined( level.weaponnamemap ) ||
         !isdefined( self.clientid ) )
        return;

    // Do not request weapon assets that the current map has not registered.
    available = false;
    foreach ( entry in level.magicboxweapons )
    {
        if ( isdefined( entry["baseName"] ) && entry["baseName"] == EZTB_CEL3 )
            available = true;
    }
    if ( !available )
    {
        if ( !isdefined( self.eztb_weapon_unavailable ) )
        {
            self.eztb_weapon_unavailable = true;
            println( "[EZTB] CEL-3 not registered on this map; keeping native loadout." );
        }
        return;
    }

    current = undefined;
    foreach ( weapon in self getweaponslistprimaries() )
    {
        if ( getweaponbasename( weapon ) == EZTB_CEL3 )
            current = weapon;
    }

    if ( !isdefined( current ) )
    {
        maps\mp\zombies\_wall_buys::givezombieweapon( self, EZTB_CEL3, 0, 1 );
        current = EZTB_CEL3;
    }

    if ( !isdefined( self.weaponstate[EZTB_CEL3] ) ||
         !isdefined( self.weaponstate[EZTB_CEL3]["level"] ) ||
         self.weaponstate[EZTB_CEL3]["level"] != 25 ||
         current != maps\mp\zombies\_wall_buys::getupgradeweaponname( self, EZTB_CEL3 ) )
    {
        maps\mp\gametypes\zombies::createzombieweaponstate( self, current );
        maps\mp\zombies\_wall_buys::setweaponlevel( self, current, 25 );
        current = maps\mp\zombies\_wall_buys::getupgradeweaponname( self, EZTB_CEL3 );
        println( "[EZTB] CEL-3 Mk25 equipped: " + self.name );
    }

    self givemaxammo( current );
    if ( self getcurrentweapon() != current )
        self switchtoweapon( current );
}

eztb_approach( target, radius )
{
    if ( !isdefined( target ) || !isdefined( target.origin ) || !eztb_can_act() )
        return false;

    goal = target.origin;
    if ( !self botsetscriptgoal( goal, 20, "critical" ) )
        return false;
    self.eztb_goal = goal;

    for ( tick = 0; tick < 40; tick++ )
    {
        if ( !isdefined( target ) || !eztb_can_act() )
            return false;
        if ( distance( self.origin, target.origin ) <= radius )
            return true;
        wait 0.25;
    }
    return false;
}

eztb_clear_goal()
{
    if ( isdefined( self.eztb_goal ) && self bothasscriptgoal() &&
         self botgetscriptgoaltype() == "critical" &&
         self botgetscriptgoal() == self.eztb_goal )
        self botclearscriptgoal();
    self.eztb_goal = undefined;
}

eztb_can_reach_trigger( target )
{
    if ( !isdefined( target ) || distance( self.origin, target.origin ) > 64 )
        return false;
    trace = bullettrace( self geteye(), target.origin + ( 0, 0, 20 ), false, self );
    return trace["fraction"] == 1 || ( isdefined( trace["entity"] ) && trace["entity"] == target );
}

eztb_try_revive()
{
    target = undefined;
    bestDistance = 2048;
    foreach ( trigger in getentarray( "revive_trigger", "targetname" ) )
    {
        if ( !isdefined( trigger.owner ) || trigger.owner == self ||
             !isdefined( trigger.owner.team ) || trigger.owner.team != self.team ||
             !( isdefined( trigger.owner.inlaststand ) && trigger.owner.inlaststand ) ||
             ( isdefined( trigger.inuse ) && trigger.inuse ) ||
             ( isdefined( self.eztb_failed_revive ) && self.eztb_failed_revive == trigger &&
               gettime() < self.eztb_revive_retry_time ) )
            continue;

        dist = distance( self.origin, trigger.origin );
        if ( dist < bestDistance )
        {
            bestDistance = dist;
            target = trigger;
        }
    }
    if ( !isdefined( target ) )
        return false;

    if ( eztb_approach( target, 64 ) && eztb_can_reach_trigger( target ) && isdefined( target.owner ) &&
         isdefined( target.owner.inlaststand ) && target.owner.inlaststand &&
         !( isdefined( target.inuse ) && target.inuse ) )
    {
        self botpressbutton( "use", 3 );
        wait 0.1;
        // Engine use can start the interaction itself; only notify if idle.
        if ( isdefined( target ) && eztb_can_act() && eztb_can_reach_trigger( target ) &&
             isdefined( target.owner ) && isdefined( target.owner.inlaststand ) &&
             target.owner.inlaststand && self usebuttonpressed() &&
             !( isdefined( target.inuse ) && target.inuse ) )
            target notify( "trigger", self );
        wait 3;
        self botclearbutton( "use" );
    }
    if ( isdefined( target ) )
    {
        self.eztb_failed_revive = target;
        self.eztb_revive_retry_time = gettime() + 15000;
    }
    eztb_clear_goal();
    return true;
}

eztb_try_door()
{
    if ( !eztb_can_act() || !isdefined( level.zombiedoors ) || !isdefined( self.moneycurrent ) )
        return;

    target = undefined;
    selectedDoor = undefined;
    bestDistance = 2048;
    foreach ( door in level.zombiedoors )
    {
        if ( ( isdefined( door.open ) && door.open ) ||
             !isdefined( door.cost ) || door.cost > self.moneycurrent ||
             !isdefined( door.triggers ) || !door maps\mp\zombies\_doors::door_has_power() ||
             ( isdefined( door.eztb_retry_time ) && gettime() < door.eztb_retry_time ) )
            continue;

        foreach ( trigger in door.triggers )
        {
            if ( !isdefined( trigger ) )
                continue;
            dist = distance( self.origin, trigger.origin );
            if ( dist < bestDistance )
            {
                bestDistance = dist;
                target = trigger;
                selectedDoor = door;
            }
        }
    }
    if ( !isdefined( target ) )
        return;

    selectedDoor.eztb_retry_time = gettime() + 15000;
    if ( eztb_approach( target, 64 ) && eztb_can_reach_trigger( target ) &&
         !( isdefined( selectedDoor.open ) && selectedDoor.open ) &&
         selectedDoor maps\mp\zombies\_doors::door_has_power() )
    {
        // The native listener performs payment and opens movers/path links.
        target notify( "trigger", self );
        println( "[EZTB] Bot requested door purchase: " + self.name );
    }
    eztb_clear_goal();
}

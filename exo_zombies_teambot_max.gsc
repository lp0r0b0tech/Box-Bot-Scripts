/*
    S1x Exo Zombies teammate bot boosts.
    S1x: install at <game folder>/s1x/scripts/exo_zombies_teambot_max.gsc.
    Put it directly in scripts, not in a zm subfolder. Remove older copies
    of this bot script and restart the game after installing.

    - Veteran is the highest native bot difficulty.
    - Living teammate bots receive 30,000 health, refreshed every 0.25 seconds.
    - Their Atlas 45 bullets one-shot ordinary zombies, including armor.
      Scripted boss immunities and delayed deaths remain under native control.
    - Human health, human weapon damage, and bot counts are unchanged.
      Spawn teammate bots using your usual S1x bot controls.

    Install only this file. Works with or without the original
    allweapondamage_Version2.gsc; no changes to that file are needed.
*/

#define EZTB_BOT_HEALTH       30000
#define EZTB_REFRESH_INTERVAL 0.25
#define EZTB_ATLAS45          "iw5_titan45zm_mp"

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
    println( "[EZTB] Veteran bots, 30000 health, and lethal Atlas 45 enabled." );
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
            }

            if ( player botgetdifficulty() != "veteran" )
                player botsetdifficulty( "veteran" );

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
    previousWeaponDamage = level.modifyweapondamage[EZTB_ATLAS45];
    level.modifyweapondamage[EZTB_ATLAS45] = ::eztb_modify_damage;
    result = self [[ level.eztb_previous_player_damage ]]( victim, inflictor, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation );
    level.modifyweapondamage[EZTB_ATLAS45] = previousWeaponDamage;

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

    if ( !isdefined( weapon ) || getweaponbasename( weapon ) != EZTB_ATLAS45 )
        return undefined;

    if ( meansOfDeath != "MOD_PISTOL_BULLET" && meansOfDeath != "MOD_RIFLE_BULLET" )
        return undefined;

    if ( damage <= 0 || !isdefined( victim.health ) || victim.health <= 0 )
        return undefined;

    // Stock helmets/body armor halve damage after this hook.
    lethalDamage = int( ( victim.health + 1 ) * 2 );
    if ( damage > lethalDamage )
        return damage;

    return lethalDamage;
}

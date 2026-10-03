/*
    S1x Exo Zombies teammate bot boosts.
    Install in your game folder at s1/scripts/zm/exo_zombies_teambot_max.gsc.
    Restart the match after installing.

    - Veteran is the highest native bot difficulty.
    - Living teammate bots receive 30,000 health, refreshed every 0.25 seconds.
    - Their Atlas 45 bullets one-shot ordinary zombies, including armor.
      Scripted boss immunities and delayed deaths remain under native control.
    - Human health, human weapon damage, and bot counts are unchanged.
      Spawn teammate bots using your usual S1x bot controls.

    Works standalone. When using allweapondamage_Version2.gsc, install the
    accompanying updated version too so its repeated hooks retain this boost.
*/

#define EZTB_BOT_HEALTH       30000
#define EZTB_REFRESH_INTERVAL 0.25
#define EZTB_ATLAS45          "iw5_titan45zm_mp"

main()
{
    init();
}

init()
{
    if ( isdefined( level.eztb_started ) )
        return;

    if ( getdvar( "g_gametype" ) != "zombies" )
        return;

    level.eztb_started = true;
    setdvar( "bot_difficulty", "veteran" );
    level.eztb_atlas_damage = ::eztb_atlas_damage;
    level thread eztb_monitor_bots();
    level thread eztb_install_damage_hook();
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
        players = getplayers();
        foreach ( player in players )
        {
            if ( !eztb_is_teammate_bot( player ) || !isalive( player ) )
                continue;

            if ( !isdefined( player.sessionstate ) || player.sessionstate != "playing" )
                continue;

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

eztb_install_damage_hook()
{
    level endon( "game_ended" );

    while ( !isdefined( level.modifyweapondamage ) )
        wait 0.05;

    level.eztb_previous_atlas_damage = level.modifyweapondamage[EZTB_ATLAS45];
    level.modifyweapondamage[EZTB_ATLAS45] = ::eztb_modify_damage;
}

eztb_modify_damage( victim, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation )
{
    botDamage = eztb_atlas_damage( victim, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation );
    if ( isdefined( botDamage ) )
        return botDamage;

    if ( isdefined( level.eztb_previous_atlas_damage ) )
        return [[ level.eztb_previous_atlas_damage ]]( victim, attacker, damage, meansOfDeath, weapon, point, direction, hitLocation );

    return damage;
}

// Also called by the all-weapon script so load order cannot remove the boost.
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

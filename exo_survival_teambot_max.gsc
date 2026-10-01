/*
    Exo Survival teammate bot max upgrades for S1x

    Place this file at:
        s1/scripts/mp/exo_survival_teambot_max.gsc

    Purpose:
        - Only runs in Exo Survival (g_gametype "horde").
        - Gives bots on the survival side (level.playerteam) max Exo Survival
          Armor upgrade and max Weapon Proficiency upgrade.
        - Sets survival-side teammate bots to the max native bot difficulty.
        - Enemy team (level.enemyteam) bots/agents are never touched.

    Covers both bot types found on the survival side:
        - Client bots (isbot / pers["isBot"]) that use the normal armory stats.
        - Squadmate agents (isagent) that do not use the armory, so their
          weapon proficiency bonus is applied through the damage callback.

    Dvars (survival side only):
        set scr_es_teambot_max 1                       // 1 = on, 0 = off
        set scr_es_teambot_armor 10                    // 0-10, 10 = max armor upgrade
        set scr_es_teambot_weapon_proficiency 10       // 0-10, 10 = max weapon proficiency
        set scr_es_teambot_difficulty veteran          // recruit/regular/hardened/veteran
        set scr_es_teambot_debug 0
*/

main()
{
    init();
}

init()
{
    if ( isdefined( level.esTeambotInitStarted ) && level.esTeambotInitStarted )
    {
        return;
    }

    level.esTeambotInitStarted = true;
    level thread esTeambotDeferredInit();
}

esTeambotDeferredInit()
{
    level endon( "game_ended" );

    wait 0.25;

    if ( !esTeambotIsExoSurvival() )
    {
        return;
    }

    esTeambotInitDvars();
    level thread esTeambotLoop();
    println( "ExoSurvivalTeambotMax: initialized." );
}

esTeambotInitDvars()
{
    setdvarifuninitialized( "scr_es_teambot_max", 1 );
    setdvarifuninitialized( "scr_es_teambot_armor", 10 );
    setdvarifuninitialized( "scr_es_teambot_weapon_proficiency", 10 );
    setdvarifuninitialized( "scr_es_teambot_difficulty", "veteran" );
    setdvarifuninitialized( "scr_es_teambot_debug", 0 );
}

esTeambotIsExoSurvival()
{
    gametype = getdvar( "g_gametype" );

    if ( isdefined( level.gametype ) )
    {
        gametype = level.gametype;
    }

    return tolower( gametype ) == "horde";
}

esTeambotLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( getdvarint( "scr_es_teambot_max" ) > 0 && isdefined( level.playerteam ) )
        {
            esTeambotInstallDamageHook();

            teammates = esTeambotGetSurvivalBots();

            for ( i = 0; i < teammates.size; i++ )
            {
                esTeambotApply( teammates[i] );
            }
        }

        wait 0.5;
    }
}

esTeambotGetSurvivalBots()
{
    result = [];
    candidates = [];

    if ( isdefined( level.players ) )
    {
        foreach ( player in level.players )
        {
            candidates[candidates.size] = player;
        }
    }

    if ( isdefined( level.agentarray ) )
    {
        foreach ( agent in level.agentarray )
        {
            candidates[candidates.size] = agent;
        }
    }

    for ( i = 0; i < candidates.size; i++ )
    {
        ent = candidates[i];

        if ( !esTeambotIsSurvivalBot( ent ) )
        {
            continue;
        }

        duplicate = false;

        for ( j = 0; j < result.size; j++ )
        {
            if ( result[j] == ent )
            {
                duplicate = true;
                break;
            }
        }

        if ( !duplicate )
        {
            result[result.size] = ent;
        }
    }

    return result;
}

esTeambotIsSurvivalBot( ent )
{
    if ( !isdefined( ent ) || !isdefined( ent.team ) || !isdefined( level.playerteam ) )
    {
        return false;
    }

    // Survival side only. Enemy horde agents are on level.enemyteam.
    if ( ent.team != level.playerteam )
    {
        return false;
    }

    if ( !isalive( ent ) )
    {
        return false;
    }

    if ( isagent( ent ) )
    {
        if ( isdefined( ent.isactive ) && !ent.isactive )
        {
            return false;
        }

        return true;
    }

    return esTeambotIsClientBot( ent );
}

esTeambotIsClientBot( ent )
{
    if ( !isplayer( ent ) )
    {
        return false;
    }

    if ( isbot( ent ) )
    {
        return true;
    }

    if ( isdefined( ent.pers ) && isdefined( ent.pers["isBot"] ) && ent.pers["isBot"] )
    {
        return true;
    }

    guid = ent getguid();

    if ( isdefined( guid ) && issubstr( tolower( "" + guid ), "bot" ) )
    {
        return true;
    }

    return false;
}

esTeambotClampLevel( value )
{
    if ( value < 0 )
    {
        return 0;
    }

    if ( value > 10 )
    {
        return 10;
    }

    return value;
}

esTeambotApply( bot )
{
    armor = esTeambotClampLevel( getdvarint( "scr_es_teambot_armor" ) );
    proficiency = esTeambotClampLevel( getdvarint( "scr_es_teambot_weapon_proficiency" ) );

    esTeambotApplyDifficulty( bot );
    esTeambotApplyArmor( bot, armor );
    esTeambotApplyProficiency( bot, proficiency );
}

esTeambotApplyDifficulty( bot )
{
    difficulty = tolower( getdvar( "scr_es_teambot_difficulty" ) );

    if ( difficulty != "recruit" && difficulty != "regular" && difficulty != "hardened" && difficulty != "veteran" )
    {
        difficulty = "veteran";
    }

    // Horde sets squadmates to "regular" on every spawn, so keep re-applying.
    if ( bot botgetdifficulty() != difficulty )
    {
        bot maps\mp\bots\_bots_util::bot_set_difficulty( difficulty );
        esTeambotDebug( bot, "difficulty " + difficulty );
    }
}

esTeambotApplyArmor( bot, armor )
{
    if ( isplayer( bot ) )
    {
        // Client bots use the stock armory formula: classmaxhealth + armor * 40.
        if ( !isdefined( bot.hordearmor ) || bot.hordearmor < armor )
        {
            bot.hordearmor = armor;
            bot setclientomnvar( "horde_armor", armor );
            esTeambotDebug( bot, "armor " + armor );
        }

        // Class not chosen yet; horde applies hordearmor when the class is set.
        if ( !isdefined( bot.classmaxhealth ) )
        {
            return;
        }

        target = bot.classmaxhealth + bot.hordearmor * 40;

        if ( bot.maxhealth < target )
        {
            bot.maxhealth = target;
            bot.health = target;
        }

        return;
    }

    // Squadmate agents: cache the spawn max health once per life and add armor.
    if ( !isdefined( bot.esTeambotArmorApplied ) || bot.esTeambotArmorApplied != armor )
    {
        if ( !isdefined( bot.esTeambotBaseMaxHealth ) )
        {
            bot.esTeambotBaseMaxHealth = bot.maxhealth;
            bot thread esTeambotClearOnDeath();
        }

        bot.hordearmor = armor;
        bot.maxhealth = bot.esTeambotBaseMaxHealth + armor * 40;
        bot.health = bot.maxhealth;
        bot.esTeambotArmorApplied = armor;
        esTeambotDebug( bot, "armor " + armor );
    }
}

esTeambotClearOnDeath()
{
    self notify( "esTeambotClearOnDeath" );
    self endon( "esTeambotClearOnDeath" );

    self waittill( "death" );

    self.esTeambotBaseMaxHealth = undefined;
    self.esTeambotArmorApplied = undefined;
    self.esTeambotProficiency = undefined;
}

esTeambotApplyProficiency( bot, proficiency )
{
    if ( isplayer( bot ) )
    {
        if ( !isdefined( bot.weaponproficiency ) || bot.weaponproficiency < proficiency )
        {
            bot.weaponproficiency = proficiency;
            bot setclientomnvar( "horde_weapon_proficiency", proficiency );
            esTeambotDebug( bot, "weapon proficiency " + proficiency );

            // Re-give current weapons with the proficiency camo when a class is set.
            if ( isdefined( bot.hordeclassweapons ) && bot getclientomnvar( "ui_horde_player_class" ) != "none" )
            {
                level thread maps\mp\gametypes\_horde_armory::hordeweaponlevel( bot );
            }
        }

        // Stock armory adds +0.2 damage per proficiency level.
        bot.weapondmgmod = 1 + bot.weaponproficiency * 0.2;
        return;
    }

    // Squadmate agents: damage bonus is applied in esTeambotModifyDamage.
    bot.weaponproficiency = proficiency;
    bot.esTeambotProficiency = proficiency;
}

esTeambotInstallDamageHook()
{
    if ( !isdefined( level.modifyplayerdamage ) )
    {
        return;
    }

    if ( level.modifyplayerdamage == ::esTeambotModifyDamage )
    {
        return;
    }

    level.esTeambotPrevModifyDamage = level.modifyplayerdamage;
    level.modifyplayerdamage = ::esTeambotModifyDamage;
}

esTeambotModifyDamage( victim, inflictor, attacker, damage, meansOfDeath, weapon, point, dir, hitLoc )
{
    if ( isdefined( level.esTeambotPrevModifyDamage ) )
    {
        damage = [[ level.esTeambotPrevModifyDamage ]]( victim, inflictor, attacker, damage, meansOfDeath, weapon, point, dir, hitLoc );
    }

    if ( !isdefined( damage ) || damage <= 0 )
    {
        return damage;
    }

    if ( getdvarint( "scr_es_teambot_max" ) <= 0 )
    {
        return damage;
    }

    // Only boost survival-side squadmate agents hitting the enemy team.
    // Client bots already get weapondmgmod from the stock horde callback.
    if ( !isdefined( attacker ) || !isdefined( victim ) || isplayer( attacker ) || !isagent( attacker ) )
    {
        return damage;
    }

    if ( !isdefined( attacker.team ) || !isdefined( victim.team ) || attacker.team != level.playerteam || victim.team != level.enemyteam )
    {
        return damage;
    }

    if ( !isdefined( attacker.esTeambotProficiency ) || attacker.esTeambotProficiency <= 0 )
    {
        return damage;
    }

    return int( damage * ( 1 + attacker.esTeambotProficiency * 0.2 ) );
}

esTeambotDebug( bot, message )
{
    if ( getdvarint( "scr_es_teambot_debug" ) <= 0 )
    {
        return;
    }

    name = "agent";

    if ( isdefined( bot.name ) )
    {
        name = bot.name;
    }

    println( "ExoSurvivalTeambotMax: " + name + " -> " + message );
}

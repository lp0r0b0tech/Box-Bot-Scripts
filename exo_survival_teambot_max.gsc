/*
    Exo Survival teammate bot max upgrades for S1x

    Place this file at:
        s1/scripts/mp/exo_survival_teambot_max.gsc

    Purpose:
        - Only runs in Exo Survival (g_gametype "horde").
        - Gives teammate bot players on the survival side (level.playerteam)
          max Exo Survival Armor upgrade and max Weapon Proficiency upgrade.
        - Sets survival-side teammate bot players to the max native bot
          difficulty.
        - Only affects client bot players (pers["isBot"] / "bot" GUIDs).
          Squadmate agents, human players, and the enemy team
          (level.enemyteam) are never touched.

    S1x compatibility notes:
        - No references to game script files (maps\mp\...) so the script
          loads standalone regardless of the dumped script set.
        - Bot detection uses pers["isBot"] with a GUID fallback instead of
          the isbot() builtin, matching the other scripts in this repo.

    Dvars (survival-side bot players only):
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

    if ( !isdefined( gametype ) )
    {
        return false;
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

    if ( !isdefined( level.players ) )
    {
        return result;
    }

    for ( i = 0; i < level.players.size; i++ )
    {
        player = level.players[i];

        if ( esTeambotIsSurvivalBot( player ) )
        {
            result[result.size] = player;
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

    // Teammate bot players only; squadmate agents are not players.
    if ( !isplayer( ent ) )
    {
        return false;
    }

    return esTeambotIsClientBot( ent );
}

esTeambotIsClientBot( ent )
{
    if ( !isplayer( ent ) )
    {
        return false;
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

    // Horde resets bot difficulty on spawn, so keep re-applying.
    current = bot botgetdifficulty();

    if ( !isdefined( current ) || current != difficulty )
    {
        bot botsetdifficulty( difficulty );
        esTeambotDebug( bot, "difficulty " + difficulty );
    }
}

esTeambotApplyArmor( bot, armor )
{
    // Client bots use the stock armory formula: classmaxhealth + armor * 40.
    if ( !isdefined( bot.hordearmor ) || bot.hordearmor < armor )
    {
        bot.hordearmor = armor;
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
}

esTeambotApplyProficiency( bot, proficiency )
{
    if ( !isdefined( bot.weaponproficiency ) || bot.weaponproficiency < proficiency )
    {
        bot.weaponproficiency = proficiency;
        esTeambotDebug( bot, "weapon proficiency " + proficiency );
    }

    // Stock armory adds +0.2 damage per proficiency level.
    bot.weapondmgmod = 1 + bot.weaponproficiency * 0.2;
}

esTeambotDebug( bot, message )
{
    if ( getdvarint( "scr_es_teambot_debug" ) <= 0 )
    {
        return;
    }

    name = "bot";

    if ( isdefined( bot.name ) )
    {
        name = bot.name;
    }

    println( "ExoSurvivalTeambotMax: " + name + " -> " + message );
}

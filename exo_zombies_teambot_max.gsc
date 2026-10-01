/*
    Exo Zombies teammate bot max settings.

    Install in s1/scripts/zm.
    Bot health: 30000
    Bot weapon damage: enough to kill the target in one hit
    Native bot difficulty: Veteran
*/

#define EZTB_BOT_HEALTH             30000
#define EZTB_BOT_DAMAGE              30000
#define EZTB_REFRESH_INTERVAL        0.25
#define EZTB_HOOK_INTERVAL           0.5

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
                if ( !eztbIsTeammateBot( player ) || !isAlive( player ) )
                {
                    continue;
                }

                player.maxhealth = EZTB_BOT_HEALTH;
                player.maxHealth = EZTB_BOT_HEALTH;
                player.health = EZTB_BOT_HEALTH;
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

    return isdefined( player.eebiIsBot ) &&
           eztbValueIsTrue( player.eebiIsBot );
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

    if ( isdefined( level.zombie_team ) &&
         isdefined( victim.team ) &&
         victim.team != level.zombie_team )
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

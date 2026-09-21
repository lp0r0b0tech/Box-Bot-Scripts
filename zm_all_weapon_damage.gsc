/*
    Exo Zombies custom damage modifier for all weapons

    Place this file at:
        s1/scripts/zm/zm_all_weapon_damage.gsc

    Damage progression for every weapon:
        Mk1  = stock / vanilla damage
        Mk2+ = Cell 3 Cauterizer-style level scaling
        Mk25 = highest supported mark for this script

    Curve:
        finalDamage = baseDamage + (baseDamage * 0.2 * (mark - 1))

    Magazine capacity and reserve ammunition:
        Left unchanged; the normal Exo Zombies weapon-upgrade system
        controls those values.

    Hit locations:
        Left unchanged; the normal Exo Zombies damage system controls
        head, neck, helmet, and body multipliers.
*/

#define AWD_CAUTERIZER_LEVEL_MULTIPLIER           0.2
#define AWD_MAX_WEAPON_LEVEL                      25
#define AWD_WEAPON_LEVEL_INCREASE_KEY             "weapon_level_increase"

main()
{
    if ( isdefined( level.awd_started ) )
    {
        return;
    }

    level.awd_started = 1;

    println( "AllWeaponDamage: Zombies script initialized." );

    level thread awd_register_damage_modifiers();
}

awd_register_damage_modifiers()
{
    level endon( "game_ended" );

    for ( i = 0; i < 2400; i++ )
    {
        if ( isdefined( level.modifyweapondamage ) )
        {
            break;
        }

        wait 0.05;
    }

    if ( !isdefined( level.modifyweapondamage ) )
    {
        println( "AllWeaponDamage: ERROR - level.modifyweapondamage was never initialized." );
        return;
    }

    println( "AllWeaponDamage: watching player weapon states." );

    for ( ;; )
    {
        awd_sync_weapon_callbacks();
        wait 0.5;
    }
}

awd_sync_weapon_callbacks()
{
    if ( !isdefined( level.modifyweapondamage ) )
    {
        return;
    }

    players = getplayers();

    if ( !isdefined( players ) )
    {
        return;
    }

    foreach ( player in players )
    {
        if ( !isdefined( player ) || !isplayer( player ) || !isdefined( player.weaponstate ) )
        {
            continue;
        }

        weaponNames = getarraykeys( player.weaponstate );

        if ( !isdefined( weaponNames ) )
        {
            continue;
        }

        foreach ( weaponName in weaponNames )
        {
            if ( !isdefined( weaponName ) || weaponName == "" )
            {
                continue;
            }

            if ( !isdefined( player.weaponstate[weaponName] ) )
            {
                continue;
            }

            baseWeaponName = getweaponbasename( weaponName );

            if ( !isdefined( baseWeaponName ) || baseWeaponName == "" )
            {
                continue;
            }

            awd_disable_stock_weapon_level_increase( player, weaponName );

            if ( !isdefined( level.modifyweapondamage[weaponName] ) ||
                 level.modifyweapondamage[weaponName] != ::awd_modify_damage )
            {
                level.modifyweapondamage[weaponName] = ::awd_modify_damage;
            }
        }
    }
}

awd_disable_stock_weapon_level_increase( player, weaponKey )
{
    if ( !isdefined( player ) ||
         !isdefined( player.weaponstate ) ||
         !isdefined( weaponKey ) ||
         weaponKey == "" )
    {
        return;
    }

    if ( isdefined( player.weaponstate[weaponKey] ) &&
         ( !isdefined( player.weaponstate[weaponKey][AWD_WEAPON_LEVEL_INCREASE_KEY] ) ||
           player.weaponstate[weaponKey][AWD_WEAPON_LEVEL_INCREASE_KEY] != 0 ) )
    {
        player.weaponstate[weaponKey][AWD_WEAPON_LEVEL_INCREASE_KEY] = 0;
    }
}

awd_modify_damage(
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
    if ( !isdefined( attacker ) || !isplayer( attacker ) )
    {
        return damage;
    }

    if ( !isdefined( attacker.weaponstate ) )
    {
        return damage;
    }

    if ( !isdefined( weapon ) || weapon == "" )
    {
        return damage;
    }

    awd_disable_stock_weapon_level_increase( attacker, weapon );

    weaponLevel = undefined;
    exactWeaponStateDefined = isdefined( attacker.weaponstate[weapon] );
    exactWeaponLevelUsable = false;

    if ( exactWeaponStateDefined &&
         isdefined( attacker.weaponstate[weapon]["level"] ) )
    {
        weaponLevel = attacker.weaponstate[weapon]["level"];
        exactWeaponLevelUsable = weaponLevel >= 2;
    }

    baseWeaponName = getweaponbasename( weapon );

    if ( !exactWeaponLevelUsable &&
         isdefined( baseWeaponName ) &&
         baseWeaponName != "" &&
         isdefined( attacker.weaponstate[baseWeaponName] ) &&
         isdefined( attacker.weaponstate[baseWeaponName]["level"] ) )
    {
        awd_disable_stock_weapon_level_increase( attacker, baseWeaponName );
        weaponLevel = attacker.weaponstate[baseWeaponName]["level"];
    }

    if ( !isdefined( weaponLevel ) || weaponLevel < 2 )
    {
        return damage;
    }

    if ( weaponLevel > AWD_MAX_WEAPON_LEVEL )
    {
        weaponLevel = AWD_MAX_WEAPON_LEVEL;
    }

    return awd_get_cauterizer_damage( damage, weaponLevel );
}

awd_get_cauterizer_damage( baseDamage, mark )
{
    if ( mark < 2 )
    {
        return baseDamage;
    }

    if ( mark > AWD_MAX_WEAPON_LEVEL )
    {
        mark = AWD_MAX_WEAPON_LEVEL;
    }

    scaledDamage = baseDamage + ( baseDamage * AWD_CAUTERIZER_LEVEL_MULTIPLIER * ( mark - 1 ) );
    if ( scaledDamage < 0 )
    {
        return int( scaledDamage - 0.5 );
    }

    return int( scaledDamage + 0.5 );
}

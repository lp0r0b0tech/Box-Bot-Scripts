/*
    Exo Zombies custom damage modifier for all weapons

    Place this file at:
        s1/scripts/zm/all_weapon_damage.gsc

    Damage progression for every weapon:
        Mk1  = stock / vanilla damage
        Mk2+ = Cell 3 Cauterizer-style level scaling

    Curve:
        finalDamage = baseDamage + (baseDamage * 0.2 * (mark - 1))

    Magazine capacity and reserve ammunition:
        Left unchanged; the normal Exo Zombies weapon-upgrade system
        controls those values.

    Hit locations:
        Left unchanged; the normal Exo Zombies damage system controls
        head, neck, helmet, and body multipliers.
*/

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

    for ( i = 0; i < 600; i++ )
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

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];

        if ( !isdefined( player ) || !isplayer( player ) || !isdefined( player.weaponstate ) )
        {
            continue;
        }

        weaponNames = player getweaponslistprimaries();

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

            baseWeaponName = getweaponbasename( weaponName );

            awd_disable_stock_weapon_level_increase( player, weaponName );
            awd_disable_stock_weapon_level_increase( player, baseWeaponName );

            level.modifyweapondamage[weaponName] = ::awd_modify_damage;

            if ( isdefined( baseWeaponName ) && baseWeaponName != "" )
            {
                level.modifyweapondamage[baseWeaponName] = ::awd_modify_damage;
            }
        }
    }
}

awd_disable_stock_weapon_level_increase( player, weaponKey )
{
    if ( !isdefined( player ) || !isdefined( weaponKey ) || weaponKey == "" )
    {
        return;
    }

    if ( isdefined( player.weaponstate[weaponKey] ) )
    {
        player.weaponstate[weaponKey]["weapon_level_increase"] = 0;
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

    baseWeaponName = getweaponbasename( weapon );

    if ( !isdefined( baseWeaponName ) || baseWeaponName == "" )
    {
        return damage;
    }

    weaponLevel = maps\mp\zombies\_util::getzombieweaponlevel(
        attacker,
        weapon
    );

    if ( !isdefined( weaponLevel ) || weaponLevel < 2 )
    {
        weaponLevel = maps\mp\zombies\_util::getzombieweaponlevel(
            attacker,
            baseWeaponName
        );
    }

    if ( !isdefined( weaponLevel ) || weaponLevel < 2 )
    {
        return damage;
    }

    if ( weaponLevel > 25 )
    {
        weaponLevel = 25;
    }

    return awd_get_cauterizer_damage( damage, weaponLevel );
}

awd_get_cauterizer_damage( baseDamage, mark )
{
    if ( mark < 2 )
    {
        return baseDamage;
    }

    if ( mark > 25 )
    {
        mark = 25;
    }

    return int( baseDamage + ( baseDamage * 0.2 * ( mark - 1 ) ) );
}

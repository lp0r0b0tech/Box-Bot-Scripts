/*
    Exo Zombies custom damage modifier for all weapons

    Place this file at:
        s1/scripts/zm/all_weapon_damage.gsc

    Damage progression for every weapon:
        Mk1  = stock / vanilla damage
        Mk2  = 2,500 base damage
        Mk20 = 10,000 base damage
        Mk25 = 17,000 base damage

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
    level.awd_previous_damage_callbacks = [];

    println( "AllWeaponDamage: Zombies script initialized." );

    level thread awd_register_damage_modifiers();
}

awd_register_damage_modifiers()
{
    level endon( "game_ended" );

    /*
        Wait for the Zombies gametype to initialize the weapon-damage
        callback table.
    */
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

            awd_register_damage_key( weaponName );
            awd_register_damage_key( baseWeaponName );
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

awd_register_damage_key( weaponKey )
{
    if ( !isdefined( weaponKey ) || weaponKey == "" )
    {
        return;
    }

    if ( !isdefined( level.awd_previous_damage_callbacks[weaponKey] ) &&
         isdefined( level.modifyweapondamage[weaponKey] ) &&
         level.modifyweapondamage[weaponKey] != ::awd_modify_damage )
    {
        level.awd_previous_damage_callbacks[weaponKey] =
            level.modifyweapondamage[weaponKey];
    }

    level.modifyweapondamage[weaponKey] = ::awd_modify_damage;
}

damage = awd_apply_previous_damage_callback(
    victim,
    attacker,
    damage,
    meansOfDeath,
    weapon,
    point,
    direction,
    hitLocation,
    baseWeaponName
)
{
    callback = undefined;

    if ( isdefined( level.awd_previous_damage_callbacks[weapon] ) )
    {
        callback = level.awd_previous_damage_callbacks[weapon];
    }
    else if ( isdefined( baseWeaponName ) &&
              isdefined( level.awd_previous_damage_callbacks[baseWeaponName] ) )
    {
        callback = level.awd_previous_damage_callbacks[baseWeaponName];
    }

    if ( !isdefined( callback ) )
    {
        return damage;
    }

    if ( callback == ::awd_modify_damage )
    {
        return damage;
    }

    return [[ callback ]](
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

/*
    Weapon-damage callback.

    Returning the supplied damage preserves normal Mk1 behavior.
    Returning a custom base damage for Mk2-Mk25 leaves stock ammo and
    stock hit-location behavior under control of the Zombies system.
*/
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
    /*
        Only change damage caused by a player.
    */
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

    /*
        Keep Mk1 completely vanilla.
    */
    if ( !isdefined( weaponLevel ) || weaponLevel < 2 )
    {
        return damage;
    }

    awd_apply_previous_damage_callback(
        victim,
        attacker,
        damage,
        meansOfDeath,
        weapon,
        point,
        direction,
        hitLocation,
        baseWeaponName
    );

    if ( weaponLevel > 25 )
    {
        weaponLevel = 25;
    }

    /*
        Do not process hitLocation here. This intentionally avoids custom
        head/neck/helmet multipliers so the game can retain its normal
        hit-location behavior.
    */
    customBaseDamage = awd_get_base_damage( weaponLevel );

    if ( damage > customBaseDamage )
    {
        return damage;
    }

    return customBaseDamage;
}

/*
    Piecewise-linear upgrade damage curve:

        Mk2  =  2,500
        Mk20 = 10,000
        Mk25 = 17,000

    Mk2 through Mk20:
        2500 + ((mark - 2) * 7500 / 18)

    Mk20 through Mk25:
        10000 + ((mark - 20) * 1400)
*/
awd_get_base_damage( mark )
{
    if ( mark < 2 )
    {
        mark = 2;
    }

    if ( mark > 25 )
    {
        mark = 25;
    }

    if ( mark <= 20 )
    {
        /*
            +9 rounds division to the nearest integer.
        */
        return 2500 + int( ( ( ( ( mark - 2 ) * 7500 ) + 9 ) / 18 ) );
    }

    return 10000 + int( ( mark - 20 ) * 1400 );
}

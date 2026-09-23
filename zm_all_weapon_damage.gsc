/*
    CB Servers S1x v0.0.4
    Exo Zombies custom damage modifier for all weapons

    Place this file at:
        s1/scripts/zm/zm_all_weapon_damage.gsc

    Damage progression for every weapon:
        Mk1  = stock / vanilla damage
        Mk2+ = Cell 3 Cauterizer-style level scaling
        Mk25 = highest supported mark for this script

    Curve:
        finalDamage = baseDamage + (baseDamage * 0.2 * (mark - 1))

    Diagnostic logging:
        Set level.awd_debug_weapons = 1 to print the exact internal weapon
        key seen by the damage callback. Each weapon/base-name pair is logged
        once so live verification stays readable.

    Supported weapons are registered explicitly for CB Servers S1x v0.0.4.
    This list includes the upgradeable firearms and special/wonder guns and
    excludes grenades, drones, teleport/repulsor equipment, Last Stand, and
    Goliath suit weapons.

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
    awd_init_supported_weapons();

    if ( !isdefined( level.awd_debug_weapons ) )
    {
        level.awd_debug_weapons = 0;
    }

    level.awd_debugged_weapons = [];

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
        awd_register_supported_weapon_callbacks();
        awd_sync_weapon_callbacks();
        wait 0.5;
    }
}

awd_init_supported_weapons()
{
    level.awd_supported_weapons = [];

    awd_add_supported_weapon( "iw5_rw1zm_mp" );
    awd_add_supported_weapon( "iw5_vbrzm_mp" );
    awd_add_supported_weapon( "iw5_gm6zm_mp" );
    awd_add_supported_weapon( "iw5_rhinozm_mp" );
    awd_add_supported_weapon( "iw5_lsatzm_mp" );
    awd_add_supported_weapon( "iw5_asawzm_mp" );
    awd_add_supported_weapon( "iw5_ak12zm_mp" );
    awd_add_supported_weapon( "iw5_bal27zm_mp" );
    awd_add_supported_weapon( "iw5_himarzm_mp" );
    awd_add_supported_weapon( "iw5_asm1zm_mp" );
    awd_add_supported_weapon( "iw5_sn6zm_mp" );
    awd_add_supported_weapon( "iw5_sac3zm_mp" );
    awd_add_supported_weapon( "iw5_fusionzm_mp" );
    awd_add_supported_weapon( "iw5_exocrossbowzm_mp" );
    awd_add_supported_weapon( "iw5_mahemzm_mp" );
    awd_add_supported_weapon( "iw5_em1zm_mp" );
    awd_add_supported_weapon( "iw5_dlcgun1zm_mp" );
    awd_add_supported_weapon( "iw5_arx160zm_mp" );
    awd_add_supported_weapon( "iw5_mp11zm_mp" );
    awd_add_supported_weapon( "iw5_hbra3zm_mp" );
    awd_add_supported_weapon( "iw5_hmr9zm_mp" );
    awd_add_supported_weapon( "iw5_maulzm_mp" );
    awd_add_supported_weapon( "iw5_m182sprzm_mp" );
    awd_add_supported_weapon( "iw5_uts19zm_mp" );
    awd_add_supported_weapon( "iw5_titan45zm_mp" );
    awd_add_supported_weapon( "iw5_microwavezm_mp" );
    awd_add_supported_weapon( "iw5_linegunzm_mp" );
    awd_add_supported_weapon( "iw5_dlcgun2zm_mp" );
    awd_add_supported_weapon( "iw5_dlcgun3zm_mp" );
    awd_add_supported_weapon( "iw5_tridentzm_mp" );
    awd_add_supported_weapon( "iw5_dlcgun4zm_mp" );
    awd_add_supported_weapon( "iw5_blunderbusszm_mp" );
}

awd_add_supported_weapon( weaponName )
{
    if ( isdefined( weaponName ) && weaponName != "" )
    {
        level.awd_supported_weapons[weaponName] = 1;
    }
}

awd_is_supported_weapon( weaponName )
{
    return isdefined( weaponName ) &&
           isdefined( level.awd_supported_weapons ) &&
           isdefined( level.awd_supported_weapons[weaponName] );
}

awd_register_supported_weapon_callbacks()
{
    if ( !isdefined( level.modifyweapondamage ) ||
         !isdefined( level.awd_supported_weapons ) )
    {
        return;
    }

    supportedWeapons = getarraykeys( level.awd_supported_weapons );

    if ( !isdefined( supportedWeapons ) )
    {
        return;
    }

    foreach ( weaponName in supportedWeapons )
    {
        if ( !isdefined( level.modifyweapondamage[weaponName] ) ||
             level.modifyweapondamage[weaponName] != ::awd_modify_damage )
        {
            level.modifyweapondamage[weaponName] = ::awd_modify_damage;
        }
    }
}

awd_sync_weapon_callbacks()
{
    if ( !isdefined( level.modifyweapondamage ) ||
         !isdefined( level.awd_supported_weapons ) )
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

            if ( !awd_is_supported_weapon( baseWeaponName ) )
            {
                continue;
            }

            awd_disable_stock_weapon_level_increase( player, weaponName );

            if ( !isdefined( level.modifyweapondamage[weaponName] ) ||
                 level.modifyweapondamage[weaponName] != ::awd_modify_damage )
            {
                level.modifyweapondamage[weaponName] = ::awd_modify_damage;
            }

            if ( baseWeaponName != weaponName &&
                 ( !isdefined( level.modifyweapondamage[baseWeaponName] ) ||
                   level.modifyweapondamage[baseWeaponName] != ::awd_modify_damage ) )
            {
                level.modifyweapondamage[baseWeaponName] = ::awd_modify_damage;
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
    exactWeaponLevelDefined = false;

    if ( exactWeaponStateDefined &&
         isdefined( attacker.weaponstate[weapon]["level"] ) )
    {
        weaponLevel = attacker.weaponstate[weapon]["level"];
        exactWeaponLevelDefined = true;
    }

    baseWeaponName = getweaponbasename( weapon );

    awd_debug_weapon_name( weapon, baseWeaponName );

    if ( !isdefined( baseWeaponName ) || baseWeaponName == "" )
    {
        return damage;
    }

    if ( !awd_is_supported_weapon( baseWeaponName ) )
    {
        return damage;
    }

    if ( !exactWeaponLevelDefined &&
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

awd_debug_weapon_name( weaponName, baseWeaponName )
{
    if ( !isdefined( level.awd_debug_weapons ) || !level.awd_debug_weapons )
    {
        return;
    }

    if ( !isdefined( level.awd_debugged_weapons ) )
    {
        level.awd_debugged_weapons = [];
    }

    if ( !isdefined( weaponName ) || weaponName == "" )
    {
        return;
    }

    debugKey = weaponName;
    baseWeaponLabel = "<undefined>";
    if ( isdefined( baseWeaponName ) && baseWeaponName != "" )
    {
        baseWeaponLabel = baseWeaponName;
        debugKey = weaponName + " -> " + baseWeaponName;
    }

    if ( isdefined( level.awd_debugged_weapons[debugKey] ) )
    {
        return;
    }

    level.awd_debugged_weapons[debugKey] = 1;
    println( "AllWeaponDamage: callback weapon = " + weaponName + ", base = " + baseWeaponLabel );
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

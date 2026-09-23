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

    Supported weapon names are registered explicitly for CB Servers
    S1x v0.0.4.
    This list includes the public Exo Zombies weapon-name map entries plus
    verified special aliases used by equipment, wonder-weapon damage,
    Goliath suit weapons, and online-confirmed S1x menu/loadout variants.

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

    while ( !isdefined( level.modifyweapondamage ) )
    {
        wait 0.05;
    }

    println( "AllWeaponDamage: watching player weapon states." );

    for ( ;; )
    {
        awd_register_supported_weapon_callbacks();
        awd_sync_weapon_callbacks();
        wait 1.0;
    }
}

awd_init_supported_weapons()
{
    level.awd_supported_weapons = [];

    awd_add_supported_weapon( "iw5_rw1zm_mp" );
    awd_add_supported_weapon( "iw5_vbrzm_mp" );
    awd_add_supported_weapon( "iw5_gm6zm_mp" );
    awd_add_supported_weapon( "iw5_gm6zm_mp_gm6scope" );
    awd_add_supported_weapon( "iw5_rhinozm_mp" );
    awd_add_supported_weapon( "iw5_lsatzm_mp" );
    awd_add_supported_weapon( "iw5_asawzm_mp" );
    awd_add_supported_weapon( "iw5_ak12zm_mp" );
    awd_add_supported_weapon( "iw5_bal27zm_mp" );
    awd_add_supported_weapon( "iw5_himarzm_mp" );
    awd_add_supported_weapon( "iw5_asm1zm_mp" );
    awd_add_supported_weapon( "iw5_sn6zm_mp" );
    awd_add_supported_weapon( "iw5_sac3zm_mp" );
    awd_add_supported_weapon( "iw5_sac3zm_mp_akimbosac3" );
    awd_add_supported_weapon( "iw5_fusionzm_mp" );
    awd_add_supported_weapon( "distraction_drone_zombie_mp" );
    awd_add_supported_weapon( "dna_aoe_grenade_zombie_mp" );
    awd_add_supported_weapon( "iw5_exocrossbowzm_mp" );
    awd_add_supported_weapon( "iw5_mahemzm_mp" );
    awd_add_supported_weapon( "iw5_mahemzm_mp_mahemscopebase" );
    awd_add_supported_weapon( "iw5_em1zm_mp" );
    awd_add_supported_weapon( "iw5_dlcgun1zm_mp" );
    awd_add_supported_weapon( "iw5_arx160zm_mp" );
    awd_add_supported_weapon( "iw5_mp11zm_mp" );
    awd_add_supported_weapon( "explosive_drone_zombie_mp" );
    awd_add_supported_weapon( "contact_grenade_zombies_mp" );
    awd_add_supported_weapon( "iw5_hbra3zm_mp" );
    awd_add_supported_weapon( "iw5_hmr9zm_mp" );
    awd_add_supported_weapon( "iw5_maulzm_mp" );
    awd_add_supported_weapon( "iw5_m182sprzm_mp" );
    awd_add_supported_weapon( "iw5_uts19zm_mp" );
    awd_add_supported_weapon( "contact_grenade_throw_zombies_mp" );
    awd_add_supported_weapon( "explosive_drone_throw_zombie_mp" );
    awd_add_supported_weapon( "distraction_drone_throw_zombie_mp" );
    awd_add_supported_weapon( "dna_aoe_grenade_throw_zombie_mp" );
    awd_add_supported_weapon( "iw5_titan45zm_mp" );
    awd_add_supported_weapon( "LastStand" );
    awd_add_supported_weapon( "iw5_microwavezm_mp" );
    awd_add_supported_weapon( "iw5_linegunzm_mp" );
    awd_add_supported_weapon( "iw5_linegundamagezm_mp" );
    awd_add_supported_weapon( "frag_grenade_zombies_mp" );
    awd_add_supported_weapon( "frag_grenade_throw_zombies_mp" );
    awd_add_supported_weapon( "iw5_dlcgun2zm_mp" );
    awd_add_supported_weapon( "iw5_dlcgun3zm_mp" );
    awd_add_supported_weapon( "teleport_zombies_mp" );
    awd_add_supported_weapon( "teleport_throw_zombies_mp" );
    awd_add_supported_weapon( "repulsor_zombie_mp" );
    awd_add_supported_weapon( "iw5_tridentzm_mp" );
    awd_add_supported_weapon( "iw5_dlcgun4zm_mp" );
    awd_add_supported_weapon( "iw5_exominigunzm_mp" );
    awd_add_supported_weapon( "playermech_rocket_zm_mp" );
    awd_add_supported_weapon( "iw5_juggernautrocketszm_mp" );
    awd_add_supported_weapon( "playermech_rocket_swarm_zm_mp" );
    awd_add_supported_weapon( "iw5_combatknifegoliath_mp" );
    awd_add_supported_weapon( "iw5_blunderbusszm_mp" );
    level.awd_supported_weapon_keys = getarraykeys( level.awd_supported_weapons );
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

awd_get_supported_weapon_alias( weaponName )
{
    if ( !isdefined( weaponName ) || weaponName == "" )
    {
        return weaponName;
    }

    switch ( weaponName )
    {
        case "contact_grenade_throw_zombies_mp":
            return "contact_grenade_zombies_mp";

        case "explosive_drone_throw_zombie_mp":
            return "explosive_drone_zombie_mp";

        case "distraction_drone_throw_zombie_mp":
            return "distraction_drone_zombie_mp";

        case "dna_aoe_grenade_throw_zombie_mp":
            return "dna_aoe_grenade_zombie_mp";

        case "frag_grenade_throw_zombies_mp":
            return "frag_grenade_zombies_mp";

        case "teleport_throw_zombies_mp":
            return "teleport_zombies_mp";

        case "iw5_linegundamagezm_mp":
            return "iw5_linegunzm_mp";

        case "iw5_gm6zm_mp_gm6scope":
            return "iw5_gm6zm_mp";

        case "iw5_sac3zm_mp_akimbosac3":
            return "iw5_sac3zm_mp";

        case "iw5_mahemzm_mp_mahemscopebase":
            return "iw5_mahemzm_mp";

        case "iw5_blunderbusszm_mp":
            return "iw5_dlcgun4zm_mp";
    }

    return weaponName;
}

awd_get_matching_weapon_state_key( player, weaponName, baseWeaponName )
{
    if ( !isdefined( player ) || !isdefined( player.weaponstate ) )
    {
        return undefined;
    }

    candidateKeys = [];
    candidateKeySet = [];
    awd_add_candidate_weapon_key( candidateKeys, candidateKeySet, weaponName );
    awd_add_candidate_weapon_key( candidateKeys, candidateKeySet, baseWeaponName );
    awd_add_candidate_weapon_key( candidateKeys, candidateKeySet, awd_get_supported_weapon_alias( weaponName ) );
    awd_add_candidate_weapon_key( candidateKeys, candidateKeySet, awd_get_supported_weapon_alias( baseWeaponName ) );
    fallbackWeaponStateKey = undefined;

    foreach ( candidateKey in candidateKeys )
    {
        if ( isdefined( player.weaponstate[candidateKey] ) )
        {
            if ( isdefined( player.weaponstate[candidateKey]["level"] ) )
            {
                return candidateKey;
            }

            if ( !isdefined( fallbackWeaponStateKey ) )
            {
                fallbackWeaponStateKey = candidateKey;
            }
        }

        if ( isdefined( player.awd_weapon_state_keys ) &&
             isdefined( player.awd_weapon_state_keys[candidateKey] ) )
        {
            cachedWeaponStateKey = player.awd_weapon_state_keys[candidateKey];

            if ( isdefined( player.weaponstate[cachedWeaponStateKey] ) )
            {
                if ( isdefined( player.weaponstate[cachedWeaponStateKey]["level"] ) )
                {
                    return cachedWeaponStateKey;
                }

                if ( !isdefined( fallbackWeaponStateKey ) )
                {
                    fallbackWeaponStateKey = cachedWeaponStateKey;
                }
            }
        }
    }

    return fallbackWeaponStateKey;
}

awd_add_candidate_weapon_key( candidateKeys, candidateKeySet, weaponKey )
{
    if ( !isdefined( candidateKeys ) ||
         !isdefined( candidateKeySet ) ||
         !isdefined( weaponKey ) ||
         weaponKey == "" )
    {
        return;
    }

    if ( isdefined( candidateKeySet[weaponKey] ) )
    {
        return;
    }

    candidateKeySet[weaponKey] = 1;
    candidateKeys[candidateKeys.size] = weaponKey;
}

awd_cache_known_variant_links( updatedWeaponStateKeys, player, observedWeaponKey )
{
    if ( !isdefined( updatedWeaponStateKeys ) ||
         !isdefined( player ) ||
         !isdefined( player.weaponstate ) ||
         !isdefined( observedWeaponKey ) ||
         observedWeaponKey == "" )
    {
        return;
    }

    switch ( observedWeaponKey )
    {
        case "iw5_gm6zm_mp":
        case "iw5_gm6zm_mp_gm6scope":
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_gm6zm_mp", observedWeaponKey );
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_gm6zm_mp_gm6scope", observedWeaponKey );
            break;

        case "iw5_sac3zm_mp":
        case "iw5_sac3zm_mp_akimbosac3":
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_sac3zm_mp", observedWeaponKey );
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_sac3zm_mp_akimbosac3", observedWeaponKey );
            break;

        case "iw5_mahemzm_mp":
        case "iw5_mahemzm_mp_mahemscopebase":
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_mahemzm_mp", observedWeaponKey );
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_mahemzm_mp_mahemscopebase", observedWeaponKey );
            break;

        case "iw5_dlcgun4zm_mp":
        case "iw5_blunderbusszm_mp":
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_dlcgun4zm_mp", observedWeaponKey );
            awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, "iw5_blunderbusszm_mp", observedWeaponKey );
            break;
    }
}

awd_cache_linked_weapon_key( updatedWeaponStateKeys, player, linkedWeaponKey, observedWeaponKey )
{
    if ( !isdefined( updatedWeaponStateKeys ) ||
         !isdefined( player ) ||
         !isdefined( player.weaponstate ) ||
         !isdefined( linkedWeaponKey ) ||
         linkedWeaponKey == "" ||
         !isdefined( observedWeaponKey ) ||
         observedWeaponKey == "" )
    {
        return;
    }

    if ( isdefined( player.weaponstate[linkedWeaponKey] ) )
    {
        updatedWeaponStateKeys[linkedWeaponKey] = linkedWeaponKey;
        return;
    }

    updatedWeaponStateKeys[linkedWeaponKey] = observedWeaponKey;
}

awd_clear_lookup_table( tableRef )
{
    if ( !isdefined( tableRef ) )
    {
        return;
    }

    tableKeys = getarraykeys( tableRef );

    if ( !isdefined( tableKeys ) )
    {
        return;
    }

    foreach ( tableKey in tableKeys )
    {
        tableRef[tableKey] = undefined;
    }
}

awd_register_supported_weapon_callbacks()
{
    if ( !isdefined( level.modifyweapondamage ) ||
         !isdefined( level.awd_supported_weapons ) ||
         !isdefined( level.awd_supported_weapon_keys ) )
    {
        return;
    }

    supportedWeapons = level.awd_supported_weapon_keys;

    foreach ( weaponName in supportedWeapons )
    {
        if ( !isdefined( level.modifyweapondamage[weaponName] ) ||
             level.modifyweapondamage[weaponName] != ::awd_modify_damage )
        {
            level.modifyweapondamage[weaponName] = ::awd_modify_damage;
        }
    }

    awd_verify_supported_weapon_callbacks( supportedWeapons );
}

awd_verify_supported_weapon_callbacks( supportedWeapons )
{
    if ( !isdefined( level.modifyweapondamage ) || !isdefined( supportedWeapons ) )
    {
        return;
    }

    foreach ( weaponName in supportedWeapons )
    {
        if ( !isdefined( level.modifyweapondamage[weaponName] ) ||
             level.modifyweapondamage[weaponName] != ::awd_modify_damage )
        {
            println( "AllWeaponDamage: ERROR - callback registration check failed for " + weaponName );
            return;
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
        if ( !isdefined( player ) || !isplayer( player ) )
        {
            continue;
        }

        if ( !isdefined( player.weaponstate ) )
        {
            if ( !isdefined( player.awd_weaponstate_missing ) ||
                 !player.awd_weaponstate_missing )
            {
                awd_clear_lookup_table( player.awd_weapon_state_keys );
                awd_clear_lookup_table( player.awd_current_weaponstate_keys );
                player.awd_weaponstate_missing = 1;
            }

            continue;
        }

        weaponNames = getarraykeys( player.weaponstate );

        if ( !isdefined( player.awd_weapon_state_keys ) )
        {
            player.awd_weapon_state_keys = [];
        }

        if ( !isdefined( player.awd_current_weaponstate_keys ) )
        {
            player.awd_current_weaponstate_keys = [];
        }

        if ( !isdefined( weaponNames ) )
        {
            if ( !isdefined( player.awd_weaponstate_missing ) ||
                 !player.awd_weaponstate_missing )
            {
                awd_clear_lookup_table( player.awd_weapon_state_keys );
                awd_clear_lookup_table( player.awd_current_weaponstate_keys );
                player.awd_weaponstate_missing = 1;
            }

            continue;
        }

        player.awd_weaponstate_missing = 0;

        updatedWeaponStateKeys = [];
        currentWeaponStateKeys = [];

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
                baseWeaponName = weaponName;
            }

            weaponAliasName = awd_get_supported_weapon_alias( weaponName );
            supportedWeaponName = awd_get_supported_weapon_alias( baseWeaponName );

            currentWeaponStateKeys[weaponName] = 1;
            updatedWeaponStateKeys[weaponName] = weaponName;

            if ( isdefined( player.weaponstate[baseWeaponName] ) )
            {
                updatedWeaponStateKeys[baseWeaponName] = baseWeaponName;
            }

            if ( isdefined( supportedWeaponName ) &&
                 supportedWeaponName != "" &&
                 isdefined( player.weaponstate[supportedWeaponName] ) )
            {
                updatedWeaponStateKeys[supportedWeaponName] = supportedWeaponName;
            }

            if ( isdefined( weaponAliasName ) &&
                 weaponAliasName != "" &&
                 isdefined( player.weaponstate[weaponAliasName] ) )
            {
                updatedWeaponStateKeys[weaponAliasName] = weaponAliasName;
            }

            awd_cache_known_variant_links( updatedWeaponStateKeys, player, weaponName );

            awd_disable_stock_weapon_level_increase( player, weaponName );

            if ( isdefined( supportedWeaponName ) &&
                 supportedWeaponName != "" &&
                 supportedWeaponName != weaponName )
            {
                awd_disable_stock_weapon_level_increase( player, supportedWeaponName );
            }

            if ( baseWeaponName != weaponName &&
                 baseWeaponName != supportedWeaponName )
            {
                awd_disable_stock_weapon_level_increase( player, baseWeaponName );
            }

            if ( awd_is_supported_weapon( weaponName ) &&
                 ( !isdefined( level.modifyweapondamage[weaponName] ) ||
                   level.modifyweapondamage[weaponName] != ::awd_modify_damage ) )
            {
                level.modifyweapondamage[weaponName] = ::awd_modify_damage;
            }

            if ( awd_is_supported_weapon( baseWeaponName ) &&
                 baseWeaponName != weaponName &&
                 ( !isdefined( level.modifyweapondamage[baseWeaponName] ) ||
                   level.modifyweapondamage[baseWeaponName] != ::awd_modify_damage ) )
            {
                level.modifyweapondamage[baseWeaponName] = ::awd_modify_damage;
            }

            if ( awd_is_supported_weapon( supportedWeaponName ) &&
                 isdefined( supportedWeaponName ) &&
                 supportedWeaponName != "" &&
                 supportedWeaponName != weaponName &&
                 supportedWeaponName != baseWeaponName &&
                 ( !isdefined( level.modifyweapondamage[supportedWeaponName] ) ||
                  level.modifyweapondamage[supportedWeaponName] != ::awd_modify_damage ) )
            {
                level.modifyweapondamage[supportedWeaponName] = ::awd_modify_damage;
            }
        }

        player.awd_weapon_state_keys = updatedWeaponStateKeys;
        player.awd_current_weaponstate_keys = currentWeaponStateKeys;
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

    baseWeaponName = getweaponbasename( weapon );

    awd_debug_weapon_name( weapon, baseWeaponName );

    if ( !isdefined( baseWeaponName ) || baseWeaponName == "" )
    {
        baseWeaponName = weapon;
    }

    weaponAliasName = awd_get_supported_weapon_alias( weapon );
    supportedWeaponAlias = awd_get_supported_weapon_alias( baseWeaponName );

    if ( !awd_is_supported_weapon( weapon ) &&
         !awd_is_supported_weapon( weaponAliasName ) &&
         !awd_is_supported_weapon( baseWeaponName ) &&
         !awd_is_supported_weapon( supportedWeaponAlias ) )
    {
        return damage;
    }

    weaponLevel = undefined;
    matchingWeaponStateKey = awd_get_matching_weapon_state_key( attacker, weapon, baseWeaponName );
    exactWeaponStateDefined = isdefined( matchingWeaponStateKey ) &&
                             isdefined( attacker.weaponstate[matchingWeaponStateKey] );
    exactWeaponLevelDefined = false;

    if ( exactWeaponStateDefined &&
         isdefined( attacker.weaponstate[matchingWeaponStateKey]["level"] ) )
    {
        weaponLevel = attacker.weaponstate[matchingWeaponStateKey]["level"];
        exactWeaponLevelDefined = true;
    }

    awd_disable_stock_weapon_level_increase( attacker, weapon );

    if ( baseWeaponName != weapon )
    {
        awd_disable_stock_weapon_level_increase( attacker, baseWeaponName );
    }

    if ( isdefined( matchingWeaponStateKey ) &&
         matchingWeaponStateKey != weapon &&
         matchingWeaponStateKey != baseWeaponName )
    {
        awd_disable_stock_weapon_level_increase( attacker, matchingWeaponStateKey );
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

    if ( !exactWeaponLevelDefined &&
         !isdefined( weaponLevel ) &&
         isdefined( supportedWeaponAlias ) &&
         supportedWeaponAlias != "" &&
         supportedWeaponAlias != baseWeaponName &&
         isdefined( attacker.weaponstate[supportedWeaponAlias] ) &&
         isdefined( attacker.weaponstate[supportedWeaponAlias]["level"] ) )
    {
        awd_disable_stock_weapon_level_increase( attacker, supportedWeaponAlias );
        weaponLevel = attacker.weaponstate[supportedWeaponAlias]["level"];
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

    return baseDamage + ( baseDamage * AWD_CAUTERIZER_LEVEL_MULTIPLIER * ( mark - 1 ) );
}

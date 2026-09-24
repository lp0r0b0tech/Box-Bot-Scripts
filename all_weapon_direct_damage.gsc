/*
    All Exo Zombies weapons — direct Mk2-Mk25 damage modifier
    Advanced Warfare Exo Zombies / S1x / CBServers

    Standard weapons:
        Mk1  = native damage
        Mk2  = 1000 damage
        Mk25 = 5000 damage

    Max-damage weapons:
        Grenades, equipment, rockets, turrets, and killstreak weapons
        always use their configured Mk25 damage.

    Hit-location multipliers:
        Head / helmet = x4
        Neck          = x5
        Other         = x1

    Native hook:
        level.modifyweapondamage[weaponName]

    Debug:
        set awd_debug_damage 1
*/


#define AWD_MIN_CUSTOM_MARK       2
#define AWD_MAX_CUSTOM_MARK       25

#define AWD_DEFAULT_MK2_DAMAGE    1000
#define AWD_DEFAULT_MK25_DAMAGE   5000

#define AWD_HOOK_WAIT_SECONDS     30
#define AWD_MONITOR_INTERVAL      1.0


/*
    Both entry points are provided for loader compatibility.
*/
main()
{
    awd_init();
}


init()
{
    awd_init();
}


awd_init()
{
    if ( isdefined( level.awd_started ) )
    {
        return;
    }

    level.awd_started = 1;

    if ( !isdefined( level.awd_debug_damage ) )
    {
        level.awd_debug_damage = 0;
    }

    level.awd_debugged_damage = [];

    awd_init_weapon_list();
    awd_init_max_damage_weapons();
    awd_init_weapon_damage();

    println( "AllWeaponDamage: script initialized." );

    level thread awd_wait_for_damage_table();
}


/*
    Wait for the Exo Zombies gametype to create the native
    weapon-specific damage callback table.
*/
awd_wait_for_damage_table()
{
    level endon( "game_ended" );

    waitCount = 0;
    maxWaitCount =
        int( AWD_HOOK_WAIT_SECONDS / 0.05 );

    while ( !isdefined( level.modifyweapondamage ) &&
            waitCount < maxWaitCount )
    {
        waitCount++;
        wait 0.05;
    }

    if ( !isdefined( level.modifyweapondamage ) )
    {
        println(
            "AllWeaponDamage: ERROR - " +
            "level.modifyweapondamage was never initialized."
        );

        return;
    }

    awd_register_all_weapons();

    level thread awd_monitor_hooks();
}


/*
    Re-register callbacks if another script replaces them.
*/
awd_monitor_hooks()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        wait AWD_MONITOR_INTERVAL;

        if ( !isdefined( level.modifyweapondamage ) )
        {
            continue;
        }

        awd_register_all_weapons();
    }
}


/*
    Standard Exo Zombies weapons.

    These use direct damage from Mk2 through Mk25.
    Mk1 continues using native damage.
*/
awd_init_weapon_list()
{
    level.awd_weapon_list = [];

    awd_add_weapon( "iw5_rw1zm_mp" );
    awd_add_weapon( "iw5_vbrzm_mp" );
    awd_add_weapon( "iw5_gm6zm_mp" );
    awd_add_weapon( "iw5_gm6zm_mp_gm6scope" );

    awd_add_weapon( "iw5_rhinozm_mp" );
    awd_add_weapon( "iw5_lsatzm_mp" );
    awd_add_weapon( "iw5_asawzm_mp" );

    awd_add_weapon( "iw5_ak12zm_mp" );
    awd_add_weapon( "iw5_bal27zm_mp" );
    awd_add_weapon( "iw5_himarzm_mp" );
    awd_add_weapon( "iw5_arx160zm_mp" );
    awd_add_weapon( "iw5_hbra3zm_mp" );
    awd_add_weapon( "iw5_m182sprzm_mp" );

    awd_add_weapon( "iw5_mp11zm_mp" );
    awd_add_weapon( "iw5_asm1zm_mp" );
    awd_add_weapon( "iw5_sn6zm_mp" );
    awd_add_weapon( "iw5_sac3zm_mp" );
    awd_add_weapon( "iw5_sac3zm_mp_akimbosac3" );
    awd_add_weapon( "iw5_hmr9zm_mp" );

    awd_add_weapon( "iw5_maulzm_mp" );
    awd_add_weapon( "iw5_uts19zm_mp" );

    awd_add_weapon( "iw5_em1zm_mp" );

    awd_add_weapon( "iw5_titan45zm_mp" );

    awd_add_weapon( "iw5_exocrossbowzm_mp" );
    awd_add_weapon( "iw5_mahemzm_mp" );
    awd_add_weapon( "iw5_mahemzm_mp_mahemscopebase" );

    awd_add_weapon( "iw5_fusionzm_mp" );
    awd_add_weapon( "iw5_microwavezm_mp" );
    awd_add_weapon( "iw5_linegunzm_mp" );
    awd_add_weapon( "iw5_linegundamagezm_mp" );
    awd_add_weapon( "iw5_tridentzm_mp" );

    awd_add_weapon( "iw5_dlcgun1zm_mp" );
    awd_add_weapon( "iw5_dlcgun2zm_mp" );
    awd_add_weapon( "iw5_dlcgun3zm_mp" );
    awd_add_weapon( "iw5_dlcgun4zm_mp" );

    awd_add_weapon( "iw5_exominigunzm_mp" );
    awd_add_weapon( "iw5_blunderbusszm_mp" );

    awd_add_weapon( "iw5_combatknifegoliath_mp" );
    awd_add_weapon( "LastStand" );
}


/*
    Grenades, equipment, rockets, turrets, and killstreak weapons.

    These always use Mk25 damage, even if they do not have a
    normal player weaponstate entry.
*/
awd_init_max_damage_weapons()
{
    level.awd_max_damage_weapons = [];

    /*
        Melee weapon forced to Mk25 damage.
    */
    awd_add_max_damage_weapon(
        "exo_melee_zm"
    );

    awd_add_max_damage_weapon(
        "iw5_combatknifegoliath_mp"
    );

    /*
        Grenades and equipment
    */
    awd_add_max_damage_weapon(
        "frag_grenade_zombies_mp"
    );

    awd_add_max_damage_weapon(
        "frag_grenade_throw_zombies_mp"
    );

    awd_add_max_damage_weapon(
        "contact_grenade_zombies_mp"
    );

    awd_add_max_damage_weapon(
        "contact_grenade_throw_zombies_mp"
    );

    awd_add_max_damage_weapon(
        "explosive_drone_zombie_mp"
    );

    awd_add_max_damage_weapon(
        "explosive_drone_throw_zombie_mp"
    );

    awd_add_max_damage_weapon(
        "distraction_drone_zombie_mp"
    );

    awd_add_max_damage_weapon(
        "distraction_drone_throw_zombie_mp"
    );

    awd_add_max_damage_weapon(
        "dna_aoe_grenade_zombie_mp"
    );

    awd_add_max_damage_weapon(
        "dna_aoe_grenade_throw_zombie_mp"
    );

    awd_add_max_damage_weapon(
        "teleport_zombies_mp"
    );

    awd_add_max_damage_weapon(
        "teleport_throw_zombies_mp"
    );

    awd_add_max_damage_weapon(
        "repulsor_zombie_mp"
    );

    /*
        Killstreaks and killstreak projectiles
    */
    awd_add_max_damage_weapon(
        "killstreakmahem_mp"
    );

    awd_add_max_damage_weapon(
        "remote_energy_turret_mp"
    );

    awd_add_max_damage_weapon(
        "drone_assault_remote_turret_mp"
    );

    awd_add_max_damage_weapon(
        "ugv_missile_mp"
    );

    awd_add_max_damage_weapon(
        "sentry_minigun_mp"
    );

    awd_add_max_damage_weapon(
        "turretheadmg_mp"
    );

    awd_add_max_damage_weapon(
        "turretheadrocket_mp"
    );

    awd_add_max_damage_weapon(
        "turretheadenergy_mp"
    );

    awd_add_max_damage_weapon(
        "playermech_rocket_zm_mp"
    );

    awd_add_max_damage_weapon(
        "iw5_juggernautrocketszm_mp"
    );

    awd_add_max_damage_weapon(
        "playermech_rocket_swarm_zm_mp"
    );

    /*
        Special weapons forced to direct Mk25 behavior.
    */
    awd_add_max_damage_weapon(
        "iw5_linegunzm_mp"
    );

    awd_add_max_damage_weapon(
        "iw5_linegundamagezm_mp"
    );

    awd_add_max_damage_weapon(
        "iw5_tridentzm_mp"
    );

    awd_add_max_damage_weapon(
        "iw5_microwavezm_mp"
    );
}


awd_add_weapon( weaponName )
{
    if ( !isdefined( weaponName ) ||
         weaponName == "" )
    {
        return;
    }

    level.awd_weapon_list[
        level.awd_weapon_list.size
    ] = weaponName;
}


awd_add_max_damage_weapon( weaponName )
{
    if ( !isdefined( weaponName ) ||
         weaponName == "" )
    {
        return;
    }

    level.awd_max_damage_weapons[weaponName] = 1;
}


awd_is_max_damage_weapon( weaponName )
{
    return isdefined( weaponName ) &&
           isdefined( level.awd_max_damage_weapons ) &&
           isdefined(
               level.awd_max_damage_weapons[weaponName]
           );
}


/*
    Configure default direct-damage ranges.

    Every normal weapon defaults to:

        Mk2  = 1000
        Mk25 = 5000

    You can override individual weapons here.
*/
awd_init_weapon_damage()
{
    level.awd_weapon_damage = [];

    foreach ( weaponName in level.awd_weapon_list )
    {
        level.awd_weapon_damage[weaponName] = [];

        level.awd_weapon_damage[weaponName]["mk2"] =
            AWD_DEFAULT_MK2_DAMAGE;

        level.awd_weapon_damage[weaponName]["mk25"] =
            AWD_DEFAULT_MK25_DAMAGE;
    }

    /*
        Max-damage weapons also receive a damage configuration.
    */
    maxWeapons =
        getArrayKeys(
            level.awd_max_damage_weapons
        );

    foreach ( weaponName in maxWeapons )
    {
        if ( !isdefined(
                level.awd_weapon_damage[weaponName]
            ) )
        {
            level.awd_weapon_damage[weaponName] = [];

            level.awd_weapon_damage[weaponName]["mk2"] =
                AWD_DEFAULT_MK2_DAMAGE;

            level.awd_weapon_damage[weaponName]["mk25"] =
                AWD_DEFAULT_MK25_DAMAGE;
        }
    }

    /*
        Optional per-weapon overrides.

        Uncomment and edit these if certain weapons need
        different Mk2/Mk25 values.
    */

    /*
    level.awd_weapon_damage["iw5_titan45zm_mp"]["mk2"] = 1000;
    level.awd_weapon_damage["iw5_titan45zm_mp"]["mk25"] = 5000;

    level.awd_weapon_damage["iw5_gm6zm_mp"]["mk2"] = 1500;
    level.awd_weapon_damage["iw5_gm6zm_mp"]["mk25"] = 7500;

    level.awd_weapon_damage["iw5_linegunzm_mp"]["mk2"] = 2000;
    level.awd_weapon_damage["iw5_linegunzm_mp"]["mk25"] = 10000;

    level.awd_weapon_damage["iw5_tridentzm_mp"]["mk2"] = 2000;
    level.awd_weapon_damage["iw5_tridentzm_mp"]["mk25"] = 10000;
    */
}


/*
    Register the direct-damage callback for all normal and
    max-damage weapon names.
*/
awd_register_all_weapons()
{
    foreach ( weaponName in level.awd_weapon_list )
    {
        level.modifyweapondamage[weaponName] =
            ::awd_modify_damage;
    }

    maxWeapons =
        getArrayKeys(
            level.awd_max_damage_weapons
        );

    foreach ( weaponName in maxWeapons )
    {
        level.modifyweapondamage[weaponName] =
            ::awd_modify_damage;
    }

    println(
        "AllWeaponDamage: registered weapon callbacks."
    );
}


/*
    Generic Exo Zombies weapon-damage callback.

    For normal weapons:
        Mk1  = native damage
        Mk2-Mk25 = direct configured damage

    For max-damage weapons:
        always use configured Mk25 damage
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
    if ( !isdefined( attacker ) ||
         !isplayer( attacker ) )
    {
        return damage;
    }

    if ( !isdefined( weapon ) ||
         weapon == "" )
    {
        return damage;
    }

    weaponName =
        getweaponbasename( weapon );

    if ( !isdefined( weaponName ) ||
         weaponName == "" )
    {
        weaponName = weapon;
    }

    weaponName =
        awd_get_damage_weapon_name(
            weaponName
        );

    /*
        Killstreaks, grenades, equipment, and listed special
        weapons always receive Mk25 damage.
    */
    if ( awd_is_max_damage_weapon( weaponName ) )
    {
        awd_disable_stock_multiplier(
            attacker,
            weaponName
        );

        baseDamage =
            awd_get_mk25_damage(
                weaponName
            );

        finalDamage =
            awd_apply_hit_location_multiplier(
                baseDamage,
                hitLocation
            );

        awd_debug_damage(
            weaponName,
            AWD_MAX_CUSTOM_MARK,
            hitLocation,
            damage,
            baseDamage,
            finalDamage
        );

        return int( finalDamage );
    }

    /*
        If this weapon is not configured, preserve native damage.
    */
    if ( !isdefined(
            level.awd_weapon_damage[weaponName]
        ) )
    {
        return damage;
    }

    weaponLevel =
        maps\mp\zombies\_util::getzombieweaponlevel(
            attacker,
            weaponName
        );

    /*
        Mk1 remains native.
    */
    if ( !isdefined( weaponLevel ) ||
         weaponLevel < AWD_MIN_CUSTOM_MARK )
    {
        return damage;
    }

    if ( weaponLevel > AWD_MAX_CUSTOM_MARK )
    {
        weaponLevel = AWD_MAX_CUSTOM_MARK;
    }

    awd_disable_stock_multiplier(
        attacker,
        weaponName
    );

    baseDamage =
        awd_get_base_damage(
            weaponName,
            weaponLevel
        );

    finalDamage =
        awd_apply_hit_location_multiplier(
            baseDamage,
            hitLocation
        );

    awd_debug_damage(
        weaponName,
        weaponLevel,
        hitLocation,
        damage,
        baseDamage,
        finalDamage
    );

    return int( finalDamage );
}


/*
    Map alternate/projectile names to the weapon-state key.
*/
awd_get_damage_weapon_name( weaponName )
{
    if ( isdefined(
            level.awd_weapon_damage[weaponName]
        ) )
    {
        return weaponName;
    }

    switch ( weaponName )
    {
        case "iw5_gm6zm_mp_gm6scope":
            return "iw5_gm6zm_mp";

        case "iw5_sac3zm_mp_akimbosac3":
            return "iw5_sac3zm_mp";

        case "iw5_mahemzm_mp_mahemscopebase":
            return "iw5_mahemzm_mp";

        case "iw5_linegundamagezm_mp":
            return "iw5_linegunzm_mp";

        case "frag_grenade_throw_zombies_mp":
            return "frag_grenade_zombies_mp";

        case "contact_grenade_throw_zombies_mp":
            return "contact_grenade_zombies_mp";

        case "explosive_drone_throw_zombie_mp":
            return "explosive_drone_zombie_mp";

        case "distraction_drone_throw_zombie_mp":
            return "distraction_drone_zombie_mp";

        case "dna_aoe_grenade_throw_zombie_mp":
            return "dna_aoe_grenade_zombie_mp";

        case "teleport_throw_zombies_mp":
            return "teleport_zombies_mp";
    }

    return weaponName;
}


/*
    Disable native weapon-level scaling.

    Without this, normal weapons could receive the direct custom
    damage and then receive the native weapon-level multiplier again.
*/
awd_disable_stock_multiplier(
    attacker,
    weaponName
)
{
    if ( !isdefined( attacker ) ||
         !isdefined( attacker.weaponstate ) ||
         !isdefined( weaponName ) )
    {
        return;
    }

    if ( !isdefined(
            attacker.weaponstate[weaponName]
        ) )
    {
        return;
    }

    attacker.weaponstate[weaponName][
        "weapon_level_increase"
    ] = 0;
}


/*
    Return the configured Mk25 value.

    Grenades and killstreaks use this value regardless of their
    weapon-state level.
*/
awd_get_mk25_damage( weaponName )
{
    if ( isdefined(
            level.awd_weapon_damage[weaponName]
        ) &&
        isdefined(
            level.awd_weapon_damage[weaponName]["mk25"]
        ) )
    {
        return level.awd_weapon_damage[weaponName]["mk25"];
    }

    return AWD_DEFAULT_MK25_DAMAGE;
}


/*
    Linear interpolation:

        Mk2  = configured Mk2 damage
        Mk25 = configured Mk25 damage

    Default:

        Mk2  = 1000
        Mk25 = 5000

    Formula:

        Mk2 + ((mark - 2) * (Mk25 - Mk2) / 23)
*/
awd_get_base_damage(
    weaponName,
    mark
)
{
    if ( mark < AWD_MIN_CUSTOM_MARK )
    {
        mark = AWD_MIN_CUSTOM_MARK;
    }

    if ( mark > AWD_MAX_CUSTOM_MARK )
    {
        mark = AWD_MAX_CUSTOM_MARK;
    }

    mk2Damage =
        level.awd_weapon_damage[weaponName]["mk2"];

    mk25Damage =
        level.awd_weapon_damage[weaponName]["mk25"];

    markRange =
        AWD_MAX_CUSTOM_MARK -
        AWD_MIN_CUSTOM_MARK;

    damageRange =
        mk25Damage -
        mk2Damage;

    return mk2Damage +
        int(
            (
                (
                    ( mark - AWD_MIN_CUSTOM_MARK ) *
                    damageRange
                ) +
                int( markRange / 2 )
            ) /
            markRange
        );
}


awd_apply_hit_location_multiplier(
    baseDamage,
    hitLocation
)
{
    if ( !isdefined( hitLocation ) )
    {
        return baseDamage;
    }

    if ( hitLocation == "head" ||
         hitLocation == "helmet" )
    {
        return baseDamage * 4;
    }

    if ( hitLocation == "neck" )
    {
        return baseDamage * 5;
    }

    return baseDamage;
}


/*
    Diagnostic logging.
*/
awd_debug_damage(
    weaponName,
    weaponLevel,
    hitLocation,
    incomingDamage,
    baseDamage,
    finalDamage
)
{
    if ( !isdefined( level.awd_debug_damage ) ||
         !level.awd_debug_damage )
    {
        return;
    }

    hitLabel = "none";

    if ( isdefined( hitLocation ) &&
         hitLocation != "" )
    {
        hitLabel = hitLocation;
    }

    if ( !isdefined(
            level.awd_debugged_damage
        ) )
    {
        level.awd_debugged_damage = [];
    }

    debugKey =
        weaponName +
        "|" +
        weaponLevel +
        "|" +
        hitLabel +
        "|" +
        finalDamage;

    if ( isdefined(
            level.awd_debugged_damage[debugKey]
        ) )
    {
        return;
    }

    level.awd_debugged_damage[debugKey] = 1;

    println(
        "AllWeaponDamage: weapon=" +
        weaponName +
        ", mark=" +
        weaponLevel +
        ", hit=" +
        hitLabel +
        ", incoming=" +
        incomingDamage +
        ", base=" +
        baseDamage +
        ", final=" +
        finalDamage
    );
}
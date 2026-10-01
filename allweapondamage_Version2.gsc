/*
    All Exo Zombies weapons — direct Mk2-Mk25 damage modifier
    Advanced Warfare Exo Zombies / S1x / CBServers

    Tuned for a 30,000 zombie health cap (e.g. BO2 round scaling):
        Mk1  = native damage
        Mk2  = 1,200 base damage
        Mk10 = 6,000 base damage
        Mk20 = 12,000 base damage
        Mk25 = 15,000 base damage

    Progression:
        Smooth linear +600 damage increase per mark from Mk2 through Mk25.
        At Mk20-Mk25, headshots (x4) deal 48,000-60,000 damage (guaranteed 1-shot kill)
        and body shots (x1) deal 12,000-15,000 damage (2-3 shots to kill capped zombies).

    Melee weapons:
        Exo suit melee ("exo_melee_zm"), Goliath combat knife ("iw5_combatknifegoliath_mp"),
        and any MOD_MELEE hit made while holding a registered weapon
        are guaranteed 1-hit kills on standard zombies, but deal configured Mk25 damage on bosses.

        The native Exo Zombies damage callback replaces all MOD_MELEE damage with
        level.playermeleedamage / level.playerexomeleedamage AFTER the
        level.modifyweapondamage callbacks run, so the computed melee damage is
        passed through those values for the current hit and restored at frame end.

    Max-damage weapons:
        Grenades, equipment, rockets, turrets, and killstreak weapons
        always use their configured Mk25 damage (15,000 base).

    Hit-location multipliers (configurable):
        Head / helmet = x4 (AWD_HEAD_MULTIPLIER)
        Neck          = x5 (AWD_NECK_MULTIPLIER)
        Other (body)  = x1 (AWD_BODY_MULTIPLIER)

    Native hook:
        level.modifyweapondamage[weaponName]

    Debug:
        set awd_debug_damage 1
*/


#define AWD_MIN_CUSTOM_MARK       2
#define AWD_MAX_CUSTOM_MARK       25

#define AWD_DEFAULT_MK2_DAMAGE    1200
#define AWD_DEFAULT_MK3_DAMAGE    1800
#define AWD_DEFAULT_MK4_DAMAGE    2400
#define AWD_DEFAULT_MK5_DAMAGE    3000
#define AWD_DEFAULT_MK6_DAMAGE    3600
#define AWD_DEFAULT_MK7_DAMAGE    4200
#define AWD_DEFAULT_MK8_DAMAGE    4800
#define AWD_DEFAULT_MK9_DAMAGE    5400
#define AWD_DEFAULT_MK10_DAMAGE   6000
#define AWD_DEFAULT_MK11_DAMAGE   6600
#define AWD_DEFAULT_MK12_DAMAGE   7200
#define AWD_DEFAULT_MK13_DAMAGE   7800
#define AWD_DEFAULT_MK14_DAMAGE   8400
#define AWD_DEFAULT_MK15_DAMAGE   9000
#define AWD_DEFAULT_MK16_DAMAGE   9600
#define AWD_DEFAULT_MK17_DAMAGE  10200
#define AWD_DEFAULT_MK18_DAMAGE  10800
#define AWD_DEFAULT_MK19_DAMAGE  11400
#define AWD_DEFAULT_MK20_DAMAGE  12000
#define AWD_DEFAULT_MK21_DAMAGE  12600
#define AWD_DEFAULT_MK22_DAMAGE  13200
#define AWD_DEFAULT_MK23_DAMAGE  13800
#define AWD_DEFAULT_MK24_DAMAGE  14400
#define AWD_DEFAULT_MK25_DAMAGE  15000
#define AWD_ONE_HIT_MELEE_DAMAGE 250000

#define AWD_NATIVE_MELEE_DAMAGE      150
#define AWD_NATIVE_EXO_MELEE_DAMAGE  500

#define AWD_HEAD_MULTIPLIER       4
#define AWD_NECK_MULTIPLIER       5
#define AWD_BODY_MULTIPLIER       1

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

    awd_capture_native_melee_damage();

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
    Check whether a hit is a melee hit.

    In Exo Zombies, player melee (including exo melee) is reported as
    MOD_MELEE with the currently held weapon, not as "exo_melee_zm",
    so the means of death must be checked as well as the weapon name.
*/
awd_is_one_hit_melee( weaponName, weapon, meansOfDeath )
{
    if ( isdefined( meansOfDeath ) &&
         meansOfDeath == "MOD_MELEE" )
    {
        return true;
    }

    if ( isdefined( weaponName ) )
    {
        if ( weaponName == "exo_melee_zm" ||
             weaponName == "iw5_combatknifegoliath_mp" ||
             issubstr( weaponName, "exo_melee" ) ||
             issubstr( weaponName, "combatknifegoliath" ) )
        {
            return true;
        }
    }

    if ( isdefined( weapon ) )
    {
        if ( weapon == "exo_melee_zm" ||
             weapon == "iw5_combatknifegoliath_mp" ||
             issubstr( weapon, "exo_melee" ) ||
             issubstr( weapon, "combatknifegoliath" ) )
        {
            return true;
        }
    }

    return false;
}


/*
    Save the native melee damage values so they can be restored
    after a buffed melee hit.
*/
awd_capture_native_melee_damage()
{
    if ( isdefined( level.awd_native_melee_saved ) )
    {
        return;
    }

    level.awd_native_melee_saved = 1;

    level.awd_native_player_melee_damage =
        AWD_NATIVE_MELEE_DAMAGE;

    level.awd_native_player_exo_melee_damage =
        AWD_NATIVE_EXO_MELEE_DAMAGE;

    if ( isdefined( level.playermeleedamage ) )
    {
        level.awd_native_player_melee_damage =
            level.playermeleedamage;
    }

    if ( isdefined( level.playerexomeleedamage ) )
    {
        level.awd_native_player_exo_melee_damage =
            level.playerexomeleedamage;
    }
}


/*
    The native damage callback runs level.modifyweapondamage first and
    then overwrites every MOD_MELEE hit with level.playermeleedamage or
    level.playerexomeleedamage. Feed the computed damage through those
    values for this hit, then restore the native values at frame end.
*/
awd_set_melee_damage_override( finalDamage )
{
    awd_capture_native_melee_damage();

    level.playermeleedamage = finalDamage;
    level.playerexomeleedamage = finalDamage;

    level thread awd_restore_melee_damage();
}


awd_restore_melee_damage()
{
    level notify( "awd_restore_melee_damage" );
    level endon( "awd_restore_melee_damage" );

    waittillframeend;

    level.playermeleedamage =
        level.awd_native_player_melee_damage;

    level.playerexomeleedamage =
        level.awd_native_player_exo_melee_damage;
}


/*
    Check whether a damage victim is a boss enemy
    (e.g., Goliath mech zombie, Oz boss, or other special boss agent).
*/
awd_is_boss( victim )
{
    if ( !isdefined( victim ) )
    {
        return false;
    }

    if ( !isplayer( victim ) &&
         victim maps\mp\zombies\_util::instakillimmune() )
    {
        return true;
    }

    if ( isdefined( victim.is_boss ) && victim.is_boss )
    {
        return true;
    }

    if ( isdefined( victim.boss ) && victim.boss )
    {
        return true;
    }

    if ( isdefined( victim.isboss ) && victim.isboss )
    {
        return true;
    }

    if ( isdefined( victim.entity_type ) )
    {
        if ( victim.entity_type == "boss" ||
             issubstr( tolower( victim.entity_type ), "boss" ) )
        {
            return true;
        }
    }

    if ( isdefined( victim.agent_type ) )
    {
        agentType = tolower( victim.agent_type );

        if ( issubstr( agentType, "boss" ) ||
             issubstr( agentType, "goliath" ) ||
             issubstr( agentType, "mech" ) ||
             issubstr( agentType, "oz" ) )
        {
            return true;
        }
    }

    if ( isdefined( victim.zombie_type ) )
    {
        zombieType = tolower( victim.zombie_type );

        if ( issubstr( zombieType, "boss" ) ||
             issubstr( zombieType, "goliath" ) ||
             issubstr( zombieType, "mech" ) ||
             issubstr( zombieType, "oz" ) )
        {
            return true;
        }
    }

    if ( isdefined( victim.sub_type ) )
    {
        subType = tolower( victim.sub_type );

        if ( issubstr( subType, "boss" ) ||
             issubstr( subType, "goliath" ) ||
             issubstr( subType, "mech" ) )
        {
            return true;
        }
    }

    if ( isdefined( victim.animname ) )
    {
        animName = tolower( victim.animname );

        if ( issubstr( animName, "boss" ) ||
             issubstr( animName, "goliath" ) ||
             issubstr( animName, "mech" ) ||
             issubstr( animName, "oz" ) )
        {
            return true;
        }
    }

    if ( isdefined( victim.classname ) )
    {
        className = tolower( victim.classname );

        if ( className == "boss" ||
             className == "boss_zombie" ||
             className == "special_zombie" ||
             issubstr( className, "boss" ) )
        {
            return true;
        }
    }

    if ( isdefined( victim.model ) )
    {
        modelName = tolower( victim.model );

        if ( issubstr( modelName, "goliath" ) ||
             issubstr( modelName, "zombie_boss" ) )
        {
            return true;
        }
    }

    return false;
}


/*
    Configure default direct-damage ranges.

    Standard weapons scale across Mk2 (1,200) to Mk25 (15,000).
    You can override individual weapons here.
*/
awd_init_weapon_damage()
{
    level.awd_default_mark_damage = [];
    level.awd_default_mark_damage[2]  = AWD_DEFAULT_MK2_DAMAGE;
    level.awd_default_mark_damage[3]  = AWD_DEFAULT_MK3_DAMAGE;
    level.awd_default_mark_damage[4]  = AWD_DEFAULT_MK4_DAMAGE;
    level.awd_default_mark_damage[5]  = AWD_DEFAULT_MK5_DAMAGE;
    level.awd_default_mark_damage[6]  = AWD_DEFAULT_MK6_DAMAGE;
    level.awd_default_mark_damage[7]  = AWD_DEFAULT_MK7_DAMAGE;
    level.awd_default_mark_damage[8]  = AWD_DEFAULT_MK8_DAMAGE;
    level.awd_default_mark_damage[9]  = AWD_DEFAULT_MK9_DAMAGE;
    level.awd_default_mark_damage[10] = AWD_DEFAULT_MK10_DAMAGE;
    level.awd_default_mark_damage[11] = AWD_DEFAULT_MK11_DAMAGE;
    level.awd_default_mark_damage[12] = AWD_DEFAULT_MK12_DAMAGE;
    level.awd_default_mark_damage[13] = AWD_DEFAULT_MK13_DAMAGE;
    level.awd_default_mark_damage[14] = AWD_DEFAULT_MK14_DAMAGE;
    level.awd_default_mark_damage[15] = AWD_DEFAULT_MK15_DAMAGE;
    level.awd_default_mark_damage[16] = AWD_DEFAULT_MK16_DAMAGE;
    level.awd_default_mark_damage[17] = AWD_DEFAULT_MK17_DAMAGE;
    level.awd_default_mark_damage[18] = AWD_DEFAULT_MK18_DAMAGE;
    level.awd_default_mark_damage[19] = AWD_DEFAULT_MK19_DAMAGE;
    level.awd_default_mark_damage[20] = AWD_DEFAULT_MK20_DAMAGE;
    level.awd_default_mark_damage[21] = AWD_DEFAULT_MK21_DAMAGE;
    level.awd_default_mark_damage[22] = AWD_DEFAULT_MK22_DAMAGE;
    level.awd_default_mark_damage[23] = AWD_DEFAULT_MK23_DAMAGE;
    level.awd_default_mark_damage[24] = AWD_DEFAULT_MK24_DAMAGE;
    level.awd_default_mark_damage[25] = AWD_DEFAULT_MK25_DAMAGE;

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
    level.awd_weapon_damage["iw5_titan45zm_mp"]["mk2"] = 1200;
    level.awd_weapon_damage["iw5_titan45zm_mp"]["mk25"] = 15000;

    level.awd_weapon_damage["iw5_gm6zm_mp"]["mk2"] = 2400;
    level.awd_weapon_damage["iw5_gm6zm_mp"]["mk25"] = 20000;

    level.awd_weapon_damage["iw5_linegunzm_mp"]["mk2"] = 3000;
    level.awd_weapon_damage["iw5_linegunzm_mp"]["mk25"] = 25000;

    level.awd_weapon_damage["iw5_tridentzm_mp"]["mk2"] = 3000;
    level.awd_weapon_damage["iw5_tridentzm_mp"]["mk25"] = 25000;
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
        Melee (MOD_MELEE with any registered weapon), Exo suit melee,
        and Goliath combat knife:
        Guaranteed 1-hit kill on standard zombies, but not on bosses.
        Bosses receive configured Mk25 damage instead.
    */
    if ( awd_is_one_hit_melee( weaponName, weapon, meansOfDeath ) )
    {
        awd_disable_stock_multiplier(
            attacker,
            weaponName
        );

        if ( !awd_is_boss( victim ) )
        {
            finalDamage = AWD_ONE_HIT_MELEE_DAMAGE;

            if ( isdefined( victim ) )
            {
                if ( isdefined( victim.health ) && victim.health > 0 )
                {
                    finalDamage = victim.health + 10000;
                }
                else if ( isdefined( victim.maxhealth ) && victim.maxhealth > 0 )
                {
                    finalDamage = victim.maxhealth + 10000;
                }

                if ( finalDamage < AWD_ONE_HIT_MELEE_DAMAGE )
                {
                    finalDamage = AWD_ONE_HIT_MELEE_DAMAGE;
                }
            }

            finalDamage = int( finalDamage );
        }
        else
        {
            /*
                Target is a boss: do not 1-hit kill. Use configured Mk25 damage.
            */
            baseDamage =
                awd_get_mk25_damage(
                    weaponName
                );

            finalDamage =
                int(
                    awd_apply_hit_location_multiplier(
                        baseDamage,
                        hitLocation
                    )
                );
        }

        if ( isdefined( meansOfDeath ) &&
             meansOfDeath == "MOD_MELEE" )
        {
            awd_set_melee_damage_override(
                finalDamage
            );
        }

        awd_debug_damage(
            "melee:" + weaponName,
            AWD_MAX_CUSTOM_MARK,
            hitLocation,
            damage,
            finalDamage,
            finalDamage
        );

        return finalDamage;
    }

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
    Upgrade damage calculation:

        Mk2  = configured Mk2 damage (default 1200)
        Mk20 = configured Mk20 damage (default 12000)
        Mk25 = configured Mk25 damage (default 15000)

    Standard weapons use the defined mark table (AWD_DEFAULT_MK#_DAMAGE).
    Weapons with custom overrides interpolate between their mk2 and mk25 values.
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

    /*
        Per-weapon mark override.
    */
    if ( isdefined( level.awd_weapon_damage ) &&
         isdefined( level.awd_weapon_damage[weaponName] ) &&
         isdefined( level.awd_weapon_damage[weaponName][mark] ) )
    {
        return level.awd_weapon_damage[weaponName][mark];
    }

    /*
        If custom per-weapon mk2 and mk25 overrides were set.
    */
    if ( isdefined( level.awd_weapon_damage ) &&
         isdefined( level.awd_weapon_damage[weaponName] ) &&
         isdefined( level.awd_weapon_damage[weaponName]["mk2"] ) &&
         isdefined( level.awd_weapon_damage[weaponName]["mk25"] ) &&
         ( level.awd_weapon_damage[weaponName]["mk2"] != AWD_DEFAULT_MK2_DAMAGE ||
           level.awd_weapon_damage[weaponName]["mk25"] != AWD_DEFAULT_MK25_DAMAGE ) )
    {
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

    /*
        Default per-mark damage lookup.
    */
    if ( isdefined( level.awd_default_mark_damage ) &&
         isdefined( level.awd_default_mark_damage[mark] ) )
    {
        return level.awd_default_mark_damage[mark];
    }

    mk2Damage =
        AWD_DEFAULT_MK2_DAMAGE;

    mk25Damage =
        AWD_DEFAULT_MK25_DAMAGE;

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
        return int( baseDamage * AWD_BODY_MULTIPLIER );
    }

    if ( hitLocation == "head" ||
         hitLocation == "helmet" )
    {
        return int( baseDamage * AWD_HEAD_MULTIPLIER );
    }

    if ( hitLocation == "neck" )
    {
        return int( baseDamage * AWD_NECK_MULTIPLIER );
    }

    return int( baseDamage * AWD_BODY_MULTIPLIER );
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

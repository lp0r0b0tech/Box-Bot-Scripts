/*
    All Exo Zombies weapons — direct Mk2-Mk25 damage modifier
    Advanced Warfare Exo Zombies / S1x / CBServers

    Progression:
        Mk1      = native damage
        Mk2-Mk25 = native damage x AWD_MK#_MULTIPLIER (3x..49x), scaled up per round after round 25

    Melee weapons:
        Exo suit melee ("exo_melee_zm"), Goliath combat knife ("iw5_combatknifegoliath_mp"),
        and any MOD_MELEE hit made while holding ANY weapon (listed or not)
        kill in a set number of hits: 1 on normal zombies, 2 on special zombies,
        20 on bosses (AWD_MELEE_HITS_NORMAL / _SPECIAL / _BOSS).

        The native Exo Zombies damage callback replaces all MOD_MELEE damage with
        level.playermeleedamage / level.playerexomeleedamage AFTER the
        level.modifyweapondamage callbacks run. Melee damage is therefore applied
        through level.modifydamagebyagenttype[agentType], which the native callback
        runs after that overwrite for every zombie type. Existing per-agent
        callbacks (e.g. Oz stage 2 armor) are wrapped and still run afterwards.

    Max-damage weapons:
        Exo slam ("boost_slam_mp"), grenades, equipment, rockets, turrets,
        killstreak weapons, and every map trap weapon are guaranteed 1-hit /
        1-shot kills on standard zombies, but deal configured Mk25 damage
        on bosses.

        The 1-hit damage is enforced twice: in level.modifyweapondamage and
        again in level.modifydamagebyagenttype[agentType], which the native
        callback runs AFTER its own equipment/melee damage rescaling.
        Sniper and turret traps additionally use a delayed finisher thread,
        because the native trapmodifydamage() overwrites their damage after
        every script callback has run.

    Each upgrade has its own multiplier define (AWD_MK2_MULTIPLIER .. AWD_MK25_MULTIPLIER).
    There are no head/neck/body hit-location multipliers.

    Native hook:
        level.modifyweapondamage[weaponName]

    Debug:
        set awd_debug_damage 1
*/


#define AWD_MIN_CUSTOM_MARK       2
#define AWD_MAX_CUSTOM_MARK       25

#define AWD_DEFAULT_MK2_DAMAGE    3750
#define AWD_DEFAULT_MK3_DAMAGE    3750
#define AWD_DEFAULT_MK4_DAMAGE    3750
#define AWD_DEFAULT_MK5_DAMAGE    3750
#define AWD_DEFAULT_MK6_DAMAGE    3750
#define AWD_DEFAULT_MK7_DAMAGE    3750
#define AWD_DEFAULT_MK8_DAMAGE    3750
#define AWD_DEFAULT_MK9_DAMAGE    3750
#define AWD_DEFAULT_MK10_DAMAGE   3750
#define AWD_DEFAULT_MK11_DAMAGE   3750
#define AWD_DEFAULT_MK12_DAMAGE   3750
#define AWD_DEFAULT_MK13_DAMAGE   3750
#define AWD_DEFAULT_MK14_DAMAGE   3750
#define AWD_DEFAULT_MK15_DAMAGE   3750
#define AWD_DEFAULT_MK16_DAMAGE   3750
#define AWD_DEFAULT_MK17_DAMAGE   3750
#define AWD_DEFAULT_MK18_DAMAGE   3750
#define AWD_DEFAULT_MK19_DAMAGE   3750
#define AWD_DEFAULT_MK20_DAMAGE   3750
#define AWD_DEFAULT_MK21_DAMAGE   3750
#define AWD_DEFAULT_MK22_DAMAGE   3750
#define AWD_DEFAULT_MK23_DAMAGE   3750
#define AWD_DEFAULT_MK24_DAMAGE   3750
#define AWD_DEFAULT_MK25_DAMAGE   3750
#define AWD_ONE_HIT_MELEE_DAMAGE 250000

// Melee hits to kill (exo melee, Goliath knife, any MOD_MELEE hit).
// Each hit deals max health / hits (rounded up), so the kill lands on exactly
// that hit from full health. 1 = instant kill.
#define AWD_MELEE_HITS_NORMAL         1
#define AWD_MELEE_HITS_SPECIAL        2
#define AWD_MELEE_HITS_BOSS           20

// Per-upgrade base damage multiplier (x native damage) used before round scaling.
// Default = 2 * mark - 1 (Mk2 = 3x ... Mk25 = 49x). Edit each value freely.
// From AWD_SCALE_START_ROUND onward the multiplier is further multiplied by
// AWD_SCALE_RATE ^ ( ( round - start ) * mark / 25 ), so higher tiers keep pace
// with zombie health growth while low tiers fall behind.
#define AWD_SCALE_START_ROUND     25
#define AWD_SCALE_RATE            1.065
#define AWD_SCALE_MAX_ROUNDS      150
#define AWD_MAX_DAMAGE            2000000000
#define AWD_MK2_MULTIPLIER 3.0
#define AWD_MK3_MULTIPLIER 5.0
#define AWD_MK4_MULTIPLIER 7.0
#define AWD_MK5_MULTIPLIER 9.0
#define AWD_MK6_MULTIPLIER 11.0
#define AWD_MK7_MULTIPLIER 13.0
#define AWD_MK8_MULTIPLIER 15.0
#define AWD_MK9_MULTIPLIER 17.0
#define AWD_MK10_MULTIPLIER 19.0
#define AWD_MK11_MULTIPLIER 21.0
#define AWD_MK12_MULTIPLIER 23.0
#define AWD_MK13_MULTIPLIER 25.0
#define AWD_MK14_MULTIPLIER 27.0
#define AWD_MK15_MULTIPLIER 29.0
#define AWD_MK16_MULTIPLIER 31.0
#define AWD_MK17_MULTIPLIER 33.0
#define AWD_MK18_MULTIPLIER 35.0
#define AWD_MK19_MULTIPLIER 37.0
#define AWD_MK20_MULTIPLIER 39.0
#define AWD_MK21_MULTIPLIER 41.0
#define AWD_MK22_MULTIPLIER 43.0
#define AWD_MK23_MULTIPLIER 45.0
#define AWD_MK24_MULTIPLIER 47.0
#define AWD_MK25_MULTIPLIER 49.0

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
    Grenades, equipment, rockets, turrets, killstreak weapons,
    exo slam, and map traps are guaranteed 1-hit / 1-shot kills on
    standard zombies (configured Mk25 damage on bosses), even if they
    do not have a normal player weaponstate entry.

    The listed special guns keep the previous behavior: they always
    use configured Mk25 damage.
*/
awd_init_max_damage_weapons()
{
    level.awd_max_damage_weapons = [];
    level.awd_one_hit_weapons = [];

    /*
        Melee weapons (1-hit kills handled by the melee paths).
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
    awd_add_one_hit_weapon(
        "frag_grenade_zombies_mp"
    );

    awd_add_one_hit_weapon(
        "frag_grenade_throw_zombies_mp"
    );

    awd_add_one_hit_weapon(
        "contact_grenade_zombies_mp"
    );

    awd_add_one_hit_weapon(
        "contact_grenade_throw_zombies_mp"
    );

    awd_add_one_hit_weapon(
        "explosive_drone_zombie_mp"
    );

    awd_add_one_hit_weapon(
        "explosive_drone_throw_zombie_mp"
    );

    awd_add_one_hit_weapon(
        "distraction_drone_zombie_mp"
    );

    awd_add_one_hit_weapon(
        "distraction_drone_throw_zombie_mp"
    );

    awd_add_one_hit_weapon(
        "dna_aoe_grenade_zombie_mp"
    );

    awd_add_one_hit_weapon(
        "dna_aoe_grenade_throw_zombie_mp"
    );

    awd_add_one_hit_weapon(
        "teleport_zombies_mp"
    );

    awd_add_one_hit_weapon(
        "teleport_throw_zombies_mp"
    );

    awd_add_one_hit_weapon(
        "repulsor_zombie_mp"
    );

    /*
        Killstreaks and killstreak projectiles
    */
    awd_add_one_hit_weapon(
        "killstreakmahem_mp"
    );

    awd_add_one_hit_weapon(
        "remote_energy_turret_mp"
    );

    awd_add_one_hit_weapon(
        "drone_assault_remote_turret_mp"
    );

    awd_add_one_hit_weapon(
        "ugv_missile_mp"
    );

    awd_add_one_hit_weapon(
        "sentry_minigun_mp"
    );

    awd_add_one_hit_weapon(
        "turretheadmg_mp"
    );

    awd_add_one_hit_weapon(
        "turretheadrocket_mp"
    );

    awd_add_one_hit_weapon(
        "turretheadenergy_mp"
    );

    awd_add_one_hit_weapon(
        "playermech_rocket_zm_mp"
    );

    awd_add_one_hit_weapon(
        "iw5_juggernautrocketszm_mp"
    );

    awd_add_one_hit_weapon(
        "playermech_rocket_swarm_zm_mp"
    );

    /*
        Goliath suit minigun (killstreak reward).

        The native modifydamagekillstreak() flattens its damage to
        2000 AFTER level.modifyweapondamage runs, so it must be in the
        one-hit set, which is re-enforced by the per-agent hook.
    */
    awd_add_one_hit_weapon(
        "iw5_exominigunzm_mp"
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

    /*
        Exo slam.

        "exo_slam" is the terminal/perk item name; the actual damage
        events arrive with the weapon "boost_slam_mp"
        (exo suit perk weapon: "exo_suit_perk_slamzm_mp").
    */
    awd_add_one_hit_weapon(
        "exo_slam"
    );

    awd_add_one_hit_weapon(
        "boost_slam_mp"
    );

    awd_add_one_hit_weapon(
        "exo_suit_perk_slamzm_mp"
    );

    /*
        Map trap weapons (native maps\mp\zombies\_util::istrapweapon list,
        plus the airstrike trap's orbital support missile).
    */
    awd_add_one_hit_weapon(
        "trap_zm_mp"
    );

    awd_add_one_hit_weapon(
        "trap_sniper_zm_mp"
    );

    awd_add_one_hit_weapon(
        "trap_missile_zm_mp"
    );

    awd_add_one_hit_weapon(
        "zombie_trap_turret_mp"
    );

    awd_add_one_hit_weapon(
        "zombie_water_trap_mp"
    );

    awd_add_one_hit_weapon(
        "zombie_vaporize_mp"
    );

    awd_add_one_hit_weapon(
        "orbitalsupport_missile_mp"
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


/*
    One-hit weapons are also max-damage weapons: the Mk25 damage is
    still used against bosses, which are never 1-hit killed.
*/
awd_add_one_hit_weapon( weaponName )
{
    if ( !isdefined( weaponName ) ||
         weaponName == "" )
    {
        return;
    }

    level.awd_one_hit_weapons[weaponName] = 1;

    awd_add_max_damage_weapon( weaponName );
}


awd_is_one_hit_weapon( weaponName )
{
    return isdefined( weaponName ) &&
           isdefined( level.awd_one_hit_weapons ) &&
           isdefined(
               level.awd_one_hit_weapons[weaponName]
           );
}


/*
    The native trapmodifydamage() overwrites sniper-trap and
    trap-turret damage AFTER every script damage callback has run,
    so these weapons need a delayed finisher to guarantee the kill.
*/
awd_needs_trap_finisher( weaponName )
{
    return isdefined( weaponName ) &&
           ( weaponName == "trap_sniper_zm_mp" ||
             weaponName == "zombie_trap_turret_mp" );
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
    Normal zombies are the basic walker/dog types; every other non-boss
    zombie type counts as special. Edit this list to reclassify types.
*/
awd_is_normal_zombie( victim )
{
    if ( !isdefined( victim ) ||
         !isdefined( victim.agent_type ) )
    {
        return true;
    }

    agentType = tolower( victim.agent_type );

    return agentType == "zombie_generic" ||
           agentType == "zombie_host" ||
           agentType == "zombie_dog";
}


/*
    Melee damage by target class: normal / special / boss hit counts.
*/
awd_get_melee_damage(
    victim,
    weaponName,
    hitLocation
)
{
    if ( awd_is_boss( victim ) )
    {
        hits = AWD_MELEE_HITS_BOSS;
    }
    else if ( awd_is_normal_zombie( victim ) )
    {
        hits = AWD_MELEE_HITS_NORMAL;
    }
    else
    {
        hits = AWD_MELEE_HITS_SPECIAL;
    }

    if ( hits <= 1 )
    {
        if ( awd_is_boss( victim ) )
        {
            return AWD_ONE_HIT_MELEE_DAMAGE;
        }

        return awd_get_one_hit_damage(
            victim,
            weaponName,
            hitLocation
        );
    }

    maxHealth = 0;

    if ( isdefined( victim ) )
    {
        if ( isdefined( victim.maxhealth ) && victim.maxhealth > 0 )
        {
            maxHealth = victim.maxhealth;
        }
        else if ( isdefined( victim.health ) && victim.health > 0 )
        {
            maxHealth = victim.health;
        }
    }

    if ( maxHealth <= 0 )
    {
        return AWD_ONE_HIT_MELEE_DAMAGE;
    }

    damage = int( maxHealth / hits ) + 1;

    if ( damage > AWD_MAX_DAMAGE )
    {
        damage = AWD_MAX_DAMAGE;
    }

    return damage;
}


/*
    1-hit damage (melee, exo slam, grenades, equipment, rockets,
    turrets, killstreaks, and map traps):
        Standard zombies = guaranteed 1-hit kill.
        Bosses           = configured Mk25 damage with hit-location multiplier.
*/
awd_get_one_hit_damage(
    victim,
    weaponName,
    hitLocation
)
{
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

        return int( finalDamage );
    }

    /*
        Target is a boss: do not 1-hit kill. Use configured Mk25 damage.
    */
    baseDamage =
        awd_get_mk25_damage(
            weaponName
        );

    return int( baseDamage );
}


/*
    Hook every zombie agent type through level.modifydamagebyagenttype.

    The native damage callback runs these hooks AFTER it replaces MOD_MELEE
    damage with level.playermeleedamage / level.playerexomeleedamage, and
    for every weapon (not only the registered weapon list). Any existing
    per-agent callback is saved and still called after the melee damage
    is applied.
*/
awd_register_agent_damage_hooks()
{
    if ( !isdefined( level.agentclasses ) )
    {
        return;
    }

    if ( !isdefined( level.modifydamagebyagenttype ) )
    {
        level.modifydamagebyagenttype = [];
    }

    if ( !isdefined( level.awd_prev_agent_damage ) )
    {
        level.awd_prev_agent_damage = [];
    }

    agentTypes =
        getArrayKeys(
            level.agentclasses
        );

    foreach ( agentType in agentTypes )
    {
        current =
            level.modifydamagebyagenttype[agentType];

        if ( isdefined( current ) &&
             current == ::awd_agent_modify_damage )
        {
            continue;
        }

        level.awd_prev_agent_damage[agentType] = current;

        level.modifydamagebyagenttype[agentType] =
            ::awd_agent_modify_damage;
    }
}


awd_agent_modify_damage(
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
    if ( isdefined( attacker ) &&
         isplayer( attacker ) &&
         isdefined( meansOfDeath ) &&
         meansOfDeath == "MOD_MELEE" )
    {
        weaponName = "none";

        if ( isdefined( weapon ) &&
             weapon != "" )
        {
            weaponName =
                getweaponbasename( weapon );

            if ( !isdefined( weaponName ) ||
                 weaponName == "" )
            {
                weaponName = weapon;
            }
        }

        finalDamage =
            awd_get_melee_damage(
                victim,
                weaponName,
                hitLocation
            );

        awd_debug_damage(
            "melee:" + weaponName,
            AWD_MAX_CUSTOM_MARK,
            hitLocation,
            damage,
            finalDamage,
            finalDamage
        );

        damage = finalDamage;
    }

    /*
        One-hit weapons (exo slam, grenades, equipment, rockets,
        turrets, killstreaks, and map traps).

        This hook runs AFTER the native callback's weapon-level and
        equipment damage rescaling, so enforcing the 1-hit damage here
        guarantees it survives those adjustments.
    */
    if ( isdefined( attacker ) &&
         isplayer( attacker ) &&
         ( !isdefined( meansOfDeath ) ||
           meansOfDeath != "MOD_MELEE" ) &&
         isdefined( weapon ) &&
         weapon != "" )
    {
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

        if ( awd_is_one_hit_weapon( weaponName ) )
        {
            finalDamage =
                awd_get_one_hit_damage(
                    victim,
                    weaponName,
                    hitLocation
                );

            awd_debug_damage(
                "onehit:" + weaponName,
                AWD_MAX_CUSTOM_MARK,
                hitLocation,
                damage,
                finalDamage,
                finalDamage
            );

            damage = finalDamage;

            /*
                The native trapmodifydamage() can still overwrite this
                damage for sniper/turret traps, so finish the kill on
                the next frame if the zombie survived.
            */
            if ( awd_needs_trap_finisher( weaponName ) &&
                 isdefined( victim ) &&
                 !awd_is_boss( victim ) )
            {
                victim thread awd_trap_finisher( attacker );
            }
        }
    }

    if ( isdefined( victim ) &&
         isdefined( victim.agent_type ) &&
         isdefined( level.awd_prev_agent_damage ) &&
         isdefined(
             level.awd_prev_agent_damage[victim.agent_type]
         ) )
    {
        damage =
            [[ level.awd_prev_agent_damage[victim.agent_type] ]](
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

    return damage;
}


/*
    Runs on the zombie. If the native trapmodifydamage() reduced a
    sniper/turret trap hit below a kill, finish the zombie with a
    plain trap hit, which no native post-callback rescaling touches.
*/
awd_trap_finisher( attacker )
{
    if ( isdefined( self.awd_trap_finisher_pending ) )
    {
        return;
    }

    self.awd_trap_finisher_pending = 1;

    self endon( "death" );

    wait 0.05;

    self.awd_trap_finisher_pending = undefined;

    if ( !isalive( self ) ||
         awd_is_boss( self ) )
    {
        return;
    }

    if ( !isdefined( attacker ) ||
         !isplayer( attacker ) )
    {
        return;
    }

    finisherDamage = AWD_ONE_HIT_MELEE_DAMAGE;

    if ( isdefined( self.health ) && self.health > 0 )
    {
        finisherDamage = self.health + 10000;
    }

    self dodamage(
        int( finisherDamage ),
        self.origin,
        attacker,
        attacker,
        "MOD_TRIGGER_HURT",
        "trap_zm_mp"
    );
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
    level.awd_mark_multiplier[2] = AWD_MK2_MULTIPLIER;
    level.awd_mark_multiplier[3] = AWD_MK3_MULTIPLIER;
    level.awd_mark_multiplier[4] = AWD_MK4_MULTIPLIER;
    level.awd_mark_multiplier[5] = AWD_MK5_MULTIPLIER;
    level.awd_mark_multiplier[6] = AWD_MK6_MULTIPLIER;
    level.awd_mark_multiplier[7] = AWD_MK7_MULTIPLIER;
    level.awd_mark_multiplier[8] = AWD_MK8_MULTIPLIER;
    level.awd_mark_multiplier[9] = AWD_MK9_MULTIPLIER;
    level.awd_mark_multiplier[10] = AWD_MK10_MULTIPLIER;
    level.awd_mark_multiplier[11] = AWD_MK11_MULTIPLIER;
    level.awd_mark_multiplier[12] = AWD_MK12_MULTIPLIER;
    level.awd_mark_multiplier[13] = AWD_MK13_MULTIPLIER;
    level.awd_mark_multiplier[14] = AWD_MK14_MULTIPLIER;
    level.awd_mark_multiplier[15] = AWD_MK15_MULTIPLIER;
    level.awd_mark_multiplier[16] = AWD_MK16_MULTIPLIER;
    level.awd_mark_multiplier[17] = AWD_MK17_MULTIPLIER;
    level.awd_mark_multiplier[18] = AWD_MK18_MULTIPLIER;
    level.awd_mark_multiplier[19] = AWD_MK19_MULTIPLIER;
    level.awd_mark_multiplier[20] = AWD_MK20_MULTIPLIER;
    level.awd_mark_multiplier[21] = AWD_MK21_MULTIPLIER;
    level.awd_mark_multiplier[22] = AWD_MK22_MULTIPLIER;
    level.awd_mark_multiplier[23] = AWD_MK23_MULTIPLIER;
    level.awd_mark_multiplier[24] = AWD_MK24_MULTIPLIER;
    level.awd_mark_multiplier[25] = AWD_MK25_MULTIPLIER;

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

    awd_register_agent_damage_hooks();

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
        MOD_MELEE hits are handled by awd_agent_modify_damage, because the
        native callback overwrites melee damage after this callback returns.
    */
    if ( isdefined( meansOfDeath ) &&
         meansOfDeath == "MOD_MELEE" )
    {
        return damage;
    }

    /*
        Exo suit melee and Goliath combat knife hits that are not
        reported as MOD_MELEE.
    */
    if ( awd_is_one_hit_melee( weaponName, weapon, meansOfDeath ) )
    {
        awd_disable_stock_multiplier(
            attacker,
            weaponName
        );

        finalDamage =
            awd_get_melee_damage(
                victim,
                weaponName,
                hitLocation
            );

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
        Exo slam, grenades, equipment, rockets, turrets, killstreaks,
        and map traps are guaranteed 1-hit kills on standard zombies.
    */
    if ( awd_is_one_hit_weapon( weaponName ) )
    {
        awd_disable_stock_multiplier(
            attacker,
            weaponName
        );

        finalDamage =
            awd_get_one_hit_damage(
                victim,
                weaponName,
                hitLocation
            );

        awd_debug_damage(
            "onehit:" + weaponName,
            AWD_MAX_CUSTOM_MARK,
            hitLocation,
            damage,
            finalDamage,
            finalDamage
        );

        return int( finalDamage );
    }

    /*
        Listed special weapons always receive Mk25 damage.
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

        finalDamage = baseDamage;

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

    baseDamage = damage;
    finalDamage = damage * awd_get_scaled_multiplier( weaponLevel );

    if ( finalDamage > AWD_MAX_DAMAGE )
    {
        finalDamage = AWD_MAX_DAMAGE;
    }


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


awd_get_mark_multiplier( mark )
{
    if ( isdefined( level.awd_mark_multiplier ) &&
         isdefined( level.awd_mark_multiplier[mark] ) )
    {
        return level.awd_mark_multiplier[mark];
    }

    return 1.0 + 2.0 * ( mark - 1 );
}


awd_get_current_round()
{
    if ( isdefined( level.wavecounter ) )
    {
        return level.wavecounter;
    }

    if ( isdefined( level.round_number ) )
    {
        return level.round_number;
    }

    if ( isdefined( level.currentroundnumber ) )
    {
        return level.currentroundnumber;
    }

    return 1;
}


/*
    Round-scaled multiplier for an upgrade tier.
    Below AWD_SCALE_START_ROUND only the per-mark base multiplier applies.
*/
awd_get_scaled_multiplier( mark )
{
    multiplier = awd_get_mark_multiplier( mark );
    roundsOver = awd_get_current_round() - AWD_SCALE_START_ROUND;

    if ( roundsOver <= 0 )
    {
        return multiplier;
    }

    if ( roundsOver > AWD_SCALE_MAX_ROUNDS )
    {
        roundsOver = AWD_SCALE_MAX_ROUNDS;
    }

    exponent = roundsOver * mark / AWD_MAX_CUSTOM_MARK;
    whole = int( exponent );
    frac = exponent - whole;

    for ( i = 0; i < whole; i++ )
    {
        multiplier *= AWD_SCALE_RATE;
    }

    return multiplier * ( 1.0 + frac * ( AWD_SCALE_RATE - 1.0 ) );
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

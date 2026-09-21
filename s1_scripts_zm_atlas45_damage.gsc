/*
    Exo Zombies Mk2-Mk25 custom damage modifier
    Advanced Warfare Exo Zombies / S1-Mod / CBServers

    Place this file at:
        s1/scripts/zm/atlas45_damage.gsc

    Scope:
        Applies to all Exo Zombies weapons registered in the stock
        weapon-damage callback table.

    Damage progression:
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
    if(isdefined(level.exo_damage_curve_started))
    {
        return;
    }

    level.exo_damage_curve_started = 1;

    println("ExoWeaponDamage: Zombies script initialized.");

    level thread atlas45_register_damage_modifier();
}

atlas45_register_damage_modifier()
{
    level endon("game_ended");

    if(isdefined(level.exo_damage_curve_registering) &&
       level.exo_damage_curve_registering)
    {
        return;
    }

    level.exo_damage_curve_registering = true;
    level thread atlas45_registration_guard_watchdog();

    /*
        Wait for the Zombies gametype to initialize the weapon-damage
        callback table.
    */
    for(i = 0; i < 600; i++)
    {
        if(isdefined(level.modifyweapondamage))
        {
            break;
        }

        wait 0.05;
    }

    if(!isdefined(level.modifyweapondamage))
    {
        println("ExoWeaponDamage: ERROR - level.modifyweapondamage was never initialized.");
        level.exo_damage_curve_registering = false;
        return;
    }

    if(!isdefined(level.exo_damage_curve_previous_callbacks))
    {
        level.exo_damage_curve_previous_callbacks = [];
    }
    if(!isdefined(level.exo_damage_curve_registered_weapons))
    {
        level.exo_damage_curve_registered_weapons = [];
    }
    level.exo_damage_curve_weapon_key_cache = [];

    registeredCount = 0;
    delegatedCount = 0;
    skippedCount = 0;
    weaponNames = getarraykeys(level.modifyweapondamage);

    for(i = 0; i < weaponNames.size; i++)
    {
        weaponName = weaponNames[i];
        if(!atlas45_should_register_weapon(weaponName))
        {
            continue;
        }
        level.exo_damage_curve_weapon_key_cache[weaponName] = weaponName;
        level.exo_damage_curve_weapon_key_cache[tolower(weaponName + "")] =
            weaponName;

        previousCallback = level.modifyweapondamage[weaponName];
        if(isdefined(previousCallback) &&
           !atlas45_is_self_reference_callback(previousCallback))
        {
            level.exo_damage_curve_previous_callbacks[weaponName] =
                previousCallback;
            level.exo_damage_curve_previous_callbacks[tolower(weaponName + "")] =
                previousCallback;
            delegatedCount++;
        }
        else
        {
            skippedCount++;
        }

        lowercaseWeaponName = tolower(weaponName + "");
        hasDistinctAliasCallback =
            lowercaseWeaponName != weaponName &&
            isdefined(level.modifyweapondamage[lowercaseWeaponName]) &&
            level.modifyweapondamage[lowercaseWeaponName] != previousCallback;

        level.modifyweapondamage[weaponName] =
            ::atlas45_modify_damage;
        level.exo_damage_curve_registered_weapons[weaponName] = true;

        if(!hasDistinctAliasCallback &&
           (lowercaseWeaponName == weaponName ||
            !isdefined(level.modifyweapondamage[lowercaseWeaponName]) ||
            level.modifyweapondamage[lowercaseWeaponName] == previousCallback))
        {
            if(isdefined(level.modifyweapondamage[lowercaseWeaponName]) &&
               !atlas45_is_self_reference_callback(level.modifyweapondamage[lowercaseWeaponName]))
            {
                level.exo_damage_curve_previous_callbacks[lowercaseWeaponName] =
                    level.modifyweapondamage[lowercaseWeaponName];
            }

            level.modifyweapondamage[lowercaseWeaponName] =
                ::atlas45_modify_damage;
            level.exo_damage_curve_registered_weapons[lowercaseWeaponName] = true;
        }

        registeredCount++;
    }

    if(registeredCount <= 0)
    {
        println("ExoWeaponDamage: no eligible zombie weapon callbacks found yet; registration will retry on next initialization attempt.");
        level.exo_damage_curve_registered = false;
        level.exo_damage_curve_registering = false;
        level thread atlas45_retry_register_damage_modifier();
        return;
    }

    level.exo_damage_curve_registered = 1;
    println("ExoWeaponDamage: damage modifier registered for " + registeredCount + " zombie weapons, delegated callbacks: " + delegatedCount + ", skipped undefined/already-hooked callbacks: " + skippedCount + ".");
    level.exo_damage_curve_registering = false;
    level thread atlas45_retry_register_damage_modifier();
}

atlas45_retry_register_damage_modifier()
{
    level endon("game_ended");

    wait 5;
    level thread atlas45_register_damage_modifier();
}

atlas45_registration_guard_watchdog()
{
    level endon("game_ended");

    wait 35;
    if(isdefined(level.exo_damage_curve_registering) &&
       level.exo_damage_curve_registering)
    {
        level.exo_damage_curve_registering = false;
    }
}

atlas45_should_register_weapon(weaponName)
{
    if(!isdefined(weaponName))
    {
        return false;
    }

    weaponName = tolower(weaponName + "");
    if(strlen(weaponName) <= 0)
    {
        return false;
    }

    return issubstr(weaponName, "_zm_");
}

/*
    Weapon-damage callback.

    Returning the supplied damage preserves normal Mk1 behavior.
    Returning a custom base damage for Mk2-Mk25 leaves stock ammo and
    stock hit-location behavior under control of the Zombies system.
*/
atlas45_modify_damage(
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
    if(!isdefined(weapon))
    {
        return damage;
    }

    weaponName = atlas45_resolve_registered_weapon_name(weapon);
    if(!isdefined(weaponName) || weaponName == "")
    {
        return atlas45_apply_compatible_previous_callback(
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            weaponName,
            point,
            direction,
            hitLocation
        );
    }
    if(!isdefined(level.exo_damage_curve_registered_weapons) ||
       !isdefined(level.exo_damage_curve_registered_weapons[weaponName]) ||
       !level.exo_damage_curve_registered_weapons[weaponName])
    {
        return atlas45_apply_compatible_previous_callback(
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            weaponName,
            point,
            direction,
            hitLocation
        );
    }

    /*
        Only change damage caused by a player.
    */
    if(!isdefined(attacker) || !isplayer(attacker))
    {
        return atlas45_apply_compatible_previous_callback(
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            weaponName,
            point,
            direction,
            hitLocation
        );
    }

    weaponLevel = maps\mp\zombies\_util::getzombieweaponlevel(
        attacker,
        weaponName
    );

    if(!isdefined(weaponLevel) || weaponLevel < 2)
    {
        /*
            Keep Mk1 completely vanilla.
        */
        return atlas45_apply_compatible_previous_callback(
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            weaponName,
            point,
            direction,
            hitLocation
        );
    }

    if(weaponLevel > 25)
    {
        weaponLevel = 25;
    }

    /*
        Returning a fixed Mk2-Mk25 base damage here avoids stacking
        stock weapon-level bonus damage on top of this custom curve.

        Do not process hitLocation here. This intentionally avoids custom
        head/neck/helmet multipliers so the game can retain its normal
        hit-location behavior.
    */
    return atlas45_get_base_damage(weaponLevel);
}

atlas45_apply_compatible_previous_callback(
    victim,
    attacker,
    damage,
    meansOfDeath,
    weapon,
    weaponName,
    point,
    direction,
    hitLocation
)
{
    resolvedWeaponName = weaponName;
    if(!isdefined(resolvedWeaponName) || resolvedWeaponName == "")
    {
        resolvedWeaponName = atlas45_resolve_registered_weapon_name(weapon);
    }

    if(!isdefined(level.exo_damage_curve_previous_callbacks))
    {
        return damage;
    }

    previousCallback = undefined;
    if(isdefined(resolvedWeaponName) && resolvedWeaponName != "" &&
       isdefined(level.exo_damage_curve_previous_callbacks[resolvedWeaponName]))
    {
        previousCallback =
            level.exo_damage_curve_previous_callbacks[resolvedWeaponName];
    }
    else if(isdefined(weapon))
    {
        weaponNameLowercase = tolower((weapon + ""));
        if(isdefined(level.exo_damage_curve_previous_callbacks[weapon + ""]))
        {
            previousCallback =
                level.exo_damage_curve_previous_callbacks[weapon + ""];
        }
        else if(isdefined(level.exo_damage_curve_previous_callbacks[weaponNameLowercase]))
        {
            previousCallback =
                level.exo_damage_curve_previous_callbacks[weaponNameLowercase];
        }
    }

    if(!isdefined(previousCallback) ||
       atlas45_is_self_reference_callback(previousCallback))
    {
        return damage;
    }

    return [[previousCallback]](
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

atlas45_is_self_reference_callback(callbackValue)
{
    if(!isdefined(callbackValue))
    {
        return true;
    }

    return callbackValue == ::atlas45_modify_damage ||
           callbackValue == ::atlas45_apply_compatible_previous_callback;
}

atlas45_resolve_registered_weapon_name(weapon)
{
    if(!isdefined(weapon) ||
       !isdefined(level.exo_damage_curve_weapon_key_cache))
    {
        return "";
    }

    weaponName = weapon + "";
    if(isdefined(level.exo_damage_curve_weapon_key_cache[weaponName]))
    {
        return level.exo_damage_curve_weapon_key_cache[weaponName];
    }

    lowercaseWeaponName = tolower(weaponName);
    if(isdefined(level.exo_damage_curve_weapon_key_cache[lowercaseWeaponName]))
    {
        return level.exo_damage_curve_weapon_key_cache[lowercaseWeaponName];
    }

    return "";
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
atlas45_get_base_damage(mark)
{
    if(mark < 2)
    {
        mark = 2;
    }

    if(mark > 25)
    {
        mark = 25;
    }

    if(mark <= 20)
    {
        /*
            Add +9 before division by 18 to round the Mk2-Mk20
            interpolation result to the nearest integer.
        */
        return 2500 + int(((((mark - 2) * 7500) + 9) / 18));
    }

    return 10000 + int((mark - 20) * 1400);
}

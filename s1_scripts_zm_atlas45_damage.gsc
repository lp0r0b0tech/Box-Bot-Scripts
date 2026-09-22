/*
    Exo Zombies Mk2-Mk25 custom damage modifier
    Advanced Warfare Exo Zombies / S1-Mod / CBServers

    Place this file at:
        s1_scripts_zm_atlas45_damage.gsc

    Scope:
        Applies to the configured Exo Zombies weapon families:
        Atlas45, RW1, M1 Irons, MP11, ASM1, PDW, SN6, SAC3,
        BAL27, AK12, HBRA3, IMR, ARX160, AE4,
        Bulldog, TAC19, S12, Blunderbuss,
        Lynx, NA45, MORS, Immolator,
        Ameli, Pytaek, OHM,
        CEL3 Cauterizer, Magnetron, KL03 Trident, LZ52 Limbo.

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

    level thread atlas45_registration_loop();
}

atlas45_registration_loop()
{
    level endon("game_ended");

    for(;;)
    {
        atlas45_register_damage_modifier();
        wait 5;
    }
}

atlas45_register_damage_modifier()
{
    level endon("game_ended");

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
        lowercaseAliasCallback = undefined;
        if(isdefined(level.modifyweapondamage[lowercaseWeaponName]))
        {
            lowercaseAliasCallback = level.modifyweapondamage[lowercaseWeaponName];
        }

        hasDistinctAliasCallback =
            lowercaseWeaponName != weaponName &&
            isdefined(lowercaseAliasCallback) &&
            !atlas45_is_self_reference_callback(lowercaseAliasCallback) &&
            lowercaseAliasCallback != previousCallback;

        level.modifyweapondamage[weaponName] =
            ::atlas45_modify_damage;
        level.exo_damage_curve_registered_weapons[weaponName] = true;

        if(!hasDistinctAliasCallback &&
           lowercaseWeaponName != weaponName &&
           (!isdefined(lowercaseAliasCallback) ||
            lowercaseAliasCallback == previousCallback ||
            atlas45_is_self_reference_callback(lowercaseAliasCallback)))
        {
            if(isdefined(lowercaseAliasCallback) &&
               !atlas45_is_self_reference_callback(lowercaseAliasCallback))
            {
                level.exo_damage_curve_previous_callbacks[lowercaseWeaponName] =
                    lowercaseAliasCallback;
            }

            level.modifyweapondamage[lowercaseWeaponName] =
                ::atlas45_modify_damage;
            level.exo_damage_curve_registered_weapons[lowercaseWeaponName] = true;
            level.exo_damage_curve_weapon_key_cache[lowercaseWeaponName] =
                weaponName;
        }

        registeredCount++;
    }

    if(registeredCount <= 0)
    {
        level.exo_damage_curve_registered = false;
        return;
    }

    shouldLogRegistration =
        !isdefined(level.exo_damage_curve_registered) ||
        !level.exo_damage_curve_registered ||
        !isdefined(level.exo_damage_curve_last_registered_count) ||
        level.exo_damage_curve_last_registered_count != registeredCount;

    level.exo_damage_curve_registered = 1;
    level.exo_damage_curve_last_registered_count = registeredCount;
    if(shouldLogRegistration)
    {
        println("ExoWeaponDamage: damage modifier registered for " + registeredCount + " zombie weapons, delegated callbacks: " + delegatedCount + ", skipped undefined/already-hooked callbacks: " + skippedCount + ".");
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

    return atlas45_is_allowed_weapon_key(weaponName);
}

atlas45_is_allowed_weapon_key(weaponName)
{
    /*
        User-selected Exo Zombies weapon families:
        Atlas45, RW1, M1 Irons, MP11, ASM1, PDW, SN6, SAC3,
        BAL27, AK12, HBRA3, IMR, ARX160, AE4,
        Bulldog, TAC19, S12, Blunderbuss,
        Lynx, NA45, MORS, Immolator,
        Ameli, Pytaek, OHM,
        CEL3 Cauterizer, Magnetron, KL03 Trident, LZ52 Limbo.
    */
    segments = atlas45_tokenize_weapon_key(weaponName);
    if(!isdefined(segments) || segments.size <= 0)
    {
        return false;
    }

    singles = atlas45_get_allowed_single_tokens();
    for(i = 0; i < segments.size; i++)
    {
        segment = segments[i];
        if(isdefined(singles[segment]) && singles[segment])
        {
            return true;
        }
    }

    pairs = atlas45_get_allowed_pair_tokens();
    for(i = 0; i < segments.size - 1; i++)
    {
        pairKey = segments[i] + "_" + segments[i + 1];
        if(isdefined(pairs[pairKey]) && pairs[pairKey])
        {
            return true;
        }
    }

    return false;
}

atlas45_tokenize_weapon_key(value)
{
    tokens = [];
    if(!isdefined(value))
    {
        return tokens;
    }

    raw = tolower(value + "");
    currentToken = "";
    allowedChars = "abcdefghijklmnopqrstuvwxyz0123456789";

    for(i = 0; i < strlen(raw); i++)
    {
        ch = getsubstr(raw, i, i + 1);
        if(issubstr(allowedChars, ch))
        {
            currentToken += ch;
        }
        else if(strlen(currentToken) > 0)
        {
            tokens[tokens.size] = currentToken;
            currentToken = "";
        }
    }

    if(strlen(currentToken) > 0)
    {
        tokens[tokens.size] = currentToken;
    }

    return tokens;
}

atlas45_get_allowed_single_tokens()
{
    if(isdefined(level.exo_damage_curve_allowed_single_tokens))
    {
        return level.exo_damage_curve_allowed_single_tokens;
    }

    tokens = [];
    tokens["atlas45"] = true;
    tokens["rw1"] = true;
    tokens["mp11"] = true;
    tokens["asm1"] = true;
    tokens["pdw"] = true;
    tokens["sn6"] = true;
    tokens["sac3"] = true;
    tokens["bal27"] = true;
    tokens["ak12"] = true;
    tokens["hbra3"] = true;
    tokens["imr"] = true;
    tokens["arx160"] = true;
    tokens["ae4"] = true;
    tokens["bulldog"] = true;
    tokens["tac19"] = true;
    tokens["s12"] = true;
    tokens["blunderbuss"] = true;
    tokens["lynx"] = true;
    tokens["na45"] = true;
    tokens["mors"] = true;
    tokens["immolator"] = true;
    tokens["ameli"] = true;
    tokens["pytaek"] = true;
    tokens["ohm"] = true;
    tokens["magnetron"] = true;

    level.exo_damage_curve_allowed_single_tokens = tokens;
    return tokens;
}

atlas45_get_allowed_pair_tokens()
{
    if(isdefined(level.exo_damage_curve_allowed_pair_tokens))
    {
        return level.exo_damage_curve_allowed_pair_tokens;
    }

    tokens = [];
    tokens["m1_irons"] = true;
    tokens["cel3_cauterizer"] = true;
    tokens["kl03_trident"] = true;
    tokens["lz52_limbo"] = true;

    level.exo_damage_curve_allowed_pair_tokens = tokens;
    return tokens;
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

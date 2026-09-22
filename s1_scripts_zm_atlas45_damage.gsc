/*
    Exo Zombies Mk2-Mk25 custom damage modifier
    Advanced Warfare Exo Zombies / S1-Mod / CBServers

    Place this file at:
        s1_scripts_zm_atlas45_damage.gsc

    Scope:
        Applies to every weapon that exposes a defined callback entry in
        level.modifyweapondamage at runtime.

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
        if(isdefined(level.exo_damage_curve_registered) &&
           level.exo_damage_curve_registered)
        {
            wait 30;
        }
        else
        {
            wait 5;
        }
    }
}

atlas45_register_damage_modifier()
{
    level endon("game_ended");

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
    if(!isdefined(level.exo_damage_curve_weapon_key_cache))
    {
        level.exo_damage_curve_weapon_key_cache = [];
    }

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
        if(!isdefined(previousCallback))
        {
            skippedCount++;
            continue;
        }

        if(!atlas45_is_self_reference_callback(previousCallback))
        {
            storedPreviousCallback = undefined;
            if(isdefined(level.exo_damage_curve_previous_callbacks[weaponName]))
            {
                storedPreviousCallback =
                    level.exo_damage_curve_previous_callbacks[weaponName];
            }

            if(!isdefined(storedPreviousCallback) ||
               storedPreviousCallback != previousCallback)
            {
                level.exo_damage_curve_previous_callbacks[weaponName] =
                    previousCallback;
                level.exo_damage_curve_previous_callbacks[tolower(weaponName + "")] =
                    previousCallback;
                delegatedCount++;
            }
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

        level.modifyweapondamage[weaponName] =
            ::atlas45_modify_damage;
        level.exo_damage_curve_registered_weapons[weaponName] = true;

        if(lowercaseWeaponName != weaponName)
        {
            if(isdefined(lowercaseAliasCallback) &&
               !atlas45_is_self_reference_callback(lowercaseAliasCallback))
            {
                storedAliasCallback = undefined;
                if(isdefined(level.exo_damage_curve_previous_callbacks[lowercaseWeaponName]))
                {
                    storedAliasCallback =
                        level.exo_damage_curve_previous_callbacks[lowercaseWeaponName];
                }

                if(!isdefined(storedAliasCallback) ||
                   storedAliasCallback != lowercaseAliasCallback)
                {
                    level.exo_damage_curve_previous_callbacks[lowercaseWeaponName] =
                        lowercaseAliasCallback;
                    delegatedCount++;
                }
            }
            else if(isdefined(level.exo_damage_curve_previous_callbacks[weaponName]))
            {
                fallbackAliasCallback = undefined;
                if(isdefined(level.exo_damage_curve_previous_callbacks[lowercaseWeaponName]))
                {
                    fallbackAliasCallback =
                        level.exo_damage_curve_previous_callbacks[lowercaseWeaponName];
                }

                if(!isdefined(fallbackAliasCallback) ||
                   atlas45_is_self_reference_callback(fallbackAliasCallback))
                {
                    /*
                        Keep Mk1 fallback behavior for lowercase lookups when the
                        lowercase alias had no distinct callback.
                    */
                    level.exo_damage_curve_previous_callbacks[lowercaseWeaponName] =
                        level.exo_damage_curve_previous_callbacks[weaponName];
                }
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
        return;
    }

    shouldLogRegistration =
        !isdefined(level.exo_damage_curve_registered) ||
        !level.exo_damage_curve_registered ||
        !isdefined(level.exo_damage_curve_last_registered_count) ||
        level.exo_damage_curve_last_registered_count != registeredCount ||
        !isdefined(level.exo_damage_curve_last_delegated_count) ||
        level.exo_damage_curve_last_delegated_count != delegatedCount ||
        !isdefined(level.exo_damage_curve_last_skipped_count) ||
        level.exo_damage_curve_last_skipped_count != skippedCount;

    level.exo_damage_curve_registered = 1;
    level.exo_damage_curve_last_registered_count = registeredCount;
    level.exo_damage_curve_last_delegated_count = delegatedCount;
    level.exo_damage_curve_last_skipped_count = skippedCount;
    if(shouldLogRegistration)
    {
        summaryText = "ExoWeaponDamage: damage modifier registered for " + registeredCount + " zombie weapons, delegated callbacks: " + delegatedCount + ", skipped primary undefined/already-hooked callbacks: " + skippedCount + ".";
        println(summaryText);
    }
}

atlas45_should_register_weapon(weaponName)
{
    if(!isdefined(weaponName))
    {
        return false;
    }

    originalWeaponName = weaponName + "";
    normalizedWeaponName = tolower(originalWeaponName);
    if(strlen(normalizedWeaponName) <= 0)
    {
        return false;
    }

    if(!(getsubstr(normalizedWeaponName, 0, 3) == "zm_" ||
         atlas45_ends_with(normalizedWeaponName, "_zm_mp")))
    {
        return false;
    }

    return isdefined(level.modifyweapondamage[originalWeaponName]) ||
           isdefined(level.modifyweapondamage[normalizedWeaponName]);
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
        weaponName = weapon + "";
        lowercaseWeaponName = tolower(weaponName);
        callbackForWeapon = undefined;
        if(isdefined(level.modifyweapondamage[weaponName]))
        {
            callbackForWeapon = level.modifyweapondamage[weaponName];
        }
        else if(isdefined(level.modifyweapondamage[lowercaseWeaponName]))
        {
            callbackForWeapon = level.modifyweapondamage[lowercaseWeaponName];
            weaponName = lowercaseWeaponName;
        }

        if(!isdefined(callbackForWeapon) ||
           !atlas45_is_self_reference_callback(callbackForWeapon))
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

        if(!isdefined(level.exo_damage_curve_weapon_key_cache))
        {
            level.exo_damage_curve_weapon_key_cache = [];
        }
        if(!isdefined(level.exo_damage_curve_registered_weapons))
        {
            level.exo_damage_curve_registered_weapons = [];
        }

        level.exo_damage_curve_weapon_key_cache[weaponName] = weaponName;
        level.exo_damage_curve_weapon_key_cache[lowercaseWeaponName] =
            weaponName;
        level.exo_damage_curve_registered_weapons[weaponName] = true;
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

    weaponLevel = atlas45_get_weapon_level(attacker, weaponName);

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
        Feed the Mk2-Mk25 curve value through a round-aware scalar, then pass
        it through the existing callback chain so stock per-weapon and
        hit-location behavior can still apply.
    */
    customBaseDamage = atlas45_get_base_damage(weaponLevel);
    scaledDamage = int(customBaseDamage * atlas45_get_round_damage_multiplier());
    if(scaledDamage < customBaseDamage)
    {
        scaledDamage = customBaseDamage;
    }

    return atlas45_apply_compatible_previous_callback(
        victim,
        attacker,
        scaledDamage,
        meansOfDeath,
        weapon,
        weaponName,
        point,
        direction,
        hitLocation
    );
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
    if(isdefined(weapon))
    {
        weaponName = weapon + "";
        weaponNameLowercase = tolower(weaponName);
        if(isdefined(level.exo_damage_curve_previous_callbacks[weaponName]))
        {
            previousCallback =
                level.exo_damage_curve_previous_callbacks[weaponName];
        }
        else if(isdefined(level.exo_damage_curve_previous_callbacks[weaponNameLowercase]))
        {
            previousCallback =
                level.exo_damage_curve_previous_callbacks[weaponNameLowercase];
        }
    }

    if(!isdefined(previousCallback) &&
       isdefined(resolvedWeaponName) && resolvedWeaponName != "" &&
       isdefined(level.exo_damage_curve_previous_callbacks[resolvedWeaponName]))
    {
        previousCallback =
            level.exo_damage_curve_previous_callbacks[resolvedWeaponName];
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

    return callbackValue == ::atlas45_modify_damage;
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

atlas45_get_weapon_level(attacker, weaponName)
{
    candidateKeys = atlas45_get_weapon_level_keys(weaponName);
    for(i = 0; i < candidateKeys.size; i++)
    {
        key = candidateKeys[i];
        levelValue = maps\mp\zombies\_util::getzombieweaponlevel(
            attacker,
            key
        );
        if(isdefined(levelValue))
        {
            return levelValue;
        }
    }

    return undefined;
}

atlas45_get_weapon_level_keys(weaponName)
{
    keys = [];
    if(!isdefined(weaponName))
    {
        return keys;
    }

    normalized = tolower(weaponName + "");
    atlas45_add_unique_key(keys, normalized);

    if(strlen(normalized) > 3 &&
       getsubstr(normalized, 0, 3) == "zm_")
    {
        baseName = getsubstr(normalized, 3, strlen(normalized));
        if(atlas45_ends_with(baseName, "_zm_mp"))
        {
            baseName = atlas45_remove_suffix(baseName, "_zm_mp");
        }

        atlas45_add_unique_key(keys, baseName);
        atlas45_add_unique_key(keys, baseName + "_zm_mp");
        atlas45_add_unique_key(keys, "iw5_" + baseName + "_zm_mp");
    }

    if(strlen(normalized) > 3 &&
       atlas45_ends_with(normalized, "_mp") &&
       !atlas45_ends_with(normalized, "_zm_mp") &&
       !atlas45_ends_with(normalized, "zm_mp"))
    {
        atlas45_add_unique_key(keys, atlas45_remove_suffix(normalized, "_mp"));
    }

    if(strlen(normalized) > 11 &&
       getsubstr(normalized, 0, 4) == "iw5_" &&
       (atlas45_ends_with(normalized, "_zm_mp") ||
        (atlas45_ends_with(normalized, "zm_mp") &&
         !atlas45_ends_with(normalized, "_zm_mp"))))
    {
        baseName = atlas45_slice_from(normalized, 4);
        if(atlas45_ends_with(baseName, "_zm_mp"))
        {
            baseName = atlas45_remove_suffix(baseName, "_zm_mp");
        }
        else
        {
            baseName = atlas45_remove_suffix(baseName, "zm_mp");
        }

        atlas45_add_unique_key(keys, baseName);
        atlas45_add_unique_key(keys, "zm_" + baseName);
    }

    if(atlas45_ends_with(normalized, "_zm_mp"))
    {
        strippedBaseName = atlas45_remove_suffix(normalized, "_zm_mp");
        atlas45_add_unique_key(
            keys,
            strippedBaseName
        );
        atlas45_add_unique_key(keys, "zm_" + strippedBaseName);
    }

    return keys;
}

atlas45_add_unique_key(keys, value)
{
    if(!isdefined(value))
    {
        return;
    }

    value = tolower(value + "");
    if(strlen(value) <= 0)
    {
        return;
    }

    for(i = 0; i < keys.size; i++)
    {
        if(keys[i] == value)
        {
            return;
        }
    }

    keys[keys.size] = value;
}

atlas45_ends_with(value, suffix)
{
    if(!isdefined(value) || !isdefined(suffix))
    {
        return false;
    }

    value = value + "";
    suffix = suffix + "";
    if(strlen(suffix) > strlen(value))
    {
        return false;
    }

    return getsubstr(
        value,
        strlen(value) - strlen(suffix),
        strlen(value)
    ) == suffix;
}

atlas45_remove_suffix(value, suffix)
{
    if(!isdefined(value) || !isdefined(suffix))
    {
        return value;
    }

    value = value + "";
    suffix = suffix + "";
    if(!atlas45_ends_with(value, suffix))
    {
        return value;
    }

    keepLength = strlen(value) - strlen(suffix);
    trimmedValue = "";
    for(i = 0; i < keepLength; i++)
    {
        trimmedValue += getsubstr(value, i, i + 1);
    }

    return trimmedValue;
}

atlas45_slice_from(value, startIndex)
{
    if(!isdefined(value))
    {
        return "";
    }

    value = value + "";
    if(startIndex < 0)
    {
        startIndex = 0;
    }
    if(startIndex >= strlen(value))
    {
        return "";
    }

    result = "";
    for(i = startIndex; i < strlen(value); i++)
    {
        result += getsubstr(value, i, i + 1);
    }

    return result;
}

atlas45_get_round_damage_multiplier()
{
    if(!isdefined(level.round_number))
    {
        return 1.0;
    }

    roundNumber = atlas45_parse_positive_int(level.round_number);
    if(roundNumber > 200)
    {
        roundNumber = 200;
    }
    if(roundNumber <= 20)
    {
        return 1.0;
    }

    if(roundNumber <= 40)
    {
        return 1.0 + ((roundNumber - 20) * 0.03);
    }

    if(roundNumber <= 70)
    {
        return 1.6 + ((roundNumber - 40) * 0.04);
    }

    return 2.8 + ((roundNumber - 70) * 0.05);
}

atlas45_parse_positive_int(value)
{
    text = value + "";
    parsedValue = 0;
    hasDigits = false;

    for(i = 0; i < strlen(text); i++)
    {
        ch = getsubstr(text, i, i + 1);
        if(ch >= "0" && ch <= "9")
        {
            parsedValue = (parsedValue * 10) + atlas45_digit_to_int(ch);
            hasDigits = true;
        }
        else if(hasDigits)
        {
            break;
        }
    }

    if(!hasDigits || parsedValue < 1)
    {
        return 1;
    }

    return parsedValue;
}

atlas45_digit_to_int(ch)
{
    if(ch == "0") return 0;
    if(ch == "1") return 1;
    if(ch == "2") return 2;
    if(ch == "3") return 3;
    if(ch == "4") return 4;
    if(ch == "5") return 5;
    if(ch == "6") return 6;
    if(ch == "7") return 7;
    if(ch == "8") return 8;

    return 9;
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

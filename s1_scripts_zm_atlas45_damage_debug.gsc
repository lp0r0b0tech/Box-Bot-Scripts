/*
    Exo Zombies Mk2-Mk25 custom damage modifier (DEBUG BUILD)
    Advanced Warfare Exo Zombies / S1-Mod / CBServers

    This build is intentionally verbose to pinpoint runtime failures in one run.
*/

main()
{
    if(isdefined(level.exo_damage_curve_started))
    {
        return;
    }

    level.exo_damage_curve_started = 1;
    level.exo_damage_debug = 1; // 1 = ON, 0 = OFF
    level.exo_damage_debug_hits = 0;
    level.exo_damage_debug_last_modifyweapondamage_dump = 0;
    level.exo_damage_debug_last_tick_print = 0;

    exo_debug("script initialized");
    exo_damage_validate_key_matcher();

    level thread exo_damage_registration_loop();
}

exo_damage_registration_loop()
{
    level endon("game_ended");

    for(;;)
    {
        exo_damage_register_callbacks();
        wait 5;
    }
}

exo_damage_register_callbacks()
{
    if(!isdefined(level.modifyweapondamage))
    {
        exo_debug("register: level.modifyweapondamage undefined");
        return false;
    }

    if(!isdefined(level.exo_damage_previous_callbacks))
    {
        level.exo_damage_previous_callbacks = [];
    }
    if(!isdefined(level.exo_damage_registered_keys))
    {
        level.exo_damage_registered_keys = [];
    }
    if(!isdefined(level.exo_damage_weapon_key_cache))
    {
        level.exo_damage_weapon_key_cache = [];
    }

    keys = getarraykeys(level.modifyweapondamage);
    hookedCount = 0;
    delegatedCount = 0;
    changed = false;
    zombieKeyCount = 0;

    for(i = 0; i < keys.size; i++)
    {
        key = keys[i];

        if(!exo_damage_is_zombie_weapon_key(key))
        {
            continue;
        }

        zombieKeyCount++;

        callback = level.modifyweapondamage[key];
        if(!isdefined(callback))
        {
            exo_debug("register: zombie key has undefined callback -> " + key);
            continue;
        }

        canonicalKey = tolower(key + "");
        level.exo_damage_weapon_key_cache[key] = canonicalKey;
        level.exo_damage_weapon_key_cache[canonicalKey] = canonicalKey;

        if(!exo_damage_is_self_callback(callback))
        {
            if(!isdefined(level.exo_damage_previous_callbacks[key]) ||
               level.exo_damage_previous_callbacks[key] != callback)
            {
                level.exo_damage_previous_callbacks[key] = callback;
                level.exo_damage_previous_callbacks[canonicalKey] = callback;
                delegatedCount++;
                changed = true;
                exo_debug("register: saved previous callback for key=" + key + " canonical=" + canonicalKey);
            }

            latestCallback = level.modifyweapondamage[key];
            if(latestCallback == callback)
            {
                level.modifyweapondamage[key] = ::exo_damage_modify;
                changed = true;
                exo_debug("register: hooked key=" + key);
            }
            else if(isdefined(latestCallback) &&
                    !exo_damage_is_self_callback(latestCallback))
            {
                level.exo_damage_previous_callbacks[key] = latestCallback;
                level.exo_damage_previous_callbacks[canonicalKey] = latestCallback;
                delegatedCount++;
                changed = true;
                exo_debug("register: race update, refreshed previous callback for key=" + key);
            }
        }

        level.exo_damage_registered_keys[key] = true;
        level.exo_damage_registered_keys[canonicalKey] = true;
        hookedCount++;
    }

    exo_debug("register pass: totalKeys=" + keys.size + " zombieKeys=" + zombieKeyCount + " hooked=" + hookedCount + " delegated=" + delegatedCount + " changed=" + changed);

    if(exo_should_dump_modifyweapondamage())
    {
        exo_dump_modifyweapondamage_keys();
    }

    if(hookedCount > 0)
    {
        if(!isdefined(level.exo_damage_last_hooked) ||
           !isdefined(level.exo_damage_last_delegated) ||
           level.exo_damage_last_hooked != hookedCount ||
           level.exo_damage_last_delegated != delegatedCount)
        {
            println("ExoWeaponDamage: hooks=" + hookedCount + ", delegated=" + delegatedCount + ".");
            changed = true;
        }

        level.exo_damage_last_hooked = hookedCount;
        level.exo_damage_last_delegated = delegatedCount;
    }

    return changed;
}

exo_damage_is_zombie_weapon_key(key)
{
    if(!isdefined(key))
    {
        return false;
    }

    text = tolower(key + "");
    if(strlen(text) <= 0)
    {
        return false;
    }

    if(exo_damage_starts_with(text, "zm_"))
    {
        return true;
    }

    if(exo_damage_starts_with(text, "iw5_") &&
       (exo_damage_ends_with(text, "_zm_mp") ||
        exo_damage_ends_with(text, "zm_mp")))
    {
        return true;
    }

    return false;
}

exo_damage_validate_key_matcher()
{
    exo_debug("matcher sanity begin");

    if(!exo_damage_is_zombie_weapon_key("zm_atlas45"))
    {
        println("ExoWeaponDamage: key matcher sanity check failed for zm_*.");
    }
    if(!exo_damage_is_zombie_weapon_key("iw5_titan45_zm_mp"))
    {
        println("ExoWeaponDamage: key matcher sanity check failed for iw5_*_zm_mp.");
    }
    if(!exo_damage_is_zombie_weapon_key("iw5_titan45zm_mp"))
    {
        println("ExoWeaponDamage: key matcher sanity check failed for iw5_*zm_mp.");
    }
    if(exo_damage_is_zombie_weapon_key("iw5_titan45_mp"))
    {
        println("ExoWeaponDamage: key matcher sanity check failed for iw5_*_mp.");
    }

    exo_debug("matcher sanity end");
}

exo_damage_modify(
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
    level.exo_damage_debug_hits++;
    debugThisHit = exo_should_log_hit(level.exo_damage_debug_hits);

    if(debugThisHit)
    {
        exo_debug("hit#" + level.exo_damage_debug_hits + " weaponRaw=" + exo_to_text(weapon) + " damageIn=" + exo_to_text(damage) + " hitLoc=" + exo_to_text(hitLocation) + " mod=" + exo_to_text(meansOfDeath));
    }

    weaponKey = "";
    if(isdefined(weapon))
    {
        weaponKey = exo_damage_resolve_weapon_key(weapon);
    }

    if(!isdefined(attacker) || !isplayer(attacker))
    {
        if(debugThisHit)
        {
            exo_debug("hit#" + level.exo_damage_debug_hits + " non-player attacker -> delegate");
        }

        return exo_damage_delegate(
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            weaponKey,
            point,
            direction,
            hitLocation
        );
    }

    if(!isdefined(weapon))
    {
        if(debugThisHit)
        {
            exo_debug("hit#" + level.exo_damage_debug_hits + " weapon undefined -> delegate");
        }

        return exo_damage_delegate(
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            weaponKey,
            point,
            direction,
            hitLocation
        );
    }

    exo_damage_clear_weapon_level_increase(attacker, weaponKey, weapon);

    weaponLevel = exo_damage_get_weapon_level(attacker, weaponKey, debugThisHit);
    if(!isdefined(weaponLevel) || weaponLevel < 2)
    {
        if(debugThisHit)
        {
            exo_debug("hit#" + level.exo_damage_debug_hits + " level<2 or undefined level=" + exo_to_text(weaponLevel) + " key=" + weaponKey + " -> delegate");
        }

        return exo_damage_delegate(
            victim,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            weaponKey,
            point,
            direction,
            hitLocation
        );
    }

    if(weaponLevel > 25)
    {
        if(debugThisHit)
        {
            exo_debug("hit#" + level.exo_damage_debug_hits + " level clamped " + weaponLevel + " -> 25");
        }
        weaponLevel = 25;
    }

    vanillaDamage = exo_damage_delegate(
        victim,
        attacker,
        damage,
        meansOfDeath,
        weapon,
        weaponKey,
        point,
        direction,
        hitLocation
    );

    baseDamage = exo_damage_get_base_damage(weaponLevel);
    roundMult = exo_damage_get_round_multiplier();
    targetDamage = int(baseDamage * roundMult);
    if(targetDamage < baseDamage)
    {
        targetDamage = baseDamage;
    }

    referenceDamage = damage;
    if(referenceDamage <= 0)
    {
        referenceDamage = vanillaDamage;
    }
    if(referenceDamage <= 0)
    {
        if(debugThisHit)
        {
            exo_debug("hit#" + level.exo_damage_debug_hits + " referenceDamage<=0, returning vanillaDamage=" + exo_to_text(vanillaDamage));
        }
        return vanillaDamage;
    }

    finalDamage = int((vanillaDamage * targetDamage) / referenceDamage);

    if(debugThisHit)
    {
        roundNumber = exo_to_text(level.round_number);
        exo_debug("hit#" + level.exo_damage_debug_hits + " key=" + weaponKey + " level=" + weaponLevel + " round=" + roundNumber + " mult=" + roundMult + " in=" + damage + " vanilla=" + vanillaDamage + " base=" + baseDamage + " target=" + targetDamage + " final=" + finalDamage);
    }

    return finalDamage;
}

exo_damage_delegate(
    victim,
    attacker,
    damage,
    meansOfDeath,
    weapon,
    weaponKey,
    point,
    direction,
    hitLocation
)
{
    if(!isdefined(level.exo_damage_previous_callbacks))
    {
        exo_debug("delegate: previous callback table undefined -> return input damage");
        return damage;
    }

    previous = undefined;

    if(isdefined(weapon))
    {
        weaponText = weapon + "";
        lowerWeaponText = tolower(weaponText);

        if(isdefined(level.exo_damage_previous_callbacks[weaponText]))
        {
            previous = level.exo_damage_previous_callbacks[weaponText];
        }
        else if(isdefined(level.exo_damage_previous_callbacks[lowerWeaponText]))
        {
            previous = level.exo_damage_previous_callbacks[lowerWeaponText];
        }
    }

    if(!isdefined(previous) &&
       isdefined(weaponKey) && weaponKey != "" &&
       isdefined(level.exo_damage_previous_callbacks[weaponKey]))
    {
        previous = level.exo_damage_previous_callbacks[weaponKey];
    }

    if(!isdefined(previous) || exo_damage_is_self_callback(previous))
    {
        fallback = exo_damage_get_current_non_self_callback(weapon, weaponKey);
        if(!isdefined(fallback))
        {
            return damage;
        }

        return [[fallback]](
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

    return [[previous]](
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

exo_damage_is_self_callback(callbackValue)
{
    if(!isdefined(callbackValue))
    {
        return true;
    }

    return callbackValue == ::exo_damage_modify;
}

exo_damage_get_current_non_self_callback(weapon, weaponKey)
{
    if(!isdefined(level.modifyweapondamage))
    {
        return undefined;
    }

    callback = undefined;

    if(isdefined(weapon))
    {
        weaponText = weapon + "";
        lowerWeaponText = tolower(weaponText);

        if(isdefined(level.modifyweapondamage[weaponText]))
        {
            callback = level.modifyweapondamage[weaponText];
        }
        else if(isdefined(level.modifyweapondamage[lowerWeaponText]))
        {
            callback = level.modifyweapondamage[lowerWeaponText];
        }
    }

    if(!isdefined(callback) &&
       isdefined(weaponKey) && weaponKey != "" &&
       isdefined(level.modifyweapondamage[weaponKey]))
    {
        callback = level.modifyweapondamage[weaponKey];
    }

    if(!isdefined(callback) || exo_damage_is_self_callback(callback))
    {
        return undefined;
    }

    return callback;
}

exo_damage_clear_weapon_level_increase(attacker, weaponKey, weapon)
{
    if(!isdefined(attacker.weaponstate))
    {
        return;
    }

    if(!isdefined(attacker.exo_damage_cleared_weapon_level_increase))
    {
        attacker.exo_damage_cleared_weapon_level_increase = [];
    }
    if(!isdefined(attacker.exo_damage_weaponstate_probe_time))
    {
        attacker.exo_damage_weaponstate_probe_time = [];
    }

    if(isdefined(weaponKey) && weaponKey != "" &&
       isdefined(attacker.exo_damage_cleared_weapon_level_increase[weaponKey]) &&
       attacker.exo_damage_cleared_weapon_level_increase[weaponKey])
    {
        keys = exo_damage_get_weapon_level_keys(weaponKey);

        if(isdefined(weapon))
        {
            exo_damage_add_unique_key(keys, weapon + "");
            exo_damage_add_unique_key(keys, tolower(weapon + ""));
        }

        for(i = 0; i < keys.size; i++)
        {
            key = keys[i];
            if(isdefined(attacker.weaponstate[key]) &&
               isdefined(attacker.weaponstate[key]["weapon_level_increase"]))
            {
                attacker.weaponstate[key]["weapon_level_increase"] = 0;
                return;
            }
        }

        attacker.exo_damage_cleared_weapon_level_increase[weaponKey] = false;
    }

    if(isdefined(weaponKey) && weaponKey != "" &&
       isdefined(level.time) &&
       isdefined(attacker.exo_damage_weaponstate_probe_time[weaponKey]) &&
       ((level.time - attacker.exo_damage_weaponstate_probe_time[weaponKey]) < 1000))
    {
        return;
    }

    if(isdefined(weaponKey) && weaponKey != "" && isdefined(level.time))
    {
        attacker.exo_damage_weaponstate_probe_time[weaponKey] = level.time;
    }

    keys = exo_damage_get_weapon_level_keys(weaponKey);

    if(isdefined(weapon))
    {
        exo_damage_add_unique_key(keys, weapon + "");
        exo_damage_add_unique_key(keys, tolower(weapon + ""));
    }

    resetAny = false;
    for(i = 0; i < keys.size; i++)
    {
        key = keys[i];
        if(isdefined(attacker.weaponstate[key]) &&
           isdefined(attacker.weaponstate[key]["weapon_level_increase"]))
        {
            attacker.weaponstate[key]["weapon_level_increase"] = 0;
            attacker.exo_damage_cleared_weapon_level_increase[key] = true;
            resetAny = true;
        }
    }

    if(resetAny && isdefined(weaponKey) && weaponKey != "")
    {
        attacker.exo_damage_cleared_weapon_level_increase[weaponKey] = true;
        exo_debug("clear_level_increase: key=" + weaponKey + " resetAny=1 keysTried=" + keys.size);
    }
}

exo_damage_resolve_weapon_key(weapon)
{
    if(!isdefined(weapon))
    {
        return "";
    }
    if(!isdefined(level.exo_damage_weapon_key_cache))
    {
        level.exo_damage_weapon_key_cache = [];
    }

    weaponText = weapon + "";
    lowerWeaponText = tolower(weaponText);

    if(isdefined(level.exo_damage_weapon_key_cache[weaponText]))
    {
        return level.exo_damage_weapon_key_cache[weaponText];
    }
    if(isdefined(level.exo_damage_weapon_key_cache[lowerWeaponText]))
    {
        return level.exo_damage_weapon_key_cache[lowerWeaponText];
    }

    level.exo_damage_weapon_key_cache[weaponText] = lowerWeaponText;
    level.exo_damage_weapon_key_cache[lowerWeaponText] = lowerWeaponText;

    return lowerWeaponText;
}

exo_damage_get_weapon_level(attacker, weaponKey, doDebug)
{
    keys = exo_damage_get_weapon_level_keys(weaponKey);

    if(doDebug)
    {
        exo_debug("level lookup: weaponKey=" + exo_to_text(weaponKey) + " candidates=" + exo_join_keys(keys));
    }

    for(i = 0; i < keys.size; i++)
    {
        levelValue = maps\mp\zombies\_util::getzombieweaponlevel(attacker, keys[i]);

        if(doDebug)
        {
            exo_debug("level lookup: key[" + i + "]=" + keys[i] + " => " + exo_to_text(levelValue));
        }

        if(isdefined(levelValue))
        {
            return levelValue;
        }
    }

    return undefined;
}

exo_damage_get_weapon_level_keys(weaponKey)
{
    keys = [];
    if(!isdefined(weaponKey))
    {
        return keys;
    }

    normalized = tolower(weaponKey + "");
    exo_damage_add_unique_key(keys, normalized);

    if(exo_damage_starts_with(normalized, "zm_"))
    {
        base = getsubstr(normalized, 3, strlen(normalized));
        base = exo_damage_remove_suffix(base, "_zm_mp");

        exo_damage_add_unique_key(keys, base);
        exo_damage_add_unique_key(keys, "zm_" + base);
        exo_damage_add_unique_key(keys, base + "_zm_mp");
        exo_damage_add_unique_key(keys, "iw5_" + base + "_zm_mp");
        exo_damage_add_unique_key(keys, "iw5_" + base + "zm_mp");
    }

    if(exo_damage_starts_with(normalized, "iw5_"))
    {
        base = getsubstr(normalized, 4, strlen(normalized));
        if(exo_damage_ends_with(base, "_zm_mp"))
        {
            base = exo_damage_remove_suffix(base, "_zm_mp");
        }
        else if(exo_damage_ends_with(base, "zm_mp"))
        {
            base = exo_damage_remove_suffix(base, "zm_mp");
        }
        base = exo_damage_remove_suffix(base, "_mp");
        base = exo_damage_remove_suffix(base, "_");

        exo_damage_add_unique_key(keys, base);
        exo_damage_add_unique_key(keys, "zm_" + base);
        exo_damage_add_unique_key(keys, "iw5_" + base + "_zm_mp");
        exo_damage_add_unique_key(keys, "iw5_" + base + "zm_mp");
    }

    if(exo_damage_ends_with(normalized, "_mp") &&
       !exo_damage_ends_with(normalized, "zm_mp"))
    {
        exo_damage_add_unique_key(keys, exo_damage_remove_suffix(normalized, "_mp"));
    }

    return keys;
}

exo_damage_add_unique_key(keys, value)
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

exo_damage_starts_with(value, prefix)
{
    if(!isdefined(value) || !isdefined(prefix))
    {
        return false;
    }

    value = value + "";
    prefix = prefix + "";
    if(strlen(prefix) > strlen(value))
    {
        return false;
    }

    return getsubstr(value, 0, strlen(prefix)) == prefix;
}

exo_damage_ends_with(value, suffix)
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

    return getsubstr(value, strlen(value) - strlen(suffix), strlen(value)) == suffix;
}

exo_damage_remove_suffix(value, suffix)
{
    if(!isdefined(value) || !isdefined(suffix))
    {
        return value;
    }

    value = value + "";
    suffix = suffix + "";
    if(!exo_damage_ends_with(value, suffix))
    {
        return value;
    }

    return getsubstr(value, 0, strlen(value) - strlen(suffix));
}

exo_damage_get_round_multiplier()
{
    maxScaledRound = 120;
    maxRoundMultiplier = 4.0;

    if(!isdefined(level.round_number))
    {
        return 1.0;
    }

    roundNumber = exo_damage_parse_signed_int(level.round_number);
    if(roundNumber < 1)
    {
        roundNumber = 1;
    }
    if(roundNumber > maxScaledRound)
    {
        roundNumber = maxScaledRound;
    }

    if(roundNumber <= 20)
    {
        return 1.0;
    }

    growthSteps = maxScaledRound - 20;
    currentStep = roundNumber - 20;
    growthPerRound = (maxRoundMultiplier - 1.0) / growthSteps;

    multiplier = 1.0 + (currentStep * growthPerRound);
    if(multiplier > maxRoundMultiplier)
    {
        multiplier = maxRoundMultiplier;
    }

    return multiplier;
}

exo_damage_parse_signed_int(value)
{
    text = value + "";
    parsedValue = 0;
    hasDigits = false;
    isNegative = false;

    for(i = 0; i < strlen(text); i++)
    {
        ch = getsubstr(text, i, i + 1);

        if(i == 0 && (ch == "-" || ch == "+"))
        {
            isNegative = ch == "-";
            continue;
        }

        if(ch >= "0" && ch <= "9")
        {
            parsedValue = (parsedValue * 10) + exo_damage_digit_to_int(ch);
            hasDigits = true;
        }
        else if(hasDigits)
        {
            break;
        }
    }

    if(!hasDigits)
    {
        return 1;
    }

    if(isNegative)
    {
        parsedValue = -parsedValue;
    }

    return parsedValue;
}

exo_damage_digit_to_int(ch)
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
*/
exo_damage_get_base_damage(mark)
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
        return 2500 + int(((((mark - 2) * 7500) + 9) / 18));
    }

    return 10000 + int((mark - 20) * 1400);
}

/* ---------------- DEBUG HELPERS ---------------- */

exo_debug(msg)
{
    if(!isdefined(level.exo_damage_debug) || !level.exo_damage_debug)
    {
        return;
    }

    println("ExoWeaponDamage[DBG]: " + msg);
}

exo_should_log_hit(hitIndex)
{
    if(!isdefined(level.exo_damage_debug) || !level.exo_damage_debug)
    {
        return false;
    }

    if(hitIndex <= 80)
    {
        return true;
    }

    return (hitIndex % 50) == 0;
}

exo_should_dump_modifyweapondamage()
{
    if(!isdefined(level.exo_damage_debug) || !level.exo_damage_debug)
    {
        return false;
    }
    if(!isdefined(level.time))
    {
        return false;
    }
    if(!isdefined(level.exo_damage_debug_last_modifyweapondamage_dump))
    {
        level.exo_damage_debug_last_modifyweapondamage_dump = 0;
    }

    if((level.time - level.exo_damage_debug_last_modifyweapondamage_dump) < 15000)
    {
        return false;
    }

    level.exo_damage_debug_last_modifyweapondamage_dump = level.time;
    return true;
}

exo_dump_modifyweapondamage_keys()
{
    if(!isdefined(level.modifyweapondamage))
    {
        exo_debug("dump modifyweapondamage: table undefined");
        return;
    }

    keys = getarraykeys(level.modifyweapondamage);
    accepted = 0;
    rejected = 0;

    exo_debug("dump modifyweapondamage: total keys=" + keys.size);

    maxPrint = 200;
    printed = 0;

    for(i = 0; i < keys.size; i++)
    {
        key = keys[i];
        if(exo_damage_is_zombie_weapon_key(key))
        {
            accepted++;
            if(printed < maxPrint)
            {
                exo_debug("MWD[ACCEPT] " + key);
                printed++;
            }
        }
        else
        {
            rejected++;
        }
    }

    exo_debug("dump modifyweapondamage summary: accepted=" + accepted + " rejected=" + rejected + " printed=" + printed);
}

exo_join_keys(keys)
{
    if(!isdefined(keys) || keys.size <= 0)
    {
        return "<none>";
    }

    out = "";
    for(i = 0; i < keys.size; i++)
    {
        if(i > 0)
        {
            out += ", ";
        }
        out += keys[i];
    }

    return out;
}

exo_to_text(value)
{
    if(!isdefined(value))
    {
        return "<undefined>";
    }

    return value + "";
}

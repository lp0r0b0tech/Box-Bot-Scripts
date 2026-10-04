// ============================================================
// S1x Combat Training - Veteran difficulty dvar + Elite guns (MP)
//
// Install: s1/scripts/mp/s1_scripts_mp_veteran_difficulty.gsc
// Campaign companion: s1_scripts_sp_veteran_difficulty.gsc (scripts/sp)
//
// Dvars (set in console / server.cfg BEFORE the map loads):
//   scr_difficulty_override "veteran"
//       off          - leave bots on the lobby difficulty
//       recruit | regular | hardened | veteran
//                    - exact native private match profile
//       veteran_plus - native Veteran profile, then tightened by
//                      scr_difficulty_veteran_plus_scale
//   scr_difficulty_veteran_plus_scale "0.5"
//       0.0 - 1.0, multiplier applied to Veteran aim spread and
//       fire delays (lower = harder). Only used by veteran_plus.
//   scr_ct_bot_elite_guns "1"
//       1 = bots spawn with Elite (loot) weapon variants
//   scr_ct_bot_elite_variants "7 8 9"
//       space separated loot indices (0-9) treated as Elite
//
// Do not load together with autobots_combat_training.gsc; that
// script forces its own "impossible" bot settings.
// ============================================================

init()
{
    gametype = toLower(getdvar("g_gametype"));

    // Exo Zombies / Exo Survival use their own bot/weapon logic.
    if (gametype == "zombies" || gametype == "horde")
        return;

    initDvarDefault("scr_difficulty_override", "veteran");
    initDvarDefault("scr_difficulty_veteran_plus_scale", "0.5");
    initDvarDefault("scr_ct_bot_elite_guns", "1");
    initDvarDefault("scr_ct_bot_elite_variants", "7 8 9");

    initEliteWeaponTables();

    level thread onPlayerConnect();
    level thread botDifficultyMonitor();
}

initDvarDefault(dvar, value)
{
    if (getdvar(dvar) == "")
        setdvar(dvar, value);
}

// --------------------------
// Difficulty
// --------------------------
getDifficultyProfile()
{
    profile = toLower(getdvar("scr_difficulty_override"));

    if (profile == "easy")
        profile = "recruit";
    else if (profile == "normal")
        profile = "regular";

    if (profile == "recruit" || profile == "regular" ||
        profile == "hardened" || profile == "veteran" ||
        profile == "veteran_plus")
        return profile;

    return "off";
}

getNativeDifficulty(profile)
{
    if (profile == "veteran_plus")
        return "veteran";

    return profile;
}

getVeteranPlusScale()
{
    scale = getdvarfloat("scr_difficulty_veteran_plus_scale");

    if (scale < 0.0)
        scale = 0.0;

    if (scale > 1.0)
        scale = 1.0;

    return scale;
}

initVeteranPlusKeys()
{
    if (isDefined(level.sdoVeteranPlusKeys))
        return;

    level.sdoVeteranPlusKeys = [];
    level.sdoVeteranPlusKeys[level.sdoVeteranPlusKeys.size] = "minInaccuracy";
    level.sdoVeteranPlusKeys[level.sdoVeteranPlusKeys.size] = "maxInaccuracy";
    level.sdoVeteranPlusKeys[level.sdoVeteranPlusKeys.size] = "minFireTime";
    level.sdoVeteranPlusKeys[level.sdoVeteranPlusKeys.size] = "maxFireTime";
    level.sdoVeteranPlusKeys[level.sdoVeteranPlusKeys.size] = "maxGraceDelayFireTime";
}

// Must be called right after BotSetDifficulty("veteran") so the
// cached values are the untouched private match Veteran values.
cacheVeteranValues()
{
    if (isDefined(level.sdoVeteranValues))
        return;

    initVeteranPlusKeys();

    values = [];

    foreach (key in level.sdoVeteranPlusKeys)
    {
        value = self botgetdifficultysetting(key);

        if (isDefined(value))
            values[key] = value;
    }

    level.sdoVeteranValues = values;
}

applyVeteranPlus()
{
    initVeteranPlusKeys();
    scale = getVeteranPlusScale();

    foreach (key in level.sdoVeteranPlusKeys)
    {
        if (!isDefined(level.sdoVeteranValues[key]))
            continue;

        self botsetdifficultysetting(key, level.sdoVeteranValues[key] * scale);
    }
}

applyBotDifficulty(forceSettings)
{
    if (!isDefined(self) || !isbot(self))
        return;

    profile = getDifficultyProfile();

    if (profile == "off")
    {
        self.sdoAppliedProfile = undefined;
        return;
    }

    nativeDifficulty = getNativeDifficulty(profile);
    current = self botgetdifficulty();

    profileChanged = !isDefined(self.sdoAppliedProfile) ||
        self.sdoAppliedProfile != profile;

    // BotSetDifficulty reloads the stock private match settings,
    // which also clears any previous veteran_plus tweaks.
    if (!isDefined(current) || current != nativeDifficulty || profileChanged)
    {
        self botsetdifficulty(nativeDifficulty);
        profileChanged = true;

        if (nativeDifficulty == "veteran")
            self cacheVeteranValues();
    }

    if (profile == "veteran_plus" && (profileChanged || forceSettings))
    {
        if (!isDefined(level.sdoVeteranValues))
        {
            self botsetdifficulty("veteran");
            self cacheVeteranValues();
        }

        // Scale is always applied to the cached clean Veteran values,
        // so it never stacks.
        self applyVeteranPlus();
    }

    self.sdoAppliedProfile = profile;
}

// The stock bot connect monitor can push the lobby difficulty back
// onto bots, so keep re-asserting the dvar profile.
botDifficultyMonitor()
{
    level endon("game_ended");

    for (;;)
    {
        wait 1.0;

        if (!isDefined(level.players))
            continue;

        foreach (player in level.players)
        {
            if (isDefined(player) && isbot(player))
                player applyBotDifficulty(false);
        }
    }
}

// --------------------------
// Player hooks
// --------------------------
onPlayerConnect()
{
    for (;;)
    {
        level waittill("connected", player);

        if (isbot(player))
            player thread onBotSpawned();
    }
}

onBotSpawned()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("spawned_player");

        // Let the stock bot_think / loadout code finish first.
        wait 0.1;

        // bot_think re-calls BotSetDifficulty every life, which
        // resets custom settings, so re-apply on every spawn.
        self applyBotDifficulty(true);

        if (getdvarint("scr_ct_bot_elite_guns") == 1)
            self giveEliteLoadout();
    }
}

// --------------------------
// Elite guns
// --------------------------
initEliteWeaponTables()
{
    // Base names of S1 MP weapons that ship with loot0-loot9 variants.
    level.sdoElitePrimaries = [];
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "ak12";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "arx160";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "bal27";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "hbra3";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "himar";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "m182spr";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "kf5";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "asm1";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "sn6";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "hmr9";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "sac3";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "lsat";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "asaw";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "exoxmg";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "em1";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "epm3";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "uts19";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "maul";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "mors";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "gm6";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "thor";
    level.sdoElitePrimaries[level.sdoElitePrimaries.size] = "m990";

    level.sdoEliteSecondaries = [];
    level.sdoEliteSecondaries[level.sdoEliteSecondaries.size] = "titan45";
    level.sdoEliteSecondaries[level.sdoEliteSecondaries.size] = "pbw";
    level.sdoEliteSecondaries[level.sdoEliteSecondaries.size] = "rw1";
    level.sdoEliteSecondaries[level.sdoEliteSecondaries.size] = "vbr";
    level.sdoEliteSecondaries[level.sdoEliteSecondaries.size] = "mp11";
}

getEliteVariantIndices()
{
    indices = [];
    tokens = strtok(getdvar("scr_ct_bot_elite_variants"), " ,");

    foreach (token in tokens)
    {
        index = int(token);

        // Only loot0-loot9 exist for these weapons.
        if (index >= 0 && index <= 9)
            indices[indices.size] = index;
    }

    if (indices.size == 0)
        indices[0] = 9;

    return indices;
}

pickEliteWeapon(baseNames, indices)
{
    base = baseNames[randomint(baseNames.size)];
    index = indices[randomint(indices.size)];

    return "iw5_" + base + "loot" + index + "_mp";
}

giveEliteLoadout()
{
    if (!isalive(self))
        return;

    indices = getEliteVariantIndices();
    primary = pickEliteWeapon(level.sdoElitePrimaries, indices);
    secondary = pickEliteWeapon(level.sdoEliteSecondaries, indices);

    foreach (weapon in self getweaponslistprimaries())
        self takeweapon(weapon);

    self giveweapon(primary);
    self givemaxammo(primary);
    self giveweapon(secondary);
    self givemaxammo(secondary);
    self switchtoweaponimmediate(primary);
}

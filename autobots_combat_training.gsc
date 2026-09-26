// ============================================================
// Autobots Combat Training Script (MP-ONLY, HARDENED v8)
// - Locks native bot_difficulty to VETERAN
// - Keeps "ultra" as the internal script profile
// - Adds autobots_bot_difficulty impossible
// - Applies maxed impossible bot settings with reactionTime = 0
// ============================================================
#include scripts/mp/_bots;

// --------------------------
// Config
// --------------------------
combatTrainingForce = true;
combatTrainingMaxPlayers = 12;
dedicatedMaxPlayers = 18;

defaultBotDifficulty = "ultra";
lockedBotDifficulty = "ultra";

defaultBotLevel = 50;
defaultBotPrestige = 23;

awStyleEnable = true;
awPressureSpawnDelay = 0.15;
awTrimDelay = 0.03;
awHealthRegenOnSpawn = true;

opWeaponsEnable = true;
opPrimaryWeapon = "iw5_m4_mp";
opPrimaryAttachment = "reflex";
opPrimaryVariant = "iw5_m4_mp_reflex_xmags_camo11";
opSecondaryWeapon = "iw5_44magnum_mp";
opSecondaryVariant = "iw5_44magnum_mp_akimbo_xmags";
opLethal = "frag_grenade_mp";
opTactical = "flash_grenade_mp";
opGiveFullAmmo = true;

compatUseSetPrestigeNative = true;
compatUseSetRankNative = true;
compatUseBotDropNative = true;

debugAutobots = true;
debugVerbose = false;
debugHeartbeatInterval = 5.0;

botDifficultyEnforcerInterval = 0.25;
spawnFailBackoff = 0.50;
maxSpawnAttemptsPerTick = 8;

// Fallback modifiers used only when the Veteran/impossible layer is disabled.
rageBotAccuracy = 9.99;
rageBotReactionTime = 0.000;
rageBotMaxHealth = 2500;
rageBotAggression = 9.99;

// Capture native Veteran settings before applying custom impossible settings.
useExactVeteranPrivateMatchValues = true;

// --------------------------
// Harder-than-Veteran dvar
// --------------------------
//
// Native bot_difficulty remains "veteran", the highest supported
// engine-native profile. This mod-owned dvar applies the impossible layer.
//
// Server config:
// set bot_difficulty veteran
// set autobots_bot_difficulty impossible
//
harderThanVeteranEnable = true;
harderThanVeteranDvar = "autobots_bot_difficulty";
harderThanVeteranProfile = "impossible";

// --------------------------
// Maxed impossible settings
// --------------------------
impossibleMinInaccuracy = 0.00;
impossibleMaxInaccuracy = 0.00;

// Native reaction time is in milliseconds.
// 0 gives the fastest possible reaction.
impossibleReactionTimeMs = 0;

impossibleMinFireTime = 0;
impossibleMaxFireTime = 0;
impossibleMinGraceDelayFireTime = 0;
impossibleMaxGraceDelayFireTime = 0;

impossibleMeleeReactAllowed = 1;
impossibleMeleeReactionTime = 0;
impossibleThrowKnifeChance = 1.00;
impossibleStrafeChance = 1.00;
impossibleDiveChance = 1.00;
impossibleAllowGrenades = 1;
impossibleAdsAllowed = 1;

impossibleAvoidSkyPercent = 0;
impossibleVisionBlinded = 0.0;
impossibleHearingDeaf = 0.0;

impossibleBotAccuracy = 9.99;
impossibleReactionTime = 0.000;
impossibleBotAggression = 9.99;
impossibleMaxHealth = 2500;

// --------------------------
// Sanity and counting
// --------------------------
sanityTestEnable = true;
sanityTestDuration = 60.0;
sanityTestSampleInterval = 5.0;

countSpectatorsAsPlayers = false;
countConnectingAsPlayers = false;

strictBotIdentityMode = true;
spawnConfirmPhase1Delay = 0.05;
spawnConfirmPhase2Delay = 0.10;
spawnConfirmPhase3Delay = 0.20;
trimSafetyMaxDrops = 32;
countStateLogUnknownOnce = true;

// --------------------------
// Init
// --------------------------
init()
{
    if (!shouldRunAutobotsHere())
    {
        dbg("init(): disabled for this mode/map");
        return;
    }

    if (combatTrainingMaxPlayers < 0)
        combatTrainingMaxPlayers = 0;

    if (dedicatedMaxPlayers < 0)
        dedicatedMaxPlayers = 0;

    if (awPressureSpawnDelay < 0.05)
        awPressureSpawnDelay = 0.05;

    if (awTrimDelay < 0.01)
        awTrimDelay = 0.01;

    if (debugHeartbeatInterval < 0.2)
        debugHeartbeatInterval = 0.2;

    if (botDifficultyEnforcerInterval < 0.10)
        botDifficultyEnforcerInterval = 0.10;

    if (rageBotAccuracy < 0.0)
        rageBotAccuracy = 0.0;

    if (rageBotAccuracy > 9.99)
        rageBotAccuracy = 9.99;

    if (rageBotReactionTime < 0.0)
        rageBotReactionTime = 0.0;

    if (rageBotReactionTime > 1.0)
        rageBotReactionTime = 1.0;

    if (rageBotMaxHealth < 100)
        rageBotMaxHealth = 100;

    if (rageBotMaxHealth > 2500)
        rageBotMaxHealth = 2500;

    if (rageBotAggression < 0.0)
        rageBotAggression = 0.0;

    if (rageBotAggression > 9.99)
        rageBotAggression = 9.99;

    if (impossibleMinInaccuracy < 0.0)
        impossibleMinInaccuracy = 0.0;

    if (impossibleMaxInaccuracy < impossibleMinInaccuracy)
        impossibleMaxInaccuracy = impossibleMinInaccuracy;

    if (impossibleReactionTimeMs < 0)
        impossibleReactionTimeMs = 0;

    if (impossibleMinFireTime < 0)
        impossibleMinFireTime = 0;

    if (impossibleMaxFireTime < impossibleMinFireTime)
        impossibleMaxFireTime = impossibleMinFireTime;

    if (impossibleMinGraceDelayFireTime < 0)
        impossibleMinGraceDelayFireTime = 0;

    if (impossibleMaxGraceDelayFireTime < impossibleMinGraceDelayFireTime)
        impossibleMaxGraceDelayFireTime = impossibleMinGraceDelayFireTime;

    if (impossibleMeleeReactionTime < 0)
        impossibleMeleeReactionTime = 0;

    if (impossibleThrowKnifeChance < 0.0)
        impossibleThrowKnifeChance = 0.0;

    if (impossibleThrowKnifeChance > 1.0)
        impossibleThrowKnifeChance = 1.0;

    if (impossibleStrafeChance < 0.0)
        impossibleStrafeChance = 0.0;

    if (impossibleStrafeChance > 1.0)
        impossibleStrafeChance = 1.0;

    if (impossibleDiveChance < 0.0)
        impossibleDiveChance = 0.0;

    if (impossibleDiveChance > 1.0)
        impossibleDiveChance = 1.0;

    if (impossibleBotAccuracy < 0.0)
        impossibleBotAccuracy = 0.0;

    if (impossibleBotAccuracy > 9.99)
        impossibleBotAccuracy = 9.99;

    if (impossibleReactionTime < 0.0)
        impossibleReactionTime = 0.0;

    if (impossibleReactionTime > 1.0)
        impossibleReactionTime = 1.0;

    if (impossibleBotAggression < 0.0)
        impossibleBotAggression = 0.0;

    if (impossibleBotAggression > 9.99)
        impossibleBotAggression = 9.99;

    if (impossibleMaxHealth < 100)
        impossibleMaxHealth = 100;

    if (impossibleMaxHealth > 2500)
        impossibleMaxHealth = 2500;

    if (spawnFailBackoff < 0.10)
        spawnFailBackoff = 0.10;

    if (maxSpawnAttemptsPerTick < 1)
        maxSpawnAttemptsPerTick = 1;

    if (sanityTestDuration < 5.0)
        sanityTestDuration = 5.0;

    if (sanityTestSampleInterval < 1.0)
        sanityTestSampleInterval = 1.0;

    if (defaultBotPrestige < 0)
        defaultBotPrestige = 0;

    if (spawnConfirmPhase1Delay < 0.01)
        spawnConfirmPhase1Delay = 0.01;

    if (spawnConfirmPhase2Delay < 0.01)
        spawnConfirmPhase2Delay = 0.01;

    if (spawnConfirmPhase3Delay < 0.01)
        spawnConfirmPhase3Delay = 0.01;

    if (trimSafetyMaxDrops < 1)
        trimSafetyMaxDrops = 1;

    if (!isDefined(level.autobotsWarnOnce))
        level.autobotsWarnOnce = [];

    if (!isDefined(level.autobotAdjusting))
        level.autobotAdjusting = false;

    if (!combatTrainingForce)
        level.combatTraining = detectCombatTraining();
    else
        level.combatTraining = true;

    lockedBotDifficulty = "ultra";
    defaultBotDifficulty = "ultra";

    // Veteran is the highest native engine difficulty.
    setdvar("bot_difficulty", "veteran");

    if (harderThanVeteranEnable)
        setdvar(harderThanVeteranDvar, harderThanVeteranProfile);

    initVeteranPrivateMatchSettingKeys();

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();

    if (sanityTestEnable)
        level thread run60SecondSanityTest();
}

// --------------------------
// Native Veteran settings
// --------------------------
initVeteranPrivateMatchSettingKeys()
{
    level.autobotVeteranSettingKeys = [];

    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "advancedPersonality";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "strategyLevel";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "adsAllowed";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "allowGrenades";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "minInaccuracy";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "maxInaccuracy";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "reactionTime";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "minFireTime";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "maxFireTime";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "minGraceDelayFireTime";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "maxGraceDelayFireTime";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "meleeDist";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "meleeChargeDist";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "meleeReactAllowed";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "meleeReactionTime";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "throwKnifeChance";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "strafeChance";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "diveChance";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "visionBlinded";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "hearingDeaf";
    level.autobotVeteranSettingKeys[level.autobotVeteranSettingKeys.size] = "avoidSkyPercent";
}

cacheNativeVeteranPrivateMatchValues()
{
    if (!useExactVeteranPrivateMatchValues)
        return;

    if (!isDefined(level.autobotVeteranSettingKeys))
        initVeteranPrivateMatchSettingKeys();

    if (!isDefined(level.autobotVeteranPrivateMatchValues))
        level.autobotVeteranPrivateMatchValues = [];

    if (!isDefined(self) || !(self isBotEntity()))
        return;

    self botsetdifficulty("veteran");

    foreach (key in level.autobotVeteranSettingKeys)
    {
        value = self botgetdifficultysetting(key);

        if (isDefined(value))
            level.autobotVeteranPrivateMatchValues[key] = value;
    }

    if (debugAutobots && debugVerbose)
        dbg("cached native Veteran difficulty settings");
}

applyNativeVeteranPrivateMatchValues()
{
    if (!useExactVeteranPrivateMatchValues)
        return;

    if (!isDefined(level.autobotVeteranPrivateMatchValues))
        cacheNativeVeteranPrivateMatchValues();

    if (!isDefined(level.autobotVeteranPrivateMatchValues))
        return;

    foreach (key in level.autobotVeteranSettingKeys)
    {
        if (!isDefined(level.autobotVeteranPrivateMatchValues[key]))
            continue;

        self botsetdifficultysetting(
            key,
            level.autobotVeteranPrivateMatchValues[key]
        );
    }
}

// --------------------------
// Impossible profile
// --------------------------
applyHarderThanVeteranDvarValues()
{
    if (!harderThanVeteranEnable)
        return;

    profile = getdvar(harderThanVeteranDvar);

    if (!isDefined(profile) || profile == "")
        profile = harderThanVeteranProfile;

    profile = toLower(profile);

    if (profile != "impossible" &&
        profile != "nightmare" &&
        profile != "ultra" &&
        profile != "rage")
    {
        return;
    }

    // Keep the native engine dvar pinned to Veteran.
    if (getdvar("bot_difficulty") != "veteran")
        setdvar("bot_difficulty", "veteran");

    self botsetdifficultysetting(
        "minInaccuracy",
        impossibleMinInaccuracy
    );

    self botsetdifficultysetting(
        "maxInaccuracy",
        impossibleMaxInaccuracy
    );

    // Native reaction time is in milliseconds.
    self botsetdifficultysetting(
        "reactionTime",
        impossibleReactionTimeMs
    );

    self botsetdifficultysetting(
        "minFireTime",
        impossibleMinFireTime
    );

    self botsetdifficultysetting(
        "maxFireTime",
        impossibleMaxFireTime
    );

    self botsetdifficultysetting(
        "minGraceDelayFireTime",
        impossibleMinGraceDelayFireTime
    );

    self botsetdifficultysetting(
        "maxGraceDelayFireTime",
        impossibleMaxGraceDelayFireTime
    );

    self botsetdifficultysetting(
        "meleeReactAllowed",
        impossibleMeleeReactAllowed
    );

    self botsetdifficultysetting(
        "meleeReactionTime",
        impossibleMeleeReactionTime
    );

    self botsetdifficultysetting(
        "throwKnifeChance",
        impossibleThrowKnifeChance
    );

    self botsetdifficultysetting(
        "strafeChance",
        impossibleStrafeChance
    );

    self botsetdifficultysetting(
        "diveChance",
        impossibleDiveChance
    );

    self botsetdifficultysetting(
        "allowGrenades",
        impossibleAllowGrenades
    );

    self botsetdifficultysetting(
        "adsAllowed",
        impossibleAdsAllowed
    );

    self botsetdifficultysetting(
        "avoidSkyPercent",
        impossibleAvoidSkyPercent
    );

    self botsetdifficultysetting(
        "visionBlinded",
        impossibleVisionBlinded
    );

    self botsetdifficultysetting(
        "hearingDeaf",
        impossibleHearingDeaf
    );

    self.botAccuracy = impossibleBotAccuracy;
    self.reactionTime = impossibleReactionTime;
    self.botAggression = impossibleBotAggression;
    self.maxHealth = impossibleMaxHealth;

    if (awHealthRegenOnSpawn)
        safeFullHeal(self);
}

// --------------------------
// Mode and utility helpers
// --------------------------
shouldRunAutobotsHere()
{
    if (isDefined(level.mapname))
    {
        mn = toLower(level.mapname);

        if (isSubStr(mn, "exo survival") ||
            isSubStr(mn, "exo zombies"))
        {
            return false;
        }

        if (isSubStr(mn, "cp_") ||
            isSubStr(mn, "survival"))
        {
            return false;
        }

        if (isSubStr(mn, "zm_") ||
            isSubStr(mn, "zombies"))
        {
            return false;
        }
    }

    gt = "";

    if (isDefined(level.gametype))
        gt = toLower(level.gametype);

    if (isSubStr(gt, "survival") ||
        isSubStr(gt, "zombie") ||
        isSubStr(gt, "infect"))
    {
        return false;
    }

    if (isDefined(level.playlist))
    {
        pl = toLower(level.playlist);

        if (isSubStr(pl, "survival") ||
            isSubStr(pl, "zombie") ||
            isSubStr(pl, "exo"))
        {
            return false;
        }
    }

    return true;
}

isSubStr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle))
        return false;

    return issubstr(hay, needle);
}

detectCombatTraining()
{
    gt = "";

    if (isDefined(level.gametype))
        gt = toLower(level.gametype);

    if (isSubStr(gt, "combat") ||
        isSubStr(gt, "training"))
    {
        return true;
    }

    mn = "";

    if (isDefined(level.mapname))
        mn = toLower(level.mapname);

    if (isSubStr(mn, "combat") ||
        isSubStr(mn, "training"))
    {
        return true;
    }

    return false;
}

dbg(msg)
{
    if (!debugAutobots)
        return;

    if (!isDefined(msg))
        msg = "undefined";

    if (isDefined(level) && isDefined(level.time))
        println("[AUTOBOTS][" + level.time + "] " + msg);
    else
        println("[AUTOBOTS] " + msg);
}

warnOnce(key, msg)
{
    if (!debugAutobots)
        return;

    if (!isDefined(level.autobotsWarnOnce))
        level.autobotsWarnOnce = [];

    if (!isDefined(key))
        key = "unknown_key";

    if (isDefined(level.autobotsWarnOnce[key]))
        return;

    level.autobotsWarnOnce[key] = true;
    dbg("WARN_ONCE " + key + ": " + msg);
}

safeGetGuid(ent)
{
    if (!isDefined(ent))
        return "unknown";

    g = ent getguid();

    if (!isDefined(g) || g == "")
        return "unknown";

    return g;
}

isBotEntity()
{
    if (isDefined(self.pers) &&
        isDefined(self.pers["isBot"]))
    {
        return self.pers["isBot"];
    }

    guidFallback = safeGetGuid(self);

    warnOnce(
        "isBot_missing_" + guidFallback,
        "pers[\"isBot\"] missing for guid=" + guidFallback
    );

    g = self getguid();

    if (isDefined(g))
    {
        gl = toLower(g);

        if (isSubStr(gl, "bot"))
            return true;
    }

    if (!strictBotIdentityMode && isDefined(self.name))
    {
        nl = toLower(self.name);

        if (isSubStr(nl, "bot ") ||
            isSubStr(nl, "[bot]"))
        {
            return true;
        }
    }

    return false;
}

safeFullHeal(ent)
{
    if (!isDefined(ent) ||
        !isDefined(ent.maxHealth) ||
        !isDefined(ent.health))
    {
        return;
    }

    ent.health = ent.maxHealth;
}

// --------------------------
// Difficulty
// --------------------------
resolveBotSkillDifficulty(difficulty)
{
    if (!isDefined(difficulty))
        return "veteran";

    difficulty = toLower(difficulty);

    if (difficulty == "recruit")
        return "recruit";

    if (difficulty == "regular")
        return "regular";

    if (difficulty == "hardened")
        return "hardened";

    if (difficulty == "veteran")
        return "veteran";

    if (difficulty == "ultra")
        return "veteran";

    warnOnce(
        "invalid_bot_skill",
        "Unknown difficulty '" + difficulty + "'; using veteran"
    );

    return "veteran";
}

setBotDifficulty(difficulty)
{
    nativeDifficulty = resolveBotSkillDifficulty(difficulty);
    currentDifficulty = self botgetdifficulty();

    if (!isDefined(currentDifficulty) ||
        currentDifficulty != nativeDifficulty)
    {
        self botsetdifficulty(nativeDifficulty);
    }

    if (nativeDifficulty == "veteran")
    {
        if (useExactVeteranPrivateMatchValues)
        {
            cacheNativeVeteranPrivateMatchValues();
            applyNativeVeteranPrivateMatchValues();
        }

        applyHarderThanVeteranDvarValues();
        return;
    }

    self.botAccuracy = rageBotAccuracy;
    self.reactionTime = rageBotReactionTime;
    self.maxHealth = rageBotMaxHealth;
    self.botAggression = rageBotAggression;
}

// --------------------------
// Loadout
// --------------------------
applyOpLoadout(ent)
{
    if (!opWeaponsEnable || !isDefined(ent))
        return;

    if (!isDefined(ent.pers))
        ent.pers = [];

    primaryToGive = "";

    if (isDefined(opPrimaryVariant) &&
        opPrimaryVariant != "")
    {
        primaryToGive = opPrimaryVariant;
    }
    else if (isDefined(opPrimaryWeapon) &&
             opPrimaryWeapon != "")
    {
        primaryToGive = opPrimaryWeapon;

        if (isDefined(opPrimaryAttachment) &&
            opPrimaryAttachment != "")
        {
            primaryToGive =
                opPrimaryWeapon + "_" + opPrimaryAttachment;
        }
    }

    secondaryToGive = "";

    if (isDefined(opSecondaryVariant) &&
        opSecondaryVariant != "")
    {
        secondaryToGive = opSecondaryVariant;
    }
    else if (isDefined(opSecondaryWeapon) &&
             opSecondaryWeapon != "")
    {
        secondaryToGive = opSecondaryWeapon;
    }

    desiredSig =
        primaryToGive + "|" +
        secondaryToGive + "|" +
        opLethal + "|" +
        opTactical;

    if (isDefined(ent.pers["autobot_loadout_sig"]) &&
        ent.pers["autobot_loadout_sig"] == desiredSig)
    {
        return;
    }

    ent takeallweapons();

    if (primaryToGive != "")
    {
        ent giveweapon(primaryToGive);
        ent switchtoweapon(primaryToGive);

        if (opGiveFullAmmo)
        {
            ent givemaxammo(primaryToGive);

            if (primaryToGive != opPrimaryWeapon)
                ent givemaxammo(opPrimaryWeapon);
        }
    }

    if (secondaryToGive != "")
    {
        ent giveweapon(secondaryToGive);

        if (opGiveFullAmmo)
        {
            ent givemaxammo(secondaryToGive);

            if (secondaryToGive != opSecondaryWeapon &&
                isDefined(opSecondaryWeapon) &&
                opSecondaryWeapon != "")
            {
                ent givemaxammo(opSecondaryWeapon);
            }
        }
    }

    if (isDefined(opLethal) &&
        opLethal != "")
    {
        ent giveweapon(opLethal);
    }

    if (isDefined(opTactical) &&
        opTactical != "")
    {
        ent giveweapon(opTactical);
    }

    ent.pers["autobot_loadout_sig"] = desiredSig;
}

// --------------------------
// Player counting
// --------------------------
isPlayerCountable(ent)
{
    if (!isDefined(ent))
        return false;

    if (!countSpectatorsAsPlayers &&
        isDefined(ent.sessionstate))
    {
        st = toLower(ent.sessionstate);

        if (st == "spectator" ||
            st == "intermission")
        {
            return false;
        }
    }

    if (!countConnectingAsPlayers &&
        isDefined(ent.pers) &&
        isDefined(ent.pers["connected"]))
    {
        c = toLower(ent.pers["connected"]);

        if (c != "connected")
            return false;
    }

    return true;
}

countTotalPlayersForCap()
{
    if (!isDefined(level.players))
        return 0;

    n = 0;

    foreach (p in level.players)
    {
        if (isPlayerCountable(p))
            n++;
    }

    return n;
}

countBots()
{
    if (!isDefined(level.players))
        return 0;

    n = 0;

    foreach (p in level.players)
    {
        if (isDefined(p) &&
            (p isBotEntity()))
        {
            n++;
        }
    }

    return n;
}

countHumans()
{
    if (!isDefined(level.players))
        return 0;

    n = 0;

    foreach (p in level.players)
    {
        if (isDefined(p) &&
            !(p isBotEntity()))
        {
            n++;
        }
    }

    return n;
}

// --------------------------
// Bot persistence
// --------------------------
setBotRankCompat(rankValue)
{
    r = int(rankValue);
    self.rank = r;

    if (!isDefined(self.pers))
        self.pers = [];

    self.pers["rank"] = r;

    if (compatUseSetRankNative)
        self setrank(r);
}

applyBotPrestigeSetting()
{
    if (!isDefined(self.pers))
        self.pers = [];

    self.pers["prestige"] = defaultBotPrestige;

    if (compatUseSetPrestigeNative)
        self setprestige(defaultBotPrestige);
}

applyAutobotDifficulty(diff)
{
    if (!isDefined(diff))
        diff = lockedBotDifficulty;

    if (!isDefined(self.pers))
        self.pers = [];

    self setBotDifficulty(diff);
    applyOpLoadout(self);

    self.pers["autobot_diff_applied"] = diff;
}

applyDifficultyToAllBots(forceWritePers)
{
    if (getdvar("bot_difficulty") != "veteran")
        setdvar("bot_difficulty", "veteran");

    if (harderThanVeteranEnable &&
        getdvar(harderThanVeteranDvar) != harderThanVeteranProfile)
    {
        setdvar(
            harderThanVeteranDvar,
            harderThanVeteranProfile
        );
    }

    if (!isDefined(level.players))
        return;

    foreach (p in level.players)
    {
        if (!isDefined(p) ||
            !(p isBotEntity()))
        {
            continue;
        }

        needsApply = forceWritePers;

        if (!needsApply)
        {
            if (!isDefined(p.pers) ||
                !isDefined(p.pers["autobot_diff_applied"]) ||
                p.pers["autobot_diff_applied"] != lockedBotDifficulty)
            {
                needsApply = true;
            }
        }

        if (needsApply)
        {
            p applyAutobotDifficulty(lockedBotDifficulty);
            p setBotRankCompat(defaultBotLevel);
            p applyBotPrestigeSetting();

            if (!isDefined(p.pers))
                p.pers = [];

            p.pers["autobot_diff_applied"] =
                lockedBotDifficulty;

            if (awHealthRegenOnSpawn)
                safeFullHeal(p);
        }
        else
        {
            p setBotDifficulty(lockedBotDifficulty);
        }
    }
}

// --------------------------
// Player connections
// --------------------------
onPlayerConnect()
{
    level endon("game_ended");

    for (;;)
    {
        level waittill("connected", player);

        if (!isDefined(player))
            continue;

        if (player isBotEntity())
        {
            player applyAutobotDifficulty(lockedBotDifficulty);
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();

            if (!isDefined(player.pers))
                player.pers = [];

            player.pers["autobot_diff_applied"] =
                lockedBotDifficulty;

            if (awHealthRegenOnSpawn)
                safeFullHeal(player);
        }
        else if (!level.combatTraining)
        {
            trimBotsToTarget();
        }
    }
}

// --------------------------
// Spawning and trimming
// --------------------------
spawnBotsSafe(amount)
{
    if (!isDefined(amount) ||
        amount <= 0)
    {
        return false;
    }

    beforePlayers = countTotalPlayersForCap();
    beforeBots = countBots();

    spawn_bots(amount, "autoassign");

    wait spawnConfirmPhase1Delay;

    if (countTotalPlayersForCap() > beforePlayers ||
        countBots() > beforeBots)
    {
        return true;
    }

    wait spawnConfirmPhase2Delay;

    if (countTotalPlayersForCap() > beforePlayers ||
        countBots() > beforeBots)
    {
        return true;
    }

    wait spawnConfirmPhase3Delay;

    if (countTotalPlayersForCap() > beforePlayers ||
        countBots() > beforeBots)
    {
        return true;
    }

    return false;
}

pickBotForDrop()
{
    bots = [];

    if (!isDefined(level.players))
        return undefined;

    foreach (p in level.players)
    {
        if (isDefined(p) &&
            (p isBotEntity()))
        {
            bots[bots.size] = p;
        }
    }

    if (bots.size <= 0)
        return undefined;

    return bots[randomint(bots.size)];
}

kickOneBot()
{
    p = pickBotForDrop();

    if (!isDefined(p))
        return false;

    if (!compatUseBotDropNative)
        return false;

    p bot_drop();

    return true;
}

trimBotsToTarget()
{
    if (!isDefined(level.autobotAdjusting))
        level.autobotAdjusting = false;

    hadLock = level.autobotAdjusting;

    if (!hadLock)
        level.autobotAdjusting = true;

    target =
        level.combatTraining
        ? combatTrainingMaxPlayers
        : dedicatedMaxPlayers;

    if (target < 0)
        target = 0;

    safety = trimSafetyMaxDrops;

    while (countTotalPlayersForCap() > target &&
           countBots() > 0 &&
           safety > 0)
    {
        if (!kickOneBot())
            break;

        safety--;

        wait (awStyleEnable ? awTrimDelay : 0.05);
    }

    if (!hadLock)
        level.autobotAdjusting = false;
}

serverBotFill()
{
    level endon("game_ended");

    wait 0.05;

    for (;;)
    {
        if (!isDefined(level.autobotAdjusting))
            level.autobotAdjusting = false;

        if (level.autobotAdjusting)
        {
            wait 0.10;
            continue;
        }

        level.autobotAdjusting = true;

        target =
            level.combatTraining
            ? combatTrainingMaxPlayers
            : dedicatedMaxPlayers;

        if (target < 0)
            target = 0;

        attempts = 0;

        while (countTotalPlayersForCap() < target &&
               attempts < maxSpawnAttemptsPerTick)
        {
            if (countTotalPlayersForCap() >= target)
                break;

            attempts++;

            if (!spawnBotsSafe(1))
                wait spawnFailBackoff;
            else
                wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        if (!level.combatTraining &&
            countTotalPlayersForCap() > target)
        {
            trimBotsToTarget();
        }

        level.autobotAdjusting = false;

        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

// --------------------------
// Difficulty enforcement
// --------------------------
delayedBotDifficultyApply()
{
    level endon("game_ended");

    wait 0.5;

    setdvar("bot_difficulty", "veteran");

    if (harderThanVeteranEnable)
    {
        setdvar(
            harderThanVeteranDvar,
            harderThanVeteranProfile
        );
    }

    applyDifficultyToAllBots(true);
}

botDifficultyEnforcer()
{
    level endon("game_ended");

    for (;;)
    {
        if (getdvar("bot_difficulty") != "veteran")
            setdvar("bot_difficulty", "veteran");

        if (harderThanVeteranEnable &&
            getdvar(harderThanVeteranDvar) != harderThanVeteranProfile)
        {
            setdvar(
                harderThanVeteranDvar,
                harderThanVeteranProfile
            );
        }

        applyDifficultyToAllBots(false);

        wait botDifficultyEnforcerInterval;
    }
}

// --------------------------
// Debugging
// --------------------------
liveDebugHeartbeat()
{
    level endon("game_ended");

    for (;;)
    {
        if (debugAutobots &&
            debugVerbose)
        {
            target =
                level.combatTraining
                ? combatTrainingMaxPlayers
                : dedicatedMaxPlayers;

            dbg(
                "heartbeat totalCap=" +
                countTotalPlayersForCap() +
                " totalRaw=" +
                (isDefined(level.players)
                    ? level.players.size
                    : 0) +
                " humans=" +
                countHumans() +
                " bots=" +
                countBots() +
                " target=" +
                target +
                " ct=" +
                level.combatTraining +
                " profile=" +
                lockedBotDifficulty +
                " nativeSkill=" +
                resolveBotSkillDifficulty(
                    lockedBotDifficulty
                ) +
                " dvar(bot_difficulty)=" +
                getdvar("bot_difficulty") +
                " dvar(" +
                harderThanVeteranDvar +
                ")=" +
                getdvar(harderThanVeteranDvar)
            );
        }

        wait debugHeartbeatInterval;
    }
}

// --------------------------
// Sanity test
// --------------------------
run60SecondSanityTest()
{
    level endon("game_ended");

    if (!debugAutobots)
        return;

    expectedProfile = lockedBotDifficulty;
    expectedNativeDifficulty =
        resolveBotSkillDifficulty(expectedProfile);

    startTime = 0;

    if (isDefined(level.time))
        startTime = level.time;

    samples = 0;
    dvarFailures = 0;
    impossibleDvarFailures = 0;
    overTargetFailures = 0;
    anyBotsSeen = false;
    badBotDiffSeen = 0;
    maxOvershoot = 0;
    spawnSuccessStreak = 0;
    spawnFailStreak = 0;

    for (;;)
    {
        elapsed = 0.0;

        if (isDefined(level.time))
            elapsed =
                (level.time - startTime) / 1000.0;

        if (elapsed >= sanityTestDuration)
            break;

        total = countTotalPlayersForCap();
        bots = countBots();

        target =
            level.combatTraining
            ? combatTrainingMaxPlayers
            : dedicatedMaxPlayers;

        dvarNow = getdvar("bot_difficulty");
        impossibleDvarNow =
            getdvar(harderThanVeteranDvar);

        if (bots > 0)
            anyBotsSeen = true;

        if (dvarNow != "veteran")
            dvarFailures++;

        if (harderThanVeteranEnable &&
            impossibleDvarNow != harderThanVeteranProfile)
        {
            impossibleDvarFailures++;
        }

        if (!level.combatTraining &&
            total > target)
        {
            overTargetFailures++;
        }

        overshoot = total - target;

        if (overshoot > maxOvershoot)
            maxOvershoot = overshoot;

        if (total < target)
            spawnFailStreak++;
        else
            spawnFailStreak = 0;

        if (total >= target)
            spawnSuccessStreak++;
        else
            spawnSuccessStreak = 0;

        if (isDefined(level.players))
        {
            foreach (p in level.players)
            {
                if (!isDefined(p) ||
                    !(p isBotEntity()))
                {
                    continue;
                }

                if (!isDefined(p.pers) ||
                    !isDefined(
                        p.pers["autobot_diff_applied"]
                    ) ||
                    p.pers["autobot_diff_applied"] !=
                        expectedProfile)
                {
                    badBotDiffSeen++;
                    continue;
                }

                actualDifficulty =
                    p botgetdifficulty();

                if (!isDefined(actualDifficulty) ||
                    actualDifficulty != expectedNativeDifficulty)
                {
                    badBotDiffSeen++;
                }
            }
        }

        samples++;

        wait sanityTestSampleInterval;
    }

    dbg(
        "SANITY end samples=" +
        samples +
        " dvarFailures=" +
        dvarFailures +
        " impossibleDvarFailures=" +
        impossibleDvarFailures +
        " overTargetFailures=" +
        overTargetFailures +
        " anyBotsSeen=" +
        anyBotsSeen +
        " badBotDiffSeen=" +
        badBotDiffSeen +
        " expectedProfile=" +
        expectedProfile +
        " expectedNativeSkill=" +
        expectedNativeDifficulty +
        " nativeDvar=veteran" +
        " customDvar=" +
        harderThanVeteranDvar +
        " customProfile=" +
        harderThanVeteranProfile +
        " maxOvershoot=" +
        maxOvershoot +
        " spawnSuccessStreak=" +
        spawnSuccessStreak +
        " spawnFailStreak=" +
        spawnFailStreak
    );
}
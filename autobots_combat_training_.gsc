// ============================================================
// Autobots Combat Training Script (CT-ONLY, HARDENED v6)
// - Restricts execution to multiplayer Combat Training only
// - Supports selected fixed profiles and SBMM-style live scaling
// - Fixes persistence by normalizing + enforcing dvar + per-bot state
// ============================================================
#include scripts/mp/_bots;
#include gungame;

// --------------------------
// Config
// --------------------------
combatTrainingMaxPlayers = 18;

botDifficultyMode = "sbmm";
botDifficultyFallback = "ultra";

// These compatibility aliases are forced to the selected profile during init().
defaultBotDifficulty = "sbmm";
lockedBotDifficulty  = "sbmm";

ultraBotAccuracy = 2.75;
ultraReactionTime = 0.01;
ultraMaxHealth = 650;
ultraBotAggression = 2.75;

godMaxAccuracy = 1000.0;
godMinReactionTime = 0.0;
godMaxHealth = 1000000;
godMaxAggression = 1000.0;

defaultBotLevel = 50;
defaultBotPrestige = 23;

awStyleEnable = true;
awPressureSpawnDelay = 0.15;
awHealthRegenOnSpawn = true;
forceGunGameInCombatTraining = true;

opWeaponsEnable = true;
opPrimaryWeapon = "iw5_m4_mp";
opPrimaryAttachment = "reflex";
opSecondaryWeapon = "iw5_44magnum_mp";
opLethal = "frag_grenade_mp";
opTactical = "flash_grenade_mp";
opGiveFullAmmo = true;

compatUseSetPrestigeNative = false;
compatUseSetRankNative = false;

debugAutobots = true;
debugVerbose = false;
debugHeartbeatInterval = 5.0;

botDifficultyEnforcerInterval = 2.0;
godTierTeamBalanceEnable = false;
godTierTeamBalanceDelta = 1;
godTierTeamBalanceInterval = 0.25;
botWinBiasEnable = true;
botWinBiasLead = 6;
spawnFailBackoff = 0.50;
maxSpawnAttemptsPerTick = 2;
botSbmmEnable = true;
botSbmmUpdateInterval = 3.0;
botSbmmStartScale = 0.45;
botSbmmMinimumScale = 0.35;
botSbmmKdFloor = 1.00;
botSbmmKdCeiling = 2.25;
botSbmmSpreadFloor = 0.0;
botSbmmSpreadCeiling = 12.0;
botSbmmScoreFloor = 0.0;
botSbmmScoreCeiling = 3000.0;
botSbmmTopPlayerWeight = 0.70;
botSbmmLobbyAverageWeight = 0.30;
botSbmmRiseSpeed = 0.45;
botSbmmFallSpeed = 0.20;
botSbmmMinWinBiasLead = 2;
botSbmmMaxWinBiasLead = 6;

sanityTestEnable = false;
sanityTestDuration = 60.0;
sanityTestSampleInterval = 5.0;

// v2 counting controls
countSpectatorsAsPlayers = false;
countConnectingAsPlayers = false;

// v3 hardening controls
strictBotIdentityMode = true;
spawnConfirmPhase1Delay = 0.05;
spawnConfirmPhase2Delay = 0.10;
spawnConfirmPhase3Delay = 0.20;

// --------------------------
// Init
// --------------------------
init()
{
    if (!shouldRunAutobotsHere())
    {
        dbg("init(): disabled outside Combat Training multiplayer");
        return;
    }

    if (combatTrainingMaxPlayers < 0) combatTrainingMaxPlayers = 0;
    if (awPressureSpawnDelay < 0.05) awPressureSpawnDelay = 0.05;
    if (debugHeartbeatInterval < 0.2) debugHeartbeatInterval = 0.2;
    if (botDifficultyEnforcerInterval < 1.0) botDifficultyEnforcerInterval = 1.0;
    if (godTierTeamBalanceInterval < 0.2) godTierTeamBalanceInterval = 0.2;
    if (godTierTeamBalanceDelta < 0) godTierTeamBalanceDelta = 0;
    if (botWinBiasLead < 0) botWinBiasLead = 0;
    if (botSbmmUpdateInterval < 1.0) botSbmmUpdateInterval = 1.0;
    if (botSbmmStartScale < 0.0) botSbmmStartScale = 0.0;
    if (botSbmmStartScale > 1.0) botSbmmStartScale = 1.0;
    if (botSbmmMinimumScale < 0.0) botSbmmMinimumScale = 0.0;
    if (botSbmmMinimumScale > 1.0) botSbmmMinimumScale = 1.0;
    if (botSbmmKdCeiling < botSbmmKdFloor) botSbmmKdCeiling = botSbmmKdFloor;
    if (botSbmmSpreadCeiling < botSbmmSpreadFloor) botSbmmSpreadCeiling = botSbmmSpreadFloor;
    if (botSbmmScoreCeiling < botSbmmScoreFloor) botSbmmScoreCeiling = botSbmmScoreFloor;
    if (botSbmmTopPlayerWeight < 0.0) botSbmmTopPlayerWeight = 0.0;
    if (botSbmmLobbyAverageWeight < 0.0) botSbmmLobbyAverageWeight = 0.0;
    if (botSbmmTopPlayerWeight <= 0.0 && botSbmmLobbyAverageWeight <= 0.0) botSbmmTopPlayerWeight = 1.0;
    if (botSbmmRiseSpeed < 0.01) botSbmmRiseSpeed = 0.01;
    if (botSbmmRiseSpeed > 1.0) botSbmmRiseSpeed = 1.0;
    if (botSbmmFallSpeed < 0.01) botSbmmFallSpeed = 0.01;
    if (botSbmmFallSpeed > 1.0) botSbmmFallSpeed = 1.0;
    if (botSbmmMinWinBiasLead < 0) botSbmmMinWinBiasLead = 0;
    if (botSbmmMaxWinBiasLead < botSbmmMinWinBiasLead) botSbmmMaxWinBiasLead = botSbmmMinWinBiasLead;
    if (spawnFailBackoff < 0.10) spawnFailBackoff = 0.10;
    if (maxSpawnAttemptsPerTick < 2) maxSpawnAttemptsPerTick = 2;
    if (sanityTestDuration < 5.0) sanityTestDuration = 5.0;
    if (sanityTestSampleInterval < 1.0) sanityTestSampleInterval = 1.0;
    if (defaultBotPrestige < 0) defaultBotPrestige = 0;
    if (spawnConfirmPhase1Delay < 0.01) spawnConfirmPhase1Delay = 0.01;
    if (spawnConfirmPhase2Delay < 0.01) spawnConfirmPhase2Delay = 0.01;
    if (spawnConfirmPhase3Delay < 0.01) spawnConfirmPhase3Delay = 0.01;

    if (!isDefined(level.autobotsWarnOnce)) level.autobotsWarnOnce = [];
    if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;
    if (!isDefined(level.autobotDvarDifficulty)) level.autobotDvarDifficulty = "";
    botDifficultyMode = normalizeDifficultyName(botDifficultyMode);
    botDifficultyFallback = normalizeDifficultyFallbackName(botDifficultyFallback);
    defaultBotDifficulty = botDifficultyMode;
    lockedBotDifficulty = botDifficultyMode;
    forceGunGameActive = false;
    if (isDefined(level.forceGunGameInCombatTraining))
        forceGunGameActive = level.forceGunGameInCombatTraining;
    else if (forceGunGameInCombatTraining)
        forceGunGameActive = true;
    if (forceGunGameActive)
        gungame::initForced();

    refreshSbmmState();
    safeSetBotDifficultyDvar();
    level.initNormalizationFailures = validateInitConfigNormalization();
    level.spawnBiasSanityFailures = 0;
    level.delayedDifficultyApplyFailures = 0;
    level.lastAppliedDifficultyToken = "";
    level.lastAppliedSbmmScale = -1.0;

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();

    dbg("init(): Combat Training active"
        + ((isDefined(level.autobotsGunGameMode) && level.autobotsGunGameMode) ? " with Gun Game coexistence" : "")
        + " | diff=" + getActiveDifficultyLabel()
        + " | dvar=" + level.autobotDvarDifficulty);
    if (sanityTestEnable) level thread run60SecondSanityTest();
}

shouldRunAutobotsHere()
{
    if (!isMultiplayerContext()) return false;

    if (isDefined(level.mapname))
    {
        mn = toLower(level.mapname);
        if (isSubStr(mn, "exo survival") || isSubStr(mn, "exo zombies")) return false;
        if (isSubStr(mn, "cp_") || isSubStr(mn, "survival")) return false;
        if (isSubStr(mn, "zm_") || isSubStr(mn, "zombies")) return false;
    }

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (isSubStr(gt, "survival") || isSubStr(gt, "zombie") || isSubStr(gt, "infect")) return false;

    if (isDefined(level.playlist))
    {
        pl = toLower(level.playlist);
        if (isSubStr(pl, "survival") || isSubStr(pl, "zombie")) return false;
        if (isSubStr(pl, "exo")) return false;
        if (isSubStr(pl, "exo survival") || isSubStr(pl, "exo zombies")) return false;
    }

    return detectCombatTraining();
}

isMultiplayerContext()
{
    if (isDefined(level.mapname))
    {
        mn = toLower(level.mapname);
        if (getsubstr(mn, 0, 3) == "mp_") return true;
    }

    return detectCombatTraining();
}

isSubStr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle)) return false;
    return issubstr(hay, needle);
}

detectCombatTraining()
{
    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (isCombatTrainingIdentifier(gt)) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (isCombatTrainingIdentifier(pl)) return true;

    mn = "";
    if (isDefined(level.mapname)) mn = toLower(level.mapname);
    if (isCombatTrainingIdentifier(mn)) return true;

    return false;
}

isCombatTrainingIdentifier(value)
{
    if (!isDefined(value) || value == "") return false;
    if (value == "training" || value == "combattraining" || value == "combat_training" || value == "combat-training" || value == "combat training") return true;
    if (value == "readiness" || value == "combat_readiness" || value == "combat-readiness" || value == "combat readiness") return true;
    if (isSubStr(value, "combat training") || isSubStr(value, "combat_training") || isSubStr(value, "combat-training")) return true;
    if (isSubStr(value, "combat readiness") || isSubStr(value, "combat_readiness") || isSubStr(value, "combat-readiness")) return true;
    return false;
}

normalizeTeamName(value)
{
    if (!isDefined(value)) return "";
    teamName = toLower(value + "");
    if (teamName == "team_allies") return "allies";
    if (teamName == "team_axis") return "axis";
    return teamName;
}

dbg(msg)
{
    if (!debugAutobots) return;
    if (!isDefined(msg)) msg = "undefined";
    if (isDefined(level) && isDefined(level.time)) println("[AUTOBOTS][" + level.time + "] " + msg);
    else println("[AUTOBOTS] " + msg);
}

warnOnce(key, msg)
{
    if (!debugAutobots) return;
    if (!isDefined(level.autobotsWarnOnce)) level.autobotsWarnOnce = [];
    if (!isDefined(key)) key = "unknown_key";
    if (isDefined(level.autobotsWarnOnce[key])) return;
    level.autobotsWarnOnce[key] = true;
    dbg("WARN_ONCE " + key + ": " + msg);
}

safeGetGuid(ent)
{
    if (!isDefined(ent)) return "unknown";
    g = ent getguid();
    if (!isDefined(g) || g == "") return "unknown";
    return g;
}

isBotEntity()
{
    if (isDefined(self.pers) && isDefined(self.pers["isBot"])) return self.pers["isBot"];

    guidFallback = safeGetGuid(self);
    warnOnce("isBot_missing_" + guidFallback, "pers[\"isBot\"] missing for guid=" + guidFallback + "; using fallback checks");

    g = self getguid();
    if (isDefined(g))
    {
        gl = toLower(g);
        if (isSubStr(gl, "bot")) return true;
    }

    if (!strictBotIdentityMode && isDefined(self.name))
    {
        nl = toLower(self.name);
        if (isSubStr(nl, "bot ")) return true;
        if (isSubStr(nl, "[bot]")) return true;
    }

    return false;
}

safeFullHeal(ent)
{
    if (!isDefined(ent) || !isDefined(ent.maxHealth) || !isDefined(ent.health)) return;
    ent.health = ent.maxHealth;
}

clampFloat(value, minValue, maxValue)
{
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
}

floatNear(value, expected, tolerance)
{
    difference = value - expected;
    if (difference < 0.0) difference = 0.0 - difference;
    return difference <= tolerance;
}

validateInitConfigNormalization()
{
    failures = 0;

    if (combatTrainingMaxPlayers < 0) { warnOnce("init_norm_max_players", "combatTrainingMaxPlayers normalization failed"); failures++; }
    if (awPressureSpawnDelay < 0.05) { warnOnce("init_norm_spawn_delay", "awPressureSpawnDelay normalization failed"); failures++; }
    if (debugHeartbeatInterval < 0.2) { warnOnce("init_norm_heartbeat", "debugHeartbeatInterval normalization failed"); failures++; }
    if (botDifficultyEnforcerInterval < 1.0) { warnOnce("init_norm_enforcer", "botDifficultyEnforcerInterval normalization failed"); failures++; }
    if (godTierTeamBalanceInterval < 0.2) { warnOnce("init_norm_team_balance_interval", "godTierTeamBalanceInterval normalization failed"); failures++; }
    if (godTierTeamBalanceDelta < 0) { warnOnce("init_norm_team_balance_delta", "godTierTeamBalanceDelta normalization failed"); failures++; }
    if (botWinBiasLead < 0) { warnOnce("init_norm_win_bias", "botWinBiasLead normalization failed"); failures++; }
    if (botSbmmUpdateInterval < 1.0) { warnOnce("init_norm_sbmm_interval", "botSbmmUpdateInterval normalization failed"); failures++; }
    if (botSbmmStartScale < 0.0 || botSbmmStartScale > 1.0) { warnOnce("init_norm_sbmm_start", "botSbmmStartScale normalization failed"); failures++; }
    if (botSbmmMinimumScale < 0.0 || botSbmmMinimumScale > 1.0) { warnOnce("init_norm_sbmm_min", "botSbmmMinimumScale normalization failed"); failures++; }
    if (botSbmmKdCeiling < botSbmmKdFloor) { warnOnce("init_norm_sbmm_kd", "botSbmm KD normalization failed"); failures++; }
    if (botSbmmSpreadCeiling < botSbmmSpreadFloor) { warnOnce("init_norm_sbmm_spread", "botSbmm spread normalization failed"); failures++; }
    if (botSbmmScoreCeiling < botSbmmScoreFloor) { warnOnce("init_norm_sbmm_score", "botSbmm score normalization failed"); failures++; }
    if (botSbmmTopPlayerWeight < 0.0) { warnOnce("init_norm_sbmm_top_weight", "botSbmmTopPlayerWeight normalization failed"); failures++; }
    if (botSbmmLobbyAverageWeight < 0.0) { warnOnce("init_norm_sbmm_average_weight", "botSbmmLobbyAverageWeight normalization failed"); failures++; }
    if (botSbmmTopPlayerWeight <= 0.0 && botSbmmLobbyAverageWeight <= 0.0) { warnOnce("init_norm_sbmm_weights", "botSbmm weight normalization failed"); failures++; }
    if (botSbmmRiseSpeed < 0.01 || botSbmmRiseSpeed > 1.0) { warnOnce("init_norm_sbmm_rise", "botSbmmRiseSpeed normalization failed"); failures++; }
    if (botSbmmFallSpeed < 0.01 || botSbmmFallSpeed > 1.0) { warnOnce("init_norm_sbmm_fall", "botSbmmFallSpeed normalization failed"); failures++; }
    if (botSbmmMinWinBiasLead < 0) { warnOnce("init_norm_sbmm_min_lead", "botSbmmMinWinBiasLead normalization failed"); failures++; }
    if (botSbmmMaxWinBiasLead < botSbmmMinWinBiasLead) { warnOnce("init_norm_sbmm_max_lead", "botSbmmMaxWinBiasLead normalization failed"); failures++; }
    if (spawnFailBackoff < 0.10) { warnOnce("init_norm_spawn_backoff", "spawnFailBackoff normalization failed"); failures++; }
    if (maxSpawnAttemptsPerTick < 2) { warnOnce("init_norm_spawn_attempts", "maxSpawnAttemptsPerTick normalization failed"); failures++; }
    if (sanityTestDuration < 5.0) { warnOnce("init_norm_sanity_duration", "sanityTestDuration normalization failed"); failures++; }
    if (sanityTestSampleInterval < 1.0) { warnOnce("init_norm_sanity_interval", "sanityTestSampleInterval normalization failed"); failures++; }
    if (defaultBotPrestige < 0) { warnOnce("init_norm_prestige", "defaultBotPrestige normalization failed"); failures++; }
    if (spawnConfirmPhase1Delay < 0.01) { warnOnce("init_norm_spawn_confirm_1", "spawnConfirmPhase1Delay normalization failed"); failures++; }
    if (spawnConfirmPhase2Delay < 0.01) { warnOnce("init_norm_spawn_confirm_2", "spawnConfirmPhase2Delay normalization failed"); failures++; }
    if (spawnConfirmPhase3Delay < 0.01) { warnOnce("init_norm_spawn_confirm_3", "spawnConfirmPhase3Delay normalization failed"); failures++; }

    return failures;
}

getRangeFactor(value, minValue, maxValue)
{
    if (maxValue <= minValue)
    {
        if (value >= maxValue) return 1.0;
        return 0.0;
    }

    value = clampFloat(value, minValue, maxValue);
    return (value - minValue) / (maxValue - minValue);
}

lerpFloat(minValue, maxValue, scale)
{
    scale = clampFloat(scale, 0.0, 1.0);
    return minValue + ((maxValue - minValue) * scale);
}

lerpInt(minValue, maxValue, scale)
{
    return int(lerpFloat(minValue * 1.0, maxValue * 1.0, scale) + 0.5);
}

normalizeDifficultyName(difficulty)
{
    if (!isDefined(difficulty)) return "ultra";
    difficulty = toLower(difficulty + "");
    if (difficulty == "god") return "god";
    if (difficulty == "sbmm") return "sbmm";
    if (difficulty == "ultra") return "ultra";
    return "ultra";
}

normalizeDifficultyFallbackName(difficulty)
{
    if (!isDefined(difficulty)) return "ultra";
    difficulty = toLower(difficulty + "");
    if (difficulty == "ultra") return "ultra";
    return "ultra";
}

getSelectedBotDifficulty()
{
    return normalizeDifficultyName(defaultBotDifficulty);
}

getSbmmScale()
{
    if (!isDefined(level.autobotSbmmScale)) return clampFloat(botSbmmMinimumScale, 0.0, 1.0);
    return clampFloat(level.autobotSbmmScale, 0.0, 1.0);
}

getSbmmDifficultyBucket(scale)
{
    scale = clampFloat(scale, 0.0, 1.0);
    return int((scale * 10.0) + 0.5);
}

getDifficultyApplyToken(difficulty)
{
    diff = normalizeDifficultyName(difficulty);
    if (diff != "sbmm") return diff;
    token = "sbmm_" + getSbmmDifficultyBucket(getSbmmScale());
    if (!isValidDifficultyApplyToken(diff, token))
    {
        warnOnce("sbmm_token_contract", "sbmm apply token contract failed; falling back to sbmm_0");
        return "sbmm_0";
    }
    return token;
}

isValidDifficultyApplyToken(difficulty, token)
{
    diff = normalizeDifficultyName(difficulty);
    if (!isDefined(token) || token == "") return false;
    if (diff != "sbmm") return token == diff;
    if (!isSubStr(token, "sbmm_")) return false;
    if (token == "sbmm" || token == "sbmm_") return false;
    return true;
}

verifyAppliedDifficultyTokens(expectedDifficulty, context)
{
    if (!isDefined(level.players)) return 0;

    diff = normalizeDifficultyName(expectedDifficulty);
    expectedToken = getDifficultyApplyToken(diff);
    failures = 0;

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;

        if (!isDefined(p.pers) || !isDefined(p.pers["autobot_diff_applied"]))
        {
            warnOnce("diff_apply_missing_" + context, "missing autobot_diff_applied after " + context);
            failures++;
            continue;
        }

        appliedToken = p.pers["autobot_diff_applied"];
        if (!isValidDifficultyApplyToken(diff, appliedToken))
        {
            warnOnce("diff_apply_invalid_" + context, "invalid autobot_diff_applied token \"" + appliedToken + "\" after " + context);
            failures++;
            continue;
        }

        if (diff == "sbmm") continue;

        if (appliedToken != expectedToken)
        {
            warnOnce("diff_apply_mismatch_" + context, "unexpected autobot_diff_applied token \"" + appliedToken + "\" after " + context);
            failures++;
        }
    }

    return failures;
}

getActiveDifficultyLabel()
{
    diff = getSelectedBotDifficulty();
    if (diff != "sbmm") return diff;
    return getDifficultyApplyToken(diff);
}

getBotDifficultyDvarTarget()
{
    desired = getSelectedBotDifficulty();
    fallback = normalizeDifficultyFallbackName(botDifficultyFallback);
    if (desired == "god" || desired == "sbmm")
        return fallback;
    return desired;
}

safeSetBotDifficultyDvar()
{
    desired = getSelectedBotDifficulty();
    target = getBotDifficultyDvarTarget();
    setdvar("bot_difficulty", target);
    level.autobotDvarDifficulty = target;

    if (target != desired)
        warnOnce("bot_diff_dvar_" + desired, "using bot_difficulty dvar fallback \"" + target + "\" while keeping script profile \"" + desired + "\"");

    return target;
}

setBotDifficulty(difficulty)
{
    diff = normalizeDifficultyName(difficulty);

    if (diff == "god")
    {
        self.botAccuracy = godMaxAccuracy;
        self.reactionTime = godMinReactionTime;
        self.maxHealth = godMaxHealth;
        self.botAggression = godMaxAggression;
    }
    else if (diff == "sbmm")
    {
        scale = getSbmmScale();
        self.botAccuracy = lerpFloat(ultraBotAccuracy, godMaxAccuracy, scale);
        self.reactionTime = lerpFloat(ultraReactionTime, godMinReactionTime, scale);
        self.maxHealth = lerpInt(ultraMaxHealth, godMaxHealth, scale);
        self.botAggression = lerpFloat(ultraBotAggression, godMaxAggression, scale);
    }
    else
    {
        self.botAccuracy = ultraBotAccuracy;
        self.reactionTime = ultraReactionTime;
        self.maxHealth = ultraMaxHealth;
        self.botAggression = ultraBotAggression;
    }

    if (awHealthRegenOnSpawn) safeFullHeal(self);
}

applyOpLoadout(ent)
{
    if (!opWeaponsEnable || !isDefined(ent)) return;
    if (isDefined(level.gungameInitialized) && level.gungameInitialized) return;
    if (isDefined(level.autobotsGunGameMode) && level.autobotsGunGameMode) return;
    if (!isDefined(ent.pers)) ent.pers = [];

    desiredSig = opPrimaryWeapon + "|" + opPrimaryAttachment + "|" + opSecondaryWeapon + "|" + opLethal + "|" + opTactical;

    primaryToGive = "";
    if (isDefined(opPrimaryWeapon) && opPrimaryWeapon != "")
    {
        primaryToGive = opPrimaryWeapon;
        if (isDefined(opPrimaryAttachment) && opPrimaryAttachment != "")
            primaryToGive = opPrimaryWeapon + "_" + opPrimaryAttachment;
    }

    if (isDefined(ent.pers["autobot_loadout_sig"]) && ent.pers["autobot_loadout_sig"] == desiredSig) return;

    ent takeallweapons();

    if (primaryToGive != "")
    {
        ent giveweapon(primaryToGive);
        ent switchtoweapon(primaryToGive);
        if (opGiveFullAmmo)
        {
            ent givemaxammo(primaryToGive);
            if (primaryToGive != opPrimaryWeapon) ent givemaxammo(opPrimaryWeapon);
        }
    }

    if (isDefined(opSecondaryWeapon) && opSecondaryWeapon != "")
    {
        ent giveweapon(opSecondaryWeapon);
        if (opGiveFullAmmo) ent givemaxammo(opSecondaryWeapon);
    }

    if (isDefined(opLethal) && opLethal != "") ent giveweapon(opLethal);
    if (isDefined(opTactical) && opTactical != "") ent giveweapon(opTactical);

    ent.pers["autobot_loadout_sig"] = desiredSig;
}

isPlayerCountable(ent)
{
    if (!isDefined(ent)) return false;

    if (!countSpectatorsAsPlayers && isDefined(ent.sessionstate))
    {
        st = toLower(ent.sessionstate);
        if (st == "spectator" || st == "intermission") return false;
    }

    if (!countConnectingAsPlayers && isDefined(ent.pers) && isDefined(ent.pers["connected"]))
    {
        c = toLower(ent.pers["connected"]);
        if (c != "connected") return false;
    }

    return true;
}

countTotalPlayersForCap()
{
    if (!isDefined(level.players)) return 0;
    n = 0; foreach (p in level.players) if (isPlayerCountable(p)) n++;
    return n;
}

countPlayersOnTeam(teamName)
{
    if (!isDefined(level.players)) return 0;

    tl = normalizeTeamName(teamName);
    n = 0;
    foreach (p in level.players)
    {
        if (!isDefined(p)) continue;
        if (!isPlayerCountable(p)) continue;
        if (getEntityTeamName(p) != tl) continue;
        n++;
    }

    return n;
}

countBots()
{
    if (!isDefined(level.players)) return 0;
    n = 0; foreach (p in level.players) if (isDefined(p) && (p isBotEntity())) n++;
    return n;
}

countHumans()
{
    if (!isDefined(level.players)) return 0;
    n = 0; foreach (p in level.players) if (isDefined(p) && !(p isBotEntity())) n++;
    return n;
}

countHumansOnTeam(teamName)
{
    if (!isDefined(level.players)) return 0;

    tl = normalizeTeamName(teamName);
    n = 0;
    foreach (p in level.players)
    {
        if (!isDefined(p) || (p isBotEntity())) continue;
        if (!isPlayerCountable(p)) continue;
        if (getEntityTeamName(p) != tl) continue;
        n++;
    }

    return n;
}

getEntityKills(ent)
{
    if (!isDefined(ent)) return 0;
    if (isDefined(ent.kills)) return int(ent.kills);
    if (isDefined(ent.pers) && isDefined(ent.pers["kills"])) return int(ent.pers["kills"]);
    return 0;
}

getEntityDeaths(ent)
{
    if (!isDefined(ent)) return 0;
    if (isDefined(ent.deaths)) return int(ent.deaths);
    if (isDefined(ent.pers) && isDefined(ent.pers["deaths"])) return int(ent.pers["deaths"]);
    return 0;
}

getEntityScore(ent)
{
    if (!isDefined(ent)) return 0;
    if (isDefined(ent.score)) return int(ent.score);
    if (isDefined(ent.pers) && isDefined(ent.pers["score"])) return int(ent.pers["score"]);
    return 0;
}

getPlayerSbmmPressure(ent)
{
    if (!isDefined(ent)) return 0.0;

    kills = getEntityKills(ent);
    deaths = getEntityDeaths(ent);
    score = getEntityScore(ent);

    deathsForKd = deaths;
    if (deathsForKd < 1) deathsForKd = 1;

    kd = (kills * 1.0) / (deathsForKd * 1.0);
    spread = kills - deaths;
    if (spread < 0) spread = 0;

    kdPressure = getRangeFactor(kd, botSbmmKdFloor, botSbmmKdCeiling);
    spreadPressure = getRangeFactor(spread * 1.0, botSbmmSpreadFloor, botSbmmSpreadCeiling);
    scorePressure = getRangeFactor(score * 1.0, botSbmmScoreFloor, botSbmmScoreCeiling);

    playerPressure = kdPressure;
    if (spreadPressure > playerPressure) playerPressure = spreadPressure;
    if (scorePressure > playerPressure) playerPressure = scorePressure;

    return clampFloat(playerPressure, 0.0, 1.0);
}

getPlayerSbmmSignedPressure(ent)
{
    if (!isDefined(ent)) return 0.0;

    kills = getEntityKills(ent);
    deaths = getEntityDeaths(ent);
    score = getEntityScore(ent);

    deathsForKd = deaths;
    if (deathsForKd < 1) deathsForKd = 1;

    kd = (kills * 1.0) / (deathsForKd * 1.0);
    spread = kills - deaths;

    kdPressureUp = getRangeFactor(kd, botSbmmKdFloor, botSbmmKdCeiling);
    kdPressureDown = 0.0;
    if (kd < botSbmmKdFloor && botSbmmKdFloor > 0.0)
        kdPressureDown = clampFloat((botSbmmKdFloor - kd) / botSbmmKdFloor, 0.0, 1.0);

    spreadPressureUp = getRangeFactor(spread * 1.0, botSbmmSpreadFloor, botSbmmSpreadCeiling);
    spreadPressureDown = 0.0;
    if (spread < 0)
        spreadPressureDown = getRangeFactor((0.0 - (spread * 1.0)), 0.0, botSbmmSpreadCeiling);

    scorePressureUp = getRangeFactor(score * 1.0, botSbmmScoreFloor, botSbmmScoreCeiling);

    positivePressure = kdPressureUp;
    if (spreadPressureUp > positivePressure) positivePressure = spreadPressureUp;
    if (scorePressureUp > positivePressure) positivePressure = scorePressureUp;

    negativePressure = kdPressureDown;
    if (spreadPressureDown > negativePressure) negativePressure = spreadPressureDown;

    if (negativePressure > positivePressure)
        return 0.0 - negativePressure;

    return positivePressure;
}

getHumanSbmmTargetScale()
{
    baseScale = clampFloat(botSbmmMinimumScale, 0.0, 1.0);
    startScale = clampFloat(botSbmmStartScale, 0.0, 1.0);
    if (startScale < baseScale) startScale = baseScale;
    if (!botSbmmEnable || !isDefined(level.players)) return baseScale;

    humanCount = 0;
    pressureTotal = 0.0;
    highestPressure = 0.0;

    foreach (p in level.players)
    {
        if (!isDefined(p) || (p isBotEntity())) continue;
        if (!isPlayerCountable(p)) continue;

        humanCount++;
        playerPressure = getPlayerSbmmSignedPressure(p);
        pressureTotal += playerPressure;

        if (playerPressure > highestPressure) highestPressure = playerPressure;
    }

    if (humanCount <= 0) return baseScale;

    averagePressure = pressureTotal / (humanCount * 1.0);
    weightTotal = botSbmmTopPlayerWeight + botSbmmLobbyAverageWeight;
    if (weightTotal <= 0.0) return baseScale;

    blendedPressure = ((highestPressure * botSbmmTopPlayerWeight) + (averagePressure * botSbmmLobbyAverageWeight)) / weightTotal;
    if (blendedPressure >= 0.0)
        return clampFloat(startScale + ((1.0 - startScale) * blendedPressure), baseScale, 1.0);

    return clampFloat(startScale + ((startScale - baseScale) * blendedPressure), baseScale, 1.0);
}

smoothSbmmScale(currentScale, targetScale)
{
    return smoothSbmmScaleWithSpeeds(currentScale, targetScale, botSbmmRiseSpeed, botSbmmFallSpeed);
}

smoothSbmmScaleWithSpeeds(currentScale, targetScale, riseSpeed, fallSpeed)
{
    currentScale = clampFloat(currentScale, 0.0, 1.0);
    targetScale = clampFloat(targetScale, 0.0, 1.0);
    riseSpeed = clampFloat(riseSpeed, 0.0, 1.0);
    fallSpeed = clampFloat(fallSpeed, 0.0, 1.0);

    speed = fallSpeed;
    if (targetScale > currentScale) speed = riseSpeed;

    return clampFloat(currentScale + ((targetScale - currentScale) * speed), 0.0, 1.0);
}

getSbmmLeadForScale(scale)
{
    return lerpInt(botSbmmMinWinBiasLead, botSbmmMaxWinBiasLead, scale);
}

refreshSbmmState()
{
    baseScale = clampFloat(botSbmmMinimumScale, 0.0, 1.0);
    rawStartScale = clampFloat(botSbmmStartScale, 0.0, 1.0);
    startScale = rawStartScale;
    if (startScale < baseScale) startScale = baseScale;

    if (!botSbmmEnable || getSelectedBotDifficulty() != "sbmm")
    {
        targetScale = baseScale;
        scale = baseScale;
    }
    else
    {
        targetScale = getHumanSbmmTargetScale();
        if (targetScale <= baseScale)
        {
            if (!isDefined(level.autobotSbmmScale))
                scale = smoothSbmmScale(rawStartScale, baseScale);
            else
            {
                currentScale = clampFloat(level.autobotSbmmScale, 0.0, 1.0);
                scale = smoothSbmmScale(currentScale, baseScale);
            }
        }
        else if (!isDefined(level.autobotSbmmScale))
            scale = smoothSbmmScale(rawStartScale, targetScale);
        else
        {
            currentScale = clampFloat(level.autobotSbmmScale, 0.0, 1.0);
            scale = smoothSbmmScale(currentScale, targetScale);
        }
    }

    level.autobotSbmmTargetScale = targetScale;
    level.autobotSbmmScale = scale;
    level.autobotDynamicWinBiasLead = getSbmmLeadForScale(scale);
    level.autobotActiveDifficultyLabel = getActiveDifficultyLabel();
}

setBotRankCompat(rankValue)
{
    r = int(rankValue);
    self.rank = r;
    if (!isDefined(self.pers)) self.pers = [];
    self.pers["rank"] = r;
    if (compatUseSetRankNative) self setrank(r);
}

applyBotPrestigeSetting()
{
    if (!isDefined(self.pers)) self.pers = [];
    self.pers["prestige"] = defaultBotPrestige;
    if (compatUseSetPrestigeNative) self setprestige(defaultBotPrestige);
}

applyAutobotDifficulty(diff)
{
    if (!isDefined(self.pers)) self.pers = [];
    selectedDifficulty = normalizeDifficultyName(diff);
    self.pers["autobot_diff_applied"] = getDifficultyApplyToken(selectedDifficulty);
    self setBotDifficulty(selectedDifficulty);
    applyOpLoadout(self);
}

applyDifficultyToAllBots(forceWritePers)
{
    selectedDifficulty = getSelectedBotDifficulty();
    selectedToken = getDifficultyApplyToken(selectedDifficulty);
    safeSetBotDifficultyDvar();
    if (!isDefined(level.players)) return;

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;

        needsApply = true;
        if (isDefined(p.pers) && isDefined(p.pers["autobot_diff_applied"]) && p.pers["autobot_diff_applied"] == selectedToken && !forceWritePers)
            needsApply = false;

        if (needsApply)
        {
            p applyAutobotDifficulty(selectedDifficulty);
            p setBotRankCompat(defaultBotLevel);
            p applyBotPrestigeSetting();

            if (!isDefined(p.pers)) p.pers = [];
            p.pers["autobot_diff_applied"] = selectedToken;
            if (awHealthRegenOnSpawn) safeFullHeal(p);
        }
    }
}

onPlayerConnect()
{
    level endon("game_ended");
    for (;;)
    {
        level waittill("connected", player);
        if (!isDefined(player)) continue;

        if (player isBotEntity())
        {
            selectedDifficulty = getSelectedBotDifficulty();
            selectedToken = getDifficultyApplyToken(selectedDifficulty);
            player applyAutobotDifficulty(selectedDifficulty);
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();

            if (!isDefined(player.pers)) player.pers = [];
            player.pers["autobot_diff_applied"] = selectedToken;

            if (awHealthRegenOnSpawn) safeFullHeal(player);
        }
    }
}

normalizeSpawnTeam(preferredTeam)
{
    if (!isDefined(preferredTeam)) return "";

    pt = normalizeTeamName(preferredTeam);
    if (pt == "allies" || pt == "axis")
        return pt;

    return "";
}

getSpawnBotsTeamToken(preferredTeam)
{
    pt = normalizeSpawnTeam(preferredTeam);
    if (pt == "allies") return "team_allies";
    if (pt == "axis") return "team_axis";
    return "autoassign";
}

runSpawnBiasSanityCheck()
{
    failures = 0;

    if (normalizeSpawnTeam("allies") != "allies")
    {
        warnOnce("spawn_bias_allies", "spawn bias sanity failed for allies");
        failures++;
    }

    if (normalizeSpawnTeam("axis") != "axis")
    {
        warnOnce("spawn_bias_axis", "spawn bias sanity failed for axis");
        failures++;
    }

    if (normalizeSpawnTeam("team_allies") != "allies")
    {
        warnOnce("spawn_bias_team_allies", "spawn bias sanity failed for team_allies");
        failures++;
    }

    if (normalizeSpawnTeam("team_axis") != "axis")
    {
        warnOnce("spawn_bias_team_axis", "spawn bias sanity failed for team_axis");
        failures++;
    }

    undefinedTeam = "";
    if (normalizeSpawnTeam(undefinedTeam) != "")
    {
        warnOnce("spawn_bias_undef", "spawn bias sanity failed for undefined");
        failures++;
    }

    if (normalizeSpawnTeam("bogus") != "")
    {
        warnOnce("spawn_bias_invalid", "spawn bias sanity failed for invalid team");
        failures++;
    }

    if (pickPreferredBotWinTeamByCounts(2, 1) != "axis")
    {
        warnOnce("spawn_bias_pref_axis", "spawn bias sanity failed for allies-heavy human teams");
        failures++;
    }

    if (pickPreferredBotWinTeamByCounts(1, 2) != "allies")
    {
        warnOnce("spawn_bias_pref_allies", "spawn bias sanity failed for axis-heavy human teams");
        failures++;
    }

    if (pickPreferredBotWinTeamByCounts(0, 1) != "allies")
    {
        warnOnce("spawn_bias_pref_allies_zero", "spawn bias sanity failed for solo axis humans");
        failures++;
    }

    if (pickPreferredBotWinTeamByCounts(1, 0) != "axis")
    {
        warnOnce("spawn_bias_pref_axis_zero", "spawn bias sanity failed for solo allies humans");
        failures++;
    }

    if (pickPreferredBotWinTeamByCounts(2, 2) != "")
    {
        warnOnce("spawn_bias_pref_tie", "spawn bias sanity failed for tied human teams");
        failures++;
    }

    if (!isSpawnLeadAllowed(0, 1))
    {
        warnOnce("spawn_bias_lead_allow", "spawn bias sanity failed for allowed lead");
        failures++;
    }

    if (isSpawnLeadAllowed(1, 1))
    {
        warnOnce("spawn_bias_lead_block", "spawn bias sanity failed for capped lead");
        failures++;
    }

    if (getPreferredBotSpawnTeamByCounts(2, 1, 1, 0, 1) != "axis")
    {
        warnOnce("spawn_bias_team_pick", "spawn bias sanity failed for preferred spawn team selection");
        failures++;
    }

    if (getPreferredBotSpawnTeamByCounts(2, 1, 3, 2, 1) != "")
    {
        warnOnce("spawn_bias_team_cap", "spawn bias sanity failed for preferred spawn team lead cap");
        failures++;
    }

    if (getSelectedBotDifficulty() == "sbmm")
    {
        expectedSbmmToken = level.autobotActiveDifficultyLabel;
        if (!isDefined(expectedSbmmToken) || expectedSbmmToken == "") expectedSbmmToken = getActiveDifficultyLabel();
        actualSbmmToken = getDifficultyApplyToken("sbmm");
        if (!isValidDifficultyApplyToken("sbmm", actualSbmmToken))
        {
            warnOnce("sbmm_token", "sbmm apply token sanity failed");
            failures++;
        }
        else if (actualSbmmToken != expectedSbmmToken)
        {
            warnOnce("sbmm_token_bucket", "sbmm startup token bucket sanity failed");
            failures++;
        }
    }

    if (getSbmmLeadForScale(0.0) != botSbmmMinWinBiasLead)
    {
        warnOnce("sbmm_lead_min", "sbmm minimum lead sanity failed");
        failures++;
    }

    if (getSbmmLeadForScale(1.0) != botSbmmMaxWinBiasLead)
    {
        warnOnce("sbmm_lead_max", "sbmm maximum lead sanity failed");
        failures++;
    }

    riseScale = smoothSbmmScaleWithSpeeds(0.50, 1.0, 0.45, 0.20);
    if (riseScale <= 0.50)
    {
        warnOnce("sbmm_rise", "sbmm rise smoothing sanity failed");
        failures++;
    }
    else if (!floatNear(riseScale, 0.725, 0.001))
    {
        warnOnce("sbmm_rise_exact", "sbmm rise smoothing exact-step sanity failed");
        failures++;
    }

    fallScale = smoothSbmmScaleWithSpeeds(0.50, 0.0, 0.45, 0.20);
    if (fallScale >= 0.50)
    {
        warnOnce("sbmm_fall", "sbmm fall smoothing sanity failed");
        failures++;
    }
    else if (!floatNear(fallScale, 0.40, 0.001))
    {
        warnOnce("sbmm_fall_exact", "sbmm fall smoothing exact-step sanity failed");
        failures++;
    }

    return failures;
}

spawnBotsSafe(amount, preferredTeam)
{
    if (!isDefined(amount) || amount <= 0) return false;

    beforePlayers = countTotalPlayersForCap();
    beforeBots = countBots();

    spawnTeam = getSpawnBotsTeamToken(preferredTeam);
    spawn_bots(amount, spawnTeam);

    wait spawnConfirmPhase1Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase2Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase3Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    return false;
}

serverBotFill()
{
    level endon("game_ended");
    wait 0.05;

    for (;;)
    {
        if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;
        if (level.autobotAdjusting) { wait 0.10; continue; }
        level.autobotAdjusting = true;
        spawnFailed = false;

        target = combatTrainingMaxPlayers;
        if (target < 0) target = 0;

        attempts = 0;
        while (countTotalPlayersForCap() < target && attempts < maxSpawnAttemptsPerTick)
        {
            if (countTotalPlayersForCap() >= target) break;
            attempts++;
            spawnTeam = "autoassign";
            preferredTeam = getPreferredBotSpawnTeam();
            if (preferredTeam != "")
                spawnTeam = preferredTeam;

            if (!spawnBotsSafe(1, spawnTeam))
            {
                spawnFailed = true;
                break;
            }

            wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        level.autobotAdjusting = false;
        if (spawnFailed)
        {
            wait spawnFailBackoff;
            continue;
        }
        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

getEntityTeamName(ent)
{
    if (!isDefined(ent)) return "";
    if (isDefined(ent.sessionteam)) return normalizeTeamName(ent.sessionteam);
    if (isDefined(ent.team)) return normalizeTeamName(ent.team);
    if (isDefined(ent.pers) && isDefined(ent.pers["team"])) return normalizeTeamName(ent.pers["team"]);
    return "";
}

isTeamBasedBotMode()
{
    if (isDefined(level.teambased)) return level.teambased;
    if (isDefined(level.teamBased)) return level.teamBased;
    return false;
}

countBotsOnTeam(teamName)
{
    if (!isDefined(level.players)) return 0;

    tl = normalizeTeamName(teamName);
    n = 0;
    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;
        if (!isPlayerCountable(p)) continue;
        if (getEntityTeamName(p) != tl) continue;
        n++;
    }

    return n;
}

countAlliedBots() { return countBotsOnTeam("allies"); }
countAxisBots()   { return countBotsOnTeam("axis"); }

pickPreferredBotWinTeamByCounts(alliesHumans, axisHumans)
{
    if (alliesHumans <= 0 && axisHumans <= 0) return "";
    if (alliesHumans > axisHumans) return "axis";
    if (axisHumans > alliesHumans) return "allies";
    return "";
}

isSpawnLeadAllowed(currentLead, maxLead)
{
    return currentLead < maxLead;
}

getActiveBotWinBiasLead()
{
    if (getSelectedBotDifficulty() != "sbmm") return botWinBiasLead;
    if (!botSbmmEnable) return botWinBiasLead;
    if (!isDefined(level.autobotDynamicWinBiasLead)) return getSbmmLeadForScale(getSbmmScale());
    return level.autobotDynamicWinBiasLead;
}

getPreferredBotSpawnTeamByCounts(alliesHumans, axisHumans, alliesPlayers, axisPlayers, maxLead)
{
    preferredTeam = pickPreferredBotWinTeamByCounts(alliesHumans, axisHumans);
    if (preferredTeam == "") return "";

    if (preferredTeam == "allies")
        totalLead = alliesPlayers - axisPlayers;
    else
        totalLead = axisPlayers - alliesPlayers;

    if (isSpawnLeadAllowed(totalLead, maxLead)) return preferredTeam;
    return "";
}

getPreferredBotSpawnTeam()
{
    activeLead = getActiveBotWinBiasLead();
    if (!botWinBiasEnable || activeLead <= 0) return "";
    if (!isTeamBasedBotMode()) return "";
    return getPreferredBotSpawnTeamByCounts(
        countHumansOnTeam("allies"),
        countHumansOnTeam("axis"),
        countPlayersOnTeam("allies"),
        countPlayersOnTeam("axis"),
        activeLead
    );
}


delayedBotDifficultyApply()
{
    level endon("game_ended");
    wait 0.5;
    safeSetBotDifficultyDvar();
    applyDifficultyToAllBots(true);
    level.lastAppliedDifficultyToken = getDifficultyApplyToken(getSelectedBotDifficulty());
    level.lastAppliedSbmmScale = getSbmmScale();
    level.delayedDifficultyApplyFailures = verifyAppliedDifficultyTokens(getSelectedBotDifficulty(), "delayed_apply");
}

botDifficultyEnforcer()
{
    level endon("game_ended");
    timeSinceEnforce = botDifficultyEnforcerInterval;
    for (;;)
    {
        refreshSbmmState();
        if (timeSinceEnforce >= botDifficultyEnforcerInterval)
        {
            safeSetBotDifficultyDvar();
            selectedDifficulty = getSelectedBotDifficulty();
            selectedToken = getDifficultyApplyToken(selectedDifficulty);
            selectedScale = getSbmmScale();
            needsApply = !isDefined(level.lastAppliedDifficultyToken) || selectedToken != level.lastAppliedDifficultyToken;
            if (!needsApply && selectedDifficulty == "sbmm")
            {
                if (!isDefined(level.lastAppliedSbmmScale) || !floatNear(level.lastAppliedSbmmScale, selectedScale, 0.0001))
                    needsApply = true;
            }

            if (needsApply)
            {
                applyDifficultyToAllBots(false);
                level.lastAppliedDifficultyToken = selectedToken;
                level.lastAppliedSbmmScale = selectedScale;
            }
            timeSinceEnforce = 0.0;
        }

        waitInterval = botDifficultyEnforcerInterval;
        if (botSbmmEnable && getSelectedBotDifficulty() == "sbmm" && botSbmmUpdateInterval < waitInterval) waitInterval = botSbmmUpdateInterval;
        wait waitInterval;
        timeSinceEnforce = timeSinceEnforce + waitInterval;
    }
}

liveDebugHeartbeat()
{
    level endon("game_ended");
    for (;;)
    {
        if (debugAutobots && debugVerbose)
        {
            target = combatTrainingMaxPlayers;
            dbg("heartbeat totalCap=" + countTotalPlayersForCap()
                + " totalRaw=" + (isDefined(level.players) ? level.players.size : 0)
                + " humans=" + countHumans()
                + " bots=" + countBots()
                + " target=" + target
                + " diff=" + getActiveDifficultyLabel()
                + " dvar(bot_difficulty)=" + level.autobotDvarDifficulty
                + " sbmmScale=" + getSbmmScale()
                + " sbmmTarget=" + (isDefined(level.autobotSbmmTargetScale) ? level.autobotSbmmTargetScale : getSbmmScale())
                + " sbmmLead=" + getActiveBotWinBiasLead()
                + " alliesBots=" + countAlliedBots()
                + " axisBots=" + countAxisBots());
        }
        wait debugHeartbeatInterval;
    }
}

run60SecondSanityTest()
{
    level endon("game_ended");
    if (!debugAutobots) return;

    spawnBiasSanityFailures = runSpawnBiasSanityCheck();
    level.spawnBiasSanityFailures = spawnBiasSanityFailures;
    startTime = 0;
    if (isDefined(level.time)) startTime = level.time;

    samples = 0;
    dvarFailures = 0;
    anyBotsSeen = false;
    badBotDiffSeen = 0;
    maxOvershoot = 0;
    spawnSuccessStreak = 0;
    spawnFailStreak = 0;
    expectedApplied = getActiveDifficultyLabel();
    expectedDvar = getBotDifficultyDvarTarget();

    for (;;)
    {
        elapsed = 0.0;
        if (isDefined(level.time)) elapsed = (level.time - startTime) / 1000.0;
        if (elapsed >= sanityTestDuration) break;

        total = countTotalPlayersForCap();
        bots = countBots();
        target = combatTrainingMaxPlayers;
        expectedApplied = getActiveDifficultyLabel();
        expectedDvar = getBotDifficultyDvarTarget();
        dvarNow = getdvar("bot_difficulty");
        if (!isDefined(dvarNow)) dvarNow = "";
        dvarNow = toLower(dvarNow);

        if (bots > 0) anyBotsSeen = true;
        if (dvarNow != expectedDvar) dvarFailures++;

        overshoot = total - target;
        if (overshoot > maxOvershoot) maxOvershoot = overshoot;

        if (total < target) spawnFailStreak++; else spawnFailStreak = 0;
        if (total >= target) spawnSuccessStreak++; else spawnSuccessStreak = 0;

        if (isDefined(level.players))
        {
            foreach (p in level.players)
            {
                if (!isDefined(p) || !(p isBotEntity())) continue;
                if (!isDefined(p.pers) || !isDefined(p.pers["autobot_diff_applied"]))
                {
                    badBotDiffSeen++;
                    continue;
                }

                if (getSelectedBotDifficulty() == "sbmm")
                {
                    if (!isValidDifficultyApplyToken("sbmm", p.pers["autobot_diff_applied"]))
                        badBotDiffSeen++;
                }
                else if (p.pers["autobot_diff_applied"] != expectedApplied)
                    badBotDiffSeen++;
            }
        }

        samples = samples + 1;
        wait sanityTestSampleInterval;
    }

    delayedDifficultyApplyFailures = 0;
    if (isDefined(level.delayedDifficultyApplyFailures)) delayedDifficultyApplyFailures = level.delayedDifficultyApplyFailures;
    if (delayedDifficultyApplyFailures > 0)
        warnOnce("sanity_delayed_apply", "delayed difficulty apply token verification failed");

    dbg("SANITY end samples=" + samples
        + " expectedApplied=" + expectedApplied
        + " expectedDvar=" + expectedDvar
        + " dvarFailures=" + dvarFailures
        + " anyBotsSeen=" + anyBotsSeen
        + " badBotDiffSeen=" + badBotDiffSeen
        + " delayedDifficultyApplyFailures=" + delayedDifficultyApplyFailures
        + " spawnBiasSanityFailures=" + spawnBiasSanityFailures
        + " maxOvershoot=" + maxOvershoot
        + " spawnSuccessStreak=" + spawnSuccessStreak
        + " spawnFailStreak=" + spawnFailStreak);
}

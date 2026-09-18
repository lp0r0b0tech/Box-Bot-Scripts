// ============================================================
// Autobots Combat Training Script (CT-ONLY, HARDENED v6, S1X-COMPAT)
// - Restricts execution to multiplayer Combat Training when identifiers exist
// - Falls back to standard multiplayer on S1X-style engines without CT identifiers
// - Supports selected fixed profiles and SBMM-style live scaling
// - Fixes persistence by normalizing + enforcing dvar + per-bot state
// ============================================================
#include scripts/mp/_bots;

// --------------------------
// Config
// --------------------------
combatTrainingMaxPlayers = 18;

botDifficultyMode = "sbmm";
// S1X keeps the engine dvar on stock-compatible values, so ultra is the only fallback profile.
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
awTrimDelay = 0.03;
awHealthRegenOnSpawn = true;
s1xCompatibilityMode = true;
s1xAllowStandardMultiplayerFallback = true;

opWeaponsEnable = true;
opPrimaryWeapon = "iw5_m4_mp";
opPrimaryAttachment = "reflex";
opSecondaryWeapon = "iw5_44magnum_mp";
opLethal = "frag_grenade_mp";
opTactical = "flash_grenade_mp";
opGiveFullAmmo = true;

compatUseSetPrestigeNative = false;
compatUseSetRankNative = false;
compatUseBotDropNative = true;

debugAutobots = true;
debugVerbose = false;
debugLogPreferredSpawnTeam = false;
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
trimSafetyMaxDrops = 32;

// --------------------------
// Atlas 45 upgrade-safe buff
// --------------------------
atlas45EnableBuff = true;
atlas45BaseId = "iw5_44magnum_mp";
atlas45Upg1Id = "iw5_44magnum_mp_upgraded";
atlas45Upg2Id = "iw5_44magnum_mp_upgraded2";
atlas45BaseMult = 1.20;
atlas45Upg1Mult = 1.45;
atlas45Upg2Mult = 1.75;
atlas45MonitorInterval = 0.25;

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
    if (awTrimDelay < 0.01) awTrimDelay = 0.01;
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
    if (trimSafetyMaxDrops < 1) trimSafetyMaxDrops = 1;
    if (atlas45MonitorInterval < 0.05) atlas45MonitorInterval = 0.05;

    if (!isDefined(level.autobotsWarnOnce)) level.autobotsWarnOnce = [];
    if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;
    if (!isDefined(level.autobotDvarDifficulty)) level.autobotDvarDifficulty = "";
    level.combatTraining = detectCombatTraining();

    botDifficultyMode = normalizeDifficultyName(botDifficultyMode);
    botDifficultyFallback = normalizeDifficultyFallbackName(botDifficultyFallback);
    defaultBotDifficulty = botDifficultyMode;
    lockedBotDifficulty = botDifficultyMode;

    initializeOptionalGunGameState();

    refreshSbmmState();
    safeSetBotDifficultyDvar();
    level.initNormalizationFailures = validateInitConfigNormalization();
    level.spawnBiasSanityFailures = 0;
    level.delayedDifficultyApplyFailures = 0;
    level.lastAppliedDifficultyToken = "";
    level.lastAppliedSbmmScale = -1.0;
    level.autobotWinBiasLead = botWinBiasLead;

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread difficultyApplyWorker();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();
    level thread liveSbmmUpdater();
    level thread atlas45GlobalMonitor();

    dbg("init(): Combat Training active"
        + ((isDefined(level.autobotsS1xFallbackMode) && level.autobotsS1xFallbackMode) ? " via S1X MP fallback" : "")
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

    if (detectCombatTraining()) return true;
    if (shouldAllowS1xMultiplayerFallback()) return true;
    return false;
}

isMultiplayerContext()
{
    nonMpMap = false;
    if (isDefined(level.mapname))
    {
        mn = toLower(level.mapname);
        if (length(mn) >= 3)
        {
            prefix = getsubstr(mn, 0, 3);
            if (prefix == "mp_") return true;
            if (prefix == "cp_" || prefix == "zm_" || prefix == "sp_") nonMpMap = true;
        }
    }

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (isCombatTrainingIdentifier(gt)) return true;
    if (isKnownMultiplayerIdentifier(gt)) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (isCombatTrainingIdentifier(pl)) return true;
    if (isKnownMultiplayerIdentifier(pl)) return true;

    if (s1xCompatibilityMode && isDefined(level.mapname) && level.mapname != "" && !nonMpMap) return true;
    if (nonMpMap) return false;
    return false;
}

isKnownMultiplayerIdentifier(value)
{
    if (!isDefined(value) || value == "") return false;
    if (value == "dm" || value == "war" || value == "dom" || value == "conf") return true;
    if (value == "sd" || value == "ctf" || value == "hp" || value == "koth") return true;
    if (value == "sab" || value == "sr" || value == "gun" || value == "gungame") return true;
    if (value == "gun_game" || value == "gun-game" || value == "arena") return true;
    return false;
}

isSubStr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle)) return false;
    return issubstr(hay, needle);
}

detectCombatTraining()
{
    level.autobotsS1xFallbackMode = false;

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (isCombatTrainingIdentifier(gt)) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (isCombatTrainingIdentifier(pl)) return true;

    mn = "";
    if (isDefined(level.mapname)) mn = toLower(level.mapname);
    if (isCombatTrainingIdentifier(mn)) return true;

    if (shouldAllowS1xMultiplayerFallback())
    {
        level.autobotsS1xFallbackMode = true;
        return true;
    }

    return false;
}

shouldAllowS1xMultiplayerFallback()
{
    if (!s1xCompatibilityMode || !s1xAllowStandardMultiplayerFallback) return false;
    return isMultiplayerContext();
}

initializeOptionalGunGameState()
{
    if (!isDefined(level.autobotsGunGameMode)) level.autobotsGunGameMode = false;
    if (!isDefined(level.forceGunGameInCombatTraining)) level.forceGunGameInCombatTraining = false;
    if (!isDefined(level.autobotDifficultyPending)) level.autobotDifficultyPending = false;
    if (!isDefined(level.autobotDifficultyForceWrite)) level.autobotDifficultyForceWrite = false;
    if (!isDefined(level.autobotDifficultyVerifyContext)) level.autobotDifficultyVerifyContext = "";
}

isGunGameActive()
{
    if (isDefined(level.gungameInitialized) && level.gungameInitialized) return true;
    if (isDefined(level.autobotsGunGameMode) && level.autobotsGunGameMode) return true;
    return false;
}

requestDifficultyApply(forceWrite, verifyContext)
{
    if (!isDefined(level.autobotDifficultyPending)) level.autobotDifficultyPending = false;
    if (!isDefined(level.autobotDifficultyForceWrite)) level.autobotDifficultyForceWrite = false;
    if (!isDefined(level.autobotDifficultyVerifyContext)) level.autobotDifficultyVerifyContext = "";

    if (forceWrite) level.autobotDifficultyForceWrite = true;
    if (isDefined(verifyContext) && verifyContext != "") level.autobotDifficultyVerifyContext = verifyContext;
    level.autobotDifficultyPending = true;
}

difficultyApplyWorker()
{
    level endon("game_ended");
    for (;;)
    {
        if (!isDefined(level.autobotDifficultyPending)) level.autobotDifficultyPending = false;
        if (!isDefined(level.autobotDifficultyForceWrite)) level.autobotDifficultyForceWrite = false;
        if (!isDefined(level.autobotDifficultyVerifyContext)) level.autobotDifficultyVerifyContext = "";
        if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;

        if (!level.autobotDifficultyPending) { wait 0.05; continue; }
        if (level.autobotAdjusting) { wait 0.05; continue; }

        level.autobotAdjusting = true;

        forceWrite = level.autobotDifficultyForceWrite;
        verifyContext = level.autobotDifficultyVerifyContext;
        level.autobotDifficultyPending = false;
        level.autobotDifficultyForceWrite = false;
        level.autobotDifficultyVerifyContext = "";

        refreshSbmmState();
        safeSetBotDifficultyDvar();
        applyDifficultyToAllBots(forceWrite);

        if (verifyContext == "delayed_apply")
            level.delayedDifficultyApplyFailures = verifyAppliedDifficultyTokens(getSelectedBotDifficulty(), verifyContext);

        level.autobotAdjusting = false;
    }
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

getEntityTeamName(ent)
{
    if (!isDefined(ent)) return "";
    if (isDefined(ent.team)) return normalizeTeamName(ent.team);
    if (isDefined(ent.pers) && isDefined(ent.pers["team"])) return normalizeTeamName(ent.pers["team"]);
    if (isDefined(ent.sessionteam)) return normalizeTeamName(ent.sessionteam);
    return "";
}

getTeamScore(teamName)
{
    tl = normalizeTeamName(teamName);
    if (tl == "") return 0;

    if (isDefined(level.teamScores) && isDefined(level.teamScores[tl])) return int(level.teamScores[tl]);
    if (isDefined(level.teamScore) && isDefined(level.teamScore[tl])) return int(level.teamScore[tl]);
    if (isDefined(game) && isDefined(game["teamScores"]) && isDefined(game["teamScores"][tl])) return int(game["teamScores"][tl]);

    return 0;
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
    if (awTrimDelay < 0.01) { warnOnce("init_norm_trim_delay", "awTrimDelay normalization failed"); failures++; }
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
    if (trimSafetyMaxDrops < 1) { warnOnce("init_norm_trim_safety", "trimSafetyMaxDrops normalization failed"); failures++; }
    if (atlas45MonitorInterval < 0.05) { warnOnce("init_norm_atlas45_interval", "atlas45MonitorInterval normalization failed"); failures++; }

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

getEffectiveSbmmScale()
{
    return clampFloat((getSbmmDifficultyBucket(getSbmmScale()) * 1.0) / 10.0, 0.0, 1.0);
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
    if (length(token) < 6) return false;
    if (getsubstr(token, 0, 5) != "sbmm_") return false;
    suffix = getsubstr(token, 5, length(token) - 5);
    if (!isNumericString(suffix)) return false;
    bucket = int(suffix);
    return bucket >= 0 && bucket <= 10;
}

isNumericString(value)
{
    if (!isDefined(value) || value == "") return false;

    i = 0;
    while (i < length(value))
    {
        ch = getsubstr(value, i, i + 1);
        if (ch != "0" && ch != "1" && ch != "2" && ch != "3" && ch != "4"
            && ch != "5" && ch != "6" && ch != "7" && ch != "8" && ch != "9")
            return false;
        i++;
    }

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
    observed = getdvar("bot_difficulty");
    if (!isDefined(observed)) observed = "";
    level.autobotDvarDifficulty = toLower(observed);

    if (target != desired)
        warnOnce("bot_diff_dvar_" + desired, "using bot_difficulty dvar fallback \"" + target + "\" while keeping script profile \"" + desired + "\"");

    return level.autobotDvarDifficulty;
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
        scale = getEffectiveSbmmScale();
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
    if (isGunGameActive()) return;
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

getBotTargetPlayerCount()
{
    if (combatTrainingMaxPlayers < 0) return 0;
    return combatTrainingMaxPlayers;
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

getPlayerSbmmMetrics(ent)
{
    metrics = [];
    metrics["positive"] = 0.0;
    metrics["negative"] = 0.0;

    if (!isDefined(ent)) return metrics;

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

    metrics["positive"] = clampFloat(positivePressure, 0.0, 1.0);
    metrics["negative"] = clampFloat(negativePressure, 0.0, 1.0);
    return metrics;
}

getPlayerSbmmPressure(ent)
{
    metrics = getPlayerSbmmMetrics(ent);
    return metrics["positive"];
}

getPlayerSbmmSignedPressure(ent)
{
    metrics = getPlayerSbmmMetrics(ent);
    if (metrics["negative"] > metrics["positive"])
        return 0.0 - metrics["negative"];
    return metrics["positive"];
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

calculateSbmmScale(baseScale, rawStartScale, targetScale, currentScale)
{
    if (!isDefined(currentScale))
    {
        if (targetScale <= baseScale)
            return smoothSbmmScale(rawStartScale, baseScale);

        return smoothSbmmScale(rawStartScale, targetScale);
    }

    currentScale = clampFloat(currentScale, 0.0, 1.0);
    if (targetScale <= baseScale)
        return smoothSbmmScale(currentScale, baseScale);

    return smoothSbmmScale(currentScale, targetScale);
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
        currentScale = undefined;
        if (isDefined(level.autobotSbmmScale))
            currentScale = level.autobotSbmmScale;
        scale = calculateSbmmScale(baseScale, rawStartScale, targetScale, currentScale);
    }

    level.autobotSbmmTargetScale = targetScale;
    level.autobotSbmmScale = scale;
    level.autobotDynamicWinBiasLead = getSbmmLeadForScale(scale);

    if (!botWinBiasEnable)
        level.autobotWinBiasLead = 0;
    else if (getSelectedBotDifficulty() == "sbmm")
        level.autobotWinBiasLead = level.autobotDynamicWinBiasLead;
    else
        level.autobotWinBiasLead = botWinBiasLead;
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
    normalizedDiff = normalizeDifficultyName(diff);
    token = getDifficultyApplyToken(normalizedDiff);

    if (!isDefined(self.pers)) self.pers = [];
    self.pers["autobot_diff_label"] = normalizedDiff;
    self.pers["autobot_diff_applied"] = token;
    if (normalizedDiff == "sbmm")
        self.pers["autobot_sbmm_scale"] = getEffectiveSbmmScale();
    else
        self.pers["autobot_sbmm_scale"] = -1.0;

    self setBotDifficulty(normalizedDiff);
    applyOpLoadout(self);
    atlas45ApplyTierBuff(self, atlas45GetCurrentWeaponSafe(self));
}

applyDifficultyToAllBots(forceWritePers)
{
    safeSetBotDifficultyDvar();
    if (!isDefined(level.players)) return;

    expectedDiff = getSelectedBotDifficulty();
    expectedToken = getDifficultyApplyToken(expectedDiff);
    expectedScale = getEffectiveSbmmScale();

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;

        needsApply = forceWritePers;
        if (!needsApply)
        {
            if (!isDefined(p.pers) || !isDefined(p.pers["autobot_diff_applied"]))
                needsApply = true;
            else if (p.pers["autobot_diff_applied"] != expectedToken)
                needsApply = true;
            else if (expectedDiff == "sbmm" && !isDefined(p.pers["autobot_sbmm_scale"]))
                needsApply = true;
        }

        if (needsApply)
        {
            p applyAutobotDifficulty(expectedDiff);
            p setBotRankCompat(defaultBotLevel);
            p applyBotPrestigeSetting();
            if (awHealthRegenOnSpawn) safeFullHeal(p);
        }
    }

    level.lastAppliedDifficultyToken = expectedToken;
    level.lastAppliedSbmmScale = expectedScale;
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
            player applyAutobotDifficulty(getSelectedBotDifficulty());
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();
            if (awHealthRegenOnSpawn) safeFullHeal(player);
        }
        else
        {
            previousToken = getDifficultyApplyToken(getSelectedBotDifficulty());
            previousScale = getEffectiveSbmmScale();
            refreshSbmmState();
            if (previousToken != getDifficultyApplyToken(getSelectedBotDifficulty()) || !floatNear(previousScale, getEffectiveSbmmScale(), 0.01))
                requestDifficultyApply(false, "");
            trimBotsToTarget();
        }
    }
}

confirmBotSpawn(beforePlayers, beforeBots)
{
    wait spawnConfirmPhase1Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase2Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase3Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    return false;
}

spawnBotsSafe(amount)
{
    if (!isDefined(amount) || amount <= 0) return false;

    beforePlayers = countTotalPlayersForCap();
    beforeBots = countBots();
    desiredTeam = getPreferredBotSpawnTeam();
    if (desiredTeam == "") desiredTeam = "autoassign";

    spawn_bots(amount, desiredTeam);
    return confirmBotSpawn(beforePlayers, beforeBots);
}

pickBotForDrop()
{
    bots = [];
    if (!isDefined(level.players)) return undefined;

    foreach (p in level.players)
        if (isDefined(p) && (p isBotEntity()))
            bots[bots.size] = p;

    if (bots.size <= 0) return undefined;
    return bots[randomint(bots.size)];
}

kickOneBot()
{
    p = pickBotForDrop();
    if (!isDefined(p)) return false;
    if (!compatUseBotDropNative) return false;
    p bot_drop();
    return true;
}

trimBotsToTarget()
{
    if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;

    hadLock = level.autobotAdjusting;
    if (!hadLock) level.autobotAdjusting = true;

    target = getBotTargetPlayerCount();
    if (target < 0) target = 0;

    safety = trimSafetyMaxDrops;
    while (countTotalPlayersForCap() > target && countBots() > 0 && safety > 0)
    {
        if (!kickOneBot()) break;
        safety--;
        wait (awStyleEnable ? awTrimDelay : 0.05);
    }

    if (!hadLock) level.autobotAdjusting = false;
}

getPreferredBotSpawnTeam()
{
    allies = countPlayersOnTeam("allies");
    axis = countPlayersOnTeam("axis");

    if (allies <= 0 && axis <= 0) return "autoassign";

    if (botWinBiasEnable)
    {
        leadTarget = botWinBiasLead;
        if (isDefined(level.autobotWinBiasLead)) leadTarget = level.autobotWinBiasLead;
        if (leadTarget < 0) leadTarget = 0;

        if (leadTarget > 0)
        {
            balanceDelta = allies - axis;
            if (balanceDelta < 0) balanceDelta = 0 - balanceDelta;
            if (balanceDelta <= godTierTeamBalanceDelta)
            {
                alliesScore = getTeamScore("allies");
                axisScore = getTeamScore("axis");
                scoreDelta = alliesScore - axisScore;

                if (scoreDelta > 0 && scoreDelta >= leadTarget) return "axis";
                if (scoreDelta < 0 && (0 - scoreDelta) >= leadTarget) return "allies";
            }
        }
    }

    if (godTierTeamBalanceEnable && getSelectedBotDifficulty() == "god")
    {
        teamDelta = allies - axis;
        if (teamDelta < 0) teamDelta = 0 - teamDelta;
        if (teamDelta > godTierTeamBalanceDelta)
        {
            if (allies < axis) return "allies";
            if (axis < allies) return "axis";
        }
    }

    if (allies < axis) return "allies";
    if (axis < allies) return "axis";

    humanAllies = countHumansOnTeam("allies");
    humanAxis = countHumansOnTeam("axis");
    if (humanAllies < humanAxis) return "allies";
    if (humanAxis < humanAllies) return "axis";

    return "autoassign";
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

        target = getBotTargetPlayerCount();
        if (target < 0) target = 0;

        attempts = 0;
        while (countTotalPlayersForCap() < target && attempts < maxSpawnAttemptsPerTick)
        {
            if (countTotalPlayersForCap() >= target) break;
            attempts++;
            if (!spawnBotsSafe(1)) wait spawnFailBackoff;
            else wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        if (countTotalPlayersForCap() > target)
            trimBotsToTarget();

        level.autobotAdjusting = false;
        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

delayedBotDifficultyApply()
{
    level endon("game_ended");
    wait 0.5;
    requestDifficultyApply(true, "delayed_apply");
}

botDifficultyEnforcer()
{
    level endon("game_ended");
    for (;;)
    {
        requestDifficultyApply(false, "");
        wait botDifficultyEnforcerInterval;
    }
}

liveSbmmUpdater()
{
    level endon("game_ended");
    for (;;)
    {
        previousScale = getEffectiveSbmmScale();
        previousToken = getDifficultyApplyToken(getSelectedBotDifficulty());

        refreshSbmmState();

        currentScale = getEffectiveSbmmScale();
        currentToken = getDifficultyApplyToken(getSelectedBotDifficulty());

        if (getSelectedBotDifficulty() == "sbmm")
        {
            if (currentToken != previousToken || !floatNear(currentScale, previousScale, 0.01))
                requestDifficultyApply(false, "");
        }

        wait botSbmmUpdateInterval;
    }
}

liveDebugHeartbeat()
{
    level endon("game_ended");
    for (;;)
    {
        if (debugAutobots && debugVerbose)
        {
            totalCap = countTotalPlayersForCap();
            totalRaw = (isDefined(level.players) ? level.players.size : 0);
            humans = countHumans();
            bots = countBots();
            preferredSpawnTeam = "";
            if (debugLogPreferredSpawnTeam) preferredSpawnTeam = getPreferredBotSpawnTeam();
            dbg("heartbeat totalCap=" + totalCap
                + " totalRaw=" + totalRaw
                + " humans=" + humans
                + " bots=" + bots
                + " target=" + getBotTargetPlayerCount()
                + " ct=" + level.combatTraining
                + " diff=" + getActiveDifficultyLabel()
                + " scale=" + getSbmmScale()
                + " targetScale=" + (isDefined(level.autobotSbmmTargetScale) ? level.autobotSbmmTargetScale : -1.0)
                + " appliedScale=" + getEffectiveSbmmScale()
                + (debugLogPreferredSpawnTeam ? " spawnTeam=" + preferredSpawnTeam : "")
                + " winBiasLead=" + (isDefined(level.autobotWinBiasLead) ? level.autobotWinBiasLead : botWinBiasLead)
                + " dvar(bot_difficulty)=" + getdvar("bot_difficulty"));
        }
        wait debugHeartbeatInterval;
    }
}

run60SecondSanityTest()
{
    level endon("game_ended");
    if (!debugAutobots) return;

    startTime = 0;
    if (isDefined(level.time)) startTime = level.time;

    samples = 0;
    dvarFailures = 0;
    overTargetFailures = 0;
    anyBotsSeen = false;
    badBotDiffSeen = 0;
    maxOvershoot = 0;
    spawnSuccessStreak = 0;
    spawnFailStreak = 0;
    scaleDriftFailures = 0;

    for (;;)
    {
        elapsed = 0.0;
        if (isDefined(level.time)) elapsed = (level.time - startTime) / 1000.0;
        if (elapsed >= sanityTestDuration) break;

        refreshSbmmState();
        expectedDiff = getSelectedBotDifficulty();
        expectedDvar = getBotDifficultyDvarTarget();
        expectedToken = getDifficultyApplyToken(expectedDiff);
        total = countTotalPlayersForCap();
        bots = countBots();
        target = getBotTargetPlayerCount();
        dvarNow = getdvar("bot_difficulty");
        if (isDefined(dvarNow)) dvarNow = toLower(dvarNow);
        else dvarNow = "";

        if (bots > 0) anyBotsSeen = true;
        if (dvarNow != expectedDvar) dvarFailures++;
        if (total > target) overTargetFailures++;

        overshoot = total - target;
        if (overshoot > maxOvershoot) maxOvershoot = overshoot;

        if (total < target) spawnFailStreak++; else spawnFailStreak = 0;
        if (total >= target) spawnSuccessStreak++; else spawnSuccessStreak = 0;

        badBotDiffSeen += verifyAppliedDifficultyTokens(expectedDiff, "sanity_test");
        if (expectedDiff == "sbmm"
            && isDefined(level.lastAppliedDifficultyToken)
            && level.lastAppliedDifficultyToken == expectedToken
            && isDefined(level.lastAppliedSbmmScale)
            && !floatNear(level.lastAppliedSbmmScale, getEffectiveSbmmScale(), 0.10))
            scaleDriftFailures++;

        samples++;
        wait sanityTestSampleInterval;
    }

    dbg("SANITY end samples=" + samples
        + " dvarFailures=" + dvarFailures
        + " overTargetFailures=" + overTargetFailures
        + " anyBotsSeen=" + anyBotsSeen
        + " badBotDiffSeen=" + badBotDiffSeen
        + " maxOvershoot=" + maxOvershoot
        + " spawnSuccessStreak=" + spawnSuccessStreak
        + " spawnFailStreak=" + spawnFailStreak
        + " scaleDriftFailures=" + scaleDriftFailures
        + " initNormalizationFailures=" + level.initNormalizationFailures
        + " delayedDifficultyApplyFailures=" + level.delayedDifficultyApplyFailures);
}

// =========================
// Atlas 45 upgrade-safe buff
// =========================
atlas45GlobalMonitor()
{
    level endon("game_ended");

    for (;;)
    {
        if (isDefined(level.players))
        {
            foreach (p in level.players)
            {
                if (!isDefined(p)) continue;
                if (!(p isBotEntity())) continue;

                if (!isDefined(p.pers)) p.pers = [];

                if (!isDefined(p.pers["atlas45_monitor_started"]) || !p.pers["atlas45_monitor_started"])
                {
                    p.pers["atlas45_monitor_started"] = true;
                    p thread atlas45EntityMonitor();
                }
            }
        }

        wait 1.0;
    }
}

atlas45EntityMonitor()
{
    self endon("death");
    self endon("disconnect");
    level endon("game_ended");

    if (!isDefined(self.pers)) self.pers = [];
    self.pers["atlas45_last_weapon"] = "";

    for (;;)
    {
        if (!atlas45EnableBuff) { wait atlas45MonitorInterval; continue; }

        w = atlas45GetCurrentWeaponSafe(self);
        if (!isDefined(w)) w = "";
        w = toLower(w);

        last = "";
        if (isDefined(self.pers["atlas45_last_weapon"])) last = self.pers["atlas45_last_weapon"];

        if (w != last)
        {
            self.pers["atlas45_last_weapon"] = w;
            atlas45ApplyTierBuff(self, w);
        }

        wait atlas45MonitorInterval;
    }
}

atlas45GetCurrentWeaponSafe(ent)
{
    if (!isDefined(ent)) return "";
    cw = ent getcurrentweapon();
    if (!isDefined(cw)) return "";
    return cw;
}

atlas45ApplyTierBuff(ent, currentWeapon)
{
    if (!isDefined(ent)) return;
    if (!isDefined(ent.pers)) ent.pers = [];

    w = toLower(currentWeapon);
    mult = 1.0;

    if (w == toLower(atlas45Upg2Id)) mult = atlas45Upg2Mult;
    else if (w == toLower(atlas45Upg1Id)) mult = atlas45Upg1Mult;
    else if (w == toLower(atlas45BaseId)) mult = atlas45BaseMult;

    ent.pers["weapon_damage_mult_" + atlas45BaseId] = 1.0;
    ent.pers["weapon_damage_mult_" + atlas45Upg1Id] = 1.0;
    ent.pers["weapon_damage_mult_" + atlas45Upg2Id] = 1.0;

    if (mult > 1.0)
    {
        ent.pers["weapon_damage_mult_" + atlas45BaseId] = mult;
        ent.pers["weapon_damage_mult_" + atlas45Upg1Id] = mult;
        ent.pers["weapon_damage_mult_" + atlas45Upg2Id] = mult;
        ent.pers["atlas45_damage_mult_active"] = mult;
    }
    else
    {
        ent.pers["atlas45_damage_mult_active"] = 1.0;
    }
}

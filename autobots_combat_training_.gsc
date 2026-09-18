// ============================================================
// Autobots Combat Training Script (MP-ONLY, HARDENED v5)
// - Forces locked difficulty to ULTRA
// - Fixes persistence by normalizing + enforcing dvar + per-bot state
// - Optional SBMM-style runtime bot profiles while keeping bot_difficulty locked to ULTRA
// ============================================================
#include scripts/mp/_bots;

// --------------------------
// Config
// --------------------------
combatTrainingForce = true;
combatTrainingMaxPlayers = 12;
dedicatedMaxPlayers = 18;

// FORCE ULTRA
defaultBotDifficulty = "ultra";
lockedBotDifficulty  = "ultra";

defaultBotLevel = 50;
defaultBotPrestige = 23;

awStyleEnable = true;
awPressureSpawnDelay = 0.15;
awTrimDelay = 0.03;
awHealthRegenOnSpawn = true;

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
debugHeartbeatInterval = 5.0;

botDifficultyEnforcerInterval = 2.0;
spawnFailBackoff = 0.50;
maxSpawnAttemptsPerTick = 8;

sanityTestEnable = true;
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
countStateLogUnknownOnce = true;

// --------------------------
// SBMM-style runtime tuning
// Server owner tuning:
// - Leave sbmmEnable = false to preserve the old fixed ultra baseline below.
// - Keep bot_difficulty locked to ultra; only tune the bounded bot entity fields here.
// - Low/Base/High are the safe profile anchors. Standard = Base, Protected = Low,
//   Challenging = Base->High midpoint, Elite = High.
// - Adjust K/D + score-per-minute weights/thresholds to decide when the lobby climbs tiers.
// --------------------------
sbmmEnable = true;
sbmmEvaluationInterval = 10.0;

sbmmNewPlayerKd = 1.0;
sbmmNewPlayerScorePerMinute = 150.0;
sbmmMinimumTrackedMinutes = 0.25;
sbmmKdWeight = 0.70;
sbmmScoreWeight = 0.30;
sbmmKdFloor = 1.0;
sbmmKdLow = 0.75;
sbmmKdHigh = 2.25;
sbmmScorePerMinuteLow = 75.0;
sbmmScorePerMinuteHigh = 350.0;
sbmmSmoothRise = 0.45;
sbmmSmoothFall = 0.25;
sbmmTierProtectedMax = 0.28;
sbmmTierChallengingMin = 0.58;
sbmmTierEliteMin = 0.82;
sbmmTierHysteresis = 0.05;

sbmmLowAccuracy = 2.15;
sbmmLowReactionTime = 0.03;
sbmmLowMaxHealth = 500;
sbmmLowAggression = 2.05;

sbmmBaseAccuracy = 2.75;
sbmmBaseReactionTime = 0.01;
sbmmBaseMaxHealth = 650;
sbmmBaseAggression = 2.75;

sbmmHighAccuracy = 3.35;
sbmmHighReactionTime = 0.005;
sbmmHighMaxHealth = 800;
sbmmHighAggression = 3.30;

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
        dbg("init(): disabled for this mode/map (Exo Survival/Exo Zombies or non-MP context)");
        return;
    }

    if (combatTrainingMaxPlayers < 0) combatTrainingMaxPlayers = 0;
    if (dedicatedMaxPlayers < 0) dedicatedMaxPlayers = 0;
    if (awPressureSpawnDelay < 0.05) awPressureSpawnDelay = 0.05;
    if (awTrimDelay < 0.01) awTrimDelay = 0.01;
    if (debugHeartbeatInterval < 0.2) debugHeartbeatInterval = 0.2;
    if (botDifficultyEnforcerInterval < 1.0) botDifficultyEnforcerInterval = 1.0;
    if (spawnFailBackoff < 0.10) spawnFailBackoff = 0.10;
    if (maxSpawnAttemptsPerTick < 1) maxSpawnAttemptsPerTick = 1;
    if (sanityTestDuration < 5.0) sanityTestDuration = 5.0;
    if (sanityTestSampleInterval < 1.0) sanityTestSampleInterval = 1.0;
    if (defaultBotPrestige < 0) defaultBotPrestige = 0;
    if (spawnConfirmPhase1Delay < 0.01) spawnConfirmPhase1Delay = 0.01;
    if (spawnConfirmPhase2Delay < 0.01) spawnConfirmPhase2Delay = 0.01;
    if (spawnConfirmPhase3Delay < 0.01) spawnConfirmPhase3Delay = 0.01;
    if (trimSafetyMaxDrops < 1) trimSafetyMaxDrops = 1;
    if (atlas45MonitorInterval < 0.05) atlas45MonitorInterval = 0.05;
    if (sbmmEvaluationInterval < 2.0) sbmmEvaluationInterval = 2.0;
    if (sbmmNewPlayerKd < 0.1) sbmmNewPlayerKd = 0.1;
    if (sbmmNewPlayerScorePerMinute < 0.0) sbmmNewPlayerScorePerMinute = 0.0;
    if (sbmmMinimumTrackedMinutes < 0.05) sbmmMinimumTrackedMinutes = 0.05;
    if (sbmmKdWeight < 0.0) sbmmKdWeight = 0.0;
    if (sbmmScoreWeight < 0.0) sbmmScoreWeight = 0.0;
    if ((sbmmKdWeight + sbmmScoreWeight) <= 0.0)
    {
        sbmmKdWeight = 0.70;
        sbmmScoreWeight = 0.30;
    }
    if (sbmmKdFloor < 0.25) sbmmKdFloor = 0.25;
    if (sbmmKdLow < 0.1) sbmmKdLow = 0.1;
    if (sbmmKdHigh <= sbmmKdLow) sbmmKdHigh = sbmmKdLow + 0.25;
    if (sbmmScorePerMinuteLow < 0.0) sbmmScorePerMinuteLow = 0.0;
    if (sbmmScorePerMinuteHigh <= sbmmScorePerMinuteLow) sbmmScorePerMinuteHigh = sbmmScorePerMinuteLow + 25.0;
    if (sbmmSmoothRise <= 0.0 || sbmmSmoothRise > 1.0) sbmmSmoothRise = 0.45;
    if (sbmmSmoothFall <= 0.0 || sbmmSmoothFall > 1.0) sbmmSmoothFall = 0.25;
    if (sbmmTierProtectedMax < 0.0) sbmmTierProtectedMax = 0.0;
    if (sbmmTierProtectedMax > 1.0) sbmmTierProtectedMax = 1.0;
    if (sbmmTierChallengingMin <= sbmmTierProtectedMax) sbmmTierChallengingMin = sbmmTierProtectedMax + 0.10;
    if (sbmmTierChallengingMin > 0.90) sbmmTierChallengingMin = 0.90;
    if (sbmmTierEliteMin <= sbmmTierChallengingMin) sbmmTierEliteMin = sbmmTierChallengingMin + 0.10;
    if (sbmmTierEliteMin > 1.0)
    {
        sbmmTierEliteMin = 1.0;
        if (sbmmTierChallengingMin >= sbmmTierEliteMin) sbmmTierChallengingMin = sbmmTierEliteMin - 0.10;
    }
    if (sbmmTierHysteresis < 0.0) sbmmTierHysteresis = 0.0;
    if (sbmmTierHysteresis > 0.20) sbmmTierHysteresis = 0.20;
    if (sbmmLowReactionTime < 0.005) sbmmLowReactionTime = 0.005;
    if (sbmmBaseReactionTime < 0.005) sbmmBaseReactionTime = 0.005;
    if (sbmmHighReactionTime < 0.005) sbmmHighReactionTime = 0.005;
    if (sbmmLowMaxHealth < 1) sbmmLowMaxHealth = 1;
    if (sbmmBaseMaxHealth < 1) sbmmBaseMaxHealth = 1;
    if (sbmmHighMaxHealth < 1) sbmmHighMaxHealth = 1;

    if (!isDefined(level.autobotsWarnOnce)) level.autobotsWarnOnce = [];
    if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;

    if (!combatTrainingForce) level.combatTraining = detectCombatTraining();
    else level.combatTraining = true;

    lockedBotDifficulty = "ultra";
    defaultBotDifficulty = "ultra";
    setdvar("bot_difficulty", "ultra");
    initSbmmState();

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();
    level thread atlas45GlobalMonitor();
    if (sbmmEnable) level thread sbmmLobbyDifficultyManager();

    if (sanityTestEnable) level thread run60SecondSanityTest();
}

shouldRunAutobotsHere()
{
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
        if (isSubStr(pl, "survival") || isSubStr(pl, "zombie") || isSubStr(pl, "exo")) return false;
    }

    return true;
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
    if (isSubStr(gt, "combat") || isSubStr(gt, "training")) return true;

    mn = "";
    if (isDefined(level.mapname)) mn = toLower(level.mapname);
    if (isSubStr(mn, "combat") || isSubStr(mn, "training")) return true;

    return false;
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

clampNumber(value, minValue, maxValue)
{
    if (!isDefined(value)) return minValue;
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
}

initSbmmState()
{
    level.sbmmActiveTier = "standard";
    level.sbmmActiveProfileKey = "base";
    level.sbmmLastRawRating = 0.50;
    level.sbmmSmoothedRating = 0.50;
    level.sbmmTrackedHumans = 0;
}

getActiveSbmmTier()
{
    if (!sbmmEnable) return "standard";
    if (!isDefined(level.sbmmActiveTier) || level.sbmmActiveTier == "") return "standard";
    return level.sbmmActiveTier;
}

getActiveSbmmProfileKey()
{
    if (!sbmmEnable) return "base";
    if (!isDefined(level.sbmmActiveProfileKey) || level.sbmmActiveProfileKey == "") return "base";
    return level.sbmmActiveProfileKey;
}

getSbmmProfileKeyForTier(tier)
{
    if (!sbmmEnable) return "base";
    if (tier == "protected") return "low";
    if (tier == "challenging") return "mid";
    if (tier == "elite") return "high";
    return "base";
}

getSbmmProfileAccuracy(profileKey)
{
    if (profileKey == "low") return sbmmLowAccuracy;
    if (profileKey == "mid") return (sbmmBaseAccuracy + sbmmHighAccuracy) / 2.0;
    if (profileKey == "high") return sbmmHighAccuracy;
    return sbmmBaseAccuracy;
}

getSbmmProfileReactionTime(profileKey)
{
    if (profileKey == "low") return sbmmLowReactionTime;
    if (profileKey == "mid") return (sbmmBaseReactionTime + sbmmHighReactionTime) / 2.0;
    if (profileKey == "high") return sbmmHighReactionTime;
    return sbmmBaseReactionTime;
}

getSbmmProfileMaxHealth(profileKey)
{
    if (profileKey == "low") return sbmmLowMaxHealth;
    if (profileKey == "mid") return int((sbmmBaseMaxHealth + sbmmHighMaxHealth) / 2.0);
    if (profileKey == "high") return sbmmHighMaxHealth;
    return sbmmBaseMaxHealth;
}

getSbmmProfileAggression(profileKey)
{
    if (profileKey == "low") return sbmmLowAggression;
    if (profileKey == "mid") return (sbmmBaseAggression + sbmmHighAggression) / 2.0;
    if (profileKey == "high") return sbmmHighAggression;
    return sbmmBaseAggression;
}

getSbmmDebugSuffix()
{
    if (!sbmmEnable) return "";

    tier = getActiveSbmmTier();
    profileKey = getActiveSbmmProfileKey();
    ratingPct = 50;
    rawPct = 50;
    humans = 0;

    if (isDefined(level.sbmmSmoothedRating)) ratingPct = int(clampNumber(level.sbmmSmoothedRating, 0.0, 1.0) * 100.0);
    if (isDefined(level.sbmmLastRawRating)) rawPct = int(clampNumber(level.sbmmLastRawRating, 0.0, 1.0) * 100.0);
    if (isDefined(level.sbmmTrackedHumans)) humans = level.sbmmTrackedHumans;

    return " sbmmTier=" + tier
        + " sbmmProfile=" + profileKey
        + " sbmmRatingPct=" + ratingPct
        + " sbmmRawPct=" + rawPct
        + " sbmmHumans=" + humans;
}

setBotDifficulty(difficulty)
{
    profileKey = getActiveSbmmProfileKey();
    activeTier = getActiveSbmmTier();

    self.botAccuracy = getSbmmProfileAccuracy(profileKey);
    self.reactionTime = getSbmmProfileReactionTime(profileKey);
    self.maxHealth = getSbmmProfileMaxHealth(profileKey);
    self.botAggression = getSbmmProfileAggression(profileKey);

    if (!isDefined(self.pers)) self.pers = [];
    self.pers["autobot_profile_applied"] = profileKey;
    self.pers["autobot_sbmm_tier"] = activeTier;

    if (awHealthRegenOnSpawn) safeFullHeal(self);
}

applyOpLoadout(ent)
{
    if (!opWeaponsEnable || !isDefined(ent)) return;
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

countCountableHumans()
{
    if (!isDefined(level.players)) return 0;
    n = 0; foreach (p in level.players) if (isDefined(p) && !(p isBotEntity()) && isPlayerCountable(p)) n++;
    return n;
}

isCurrentPlayerEntity(ent)
{
    if (!isDefined(ent) || !isDefined(level.players)) return false;

    foreach (p in level.players)
        if (isDefined(p) && p == ent)
            return true;

    return false;
}

// Event-driven first, with direct stat sampling as a defensive fallback for runtimes
// that do not expose all death event arguments or scoreboard fields the same way.
getSbmmKillsSample(ent)
{
    if (!isDefined(ent)) return 0;
    if (isDefined(ent.kills)) return int(ent.kills);
    if (isDefined(ent.pers) && isDefined(ent.pers["kills"])) return int(ent.pers["kills"]);
    return 0;
}

getSbmmDeathsSample(ent)
{
    if (!isDefined(ent)) return 0;
    if (isDefined(ent.deaths)) return int(ent.deaths);
    if (isDefined(ent.pers) && isDefined(ent.pers["deaths"])) return int(ent.pers["deaths"]);
    return 0;
}

getSbmmScoreSample(ent)
{
    if (!isDefined(ent)) return 0;
    if (isDefined(ent.score)) return int(ent.score);
    if (isDefined(ent.pers) && isDefined(ent.pers["score"])) return int(ent.pers["score"]);
    if (isDefined(ent.pers) && isDefined(ent.pers["playerScore"])) return int(ent.pers["playerScore"]);
    return 0;
}

initSbmmStatBaselines(ent)
{
    if (!isDefined(ent)) return;
    if (!isDefined(ent.pers)) ent.pers = [];

    if (!isDefined(ent.pers["sbmm_event_kills"])) ent.pers["sbmm_event_kills"] = 0;
    if (!isDefined(ent.pers["sbmm_event_deaths"])) ent.pers["sbmm_event_deaths"] = 0;
    if (!isDefined(ent.pers["sbmm_base_kills"])) ent.pers["sbmm_base_kills"] = getSbmmKillsSample(ent);
    if (!isDefined(ent.pers["sbmm_base_deaths"])) ent.pers["sbmm_base_deaths"] = getSbmmDeathsSample(ent);
    if (!isDefined(ent.pers["sbmm_base_score"])) ent.pers["sbmm_base_score"] = getSbmmScoreSample(ent);
    if (!isDefined(ent.pers["sbmm_join_time"]))
    {
        if (isDefined(level.time)) ent.pers["sbmm_join_time"] = level.time;
        else ent.pers["sbmm_join_time"] = 0;
    }
}

startSbmmEntityTrackerIfNeeded(ent)
{
    if (!sbmmEnable || !isDefined(ent)) return;
    if (!isDefined(ent.pers)) ent.pers = [];

    initSbmmStatBaselines(ent);

    if (!isDefined(ent.pers["sbmm_tracker_started"]) || !ent.pers["sbmm_tracker_started"])
    {
        ent.pers["sbmm_tracker_started"] = true;
        ent thread sbmmTrackEntityDeaths();
    }
}

sbmmTrackEntityDeaths()
{
    self endon("disconnect");
    level endon("game_ended");

    for (;;)
    {
        attacker = undefined;
        self waittill("death", attacker);

        initSbmmStatBaselines(self);

        if (!(self isBotEntity()))
            self.pers["sbmm_event_deaths"]++;

        if (!isDefined(attacker) || attacker == self) continue;
        if (!isCurrentPlayerEntity(attacker)) continue;

        startSbmmEntityTrackerIfNeeded(attacker);
        if (!(attacker isBotEntity()))
            attacker.pers["sbmm_event_kills"]++;
    }
}

ensureSbmmTrackers()
{
    if (!sbmmEnable || !isDefined(level.players)) return;

    foreach (p in level.players)
    {
        if (!isDefined(p)) continue;
        startSbmmEntityTrackerIfNeeded(p);
    }
}

getSbmmTrackedKills(ent)
{
    initSbmmStatBaselines(ent);

    sampleNow = getSbmmKillsSample(ent);
    base = ent.pers["sbmm_base_kills"];
    delta = sampleNow - base;

    if (delta < 0)
    {
        ent.pers["sbmm_base_kills"] = sampleNow;
        delta = 0;
    }

    tracked = ent.pers["sbmm_event_kills"];
    if (delta > tracked) tracked = delta;
    if (tracked < 0) tracked = 0;
    return tracked;
}

getSbmmTrackedDeaths(ent)
{
    initSbmmStatBaselines(ent);

    sampleNow = getSbmmDeathsSample(ent);
    base = ent.pers["sbmm_base_deaths"];
    delta = sampleNow - base;

    if (delta < 0)
    {
        ent.pers["sbmm_base_deaths"] = sampleNow;
        delta = 0;
    }

    tracked = ent.pers["sbmm_event_deaths"];
    if (delta > tracked) tracked = delta;
    if (tracked < 0) tracked = 0;
    return tracked;
}

getSbmmTrackedScore(ent)
{
    initSbmmStatBaselines(ent);

    sampleNow = getSbmmScoreSample(ent);
    base = ent.pers["sbmm_base_score"];
    delta = sampleNow - base;

    if (delta < 0)
    {
        ent.pers["sbmm_base_score"] = sampleNow;
        delta = 0;
    }

    if (delta < 0) delta = 0;
    return delta;
}

getSbmmTrackedMinutes(ent)
{
    initSbmmStatBaselines(ent);

    now = 0;
    if (isDefined(level.time)) now = level.time;

    joinTime = ent.pers["sbmm_join_time"];
    elapsedMs = now - joinTime;
    if (elapsedMs <= 0) return sbmmMinimumTrackedMinutes;

    minutes = elapsedMs / 60000.0;
    if (minutes < sbmmMinimumTrackedMinutes) return sbmmMinimumTrackedMinutes;
    return minutes;
}

normalizeSbmmValue(value, lowValue, highValue)
{
    if (highValue <= lowValue) return 0.50;
    return clampNumber((value - lowValue) / (highValue - lowValue), 0.0, 1.0);
}

getSbmmPlayerRating(ent)
{
    kills = getSbmmTrackedKills(ent);
    deaths = getSbmmTrackedDeaths(ent);
    score = getSbmmTrackedScore(ent);
    minutes = getSbmmTrackedMinutes(ent);

    activity = kills + deaths;
    if (activity <= 0 && score <= 0)
    {
        kd = sbmmNewPlayerKd;
        spm = sbmmNewPlayerScorePerMinute;
    }
    else
    {
        kdDivisor = deaths;
        if (kdDivisor < sbmmKdFloor) kdDivisor = sbmmKdFloor;

        kd = kills / kdDivisor;
        spm = score / minutes;
    }

    kdNorm = normalizeSbmmValue(kd, sbmmKdLow, sbmmKdHigh);
    scoreNorm = normalizeSbmmValue(spm, sbmmScorePerMinuteLow, sbmmScorePerMinuteHigh);

    totalWeight = sbmmKdWeight + sbmmScoreWeight;
    if (totalWeight <= 0.0) return 0.50;

    return clampNumber(((kdNorm * sbmmKdWeight) + (scoreNorm * sbmmScoreWeight)) / totalWeight, 0.0, 1.0);
}

calculateSbmmLobbyRating()
{
    totalRating = 0.0;
    humans = 0;

    if (!isDefined(level.players))
    {
        level.sbmmTrackedHumans = 0;
        return 0.50;
    }

    foreach (p in level.players)
    {
        if (!isDefined(p) || (p isBotEntity()) || !isPlayerCountable(p)) continue;
        totalRating += getSbmmPlayerRating(p);
        humans++;
    }

    level.sbmmTrackedHumans = humans;

    if (humans <= 0) return 0.50;
    return clampNumber(totalRating / humans, 0.0, 1.0);
}

pickSbmmTierNoHysteresis(rating)
{
    if (rating >= sbmmTierEliteMin) return "elite";
    if (rating >= sbmmTierChallengingMin) return "challenging";
    if (rating <= sbmmTierProtectedMax) return "protected";
    return "standard";
}

pickSbmmTier(rating, currentTier)
{
    if (!isDefined(currentTier) || currentTier == "") return pickSbmmTierNoHysteresis(rating);

    if (currentTier == "protected")
    {
        if (rating >= (sbmmTierProtectedMax + sbmmTierHysteresis)) return "standard";
        return "protected";
    }

    if (currentTier == "challenging")
    {
        if (rating < (sbmmTierChallengingMin - sbmmTierHysteresis)) return "standard";
        if (rating >= (sbmmTierEliteMin + sbmmTierHysteresis)) return "elite";
        return "challenging";
    }

    if (currentTier == "elite")
    {
        if (rating < (sbmmTierEliteMin - sbmmTierHysteresis)) return "challenging";
        return "elite";
    }

    if (rating < (sbmmTierProtectedMax - sbmmTierHysteresis)) return "protected";
    if (rating >= (sbmmTierChallengingMin + sbmmTierHysteresis)) return "challenging";
    return "standard";
}

smoothSbmmRating(rawRating)
{
    if (!isDefined(level.sbmmSmoothedRating))
    {
        level.sbmmSmoothedRating = rawRating;
        return rawRating;
    }

    alpha = sbmmSmoothFall;
    if (rawRating > level.sbmmSmoothedRating) alpha = sbmmSmoothRise;

    level.sbmmSmoothedRating = clampNumber(level.sbmmSmoothedRating + ((rawRating - level.sbmmSmoothedRating) * alpha), 0.0, 1.0);
    return level.sbmmSmoothedRating;
}

evaluateSbmmAndApply(forceBotRefresh)
{
    if (!sbmmEnable) return;

    ensureSbmmTrackers();

    rawRating = calculateSbmmLobbyRating();
    level.sbmmLastRawRating = rawRating;

    smoothedRating = smoothSbmmRating(rawRating);
    newTier = pickSbmmTier(smoothedRating, level.sbmmActiveTier);
    newProfileKey = getSbmmProfileKeyForTier(newTier);

    tierChanged = !isDefined(level.sbmmActiveTier) || level.sbmmActiveTier != newTier;
    profileChanged = !isDefined(level.sbmmActiveProfileKey) || level.sbmmActiveProfileKey != newProfileKey;

    level.sbmmActiveTier = newTier;
    level.sbmmActiveProfileKey = newProfileKey;

    if (tierChanged || profileChanged || forceBotRefresh)
        applyDifficultyToAllBots(true);
}

sbmmLobbyDifficultyManager()
{
    level endon("game_ended");
    wait 0.5;
    evaluateSbmmAndApply(true);

    for (;;)
    {
        wait sbmmEvaluationInterval;
        evaluateSbmmAndApply(false);
    }
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
    self.pers["autobot_diff_applied"] = "ultra";
    self setBotDifficulty("ultra");
    applyOpLoadout(self);
    atlas45ApplyTierBuff(self, atlas45GetCurrentWeaponSafe(self));
}

applyDifficultyToAllBots(forceWritePers)
{
    if (getdvar("bot_difficulty") != "ultra") setdvar("bot_difficulty", "ultra");
    if (!isDefined(level.players)) return;

    currentTier = getActiveSbmmTier();
    currentProfileKey = getActiveSbmmProfileKey();

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;

        needsApply = true;
        if (isDefined(p.pers)
            && isDefined(p.pers["autobot_diff_applied"])
            && p.pers["autobot_diff_applied"] == "ultra"
            && isDefined(p.pers["autobot_profile_applied"])
            && p.pers["autobot_profile_applied"] == currentProfileKey
            && isDefined(p.pers["autobot_sbmm_tier"])
            && p.pers["autobot_sbmm_tier"] == currentTier
            && !forceWritePers)
            needsApply = false;

        if (needsApply)
        {
            p applyAutobotDifficulty("ultra");
            p setBotRankCompat(defaultBotLevel);
            p applyBotPrestigeSetting();

            if (!isDefined(p.pers)) p.pers = [];
            p.pers["autobot_diff_applied"] = "ultra";
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

        if (sbmmEnable) startSbmmEntityTrackerIfNeeded(player);

        if (player isBotEntity())
        {
            player applyAutobotDifficulty("ultra");
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();

            if (!isDefined(player.pers)) player.pers = [];
            player.pers["autobot_diff_applied"] = "ultra";

            if (awHealthRegenOnSpawn) safeFullHeal(player);
        }
        else if (!level.combatTraining)
        {
            trimBotsToTarget();
        }
    }
}

spawnBotsSafe(amount)
{
    if (!isDefined(amount) || amount <= 0) return false;

    beforePlayers = countTotalPlayersForCap();
    beforeBots = countBots();

    spawn_bots(amount, "autoassign");

    wait spawnConfirmPhase1Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase2Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase3Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    return false;
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

    target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
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

serverBotFill()
{
    level endon("game_ended");
    wait 0.05;

    for (;;)
    {
        if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;
        if (level.autobotAdjusting) { wait 0.10; continue; }
        level.autobotAdjusting = true;

        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
        if (target < 0) target = 0;

        attempts = 0;
        while (countTotalPlayersForCap() < target && attempts < maxSpawnAttemptsPerTick)
        {
            if (countTotalPlayersForCap() >= target) break;
            attempts++;
            if (!spawnBotsSafe(1)) wait spawnFailBackoff;
            else wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        if (!level.combatTraining && countTotalPlayersForCap() > target)
            trimBotsToTarget();

        level.autobotAdjusting = false;
        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

delayedBotDifficultyApply()
{
    level endon("game_ended");
    wait 0.5;
    setdvar("bot_difficulty", "ultra");
    applyDifficultyToAllBots(true);
}

botDifficultyEnforcer()
{
    level endon("game_ended");
    for (;;)
    {
        if (getdvar("bot_difficulty") != "ultra")
            setdvar("bot_difficulty", "ultra");

        applyDifficultyToAllBots(false);
        wait botDifficultyEnforcerInterval;
    }
}

liveDebugHeartbeat()
{
    level endon("game_ended");
    for (;;)
    {
        if (debugAutobots && debugVerbose)
        {
            target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
            dbg("heartbeat totalCap=" + countTotalPlayersForCap()
                + " totalRaw=" + (isDefined(level.players) ? level.players.size : 0)
                + " humans=" + countHumans()
                + " bots=" + countBots()
                + " target=" + target
                + " ct=" + level.combatTraining
                + " diff=ultra"
                + " dvar(bot_difficulty)=" + getdvar("bot_difficulty")
                + getSbmmDebugSuffix());
        }
        wait debugHeartbeatInterval;
    }
}

run60SecondSanityTest()
{
    level endon("game_ended");
    if (!debugAutobots) return;

    expected = "ultra";
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

    for (;;)
    {
        elapsed = 0.0;
        if (isDefined(level.time)) elapsed = (level.time - startTime) / 1000.0;
        if (elapsed >= sanityTestDuration) break;

        total = countTotalPlayersForCap();
        bots = countBots();
        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
        dvarNow = getdvar("bot_difficulty");

        if (bots > 0) anyBotsSeen = true;
        if (dvarNow != expected) dvarFailures++;
        if (!level.combatTraining && total > target) overTargetFailures++;

        overshoot = total - target;
        if (overshoot > maxOvershoot) maxOvershoot = overshoot;

        if (total < target) spawnFailStreak++; else spawnFailStreak = 0;
        if (total >= target) spawnSuccessStreak++; else spawnSuccessStreak = 0;

        if (isDefined(level.players))
        {
            foreach (p in level.players)
            {
                if (!isDefined(p) || !(p isBotEntity())) continue;
                if (!isDefined(p.pers) || !isDefined(p.pers["autobot_diff_applied"]) || p.pers["autobot_diff_applied"] != expected)
                    badBotDiffSeen++;
            }
        }

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
        + getSbmmDebugSuffix());
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
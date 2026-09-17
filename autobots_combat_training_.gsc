// ============================================================
// Autobots Combat Training Script (CT-ONLY, HARDENED v6)
// - Restricts execution to multiplayer Combat Training only
// - Supports configurable GOD difficulty with ULTRA dvar fallback
// - Fixes persistence by normalizing + enforcing dvar + per-bot state
// ============================================================
#include scripts/mp/_bots;

// --------------------------
// Config
// --------------------------
combatTrainingMaxPlayers = 18;

botDifficultyMode = "god";
botDifficultyFallback = "ultra";

defaultBotDifficulty = "god";
lockedBotDifficulty  = "god";

godMaxAccuracy = 1000.0;
godMinReactionTime = 0.0;
godMaxHealth = 1000000;
godMaxAggression = 1000.0;

defaultBotLevel = 50;
defaultBotPrestige = 23;

awStyleEnable = true;
awPressureSpawnDelay = 0.15;
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
    if (spawnFailBackoff < 0.10) spawnFailBackoff = 0.10;
    if (maxSpawnAttemptsPerTick < 1) maxSpawnAttemptsPerTick = 1;
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
    botDifficultyFallback = normalizeDifficultyName(botDifficultyFallback);
    defaultBotDifficulty = botDifficultyMode;
    lockedBotDifficulty = botDifficultyMode;

    safeSetBotDifficultyDvar();
    runSpawnBiasSanityCheck();

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();

    dbg("init(): Combat Training only active | diff=" + defaultBotDifficulty + " | dvar=" + level.autobotDvarDifficulty);
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
    if (isSubStr(gt, "exo")) return false;

    if (isDefined(level.playlist))
    {
        pl = toLower(level.playlist);
        if (isSubStr(pl, "survival") || isSubStr(pl, "zombie") || isSubStr(pl, "exo")) return false;
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
    if (isSubStr(gt, "combat") || isSubStr(gt, "training")) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (isSubStr(pl, "combat") || isSubStr(pl, "training") || isSubStr(pl, "readiness")) return true;

    mn = "";
    if (isDefined(level.mapname)) mn = toLower(level.mapname);
    if (isSubStr(mn, "combat") || isSubStr(mn, "training")) return true;

    return false;
}

normalizeTeamName(value)
{
    if (!isDefined(value)) return "";
    return toLower(value + "");
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

normalizeDifficultyName(difficulty)
{
    if (!isDefined(difficulty)) return "ultra";
    difficulty = toLower(difficulty);
    if (difficulty == "god") return "god";
    if (difficulty == "ultra") return "ultra";
    return "ultra";
}

getSelectedBotDifficulty()
{
    return normalizeDifficultyName(defaultBotDifficulty);
}

getBotDifficultyDvarTarget()
{
    desired = getSelectedBotDifficulty();
    fallback = normalizeDifficultyName(botDifficultyFallback);
    if (desired == "god")
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
    else
    {
        self.botAccuracy = 2.75;
        self.reactionTime = 0.01;
        self.maxHealth = 650;
        self.botAggression = 2.75;
    }

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
    self.pers["autobot_diff_applied"] = selectedDifficulty;
    self setBotDifficulty(selectedDifficulty);
    applyOpLoadout(self);
}

applyDifficultyToAllBots(forceWritePers)
{
    selectedDifficulty = getSelectedBotDifficulty();
    safeSetBotDifficultyDvar();
    if (!isDefined(level.players)) return;

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;

        needsApply = true;
        if (isDefined(p.pers) && isDefined(p.pers["autobot_diff_applied"]) && p.pers["autobot_diff_applied"] == selectedDifficulty && !forceWritePers)
            needsApply = false;

        if (needsApply)
        {
            p applyAutobotDifficulty(selectedDifficulty);
            p setBotRankCompat(defaultBotLevel);
            p applyBotPrestigeSetting();

            if (!isDefined(p.pers)) p.pers = [];
            p.pers["autobot_diff_applied"] = selectedDifficulty;
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
            player applyAutobotDifficulty(getSelectedBotDifficulty());
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();

            if (!isDefined(player.pers)) player.pers = [];
            player.pers["autobot_diff_applied"] = getSelectedBotDifficulty();

            if (awHealthRegenOnSpawn) safeFullHeal(player);
        }
    }
}

normalizeSpawnTeam(preferredTeam)
{
    if (!isDefined(preferredTeam)) return "autoassign";

    pt = normalizeTeamName(preferredTeam);
    if (pt == "allies" || pt == "axis")
        return pt;

    return "autoassign";
}

runSpawnBiasSanityCheck()
{
    if (normalizeSpawnTeam("allies") != "allies")
        warnOnce("spawn_bias_allies", "spawn bias sanity failed for allies");

    if (normalizeSpawnTeam("axis") != "axis")
        warnOnce("spawn_bias_axis", "spawn bias sanity failed for axis");

    if (normalizeSpawnTeam(undefined) != "autoassign")
        warnOnce("spawn_bias_undef", "spawn bias sanity failed for undefined");

    if (normalizeSpawnTeam("bogus") != "autoassign")
        warnOnce("spawn_bias_invalid", "spawn bias sanity failed for invalid team");
}

spawnBotsSafe(amount, preferredTeam)
{
    if (!isDefined(amount) || amount <= 0) return false;

    beforePlayers = countTotalPlayersForCap();
    beforeBots = countBots();

    spawnTeam = normalizeSpawnTeam(preferredTeam);
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

            if (!spawnBotsSafe(1, spawnTeam)) wait spawnFailBackoff;
            else wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        level.autobotAdjusting = false;
        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

getEntityTeamName(ent)
{
    if (!isDefined(ent)) return "";
    if (isDefined(ent.team)) return normalizeTeamName(ent.team);
    if (isDefined(ent.sessionteam)) return normalizeTeamName(ent.sessionteam);
    if (isDefined(ent.pers) && isDefined(ent.pers["team"])) return normalizeTeamName(ent.pers["team"]);
    return "";
}

countBotsOnTeam(teamName)
{
    if (!isDefined(level.players)) return 0;

    tl = normalizeTeamName(teamName);
    n = 0;
    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;
        if (getEntityTeamName(p) != tl) continue;
        n++;
    }

    return n;
}

countAlliedBots() { return countBotsOnTeam("allies"); }
countAxisBots()   { return countBotsOnTeam("axis"); }

getPreferredBotWinTeam()
{
    alliesHumans = countHumansOnTeam("allies");
    axisHumans = countHumansOnTeam("axis");

    if (alliesHumans <= 0 && axisHumans <= 0) return "";
    if (alliesHumans > axisHumans) return "axis";
    if (axisHumans > alliesHumans) return "allies";
    return "";
}

getPreferredBotSpawnTeam()
{
    if (!botWinBiasEnable || botWinBiasLead <= 0) return "";

    preferredTeam = getPreferredBotWinTeam();
    if (preferredTeam == "") return "";

    otherTeam = "allies";
    if (preferredTeam == "allies") otherTeam = "axis";

    botLead = countBotsOnTeam(preferredTeam) - countBotsOnTeam(otherTeam);
    if (botLead < botWinBiasLead) return preferredTeam;

    return "";
}


delayedBotDifficultyApply()
{
    level endon("game_ended");
    wait 0.5;
    safeSetBotDifficultyDvar();
    applyDifficultyToAllBots(true);
}

botDifficultyEnforcer()
{
    level endon("game_ended");
    for (;;)
    {
        safeSetBotDifficultyDvar();
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
            target = combatTrainingMaxPlayers;
            dbg("heartbeat totalCap=" + countTotalPlayersForCap()
                + " totalRaw=" + (isDefined(level.players) ? level.players.size : 0)
                + " humans=" + countHumans()
                + " bots=" + countBots()
                + " target=" + target
                + " diff=" + getSelectedBotDifficulty()
                + " dvar(bot_difficulty)=" + level.autobotDvarDifficulty
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

    expectedApplied = getSelectedBotDifficulty();
    expectedDvar = level.autobotDvarDifficulty;
    if (!isDefined(expectedDvar) || expectedDvar == "") expectedDvar = getBotDifficultyDvarTarget();
    startTime = 0;
    if (isDefined(level.time)) startTime = level.time;

    samples = 0;
    dvarFailures = 0;
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
        target = combatTrainingMaxPlayers;
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
                if (!isDefined(p.pers) || !isDefined(p.pers["autobot_diff_applied"]) || p.pers["autobot_diff_applied"] != expectedApplied)
                    badBotDiffSeen++;
            }
        }

        samples++;
        wait sanityTestSampleInterval;
    }

    dbg("SANITY end samples=" + samples
        + " expectedApplied=" + expectedApplied
        + " expectedDvar=" + expectedDvar
        + " dvarFailures=" + dvarFailures
        + " anyBotsSeen=" + anyBotsSeen
        + " badBotDiffSeen=" + badBotDiffSeen
        + " maxOvershoot=" + maxOvershoot
        + " spawnSuccessStreak=" + spawnSuccessStreak
        + " spawnFailStreak=" + spawnFailStreak);
}

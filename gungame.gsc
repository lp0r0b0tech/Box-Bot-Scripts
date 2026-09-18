#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes\_gamelogic;

ggWeaponPrefix = "";
ggWeaponSuffix = "";
ggFallbackSafeMode = true;
ggFallbackPrimaryWeapon = "iw5_m4_mp";
ggFallbackSecondaryWeapon = "iw5_44magnum_mp";
ggFallbackFinalTierWeapon = "iw5_44magnum_mp";

isSubStr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle)) return false;
    return issubstr(hay, needle);
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

isMultiplayerContext()
{
    if (isDefined(level.mapname))
    {
        mn = toLower(level.mapname);
        if (length(mn) >= 3)
        {
            if (getsubstr(mn, 0, 3) == "mp_") return true;
            if (getsubstr(mn, 0, 3) == "cp_" || getsubstr(mn, 0, 3) == "zm_" || getsubstr(mn, 0, 3) == "sp_") return false;
        }
    }

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (gt == "dm" || gt == "war" || gt == "dom" || gt == "conf" || gt == "sd" || gt == "ctf" || gt == "hp" || gt == "gun" || gt == "gungame" || gt == "gun_game" || gt == "gun-game") return true;
    if (isCombatTrainingIdentifier(gt)) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (isCombatTrainingIdentifier(pl)) return true;

    return false;
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

shouldRunGunGameHere()
{
    if (isDefined(level.forceGunGameInCombatTraining) && level.forceGunGameInCombatTraining) return true;

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (gt == "gun" || gt == "gungame" || gt == "gun_game" || gt == "gun-game") return true;
    if (isSubStr(gt, "gungame") || isSubStr(gt, "gun game") || isSubStr(gt, "gun_game") || isSubStr(gt, "gun-game")) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (pl == "gun" || pl == "gungame" || pl == "gun_game" || pl == "gun-game") return true;
    if (isSubStr(pl, "gungame") || isSubStr(pl, "gun game") || isSubStr(pl, "gun_game") || isSubStr(pl, "gun-game")) return true;

    if (!isMultiplayerContext()) return false;

    if (isDefined(level.mapname))
    {
        mn = toLower(level.mapname);
        if (isSubStr(mn, "exo survival") || isSubStr(mn, "exo zombies")) return false;
        if (isSubStr(mn, "cp_") || isSubStr(mn, "survival")) return false;
        if (isSubStr(mn, "zm_") || isSubStr(mn, "zombies")) return false;
    }

    if (isSubStr(gt, "survival") || isSubStr(gt, "zombie") || isSubStr(gt, "infect")) return false;

    if (isDefined(level.playlist))
    {
        if (isSubStr(pl, "survival") || isSubStr(pl, "zombie")) return false;
        if (isSubStr(pl, "exo")) return false;
        if (isSubStr(pl, "exo survival") || isSubStr(pl, "exo zombies")) return false;
    }

    return detectCombatTraining();
}

init()
{
    if (!shouldRunGunGameHere()) return;
    if (!isDefined(level.forceGunGameInCombatTraining))
        level.forceGunGameInCombatTraining = detectCombatTraining();
    initGunGameState();
}

initForced()
{
    initGunGameState();
}

initGunGameState()
{
    if (isDefined(level.gungameInitialized) && level.gungameInitialized) return;
    level.gungameInitialized = true;
    level.autobotsGunGameMode = true;

    level.gg_weapons = [];

    buildGunGameWeaponRotation();

    level.gungameSanityFailures = runGunGameSanityCheck();
    initializeExistingGunGamePlayers();
    level thread onPlayerConnect();
}

buildGunGameWeaponAlias(baseAlias)
{
    return ggWeaponPrefix + baseAlias + ggWeaponSuffix;
}

addGunGameWeaponAlias(baseAlias)
{
    if (!isDefined(baseAlias) || baseAlias == "") return;
    addGunGameWeapon(buildGunGameWeaponAlias(baseAlias));
}

buildGunGameWeaponRotation()
{
    if (ggFallbackSafeMode)
    {
        addGunGameWeapon(ggFallbackPrimaryWeapon);
        addGunGameWeapon(ggFallbackSecondaryWeapon);
        // Keep a known-safe weapon equipped on the last tier; melee/crush still ends the match there.
        addGunGameWeapon(ggFallbackFinalTierWeapon);
        return;
    }

    addGunGameWeaponAlias("bal27");
    addGunGameWeaponAlias("ak12");
    addGunGameWeaponAlias("arx160");
    addGunGameWeaponAlias("hbra3");
    addGunGameWeaponAlias("imr");
    addGunGameWeaponAlias("mk14");
    addGunGameWeaponAlias("ae4");
    addGunGameWeaponAlias("stg44");
    addGunGameWeaponAlias("ak47");
    addGunGameWeaponAlias("kf5");
    addGunGameWeaponAlias("mp11");
    addGunGameWeaponAlias("asm1");
    addGunGameWeaponAlias("sn6");
    addGunGameWeaponAlias("sac3");
    addGunGameWeaponAlias("amr9");
    addGunGameWeaponAlias("mp40");
    addGunGameWeaponAlias("sten");
    addGunGameWeaponAlias("lynx");
    addGunGameWeaponAlias("mors");
    addGunGameWeaponAlias("na45");
    addGunGameWeaponAlias("atlas20mm");
    addGunGameWeaponAlias("svo");
    addGunGameWeaponAlias("tac19");
    addGunGameWeaponAlias("s12");
    addGunGameWeaponAlias("bulldog");
    addGunGameWeaponAlias("blunderbuss");
    addGunGameWeaponAlias("cel3cauterizer");
    addGunGameWeaponAlias("em1");
    addGunGameWeaponAlias("pytaek");
    addGunGameWeaponAlias("xmg");
    addGunGameWeaponAlias("epm3");
    addGunGameWeaponAlias("ameli");
    addGunGameWeaponAlias("ohm");
    addGunGameWeaponAlias("atlas45");
    addGunGameWeaponAlias("rw1");
    addGunGameWeaponAlias("mp443grach");
    addGunGameWeaponAlias("pdw");
    addGunGameWeaponAlias("m1irons");
    addGunGameWeaponAlias("m1911");
    addGunGameWeaponAlias("stingerm7");
    addGunGameWeaponAlias("maaws");
    addGunGameWeaponAlias("mahem");
    addGunGameWeaponAlias("rpg7");
    addGunGameWeaponAlias("mdl");
    addGunGameWeaponAlias("crossbow");
    addGunGameWeaponAlias("repulsor");
    addGunGameWeaponAlias("m1garand");
    addGunGameWeaponAlias("leveraction");
    addGunGameWeaponAlias("m16");
    addGunGameWeaponAlias("combatknife");
}

addGunGameWeapon(weaponName)
{
    if (!isDefined(weaponName) || weaponName == "") return;
    level.gg_weapons[level.gg_weapons.size] = weaponName;
}

weaponMatchesTierWeapon(killWeapon, expectedWeapon)
{
    if (!isDefined(killWeapon) || !isDefined(expectedWeapon)) return false;

    killWeaponCompare = toLower(killWeapon + "");
    expectedWeaponCompare = toLower(expectedWeapon + "");

    if (killWeaponCompare == expectedWeaponCompare) return true;
    if (issubstr(killWeaponCompare, expectedWeaponCompare + "_")) return true;
    if (issubstr(killWeaponCompare, expectedWeaponCompare + "+")) return true;

    return false;
}

isGunGameParticipant(player)
{
    if (!isDefined(player)) return false;
    if (!isDefined(player.gg_level)) return false;
    if (!isDefined(player.pers) || !isDefined(player.pers["gg_initialized"])) return false;
    return player.pers["gg_initialized"];
}

initializeGunGamePlayer(player)
{
    if (!isDefined(player)) return;
    if (!isDefined(player.pers)) return;

    if (!isDefined(player.pers["gg_initialized"]) || !player.pers["gg_initialized"])
    {
        player.pers["gg_initialized"] = true;
        player.gg_level = 0;
    }

    if (!isDefined(player.pers["gg_watchers_started"]) || !player.pers["gg_watchers_started"])
    {
        player.pers["gg_watchers_started"] = true;
        player thread onPlayerSpawned();
        player thread watchKill();
    }

    if (isalive(player))
        player scheduleGunGameWeaponGrant();
}

initializeExistingGunGamePlayers()
{
    if (!isDefined(level.players)) return;

    foreach (player in level.players)
    {
        if (!isDefined(player)) continue;
        if (isDefined(player.pers))
            initializeGunGamePlayer(player);
        else
            player thread initializeGunGamePlayerWhenReady();
    }
}

onPlayerConnect()
{
    for (;;)
    {
        level waittill("connected", player);
        if (!isDefined(player)) continue;
        player thread initializeGunGamePlayerWhenReady();
    }
}

initializeGunGamePlayerWhenReady()
{
    level endon("game_ended");
    self endon("disconnect");
    timeoutAt = 10.0;
    totalWait = 30.0;

    for (;;)
    {
        if (isDefined(self.pers))
            break;
        if (totalWait <= 0.0)
            return;
        if (timeoutAt <= 0.0)
        {
            wait 1.0;
            timeoutAt = 10.0;
            totalWait = totalWait - 1.0;
            continue;
        }
        wait 0.05;
        timeoutAt = timeoutAt - 0.05;
        totalWait = totalWait - 0.05;
    }

    initializeGunGamePlayer(self);
}

onPlayerSpawned()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("spawned_player");
        self scheduleGunGameWeaponGrant();
    }
}

scheduleGunGameWeaponGrant()
{
    if (!isDefined(self.pers)) return;
    self.pers["gg_weapon_grant_requested"] = true;
    if (isDefined(self.pers["gg_weapon_grant_running"]) && self.pers["gg_weapon_grant_running"]) return;

    self.pers["gg_weapon_grant_running"] = true;
    self thread giveGunGameWeapon();
}

giveGunGameWeapon()
{
    self endon("disconnect");
    if (!isDefined(self.pers)) return;

    for (;;)
    {
        self.pers["gg_weapon_grant_requested"] = false;

        if (isalive(self) && isDefined(level.gg_weapons) && level.gg_weapons.size > 0)
        {
            if (!isDefined(self.gg_level)) self.gg_level = 0;
            if (self.gg_level < 0) self.gg_level = 0;
            if (self.gg_level >= level.gg_weapons.size) self.gg_level = level.gg_weapons.size - 1;

            currentWeapon = level.gg_weapons[self.gg_level];
            if (isDefined(currentWeapon) && currentWeapon != "")
            {
                self takeallweapons();
                self giveweapon(currentWeapon);
                self switchtoweapon(currentWeapon);
                self givemaxammo(currentWeapon);
            }
        }

        if (!isDefined(self.pers["gg_weapon_grant_requested"]) || !self.pers["gg_weapon_grant_requested"])
            break;
    }

    self.pers["gg_weapon_grant_running"] = false;
    if (isDefined(self.pers["gg_weapon_grant_requested"]) && self.pers["gg_weapon_grant_requested"])
        self scheduleGunGameWeaponGrant();
}

watchKill()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("killed_enemy", victim, weapon, meansOfDeath);
        if (!isGunGameParticipant(self)) continue;
        if (!areGunGameEnemies(self, victim)) continue;
        if (!isDefined(level.gg_weapons) || level.gg_weapons.size <= 0) continue;
        if (!isDefined(self.gg_level)) self.gg_level = 0;
        if (self.gg_level < 0) self.gg_level = 0;
        if (self.gg_level >= level.gg_weapons.size) self.gg_level = level.gg_weapons.size - 1;

        currentWeapon = level.gg_weapons[self.gg_level];
        finalTier = (self.gg_level >= (level.gg_weapons.size - 1));
        validTierKill = weaponMatchesTierWeapon(weapon, currentWeapon);
        validTierKill = shouldAwardFinalTierGunGameKill(validTierKill, finalTier, meansOfDeath);

        if (shouldDemoteGunGameVictim(validTierKill, finalTier, meansOfDeath, isGunGameParticipant(victim)))
            victim thread demotePlayer();

        if (validTierKill)
        {
            if (finalTier)
            {
                self iprintlnbold("^2Gun Game Winner!");
                winner = getGunGameEndGameWinnerToken(self);
                if (winner == "none")
                    return;
                maps\mp\gametypes\_gamelogic::endGame(winner, "scorelimit");
                return;
            }

            self.gg_level++;
            if (self.gg_level >= level.gg_weapons.size) self.gg_level = level.gg_weapons.size - 1;
            self scheduleGunGameWeaponGrant();
        }
    }
}

demotePlayer()
{
    self endon("disconnect");

    if (!isDefined(self.gg_level)) self.gg_level = 0;
    if (self.gg_level > 0)
    {
        self.gg_level--;
        self iprintlnbold("^1Humiliated! Demoted to previous tier.");
        if (isalive(self))
            self scheduleGunGameWeaponGrant();
    }
}

getGunGameWinnerToken(player)
{
    if (!isDefined(player)) return "none";

    teamToken = "";
    if (isDefined(player.pers) && isDefined(player.pers["team"])) teamToken = toLower(player.pers["team"] + "");
    else if (isDefined(player.sessionteam)) teamToken = toLower(player.sessionteam + "");
    else if (isDefined(player.team)) teamToken = toLower(player.team + "");

    if (teamToken == "team_allies") return "allies";
    if (teamToken == "team_axis") return "axis";
    if (teamToken == "allies" || teamToken == "axis") return teamToken;

    return "none";
}

areGunGameEnemies(attacker, victim)
{
    if (!isDefined(attacker) || !isDefined(victim)) return false;
    if (attacker == victim) return false;
    if (isGunGameFreeForAllMode()) return true;

    attackerTeam = getGunGameWinnerToken(attacker);
    victimTeam = getGunGameWinnerToken(victim);
    if (attackerTeam == "none" || victimTeam == "none") return false;
    return attackerTeam != victimTeam;
}

getGunGameEndGameWinner(player)
{
    return getGunGameEndGameWinnerToken(player);
}

getGunGameEndGameWinnerToken(player)
{
    return getGunGameEndGameWinnerTokenForMode(player, isGunGameFreeForAllMode());
}

getGunGameEndGameWinnerTokenForMode(player, freeForAllMode)
{
    winnerToken = getGunGameWinnerToken(player);
    if (winnerToken != "none") return winnerToken;
    if (freeForAllMode) return "allies";
    return "none";
}

shouldAwardFinalTierGunGameKill(validTierKill, finalTier, meansOfDeath)
{
    if (validTierKill) return true;
    if (!finalTier) return false;
    return meansOfDeath == "MOD_MELEE" || meansOfDeath == "MOD_CRUSH";
}

shouldDemoteGunGameVictim(validTierKill, finalTier, meansOfDeath, victimParticipant)
{
    if (!victimParticipant) return false;
    if (meansOfDeath != "MOD_MELEE" && meansOfDeath != "MOD_CRUSH") return false;
    return validTierKill && finalTier;
}

runGunGameSanityCheck()
{
    failures = 0;

    if (!shouldAwardFinalTierGunGameKill(false, true, "MOD_MELEE"))
        failures++;

    if (!shouldAwardFinalTierGunGameKill(false, true, "MOD_CRUSH"))
        failures++;

    if (!shouldDemoteGunGameVictim(true, true, "MOD_MELEE", true))
        failures++;

    if (shouldDemoteGunGameVictim(false, false, "MOD_MELEE", false))
        failures++;

    if (shouldDemoteGunGameVictim(false, false, "MOD_CRUSH", true))
        failures++;

    if (!shouldDemoteGunGameVictim(true, true, "MOD_CRUSH", true))
        failures++;

    testPlayer = [];
    testPlayer.pers = [];
    testPlayer.pers["team"] = "allies";
    if (getGunGameEndGameWinnerToken(testPlayer) != "allies")
        failures++;

    teammateA = [];
    teammateA.pers = [];
    teammateA.pers["team"] = "allies";
    teammateB = [];
    teammateB.pers = [];
    teammateB.pers["team"] = "team_allies";
    if (areGunGameEnemies(teammateA, teammateB))
        failures++;

    noTeamPlayer = [];
    noTeamPlayer.pers = [];
    if (getGunGameEndGameWinnerTokenForMode(noTeamPlayer, true) != "allies")
        failures++;

    if (getGunGameEndGameWinnerTokenForMode(noTeamPlayer, false) != "none")
        failures++;

    return failures;
}

isGunGameFreeForAllMode()
{
    if (isDefined(level.teambased))
        return !level.teambased;

    if (isDefined(level.teamBased))
        return !level.teamBased;

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (gt == "dm" || gt == "ffa" || gt == "gun" || gt == "gungame" || gt == "gun_game" || gt == "gun-game") return true;
    if (issubstr(gt, "free") || issubstr(gt, "ffa") || issubstr(gt, "gungame") || issubstr(gt, "gun game") || issubstr(gt, "gun_game") || issubstr(gt, "gun-game")) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (pl == "gun" || pl == "gungame" || pl == "gun_game" || pl == "gun-game") return true;
    if (issubstr(pl, "gungame") || issubstr(pl, "gun game") || issubstr(pl, "gun_game") || issubstr(pl, "gun-game")) return true;

    return false;
}

#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes\_gamelogic;

isGunGameMode()
{
    if (isDefined(level.forceGunGameInCombatTraining) && level.forceGunGameInCombatTraining) return true;
    if (isDefined(level.autobotsForceGunGameInCombatTraining) && level.autobotsForceGunGameInCombatTraining) return true;

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (gt == "gun" || gt == "gungame" || gt == "gun_game" || gt == "gun-game") return true;
    if (issubstr(gt, "gungame") || issubstr(gt, "gun game") || issubstr(gt, "gun_game") || issubstr(gt, "gun-game")) return true;

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);
    if (pl == "gun" || pl == "gungame" || pl == "gun_game" || pl == "gun-game") return true;
    if (issubstr(pl, "gungame") || issubstr(pl, "gun game") || issubstr(pl, "gun_game") || issubstr(pl, "gun-game")) return true;

    return false;
}

init()
{
    if (!isGunGameMode()) return;
    if (isDefined(level.gungameInitialized) && level.gungameInitialized) return;
    level.gungameInitialized = true;
    level.autobotsGunGameMode = true;

    level.gg_weapons = [];

    // Base rotation
    addGunGameWeapon("iw5_bal27_mp");          // Bal-27
    addGunGameWeapon("iw5_ak12_mp");           // AK12
    addGunGameWeapon("iw5_asm1_mp");           // ASM1
    addGunGameWeapon("iw5_kf5_mp");            // KF5
    addGunGameWeapon("iw5_sn6_mp");            // SN6
    addGunGameWeapon("iw5_hbra3_mp");          // HBRa3
    addGunGameWeapon("iw5_arx160_mp");         // ARX-160
    addGunGameWeapon("iw5_himar_mp");          // IMR
    addGunGameWeapon("iw5_sac3_mp");           // SAC3
    addGunGameWeapon("iw5_mp11_mp");           // MP11
    addGunGameWeapon("iw5_asaw_mp");           // Ameli
    addGunGameWeapon("iw5_lsat_mp");           // Pytaek
    addGunGameWeapon("iw5_mors_mp");           // MORS
    addGunGameWeapon("iw5_uts19_mp");          // Tac-19
    addGunGameWeapon("iw5_rw1_mp");            // RW1
    addGunGameWeapon("iw5_titan45_mp");        // Atlas 45
    addGunGameWeapon("iw5_mahem_mp");          // MAHEM
    addGunGameWeapon("iw5_exocrossbow_mp");    // Crossbow

    // DLC and loot-box-only weapons
    addGunGameWeapon("iw5_dlcgun1_mp");        // AE4
    addGunGameWeapon("iw5_dlcgun2_mp");        // Ohm
    addGunGameWeapon("iw5_dlcgun6_mp");        // STG44
    addGunGameWeapon("iw5_dlcgun7_mp");        // SVO
    addGunGameWeapon("iw5_dlcgun8loot0_mp");   // CEL-3 Cauterizer
    addGunGameWeapon("iw5_dlcgun7loot0_mp");   // AK-47
    addGunGameWeapon("iw5_dlcgun8_mp");        // M16
    addGunGameWeapon("iw5_dlcgun38_mp");       // Repulsor
    addGunGameWeapon("iw5_dlcgun13_mp");       // 1911
    addGunGameWeapon("iw5_dlcgun18_mp");       // MP40
    addGunGameWeapon("iw5_dlcgun23_mp");       // M1 Garand
    addGunGameWeapon("iw5_dlcgun28_mp");       // Sten
    addGunGameWeapon("iw5_dlcgun33_mp");       // Lever Action
    addGunGameWeapon("iw5_dlcgun3_mp");        // M1 Irons
    addGunGameWeapon("iw5_dlcgun4_mp");        // Blunderbuss

    addGunGameWeapon("iw5_combatknife_mp");    // Final weapon

    level.gungameSanityFailures = runGunGameSanityCheck();
    initializeExistingGunGamePlayers();
    level thread onPlayerConnect();
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

    if (!isDefined(player.pers)) player.pers = [];
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
        player giveGunGameWeapon();
}

initializeExistingGunGamePlayers()
{
    if (!isDefined(level.players)) return;

    foreach (player in level.players)
        initializeGunGamePlayer(player);
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
    self endon("disconnect");

    for (;;)
    {
        if (isDefined(self.pers) || isDefined(self.sessionteam) || isDefined(self.team) || isalive(self))
            break;
        wait 0.05;
    }

    initializeGunGamePlayer(self);
}

onPlayerSpawned()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("spawned_player");
        self thread giveGunGameWeapon();
    }
}

giveGunGameWeapon()
{
    self endon("disconnect");
    self endon("death");

    if (!isDefined(level.gg_weapons) || level.gg_weapons.size <= 0) return;

    if (!isDefined(self.gg_level)) self.gg_level = 0;
    if (self.gg_level < 0) self.gg_level = 0;
    if (self.gg_level >= level.gg_weapons.size) self.gg_level = level.gg_weapons.size - 1;

    currentWeapon = level.gg_weapons[self.gg_level];
    if (!isDefined(currentWeapon) || currentWeapon == "") return;

    self takeallweapons();
    self giveweapon(currentWeapon);
    self switchtoweapon(currentWeapon);
    self givemaxammo(currentWeapon);
}

watchKill()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("killed_enemy", victim, meansOfDeath, weapon);
        if (!isGunGameParticipant(self)) continue;
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
                winner = getGunGameEndGameWinner(self);
                if (!isDefined(winner))
                {
                    self iprintlnbold("^1Gun Game could not resolve a winning team token.");
                    return;
                }

                maps\mp\gametypes\_gamelogic::endGame(winner, "scorelimit");
                return;
            }

            self.gg_level++;
            if (self.gg_level >= level.gg_weapons.size) self.gg_level = level.gg_weapons.size - 1;
            self thread giveGunGameWeapon();
            self playlocalsound("mp_war_objective_taken");
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
        self playlocalsound("mp_war_objective_lost");

        if (isalive(self))
            self thread giveGunGameWeapon();
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

getGunGameEndGameWinner(player)
{
    return getGunGameEndGameWinnerForMode(player, isGunGameFreeForAllMode());
}

getGunGameEndGameWinnerForMode(player, freeForAllMode)
{
    winnerToken = getGunGameWinnerToken(player);
    if (winnerToken != "none") return winnerToken;
    if (freeForAllMode) return player;
    return undefined;
}

shouldAwardFinalTierGunGameKill(validTierKill, finalTier, meansOfDeath)
{
    if (validTierKill) return true;
    if (!finalTier) return false;
    return meansOfDeath == "MOD_MELEE";
}

shouldDemoteGunGameVictim(validTierKill, finalTier, meansOfDeath, victimParticipant)
{
    if (!victimParticipant) return false;
    if (meansOfDeath != "MOD_MELEE" && meansOfDeath != "MOD_CRUSH") return false;
    if (validTierKill && finalTier) return false;
    return true;
}

runGunGameSanityCheck()
{
    failures = 0;

    if (!shouldAwardFinalTierGunGameKill(false, true, "MOD_MELEE"))
        failures++;

    if (!shouldAwardFinalTierGunGameKill(false, true, "MOD_CRUSH"))
        failures++;

    if (shouldDemoteGunGameVictim(true, true, "MOD_MELEE", true))
        failures++;

    if (shouldDemoteGunGameVictim(false, false, "MOD_MELEE", false))
        failures++;

    if (!shouldDemoteGunGameVictim(false, false, "MOD_CRUSH", true))
        failures++;

    testPlayer = [];
    if (getGunGameEndGameWinnerForMode(testPlayer, true) != testPlayer)
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
    if (gt == "dm" || gt == "ffa") return true;
    if (issubstr(gt, "free") || issubstr(gt, "ffa")) return true;

    return false;
}

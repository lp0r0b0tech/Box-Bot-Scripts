#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

init()
{
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

    level thread onPlayerConnect();
}

addGunGameWeapon(weaponName)
{
    if (!isDefined(weaponName) || weaponName == "") return;
    level.gg_weapons[level.gg_weapons.size] = weaponName;
}

onPlayerConnect()
{
    for (;;)
    {
        level waittill("connected", player);
        if (!isDefined(player)) continue;

        player.gg_level = 0;
        player thread onPlayerSpawned();
        player thread watchKill();
    }
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

    self takeallweapons();

    if (!isDefined(self.gg_level)) self.gg_level = 0;
    if (self.gg_level < 0) self.gg_level = 0;
    if (self.gg_level >= level.gg_weapons.size) self.gg_level = level.gg_weapons.size - 1;

    currentWeapon = level.gg_weapons[self.gg_level];
    if (!isDefined(currentWeapon) || currentWeapon == "") return;

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

        if (meansOfDeath == "MOD_MELEE" || meansOfDeath == "MOD_CRUSH")
            victim thread demotePlayer();

        if (weapon == level.gg_weapons[self.gg_level] || meansOfDeath == "MOD_MELEE")
        {
            if (self.gg_level >= (level.gg_weapons.size - 1))
            {
                level thread maps\mp\gametypes\_gamelogic::endGame(self, "Gun Game Winner!");
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

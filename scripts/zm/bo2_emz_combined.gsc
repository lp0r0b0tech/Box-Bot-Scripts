// BO2-style Exo Zombies health and speed tuning with optional EMZ proximity diagnostics.
// Install in s1/scripts/zm. The proximity check logs only; it does not apply EMP.

main()
{
    init();
}

init()
{
    if (isDefined(level.bo2_emz_started))
        return;

    level.bo2_emz_started = true;
    level.bo2_health_cap = 30000;
    level.bo2_speed_cap = 0.50;
    level.bo2_goliath_min_health = 60000;
    level.bo2_oz_min_health_per_player = 100000;
    level.bo2_boss_health_multiplier = 4;
    level.bo2_last_round = -1;
    level.bo2_health = 150;
    level.emz_debug = true;
    level.emz_emp_range = 128;
    level.emz_tick = 0.25;
    level.emz_log_interval = 1.0;
    level.emz_last_log_time = -1000;

    level thread bo2_emz_wait_for_zombies();
}

bo2_emz_wait_for_zombies()
{
    level endon("game_ended");

    for (attempt = 0; attempt < 120; attempt++)
    {
        if (emz_should_run_here())
        {
            emz_log("init: enabled");
            level thread bo2_round_monitor();
            level thread bo2_oz_stage1_monitor();
            return;
        }

        wait 0.25;
    }

    emz_log("init: disabled (non-zombie context)");
}

bo2_round_monitor()
{
    level endon("game_ended");

    for (;;)
    {
        cap = 30000;
        if (getDvar("scr_bo2_health_cap") != "")
            cap = getDvarInt("scr_bo2_health_cap");
        if (cap < 1)
            cap = 1;
        level.bo2_health_cap = cap;

        speed = 0.50;
        if (getDvar("scr_bo2_speed_cap") != "")
            speed = getDvarFloat("scr_bo2_speed_cap");
        if (speed <= 0)
            speed = 0.01;
        if (speed > 1)
            speed = 1;
        level.bo2_speed_cap = speed;

        roundValue = undefined;
        if (isDefined(level.wavecounter))
            roundValue = level.wavecounter;
        else if (isDefined(level.round_number))
            roundValue = level.round_number;
        else if (isDefined(level.round))
            roundValue = level.round;
        else if (isDefined(level.roundNumber))
            roundValue = level.roundNumber;
        else if (isDefined(level.currentroundnumber))
            roundValue = level.currentroundnumber;

        if (isDefined(roundValue))
        {
            health = bo2_health_for_round(roundValue);
            level.bo2_last_round = roundValue;
            level.bo2_health = health;

            zombies = bo2_get_zombies();
            players = [];
            if (level.emz_debug && level.emz_emp_range > 0)
                players = getplayers();

            foreach (zombie in zombies)
            {
                if (!isDefined(zombie) || !isAlive(zombie))
                    continue;

                if (bo2_is_boss(zombie))
                {
                    bo2_apply_boss_health(zombie);
                    continue;
                }

                bo2_apply_health(zombie, health);
                bo2_apply_speed_cap(zombie);
                emz_check_players(zombie, players);
            }
        }

        wait 0.25;
    }
}

bo2_health_for_round(round_number)
{
    health = 150;
    if (health >= level.bo2_health_cap)
        return level.bo2_health_cap;

    for (round = 2; round <= round_number; round++)
    {
        if (round <= 9)
            health += 100;
        else
            health += int(health * 0.10);

        if (health >= level.bo2_health_cap)
            return level.bo2_health_cap;
    }

    return health;
}

bo2_get_zombies()
{
    zombies = [];

    if (!isDefined(level.agentarray) || !isDefined(level.enemyteam))
        return zombies;

    foreach (agent in level.agentarray)
    {
        if (!isDefined(agent) || !isAlive(agent) || !isDefined(agent.team))
            continue;

        if (isDefined(agent.isactive) && !agent.isactive)
            continue;

        if (!isDefined(agent.agent_type) || !issubstr(toLower(agent.agent_type), "zombie"))
            continue;

        if (agent.team == level.enemyteam)
            zombies[zombies.size] = agent;
    }

    return zombies;
}

bo2_is_boss(zombie)
{
    if (isDefined(zombie.is_boss) && zombie.is_boss)
        return true;
    if (isDefined(zombie.boss) && zombie.boss)
        return true;
    if (isDefined(zombie.entity_type) && zombie.entity_type == "boss")
        return true;
    if (isDefined(zombie.agent_type))
    {
        agentType = toLower(zombie.agent_type);
        if (issubstr(agentType, "boss") || issubstr(agentType, "goliath"))
            return true;
    }
    if (isDefined(zombie.classname))
    {
        cname = toLower(zombie.classname);
        if (cname == "boss" || cname == "boss_zombie" || cname == "special_zombie")
            return true;
    }

    return false;
}

bo2_apply_health(zombie, health)
{
    if (isDefined(zombie.bo2_applied_health) && zombie.bo2_applied_health == health)
        return;

    if (!isDefined(zombie.maxhealth) || !isDefined(zombie.health))
        return;

    oldMax = zombie.maxhealth;
    oldHealth = zombie.health;
    zombie.maxhealth = health;

    if (oldMax > 0)
        zombie.health = int(oldHealth * health / oldMax);
    else
        zombie.health = health;

    if (zombie.health > health)
        zombie.health = health;
    if (zombie.health < 1)
        zombie.health = 1;

    zombie.bo2_applied_health = health;
}

bo2_apply_boss_health(zombie)
{
    if (!isDefined(zombie.agent_type) || !isDefined(zombie.maxhealth) ||
        !isDefined(zombie.health) || isDefined(zombie.bo2_boss_health_applied))
        return;

    agentType = toLower(zombie.agent_type);
    if (agentType == "zombie_boss_oz_stage2")
    {
        // Native postspawn multiplies health by player count and sets up phase thresholds.
        if (!isDefined(zombie.postspawnfinished) || !zombie.postspawnfinished)
            return;

        playerCount = 1;
        players = getplayers();
        if (isDefined(players) && players.size > 0)
            playerCount = players.size;

        minimum = level.bo2_oz_min_health_per_player * playerCount;
    }
    else if (issubstr(agentType, "goliath"))
    {
        // Enhanced Goliaths reset native health shortly after spawning.
        if (!isDefined(zombie.bo2_boss_first_seen_time))
        {
            zombie.bo2_boss_first_seen_time = level.time;
            return;
        }
        if (level.time - zombie.bo2_boss_first_seen_time < 500)
            return;

        minimum = level.bo2_goliath_min_health;
    }
    else
        return;

    oldMax = zombie.maxhealth;
    if (oldMax <= 0)
        return;

    target = oldMax * level.bo2_boss_health_multiplier;
    if (target < minimum)
        target = minimum;

    zombie.maxhealth = target;
    if (isDefined(zombie.agenthealth))
        zombie.agenthealth = target;
    zombie.health = int(zombie.health * target / oldMax);
    if (zombie.health > target)
        zombie.health = target;
    if (zombie.health < 1)
        zombie.health = 1;

    zombie.bo2_boss_health_applied = true;
    if (agentType == "zombie_boss_oz_stage2")
        setomnvar("ui_zm_fight_health_max", target);
}

bo2_oz_stage1_monitor()
{
    level endon("game_ended");

    for (;;)
    {
        bo2_limit_oz_stage1_damage();
        wait 0.05;
    }
}

bo2_limit_oz_stage1_damage()
{
    if (!isDefined(level.bossozstage1))
        return;

    oz = level.bossozstage1;
    if (!isDefined(oz.damagecallback))
        return;

    if (oz.damagecallback == ::bo2_oz_stage1_damage)
        return;

    // Keep the game's room transitions and exposed/armored state; wrap only
    // the damage value passed to its own callback.
    oz.bo2_original_damagecallback = oz.damagecallback;
    oz.damagecallback = ::bo2_oz_stage1_damage;
}

bo2_oz_stage1_damage(
    inflictor, attacker, damage, damageFlags, meansOfDeath, weapon,
    point, direction, hitLocation, timeOffset, modelIndex, partName
)
{
    if (!isDefined(self.bo2_original_damagecallback))
        return;

    players = getplayers();
    playerCount = 1;
    if (isDefined(players) && players.size > 0)
        playerCount = players.size;

    // Oz's native room threshold is 4900 per player. Bound each ordinary
    // weapon hit to about a quarter of it, accounting for native Mk scaling.
    maxDamage = int(4900 * playerCount / 4);
    if (isDefined(attacker) && isPlayer(attacker) && isDefined(weapon))
    {
        weaponName = getweaponbasename(weapon);
        if (isDefined(weaponName) && isDefined(level.damageweapontoweapon) &&
            isDefined(level.damageweapontoweapon[weaponName]))
            weaponName = level.damageweapontoweapon[weaponName];

        if (isDefined(weaponName) && isDefined(attacker.weaponstate) &&
            isDefined(attacker.weaponstate[weaponName]) &&
            isDefined(attacker.weaponstate[weaponName]["level"]))
        {
            increase = 0.2;
            if (isDefined(attacker.weaponstate[weaponName]["weapon_level_increase"]))
                increase = attacker.weaponstate[weaponName]["weapon_level_increase"];

            multiplier = 1 + increase * (attacker.weaponstate[weaponName]["level"] - 1);
            if (multiplier > 1)
                maxDamage = int(maxDamage / multiplier);
        }
    }

    if (maxDamage < 1)
        maxDamage = 1;
    if (damage > maxDamage)
        damage = maxDamage;

    self [[ self.bo2_original_damagecallback ]](
        inflictor, attacker, damage, damageFlags, meansOfDeath, weapon,
        point, direction, hitLocation, timeOffset, modelIndex, partName
    );
}

bo2_apply_speed_cap(zombie)
{
    if (!isDefined(zombie.buffs))
        zombie.buffs = [];

    if (!isDefined(zombie.buffs["bo2_speed_cap"]))
        zombie.buffs["bo2_speed_cap"] = spawnstruct();

    // Native updatebuffs() subtracts from every buff's lifespan.
    zombie.buffs["bo2_speed_cap"].lifespan = 1.0;

    if (!isDefined(zombie.buffs["bo2_speed_cap"].speedmultiplier) ||
        zombie.buffs["bo2_speed_cap"].speedmultiplier != level.bo2_speed_cap)
    {
        zombie.buffs["bo2_speed_cap"].speedmultiplier = level.bo2_speed_cap;
        zombie notify("speed_debuffs_changed");
    }
}

emz_should_run_here()
{
    if (isDefined(level.zombiemode) && level.zombiemode)
        return true;
    if (isDefined(level.zombieMap) && level.zombieMap)
        return true;

    gt = toLower(getDvar("g_gametype"));
    mn = toLower(getDvar("mapname"));
    if (isDefined(level.gametype))
        gt = toLower(level.gametype);
    if (isDefined(level.mapname))
        mn = toLower(level.mapname);

    if (issubstr(gt, "zombie") || gt == "zm")
        return true;
    if (issubstr(mn, "mp_zombie_") || issubstr(mn, "zombie_") || issubstr(mn, "zm_"))
        return true;

    return false;
}

emz_log(msg)
{
    if (!level.emz_debug)
        return;

    if (isDefined(level.time))
    {
        if (level.time - level.emz_last_log_time < int(level.emz_log_interval * 1000))
            return;
        level.emz_last_log_time = level.time;
    }

    println("[EMZ] " + msg);
}

emz_check_players(zombie, players)
{
    if (!level.emz_debug || level.emz_emp_range <= 0)
        return;

    if (!isDefined(players))
        return;

    foreach (player in players)
    {
        if (isDefined(player) && isDefined(player.origin) && isDefined(zombie.origin))
        {
            dist = distance(zombie.origin, player.origin);
            if (dist <= level.emz_emp_range)
                emz_log("player within EMP range: " + dist);
        }
    }
}

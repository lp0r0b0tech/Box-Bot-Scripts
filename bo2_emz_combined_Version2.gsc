// ============================================================
// Combined Script:
// - BO2-style health scaling + 30,000 cap + boss exclusion + speed cap
// - EMZ Safe Coexist debug/detection system
// ============================================================

init()
{
    // ---------------- BO2 scaling settings ----------------
    level.bo2_health_cap = 30000;
    level.bo2_speed_cap = 0.75; // 1.0 = normal speed, 0.75 = 75%

    level.bo2_last_round = -1;
    level.bo2_health = 150;

    // ---------------- EMZ settings ----------------
    level.emz_debug = true;
    level.emz_emp_range = 0.1;
    level.emz_tick = 0.25;
    level.emz_log_interval = 1.0;

    if (!isDefined(level.emz_last_log_time))
        level.emz_last_log_time = 0;

    if (!emz_should_run_here())
    {
        emz_log("init: disabled (non-zombie context)");
        return;
    }

    emz_log("init: enabled");

    // Start BO2 monitor only in valid zombie contexts.
    level thread bo2_round_monitor();
}

// ============================================================
// BO2-style health scaling
// ============================================================

bo2_round_monitor()
{
    level endon("game_ended");

    for (;;)
    {
        roundValue = undefined;

        if (isDefined(level.round_number))
            roundValue = level.round_number;
        else if (isDefined(level.round))
            roundValue = level.round;
        else if (isDefined(level.roundNumber))
            roundValue = level.roundNumber;

        if (!isDefined(roundValue))
        {
            wait 0.05;
            continue;
        }

        if (roundValue != level.bo2_last_round)
        {
            level.bo2_last_round = roundValue;
            level.bo2_health = bo2_health_for_round(roundValue);

            bo2_apply_health_to_zombies(level.bo2_health);
        }
        else
        {
            bo2_apply_health_to_new_zombies(level.bo2_health);
        }

        wait 0.05;
    }
}

bo2_health_for_round(round_number)
{
    if (round_number < 1)
        round_number = 1;

    health = 150;

    for (round = 2; round <= round_number; round++)
    {
        if (round <= 9)
        {
            health = health + 100;
        }
        else
        {
            health = health + int(health * 0.10);
        }

        if (health >= level.bo2_health_cap)
            return level.bo2_health_cap;
    }

    return health;
}

bo2_get_zombies()
{
    if (isDefined(level.zombie_team))
    {
        zombies = GetAITeamArray(level.zombie_team);
        if (isDefined(zombies) && zombies.size > 0)
            return zombies;
    }

    if (isDefined(level.zombie_team_name))
    {
        zombies = GetAITeamArray(level.zombie_team_name);
        if (isDefined(zombies) && zombies.size > 0)
            return zombies;
    }

    zombies = GetAIArray();
    if (isDefined(zombies) && zombies.size > 0)
        return zombies;

    return [];
}

bo2_is_boss(zombie)
{
    if (!isDefined(zombie))
        return true;

    if (isDefined(zombie.is_boss) && zombie.is_boss)
        return true;

    if (isDefined(zombie.boss) && zombie.boss)
        return true;

    if (isDefined(zombie.entity_type) && zombie.entity_type == "boss")
        return true;

    if (isDefined(zombie.classname))
    {
        if (zombie.classname == "boss")
            return true;

        if (zombie.classname == "boss_zombie")
            return true;

        if (zombie.classname == "special_zombie")
            return true;
    }

    return false;
}

bo2_apply_speed_cap(zombie)
{
    if (!isDefined(zombie) || !isAlive(zombie))
        return;

    if (bo2_is_boss(zombie))
        return;

    zombie SetMoveSpeedScale(level.bo2_speed_cap);
}

bo2_apply_health_to_zombies(health)
{
    zombies = bo2_get_zombies();

    foreach (zombie in zombies)
    {
        if (!isDefined(zombie) || !isAlive(zombie))
            continue;

        if (bo2_is_boss(zombie))
            continue;

        bo2_apply_speed_cap(zombie);

        if (!isDefined(zombie.maxhealth))
        {
            zombie.maxhealth = health;
            zombie.health = health;
            continue;
        }

        if (zombie.maxhealth == health)
            continue;

        old_max_health = zombie.maxhealth;
        old_health = zombie.health;

        zombie.maxhealth = health;

        if (old_max_health > 0)
            zombie.health = int(old_health * health / old_max_health);

        if (zombie.health > zombie.maxhealth)
            zombie.health = zombie.maxhealth;

        if (zombie.health < 1)
            zombie.health = 1;
    }
}

bo2_apply_health_to_new_zombies(health)
{
    zombies = bo2_get_zombies();

    foreach (zombie in zombies)
    {
        if (!isDefined(zombie) || !isAlive(zombie))
            continue;

        if (bo2_is_boss(zombie))
            continue;

        bo2_apply_speed_cap(zombie);

        if (!isDefined(zombie.maxhealth))
        {
            zombie.maxhealth = health;
            zombie.health = health;
        }
    }
}

// ============================================================
// EMZ Safe Coexist Script
// ============================================================

emz_should_run_here()
{
    gt = "";
    if (isDefined(level.gametype))
        gt = toLower(level.gametype);

    mn = "";
    if (isDefined(level.mapname))
        mn = toLower(level.mapname);

    pl = "";
    if (isDefined(level.playlist))
        pl = toLower(level.playlist);

    if (emz_substr(gt, "zombie") || emz_substr(gt, "infect")) return true;
    if (emz_substr(mn, "zm_") || emz_substr(mn, "zombie")) return true;
    if (emz_substr(pl, "zombie") || emz_substr(pl, "exo")) return true;

    return false;
}

emz_substr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle)) return false;
    return issubstr(hay, needle);
}

emz_log(msg)
{
    if (!isDefined(level.emz_debug) || !level.emz_debug) return;
    if (!isDefined(msg)) msg = "undefined";

    now = 0;
    if (isDefined(level.time)) now = level.time;

    last = 0;
    if (isDefined(level.emz_last_log_time)) last = level.emz_last_log_time;

    minGapMs = int(level.emz_log_interval * 1000.0);
    if (now - last < minGapMs) return;

    level.emz_last_log_time = now;
    println("[EMZ] " + msg);
}

zombie_spawn_init(animname_set)
{
    if (!emz_should_run_here()) return;
    if (!isDefined(self)) return;

    emz_log("zombie_spawn_init called");
    self thread emz_test_loop();
}

emz_test_loop()
{
    if (!isDefined(self)) return;

    self endon("death");
    self endon("disconnect");
    level endon("game_ended");

    for (;;)
    {
        if (!emz_should_run_here())
            return;

        if (!isDefined(level.emz_emp_range) || level.emz_emp_range <= 0)
            level.emz_emp_range = 1.5;

        if (!isDefined(level.emz_tick) || level.emz_tick < 0.05)
            level.emz_tick = 0.25;

        players = getplayers();
        if (!isDefined(players))
        {
            emz_log("getplayers undefined");
            wait(level.emz_tick);
            continue;
        }

        if (!isDefined(self.origin))
        {
            wait(level.emz_tick);
            continue;
        }

        for (i = 0; i < players.size; i++)
        {
            player = players[i];
            if (!isDefined(player)) continue;
            if (!isDefined(player.origin)) continue;

            dist = distance(self.origin, player.origin);

            if (dist <= level.emz_emp_range)
                emz_log("player within EMP range: " + dist);
        }

        wait(level.emz_tick);
    }
}

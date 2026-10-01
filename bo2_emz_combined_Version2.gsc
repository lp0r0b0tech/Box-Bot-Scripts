// ============================================================
// Combined Script:
// - BO2-style health scaling + 30,000 cap + boss exclusion + speed cap
// - EMZ Safe Coexist debug/detection system
// ============================================================

main()
{
    init();
}

init()
{
    // ---------------- BO2 scaling settings ----------------
    level.bo2_health_cap = 30000;
    level.bo2_speed_cap = 0.75; // 1.0 = normal speed, 0.75 = 75%

    // Allow dvar overrides if set by user or config
    if (getDvar("scr_bo2_speed_cap") != "")
        level.bo2_speed_cap = getDvarFloat("scr_bo2_speed_cap");

    if (getDvar("scr_bo2_health_cap") != "")
        level.bo2_health_cap = getDvarInt("scr_bo2_health_cap");

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
        // Support runtime dvar adjustments
        if (getDvar("scr_bo2_speed_cap") != "")
            level.bo2_speed_cap = getDvarFloat("scr_bo2_speed_cap");

        if (getDvar("scr_bo2_health_cap") != "")
            level.bo2_health_cap = getDvarInt("scr_bo2_health_cap");

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
    // 1. Check level.agentarray (Advanced Warfare / S1x Exo Zombies uses agents)
    if (isDefined(level.agentarray) && level.agentarray.size > 0)
    {
        zombies = [];
        foreach (agent in level.agentarray)
        {
            if (!isDefined(agent) || !isAlive(agent))
                continue;

            // Exclude players and bots
            if (isDefined(agent.agent_type) && agent.agent_type == "player")
                continue;

            // In Exo Zombies, enemy zombies are on axis / level.enemyteam
            if (isDefined(agent.team))
            {
                if (agent.team == "allies")
                    continue;

                if (isDefined(level.enemyteam) && agent.team != level.enemyteam)
                    continue;
            }

            zombies[zombies.size] = agent;
        }

        if (zombies.size > 0)
            return zombies;
    }

    // 2. Legacy / Treyarch actor arrays
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

    if (isDefined(zombie.agent_type))
    {
        agentType = toLower(zombie.agent_type);
        if (issubstr(agentType, "boss") || issubstr(agentType, "oz"))
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

bo2_apply_speed_cap(zombie)
{
    if (!isDefined(zombie) || !isAlive(zombie))
        return;

    if (bo2_is_boss(zombie))
        return;

    if (!isDefined(level.bo2_speed_cap))
        return;

    // 1. S1 Exo Zombies native buff system
    // Maps\mp\zombies\_zombies.gsc calculates moveratescale, nonmoveratescale,
    // and traverseratescale by multiplying by getbuffspeedmultiplier(), which checks
    // buffs[name].speedmultiplier and listens for "speed_debuffs_changed".
    if (!isDefined(zombie.buffs))
        zombie.buffs = [];

    needsNotify = false;
    if (!isDefined(zombie.buffs["bo2_speed_cap"]))
    {
        buff = spawnstruct();
        buff.speedmultiplier = level.bo2_speed_cap;
        zombie.buffs["bo2_speed_cap"] = buff;
        needsNotify = true;
    }
    else if (!isDefined(zombie.buffs["bo2_speed_cap"].speedmultiplier) || zombie.buffs["bo2_speed_cap"].speedmultiplier != level.bo2_speed_cap)
    {
        zombie.buffs["bo2_speed_cap"].speedmultiplier = level.bo2_speed_cap;
        needsNotify = true;
    }

    if (needsNotify)
        zombie notify("speed_debuffs_changed");

    // 2. Direct rate scale clamping to prevent accelerating beyond cap
    if (isDefined(zombie.moveratescale) && zombie.moveratescale > level.bo2_speed_cap)
        zombie.moveratescale = level.bo2_speed_cap;

    if (isDefined(zombie.nonmoveratescale) && zombie.nonmoveratescale > level.bo2_speed_cap)
        zombie.nonmoveratescale = level.bo2_speed_cap;

    if (isDefined(zombie.traverseratescale) && zombie.traverseratescale > level.bo2_speed_cap)
        zombie.traverseratescale = level.bo2_speed_cap;

    if (isDefined(zombie.generalspeedratescale) && zombie.generalspeedratescale > level.bo2_speed_cap)
        zombie.generalspeedratescale = level.bo2_speed_cap;

    zombie.movespeedscaler = level.bo2_speed_cap;

    // 3. Movemode clamping: if speed cap is slow, prevent higher sprint/run animations
    if (level.bo2_speed_cap <= 0.4)
    {
        if (isDefined(zombie.movemode) && zombie.movemode != "walk")
            zombie.movemode = "walk";
    }
    else if (level.bo2_speed_cap <= 0.75)
    {
        if (isDefined(zombie.movemode) && zombie.movemode == "sprint")
            zombie.movemode = "run";
    }

    // 4. Legacy CoD / BO2 zombie move speed compatibility
    if (isDefined(zombie.zombie_move_speed))
    {
        if (level.bo2_speed_cap <= 0.4)
            zombie.zombie_move_speed = "walk";
        else if (level.bo2_speed_cap <= 0.75 && zombie.zombie_move_speed == "super_sprint")
            zombie.zombie_move_speed = "sprint";
    }

    // 5. Fallback engine speed scale
    zombie SetMoveSpeedScale(level.bo2_speed_cap);

    // 6. Ensure per-zombie watcher thread is running to maintain speed cap
    if (!isDefined(zombie.bo2_speed_watcher_running))
    {
        zombie.bo2_speed_watcher_running = true;
        zombie thread bo2_zombie_speed_watcher();
    }
}

bo2_zombie_speed_watcher()
{
    self endon("death");
    level endon("game_ended");

    for (;;)
    {
        wait 0.25;

        if (!isDefined(self) || !isAlive(self))
            return;

        if (bo2_is_boss(self))
            return;

        if (!isDefined(level.bo2_speed_cap))
            continue;

        // Keep buff speedmultiplier updated
        if (isDefined(self.buffs) && isDefined(self.buffs["bo2_speed_cap"]))
        {
            if (self.buffs["bo2_speed_cap"].speedmultiplier != level.bo2_speed_cap)
            {
                self.buffs["bo2_speed_cap"].speedmultiplier = level.bo2_speed_cap;
                self notify("speed_debuffs_changed");
            }
        }
        else
        {
            bo2_apply_speed_cap(self);
        }

        // Clamp scales if native logic updated them
        if (isDefined(self.moveratescale) && self.moveratescale > level.bo2_speed_cap)
            self.moveratescale = level.bo2_speed_cap;

        if (isDefined(self.nonmoveratescale) && self.nonmoveratescale > level.bo2_speed_cap)
            self.nonmoveratescale = level.bo2_speed_cap;

        if (isDefined(self.traverseratescale) && self.traverseratescale > level.bo2_speed_cap)
            self.traverseratescale = level.bo2_speed_cap;

        if (level.bo2_speed_cap <= 0.4)
        {
            if (isDefined(self.movemode) && self.movemode != "walk")
                self.movemode = "walk";
        }
        else if (level.bo2_speed_cap <= 0.75)
        {
            if (isDefined(self.movemode) && self.movemode == "sprint")
                self.movemode = "run";
        }
    }
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

        if (!isDefined(zombie.maxhealth) || !isDefined(zombie.bo2_health_round))
        {
            zombie.maxhealth = health;
            zombie.health = health;
            zombie.bo2_health_round = level.bo2_last_round;
            continue;
        }

        if (zombie.maxhealth == health && zombie.bo2_health_round == level.bo2_last_round)
            continue;

        old_max_health = zombie.maxhealth;
        old_health = zombie.health;

        zombie.maxhealth = health;

        if (old_max_health > 0)
            zombie.health = int(old_health * health / old_max_health);
        else
            zombie.health = health;

        if (zombie.health > zombie.maxhealth)
            zombie.health = zombie.maxhealth;

        if (zombie.health < 1)
            zombie.health = 1;

        zombie.bo2_health_round = level.bo2_last_round;
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

        if (!isDefined(zombie.bo2_health_round) || zombie.bo2_health_round != level.bo2_last_round)
        {
            zombie.maxhealth = health;
            zombie.health = health;
            zombie.bo2_health_round = level.bo2_last_round;
        }
    }
}

// ============================================================
// EMZ Safe Coexist Script
// ============================================================

emz_should_run_here()
{
    if (isDefined(level.zombiemode) && level.zombiemode)
        return true;

    if (isDefined(level.zombieMap) && level.zombieMap)
        return true;

    gt = "";
    if (isDefined(level.gametype))
        gt = toLower(level.gametype);
    else if (getDvar("g_gametype") != "")
        gt = toLower(getDvar("g_gametype"));

    mn = "";
    if (isDefined(level.mapname))
        mn = toLower(level.mapname);
    else if (getDvar("mapname") != "")
        mn = toLower(getDvar("mapname"));

    pl = "";
    if (isDefined(level.playlist))
        pl = toLower(level.playlist);
    else if (getDvar("playlist") != "")
        pl = toLower(getDvar("playlist"));

    if (emz_substr(gt, "zombie") || emz_substr(gt, "infect") || emz_substr(gt, "zm") || emz_substr(gt, "horde")) return true;
    if (emz_substr(mn, "zm_") || emz_substr(mn, "zombie") || emz_substr(mn, "mp_zombie_")) return true;
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
    bo2_apply_speed_cap(self);
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

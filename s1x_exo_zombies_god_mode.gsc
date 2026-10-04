// ============================================================
// S1x Exo Zombies - Toggle God Mode
// Hold ADS (aim) and press Melee to toggle god mode on/off.
// God mode persists across respawns until toggled off.
// Only applies to human players, never bots.
// ============================================================

init()
{
    level thread god_on_player_connect();

    // Cover players already connected when the script loads.
    players = level.players;

    if (isDefined(players))
    {
        foreach (player in players)
        {
            player thread god_player_setup();
        }
    }
}

god_on_player_connect()
{
    level endon("game_ended");

    for (;;)
    {
        level waittill("connected", player);

        if (!isDefined(player))
            continue;

        player thread god_player_setup();
    }
}

god_player_setup()
{
    self endon("disconnect");
    level endon("game_ended");

    if (self god_is_bot())
        return;

    if (isDefined(self.god_mode_threads_started))
        return;

    self.god_mode_threads_started = true;
    self.god_mode_enabled = false;

    self thread god_toggle_watcher();
    self thread god_respawn_watcher();
}

god_toggle_watcher()
{
    self endon("disconnect");
    level endon("game_ended");

    for (;;)
    {
        if (isAlive(self) &&
            self adsButtonPressed() &&
            self meleeButtonPressed())
        {
            self god_toggle();

            // Debounce: wait for melee release so one press = one toggle.
            while (self meleeButtonPressed())
                wait 0.05;
        }

        wait 0.05;
    }
}

god_toggle()
{
    if (!isDefined(self.god_mode_enabled) || !self.god_mode_enabled)
    {
        self.god_mode_enabled = true;
        self god_apply();
        self iPrintLnBold("^2God Mode: ON");
    }
    else
    {
        self.god_mode_enabled = false;
        self god_remove();
        self iPrintLnBold("^1God Mode: OFF");
    }
}

god_respawn_watcher()
{
    self endon("disconnect");
    level endon("game_ended");

    for (;;)
    {
        self waittill("spawned_player");

        if (isDefined(self.god_mode_enabled) && self.god_mode_enabled)
        {
            self god_apply();
            self iPrintLn("^2God Mode still ON");
        }
    }
}

god_apply()
{
    if (!isAlive(self))
        return;

    self enableInvulnerability();
}

god_remove()
{
    if (!isAlive(self))
        return;

    self disableInvulnerability();
}

god_is_bot()
{
    if (isDefined(self.pers) &&
        isDefined(self.pers["isBot"]) &&
        self.pers["isBot"])
    {
        return true;
    }

    guid = self getGuid();

    if (isDefined(guid) && isSubStr(guid, "bot"))
        return true;

    return false;
}

/*
    S1x Combat Training Gun Game.

    Install in s1/scripts/mp alongside autobots_combat_training.gsc.
    Use Free-for-All (dm) or Team Deathmatch (war), not native gun mode.
    Remove older copies of this script before loading it.

    Enemy kills advance one stage (100 points). Melee also sets the
    victim back one stage. At the last stage only that weapon can win.
    Team scores show the team's highest stage, not the sum of kills.
    The normal time limit still applies.

    Weapon names are checked against the loaded MP roster. Missing
    weapons are logged and skipped; the score limit uses the usable list.
    Other scripts must not replace these callbacks or force loadouts.
*/

#define GG_SCORE_PER_KILL 100
#define GG_EQUIP_DELAY 0.5
#define GG_WAIT_INTERVAL 0.05
#define GG_WAIT_ATTEMPTS 600

main()
{
    init();
}

init()
{
    if ( isdefined( level.gungame_started ) )
        return;

    gametype = getdvar( "g_gametype" );
    if ( gametype != "dm" && gametype != "war" )
        return;

    level.gungame_started = 1;
    level thread gungame_setup();
}

gungame_setup()
{
    level endon( "game_ended" );

    attempts = 0;
    while ( !gungame_setup_ready() && attempts < GG_WAIT_ATTEMPTS )
    {
        wait GG_WAIT_INTERVAL;
        attempts++;
    }

    if ( !gungame_setup_ready() )
    {
        println( "GunGame: native MP setup timed out; mode not installed." );
        return;
    }

    level.gungame_weapons = [];
    gungame_add_weapon( "iw5_dlcgun13_mp" );
    gungame_add_weapon( "iw5_dlcgun1_mp" );
    gungame_add_weapon( "iw5_dlcgun7loot0_mp" );
    gungame_add_weapon( "iw5_ak12_mp" );
    gungame_add_weapon( "iw5_hmr9_mp" );
    gungame_add_weapon( "iw5_arx160_mp" );
    gungame_add_weapon( "iw5_asaw_mp" );
    gungame_add_weapon( "iw5_titan45_mp" );
    gungame_add_weapon( "iw5_dlcgun4_mp" );
    gungame_add_weapon( "iw5_pbw_mp" );
    gungame_add_weapon( "iw5_vbr_mp" );
    gungame_add_weapon( "iw5_uts19_mp" );
    gungame_add_weapon( "iw5_maul_mp" );
    gungame_add_weapon( "iw5_dlcgun8loot0_mp" );
    gungame_add_weapon( "iw5_combatknife_mp" );
    gungame_add_weapon( "iw5_exocrossbow_mp" );
    gungame_add_weapon( "iw5_em1_mp" );
    gungame_add_weapon( "iw5_epm3_mp" );
    gungame_add_weapon( "iw5_hbra3_mp" );
    gungame_add_weapon( "iw5_riotshieldt6_mp" );
    gungame_add_weapon( "iw5_himar_mp" );
    gungame_add_weapon( "iw5_kf5_mp" );
    gungame_add_weapon( "iw5_dlcgun33_mp" );
    gungame_add_weapon( "iw5_gm6_mp" );
    gungame_add_weapon( "iw5_dlcgun23_mp" );
    gungame_add_weapon( "iw5_dlcgun3_mp" );
    gungame_add_weapon( "iw5_dlcgun8_mp" );
    gungame_add_weapon( "iw5_maaws_mp" );
    gungame_add_weapon( "iw5_mahem_mp" );
    gungame_add_weapon( "iw5_microdronelauncher_mp" );
    gungame_add_weapon( "iw5_m990_mp" );
    gungame_add_weapon( "iw5_mp11_mp" );
    gungame_add_weapon( "iw5_dlcgun18_mp" );
    gungame_add_weapon( "iw5_dlcgun2_mp" );
    gungame_add_weapon( "iw5_lsat_mp" );
    gungame_add_weapon( "iw5_dlcgun38_mp" );
    gungame_add_weapon( "iw5_rhino_mp" );
    gungame_add_weapon( "iw5_sac3_mp" );
    gungame_add_weapon( "iw5_sn6_mp" );
    gungame_add_weapon( "iw5_dlcgun6_mp" );
    gungame_add_weapon( "iw5_dlcgun7_mp" );
    gungame_add_weapon( "iw5_stingerm7_mp" );
    gungame_add_weapon( "iw5_dlcgun28_mp" );
    gungame_add_weapon( "iw5_asm1_mp" );
    gungame_add_weapon( "iw5_m182spr_mp" );
    gungame_add_weapon( "iw5_mors_mp" );
    gungame_add_weapon( "iw5_bal27_mp" );
    gungame_add_weapon( "iw5_rw1_mp" );
    gungame_add_weapon( "iw5_exoxmg_mp" );
    gungame_add_weapon( "iw5_thor_mp" );

    if ( !level.gungame_weapons.size )
    {
        println( "GunGame: no usable weapons; mode not installed." );
        return;
    }

    level.gungame_scorelimit = level.gungame_weapons.size * GG_SCORE_PER_KILL;
    // Native score checks read the watched value, not level.scorelimit.
    maps\mp\_utility::setoverridewatchdvar( "scorelimit", level.gungame_scorelimit );
    level.scorelimitoverride = 1;
    level.overtimescorewinoverride = 1;
    level.gungame_finished = false;
    level.gungame_active = true;
    level.gungame_original_killed_callback = level.callbackPlayerKilled;
    level.callbackPlayerKilled = ::gungame_callback_player_killed;
    level.gungame_original_score_callback = level.onPlayerScore;
    level.onPlayerScore = ::gungame_on_player_score;

    level thread gungame_watch_connections();
    foreach ( player in level.players )
        gungame_start_player( player );
    gungame_refresh_native_scores();
}

gungame_setup_ready()
{
    return isdefined( level.gametypestarted ) && level.gametypestarted &&
        isdefined( level.callbackPlayerKilled ) &&
        isdefined( level.players ) && isdefined( level.weaponlist ) &&
        isdefined( level.teambased ) && isdefined( level.watchdvars );
}

gungame_add_weapon( weapon )
{
    foreach ( available in level.weaponlist )
    {
        if ( available != weapon )
            continue;

        base = maps\mp\_utility::getbaseweaponname( weapon );
        // The native builder adds required scopes and paired-weapon attachments.
        weapon = maps\mp\gametypes\_class::buildweaponname(
            base, "none", "none", "none", 0, 0
        );
        level.gungame_weapons[level.gungame_weapons.size] = weapon;
        return;
    }

    println( "GunGame: skipping unavailable weapon " + weapon );
}

gungame_watch_connections()
{
    level endon( "game_ended" );
    for ( ;; )
    {
        level waittill( "connected", player );
        gungame_start_player( player );
    }
}

gungame_start_player( player )
{
    if ( !isdefined( player ) || !isplayer( player ) ||
         isdefined( player.gungame_tracking ) )
        return;

    player.gungame_tracking = true;
    player.gungame_stage = 0;
    player thread gungame_track_player();
    player thread gungame_watch_disconnect();
    player thread gungame_watch_team();
}

gungame_track_player()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    if ( isalive( self ) )
        self thread gungame_equip_stage();

    for ( ;; )
    {
        self waittill( "spawned_player" );
        gungame_refresh_native_scores();
        self thread gungame_equip_stage();
    }
}

gungame_watch_disconnect()
{
    level endon( "game_ended" );
    self waittill( "disconnect" );
    gungame_refresh_native_scores();
}

gungame_watch_team()
{
    self endon( "disconnect" );
    level endon( "game_ended" );
    for ( ;; )
    {
        self common_scripts\utility::waittill_either( "joined_team", "joined_spectators" );
        gungame_refresh_native_scores();
    }
}

gungame_callback_player_killed(
    inflictor, attacker, damage, meansOfDeath, weapon,
    direction, hitLocation, timeOffset, deathAnimDuration
)
{
    if ( !level.gungame_finished && game["state"] == "playing" &&
         gungame_is_enemy( attacker ) )
    {
        gungame_start_player( self );
        gungame_start_player( attacker );

        if ( maps\mp\_utility::ismeleeMOD( meansOfDeath ) &&
             self.gungame_stage > 0 )
            self.gungame_stage--;

        lastStage = level.gungame_weapons.size - 1;
        if ( attacker.gungame_stage < lastStage )
        {
            attacker.gungame_stage++;
            attacker thread gungame_equip_stage();
        }
        else if ( attacker.gungame_stage == lastStage && isdefined( weapon ) &&
                  maps\mp\_utility::getbaseweaponname( weapon ) ==
                  maps\mp\_utility::getbaseweaponname( level.gungame_weapons[lastStage] ) )
        {
            attacker.gungame_stage++;
            level.gungame_finished = true;
            level.gungame_winner = attacker;
        }
    }

    // Run on level, independently of native death/killcam waits and respawns.
    // Also repair native suicide, teamkill, and environmental-death penalties.
    gungame_refresh_native_scores();
    [[ level.gungame_original_killed_callback ]](
        inflictor, attacker, damage, meansOfDeath, weapon,
        direction, hitLocation, timeOffset, deathAnimDuration
    );
}

gungame_is_enemy( attacker )
{
    if ( !isdefined( attacker ) || !isplayer( attacker ) || attacker == self ||
         !isdefined( attacker.pers["team"] ) || !isdefined( self.pers["team"] ) ||
         attacker.pers["team"] == "spectator" || self.pers["team"] == "spectator" )
        return false;

    return !level.teambased || attacker.pers["team"] != self.pers["team"];
}

gungame_on_player_score( event, player, victim )
{
    // Preserve native awards but reconcile assists/bonuses with stage scores.
    gungame_refresh_native_scores();
    if ( isdefined( level.gungame_original_score_callback ) )
        return [[ level.gungame_original_score_callback ]]( event, player, victim );
    return undefined;
}

gungame_equip_stage()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "joined_team" );
    self endon( "joined_spectators" );
    level endon( "game_ended" );
    self notify( "gungame_equip_stage" );
    self endon( "gungame_equip_stage" );

    wait GG_EQUIP_DELAY;
    if ( !isalive( self ) || level.gungame_finished )
        return;

    stage = self.gungame_stage;
    weapon = level.gungame_weapons[stage];
    attempts = 0;
    while ( !self loadweapons( weapon ) )
    {
        if ( attempts >= GG_WAIT_ATTEMPTS )
        {
            println( "GunGame: timed out loading " + weapon );
            return;
        }
        wait GG_WAIT_INTERVAL;
        attempts++;
    }

    if ( !isalive( self ) || self.gungame_stage != stage || level.gungame_finished )
        return;

    self takeallweapons();
    self maps\mp\_utility::_giveweapon( weapon );
    self.primaryweapon = weapon;
    self.pers["primaryWeapon"] = maps\mp\_utility::getbaseweaponname( weapon );
    self givemaxammo( weapon );
    self switchtoweaponimmediate( weapon );
    self switchtoweapon( weapon );
}

gungame_refresh_native_scores()
{
    if ( isdefined( level.gungame_score_refresh_pending ) )
        return;
    level.gungame_score_refresh_pending = true;
    level thread gungame_refresh_native_scores_next_frame();
}

gungame_refresh_native_scores_next_frame()
{
    level endon( "game_ended" );
    wait 0;
    level.gungame_score_refresh_pending = undefined;

    foreach ( player in level.players )
    {
        if ( !isdefined( player ) || !isdefined( player.gungame_stage ) ||
             !isdefined( player.pers ) )
            continue;

        score = player.gungame_stage * GG_SCORE_PER_KILL;
        maps\mp\gametypes\_gamescore::_setPlayerScore( player, score );
        player.score = score;
        player maps\mp\_utility::setExtraScore0( score );
    }

    gungame_update_team_scores();
    level thread maps\mp\gametypes\_gamescore::sendUpdatedDMScores();

    if ( level.gungame_finished && isdefined( level.gungame_winner ) &&
         !isdefined( level.gungame_win_checked ) )
    {
        level.gungame_win_checked = true;
        // All scores are consistent before any native setter can end the game.
        level.scorelimitoverride = 0;
        level.gungame_winner thread maps\mp\gametypes\_gamelogic::checkScoreLimit();
    }
    else if ( level.gungame_finished && !isdefined( level.gungame_winner ) &&
              !isdefined( level.gungame_win_checked ) )
    {
        // A disconnect in the winning frame must not freeze the remaining game.
        level.gungame_finished = false;
    }
}

gungame_update_team_scores()
{
    if ( !level.teambased || !isdefined( level.teamNameList ) )
        return;

    foreach ( team in level.teamNameList )
    {
        teamLeadScore = 0;
        foreach ( player in level.players )
        {
            if ( !isdefined( player ) || !isdefined( player.gungame_stage ) ||
                 !isdefined( player.pers["team"] ) || player.pers["team"] != team )
                continue;

            playerScore = player.gungame_stage * GG_SCORE_PER_KILL;
            if ( playerScore > teamLeadScore )
                teamLeadScore = playerScore;
        }
        maps\mp\gametypes\_gamescore::_setTeamScore( team, teamLeadScore );
    }
}

/*
    S1x Combat Training Gun Game.

    Load this script alongside the other MP scripts. Each kill advances
    the player through the usable Advanced Warfare multiplayer weapons.
*/

#define GG_SCORE_PER_KILL 100

init()
{
    if ( isdefined( level.gungame_started ) )
    {
        return;
    }

    level.gungame_started = 1;
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

    level.gungame_scorelimit =
        level.gungame_weapons.size * GG_SCORE_PER_KILL;
    level.scorelimit = level.gungame_scorelimit;
    setdvar(
        "scr_dm_scorelimit",
        "" + level.gungame_scorelimit
    );
    setdvar(
        "scr_war_scorelimit",
        "" + level.gungame_scorelimit
    );

    level thread gungame_install_kill_callback();
    level thread gungame_watch_connections();
}


gungame_add_weapon( weapon )
{
    level.gungame_weapons[
        level.gungame_weapons.size
    ] = weapon;
}


gungame_watch_connections()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread gungame_track_player();
    }
}


gungame_track_player()
{
    self endon( "disconnect" );

    self.gungame_stage = 0;
    self.gungame_score_initialized = 0;

    for ( ;; )
    {
        self waittill( "spawned_player" );

        if ( !self.gungame_score_initialized )
        {
            self.gungame_score_initialized = 1;
            self thread gungame_update_native_score();
        }

        self thread gungame_equip_stage();
    }
}


gungame_install_kill_callback()
{
    level endon( "game_ended" );

    waitCount = 0;

    while ( ( !isdefined( level.callbackPlayerKilled ) ||
              !isdefined( level.gametypestarted ) ||
              !level.gametypestarted ) &&
            waitCount < 600 )
    {
        waitCount++;
        wait 0.05;
    }

    if ( !isdefined( level.callbackPlayerKilled ) )
    {
        println(
            "GunGame: couldn't find the native player-killed callback."
        );
        return;
    }

    level.gungame_original_killed_callback =
        level.callbackPlayerKilled;
    level.callbackPlayerKilled =
        ::gungame_callback_player_killed;
}


gungame_callback_player_killed(
    inflictor,
    attacker,
    damage,
    meansOfDeath,
    weapon,
    direction,
    hitLocation,
    timeOffset,
    deathAnimDuration
)
{
    if ( isdefined( level.gungame_original_killed_callback ) )
    {
        [[ level.gungame_original_killed_callback ]](
            inflictor,
            attacker,
            damage,
            meansOfDeath,
            weapon,
            direction,
            hitLocation,
            timeOffset,
            deathAnimDuration
        );
    }

    if ( !isdefined( attacker ) ||
         !isplayer( attacker ) ||
         attacker == self )
    {
        return;
    }

    if ( isdefined( meansOfDeath ) &&
         ismeleeMOD( meansOfDeath ) )
    {
        gungame_set_back_player( self );
    }

    gungame_advance_player( attacker );
}


gungame_equip_stage()
{
    self endon( "disconnect" );

    wait 0.5;

    if ( !isAlive( self ) )
    {
        return;
    }

    if ( !isdefined( self.gungame_stage ) )
    {
        self.gungame_stage = 0;
    }

    weaponIndex = self.gungame_stage;

    if ( weaponIndex >= level.gungame_weapons.size )
    {
        weaponIndex = level.gungame_weapons.size - 1;
    }

    weapon = level.gungame_weapons[weaponIndex];

    self takeallweapons();
    self giveweapon( weapon );
    self switchtoweapon( weapon );
}


gungame_advance_player( player )
{
    if ( !isdefined( player ) ||
         !isplayer( player ) ||
         !isdefined( player.gungame_stage ) )
    {
        return;
    }

    if ( player.gungame_stage <
         level.gungame_weapons.size )
    {
        player.gungame_stage++;
    }

    player thread gungame_update_native_score();

    if ( player.gungame_stage <
         level.gungame_weapons.size )
    {
        player thread gungame_equip_stage();
    }
}


gungame_set_back_player( player )
{
    if ( !isdefined( player ) ||
         !isplayer( player ) ||
         !isdefined( player.gungame_stage ) )
    {
        return;
    }

    if ( player.gungame_stage > 0 )
    {
        player.gungame_stage--;
    }

    player thread gungame_update_native_score();
}


gungame_update_native_score()
{
    score =
        self.gungame_stage * GG_SCORE_PER_KILL;

    maps\mp\gametypes\_gamescore::_setPlayerScore(
        self,
        score
    );

    self setExtraScore0( score );

    level thread
        maps\mp\gametypes\_gamescore::sendUpdatedDMScores();

    gungame_update_team_scores();
}


gungame_update_team_scores()
{
    if ( !isdefined( level.teambased ) ||
         !level.teambased ||
         !isdefined( level.teamNameList ) )
    {
        return;
    }

    foreach ( team in level.teamNameList )
    {
        teamLeadScore = 0;

        foreach ( player in level.players )
        {
            if ( !isdefined( player ) ||
                 !isdefined( player.gungame_stage ) ||
                 !isdefined( player.pers ) ||
                 !isdefined( player.pers["team"] ) ||
                 player.pers["team"] != team )
            {
                continue;
            }

            playerScore =
                player.gungame_stage *
                GG_SCORE_PER_KILL;

            if ( playerScore > teamLeadScore )
            {
                teamLeadScore = playerScore;
            }
        }

        maps\mp\gametypes\_gamescore::_setTeamScore(
            team,
            teamLeadScore
        );
    }
}

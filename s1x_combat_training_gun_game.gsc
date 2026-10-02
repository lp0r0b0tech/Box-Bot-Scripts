/*
    S1x Combat Training Gun Game.

    Load this script alongside the other MP scripts. A kill of another
    player advances the attacker through the usable weapon list.
    Each stage is worth GG_SCORE_PER_KILL points; a kill with the
    final weapon reaches the score limit. Melee kills set the victim
    back one stage.
*/

#define GG_SCORE_PER_KILL 100
#define GG_EQUIP_DELAY 0.5
#define GG_SETUP_WAIT_INTERVAL 0.05
#define GG_SETUP_WAIT_ATTEMPTS 600
#define GG_SCORELIMIT_GUARD 999999

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
    gungame_set_scorelimit( GG_SCORELIMIT_GUARD );

    level thread gungame_install_kill_callback();
    level thread gungame_watch_connections();
    level thread gungame_start_existing_players();
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

    if ( !gungame_wait_for_setup( false ) )
    {
        return;
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        gungame_start_player( player );
    }
}


gungame_start_existing_players()
{
    level endon( "game_ended" );

    if ( !gungame_wait_for_setup( false ) )
    {
        return;
    }

    foreach ( player in level.players )
    {
        gungame_start_player( player );
    }
}


gungame_start_player( player )
{
    if ( !isdefined( player ) ||
         !isplayer( player ) ||
         isdefined( player.gungame_tracking ) )
    {
        return;
    }

    player.gungame_tracking = 1;

    if ( !isdefined( player.gungame_stage ) )
    {
        player.gungame_stage = 0;
    }

    player thread gungame_track_player();
    player thread gungame_watch_disconnect();
}


gungame_track_player()
{
    self endon( "disconnect" );

    if ( isAlive( self ) )
    {
        self thread gungame_update_native_score();
        self thread gungame_equip_stage();
    }

    for ( ;; )
    {
        self waittill( "spawned_player" );

        self thread gungame_update_native_score();
        self thread gungame_equip_stage();
    }
}


gungame_watch_disconnect()
{
    level endon( "game_ended" );

    self waittill( "disconnect" );
    wait 0;

    gungame_update_team_scores();
    gungame_refresh_native_scores();
}


gungame_install_kill_callback()
{
    level endon( "game_ended" );

    if ( !gungame_wait_for_setup( true ) )
    {
        return;
    }

    gungame_set_scorelimit( GG_SCORELIMIT_GUARD );

    level.gungame_original_killed_callback =
        level.callbackPlayerKilled;
    level.callbackPlayerKilled =
        ::gungame_callback_player_killed;
}


gungame_wait_for_setup( waitForCallback )
{
    waitAttempts = 0;

    while ( !gungame_setup_is_ready( waitForCallback ) &&
            waitAttempts < GG_SETUP_WAIT_ATTEMPTS )
    {
        wait GG_SETUP_WAIT_INTERVAL;
        waitAttempts++;
    }

    if ( !gungame_setup_is_ready( waitForCallback ) )
    {
        if ( waitForCallback )
        {
            println(
                "GunGame: timed out after " +
                ( GG_SETUP_WAIT_ATTEMPTS *
                  GG_SETUP_WAIT_INTERVAL ) +
                " seconds waiting for native kill callback setup."
            );
        }
        else
        {
            println(
                "GunGame: timed out after " +
                ( GG_SETUP_WAIT_ATTEMPTS *
                  GG_SETUP_WAIT_INTERVAL ) +
                " seconds waiting for the player list or gametype start."
            );
        }

        return false;
    }

    return true;
}


gungame_setup_is_ready( waitForCallback )
{
    if ( !isdefined( level.gametypestarted ) ||
         !level.gametypestarted )
    {
        return false;
    }

    if ( waitForCallback )
    {
        return isdefined( level.callbackPlayerKilled );
    }

    return isdefined( level.players );
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
    hasAttacker =
        isdefined( attacker ) &&
        isplayer( attacker ) &&
        attacker != self;

    meleeKill =
        isdefined( meansOfDeath ) &&
        ismeleeMOD( meansOfDeath );

    if ( hasAttacker )
    {
        gungame_start_player( self );
        gungame_start_player( attacker );

        if ( meleeKill )
        {
            gungame_set_back_player( self );
        }

        gungame_advance_player( attacker );

    }

    if ( hasAttacker )
    {
        gungame_set_scorelimit( GG_SCORELIMIT_GUARD );
    }

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

    if ( !hasAttacker )
    {
        return;
    }

    if ( isdefined( attacker.gungame_stage ) &&
         attacker.gungame_stage >=
         level.gungame_weapons.size )
    {
        gungame_set_scorelimit( level.gungame_scorelimit );
    }

    gungame_update_team_scores();

    // Replace native kill points with the updated Gun Game stage score.
    if ( meleeKill )
    {
        gungame_set_native_player_score( self );
    }

    gungame_set_native_player_score( attacker );
    gungame_refresh_native_scores();

    if ( isdefined( attacker.gungame_stage ) )
    {
        if ( attacker.gungame_stage <
             level.gungame_weapons.size )
        {
            attacker thread gungame_equip_stage();
        }
        else
        {
            attacker maps\mp\gametypes\_gamelogic::checkScoreLimit();
        }
    }
}


gungame_set_scorelimit( scorelimit )
{
    level.scorelimit = scorelimit;
    setdvar( "scr_dm_scorelimit", "" + scorelimit );
    setdvar( "scr_war_scorelimit", "" + scorelimit );
}


gungame_equip_stage()
{
    self endon( "disconnect" );

    self notify( "gungame_equip_stage" );
    self endon( "gungame_equip_stage" );

    wait GG_EQUIP_DELAY;

    if ( !isAlive( self ) )
    {
        return;
    }

    if ( !isdefined( self.gungame_stage ) )
    {
        self.gungame_stage = 0;
    }

    if ( self.gungame_stage >=
         level.gungame_weapons.size )
    {
        return;
    }

    weapon =
        level.gungame_weapons[self.gungame_stage];

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

}


gungame_update_native_score()
{
    gungame_set_native_player_score( self );
    gungame_update_team_scores();
    gungame_refresh_native_scores();
}


gungame_set_native_player_score( player )
{
    if ( !isdefined( player ) ||
         !isdefined( player.gungame_stage ) )
    {
        return;
    }

    score =
        player.gungame_stage * GG_SCORE_PER_KILL;

    maps\mp\gametypes\_gamescore::_setPlayerScore(
        player,
        score
    );

    player setExtraScore0( score );
}


gungame_refresh_native_scores()
{
    if ( isdefined( level.gungame_score_refresh_pending ) )
    {
        return;
    }

    level.gungame_score_refresh_pending = 1;
    level thread gungame_refresh_native_scores_next_frame();
}


gungame_refresh_native_scores_next_frame()
{
    level endon( "game_ended" );

    wait 0;

    level.gungame_score_refresh_pending = undefined;
    level thread
        maps\mp\gametypes\_gamescore::sendUpdatedDMScores();
}


gungame_update_team_scores()
{
    if ( !isdefined( level.teambased ) ||
         !level.teambased ||
         !isdefined( level.teamNameList ) ||
         !isdefined( level.players ) )
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

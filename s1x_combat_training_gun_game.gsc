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

    for ( ;; )
    {
        self waittill( "spawned_player" );
        self thread gungame_equip_stage();

        self waittill(
            "death",
            attacker,
            meansOfDeath
        );

        if ( isdefined( attacker ) &&
             isplayer( attacker ) &&
             attacker != self )
        {
            if ( isdefined( meansOfDeath ) &&
                 ismeleeMOD( meansOfDeath ) )
            {
                gungame_set_back_player( self );
            }
            else
            {
                gungame_advance_player( attacker );
            }
        }
    }
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
         level.gungame_weapons.size - 1 )
    {
        player.gungame_stage++;
    }

    player thread gungame_equip_stage();
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

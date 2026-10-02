/*
    S1x Combat Training Gun Game.

    Install in s1/scripts/mp alongside autobots_combat_training.gsc.
    Select native Gun Game (g_gametype gun) before starting the map.
    This script does nothing in other modes. Remove older copies.

    Extends the native weapon roster and promotes melee kills while
    holding the current knife/shield stage weapon. The native kill
    handler still handles victim setbacks and all other kills.
    Native Gun Game owns scoring, HUD, ammo, spawning, randomization,
    time limits, and victory. Match score is one point per stage;
    native award points are separate.

    Missing weapons are logged and skipped.
    The score limit is the number of usable stages. Load at map startup,
    not into an ongoing match. Other scripts must not force loadouts.
*/

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
    if ( gametype != "gun" )
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
        println( "GunGame: native setup timed out; keeping the stock roster." );
        return;
    }

    // Do not replace a roster after native giveNextGun has captured a weapon.
    // Its streaming wait can otherwise equip an old weapon over the new stage.
    foreach ( player in level.players )
    {
        if ( isdefined( player ) &&
             ( isdefined( player.gun_curgun ) || isalive( player ) ) )
        {
            println( "GunGame: players already spawned; restart the map to install the roster." );
            return;
        }
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
        println( "GunGame: no usable weapons; keeping the stock roster." );
        return;
    }

    level.gun_guns = level.gungame_weapons;
    setdynamicdvar( "scr_gun_scorelimit", level.gun_guns.size );
    maps\mp\_utility::registerscorelimitdvar( "gun", level.gun_guns.size );
    // Private-match properties must not restore the old roster's limit.
    maps\mp\_utility::setoverridewatchdvar( "scorelimit", level.gun_guns.size );
    level notify( "update_scorelimit", level.gun_guns.size );
    level.gungame_active = true;
    level.gungame_original_killed = level.onPlayerKilled;
    level.onPlayerKilled = ::gungame_on_player_killed;

    // Native connection/spawn handlers use the new roster for later players.
    foreach ( player in level.players )
    {
        if ( isdefined( player ) && isdefined( player.gungamegunindex ) &&
             level.matchrules_randomize )
            player.gunlist = common_scripts\utility::array_randomize( level.gun_guns );
    }
}

gungame_setup_ready()
{
    return isdefined( level.gun_guns ) && isdefined( level.onSpawnPlayer ) &&
        isdefined( level.onPlayerKilled ) &&
        isdefined( level.matchrules_randomize ) &&
        isdefined( level.players ) && isdefined( level.weaponlist ) &&
        isdefined( level.teambased ) && isdefined( level.watchdvars );
}

gungame_add_weapon( weapon )
{
    foreach ( available in level.weaponlist )
    {
        if ( available != weapon )
            continue;

        // Native gun::addattachments expects base IDs, not assembled weapons.
        level.gungame_weapons[level.gungame_weapons.size] =
            maps\mp\_utility::getbaseweaponname( weapon );
        return;
    }

    println( "GunGame: skipping unavailable weapon " + weapon );
}

gungame_on_player_killed(
    inflictor, attacker, damage, meansOfDeath, weapon,
    direction, hitLocation, timeOffset, deathAnimDuration, lifeId
)
{
    stage = gungame_melee_stage( attacker, meansOfDeath );

    // Call once, with the real kill data: native victim setbacks stay intact.
    [[ level.gungame_original_killed ]](
        inflictor, attacker, damage, meansOfDeath, weapon,
        direction, hitLocation, timeOffset, deathAnimDuration, lifeId
    );

    if ( stage < 0 || !isdefined( attacker ) ||
         attacker.gungamegunindex != stage || game["state"] != "playing" )
        return;

    // Do not double-promote if a native handler already advanced this kill.
    attacker.gungameprevgunindex = stage;
    attacker.gungamegunindex++;
    attacker.lastkillweapon = weapon;
    attacker.lastleveluptime = gettime();
    attacker thread maps\mp\_events::increasegunlevelevent();

    if ( attacker.gungamegunindex < level.gun_guns.size )
        attacker thread gungame_equip_after_melee();
}

gungame_melee_stage( attacker, meansOfDeath )
{
    if ( game["state"] != "playing" || !isplayer( self ) ||
         !isdefined( attacker ) || !isplayer( attacker ) || attacker == self ||
         !isalive( attacker ) || !isdefined( meansOfDeath ) ||
         !maps\mp\_utility::ismeleeMOD( meansOfDeath ) ||
         !isdefined( attacker.gungamegunindex ) ||
         !isdefined( attacker.pers["team"] ) ||
         !isdefined( self.pers["team"] ) ||
         attacker.pers["team"] == "spectator" || self.pers["team"] == "spectator" )
        return -1;

    guns = level.gun_guns;
    if ( level.matchrules_randomize )
    {
        if ( !isdefined( attacker.gunlist ) )
            return -1;
        guns = attacker.gunlist;
    }

    stage = attacker.gungamegunindex;
    if ( stage < 0 || stage >= guns.size )
        return -1;

    base = maps\mp\_utility::getbaseweaponname( guns[stage] );
    if ( base != "iw5_combatknife" && base != "iw5_riotshieldt6" )
        return -1;

    // A second kill before the new weapon streams must not skip another stage.
    heldWeapon = attacker getcurrentweapon();
    if ( !isdefined( heldWeapon ) || heldWeapon == "none" ||
         maps\mp\_utility::getbaseweaponname( heldWeapon ) != base )
        return -1;

    return stage;
}

gungame_equip_after_melee()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "spawned_player" );
    self endon( "joined_team" );
    self endon( "joined_spectators" );
    level endon( "game_ended" );
    self notify( "gungame_melee_equip" );
    self endon( "gungame_melee_equip" );

    if ( !isalive( self ) || game["state"] != "playing" )
        return;

    stage = self.gungamegunindex;
    base = self maps\mp\gametypes\gun::getnextgun();
    weapon = maps\mp\gametypes\gun::addattachments( base );
    attempts = 0;
    while ( !self loadweapons( weapon ) )
    {
        if ( self.gungamegunindex != stage || attempts >= GG_WAIT_ATTEMPTS )
            return;
        wait GG_WAIT_INTERVAL;
        attempts++;
    }

    // Native giveNextGun can yield while streaming without rechecking its stage.
    // Revalidate here so a newer promotion or spawn keeps its own loadout.
    if ( !isalive( self ) || self.gungamegunindex != stage ||
         game["state"] != "playing" )
        return;

    self.gun_curgun = base;
    self takeallweapons();
    self maps\mp\_utility::_giveweapon( weapon );
    self.primaryweapon = weapon;
    self.pers["primaryWeapon"] = maps\mp\_utility::getbaseweaponname( weapon );
    self givestartammo( weapon );
    self switchtoweaponimmediate( weapon );
    self switchtoweapon( weapon );
    self.gungameprevgunindex = self.gungamegunindex;
}

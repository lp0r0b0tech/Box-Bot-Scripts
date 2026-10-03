/*
    S1x Combat Training Gun Game.

    Install in s1/scripts/mp alongside autobots_combat_training.gsc.
    Select native Gun Game (g_gametype gun) before starting the map.
    This script does nothing in other modes. Remove older copies.

    Each weapon family is one stage. Pick one random registered variant
    for each player whenever that weapon is equipped, including respawns
    and revisits after setbacks. A qualifying kill advances to the next
    weapon family, not another variant. Use the base if no variants exist.
    The native Randomize option controls weapon-family order only.

    Extends the native weapon roster and promotes melee kills while
    holding the current knife/shield stage weapon. The native kill
    handler still handles victim setbacks and all other kills.
    Native Gun Game owns scoring, HUD, ammo, spawning, randomization,
    time limits, and victory. Match score is one point per stage;
    native award points are separate. Matches have a 15-minute time limit;
    completing the weapon progression can still end the match sooner.
    The native bottom-left score follows completed weapon stages,
    including setbacks immediately; award/XP points remain separate.

    Variants and built-in attachments come from the native stats table,
    not guessed loot numbers. Missing weapon families are logged and skipped.
    The score limit is the number of usable stages. Load at map startup,
    not into an ongoing match. Other scripts must not force loadouts.
*/

#define GG_WAIT_INTERVAL 0.05
#define GG_WAIT_ATTEMPTS 600
#define GG_MATCH_MINUTES 15

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
    level.gungame_family_seen = [];
    gungame_index_variants();
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
    // Native gun::addattachments uses this to include variant-built-in attachments.
    setdvar( "scr_gun_loot_variants", 1 );
    setdynamicdvar( "scr_gun_scorelimit", level.gun_guns.size );
    maps\mp\_utility::registerscorelimitdvar( "gun", level.gun_guns.size );
    // Private-match properties must not restore the old roster's limit.
    maps\mp\_utility::setoverridewatchdvar( "scorelimit", level.gun_guns.size );
    level notify( "update_scorelimit", level.gun_guns.size );
    setdynamicdvar( "scr_gun_timelimit", GG_MATCH_MINUTES );
    maps\mp\_utility::setoverridewatchdvar( "timelimit", GG_MATCH_MINUTES );
    maps\mp\_utility::registertimelimitdvar( "gun", GG_MATCH_MINUTES );
    level notify( "update_timelimit", GG_MATCH_MINUTES );
    level.gungame_active = true;
    level.gungame_original_killed = level.onPlayerKilled;
    level.onPlayerKilled = ::gungame_on_player_killed;
    level.gungame_original_score = level.onPlayerScore;
    level.onPlayerScore = ::gungame_on_player_score;
    level.onSpawnPlayer = ::gungame_on_spawn_player;

    // Native gun uses gunlist only in this mode. Preserve the user's order
    // setting separately; variant choices must never mutate the shared roster.
    level.gungame_randomize_order = level.matchrules_randomize;
    level.matchrules_randomize = true;
    foreach ( player in level.players )
    {
        if ( isdefined( player ) && isdefined( player.gungamegunindex ) )
            player gungame_init_player_roster();
    }
    gungame_refresh_native_scores();
}

gungame_setup_ready()
{
    return isdefined( level.gun_guns ) && isdefined( level.onSpawnPlayer ) &&
        isdefined( level.onPlayerKilled ) &&
        isdefined( level.onPlayerScore ) &&
        isdefined( level.matchrules_randomize ) &&
        isdefined( level.players ) && isdefined( level.weaponlist ) &&
        isdefined( level.teambased ) && isdefined( level.watchdvars );
}

gungame_index_variants()
{
    level.gungame_variant_families = [];
    level.gungame_registered_weapons = [];
    table = "mp/statstable.csv";
    rows = tablegetrowcount( table );

    for ( row = 0; row < rows; row++ )
    {
        name = tablelookupbyrow( table, row, 4 );
        category = tablelookupbyrow( table, row, 2 );
        if ( !isdefined( name ) || name == "" ||
             getsubstr( name, 0, 4 ) != "iw5_" ||
             !isdefined( category ) || !issubstr( category, "weapon_" ) ||
             tablelookupbyrow( table, row, 51 ) != "" ||
             isdefined( level.gungame_registered_weapons[name] ) )
            continue;

        family = maps\mp\_utility::getbaseweaponname( name, 1 );
        if ( !isdefined( level.gungame_variant_families[family] ) )
            level.gungame_variant_families[family] = [];

        variants = level.gungame_variant_families[family];
        variants[variants.size] = name;
        level.gungame_variant_families[family] = variants;
        level.gungame_registered_weapons[name] = true;
    }
}

gungame_add_weapon( weapon )
{
    family = maps\mp\_utility::getbaseweaponname( weapon, 1 );
    if ( isdefined( level.gungame_family_seen[family] ) )
        return;
    level.gungame_family_seen[family] = true;

    if ( !isdefined( level.gungame_variant_families[family] ) )
    {
        println( "GunGame: skipping unregistered weapon family " + family );
        return;
    }

    // A single representative per family keeps the native score limit in stages.
    if ( isdefined( level.gungame_registered_weapons[family] ) )
        representative = family;
    else
        representative = level.gungame_variant_families[family][0];
    level.gungame_weapons[level.gungame_weapons.size] = representative;
}

gungame_init_player_roster()
{
    if ( isdefined( self.gungame_family_order ) )
        return;

    self.gungame_family_order = [];
    foreach ( weapon in level.gun_guns )
    {
        self.gungame_family_order[self.gungame_family_order.size] =
            maps\mp\_utility::getbaseweaponname( weapon, 1 );
    }
    if ( level.gungame_randomize_order )
        self.gungame_family_order =
            common_scripts\utility::array_randomize( self.gungame_family_order );

    self.gunlist = [];
    for ( stage = 0; stage < self.gungame_family_order.size; stage++ )
        self gungame_pick_variant( stage );
    self thread gungame_watch_score_disconnect();
}

gungame_pick_variant( stage )
{
    if ( stage < 0 || stage >= self.gungame_family_order.size )
        return;

    family = self.gungame_family_order[stage];
    variants = level.gungame_variant_families[family];
    choices = [];
    foreach ( variant in variants )
    {
        if ( variant != family )
            choices[choices.size] = variant;
    }
    if ( !choices.size )
        choices = variants;

    self.gunlist[stage] = choices[randomint( choices.size )];
}

gungame_on_spawn_player()
{
    // Match-rule reinitialization must not switch native kills back to the
    // shared representatives instead of this player's selected variants.
    level.matchrules_randomize = true;
    self notify( "gungame_variant_spawn" );
    self gungame_init_player_roster();
    if ( isdefined( self.gungamegunindex ) )
        self gungame_pick_variant( self.gungamegunindex );

    self thread gungame_spawn_loadout();
    gungame_refresh_native_scores();
}

gungame_spawn_loadout()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "gungame_variant_spawn" );
    level endon( "game_ended" );

    // Same loadout boundary and setback event as native gun::waitloadoutdone.
    level waittill( "player_spawned" );
    // A weapon-streaming wait must not delay the native setback splash/stats.
    if ( self.showsetbacksplash )
    {
        self.showsetbacksplash = false;
        self thread maps\mp\_events::decreasegunlevelevent();
    }
    gungame_refresh_native_scores();
    self gungame_equip_stage( true );
}

gungame_on_player_killed(
    inflictor, attacker, damage, meansOfDeath, weapon,
    direction, hitLocation, timeOffset, deathAnimDuration, lifeId
)
{
    // Schedule before native handling: promotions can wait for weapon streaming.
    gungame_refresh_native_scores();
    level.matchrules_randomize = true;
    if ( isdefined( attacker ) && isplayer( attacker ) && attacker != self )
    {
        // Cancel the native promotion's streaming wait before a respawn can
        // reroll the stage. Score events already run on independent threads.
        attacker endon( "disconnect" );
        attacker endon( "death" );
        attacker endon( "gungame_variant_spawn" );
        attacker endon( "joined_team" );
        attacker endon( "joined_spectators" );
    }

    if ( gungame_wrong_variant_kill( attacker, meansOfDeath, weapon ) )
        return;

    stage = gungame_melee_stage( attacker, meansOfDeath );

    // Native onPlayerKilled increments and equips before returning, so prepare
    // the next slot now. Leave the current variant unchanged for kill matching.
    if ( isdefined( attacker ) && isplayer( attacker ) && attacker != self &&
         isdefined( attacker.gungame_family_order ) &&
         isdefined( attacker.gungamegunindex ) )
        attacker gungame_pick_variant( attacker.gungamegunindex + 1 );

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
    gungame_refresh_native_scores();

    if ( attacker.gungamegunindex < level.gun_guns.size )
        attacker thread gungame_equip_stage( false );
}

gungame_on_player_score( event, player, victim )
{
    // Preserve native award statistics, not its additive match-score delta.
    // In particular, the delayed respawn setback must not subtract twice.
    player [[ level.gungame_original_score ]]( event, player, victim );
    gungame_refresh_native_scores();
    return 0;
}

gungame_watch_score_disconnect()
{
    level endon( "game_ended" );
    self waittill( "disconnect" );
    gungame_refresh_native_scores();
}

gungame_refresh_native_scores()
{
    if ( isdefined( level.gungame_score_refresh_pending ) )
        return;

    level.gungame_score_refresh_pending = true;
    level thread gungame_sync_native_scores();
}

gungame_sync_native_scores()
{
    level endon( "game_ended" );
    wait 0;
    level.gungame_score_refresh_pending = undefined;

    if ( game["state"] == "postgame" )
        return;

    setdvar( "ui_scorelimit", level.gun_guns.size );
    // Queue the native HUD refresh before a winning score can end this thread.
    level thread maps\mp\gametypes\_gamescore::sendUpdatedDMScores();
    foreach ( player in level.players )
    {
        if ( !isdefined( player ) || !isplayer( player ) ||
             !isdefined( player.gungamegunindex ) ||
             !isdefined( player.pers ) || !isdefined( player.pers["score"] ) )
            continue;

        score = int( max( 0, min( player.gungamegunindex, level.gun_guns.size ) ) );
        changed = player.pers["score"] != score;
        // This native setter also checks victory in the player's context.
        maps\mp\gametypes\_gamescore::_setPlayerScore( player, score );
        // The setter returns early if pers["score"] already matches.
        player.score = score;
        if ( changed )
            player maps\mp\gametypes\_gamelogic::checkplayerscorelimitsoon();
    }
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
    family = maps\mp\_utility::getbaseweaponname( guns[stage], 1 );
    if ( family != "iw5_combatknife" && family != "iw5_riotshieldt6" )
        return -1;

    // A second kill before the new weapon streams must not skip another stage.
    heldWeapon = attacker getcurrentweapon();
    if ( !isdefined( heldWeapon ) || heldWeapon == "none" ||
         maps\mp\_utility::getbaseweaponname( heldWeapon ) != base )
        return -1;

    return stage;
}

gungame_wrong_variant_kill( attacker, meansOfDeath, weapon )
{
    if ( !isplayer( self ) || !isdefined( attacker ) ||
         !isplayer( attacker ) || attacker == self ||
         !isdefined( attacker.gungamegunindex ) || !isdefined( weapon ) )
        return false;

    // Only tighten native weapon-promotion checks, never suicide/melee setbacks.
    if ( meansOfDeath != "MOD_PISTOL_BULLET" && meansOfDeath != "MOD_RIFLE_BULLET" &&
         meansOfDeath != "MOD_HEAD_SHOT" && meansOfDeath != "MOD_PROJECTILE" &&
         meansOfDeath != "MOD_PROJECTILE_SPLASH" && meansOfDeath != "MOD_EXPLOSIVE" &&
         meansOfDeath != "MOD_IMPACT" && meansOfDeath != "MOD_GRENADE" &&
         meansOfDeath != "MOD_GRENADE_SPLASH" )
        return false;
    if ( weapon == "boost_slam_mp" || weapon == "iw5_dlcgun12loot8_mp" )
        return false;

    guns = level.gun_guns;
    if ( level.matchrules_randomize )
    {
        if ( !isdefined( attacker.gunlist ) )
            return false;
        guns = attacker.gunlist;
    }

    stage = attacker.gungamegunindex;
    if ( stage < 0 || stage >= guns.size )
        return true;

    // Native substring matching confuses loot1 with loot10 or a plain base.
    return maps\mp\_utility::getbaseweaponname( weapon ) !=
        maps\mp\_utility::getbaseweaponname( guns[stage] );
}

gungame_equip_stage( spawnEquip )
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "gungame_variant_spawn" );
    if ( !spawnEquip )
        self endon( "spawned_player" );
    self endon( "joined_team" );
    self endon( "joined_spectators" );
    level endon( "game_ended" );
    self notify( "gungame_melee_equip" );
    self endon( "gungame_melee_equip" );

    if ( !isalive( self ) || game["state"] == "postgame" )
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
         self.gunlist[stage] != base || game["state"] == "postgame" )
        return;

    self.gun_curgun = base;
    self takeallweapons();
    self maps\mp\_utility::_giveweapon( weapon );
    self.primaryweapon = weapon;
    self.pers["primaryWeapon"] = maps\mp\_utility::getbaseweaponname( weapon );
    self givestartammo( weapon );
    if ( spawnEquip )
        self setspawnweapon( weapon );
    self switchtoweaponimmediate( weapon );
    self switchtoweapon( weapon );
    self.gungameprevgunindex = self.gungamegunindex;
}

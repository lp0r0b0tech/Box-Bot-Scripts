/*
    Exo Zombies Microwave Gun support

    Only Infection (mp_zombie_brg) ships the script that makes the Microwave
    Gun work. The weapon from mods/exo_weapons_all deals no damage by itself
    (the beam is script driven), so on every other zombies map it looks right
    but never hurts anything. This script ports the Infection behaviour:

        - holding fire cooks every zombie inside a thin beam (650 units
          hip-fire, up to 850 units while aiming, shortened by walls),
        - each tick deals 30 damage and stacks a slow on the zombie
          (down to 60% - 40% speed for 3 - 10 s, scaling with weapon level),
        - a cooked zombie bubbles: the flesh effects on its spine, head and
          shoulders grow as the cooking builds up, under a bubbling loop,
        - a zombie the beam kills pops in the microwave gib effect with the
          pop sound, and its body vanishes,
        - insta-kill turns the beam into an outright kill,
        - the beam drains a 900 unit energy battery shown on the HUD,
          and max ammo, buying again or upgrading the weapon refills it.

    Surface impacts: the other maps only know the beam's concrete impact
    (Infection's impact table adds flammable surfaces and water), so while
    fire is held the script plays those two itself, about every 150 ms, at
    the point where the beam meets the world.

    It does nothing when:
        - the map already provides the Microwave Gun (Infection),
        - mods/exo_weapons_all is not loaded.

    The effects and sounds ship in the pack from build 9 on, so the pack and
    this script have to be installed together: loading the effects against
    an older pack raises a script error. The burger quest and the
    cooked-zombies achievement are Infection only.

    Toggle:
        set scr_zm_microwave_enabled 1

    Diagnostics (every map start and the first use of each effect):
        s1/exo_zombies_support.log
*/

#define MWS_GUN_NAME            "iw5_microwavezm_mp"
#define MWS_MAX_AMMO            900.0
#define MWS_TICK                0.05
#define MWS_FIRE_WINDOW_MS      100
#define MWS_BEAM_WIDTH          25
#define MWS_HIP_RANGE           650
#define MWS_MAX_RANGE           850
#define MWS_RANGE_UPDATE_MS     500
#define MWS_BEAM_DAMAGE         30
#define MWS_POINTS_INTERVAL_MS  500
#define MWS_BUFF_NAME           "microwaveBuff"
#define MWS_BUFF_STEP           0.05
#define MWS_BUFF_FULL_LEVEL     0.2
#define MWS_BUFF_FIRST_SLOW     0.9
#define MWS_BUFF_SHORT_LIFE     2.0
#define MWS_BUFF_EXPLODE_TIME   2.0
#define MWS_BUFF_FX_SWITCH      0.25
#define MWS_IMPACT_INTERVAL_MS  150
#define MWS_BUBBLE_SOUND        "npc_mwave_flesh_bubble"
#define MWS_POP_SOUND           "npc_mwave_flesh_expl_front"
#define MWS_LOG_FILE            "s1/exo_zombies_support.log"

main()
{
}

init()
{
    if ( getdvar( "g_gametype" ) != "zombies" ||
         isdefined( level.mws_startHooked ) )
    {
        return;
    }

    // Wrap the native hook so this runs right after the map's own weapon init.
    level.mws_previousStartFunc = level.onstartgametypelevelfunc;
    level.onstartgametypelevelfunc = ::mws_start_gametype;
    level.mws_startHooked = true;
}

mws_start_gametype()
{
    if ( isdefined( level.mws_previousStartFunc ) )
    {
        [[ level.mws_previousStartFunc ]]();
    }

    // A separate thread keeps a script error here from stopping game start.
    level thread mws_setup();
}

mws_setup()
{
    setdvarifuninitialized( "scr_zm_microwave_enabled", 1 );

    if ( isdefined( level.mws ) )
    {
        return;
    }

    if ( getdvar( "mapname" ) == "mp_zombie_brg" ||
         ( isdefined( level._effect ) && isdefined( level._effect[ "microwave_buff" ] ) ) )
    {
        mws_log( "the map script already provides the Microwave Gun; support stays off." );
        return;
    }

    if ( getdvarint( "scr_zm_microwave_enabled" ) <= 0 )
    {
        mws_log( "scr_zm_microwave_enabled is 0; support stays off." );
        return;
    }

    if ( !mws_weapon_registered( MWS_GUN_NAME ) )
    {
        mws_log( MWS_GUN_NAME + " is not registered (mods/exo_weapons_all is not loaded); support stays off." );
        return;
    }

    level.mws = spawnstruct();
    level.mws.logged = [];

    // Effects can only be loaded before this thread first waits.
    mws_log( "loading effects" );
    mws_load_effects();
    mws_log( "effects loaded" );

    // Each map owns these hooks; keep whatever is installed and answer only
    // for the Microwave Gun.
    level.mws_previousAmmoLowFunc = level.playerammolowfunc;
    level.playerammolowfunc = ::mws_hook_ammo_low;

    level.mws_previousMaxAmmoFunc = level.activatemaxammofunc;
    level.activatemaxammofunc = ::mws_hook_activate_max_ammo;

    level.mws_previousWeaponLevelFunc = level.setweaponlevelfunc;
    level.setweaponlevelfunc = ::mws_hook_set_weapon_level;

    level.mws_previousScriptedAmmoFunc = level.givemaxscriptedammofunc;
    level.givemaxscriptedammofunc = ::mws_hook_give_max_scripted_ammo;

    level.mws_previousKillPointsFunc = level.givepointsforkillshotfunc;
    level.givepointsforkillshotfunc = ::mws_hook_kill_points;

    level.mws_previousDamagePointsFunc = level.playercanawardpointsfordamagefunc;
    level.playercanawardpointsfordamagefunc = ::mws_hook_damage_points;

    level.mws_previousKilledFxFunc = level.spawnzombiekilledfxfunc;
    level.spawnzombiekilledfxfunc = ::mws_hook_zombie_killed_fx;

    level thread mws_watch_players();
    mws_log( "ready" );
}

// Stock loads these in _zombie_microwave_gun::init, which only Infection runs.
// The handles stay on level.mws: level._effect["microwave_buff"] is how this
// script recognises a map that provides the gun itself.
mws_load_effects()
{
    level.mws.fxBuffLow = loadfx( "vfx/weaponimpact/xombie_flesh_microwave_bubbles_1" );
    level.mws.fxBuffHigh = loadfx( "vfx/weaponimpact/xombie_flesh_microwave_bubbles_2" );
    level.mws.fxBuffHead = loadfx( "vfx/weaponimpact/xombie_flesh_microwave_bubbles_head_2" );
    level.mws.fxBuffShoulderLeft = loadfx( "vfx/weaponimpact/xombie_flesh_microwave_bubbles_le_2" );
    level.mws.fxBuffShoulderRight = loadfx( "vfx/weaponimpact/xombie_flesh_microwave_bubbles_ri_2" );
    level.mws.fxDeath = loadfx( "vfx/blood/dlc_zombie_microwave_death" );
    level.mws.fxFlammable = loadfx( "vfx/weaponimpact/microwave_flammable" );
    level.mws.fxWaterSplash = loadfx( "vfx/weaponimpact/mwave_water_splash" );
}

mws_log( text )
{
    writefile( MWS_LOG_FILE,
        "[microwave] map=" + getdvar( "mapname" ) + " " + text + "\n", 1 );
}

mws_log_once( key, text )
{
    if ( !isdefined( level.mws ) || isdefined( level.mws.logged[ key ] ) )
    {
        return;
    }

    level.mws.logged[ key ] = true;
    mws_log( text );
}

mws_weapon_registered( weaponName )
{
    baseName = getweaponbasename( weaponName );
    return isdefined( baseName ) && baseName == weaponName;
}

mws_is_microwave( weaponName )
{
    return isdefined( weaponName ) && issubstr( weaponName, MWS_GUN_NAME );
}

mws_clamp( value, minValue, maxValue )
{
    if ( value < minValue )
    {
        return minValue;
    }

    if ( value > maxValue )
    {
        return maxValue;
    }

    return value;
}

mws_lerp( fraction, fromValue, toValue )
{
    return fromValue + ( toValue - fromValue ) * fraction;
}

mws_apply_level( data, weaponLevel )
{
    weaponLevel = mws_clamp( weaponLevel, 1, 20 );
    ratio = mws_clamp( ( weaponLevel - 1 ) / 19.0, 0, 1 );
    data.buffLifespan = mws_lerp( ratio, 3.0, 10.0 );
    data.fullySlowed = mws_lerp( ratio, 0.6, 0.4 );
    data.beamWidth = MWS_BEAM_WIDTH;
}

mws_hook_ammo_low( weaponName )
{
    if ( mws_is_microwave( weaponName ) && isdefined( self.pers[ "mws_ammo" ] ) )
    {
        return ( self.pers[ "mws_ammo" ] / MWS_MAX_AMMO ) < 0.05;
    }

    if ( isdefined( level.mws_previousAmmoLowFunc ) )
    {
        return [[ level.mws_previousAmmoLowFunc ]]( weaponName );
    }

    return undefined;
}

mws_hook_activate_max_ammo()
{
    if ( isdefined( level.mws_previousMaxAmmoFunc ) )
    {
        self [[ level.mws_previousMaxAmmoFunc ]]();
    }

    self mws_refill();
}

mws_hook_set_weapon_level( weaponName, weaponLevel )
{
    if ( isdefined( level.mws_previousWeaponLevelFunc ) )
    {
        self [[ level.mws_previousWeaponLevelFunc ]]( weaponName, weaponLevel );
    }

    if ( mws_is_microwave( weaponName ) && isdefined( self.mws_data ) )
    {
        mws_apply_level( self.mws_data, weaponLevel );
        self mws_refill();
    }
}

mws_hook_give_max_scripted_ammo( weaponName )
{
    if ( isdefined( level.mws_previousScriptedAmmoFunc ) )
    {
        self [[ level.mws_previousScriptedAmmoFunc ]]( weaponName );
    }

    if ( mws_is_microwave( weaponName ) )
    {
        self mws_refill();
    }
}

mws_hook_kill_points( defaultEvent, weaponName )
{
    if ( mws_is_microwave( weaponName ) )
    {
        return "kill_head";
    }

    if ( isdefined( level.mws_previousKillPointsFunc ) )
    {
        return [[ level.mws_previousKillPointsFunc ]]( defaultEvent, weaponName );
    }

    return defaultEvent;
}

mws_hook_damage_points( weaponName, victim )
{
    if ( isdefined( level.mws_previousDamagePointsFunc ) &&
         ![[ level.mws_previousDamagePointsFunc ]]( weaponName, victim ) )
    {
        return false;
    }

    // The beam hits every tick; award damage points only twice a second.
    if ( isdefined( victim ) && mws_is_microwave( weaponName ) )
    {
        if ( isdefined( victim.mws_nextPointsTime ) && gettime() < victim.mws_nextPointsTime )
        {
            return false;
        }

        victim.mws_nextPointsTime = gettime() + MWS_POINTS_INTERVAL_MS;
    }

    return true;
}

mws_refill()
{
    if ( !isdefined( self.mws_data ) || !isdefined( self.pers[ "mws_ammo" ] ) )
    {
        return;
    }

    self.pers[ "mws_ammo" ] = MWS_MAX_AMMO;

    if ( self.mws_data.equipped )
    {
        self setclientomnvar( "ui_energy_ammo", 1 );
    }

    self mws_unblock_fire( self.mws_data );
}

mws_block_fire( data )
{
    data.blocked = true;
    self allowfire( 0 );
}

mws_unblock_fire( data )
{
    if ( data.blocked )
    {
        data.blocked = false;
        self allowfire( 1 );
    }
}

mws_watch_players()
{
    level endon( "game_ended" );

    foreach ( player in getentarray( "player", "classname" ) )
    {
        player thread mws_player_loop();
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread mws_player_loop();
    }
}

mws_player_loop()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    if ( isdefined( self.mws_started ) )
    {
        return;
    }

    self.mws_started = true;

    data = spawnstruct();
    data.lastFiredTime = 0;
    data.beamRange = MWS_HIP_RANGE;
    data.nextRangeTime = 0;
    data.nextImpactTime = 0;
    data.equipped = false;
    data.weaponName = "";
    data.blocked = false;
    mws_apply_level( data, 1 );
    self.mws_data = data;

    for ( ;; )
    {
        wait MWS_TICK;
        self mws_tick( data );
    }
}

mws_tick( data )
{
    weapon = self getcurrentweapon();
    holding = mws_is_microwave( weapon );

    // Upgrading swaps in a new weapon name while the gun stays in hand.
    if ( holding && ( !data.equipped || weapon != data.weaponName ) )
    {
        self mws_on_equip( data, weapon );
    }
    else if ( !holding && data.equipped )
    {
        self mws_on_unequip( data );
    }

    if ( !holding )
    {
        return;
    }

    self setclientomnvar( "ui_em1_heat", self getweaponheatlevel( weapon ) );

    if ( gettime() >= data.nextRangeTime )
    {
        data.nextRangeTime = gettime() + MWS_RANGE_UPDATE_MS;
        self mws_update_beam_range( data );
    }

    if ( self attackbuttonpressed() && !self isreloading() && self isfiring() &&
         !self isusingoffhand() && !self ismeleeing() )
    {
        data.lastFiredTime = gettime();
        self mws_spend_ammo( data );
    }

    if ( gettime() - data.lastFiredTime <= MWS_FIRE_WINDOW_MS )
    {
        self mws_cook_enemies( data );
        self mws_impact_fx( data );
    }
}

mws_on_equip( data, weapon )
{
    data.equipped = true;
    data.weaponName = weapon;
    data.nextRangeTime = 0;

    if ( !isdefined( self.pers[ "mws_ammo" ] ) )
    {
        self.pers[ "mws_ammo" ] = MWS_MAX_AMMO;
    }

    self setweaponammostock( weapon, 0 );
    self mws_update_ammo_omnvar();

    if ( self.pers[ "mws_ammo" ] <= 0 )
    {
        self mws_block_fire( data );
    }
}

mws_on_unequip( data )
{
    data.equipped = false;
    data.weaponName = "";
    self mws_unblock_fire( data );

    // An empty battery is forgotten once the gun is gone so a new one starts full.
    if ( isdefined( self.pers[ "mws_ammo" ] ) && self.pers[ "mws_ammo" ] <= 0 &&
         !self mws_has_microwave() && !maps\mp\zombies\_util::isplayerinlaststand( self ) )
    {
        self.pers[ "mws_ammo" ] = undefined;
    }
}

mws_has_microwave()
{
    foreach ( weaponName in self getweaponslistprimaries() )
    {
        if ( mws_is_microwave( weaponName ) )
        {
            return true;
        }
    }

    return false;
}

mws_update_ammo_omnvar()
{
    if ( isdefined( self.pers[ "mws_ammo" ] ) )
    {
        self setclientomnvar( "ui_energy_ammo", self.pers[ "mws_ammo" ] / MWS_MAX_AMMO );
    }
}

mws_unlimited_ammo()
{
    return maps\mp\zombies\_util::gameflagexists( "unlimited_ammo" ) &&
        maps\mp\_utility::gameflag( "unlimited_ammo" );
}

mws_spend_ammo( data )
{
    if ( !isdefined( self.pers[ "mws_ammo" ] ) )
    {
        return;
    }

    ammo = self.pers[ "mws_ammo" ];
    self mws_update_ammo_omnvar();

    if ( ammo <= 0 )
    {
        self mws_switch_away( data );
        return;
    }

    if ( !mws_unlimited_ammo() )
    {
        self.pers[ "mws_ammo" ] = ammo - 1;
    }
}

mws_switch_away( data )
{
    self mws_block_fire( data );

    foreach ( weaponName in self getweaponslistprimaries() )
    {
        if ( !mws_is_microwave( weaponName ) )
        {
            self switchtoweapon( weaponName );
            return;
        }
    }
}

mws_update_beam_range( data )
{
    eye = self geteye();
    forward = anglestoforward( self getangles() );
    trace = bullettrace( eye, eye + forward * MWS_MAX_RANGE, 0, self, 0, 0, 0, 0, 0, 1, 0 );

    if ( trace[ "fraction" ] < 1 )
    {
        data.beamRange = length( trace[ "position" ] - eye );
    }
    else
    {
        data.beamRange = MWS_MAX_RANGE;
    }
}

// Infection's impact table adds flammable surfaces and water to the beam's
// concrete impact; the other maps' tables stop at concrete, so play those two
// here, at most every MWS_IMPACT_INTERVAL_MS while fire is held.
mws_impact_fx( data )
{
    if ( gettime() < data.nextImpactTime )
    {
        return;
    }

    data.nextImpactTime = gettime() + MWS_IMPACT_INTERVAL_MS;

    range = MWS_MAX_RANGE;

    if ( self playerads() < 0.3 )
    {
        range = MWS_HIP_RANGE;
    }

    eye = self geteye();
    forward = anglestoforward( self getangles() );
    trace = bullettrace( eye, eye + forward * range, 0, self, 0, 0, 0, 0, 0, 1, 0 );

    if ( trace[ "fraction" ] >= 1 || !isdefined( trace[ "surfacetype" ] ) )
    {
        return;
    }

    surface = trace[ "surfacetype" ];
    fx = undefined;

    if ( issubstr( surface, "water" ) )
    {
        fx = level.mws.fxWaterSplash;
    }
    else if ( mws_surface_flammable( surface ) )
    {
        fx = level.mws.fxFlammable;
    }

    if ( !isdefined( fx ) )
    {
        return;
    }

    normal = trace[ "normal" ];
    up = ( 0, 0, 1 );

    if ( abs( normal[ 2 ] ) > 0.99 )
    {
        up = ( 1, 0, 0 );
    }

    playfx( fx, trace[ "position" ], normal, up );
    mws_log_once( "impact_" + surface, "beam impact effect on surface " + surface );
}

mws_surface_flammable( surface )
{
    return issubstr( surface, "wood" ) || issubstr( surface, "cloth" ) ||
        issubstr( surface, "carpet" ) || issubstr( surface, "paper" ) ||
        issubstr( surface, "foliage" ) || issubstr( surface, "grass" ) ||
        issubstr( surface, "bark" ) || issubstr( surface, "leaves" );
}

mws_point_distance_to_line_sq( point, lineStart, lineEnd )
{
    lineLengthSq = lengthsquared( lineEnd - lineStart );

    if ( lineLengthSq == 0 )
    {
        return lengthsquared( lineStart - point );
    }

    along = vectordot( point - lineStart, lineEnd - lineStart ) / lineLengthSq;

    if ( along < 0 )
    {
        return lengthsquared( point - lineStart );
    }

    if ( along > 1 )
    {
        return lengthsquared( point - lineEnd );
    }

    return lengthsquared( point - ( lineStart + along * ( lineEnd - lineStart ) ) );
}

mws_cook_enemies( data )
{
    if ( !isdefined( level.agentarray ) )
    {
        return;
    }

    range = data.beamRange;

    if ( self playerads() < 0.3 )
    {
        range = min( range, MWS_HIP_RANGE );
    }

    width = data.beamWidth;
    cullDistanceSq = squared( range + width * 2 );
    widthSq = squared( width );
    eye = self geteye();
    forward = anglestoforward( self getangles() );
    flatForward = forward * ( 1, 1, 0 );
    beamStart = eye + forward * width;
    beamEnd = beamStart + forward * range;
    playerTeam = self.team;

    foreach ( agent in level.agentarray )
    {
        if ( !isdefined( agent ) || !isalive( agent ) )
        {
            continue;
        }

        if ( isdefined( agent.team ) && agent.team == playerTeam )
        {
            continue;
        }

        if ( distancesquared( self.origin, agent.origin ) > cullDistanceSq )
        {
            continue;
        }

        if ( vectordot( ( agent.origin - eye ) * ( 1, 1, 0 ), flatForward ) < 0 )
        {
            continue;
        }

        // Stock tests the eye and the upper spine; approximate the spine from the eye height.
        agentEye = agent geteye();
        torso = agent.origin + ( 0, 0, ( agentEye[ 2 ] - agent.origin[ 2 ] ) * 0.7 );
        eyeDistanceSq = mws_point_distance_to_line_sq( agentEye, beamStart, beamEnd );
        torsoDistanceSq = mws_point_distance_to_line_sq( torso, beamStart, beamEnd );

        if ( min( eyeDistanceSq, torsoDistanceSq ) > widthSq )
        {
            continue;
        }

        self mws_cook_agent( agent );
    }
}

mws_cook_agent( agent )
{
    if ( maps\mp\zombies\_util::isinstakill() )
    {
        earthquake( randomfloatrange( 0.5, 1 ), randomfloatrange( 0.5, 1 ), agent.origin, 128 );
        agent dodamage( agent.maxhealth + 10, agent geteye(), self, undefined, "MOD_EXPLOSIVE", MWS_GUN_NAME, "none" );
        return;
    }

    agent dodamage( MWS_BEAM_DAMAGE, agent geteye(), self, undefined, "MOD_EXPLOSIVE", MWS_GUN_NAME, "none" );

    if ( !isdefined( agent ) || !isalive( agent ) )
    {
        return;
    }

    agent maps\mp\zombies\_zombies::addbuff( MWS_BUFF_NAME, agent mws_get_buff( self ) );
}

mws_get_buff( player )
{
    buff = maps\mp\zombies\_zombies::getbuff( MWS_BUFF_NAME );

    if ( !isdefined( buff ) )
    {
        buff = spawnstruct();
        buff.buffupdate = ::mws_update_buff;
        buff.buffremove = ::mws_remove_buff;
        buff.speedmultiplier = MWS_BUFF_FIRST_SLOW;
        buff.bufflevel = MWS_BUFF_STEP;
        buff.timetoexplode = MWS_BUFF_EXPLODE_TIME;
        self mws_buff_started( buff );
    }
    else
    {
        previousLevel = buff.bufflevel;
        buff.bufflevel = buff.bufflevel + MWS_BUFF_STEP;
        buff.speedmultiplier = mws_buff_speed( buff );
        self mws_buff_raised( buff, previousLevel );
    }

    buff.lifespan = player.mws_data.buffLifespan;
    buff.player = player;
    return buff;
}

mws_buff_speed( buff )
{
    if ( !isdefined( buff.player ) || !isdefined( buff.player.mws_data ) )
    {
        return MWS_BUFF_FIRST_SLOW;
    }

    strength = mws_clamp( buff.bufflevel / MWS_BUFF_FULL_LEVEL, 0, 1 );

    if ( buff.lifespan < MWS_BUFF_SHORT_LIFE )
    {
        strength = mws_clamp( buff.lifespan / MWS_BUFF_SHORT_LIFE, 0, 1 );
    }

    return mws_lerp( strength, MWS_BUFF_FIRST_SLOW, buff.player.mws_data.fullySlowed );
}

mws_update_buff( buff )
{
    buff.speedmultiplier = mws_buff_speed( buff );
}

mws_remove_buff( buff )
{
    buff.speedmultiplier = 1;

    index = mws_buff_fx_index( buff.bufflevel, buff.timetoexplode );
    maps\mp\zombies\_util::stopfxontagnetwork( mws_buff_spine_fx( index ), self, "J_Spine4" );
    self thread mws_bubble_stop();

    if ( index == 0 )
    {
        return;
    }

    maps\mp\zombies\_util::stopfxontagnetwork( level.mws.fxBuffHead, self, "J_head" );

    if ( self mws_buff_has_limbs() )
    {
        maps\mp\zombies\_util::stopfxontagnetwork( level.mws.fxBuffShoulderLeft, self, "J_Shoulder_LE" );
        maps\mp\zombies\_util::stopfxontagnetwork( level.mws.fxBuffShoulderRight, self, "J_Shoulder_RI" );
    }
}

// The flesh effect starts on the spine and, once the cooking has built up,
// moves to the stronger one and adds the head and shoulders (as in stock).
mws_buff_started( buff )
{
    maps\mp\zombies\_util::playfxontagnetwork( level.mws.fxBuffLow, self, "J_Spine4" );
    self mws_bubble_start( mws_clamp( buff.bufflevel / buff.timetoexplode, 0, 1 ) );
    mws_log_once( "buff", "first cooked zombie: flesh effect and bubbling loop started" );
}

mws_buff_raised( buff, previousLevel )
{
    previousIndex = mws_buff_fx_index( previousLevel, buff.timetoexplode );
    index = mws_buff_fx_index( buff.bufflevel, buff.timetoexplode );

    if ( index > previousIndex )
    {
        maps\mp\zombies\_util::stopfxontagnetwork( mws_buff_spine_fx( previousIndex ), self, "J_Spine4" );
        maps\mp\zombies\_util::playfxontagnetwork( mws_buff_spine_fx( index ), self, "J_Spine4" );
        maps\mp\zombies\_util::playfxontagnetwork( level.mws.fxBuffHead, self, "J_head" );

        if ( self mws_buff_has_limbs() )
        {
            maps\mp\zombies\_util::playfxontagnetwork( level.mws.fxBuffShoulderLeft, self, "J_Shoulder_LE" );
            maps\mp\zombies\_util::playfxontagnetwork( level.mws.fxBuffShoulderRight, self, "J_Shoulder_RI" );
        }

        mws_log_once( "buff_high", "cooked zombie reached the stronger flesh effect" );
    }

    self mws_bubble_volume( mws_clamp( buff.bufflevel / buff.timetoexplode, 0, 1 ) );
}

mws_buff_fx_index( buffLevel, timeToExplode )
{
    if ( buffLevel / timeToExplode < MWS_BUFF_FX_SWITCH )
    {
        return 0;
    }

    return 1;
}

mws_buff_spine_fx( index )
{
    if ( index == 0 )
    {
        return level.mws.fxBuffLow;
    }

    return level.mws.fxBuffHigh;
}

// Dogs have no shoulder tags to attach the effect to.
mws_buff_has_limbs()
{
    return !isdefined( self.species ) || self.species != "dog";
}

// The bubbling is one looping sound per zombie. Re-cooking a zombie while the
// previous loop is still fading out takes the loop back instead of letting
// the fade-out delete it.
mws_bubble_start( volume )
{
    self notify( "mws_bubble_restart" );

    if ( !isdefined( self.mws_bubbleSound ) )
    {
        self.mws_bubbleSound = spawn( "script_origin", self.origin );
        self.mws_bubbleSound linkto( self );
        self thread common_scripts\utility::delete_on_death( self.mws_bubbleSound );
    }

    self.mws_bubbleSound playloopsound( MWS_BUBBLE_SOUND );
    self.mws_bubbleSound scalevolume( mws_clamp( volume, 0, 1 ), 0 );
}

mws_bubble_volume( volume )
{
    if ( isdefined( self.mws_bubbleSound ) )
    {
        self.mws_bubbleSound scalevolume( mws_clamp( volume, 0, 1 ), 0 );
    }
}

mws_bubble_stop()
{
    sound = self.mws_bubbleSound;

    if ( !isdefined( sound ) )
    {
        return;
    }

    self endon( "mws_bubble_restart" );
    sound endon( "death" );

    wait 1.3;
    sound scalevolume( 0, 1.0 );
    wait 1.0;
    sound stoploopsound();
    waitframe();
    sound delete();
    self.mws_bubbleSound = undefined;
}

// Infection's map script plays the gib effect when the beam kills a zombie
// (level.spawnzombiekilledfxfunc is the hook it uses); the other maps have no
// such hook, so install one that answers only for the Microwave Gun and
// leaves every other kill to whatever was installed before.
mws_hook_zombie_killed_fx( mod, weapon )
{
    if ( isdefined( level.mws_previousKilledFxFunc ) )
    {
        handled = self [[ level.mws_previousKilledFxFunc ]]( mod, weapon );

        if ( isdefined( handled ) && handled )
        {
            return true;
        }
    }

    if ( !isdefined( mod ) || mod != "MOD_EXPLOSIVE" || !mws_is_microwave( weapon ) )
    {
        return false;
    }

    return self mws_play_death_fx();
}

mws_play_death_fx()
{
    if ( !isdefined( self.body ) )
    {
        return false;
    }

    tag = "J_MainRoot";

    if ( isdefined( level.dismemberment ) && isdefined( level.dismemberment[ "full" ] ) &&
         isdefined( level.dismemberment[ "full" ][ "fxTagName" ] ) )
    {
        tag = level.dismemberment[ "full" ][ "fxTagName" ];
    }

    playfx( level.mws.fxDeath, self.body gettagorigin( tag ) );
    self.body playsound( MWS_POP_SOUND );
    self.body hide();
    self.body hideallparts();
    mws_log_once( "death", "first zombie killed by the beam: gib effect and pop sound played" );
    return true;
}

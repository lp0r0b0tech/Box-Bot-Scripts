/*
    Exo Zombies Line Gun support

    Only Carrier (mp_zombie_ark) ships the script that makes the Line Gun
    work. On every other zombies map the weapon from mods/exo_weapons_all
    fires plain bullets that do 0 damage, so the "wonder weapon" appears
    dead. This script ports the Carrier behaviour: each shot sends a
    400 unit wide line forward at 450 units/s and damages every zombie it
    sweeps through.

    It does nothing when:
        - the map already provides the Line Gun (Carrier),
        - mods/exo_weapons_all is not loaded.

    R41 supplies Carrier's native traveling laser, impact/death effects and
    projectile loop/impact audio. The map's native implementation is retained
    on Carrier.

    Toggles:
        set scr_zm_linegun_enabled 1
        set scr_zm_linegun_damage  1200
*/

#define LGS_GUN_NAME            "iw5_linegunzm_mp"
#define LGS_DAMAGE_WEAPON       "iw5_linegundamagezm_mp"
#define LGS_LASER_FX_PATH       "vfx/muzzleflash/dlc_zombies_linegun_laser"
#define LGS_IMPACT_FX_PATH      "vfx/blood/dlc_zombie_line_gun_gib"
#define LGS_DEATH_FX_PATH       "vfx/muzzleflash/dlc_zombies_drone_death"
#define LGS_MAX_DISTANCE        5000
#define LGS_MOVE_SPEED          450
#define LGS_START_WIDTH         200
#define LGS_BEAM_REUSE_DELAY    1.0
#define LGS_HIT_LOCKOUT_MS      100
#define LGS_DEFAULT_DAMAGE      1200

main()
{
}

init()
{
    if ( getdvar( "g_gametype" ) != "zombies" ||
         isdefined( level.lgs_startHooked ) )
    {
        return;
    }

    // Wrap the native hook so this runs right after the map's own weapon init.
    level.lgs_previousStartFunc = level.onstartgametypelevelfunc;
    level.onstartgametypelevelfunc = ::lgs_start_gametype;
    level.lgs_startHooked = true;
}

lgs_start_gametype()
{
    if ( isdefined( level.lgs_previousStartFunc ) )
    {
        [[ level.lgs_previousStartFunc ]]();
    }

    // A separate thread keeps a script error here from stopping game start.
    level thread lgs_setup();
}

lgs_setup()
{
    setdvarifuninitialized( "scr_zm_linegun_enabled", 1 );
    setdvarifuninitialized( "scr_zm_linegun_damage", LGS_DEFAULT_DAMAGE );

    if ( isdefined( level.linegun ) )
    {
        println( "LineGunSupport: the map script already provides the Line Gun." );
        return;
    }

    if ( getdvarint( "scr_zm_linegun_enabled" ) <= 0 )
    {
        return;
    }

    if ( !lgs_weapon_registered( LGS_GUN_NAME ) ||
         !lgs_weapon_registered( LGS_DAMAGE_WEAPON ) ||
         !lgs_weapon_registered( "iw5_dlcwscamo41_mp" ) )
    {
        println( "LineGunSupport: the R41 native Line Gun effects pack is not loaded; support stays off." );
        return;
    }

    level.lgs = spawnstruct();
    level.lgs.fxReady = false;
    level.lgs.shots = 0;
    level.lgs.hits = 0;

    if ( !isdefined( level.modifyweapondamage ) )
    {
        level.modifyweapondamage = [];
    }

    if ( !isdefined( level.damageweapontoweapon ) )
    {
        level.damageweapontoweapon = [];
    }

    // Another script (all_weapon_damage.gsc) may own this callback; keep it.
    if ( !isdefined( level.modifyweapondamage[ LGS_GUN_NAME ] ) )
    {
        level.modifyweapondamage[ LGS_GUN_NAME ] = ::lgs_modify_damage;
    }

    level.damageweapontoweapon[ LGS_DAMAGE_WEAPON ] = LGS_GUN_NAME;

    level thread lgs_watch_players();
    println( "LineGunSupport: ready." );

    level.lgs.laserFx = loadfx( LGS_LASER_FX_PATH );
    level.lgs.impactFx = loadfx( LGS_IMPACT_FX_PATH );
    level.lgs.deathFx = loadfx( LGS_DEATH_FX_PATH );
    level.lgs.fxReady = true;
}

lgs_weapon_registered( weaponName )
{
    baseName = getweaponbasename( weaponName );
    return isdefined( baseName ) && baseName == weaponName;
}

lgs_damage_amount()
{
    amount = getdvarint( "scr_zm_linegun_damage" );
    if ( amount <= 0 )
    {
        amount = LGS_DEFAULT_DAMAGE;
    }

    return amount;
}

lgs_modify_damage( victim, attacker, damage, meansOfDeath, weaponName, point, direction, hitLoc )
{
    return lgs_damage_amount();
}

lgs_watch_players()
{
    level endon( "game_ended" );

    foreach ( player in getentarray( "player", "classname" ) )
    {
        player thread lgs_player_loop();
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread lgs_player_loop();
    }
}

lgs_player_loop()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    if ( isdefined( self.lgs_started ) )
    {
        return;
    }

    self.lgs_started = true;

    for ( ;; )
    {
        self waittill( "weapon_fired", weaponName );

        if ( !isdefined( weaponName ) ||
             getweaponbasename( weaponName ) != LGS_GUN_NAME )
        {
            continue;
        }

        self thread lgs_fire();
    }
}

lgs_fire()
{
    ads = self playerads();
    angles = self getangles();
    flatAngles = ( angles[0], angles[1], 0 );
    spreadPitch = randomfloatrange( -1.0, 1.0 ) * ( 1.0 - ads );
    spreadYaw = randomfloatrange( -1.0, 1.0 ) * ( 1.0 - ads );
    spreadAngles = flatAngles + ( 3 * spreadPitch, 3 * spreadYaw, 0 );
    forward = anglestoforward( angles );
    spreadForward = anglestoforward( spreadAngles );
    viewOrigin = self getvieworigin();
    startOrigin = viewOrigin + self getvelocity() * 0.05 +
        rotatevector( ( 30, 0, 0 ), flatAngles );
    traceEnd = viewOrigin + spreadForward * LGS_MAX_DISTANCE;
    traceStart = viewOrigin;
    ignoreEnt = self;
    checkGlass = 1;
    skipCount = 0;
    trace = undefined;

    while ( skipCount < 3 )
    {
        trace = bullettrace( traceStart, traceEnd, 0, ignoreEnt, 0, 0, 0, 0, checkGlass, 0, 0 );

        if ( isdefined( trace[ "glass" ] ) )
        {
            checkGlass = 0;
            glassDelay = distance( startOrigin, trace[ "position" ] ) / LGS_MOVE_SPEED;
            thread lgs_touch_glass( trace[ "glass" ], forward, glassDelay );
            continue;
        }

        hitEnt = trace[ "entity" ];
        passThrough = isdefined( hitEnt ) && isdefined( hitEnt.linegunignore ) &&
            hitEnt.linegunignore;

        if ( !passThrough )
        {
            break;
        }

        traceStart = trace[ "position" ];
        ignoreEnt = hitEnt;
        skipCount++;
    }

    if ( trace[ "fraction" ] <= 0 )
    {
        return;
    }

    endOrigin = trace[ "position" ];
    moveTime = distance( viewOrigin, endOrigin ) / LGS_MOVE_SPEED;
    if ( moveTime < 0.05 )
    {
        moveTime = 0.05;
    }

    beam = lgs_get_beam( startOrigin, self.angles );
    beam moveto( endOrigin, moveTime );

    roll = -1 * spreadYaw * 20;
    if ( roll != 0 )
    {
        beam rotatevelocity( ( 0, 0, roll ), moveTime );
    }

    level.lgs.shots++;
    beam thread lgs_damage_update( self );
    beam waittill( "movedone" );
    level thread lgs_release_beam( beam );
}

lgs_touch_glass( glass, direction, delay )
{
    wait delay;

    if ( !isglassdestroyed( glass ) )
    {
        destroyglass( glass, direction );
    }
}

lgs_get_beam( origin, angles )
{
    beam = undefined;

    foreach ( candidate in getentarray( "lgs_beam", "targetname" ) )
    {
        if ( !isdefined( candidate.inuse ) || !candidate.inuse )
        {
            beam = candidate;
            beam dontinterpolate();
            break;
        }
    }

    if ( !isdefined( beam ) )
    {
        beam = spawn( "script_model", origin );
        beam.targetname = "lgs_beam";
    }

    beam setmodel( "tag_origin" );
    beam.origin = origin;
    beam.angles = angles;
    if ( level.lgs.fxReady )
    {
        playfxontag( level.lgs.laserFx, beam, "tag_origin" );
        beam playloopsound( "wpn_linegun_beam_hi" );
    }
    beam.inuse = true;
    return beam;
}

lgs_release_beam( beam )
{
    beam notify( "released" );
    if ( level.lgs.fxReady )
    {
        killfxontag( level.lgs.laserFx, beam, "tag_origin" );
        playfxontag( level.lgs.deathFx, beam, "tag_origin" );
        beam stoploopsound( "wpn_linegun_beam_hi" );
        beam playsound( "wpn_linegun_exp" );
    }
    wait LGS_BEAM_REUSE_DELAY;
    beam.inuse = false;
}

lgs_damage_update( attacker )
{
    self endon( "death" );
    self endon( "released" );

    while ( isdefined( attacker ) )
    {
        right = anglestoright( self.angles );

        lgs_damage_line( self.origin, self.origin + right * LGS_START_WIDTH, attacker );
        lgs_damage_line( self.origin, self.origin - right * LGS_START_WIDTH, attacker );
        wait 0.05;
    }
}

lgs_damage_line( lineStart, lineEnd, attacker )
{
    if ( !isdefined( level.characters ) )
    {
        return;
    }

    lineVector = lineEnd - lineStart;
    lineLengthSq = lengthsquared( lineVector );
    if ( lineLengthSq <= 0 )
    {
        return;
    }

    maxOffset = LGS_MOVE_SPEED / 20;
    maxOffsetSq = maxOffset * maxOffset;
    victims = [];

    foreach ( character in level.characters )
    {
        if ( !isdefined( character ) || !isalive( character ) )
        {
            continue;
        }

        if ( isdefined( character.team ) && character.team == attacker.team )
        {
            continue;
        }

        scale = vectordot( character.origin - lineStart, lineVector ) / lineLengthSq;
        if ( scale < 0.0 || scale > 1.0 )
        {
            continue;
        }

        linePoint = lineStart + lineVector * scale;
        height = 70;
        if ( isdefined( character.dismember_crawl ) && character.dismember_crawl )
        {
            height = 40;
        }

        if ( linePoint[2] < character.origin[2] ||
             linePoint[2] > character.origin[2] + height )
        {
            continue;
        }

        flatPoint = ( character.origin[0], character.origin[1], linePoint[2] );
        if ( distancesquared( linePoint, flatPoint ) > maxOffsetSq )
        {
            continue;
        }

        if ( isdefined( character.lgs_lastHit ) &&
             gettime() - character.lgs_lastHit < LGS_HIT_LOCKOUT_MS )
        {
            continue;
        }

        character.lgs_linePoint = linePoint;
        character.lgs_lineScale = scale;
        victims[ victims.size ] = character;
    }

    if ( victims.size == 0 )
    {
        return;
    }

    wallTrace = bullettrace( lineStart, lineEnd, 0, attacker );
    if ( wallTrace[ "fraction" ] <= 0 )
    {
        return;
    }

    foreach ( victim in victims )
    {
        if ( !isdefined( victim ) || !isalive( victim ) )
        {
            continue;
        }

        if ( victim.lgs_lineScale > wallTrace[ "fraction" ] )
        {
            continue;
        }

        hitPoint = ( victim.origin[0], victim.origin[1], victim.lgs_linePoint[2] );
        hitLoc = lgs_hit_location( victim, hitPoint );

        if ( level.lgs.fxReady )
        {
            playfx( level.lgs.impactFx, hitPoint );
        }

        victim.lgs_lastHit = gettime();
        victim dodamage( lgs_damage_amount(), hitPoint, attacker, attacker,
            "MOD_RIFLE_BULLET", LGS_DAMAGE_WEAPON, hitLoc );
        attacker maps\mp\gametypes\_damagefeedback::updatedamagefeedback( "linegun", victim );
        level.lgs.hits++;
    }
}

lgs_hit_location( victim, hitPoint )
{
    heightHit = hitPoint[2] - victim.origin[2];

    if ( heightHit < 32 )
    {
        locations = [ "right_leg_upper", "left_leg_upper" ];
    }
    else if ( heightHit < 60 )
    {
        locations = [ "left_arm_upper", "right_arm_upper" ];
    }
    else
    {
        locations = [ "head", "neck" ];
    }

    return locations[ randomint( locations.size ) ];
}

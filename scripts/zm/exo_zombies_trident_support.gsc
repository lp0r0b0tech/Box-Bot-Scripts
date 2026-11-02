/*
    Exo Zombies Trident support

    Only Descent (mp_zombie_h2o) ships the script that makes the Trident
    work. On every other zombies map the weapon from mods/exo_weapons_all
    fires a plain missile that does nothing useful, so the "wonder weapon"
    appears dead. This script ports the Descent behaviour: every shot is
    replaced by a fast projectile (1300 units/s for 2.5 s) that damages each
    zombie it passes through (up to 5 in a row), ricochets off walls and
    steers toward the best zombie in sight after every bounce.

    It does nothing when:
        - the map already provides the Trident (Descent),
        - mods/exo_weapons_all is not loaded.

    Trail visual: the pack's vfx/trail/trail_trident effect. The original
    green/purple trail effects and the projectile sounds are not part of the
    pack, so the projectile is silent apart from the weapon's own fire sound.

    Toggles:
        set scr_zm_trident_enabled 1
        set scr_zm_trident_damage  1200
*/

#define TDS_GUN_NAME            "iw5_tridentzm_mp"
#define TDS_TRAIL_FX_PATH       "vfx/trail/trail_trident"
#define TDS_MAX_DISTANCE        5000
#define TDS_MOVE_SPEED          1300
#define TDS_LIFETIME_MS         2500
#define TDS_DEFAULT_DAMAGE      1200
#define TDS_PENETRATE_COUNT     5
#define TDS_SMART_DOT           0.75
#define TDS_SMART_DIST          1500
#define TDS_HIPFIRE_SPREAD      2
#define TDS_IMPULSE_RADIUS      30
#define TDS_IMPULSE_FORCE       10
#define TDS_RELEASE_DELAY       1.0
#define TDS_MAX_TRACE_LOOPS     12

main()
{
}

init()
{
    if ( getdvar( "g_gametype" ) != "zombies" ||
         isdefined( level.tds_startHooked ) )
    {
        return;
    }

    // Wrap the native hook so this runs right after the map's own weapon init.
    level.tds_previousStartFunc = level.onstartgametypelevelfunc;
    level.onstartgametypelevelfunc = ::tds_start_gametype;
    level.tds_startHooked = true;
}

tds_start_gametype()
{
    if ( isdefined( level.tds_previousStartFunc ) )
    {
        [[ level.tds_previousStartFunc ]]();
    }

    // A separate thread keeps a script error here from stopping game start.
    level thread tds_setup();
}

tds_setup()
{
    setdvarifuninitialized( "scr_zm_trident_enabled", 1 );
    setdvarifuninitialized( "scr_zm_trident_damage", TDS_DEFAULT_DAMAGE );

    if ( getdvar( "mapname" ) == "mp_zombie_h2o" || isdefined( level.trident ) )
    {
        println( "TridentSupport: the map script already provides the Trident." );
        return;
    }

    if ( getdvarint( "scr_zm_trident_enabled" ) <= 0 )
    {
        return;
    }

    if ( !tds_weapon_registered( TDS_GUN_NAME ) )
    {
        println( "TridentSupport: Trident weapon is not loaded; support stays off." );
        return;
    }

    level.tds = spawnstruct();
    level.tds.fxReady = false;
    level.tds.shots = 0;
    level.tds.hits = 0;

    if ( !isdefined( level.modifyweapondamage ) )
    {
        level.modifyweapondamage = [];
    }

    if ( !isdefined( level.onzombiespawnfuncs ) )
    {
        level.onzombiespawnfuncs = [];
    }

    // Another script (all_weapon_damage.gsc) may own this callback; keep it.
    if ( !isdefined( level.modifyweapondamage[ TDS_GUN_NAME ] ) )
    {
        level.modifyweapondamage[ TDS_GUN_NAME ] = ::tds_modify_damage;
    }

    // Lets the ricochet aim lead moving zombies.
    level.onzombiespawnfuncs[ level.onzombiespawnfuncs.size ] = ::tds_on_zombie_spawn;

    level thread tds_watch_players();
    println( "TridentSupport: ready." );

    // Last on purpose: a failure only costs the trail visual.
    level.tds.trailFx = loadfx( TDS_TRAIL_FX_PATH );
    level.tds.fxReady = true;
}

tds_weapon_registered( weaponName )
{
    baseName = getweaponbasename( weaponName );
    return isdefined( baseName ) && baseName == weaponName;
}

tds_damage_amount()
{
    amount = getdvarint( "scr_zm_trident_damage" );
    if ( amount <= 0 )
    {
        amount = TDS_DEFAULT_DAMAGE;
    }

    return amount;
}

tds_modify_damage( victim, attacker, damage, meansOfDeath, weaponName, point, direction, hitLoc )
{
    return tds_damage_amount();
}

tds_on_zombie_spawn()
{
    self endon( "death" );

    for ( ;; )
    {
        waittillframeend;
        self.tds_prevOrigin = self.origin;
        wait 0.05;
    }
}

tds_watch_players()
{
    level endon( "game_ended" );

    foreach ( player in getentarray( "player", "classname" ) )
    {
        player thread tds_player_loop();
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread tds_player_loop();
    }
}

tds_player_loop()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    if ( isdefined( self.tds_started ) )
    {
        return;
    }

    self.tds_started = true;

    for ( ;; )
    {
        self waittill( "missile_fire", missile, weaponName );

        if ( !isdefined( weaponName ) ||
             getweaponbasename( weaponName ) != TDS_GUN_NAME )
        {
            continue;
        }

        // The stock missile is replaced by the scripted projectile below.
        if ( isdefined( missile ) )
        {
            missile delete();
        }

        level thread tds_fire( self );
    }
}

tds_fire( attacker )
{
    ads = attacker playerads();
    angles = attacker getangles();
    flatAngles = ( angles[0], angles[1], 0 );
    spreadPitch = randomfloatrange( -1.0, 1.0 ) * ( 1.0 - ads );
    spreadYaw = randomfloatrange( -1.0, 1.0 ) * ( 1.0 - ads );
    direction = anglestoforward( flatAngles +
        ( TDS_HIPFIRE_SPREAD * spreadPitch, TDS_HIPFIRE_SPREAD * spreadYaw, 0 ) );
    viewOrigin = attacker getvieworigin();
    startOrigin = viewOrigin + attacker getvelocity() * 0.05 +
        rotatevector( ( 30, 0, 0 ), flatAngles );
    stepLength = TDS_MOVE_SPEED * 0.05;

    projectile = tds_get_projectile( startOrigin, attacker.angles );
    projectile moveto( viewOrigin + direction * TDS_MAX_DISTANCE,
        TDS_MAX_DISTANCE / TDS_MOVE_SPEED );
    level.tds.shots++;

    traceStart = viewOrigin;
    traceEnd = startOrigin + direction * stepLength;
    ignoreEnt = attacker;
    lastTarget = undefined;
    penetrate = TDS_PENETRATE_COUNT;
    endTime = gettime() + TDS_LIFETIME_MS;

    while ( gettime() < endTime )
    {
        for ( loops = 0; loops < TDS_MAX_TRACE_LOOPS; loops++ )
        {
            trace = bullettrace( traceStart, traceEnd, 1, ignoreEnt, 0, 1, 0, 0, 1, 0, 0 );

            if ( isdefined( trace[ "glass" ] ) )
            {
                if ( !isglassdestroyed( trace[ "glass" ] ) )
                {
                    destroyglass( trace[ "glass" ], direction );
                }

                continue;
            }

            if ( trace[ "fraction" ] >= 1 )
            {
                break;
            }

            normal = trace[ "normal" ];
            hitPos = trace[ "position" ] + normal;
            hitEnt = trace[ "entity" ];
            hitAgent = false;

            if ( isdefined( hitEnt ) )
            {
                tds_damage_entity( attacker, hitEnt, hitPos, trace[ "hitLoc" ] );
                hitAgent = isdefined( hitEnt ) && isagent( hitEnt );
            }

            if ( hitAgent && penetrate > 0 )
            {
                // Keep going through the zombie that was just hit.
                ignoreEnt = hitEnt;
                traceStart = hitPos;
                penetrate--;
                continue;
            }

            if ( !hitAgent )
            {
                penetrate = 0;
            }

            projectile.origin = hitPos;
            direction = tds_reflect( direction, normal );

            target = tds_find_target( attacker, hitPos, direction, lastTarget, ignoreEnt );
            lastTarget = undefined;
            if ( isdefined( target ) )
            {
                direction = target.direction;
                lastTarget = target.entity;
            }

            projectile moveto( projectile.origin + direction * TDS_MAX_DISTANCE,
                TDS_MAX_DISTANCE / TDS_MOVE_SPEED );
            break;
        }

        wait 0.05;

        if ( !isdefined( attacker ) )
        {
            break;
        }

        traceStart = projectile.origin;
        traceEnd = traceStart + direction * stepLength;
    }

    tds_release_projectile( projectile );
}

tds_reflect( direction, normal )
{
    return direction - normal * ( 2.0 * vectordot( normal, direction ) );
}

tds_target_list()
{
    candidates = [];

    if ( isdefined( level.characters ) )
    {
        candidates = level.characters;
    }

    if ( isdefined( level.bossozstage1 ) && isdefined( level.bossozstage1.damagecallback ) )
    {
        candidates[ candidates.size ] = level.bossozstage1;
    }

    if ( isdefined( level.ammodrone ) )
    {
        candidates[ candidates.size ] = level.ammodrone;
    }

    if ( isdefined( level.ammodrone2 ) )
    {
        candidates[ candidates.size ] = level.ammodrone2;
    }

    return candidates;
}

// Returns the best zombie to steer toward after a bounce, or undefined.
tds_find_target( attacker, hitPos, reflected, lastTarget, ignoreEnt )
{
    bestDot = TDS_SMART_DOT;
    best = undefined;

    foreach ( candidate in tds_target_list() )
    {
        if ( !isdefined( candidate ) || isplayer( candidate ) || !isalive( candidate ) )
        {
            continue;
        }

        if ( isdefined( candidate.team ) && candidate.team == attacker.team )
        {
            continue;
        }

        if ( isdefined( lastTarget ) && lastTarget == candidate )
        {
            continue;
        }

        targetPos = candidate.origin + ( 0, 0, 40 );
        if ( isdefined( candidate.agent_type ) && candidate.agent_type == "zombie_dog" )
        {
            targetPos = candidate.origin + ( 0, 0, 15 );
        }
        else if ( isdefined( candidate.dismember_crawl ) && candidate.dismember_crawl )
        {
            targetPos = candidate.origin + ( 0, 0, 5 );
        }

        targetVelocity = ( 0, 0, 0 );
        if ( isdefined( candidate.tds_prevOrigin ) )
        {
            targetVelocity = ( candidate.origin - candidate.tds_prevOrigin ) * 20;
        }

        if ( distance( targetPos, hitPos ) > TDS_SMART_DIST )
        {
            continue;
        }

        aimDirection = tds_intercept_direction( targetPos, targetVelocity, hitPos, TDS_MOVE_SPEED );
        aimDot = vectordot( reflected, aimDirection );
        if ( aimDot <= bestDot )
        {
            continue;
        }

        sightTrace = bullettrace( hitPos, targetPos, 0, ignoreEnt, 0, 0, 0, 0, 0, 0, 0 );
        if ( sightTrace[ "fraction" ] >= 1 ||
             ( isdefined( sightTrace[ "entity" ] ) && sightTrace[ "entity" ] == candidate ) )
        {
            bestDot = aimDot;
            best = spawnstruct();
            best.entity = candidate;
            best.direction = aimDirection;
        }
    }

    return best;
}

tds_intercept_direction( targetPos, targetVelocity, fromPos, speed )
{
    toTarget = vectornormalize( targetPos - fromPos );
    alongSpeed = vectordot( toTarget, targetVelocity );
    sideVelocity = targetVelocity - toTarget * alongSpeed;
    sideSpeed = length( sideVelocity );
    result = sideVelocity;

    if ( sideSpeed <= speed )
    {
        result = toTarget * sqrt( speed * speed - sideSpeed * sideSpeed ) + sideVelocity;
    }

    return vectornormalize( result );
}

tds_damage_entity( attacker, victim, hitPos, hitLoc )
{
    if ( !isalive( victim ) || isplayer( victim ) )
    {
        return;
    }

    if ( !isagent( victim ) )
    {
        victim dodamage( tds_damage_amount(), hitPos, attacker, attacker,
            "MOD_PROJECTILE", TDS_GUN_NAME );
        return;
    }

    if ( !isdefined( hitLoc ) )
    {
        hitLoc = "none";
    }

    victim.ragdollimmediately = 1;
    victim dodamage( tds_damage_amount(), hitPos, attacker, attacker,
        "MOD_PROJECTILE", TDS_GUN_NAME, hitLoc );

    if ( isdefined( victim ) )
    {
        victim.ragdollimmediately = 0;
    }

    level.tds.hits++;
    level thread tds_physics_explosion( hitPos );
}

tds_physics_explosion( position )
{
    wait 0.1;
    physicsexplosionsphere( position, TDS_IMPULSE_RADIUS, 0, TDS_IMPULSE_FORCE, 0 );
}

tds_get_projectile( origin, angles )
{
    projectile = undefined;

    foreach ( candidate in getentarray( "tds_projectile", "targetname" ) )
    {
        if ( !isdefined( candidate.inuse ) || !candidate.inuse )
        {
            projectile = candidate;
            projectile dontinterpolate();
            projectile show();
            break;
        }
    }

    if ( !isdefined( projectile ) )
    {
        projectile = spawn( "script_model", origin );
        projectile.targetname = "tds_projectile";
    }

    projectile setmodel( "tag_origin" );
    projectile setcontents( 0 );
    projectile.origin = origin;
    projectile.angles = angles;
    projectile.inuse = true;

    if ( level.tds.fxReady )
    {
        playfxontag( level.tds.trailFx, projectile, "tag_origin" );
    }

    return projectile;
}

tds_release_projectile( projectile )
{
    projectile setmodel( "tag_origin" );
    projectile notify( "released" );

    if ( level.tds.fxReady )
    {
        stopfxontag( level.tds.trailFx, projectile, "tag_origin" );
    }

    wait TDS_RELEASE_DELAY;
    projectile.inuse = false;
}

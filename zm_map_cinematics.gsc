/*
    Exo Zombies map intro / outro cinematic viewer for S1x

    Place this file at:
        s1/scripts/zm/map_cinematics.gsc

    Purpose:
        - Watch the Exo Zombies map intro and outro cinematics on demand
          from the S1x console while in an Exo Zombies match.
        - Zombies are paused and players are frozen/ignored while a
          cinematic plays, then everything is restored afterwards.

    Console usage (open the console with ~ and type):
        set scr_zm_cine intro              play the intro of the current map
        set scr_zm_cine outro              play the outro of the current map
        set scr_zm_cine outbreak_intro     play a specific map cinematic
        set scr_zm_cine descent_outro      (outbreak / infection / carrier / descent,
                                            or lab / brg / ark / h2o, or dlc1 - dlc4)
        set scr_zm_cine zombies_bg_dlc2_intro   play any bink by its raw name
        set scr_zm_cine stop               stop the cinematic that is playing
        set scr_zm_cine list               print every available cinematic

    Settings:
        set scr_zm_cine_duration 60        seconds before playback auto-stops
        set scr_zm_cine_pause 1            pause zombies / freeze players while watching
        set scr_zm_cine_audio_mix 1        use the game's "bink_mix" sound submix
*/

#define ZMCINE_DEFAULT_DURATION                 60
#define ZMCINE_DEFAULT_PAUSE                    1
#define ZMCINE_DEFAULT_AUDIO_MIX                1
#define ZMCINE_POLL_INTERVAL                    0.1
#define ZMCINE_MIN_DURATION                     1

main()
{
    init();
}

init()
{
    if ( isdefined( level.zmcineInitStarted ) && level.zmcineInitStarted )
    {
        return;
    }

    level.zmcineInitStarted = true;
    level thread zmcineDeferredInit();
}

zmcineDeferredInit()
{
    wait 0.25;

    if ( !zmcineIsZombieContext() )
    {
        return;
    }

    zmcineInitDvars();

    level.zmcine = spawnstruct();
    level.zmcine.playing = false;
    level.zmcine.current = "";
    level.zmcine.paused = false;
    level.zmcine.frozenPlayers = [];
    level.zmcine.usedAudioMix = false;

    level thread zmcineCommandLoop();
    level thread zmcineGameEndedWatcher();

    println( "ZMCinematics: ready. Use 'set scr_zm_cine list' in the console." );
}

zmcineInitDvars()
{
    setdvar( "scr_zm_cine", "" );
    setdvarifuninitialized( "scr_zm_cine_duration", ZMCINE_DEFAULT_DURATION );
    setdvarifuninitialized( "scr_zm_cine_pause", ZMCINE_DEFAULT_PAUSE );
    setdvarifuninitialized( "scr_zm_cine_audio_mix", ZMCINE_DEFAULT_AUDIO_MIX );
}

zmcineCommandLoop()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        command = getdvar( "scr_zm_cine" );

        if ( isdefined( command ) && command != "" )
        {
            setdvar( "scr_zm_cine", "" );
            zmcineHandleCommand( command );
        }

        wait ZMCINE_POLL_INTERVAL;
    }
}

zmcineGameEndedWatcher()
{
    level waittill( "game_ended" );

    // Only stop our own playback so the real end-game outro is not interrupted.
    if ( level.zmcine.playing )
    {
        zmcineStop( false );
    }
}

zmcineHandleCommand( command )
{
    command = toLower( command + "" );

    if ( command == "stop" )
    {
        if ( !level.zmcine.playing )
        {
            zmcineMessage( "No cinematic is playing." );
            return;
        }

        zmcineStop( true );
        return;
    }

    if ( command == "list" || command == "help" )
    {
        zmcinePrintList();
        return;
    }

    cinematic = zmcineResolveName( command );

    if ( !isdefined( cinematic ) )
    {
        zmcineMessage( "Unknown cinematic '" + command + "'. Use 'set scr_zm_cine list'." );
        return;
    }

    zmcinePlay( cinematic );
}

zmcineResolveName( command )
{
    if ( command == "intro" || command == "outro" )
    {
        dlc = zmcineGetMapDlc( getdvar( "mapname" ) );

        if ( dlc == 0 )
        {
            return undefined;
        }

        return zmcineBuildName( dlc, command );
    }

    if ( command == "survival_outro" || command == "coop_outro" )
    {
        return "coop_outro";
    }

    tokens = strtok( command, "_" );

    if ( tokens.size == 2 && ( tokens[1] == "intro" || tokens[1] == "outro" ) )
    {
        dlc = zmcineGetAliasDlc( tokens[0] );

        if ( dlc > 0 )
        {
            return zmcineBuildName( dlc, tokens[1] );
        }
    }

    // Anything else is treated as a raw bink name, e.g. zombies_bg_dlc2_intro.
    if ( tokens.size > 0 )
    {
        return command;
    }

    return undefined;
}

zmcineBuildName( dlc, part )
{
    return "zombies_bg_dlc" + dlc + "_" + part;
}

zmcineGetMapDlc( mapname )
{
    if ( !isdefined( mapname ) )
    {
        return 0;
    }

    switch ( toLower( mapname + "" ) )
    {
        case "mp_zombie_lab":
            return 1;
        case "mp_zombie_brg":
            return 2;
        case "mp_zombie_ark":
            return 3;
        case "mp_zombie_h2o":
            return 4;
    }

    return 0;
}

zmcineGetAliasDlc( alias )
{
    switch ( alias )
    {
        case "outbreak":
        case "lab":
        case "dlc1":
            return 1;
        case "infection":
        case "brg":
        case "dlc2":
            return 2;
        case "carrier":
        case "ark":
        case "dlc3":
            return 3;
        case "descent":
        case "h2o":
        case "dlc4":
            return 4;
    }

    return 0;
}

zmcinePlay( cinematic )
{
    if ( level.zmcine.playing )
    {
        zmcineStop( true );
    }

    level.zmcine.playing = true;
    level.zmcine.current = cinematic;
    level.zmcine.token = zmcineNextToken();

    if ( getdvarint( "scr_zm_cine_pause" ) > 0 )
    {
        zmcineBeginPause();
    }

    if ( getdvarint( "scr_zm_cine_audio_mix" ) > 0 )
    {
        addsoundsubmix( "bink_mix" );
        level.zmcine.usedAudioMix = true;
    }

    playcinematicforall( cinematic, 1 );
    zmcineMessage( "Playing " + cinematic + ". Use 'set scr_zm_cine stop' to stop." );

    level thread zmcineAutoStop( level.zmcine.token );
}

zmcineNextToken()
{
    if ( !isdefined( level.zmcine.tokenCounter ) )
    {
        level.zmcine.tokenCounter = 0;
    }

    level.zmcine.tokenCounter++;
    return level.zmcine.tokenCounter;
}

zmcineAutoStop( token )
{
    level endon( "game_ended" );

    duration = getdvarfloat( "scr_zm_cine_duration" );

    if ( duration < ZMCINE_MIN_DURATION )
    {
        duration = ZMCINE_MIN_DURATION;
    }

    wait duration;

    if ( level.zmcine.playing && level.zmcine.token == token )
    {
        zmcineStop( true );
    }
}

zmcineStop( restore )
{
    if ( !level.zmcine.playing )
    {
        return;
    }

    stopcinematicforall( level.zmcine.current );

    if ( level.zmcine.usedAudioMix )
    {
        clearsoundsubmix( "bink_mix" );
        level.zmcine.usedAudioMix = false;
    }

    if ( restore )
    {
        zmcineEndPause();
    }
    else
    {
        level.zmcine.paused = false;
        level.zmcine.frozenPlayers = [];
    }

    zmcineMessage( "Stopped " + level.zmcine.current + "." );

    level.zmcine.playing = false;
    level.zmcine.current = "";
}

zmcineBeginPause()
{
    level.zmcine.previousGamePaused = level.zombiegamepaused;
    level.zombiegamepaused = 1;
    level.zmcine.paused = true;
    level.zmcine.frozenPlayers = [];

    players = level.players;

    if ( !isdefined( players ) )
    {
        return;
    }

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];

        if ( !isdefined( player ) )
        {
            continue;
        }

        player.zmcinePrevIgnoreMe = player.ignoreme;
        player.zmcinePrevFrozen = player.controlsfrozen;
        player.ignoreme = 1;
        player maps\mp\_utility::freezecontrolswrapper( 1 );

        level.zmcine.frozenPlayers[level.zmcine.frozenPlayers.size] = player;
    }
}

zmcineEndPause()
{
    if ( !level.zmcine.paused )
    {
        return;
    }

    level.zombiegamepaused = level.zmcine.previousGamePaused;
    level.zmcine.previousGamePaused = undefined;
    level.zmcine.paused = false;

    for ( i = 0; i < level.zmcine.frozenPlayers.size; i++ )
    {
        player = level.zmcine.frozenPlayers[i];

        if ( !isdefined( player ) )
        {
            continue;
        }

        player.ignoreme = player.zmcinePrevIgnoreMe;

        if ( isdefined( player.zmcinePrevFrozen ) && player.zmcinePrevFrozen )
        {
            player maps\mp\_utility::freezecontrolswrapper( 1 );
        }
        else
        {
            player maps\mp\_utility::freezecontrolswrapper( 0 );
        }

        player.zmcinePrevIgnoreMe = undefined;
        player.zmcinePrevFrozen = undefined;
    }

    level.zmcine.frozenPlayers = [];
}

zmcinePrintList()
{
    names = [];
    names[names.size] = "intro / outro (current map)";
    names[names.size] = "outbreak_intro   outbreak_outro   (mp_zombie_lab, zombies_bg_dlc1_*)";
    names[names.size] = "infection_intro  infection_outro  (mp_zombie_brg, zombies_bg_dlc2_*)";
    names[names.size] = "carrier_intro    carrier_outro    (mp_zombie_ark, zombies_bg_dlc3_*)";
    names[names.size] = "descent_intro    descent_outro    (mp_zombie_h2o, zombies_bg_dlc4_*)";
    names[names.size] = "survival_outro   (coop_outro)";
    names[names.size] = "stop";

    println( "ZMCinematics: usage 'set scr_zm_cine <name>'. Available names:" );

    for ( i = 0; i < names.size; i++ )
    {
        println( "    " + names[i] );
    }

    zmcineMessage( "Cinematic list printed to the console." );
}

zmcineMessage( text )
{
    println( "ZMCinematics: " + text );

    players = level.players;

    if ( !isdefined( players ) )
    {
        return;
    }

    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[i] ) )
        {
            players[i] iprintln( text );
        }
    }
}

zmcineIsZombieContext()
{
    if ( isdefined( level.zombiemode ) && level.zombiemode )
    {
        return true;
    }

    if ( isdefined( level.zombieMap ) && level.zombieMap )
    {
        return true;
    }

    return zmcineGetMapDlc( getdvar( "mapname" ) ) > 0;
}

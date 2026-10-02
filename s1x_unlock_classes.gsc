/*
    S1x multiplayer custom-class slot unlock.
    Install in <game directory>/s1x/scripts/s1x_unlock_classes.gsc.
    Start a locally hosted MP match, then reopen Create-a-Class.

    Uses S1x's client menu unlock; does not edit rank or saved classes.
    This is not a remote-client unlock or a corrupted-profile repair.
*/

init()
{
    if ( getdvarint( "dedicated" ) != 0 )
    {
        return;
    }

    gametype = getdvar( "g_gametype" );
    if ( gametype == "zombies" || gametype == "survival" || gametype == "horde" ||
         issubstr( getdvar( "mapname" ), "mp_zombie" ) )
    {
        return;
    }

    if ( isdefined( level.s1xClassUnlockStarted ) )
    {
        return;
    }

    level.s1xClassUnlockStarted = true;
    level thread keepClassSlotsUnlocked();
}

keepClassSlotsUnlocked()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        // Reapply if another script resets the client-side unlock setting.
        if ( getdvarint( "cg_unlockall_classes" ) != 1 )
        {
            setdvar( "cg_unlockall_classes", 1 );
        }

        wait 1;
    }
}

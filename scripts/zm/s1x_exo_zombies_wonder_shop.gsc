/*
    Exo Zombies Wonder Shop - S1x (Call of Duty: Advanced Warfare)
    Gametype: Exo Zombies ("zclassic" / "zteam" etc.)

    A self-contained points shop that sells the full base Exo Zombies
    DLC weapon roster, including every true wonder weapon from the DLC
    maps (KL03-Trident, CEL-3 Cauterizer, Magnetron, LZ-52 Limbo), for a
    flat 1000-point cost per weapon.

    Modeled on the Exo Survival Plus gun shop (s1x_exo_survival_plus.gsc):
    same cursor-based menu, but weapons are purchased with zombies score
    (self.score) and handed out through the native zombies weapon-state
    pipeline (maps\mp\zombies\_wall_buys::givezombieweapon) so purchased
    weapons get a proper level-1 weaponstate and can be upgraded at the
    Pack-a-Punch / upgrade station like any wall-buy weapon.

    Controls (anywhere on the map, while alive):
        Hold [AIM] + press [MELEE]  -> open / toggle the wonder shop
        [FIRE]                      -> next weapon
        [AIM]                       -> previous weapon
        [USE]                       -> buy the selected weapon
        [JUMP]                      -> upgrade the selected weapon
        [MELEE]                     -> close the shop

    Dvars:
        ezs_weapon_cost        points cost per shop weapon   (default 1000)
        ezs_shop_enabled       enable the wonder shop          (default 1)
        ezs_include_mp_only    also sell MP-exclusive DLC weapons
                                that have no native zombies ("zm")
                                asset variant                   (default 0)
        ezs_upgrade_cost       points cost per upgrade level   (default 2500)
        ezs_upgrade_max_level  max weaponstate level reachable
                                through the in-shop upgrade      (default 25)

    In-shop upgrade (ezs_upgrade_weapon(), [JUMP]):
    Pressing [JUMP] on an owned weapon spends ezs_upgrade_cost points and
    raises that weapon's weaponstate["level"] by one, using the same
    Mk2-Mk25 damage curve as the native Pack-a-Punch / upgrade station
    (see all_weapon_damage.gsc). Every weapon in the shop -- normal
    roster or MP-only alike -- is then re-given through the exact same
    native getupgradeweaponname()/givezombieweapon() path the physical
    kiosk uses, so it gets the correct Mk2-25 camo + attachment combo for
    its new level: a full visual + functional upgrade without needing to
    find the in-map kiosk. getupgradeweaponname()'s attachment tables are
    only populated for native "zm" weapon bases, but for any other base
    (every MP-only weapon) it transparently falls back to no attachment
    and still builds a valid camo'd name through the same weapon-class-
    agnostic buildweaponname() the multiplayer camo/create-a-class system
    itself uses -- so MP-only weapons get full camo progression too, with
    no separate code path required.

    MP-exclusive weapons (ezs_include_mp_only):
    Every multiplayer weapon that already has a native zombies ("zm")
    variant is sold above through the normal weapon-state pipeline. A
    handful of weapons -- both DLC (STG-44, SVO, AK-47, M16, 1911,
    MP40, M1 Garand, Sten, Lever Action, Repulsor, and the MP-variant
    CEL-3 Cauterizer) and base-game (KF5, EPM3, Exo XMG, MORS, PBW,
    THOR) -- were never ported to Exo Zombies at all: there is no "zm"
    weapon asset anywhere in the game data. Despite that, they are given
    and upgraded through the exact same maps\mp\zombies\_wall_buys::
    givezombieweapon()/getupgradeweaponname() calls used for every other
    weapon in this shop (see ezs_give_weapon()/ezs_upgrade_weapon()
    below) -- that whole pipeline is pure weapon-ID bookkeeping with no
    "zm"-specific asset lookup anywhere in it, so it works identically
    for any weapon string, zm or not. They are still kept in a separate,
    opt-in list because their assets are not part of any Exo Zombies
    map's native precache/preload set (the gametype skips precaching MP
    weapons entirely in zombies): this file registers them with
    precacheitem() itself in main() (see ezs_precache_mp_only_weapons())
    before anything else runs, and additionally streams each one in with
    the built-in loadweapons() (polled, see ezs_wait_load_weapon()) right
    before giving/re-giving it -- the same two-step
    precacheitem()-then-loadweapons() sequence the native horde/gun
    gametypes use for weapons outside their normal preload set. Without
    both steps they can silently fail to give/switch to at all. They
    still carry more risk of client-side issues than the normal roster,
    hence disabled by default. Enable with
    setdvar ezs_include_mp_only 1  only after confirming it is stable
    on your map(s).

    Ownership of MP-only weapons is tracked explicitly per catalog
    weapon ID (self.ezs_mp_owned) rather than by scanning held weapons'
    getweaponbasename() -- several MP-only IDs (the "loot" ones, see
    ezs_build_weapon_list() below) are variant slots of the same base
    DLC weapon and can share a base name, which previously caused false
    "You already have the ..." messages.

    NOTE: scripts/zm/s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc opens on
    the same Hold [AIM] + press [MELEE] gesture. If that file is also
    loaded, set  scr_zm_dlc_shop_enabled 0  (or remove it) to avoid both
    shops trying to open at once.

    Install (s1x):
        Place this file at:
            s1x > data > scripts > zm > s1x_exo_zombies_wonder_shop.gsc
        (next to s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc). The gametype
        guard below also disables the shop automatically if it is ever
        loaded outside Exo Zombies.
*/

main()
{
    println( "[EZS] main loaded." );
    ezs_precache_mp_only_weapons();
    init();
}


/*
    maps\mp\gametypes\_weapons::init() -- which runs for every Exo Zombies
    map just like any other gametype -- only calls precacheitem() on the
    native weapon list when  !level.iszombiegame , i.e. it deliberately
    skips precaching ALL multiplayer weapons in zombies games (relying on
    each zombies map/DLC to separately precache its own "zm" variants
    elsewhere). The 17 MP-only weapons sold below have no "zm" variant and
    are therefore never precached by anything on an Exo Zombies map. A
    giveweapon()/switchtoweapon() call for an unprecached weapon asset
    silently does nothing client-side -- which is exactly what was
    reported ("bought the weapon but got no weapon" / "not giving any of
    the mp weapons").

    Precache must happen before the match's precache window closes, which
    is effectively immediately at map load -- ezs_init() below can't do
    this itself since it deliberately waits/polls for the zombies gametype
    to finish setting up before touching anything, by which point the
    window is long gone. Call this synchronously, unconditionally (so it
    still works even if ezs_include_mp_only is set after this file's
    main() already ran), directly from main() before anything else.
*/
ezs_precache_mp_only_weapons()
{
    precacheitem( "iw5_dlcgun6_mp" );
    precacheitem( "iw5_dlcgun6loot5_mp" );
    precacheitem( "iw5_dlcgun7loot0_mp" );
    precacheitem( "iw5_dlcgun7loot6_mp" );
    precacheitem( "iw5_dlcgun8loot1_mp" );
    precacheitem( "iw5_dlcgun13_mp" );
    precacheitem( "iw5_dlcgun18_mp" );
    precacheitem( "iw5_dlcgun23_mp" );
    precacheitem( "iw5_dlcgun28_mp" );
    precacheitem( "iw5_dlcgun33_mp" );
    precacheitem( "iw5_dlcgun38_mp" );
    precacheitem( "iw5_kf5_mp" );
    precacheitem( "iw5_epm3_mp" );
    precacheitem( "iw5_exoxmg_mp" );
    precacheitem( "iw5_mors_mp" );
    precacheitem( "iw5_pbw_mp" );
    precacheitem( "iw5_thor_mp" );
}


init()
{
    if ( isdefined( level.ezs_started ) )
    {
        return;
    }

    level.ezs_started = 1;
    level thread ezs_init();
}


/*
    Zombies gametype scripts (level.playerteam, level.modifyweapondamage,
    etc.) are not guaranteed to exist yet the instant a loose mod script's
    main()/init() runs. Doing anything substantial synchronously here --
    especially referencing zombies-only code paths like
    maps\mp\zombies\_wall_buys::givezombieweapon -- before that
    initialization finishes can hard-crash the client at map load with no
    console output. Defer and guard exactly like exo_zombies_teambot_max.gsc
    does: wait a tick, bail outside Exo Zombies, then poll for the gametype
    to finish setting up before doing anything else.
*/
ezs_init()
{
    level endon( "game_ended" );

    wait 0.05;

    if ( getdvar( "g_gametype" ) != "zombies" )
    {
        println( "[EZS] Disabled outside Exo Zombies." );
        return;
    }

    for ( var_0 = 0; var_0 < 600; var_0++ )
    {
        if ( isdefined( level.playerteam ) && isdefined( level.enemyteam ) &&
             isdefined( level.modifyweapondamage ) )
        {
            break;
        }

        wait 0.05;
    }

    if ( !isdefined( level.playerteam ) || !isdefined( level.enemyteam ) ||
         !isdefined( level.modifyweapondamage ) )
    {
        println( "[EZS] ERROR: Zombies initialization timed out." );
        return;
    }

    if ( getdvar( "ezs_weapon_cost" ) == "" )
    {
        setdvar( "ezs_weapon_cost", "1000" );
    }

    if ( getdvar( "ezs_shop_enabled" ) == "" )
    {
        setdvar( "ezs_shop_enabled", "1" );
    }

    if ( getdvar( "ezs_include_mp_only" ) == "" )
    {
        setdvar( "ezs_include_mp_only", "0" );
    }

    if ( getdvar( "ezs_upgrade_cost" ) == "" )
    {
        setdvar( "ezs_upgrade_cost", "2500" );
    }

    if ( getdvar( "ezs_upgrade_max_level" ) == "" )
    {
        setdvar( "ezs_upgrade_max_level", "25" );
    }

    ezs_build_weapon_list();

    println( "[EZS] Exo Zombies Wonder Shop initialized on " + getdvar( "mapname" ) );

    if ( getdvarint( "ezs_shop_enabled" ) )
    {
        level thread ezs_on_player_connect();
    }
}


/*
    ============================================================
    Wonder shop weapon list
    ============================================================
    The full base Exo Zombies DLC weapon roster (same roster used
    by the Mk2-Mk25 damage system), with the four true DLC wonder
    weapons (Trident, CEL-3 Cauterizer, Magnetron, Limbo) called
    out up front.
*/
ezs_build_weapon_list()
{
    level.ezs_weapons = [];

    // ---- Wonder weapons ----
    ezs_add_weapon( "iw5_tridentzm_mp", "KL03-Trident" );
    ezs_add_weapon( "iw5_fusionzm_mp", "CEL-3 Cauterizer" );
    ezs_add_weapon( "iw5_microwavezm_mp", "Magnetron" );
    ezs_add_weapon( "iw5_linegunzm_mp", "LZ-52 Limbo" );

    // ---- Base DLC armory ----
    ezs_add_weapon( "iw5_rw1zm_mp", "RW1" );
    ezs_add_weapon( "iw5_vbrzm_mp", "VBR" );
    ezs_add_weapon( "iw5_gm6zm_mp", "GM6" );

    ezs_add_weapon( "iw5_rhinozm_mp", "Rhino" );
    ezs_add_weapon( "iw5_lsatzm_mp", "LSAT" );
    ezs_add_weapon( "iw5_asawzm_mp", "ASAW" );

    ezs_add_weapon( "iw5_ak12zm_mp", "AK12" );
    ezs_add_weapon( "iw5_bal27zm_mp", "BAL-27" );
    ezs_add_weapon( "iw5_himarzm_mp", "Himar" );
    ezs_add_weapon( "iw5_arx160zm_mp", "ARX-160" );
    ezs_add_weapon( "iw5_hbra3zm_mp", "HBRa3" );
    ezs_add_weapon( "iw5_m182sprzm_mp", "M182 SPR" );

    ezs_add_weapon( "iw5_mp11zm_mp", "MP11" );
    ezs_add_weapon( "iw5_asm1zm_mp", "ASM1" );
    ezs_add_weapon( "iw5_sn6zm_mp", "SN6" );
    ezs_add_weapon( "iw5_sac3zm_mp", "SAC3" );
    ezs_add_weapon( "iw5_hmr9zm_mp", "HMR9" );

    ezs_add_weapon( "iw5_maulzm_mp", "Maul" );
    ezs_add_weapon( "iw5_uts19zm_mp", "UTS-19" );

    ezs_add_weapon( "iw5_em1zm_mp", "EM1" );

    ezs_add_weapon( "iw5_titan45zm_mp", "Titan 45" );

    ezs_add_weapon( "iw5_exocrossbowzm_mp", "Exo Crossbow" );
    ezs_add_weapon( "iw5_mahemzm_mp", "MAHEM" );

    ezs_add_weapon( "iw5_dlcgun1zm_mp", "DLC Weapon I" );
    ezs_add_weapon( "iw5_dlcgun2zm_mp", "DLC Weapon II" );
    ezs_add_weapon( "iw5_dlcgun3zm_mp", "DLC Weapon III" );
    ezs_add_weapon( "iw5_dlcgun4zm_mp", "DLC Weapon IV" );

    ezs_add_weapon( "iw5_exominigunzm_mp", "Exo Minigun" );
    ezs_add_weapon( "iw5_blunderbusszm_mp", "Blunderbuss" );

    // ---- MP-only DLC weapons (no native zombies asset) ----
    // Opt-in only: see the file header NOTE above before enabling.
    if ( getdvarint( "ezs_include_mp_only" ) )
    {
        ezs_add_weapon_mp_only( "iw5_dlcgun6_mp", "STG-44 (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun6loot5_mp", "SVO (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun7loot0_mp", "AK-47 (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun7loot6_mp", "M16 (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun8loot1_mp", "CEL-3 Cauterizer (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun13_mp", "1911 (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun18_mp", "MP40 (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun23_mp", "M1 Garand (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun28_mp", "Sten (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun33_mp", "Lever Action (MP)" );
        ezs_add_weapon_mp_only( "iw5_dlcgun38_mp", "Repulsor (MP)" );

        // ---- MP-only base-game weapons (no native zombies asset) ----
        ezs_add_weapon_mp_only( "iw5_kf5_mp", "KF5 (MP)" );
        ezs_add_weapon_mp_only( "iw5_epm3_mp", "EPM3 (MP)" );
        ezs_add_weapon_mp_only( "iw5_exoxmg_mp", "Exo XMG (MP)" );
        ezs_add_weapon_mp_only( "iw5_mors_mp", "MORS (MP)" );
        ezs_add_weapon_mp_only( "iw5_pbw_mp", "PBW (MP)" );
        ezs_add_weapon_mp_only( "iw5_thor_mp", "THOR (MP)" );
    }
}


ezs_add_weapon( var_0, var_1 )
{
    var_2 = spawnstruct();
    var_2.weapon = var_0;
    var_2.display = var_1;
    var_2.mponly = 0;
    level.ezs_weapons[level.ezs_weapons.size] = var_2;
}


ezs_add_weapon_mp_only( var_0, var_1 )
{
    var_2 = spawnstruct();
    var_2.weapon = var_0;
    var_2.display = var_1;
    var_2.mponly = 1;
    level.ezs_weapons[level.ezs_weapons.size] = var_2;
}


/*
    ============================================================
    Wonder shop - per player
    ============================================================
*/
ezs_on_player_connect()
{
    level endon( "game_ended" );

    for (;;)
    {
        level waittill( "connected", var_0 );
        var_0 thread ezs_player_shop_watcher();
    }
}


ezs_player_shop_watcher()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    self.ezs_menu_open = 0;
    self.ezs_index = 0;

    self iprintln( "^2Wonder Shop:^7 hold [{+speed_throw}] and press [{+melee}]" );

    for (;;)
    {
        wait 0.05;

        if ( !isalive( self ) )
        {
            continue;
        }

        if ( isdefined( self.laststand ) && self.laststand )
        {
            continue;
        }

        if ( self adsbuttonpressed() && self meleebuttonpressed() )
        {
            self ezs_open_shop();

            while ( self meleebuttonpressed() || self adsbuttonpressed() )
            {
                wait 0.05;
            }
        }
    }
}


ezs_open_shop()
{
    if ( self.ezs_menu_open )
    {
        return;
    }

    self.ezs_menu_open = 1;
    self freezecontrols( 1 );
    self ezs_create_hud();

    while ( self meleebuttonpressed() || self adsbuttonpressed() || self usebuttonpressed() || self attackbuttonpressed() || self jumpbuttonpressed() )
    {
        wait 0.05;
    }

    self ezs_render_hud();

    var_1 = gettime();

    for (;;)
    {
        wait 0.05;

        if ( !isalive( self ) || isdefined( self.laststand ) && self.laststand )
        {
            break;
        }

        // Safety net: never let the shop (and the frozen controls that
        // come with it) get stuck open indefinitely.
        if ( ( gettime() - var_1 ) >= 60000 )
        {
            self iprintlnbold( "^1Wonder Shop closed (idle timeout)" );
            break;
        }

        if ( self meleebuttonpressed() )
        {
            break;
        }

        if ( self attackbuttonpressed() )
        {
            var_1 = gettime();
            self.ezs_index = ( self.ezs_index + 1 ) % level.ezs_weapons.size;
            self ezs_render_hud();
            self ezs_wait_buttons_released();
            continue;
        }

        if ( self adsbuttonpressed() )
        {
            var_1 = gettime();
            self.ezs_index = ( self.ezs_index - 1 + level.ezs_weapons.size ) % level.ezs_weapons.size;
            self ezs_render_hud();
            self ezs_wait_buttons_released();
            continue;
        }

        if ( self usebuttonpressed() )
        {
            var_1 = gettime();
            var_0 = self ezs_try_buy();
            self ezs_wait_buttons_released();

            if ( var_0 )
            {
                break;
            }

            self ezs_render_hud();
        }

        if ( self jumpbuttonpressed() )
        {
            var_1 = gettime();
            self ezs_upgrade_weapon();
            self ezs_wait_buttons_released();
            self ezs_render_hud();
        }
    }

    self ezs_destroy_hud();
    self freezecontrols( 0 );
    self.ezs_menu_open = 0;
}


ezs_wait_buttons_released()
{
    self endon( "disconnect" );

    while ( self attackbuttonpressed() || self adsbuttonpressed() || self usebuttonpressed() || self jumpbuttonpressed() )
    {
        wait 0.05;
    }
}


ezs_try_buy()
{
    var_0 = level.ezs_weapons[self.ezs_index];
    var_1 = getdvarint( "ezs_weapon_cost" );

    if ( self ezs_owns_weapon( var_0 ) )
    {
        self iprintlnbold( "^1You already have the " + var_0.display );
        return 0;
    }

    if ( !isdefined( self.score ) )
    {
        self.score = 0;
    }

    if ( self.score < var_1 )
    {
        self iprintlnbold( "^1Not enough points (" + var_1 + " needed)" );
        return 0;
    }

    self.score = self.score - var_1;

    self ezs_destroy_hud();
    self freezecontrols( 0 );
    self ezs_give_weapon( var_0 );
    self freezecontrols( 1 );

    self iprintlnbold( "^2Bought " + var_0.display );
    return 1;
}


/*
    Gives the purchased weapon. maps\mp\zombies\_wall_buys::givezombieweapon()
    and everything it calls (createzombieweaponstate(),
    maps\mp\_utility::_giveweapon(), givemaxammo(), switchtoweaponimmediate(),
    the 2-distinct-primaries cap via getweaponslistprimariesminusalts()/
    getcurrentprimaryweapon()) are pure weapon-ID bookkeeping with no "zm"
    asset lookup anywhere -- verified against the decompiled source: none
    of those functions do anything but call the generic engine
    giveweapon()/takeweapon()/weaponstate[] on whatever weapon string is
    passed in. There is nothing "zm"-specific about this pipeline, so
    MP-only weapons (no zm asset, see the file header) are given through
    the exact same call as every other weapon in this shop -- no separate
    giveweapon()/takeweapon()/cap logic needed for them anymore.

    precacheitem() in main() (see ezs_precache_mp_only_weapons()) only
    registers the weapon names as known/valid network configstrings --
    confirmed by decompiled usage, it does NOT stream the actual weapon
    model/viewmodel/sound file data into memory. The real, engine-
    supported way to force-load a weapon's file data at runtime -- used
    throughout the native code (maps\mp\gametypes\horde.gsc,
    maps\mp\gametypes\_horde_util::trygivehordeweapon(),
    maps\mp\gametypes\gun.gsc, maps\mp\gametypes\_playerlogic.gsc) for
    exactly this situation, a weapon that is valid but was not part of
    the player's/gametype's normal preloaded set -- is the built-in
    loadweapons() function, polled in a while loop until it returns true.
    Notably horde.gsc itself calls  self loadweapons( [ ..., "iw5_kf5_mp",
    ..., "iw5_pbw_mp" ] )  for two of this shop's own MP-only weapons,
    confirming those exact assets are loadable this way mid-match outside
    their "home" gametype. Without this step giveweapon()/switchtoweapon()
    can silently do nothing even though the weapon name itself is valid
    and precached -- which matches the continued "still not giving the mp
    weapons" report after precacheitem() alone was added.
*/
ezs_give_weapon( var_0 )
{
    if ( isdefined( var_0.mponly ) && var_0.mponly )
    {
        self ezs_wait_load_weapon( var_0.weapon );
    }

    maps\mp\zombies\_wall_buys::givezombieweapon( self, var_0.weapon, 1, 1 );

    if ( isdefined( var_0.mponly ) && var_0.mponly )
    {
        if ( !isdefined( self.ezs_mp_owned ) )
        {
            self.ezs_mp_owned = [];
        }

        self.ezs_mp_owned[var_0.weapon] = 1;
    }
}


/*
    Polls the built-in loadweapons() until the given weapon's file data
    (model/viewmodel/sounds) is actually streamed in, exactly like the
    native callers above do -- bounded to ~5 seconds (100 frames at a
    nominal 20fps lower bound) so a genuinely missing/invalid asset on a
    particular map can't hang the buy/upgrade action forever.
*/
ezs_wait_load_weapon( var_0 )
{
    self endon( "disconnect" );

    var_1 = 0;

    while ( !self loadweapons( [ var_0 ] ) && var_1 < 100 )
    {
        waitframe();
        var_1++;
    }
}


/*
    Weapon upgrade: spends points to raise the weaponstate level of the
    currently selected (and owned) shop weapon by one, up to
    ezs_upgrade_max_level (25), using the same Mk2-Mk25 damage curve
    all_weapon_damage.gsc already applies.

    Every weapon -- normal roster or MP-only -- is re-given through the
    exact same native getupgradeweaponname()/givezombieweapon() path the
    physical Pack-a-Punch kiosk itself uses. getupgradeweaponname() is
    fully generic: its attachment-per-level switch tables only have
    cases for native "zm" weapon bases, but for any base not listed
    (every MP-only weapon) getmagicboxweapondefaultattachment() simply
    falls back to "none" and buildweaponname() -- the same weapon-class-
    agnostic builder the multiplayer camo/create-a-class system uses --
    still builds and the resulting name is still given through
    givezombieweapon(), which (see ezs_give_weapon() above) is itself
    pure weapon-ID bookkeeping with no "zm"-specific logic. So MP-only
    weapons get their Mk2-25 camo progression here exactly like every
    other weapon, with no separate code path needed.

    NOTE: the "upgraded" toast deliberately does NOT include the new
    level number. iprintlnbold()/iprintln() share the exact same
    engine configstring table settext() does (confirmed via the
    G_FindConfigstringIndex: overflow error, which is raised by both);
    baking var_5 (the new level, 1-25) into that toast text means up
    to 25 distinct strings PER weapon -- up to 1250 across the full
    50-weapon roster -- which was by far the single largest remaining
    contributor to that table filling up over a long play session
    (confirmed by a user screenshot showing the overflow triggered by
    "< HMR9 >", i.e. a plain weapon-name string, meaning the table was
    already saturated by something else before that bounded, ~70-string
    total from every weapon's shop-menu display name was even fully
    used). The live level is already shown continuously on the HUD via
    ezs_hud_level setvalue() (see ezs_render_hud()), so dropping it from
    the one-shot toast loses no information the player can't already see.
*/
ezs_upgrade_weapon()
{
    var_0 = level.ezs_weapons[self.ezs_index];

    if ( !self ezs_owns_weapon( var_0 ) )
    {
        self iprintlnbold( "^1Buy the " + var_0.display + " first" );
        return 0;
    }

    var_1 = getweaponbasename( var_0.weapon );
    var_2 = getdvarint( "ezs_upgrade_cost" );
    var_3 = getdvarint( "ezs_upgrade_max_level" );

    if ( !isdefined( self.weaponstate[var_1] ) ||
         !isdefined( self.weaponstate[var_1]["level"] ) )
    {
        self.weaponstate[var_1]["level"] = 1;
    }

    var_4 = self.weaponstate[var_1]["level"];

    if ( var_4 >= var_3 )
    {
        self iprintlnbold( "^1" + var_0.display + " is already max level (" + var_3 + ")" );
        return 0;
    }

    if ( !isdefined( self.score ) )
    {
        self.score = 0;
    }

    if ( self.score < var_2 )
    {
        self iprintlnbold( "^1Not enough points (" + var_2 + " needed to upgrade)" );
        return 0;
    }

    self.score = self.score - var_2;
    var_5 = var_4 + 1;

    var_6 = self ezs_find_owned_weapon( var_1 );

    if ( isdefined( var_6 ) )
    {
        self takeweapon( var_6 );
    }

    self.weaponstate[var_1]["level"] = var_5;

    if ( isdefined( level.camolevel ) )
    {
        var_7 = maps\mp\zombies\_wall_buys::getupgradeweaponname( self, var_1 );

        if ( isdefined( var_0.mponly ) && var_0.mponly )
        {
            self ezs_wait_load_weapon( var_7 );
        }

        maps\mp\zombies\_wall_buys::givezombieweapon( self, var_7, 0, 1 );
    }
    else
    {
        if ( isdefined( var_0.mponly ) && var_0.mponly )
        {
            self ezs_wait_load_weapon( var_0.weapon );
        }

        maps\mp\zombies\_wall_buys::givezombieweapon( self, var_0.weapon, 0, 1 );
    }

    self iprintlnbold( "^2" + var_0.display + " upgraded!" );
    return 1;
}


/*
    Returns the exact weapon name currently owned by the player whose
    base name matches weaponBaseName (e.g. a scoped/akimbo variant such
    as "iw5_gm6zm_mp_gm6scope"), or undefined if not owned.
*/
ezs_find_owned_weapon( var_0 )
{
    var_1 = self getweaponslistprimaries();

    foreach ( var_3 in var_1 )
    {
        if ( getweaponbasename( var_3 ) == var_0 )
        {
            return var_3;
        }
    }

    return undefined;
}


/*
    Takes the catalog entry (not just the weapon string) so it can branch
    on var_0.mponly. MP-only weapon IDs are not guaranteed to have unique
    getweaponbasename() results -- several of them (see the "loot" naming
    note on ezs_build_weapon_list() above) are variant slots of the same
    base DLC weapon, so scanning getweaponslistprimaries() by base name
    can match the wrong catalog entry and falsely report "already own".
    Ownership of MP-only weapons is instead tracked explicitly per
    catalog weapon ID in self.ezs_mp_owned, set the moment the shop hands
    one out (see ezs_give_weapon()), which has no such ambiguity.
*/
ezs_owns_weapon( var_0 )
{
    if ( isdefined( var_0.mponly ) && var_0.mponly )
    {
        return isdefined( self.ezs_mp_owned ) && isdefined( self.ezs_mp_owned[var_0.weapon] );
    }

    var_1 = getweaponbasename( var_0.weapon );
    var_2 = self getweaponslistprimaries();

    foreach ( var_4 in var_2 )
    {
        if ( getweaponbasename( var_4 ) == var_1 )
        {
            return 1;
        }
    }

    return 0;
}


ezs_create_hud()
{
    if ( isdefined( self.ezs_hud_title ) )
    {
        return;
    }

    self.ezs_hud_title = newclienthudelem( self );
    self.ezs_hud_title.alignx = "center";
    self.ezs_hud_title.aligny = "middle";
    self.ezs_hud_title.horzalign = "center";
    self.ezs_hud_title.vertalign = "middle";
    self.ezs_hud_title.y = -60;
    self.ezs_hud_title.fontscale = 1.6;
    self.ezs_hud_title.color = ( 0.2, 1.0, 0.2 );
    self.ezs_hud_title.alpha = 1;
    self.ezs_hud_title.sort = 20;
    self.ezs_hud_title settext( "WONDER SHOP" );

    self.ezs_hud_item = newclienthudelem( self );
    self.ezs_hud_item.alignx = "center";
    self.ezs_hud_item.aligny = "middle";
    self.ezs_hud_item.horzalign = "center";
    self.ezs_hud_item.vertalign = "middle";
    self.ezs_hud_item.y = -35;
    self.ezs_hud_item.fontscale = 1.4;
    self.ezs_hud_item.alpha = 1;
    self.ezs_hud_item.sort = 20;

    // Every number on this HUD changes constantly (score every zombie
    // kill, the weapon slot index on every scroll, the weapon level on
    // every upgrade), so NONE of them may ever be baked into a settext()
    // string: settext() interns each unique string into the engine's
    // shared configstring table (shared across every hud/script in the
    // session, hard-capped around 650 entries), and an always-changing
    // number means an always-new string, which eventually overflows
    // that table and kicks the player with a
    // "G_FindConfigstringIndex: overflow" error -- this previously
    // happened to the score/points field, and (because the fix for that
    // only addressed the points number) it also happened again from the
    // weapon slot index ("Cost: 1000   (34/50)" in the error) and would
    // eventually happen from the weapon level too. setvalue() updates a
    // numeric field on the hud elem directly with no configstring cost,
    // same as native score/ammo/kill-counter huds, and (per the native
    // _zombies_sidequests.gsc live-counter pattern) can be combined with
    // a settext() label set once up front, so every label below is set
    // once here and only the matching number is refreshed with
    // setvalue() in ezs_render_hud().
    self.ezs_hud_cost = newclienthudelem( self );
    self.ezs_hud_cost.alignx = "center";
    self.ezs_hud_cost.aligny = "middle";
    self.ezs_hud_cost.horzalign = "center";
    self.ezs_hud_cost.vertalign = "middle";
    self.ezs_hud_cost.y = -15;
    self.ezs_hud_cost.fontscale = 1.0;
    self.ezs_hud_cost.alpha = 1;
    self.ezs_hud_cost.sort = 20;
    self.ezs_hud_cost settext( "Cost: " );

    self.ezs_hud_slot = newclienthudelem( self );
    self.ezs_hud_slot.alignx = "right";
    self.ezs_hud_slot.aligny = "middle";
    self.ezs_hud_slot.horzalign = "center";
    self.ezs_hud_slot.vertalign = "middle";
    self.ezs_hud_slot.x = -5;
    self.ezs_hud_slot.y = 2;
    self.ezs_hud_slot.fontscale = 1.0;
    self.ezs_hud_slot.alpha = 1;
    self.ezs_hud_slot.sort = 20;
    self.ezs_hud_slot settext( "Weapon " );

    // Static suffix: the weapon count never changes once the shop is
    // built, so a single settext() call here is safe (same string every
    // time, no configstring growth) -- it is only the current index
    // (ezs_hud_slot, above) that changes per render.
    self.ezs_hud_slot_total = newclienthudelem( self );
    self.ezs_hud_slot_total.alignx = "left";
    self.ezs_hud_slot_total.aligny = "middle";
    self.ezs_hud_slot_total.horzalign = "center";
    self.ezs_hud_slot_total.vertalign = "middle";
    self.ezs_hud_slot_total.x = 5;
    self.ezs_hud_slot_total.y = 2;
    self.ezs_hud_slot_total.fontscale = 1.0;
    self.ezs_hud_slot_total.alpha = 1;
    self.ezs_hud_slot_total.sort = 20;
    self.ezs_hud_slot_total settext( " / " + level.ezs_weapons.size );

    self.ezs_hud_level = newclienthudelem( self );
    self.ezs_hud_level.alignx = "right";
    self.ezs_hud_level.aligny = "middle";
    self.ezs_hud_level.horzalign = "center";
    self.ezs_hud_level.vertalign = "middle";
    self.ezs_hud_level.x = -5;
    self.ezs_hud_level.y = 19;
    self.ezs_hud_level.fontscale = 1.0;
    self.ezs_hud_level.alpha = 0;
    self.ezs_hud_level.sort = 20;
    self.ezs_hud_level settext( "Level: " );

    // Static suffix: the max upgrade level never changes once the shop
    // is built, so a single settext() call here is safe.
    self.ezs_hud_level_max = newclienthudelem( self );
    self.ezs_hud_level_max.alignx = "left";
    self.ezs_hud_level_max.aligny = "middle";
    self.ezs_hud_level_max.horzalign = "center";
    self.ezs_hud_level_max.vertalign = "middle";
    self.ezs_hud_level_max.x = 5;
    self.ezs_hud_level_max.y = 19;
    self.ezs_hud_level_max.fontscale = 1.0;
    self.ezs_hud_level_max.alpha = 0;
    self.ezs_hud_level_max.sort = 20;
    self.ezs_hud_level_max settext( " / " + getdvarint( "ezs_upgrade_max_level" ) );

    self.ezs_hud_points = newclienthudelem( self );
    self.ezs_hud_points.alignx = "center";
    self.ezs_hud_points.aligny = "middle";
    self.ezs_hud_points.horzalign = "center";
    self.ezs_hud_points.vertalign = "middle";
    self.ezs_hud_points.y = 36;
    self.ezs_hud_points.fontscale = 1.0;
    self.ezs_hud_points.alpha = 1;
    self.ezs_hud_points.sort = 20;
    self.ezs_hud_points settext( "Your points: " );

    self.ezs_hud_help = newclienthudelem( self );
    self.ezs_hud_help.alignx = "center";
    self.ezs_hud_help.aligny = "middle";
    self.ezs_hud_help.horzalign = "center";
    self.ezs_hud_help.vertalign = "middle";
    self.ezs_hud_help.y = 56;
    self.ezs_hud_help.fontscale = 0.9;
    self.ezs_hud_help.alpha = 0.8;
    self.ezs_hud_help.sort = 20;
    self.ezs_hud_help settext( "[FIRE] next  [AIM] prev  [USE] buy  [JUMP] upgrade  [MELEE] close" );
}


ezs_render_hud()
{
    if ( !isdefined( self.ezs_hud_item ) )
    {
        return;
    }

    var_0 = level.ezs_weapons[self.ezs_index];
    var_1 = getdvarint( "ezs_weapon_cost" );
    var_2 = 0;

    if ( isdefined( self.score ) )
    {
        var_2 = self.score;
    }

    self.ezs_hud_item settext( "< " + var_0.display + " >" );

    var_5 = 0;
    var_6 = 0;

    if ( self ezs_owns_weapon( var_0 ) )
    {
        var_4 = getweaponbasename( var_0.weapon );

        if ( isdefined( self.weaponstate[var_4] ) &&
             isdefined( self.weaponstate[var_4]["level"] ) )
        {
            var_5 = 1;
            var_6 = self.weaponstate[var_4]["level"];
        }
    }

    self.ezs_hud_cost setvalue( var_1 );
    self.ezs_hud_slot setvalue( self.ezs_index + 1 );
    self.ezs_hud_level.alpha = var_5;
    self.ezs_hud_level_max.alpha = var_5;
    self.ezs_hud_level setvalue( var_6 );
    self.ezs_hud_points setvalue( var_2 );
}


ezs_destroy_hud()
{
    if ( isdefined( self.ezs_hud_title ) )
    {
        self.ezs_hud_title destroy();
        self.ezs_hud_title = undefined;
    }

    if ( isdefined( self.ezs_hud_item ) )
    {
        self.ezs_hud_item destroy();
        self.ezs_hud_item = undefined;
    }

    if ( isdefined( self.ezs_hud_cost ) )
    {
        self.ezs_hud_cost destroy();
        self.ezs_hud_cost = undefined;
    }

    if ( isdefined( self.ezs_hud_slot ) )
    {
        self.ezs_hud_slot destroy();
        self.ezs_hud_slot = undefined;
    }

    if ( isdefined( self.ezs_hud_slot_total ) )
    {
        self.ezs_hud_slot_total destroy();
        self.ezs_hud_slot_total = undefined;
    }

    if ( isdefined( self.ezs_hud_level ) )
    {
        self.ezs_hud_level destroy();
        self.ezs_hud_level = undefined;
    }

    if ( isdefined( self.ezs_hud_level_max ) )
    {
        self.ezs_hud_level_max destroy();
        self.ezs_hud_level_max = undefined;
    }

    if ( isdefined( self.ezs_hud_points ) )
    {
        self.ezs_hud_points destroy();
        self.ezs_hud_points = undefined;
    }

    if ( isdefined( self.ezs_hud_help ) )
    {
        self.ezs_hud_help destroy();
        self.ezs_hud_help = undefined;
    }
}

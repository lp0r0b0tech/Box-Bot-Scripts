/*
    Exo Zombies Wonder Shop - S1x (Call of Duty: Advanced Warfare)
    Gametype: Exo Zombies ("zclassic" / "zteam" etc.)

    A self-contained points shop that sells the 4 true wonder weapons from
    the Exo Zombies DLC maps (KL03-Trident, CEL-3 Cauterizer, Magnetron,
    LZ-52 Limbo), for a flat 1000-point cost per weapon.

    Modeled on the Exo Survival Plus gun shop (s1x_exo_survival_plus.gsc):
    same cursor-based menu, but weapons are purchased with zombies score
    (self.score) and handed out through the native zombies weapon-state
    pipeline (maps\mp\zombies\_wall_buys::givezombieweapon) so purchased
    weapons get a proper level-1 weaponstate and can still be upgraded at
    the physical Pack-a-Punch / upgrade station like any wall-buy weapon.

    Controls (anywhere on the map, while alive):
        Hold [AIM] + press [MELEE]  -> open / toggle the wonder shop
        [FIRE]                      -> next weapon
        [AIM]                       -> previous weapon
        [USE]                       -> buy the selected weapon
        [MELEE]                     -> close the shop

    Dvars:
        ezs_weapon_cost        points cost per shop weapon   (default 1000)
        ezs_shop_enabled       enable the wonder shop          (default 1)

    NOTE: The in-shop upgrade feature (ezs_upgrade_weapon(), [JUMP]) has
    been removed. Weapons purchased here can still be upgraded the normal
    way, at a physical Pack-a-Punch / upgrade station in the map.

    NOTE: This shop only sells the 4 wonder weapons -- every weapon here
    has a native zombies ("zm") asset variant. The rest of the base Exo
    Zombies DLC armory (RW1, VBR, GM6, Rhino, LSAT, ASAW, AK12, BAL-27,
    Himar, ARX-160, HBRa3, M182 SPR, MP11, ASM1, SN6, SAC3, HMR9, Maul,
    UTS-19, EM1, Titan 45, Exo Crossbow, MAHEM, the 4 DLC weapons, Exo
    Minigun, Blunderbuss) has been removed from this shop's roster per
    user request. MP-only weapons (multiplayer weapons with no "zm"
    variant, e.g. PBW, THOR, the MP-exclusive DLC guns) were previously
    offered behind an opt-in
    ezs_include_mp_only dvar, but their assets are not reliably part of
    every Exo Zombies map's loaded zone -- on maps where they are
    missing, loadweapons() times out and the purchase/upgrade has to be
    refunded (see the "EZS: failed to give" server log pattern from
    earlier revisions of this file). That entire MP-only weapon catalog,
    its precache step, and its give/upgrade/ownership special-casing
    have been removed from this file: this shop now only ever sells
    weapons guaranteed to work on any Exo Zombies map. Adding any of
    those weapons back requires getting their assets linked into the
    target map's zone file (a map-build/linker step outside this
    script), not a script change here.

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
    init();
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
}


ezs_add_weapon( var_0, var_1 )
{
    var_2 = spawnstruct();
    var_2.weapon = var_0;
    var_2.display = var_1;
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

    while ( self meleebuttonpressed() || self adsbuttonpressed() || self usebuttonpressed() || self attackbuttonpressed() )
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
    }

    self ezs_destroy_hud();
    self freezecontrols( 0 );
    self.ezs_menu_open = 0;
}


ezs_wait_buttons_released()
{
    self endon( "disconnect" );

    while ( self attackbuttonpressed() || self adsbuttonpressed() || self usebuttonpressed() )
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
    passed in. Every weapon sold by this shop has a native "zm" zombies
    asset variant (see ezs_build_weapon_list()), so a plain
    givezombieweapon() call is always sufficient here -- no precache or
    loadweapons() streaming step is needed.
*/
ezs_give_weapon( var_0 )
{
    maps\mp\zombies\_wall_buys::givezombieweapon( self, var_0.weapon, 1, 1 );
}


ezs_owns_weapon( var_0 )
{
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
    self.ezs_hud_help settext( "[FIRE] next  [AIM] prev  [USE] buy  [MELEE] close" );
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

    self.ezs_hud_cost setvalue( var_1 );
    self.ezs_hud_slot setvalue( self.ezs_index + 1 );
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

/*
    Exo Survival Plus — S1x (Call of Duty: Advanced Warfare)
    Gametype: "horde" (Exo Survival)

    Features:

    1) Gun Shop
        Adds every base-game weapon that is missing from the native armory
        plus every base DLC weapon (AE4, Ohm, M1 Irons, Blunderbuss, STG-44,
        SVO, AK-47, M16, CEL-3 Cauterizer, 1911, MP40, M1 Garand, Sten,
        Lever Action, Repulsor) to a purchasable in-game shop.

        Weapons are bought with the normal Exo Survival armory points and
        are given through the native horde weapon pipeline
        (maps\mp\gametypes\_horde_util::trygivehordeweapon), so camo /
        weapon proficiency / class-slot bookkeeping all behave natively.

        Controls (anywhere on the map, while alive):
            Hold [AIM] + press [MELEE]  -> open / toggle the gun shop
            [FIRE]                      -> next weapon
            [AIM]                       -> previous weapon
            [USE]                       -> buy the selected weapon
            [MELEE]                     -> close the shop

    1b) Alt-fire mode toggle
        Natively, weapons with a secondary firing mode (e.g. the Ohm's
        shotgun mode) are swapped with Action Slot 3 ("altMode"), which
        the base game binds at spawn. That bind isn't reachable on every
        client/control scheme, so as a reliable fallback this script also
        lets players double-tap [MELEE] to swap the current weapon for
        its alt-mode pair (maps\mp\gametypes\_weapons::weaponaltweaponname),
        e.g. toggling the Ohm between LMG and shotgun mode. The gun shop
        still closes on a single melee press; double-tapping only swaps
        weapon mode while the shop is closed.

    2) DLC map support
        Makes all 16 DLC multiplayer maps (Havoc, Ascendance, Supremacy,
        Reckoning) playable in Exo Survival. On maps that are missing the
        native Exo Survival map data this script:
            - spawns a working weapon armory and exo armory kiosk near the
              player spawns (full native buy menus),
            - injects collect ("horde_collect"), defend ("horde_defend")
              and support-drop ("horde_drop") locations generated from the
              map's TDM spawn points,
            - limits objective rounds to Defend / Collect / Intel when the
              map has no defuse-bomb or uplink entities, so no objective
              round can fail from missing map data.

    Dvars:
        esp_gun_cost          armory point cost per shop weapon  (default 3)
        esp_shop_enabled      enable the custom gun shop         (default 1)
        esp_dlc_maps_enabled  enable the DLC map support         (default 1)
        esp_dlc_rotation      1 = write a map rotation with all base + DLC
                              maps in gametype horde             (default 0)
        esp_altmode_toggle_enabled
                              enable the double-tap [MELEE] alt-mode
                              toggle fallback (Ohm, etc.)        (default 1)

    Install (s1x):
        Place this file in  %localappdata%\Plutonium-style s1x scripts dir:
        s1x > data > scripts  (loaded as a loose GSC by s1x)
*/

main()
{
    esp_init();
}


init()
{
    esp_init();
}


esp_init()
{
    if ( isdefined( level.esp_started ) )
    {
        return;
    }

    level.esp_started = 1;

    if ( getdvar( "g_gametype" ) != "horde" )
    {
        return;
    }

    if ( getdvar( "esp_gun_cost" ) == "" )
    {
        setdvar( "esp_gun_cost", "3" );
    }

    if ( getdvar( "esp_shop_enabled" ) == "" )
    {
        setdvar( "esp_shop_enabled", "1" );
    }

    if ( getdvar( "esp_dlc_maps_enabled" ) == "" )
    {
        setdvar( "esp_dlc_maps_enabled", "1" );
    }

    if ( getdvar( "esp_dlc_rotation" ) == "" )
    {
        setdvar( "esp_dlc_rotation", "0" );
    }

    if ( getdvar( "esp_altmode_toggle_enabled" ) == "" )
    {
        setdvar( "esp_altmode_toggle_enabled", "1" );
    }

    esp_build_weapon_list();

    println( "[ESP] Exo Survival Plus initialized on " + getdvar( "mapname" ) );

    if ( getdvarint( "esp_dlc_maps_enabled" ) )
    {
        level thread esp_dlc_map_support();
    }

    if ( getdvarint( "esp_dlc_rotation" ) )
    {
        esp_set_dlc_rotation();
    }

    if ( getdvarint( "esp_shop_enabled" ) || getdvarint( "esp_altmode_toggle_enabled" ) )
    {
        level thread esp_on_player_connect();
    }
}


/*
    ============================================================
    Gun shop weapon list
    ============================================================
    Base weapons missing from the native armory, then every
    base DLC weapon by its GSC name. Base versions only — no
    loot / royalty variants. Note: the internal names of the
    SVO, AK-47, M16 and CEL-3 contain "loot" because Sledgehammer
    packed those base guns into leftover variant slots of
    dlcgun6/7/8; they are the true base weapons per the game's
    unlock table (type "weapon", not "loot").
*/
esp_build_weapon_list()
{
    level.esp_weapons = [];

    esp_add_weapon( "iw5_exocrossbow_mp", "Crossbow" );
    esp_add_weapon( "iw5_combatknife_mp", "Combat Knife" );
    esp_add_weapon( "iw5_riotshieldt6_mp", "Riot Shield" );

    esp_add_weapon( "iw5_dlcgun1_mp", "AE4" );
    esp_add_weapon( "iw5_dlcgun2_mp", "Ohm" );
    esp_add_weapon( "iw5_dlcgun3_mp", "M1 Irons" );
    esp_add_weapon( "iw5_dlcgun4_mp", "Blunderbuss" );
    esp_add_weapon( "iw5_dlcgun6_mp", "STG-44" );
    esp_add_weapon( "iw5_dlcgun6loot5_mp", "SVO" );
    esp_add_weapon( "iw5_dlcgun7loot0_mp", "AK-47" );
    esp_add_weapon( "iw5_dlcgun7loot6_mp", "M16" );
    esp_add_weapon( "iw5_dlcgun8loot1_mp", "CEL-3 Cauterizer" );
    esp_add_weapon( "iw5_dlcgun13_mp", "1911" );
    esp_add_weapon( "iw5_dlcgun18_mp", "MP40" );
    esp_add_weapon( "iw5_dlcgun23_mp", "M1 Garand" );
    esp_add_weapon( "iw5_dlcgun28_mp", "Sten" );
    esp_add_weapon( "iw5_dlcgun33_mp", "Lever Action" );
    esp_add_weapon( "iw5_dlcgun38_mp", "Repulsor" );
}


esp_add_weapon( var_0, var_1 )
{
    var_2 = spawnstruct();
    var_2.weapon = var_0;
    var_2.display = var_1;
    level.esp_weapons[level.esp_weapons.size] = var_2;
}


/*
    ============================================================
    Gun shop — per player
    ============================================================
*/
esp_on_player_connect()
{
    level endon( "game_ended" );

    for (;;)
    {
        level waittill( "connected", var_0 );

        if ( getdvarint( "esp_shop_enabled" ) )
        {
            var_0 thread esp_player_shop_watcher();
        }

        if ( getdvarint( "esp_altmode_toggle_enabled" ) )
        {
            var_0 thread esp_altmode_watcher();
        }
    }
}


esp_player_shop_watcher()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    self.esp_menu_open = 0;
    self.esp_index = 0;

    self iprintln( "^2Gun Shop:^7 hold [{+speed_throw}] and press [{+melee}]" );

    for (;;)
    {
        wait 0.05;

        if ( !isalive( self ) )
        {
            continue;
        }

        if ( isdefined( self.usingarmory ) && self.usingarmory )
        {
            continue;
        }

        if ( isdefined( self.laststand ) && self.laststand )
        {
            continue;
        }

        if ( self adsbuttonpressed() && self meleebuttonpressed() )
        {
            self esp_open_shop();

            while ( self meleebuttonpressed() || self adsbuttonpressed() )
            {
                wait 0.05;
            }
        }
    }
}


/*
    Fallback alt-fire mode toggle.

    Action Slot 3 ("altMode", set natively by maps\mp\gametypes\_class
    and maps\mp\gametypes\horde) is supposed to swap weapons like the
    Ohm between their primary and alt-fire (shotgun) modes, but that
    bind isn't reachable/working for every client. Double-tapping
    [MELEE] (two presses within 0.4s) while the gun shop is closed
    swaps the current weapon for its alt-mode pair instead, using the
    same native weaponaltweaponname() lookup the engine itself uses.
*/
esp_altmode_watcher()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    var_0 = 0;

    for (;;)
    {
        wait 0.05;

        if ( !isalive( self ) )
        {
            continue;
        }

        if ( isdefined( self.esp_menu_open ) && self.esp_menu_open )
        {
            continue;
        }

        if ( isdefined( self.usingarmory ) && self.usingarmory )
        {
            continue;
        }

        if ( isdefined( self.laststand ) && self.laststand )
        {
            continue;
        }

        if ( self meleebuttonpressed() )
        {
            var_1 = gettime();

            if ( var_0 != 0 && ( var_1 - var_0 ) <= 400 )
            {
                self esp_try_toggle_altmode();
                var_0 = 0;
            }
            else
            {
                var_0 = var_1;
            }

            while ( self meleebuttonpressed() )
            {
                wait 0.05;
            }
        }
    }
}


esp_try_toggle_altmode()
{
    var_0 = self getcurrentweapon();

    if ( !isdefined( var_0 ) || var_0 == "none" )
    {
        return;
    }

    var_1 = weaponaltweaponname( var_0 );

    if ( !isdefined( var_1 ) || var_1 == "none" || var_1 == var_0 )
    {
        return;
    }

    self switchtoweapon( var_1 );
}


esp_open_shop()
{
    if ( self.esp_menu_open )
    {
        return;
    }

    self.esp_menu_open = 1;
    self freezecontrols( 1 );
    self esp_create_hud();

    while ( self meleebuttonpressed() || self adsbuttonpressed() || self usebuttonpressed() || self attackbuttonpressed() )
    {
        wait 0.05;
    }

    self esp_render_hud();

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
            self iprintlnbold( "^1Gun Shop closed (idle timeout)" );
            break;
        }

        if ( self meleebuttonpressed() )
        {
            break;
        }

        if ( self attackbuttonpressed() )
        {
            var_1 = gettime();
            self.esp_index = ( self.esp_index + 1 ) % level.esp_weapons.size;
            self esp_render_hud();
            self esp_wait_buttons_released();
            continue;
        }

        if ( self adsbuttonpressed() )
        {
            var_1 = gettime();
            self.esp_index = ( self.esp_index - 1 + level.esp_weapons.size ) % level.esp_weapons.size;
            self esp_render_hud();
            self esp_wait_buttons_released();
            continue;
        }

        if ( self usebuttonpressed() )
        {
            var_1 = gettime();
            var_0 = self esp_try_buy();
            self esp_wait_buttons_released();

            if ( var_0 )
            {
                break;
            }

            self esp_render_hud();
        }
    }

    self esp_destroy_hud();
    self freezecontrols( 0 );
    self.esp_menu_open = 0;
}


esp_wait_buttons_released()
{
    self endon( "disconnect" );

    while ( self attackbuttonpressed() || self adsbuttonpressed() || self usebuttonpressed() )
    {
        wait 0.05;
    }
}


esp_try_buy()
{
    var_0 = level.esp_weapons[self.esp_index];
    var_1 = getdvarint( "esp_gun_cost" );

    if ( self esp_owns_weapon( var_0.weapon ) )
    {
        self iprintlnbold( "^1You already have the " + var_0.display );
        return 0;
    }

    if ( !isdefined( self.armorypoints ) || self.armorypoints < var_1 )
    {
        self iprintlnbold( "^1Not enough upgrade points (" + var_1 + " needed)" );
        return 0;
    }

    self.armorypoints = self.armorypoints - var_1;
    self setclientomnvar( "ui_horde_player_points", self.armorypoints );

    self esp_destroy_hud();
    self freezecontrols( 0 );
    maps\mp\gametypes\_horde_util::trygivehordeweapon( self, var_0.weapon, 1, 1 );
    self freezecontrols( 1 );

    self iprintlnbold( "^2Bought " + var_0.display );
    return 1;
}


esp_owns_weapon( var_0 )
{
    var_1 = getweaponbasename( var_0 );
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


esp_create_hud()
{
    if ( isdefined( self.esp_hud_title ) )
    {
        return;
    }

    self.esp_hud_title = newclienthudelem( self );
    self.esp_hud_title.alignx = "center";
    self.esp_hud_title.aligny = "middle";
    self.esp_hud_title.horzalign = "center";
    self.esp_hud_title.vertalign = "middle";
    self.esp_hud_title.y = -60;
    self.esp_hud_title.fontscale = 1.6;
    self.esp_hud_title.color = ( 0.2, 1.0, 0.2 );
    self.esp_hud_title.alpha = 1;
    self.esp_hud_title.sort = 20;
    self.esp_hud_title settext( "GUN SHOP" );

    self.esp_hud_item = newclienthudelem( self );
    self.esp_hud_item.alignx = "center";
    self.esp_hud_item.aligny = "middle";
    self.esp_hud_item.horzalign = "center";
    self.esp_hud_item.vertalign = "middle";
    self.esp_hud_item.y = -35;
    self.esp_hud_item.fontscale = 1.4;
    self.esp_hud_item.alpha = 1;
    self.esp_hud_item.sort = 20;

    // Both the slot index (changes on every scroll) and the points
    // (change on every armory point earned) must never be baked into a
    // settext() string: settext() interns each unique string into the
    // engine's shared configstring table (shared across every
    // hud/script in the session, hard-capped around 650 entries), and
    // an always-changing number means an always-new string, which
    // eventually overflows that table and kicks the player with a
    // "G_FindConfigstringIndex: overflow" error -- this previously
    // happened to the points field, and (because that fix only
    // addressed the points number) it also happened again from the
    // weapon slot index baked into this same line. setvalue() updates a
    // numeric field on the hud elem directly with no configstring cost,
    // same as native score/ammo/kill-counter huds, and (per the native
    // _zombies_sidequests.gsc live-counter pattern) can be combined
    // with a settext() label set once up front, so every label below is
    // set once here and only the matching number is refreshed with
    // setvalue() in esp_render_hud().
    self.esp_hud_cost = newclienthudelem( self );
    self.esp_hud_cost.alignx = "center";
    self.esp_hud_cost.aligny = "middle";
    self.esp_hud_cost.horzalign = "center";
    self.esp_hud_cost.vertalign = "middle";
    self.esp_hud_cost.y = -15;
    self.esp_hud_cost.fontscale = 1.0;
    self.esp_hud_cost.alpha = 1;
    self.esp_hud_cost.sort = 20;
    self.esp_hud_cost settext( "Cost: " );

    self.esp_hud_slot = newclienthudelem( self );
    self.esp_hud_slot.alignx = "right";
    self.esp_hud_slot.aligny = "middle";
    self.esp_hud_slot.horzalign = "center";
    self.esp_hud_slot.vertalign = "middle";
    self.esp_hud_slot.x = -5;
    self.esp_hud_slot.y = 2;
    self.esp_hud_slot.fontscale = 1.0;
    self.esp_hud_slot.alpha = 1;
    self.esp_hud_slot.sort = 20;
    self.esp_hud_slot settext( "Weapon " );

    // Static suffix: the weapon count never changes once the shop is
    // built, so a single settext() call here is safe (same string every
    // time, no configstring growth) -- it is only the current index
    // (esp_hud_slot, above) that changes per render.
    self.esp_hud_slot_total = newclienthudelem( self );
    self.esp_hud_slot_total.alignx = "left";
    self.esp_hud_slot_total.aligny = "middle";
    self.esp_hud_slot_total.horzalign = "center";
    self.esp_hud_slot_total.vertalign = "middle";
    self.esp_hud_slot_total.x = 5;
    self.esp_hud_slot_total.y = 2;
    self.esp_hud_slot_total.fontscale = 1.0;
    self.esp_hud_slot_total.alpha = 1;
    self.esp_hud_slot_total.sort = 20;
    self.esp_hud_slot_total settext( " / " + level.esp_weapons.size );

    self.esp_hud_points = newclienthudelem( self );
    self.esp_hud_points.alignx = "center";
    self.esp_hud_points.aligny = "middle";
    self.esp_hud_points.horzalign = "center";
    self.esp_hud_points.vertalign = "middle";
    self.esp_hud_points.y = 19;
    self.esp_hud_points.fontscale = 1.0;
    self.esp_hud_points.alpha = 1;
    self.esp_hud_points.sort = 20;
    self.esp_hud_points settext( "Your points: " );

    self.esp_hud_help = newclienthudelem( self );
    self.esp_hud_help.alignx = "center";
    self.esp_hud_help.aligny = "middle";
    self.esp_hud_help.horzalign = "center";
    self.esp_hud_help.vertalign = "middle";
    self.esp_hud_help.y = 39;
    self.esp_hud_help.fontscale = 0.9;
    self.esp_hud_help.alpha = 0.8;
    self.esp_hud_help.sort = 20;
    self.esp_hud_help settext( "[FIRE] next  [AIM] prev  [USE] buy  [MELEE] close" );
}


esp_render_hud()
{
    if ( !isdefined( self.esp_hud_item ) )
    {
        return;
    }

    var_0 = level.esp_weapons[self.esp_index];
    var_1 = getdvarint( "esp_gun_cost" );
    var_2 = 0;

    if ( isdefined( self.armorypoints ) )
    {
        var_2 = self.armorypoints;
    }

    self.esp_hud_item settext( "< " + var_0.display + " >" );
    self.esp_hud_cost setvalue( var_1 );
    self.esp_hud_slot setvalue( self.esp_index + 1 );
    self.esp_hud_points setvalue( var_2 );
}


esp_destroy_hud()
{
    if ( isdefined( self.esp_hud_title ) )
    {
        self.esp_hud_title destroy();
        self.esp_hud_title = undefined;
    }

    if ( isdefined( self.esp_hud_item ) )
    {
        self.esp_hud_item destroy();
        self.esp_hud_item = undefined;
    }

    if ( isdefined( self.esp_hud_cost ) )
    {
        self.esp_hud_cost destroy();
        self.esp_hud_cost = undefined;
    }

    if ( isdefined( self.esp_hud_slot ) )
    {
        self.esp_hud_slot destroy();
        self.esp_hud_slot = undefined;
    }

    if ( isdefined( self.esp_hud_slot_total ) )
    {
        self.esp_hud_slot_total destroy();
        self.esp_hud_slot_total = undefined;
    }

    if ( isdefined( self.esp_hud_points ) )
    {
        self.esp_hud_points destroy();
        self.esp_hud_points = undefined;
    }

    if ( isdefined( self.esp_hud_help ) )
    {
        self.esp_hud_help destroy();
        self.esp_hud_help = undefined;
    }
}


/*
    ============================================================
    DLC map support
    ============================================================
    All of the native Exo Survival map data is generated at
    runtime when the current map is missing it:

    - armory kiosks:     getentarray( "horde_armory", "targetname" )
    - collect locations: getstructarray( "horde_collect", "targetname" )
    - defend locations:  getstructarray( "horde_defend", "targetname" )
    - drop locations:    getstructarray( "horde_drop", "targetname" )
    - defuse bombs:      getentarray( "horde_defuse_bomb", "targetname" )
    - uplink starts:     getstructarray( "ball_start", "targetname" )
*/
esp_dlc_map_support()
{
    level endon( "game_ended" );

    var_0 = 0;

    while ( !isdefined( level.struct_class_names ) && var_0 < 100 )
    {
        wait 0.05;
        var_0++;
    }

    if ( !isdefined( level.struct_class_names ) )
    {
        println( "[ESP] struct tables never initialized, aborting DLC map support" );
        return;
    }

    var_1 = esp_gather_fallback_points();

    if ( var_1.size < 1 )
    {
        println( "[ESP] no spawn points found, aborting DLC map support" );
        return;
    }

    var_2 = 0;

    if ( common_scripts\utility::getstructarray( "horde_collect", "targetname" ).size < 20 )
    {
        esp_inject_structs( "horde_collect", var_1, 24 );
        var_2 = 1;
    }

    if ( common_scripts\utility::getstructarray( "horde_defend", "targetname" ).size < 1 )
    {
        esp_inject_structs( "horde_defend", var_1, 8 );
        var_2 = 1;
    }

    if ( common_scripts\utility::getstructarray( "horde_drop", "targetname" ).size < 1 )
    {
        esp_inject_structs( "horde_drop", var_1, 12 );
        level thread esp_fix_drop_locations();
        var_2 = 1;
    }

    if ( getentarray( "horde_armory", "targetname" ).size < 1 )
    {
        esp_spawn_armories( var_1 );
        var_2 = 1;
    }

    level thread esp_restrict_objective_rounds();

    if ( var_2 )
    {
        println( "[ESP] DLC map support active on " + getdvar( "mapname" ) );
    }
}


/*
    Collect usable ground positions from the map's TDM / DM
    spawn points (present on every multiplayer map).
*/
esp_gather_fallback_points()
{
    var_0 = [];
    var_1 = [];
    var_1[var_1.size] = "mp_tdm_spawn";
    var_1[var_1.size] = "mp_tdm_spawn_allies_start";
    var_1[var_1.size] = "mp_tdm_spawn_axis_start";
    var_1[var_1.size] = "mp_dm_spawn";

    foreach ( var_3 in var_1 )
    {
        var_4 = getentarray( var_3, "classname" );

        foreach ( var_6 in var_4 )
        {
            var_0[var_0.size] = var_6;
        }
    }

    return var_0;
}


/*
    Append generated structs to the script struct table so the
    native common_scripts\utility::getstructarray calls made by
    horde.gsc find them. Positions are cycled from the spawn
    points with a small jitter when more entries are needed
    than there are spawns.
*/
esp_inject_structs( var_0, var_1, var_2 )
{
    if ( !isdefined( level.struct_class_names["targetname"] ) )
    {
        level.struct_class_names["targetname"] = [];
    }

    if ( !isdefined( level.struct_class_names["targetname"][var_0] ) )
    {
        level.struct_class_names["targetname"][var_0] = [];
    }

    for ( var_3 = 0; var_3 < var_2; var_3++ )
    {
        var_4 = var_1[var_3 % var_1.size];
        var_5 = spawnstruct();
        var_5.origin = var_4.origin;
        var_5.angles = var_4.angles;

        if ( var_3 >= var_1.size )
        {
            var_5.origin = var_5.origin + ( randomintrange( -96, 96 ), randomintrange( -96, 96 ), 0 );
        }

        var_5.targetname = var_0;
        level.struct_class_names["targetname"][var_0][level.struct_class_names["targetname"][var_0].size] = var_5;
    }

    println( "[ESP] injected " + var_2 + " '" + var_0 + "' locations" );
}


/*
    inithordesettings() caches level.hordedroplocations before this
    script can inject structs, so refill the cached array too.
*/
esp_fix_drop_locations()
{
    level endon( "game_ended" );

    var_0 = 0;

    while ( !isdefined( level.hordedroplocations ) && var_0 < 200 )
    {
        wait 0.05;
        var_0++;
    }

    if ( !isdefined( level.hordedroplocations ) || level.hordedroplocations.size > 0 )
    {
        return;
    }

    var_1 = common_scripts\utility::getstructarray( "horde_drop", "targetname" );

    foreach ( var_3 in var_1 )
    {
        var_3.tracelocation = var_3.origin;
        level.hordedroplocations[level.hordedroplocations.size] = var_3;
    }

    println( "[ESP] refilled " + level.hordedroplocations.size + " support drop locations" );
}


/*
    Spawn a weapon armory and an exo armory kiosk. The native
    initarmories() in _horde_armory.gsc picks these up by
    targetname and runs the full native buy menu on them.
*/
esp_spawn_armories( var_0 )
{
    var_1 = var_0[0].origin;
    var_2 = var_0[0].origin + ( 128, 0, 0 );

    foreach ( var_4 in var_0 )
    {
        if ( isdefined( var_4.classname ) && var_4.classname == "mp_tdm_spawn_allies_start" )
        {
            var_1 = var_4.origin;
            var_2 = var_4.origin + ( 128, 0, 0 );
            break;
        }
    }

    esp_spawn_armory_kiosk( var_1, "specops_ui_equipmentstore", "equipment_armory", "esp_armory_dummy_1" );
    esp_spawn_armory_kiosk( var_2, "specops_ui_exostore", "exo_armory", "esp_armory_dummy_2" );
    println( "[ESP] spawned replacement armory kiosks" );
}


esp_spawn_armory_kiosk( var_0, var_1, var_2, var_3 )
{
    var_4 = spawn( "trigger_radius", var_0, 0, 64, 72 );
    var_4.targetname = "horde_armory";
    var_4.script_parameters = var_1;
    var_4.script_noteworthy = var_2;
    var_4.target = var_3;

    var_5 = spawn( "script_model", var_0 );
    var_5 setmodel( "com_laptop_2_open" );
    var_5.angles = ( 0, 0, 0 );
}


/*
    The native objective rotation is [ defend, collect, intel,
    defuse, uplink ]. Defuse needs "horde_defuse_bomb" entities
    and uplink needs "ball_start" structs baked into the map.
    When those are missing, prefill level.hordeobjectiveorder with
    only the objectives this map can run so runhordeobjective()
    never schedules a broken round. 1 = defend, 2 = collect,
    3 = intel, 4 = defuse, 5 = uplink.
*/
esp_restrict_objective_rounds()
{
    level endon( "game_ended" );

    var_0 = [];
    var_0[var_0.size] = 1;
    var_0[var_0.size] = 2;
    var_0[var_0.size] = 3;

    if ( getentarray( "horde_defuse_bomb", "targetname" ).size > 0 )
    {
        var_0[var_0.size] = 4;
    }

    if ( common_scripts\utility::getstructarray( "ball_start", "targetname" ).size > 0 && getdvar( "mapname" ) != "mp_prison_z" )
    {
        var_0[var_0.size] = 5;
    }

    if ( var_0.size >= 5 )
    {
        return;
    }

    var_1 = [];

    while ( var_1.size < 12 )
    {
        var_2 = common_scripts\utility::array_randomize( var_0 );

        foreach ( var_4 in var_2 )
        {
            var_1[var_1.size] = var_4;
        }
    }

    level.hordeobjectiveorder = var_1;
    level.hordeobjectiveindex = 0;
    println( "[ESP] objective rounds limited to supported types" );
}


/*
    Optional: full base + DLC map rotation for Exo Survival.
    Havoc, Ascendance, Supremacy and Reckoning packs included.
*/
esp_set_dlc_rotation()
{
    var_0 = "gametype horde";
    var_1 = [];
    var_1[var_1.size] = "mp_refraction";
    var_1[var_1.size] = "mp_lab2";
    var_1[var_1.size] = "mp_comeback";
    var_1[var_1.size] = "mp_detroit";
    var_1[var_1.size] = "mp_greenband";
    var_1[var_1.size] = "mp_instinct";
    var_1[var_1.size] = "mp_recovery";
    var_1[var_1.size] = "mp_venus";
    var_1[var_1.size] = "mp_laser2";
    var_1[var_1.size] = "mp_solar";
    var_1[var_1.size] = "mp_terrace";
    var_1[var_1.size] = "mp_levity";
    var_1[var_1.size] = "mp_drift";
    var_1[var_1.size] = "mp_sideshow";
    var_1[var_1.size] = "mp_core";
    var_1[var_1.size] = "mp_urban";
    var_1[var_1.size] = "mp_chopshop";
    var_1[var_1.size] = "mp_climate";
    var_1[var_1.size] = "mp_perplex";
    var_1[var_1.size] = "mp_site244";
    var_1[var_1.size] = "mp_compound";
    var_1[var_1.size] = "mp_kremlin";
    var_1[var_1.size] = "mp_parliament";
    var_1[var_1.size] = "mp_skyrise";
    var_1[var_1.size] = "mp_fracture";
    var_1[var_1.size] = "mp_overload";
    var_1[var_1.size] = "mp_quarantine";
    var_1[var_1.size] = "mp_swarm";

    foreach ( var_3 in var_1 )
    {
        var_0 = var_0 + " map " + var_3;
    }

    setdvar( "sv_maprotation", var_0 );
    println( "[ESP] map rotation set to all base + DLC maps" );
}

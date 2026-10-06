/*
    Exo Survival Plus — S1x (Call of Duty: Advanced Warfare)
    Gametype: "horde" (Exo Survival)

    Features:

    1) Gun Shop
        Adds the Crossbow and selected base DLC weapons
        (Ohm, M1 Irons, Blunderbuss, STG-44,
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

        The Ohm uses the native [Toggle Grenade Launcher] control to
        switch between LMG and shotgun modes while the shop is closed.
        Combat Knife, AE4, and Riot Shield are not sold in this shop.

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

    if ( getdvarint( "esp_shop_enabled" ) )
    {
        level thread esp_on_player_connect();
    }
}


/*
    ============================================================
    Gun shop weapon list
    ============================================================
    Crossbow, then selected base DLC weapons by their GSC names.
    Base versions only — no
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
        var_0 thread esp_player_shop_watcher();
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

    for (;;)
    {
        wait 0.05;

        if ( !isalive( self ) || isdefined( self.laststand ) && self.laststand )
        {
            break;
        }

        if ( self meleebuttonpressed() )
        {
            break;
        }

        if ( self attackbuttonpressed() )
        {
            self.esp_index = ( self.esp_index + 1 ) % level.esp_weapons.size;
            self esp_render_hud();
            self esp_wait_buttons_released();
            continue;
        }

        if ( self adsbuttonpressed() )
        {
            self.esp_index = ( self.esp_index - 1 + level.esp_weapons.size ) % level.esp_weapons.size;
            self esp_render_hud();
            self esp_wait_buttons_released();
            continue;
        }

        if ( self usebuttonpressed() )
        {
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

    var_2 = var_0.weapon;

    if ( var_0.weapon == "iw5_dlcgun2_mp" )
    {
        // The native builder adds the Ohm's automatic alt-mode attachment.
        var_2 = maps\mp\gametypes\_class::buildweaponname( "iw5_dlcgun2", "none", "none", "none", 0, 0 );
    }

    self.armorypoints = self.armorypoints - var_1;
    self setclientomnvar( "ui_horde_player_points", self.armorypoints );

    self esp_destroy_hud();
    self freezecontrols( 0 );
    maps\mp\gametypes\_horde_util::trygivehordeweapon( self, var_2, 1, 1 );

    if ( var_0.weapon == "iw5_dlcgun2_mp" )
    {
        self maps\mp\_utility::_setactionslot( 3, "altMode" );
    }

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

    // Changing numbers must use setvalue(), not new configstring text.
    self.esp_hud_labels = [];
    self.esp_hud_labels[0] = self esp_create_hud_field( -8, -15, "right" );
    self.esp_hud_labels[0] settext( "Cost:" );
    self.esp_hud_cost = self esp_create_hud_field( 8, -15, "left" );

    self.esp_hud_labels[1] = self esp_create_hud_field( -8, 2, "right" );
    self.esp_hud_labels[1] settext( "Weapon:" );
    self.esp_hud_slot = self esp_create_hud_field( 8, 2, "left" );
    self.esp_hud_labels[2] = self esp_create_hud_field( 48, 2, "left" );
    self.esp_hud_labels[2] settext( "/ " + level.esp_weapons.size );

    self.esp_hud_labels[3] = self esp_create_hud_field( -8, 19, "right" );
    self.esp_hud_labels[3] settext( "Your points:" );
    self.esp_hud_points = self esp_create_hud_field( 8, 19, "left" );

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


esp_create_hud_field( var_0, var_1, var_2 )
{
    var_3 = newclienthudelem( self );
    var_3.alignx = var_2;
    var_3.aligny = "middle";
    var_3.horzalign = "center";
    var_3.vertalign = "middle";
    var_3.x = var_0;
    var_3.y = var_1;
    var_3.fontscale = 1.0;
    var_3.alpha = 1;
    var_3.sort = 20;
    return var_3;
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

    if ( isdefined( self.esp_hud_points ) )
    {
        self.esp_hud_points destroy();
        self.esp_hud_points = undefined;
    }

    if ( isdefined( self.esp_hud_labels ) )
    {
        foreach ( var_0 in self.esp_hud_labels )
        {
            if ( isdefined( var_0 ) )
            {
                var_0 destroy();
            }
        }

        self.esp_hud_labels = undefined;
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

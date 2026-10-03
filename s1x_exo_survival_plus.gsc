/*
    Exo Survival Plus — S1x (Call of Duty: Advanced Warfare)
    Gametype: "horde" (Exo Survival)

    SERVER SIDE — pair this with exo_survival_plus_ui.lua
    (ui_scripts), which adds the new weapons to the NATIVE
    armory buy menus. This script receives the purchases.

    Features:

    1) Native shop weapons
        The LUI script adds every missing base weapon and every
        base DLC weapon (AE4, Ohm, M1 Irons, Blunderbuss, STG-44,
        SVO, AK-47, M16, CEL-3 Cauterizer, 1911, MP40, M1 Garand,
        Sten, Lever Action, Repulsor) to the native weapon armory
        category menus. Buy buttons send the custom
        "esp_weapon_upgrade" event with the shop index; this
        script validates armory points, charges the player and
        gives the gun through the native horde weapon pipeline
        (maps\mp\gametypes\_horde_util::trygivehordeweapon) so
        camo / weapon proficiency / class-slot bookkeeping all
        behave exactly like a native purchase.

        The index -> weapon/cost table here MUST stay in sync
        with ESP_WEAPONS in exo_survival_plus_ui.lua.

    2) DLC map support
        Makes all 16 DLC multiplayer maps (Havoc, Ascendance,
        Supremacy, Reckoning) playable in Exo Survival. On maps
        missing the native Exo Survival map data this script:
            - spawns a working weapon armory and exo armory kiosk
              near the player spawns (full native buy menus),
            - injects collect ("horde_collect"), defend
              ("horde_defend") and support-drop ("horde_drop")
              locations generated from the map's TDM spawn points,
            - limits objective rounds to Defend / Collect / Intel
              when the map has no defuse-bomb or uplink entities,
              so no objective round can fail from missing map data.

    Dvars:
        esp_shop_enabled      enable the shop purchase handler   (default 1)
        esp_dlc_maps_enabled  enable the DLC map support         (default 1)
        esp_dlc_rotation      1 = write a map rotation with all base + DLC
                              maps in gametype horde             (default 0)

    Install (s1x):
        <AW folder>/s1x/scripts/s1x_exo_survival_plus.gsc
        <AW folder>/s1x/ui_scripts/exo_survival_plus/__init__.lua
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

    esp_build_shop_table();

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
    Shop table — index, weapon, display name, cost
    ============================================================
    Indexes and costs MUST match ESP_WEAPONS in
    exo_survival_plus_ui.lua.

    Pistols   600+ | SMGs 610+ | Assault 620+ | Shotguns 630+
    Snipers   640+ | Heavy 650+ | Launcher 660+
*/
esp_build_shop_table()
{
    level.esp_shop = [];

    esp_add_shop_item( 600, "iw5_dlcgun3_mp", "M1 Irons", 2 );
    esp_add_shop_item( 601, "iw5_dlcgun13_mp", "1911", 2 );
    esp_add_shop_item( 602, "iw5_combatknife_mp", "Combat Knife", 1 );

    esp_add_shop_item( 610, "iw5_dlcgun18_mp", "MP40", 3 );
    esp_add_shop_item( 611, "iw5_dlcgun28_mp", "Sten", 3 );

    esp_add_shop_item( 620, "iw5_dlcgun6_mp", "STG-44", 3 );
    esp_add_shop_item( 621, "iw5_dlcgun7loot0_mp", "AK-47", 3 );
    esp_add_shop_item( 622, "iw5_dlcgun8_mp", "M16", 3 );
    esp_add_shop_item( 623, "iw5_dlcgun23_mp", "M1 Garand", 3 );
    esp_add_shop_item( 624, "iw5_dlcgun1_mp", "AE4", 3 );

    esp_add_shop_item( 630, "iw5_dlcgun4_mp", "Blunderbuss", 3 );
    esp_add_shop_item( 631, "iw5_dlcgun8loot0_mp", "CEL-3 Cauterizer", 4 );
    esp_add_shop_item( 632, "iw5_dlcgun33_mp", "Lever Action", 3 );

    esp_add_shop_item( 640, "iw5_dlcgun7_mp", "SVO", 3 );

    esp_add_shop_item( 650, "iw5_dlcgun2_mp", "Ohm", 4 );
    esp_add_shop_item( 651, "iw5_dlcgun38_mp", "Repulsor", 4 );
    esp_add_shop_item( 652, "iw5_riotshieldt6_mp", "Riot Shield", 2 );

    esp_add_shop_item( 660, "iw5_exocrossbow_mp", "Crossbow", 3 );
}


esp_add_shop_item( var_0, var_1, var_2, var_3 )
{
    var_4 = spawnstruct();
    var_4.weapon = var_1;
    var_4.display = var_2;
    var_4.cost = var_3;
    level.esp_shop[var_0] = var_4;
}


/*
    ============================================================
    Native shop purchase handler
    ============================================================
    The LUI buy buttons call Engine.NotifyServer with the custom
    event type "esp_weapon_upgrade" and the shop index. The
    native armory handler in _horde_armory.gsc ignores unknown
    event types (hordeisarmoryupgrade), so this listener is the
    only consumer and there is no double handling.
*/
esp_on_player_connect()
{
    level endon( "game_ended" );

    for (;;)
    {
        level waittill( "connected", var_0 );
        var_0 thread esp_player_purchase_listener();
    }
}


esp_player_purchase_listener()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for (;;)
    {
        self waittill( "luinotifyserver", var_0, var_1 );

        if ( var_0 != "esp_weapon_upgrade" )
        {
            continue;
        }

        var_2 = int( var_1 );

        if ( !isdefined( level.esp_shop[var_2] ) )
        {
            continue;
        }

        if ( !isalive( self ) || maps\mp\gametypes\_horde_util::isplayerinlaststand( self ) )
        {
            continue;
        }

        self esp_handle_purchase( var_2 );
    }
}


esp_handle_purchase( var_0 )
{
    var_1 = level.esp_shop[var_0];

    if ( isdefined( level.hordeweaponsjammed ) && level.hordeweaponsjammed )
    {
        self setclientomnvar( "ui_horde_armory_purchase_fail", 4 );
        return;
    }

    var_2 = self getcurrentprimaryweapon();

    if ( var_2 == "none" || issubstr( var_2, "turret" ) )
    {
        self setclientomnvar( "ui_horde_armory_purchase_fail", 1 );
        return;
    }

    if ( self esp_owns_weapon( var_1.weapon ) )
    {
        self setclientomnvar( "ui_horde_armory_purchase_fail", 1 );
        self iprintlnbold( "^1You already have the " + var_1.display );
        return;
    }

    if ( !isdefined( self.armorypoints ) || self.armorypoints < var_1.cost )
    {
        self setclientomnvar( "ui_horde_armory_purchase_fail", 0 );
        return;
    }

    self.armorypoints = self.armorypoints - var_1.cost;
    self setclientomnvar( "ui_horde_player_points", self.armorypoints );
    self setclientomnvar( "ui_horde_armory_purchase", var_0 );
    self playsoundtoplayer( "new_title_unlocks", self );

    wait 0.05;
    maps\mp\gametypes\_horde_util::trygivehordeweapon( self, var_1.weapon, 1, 1 );
    self iprintlnbold( "^2Bought " + var_1.display );
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

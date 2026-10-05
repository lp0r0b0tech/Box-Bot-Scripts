/*
    Exo Zombies Wonder Shop — S1x (Call of Duty: Advanced Warfare)
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
        [MELEE]                     -> close the shop

    Dvars:
        ezs_weapon_cost   points cost per shop weapon   (default 1000)
        ezs_shop_enabled  enable the wonder shop          (default 1)

    NOTE: scripts/zm/s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc opens on
    the same Hold [AIM] + press [MELEE] gesture. If that file is also
    loaded, set  scr_zm_dlc_shop_enabled 0  (or remove it) to avoid both
    shops trying to open at once.

    Install (s1x):
        Place this file in  %localappdata%\Plutonium-style s1x scripts dir:
        s1x > data > scripts  (loaded as a loose GSC by s1x)
*/

main()
{
    ezs_init();
}


init()
{
    ezs_init();
}


ezs_init()
{
    if ( isdefined( level.ezs_started ) )
    {
        return;
    }

    level.ezs_started = 1;

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
    Wonder shop — per player
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

    if ( self ezs_owns_weapon( var_0.weapon ) )
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
    maps\mp\zombies\_wall_buys::givezombieweapon( self, var_0.weapon, 1, 1 );
    self freezecontrols( 1 );

    self iprintlnbold( "^2Bought " + var_0.display );
    return 1;
}


ezs_owns_weapon( var_0 )
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

    self.ezs_hud_info = newclienthudelem( self );
    self.ezs_hud_info.alignx = "center";
    self.ezs_hud_info.aligny = "middle";
    self.ezs_hud_info.horzalign = "center";
    self.ezs_hud_info.vertalign = "middle";
    self.ezs_hud_info.y = -15;
    self.ezs_hud_info.fontscale = 1.0;
    self.ezs_hud_info.alpha = 1;
    self.ezs_hud_info.sort = 20;

    self.ezs_hud_help = newclienthudelem( self );
    self.ezs_hud_help.alignx = "center";
    self.ezs_hud_help.aligny = "middle";
    self.ezs_hud_help.horzalign = "center";
    self.ezs_hud_help.vertalign = "middle";
    self.ezs_hud_help.y = 5;
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
    self.ezs_hud_info settext( "Cost: " + var_1 + "   Your points: " + var_2 + "   (" + ( self.ezs_index + 1 ) + "/" + level.ezs_weapons.size + ")" );
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

    if ( isdefined( self.ezs_hud_info ) )
    {
        self.ezs_hud_info destroy();
        self.ezs_hud_info = undefined;
    }

    if ( isdefined( self.ezs_hud_help ) )
    {
        self.ezs_hud_help destroy();
        self.ezs_hud_help = undefined;
    }
}

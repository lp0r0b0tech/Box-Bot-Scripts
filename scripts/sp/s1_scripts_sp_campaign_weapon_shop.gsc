/*
    Free S1x Campaign weapon shop.

    Install in s1/scripts/sp. Enable before starting or restarting a
    Campaign map with:
        set scr_sp_campaign_weapon_shop 1

    Hold [Aim] + tap [Melee] to open.
    [Attack] next, [Melee] previous, [Use] grant, [Frag] close.

    The weapon IDs below are referenced by this repository's MP script
    roster or Exo Zombies zone manifests. They still need to be present
    in Campaign-compatible fastfiles; this script cannot convert or add
    weapon assets to Campaign.
*/

#define SPWS_DEFAULT_ENABLED       0
#define SPWS_POLL_INTERVAL         0.05
#define SPWS_LOAD_ATTEMPTS         100
#define SPWS_IDLE_TIMEOUT_SECONDS  30

main()
{
    spws_init();
}

init()
{
    spws_init();
}

spws_init()
{
    if ( isdefined( level.spwsInitStarted ) && level.spwsInitStarted )
    {
        return;
    }

    level.spwsInitStarted = true;
    setdvarifuninitialized( "scr_sp_campaign_weapon_shop", SPWS_DEFAULT_ENABLED );
    spws_build_weapon_list();
    level thread spws_watch_players();

    println( "CampaignWeaponShop: initialized; set scr_sp_campaign_weapon_shop 1 to enable." );
}

spws_build_weapon_list()
{
    level.spws_weapons = [];

    spws_add_weapon( "iw5_dlcgun13_mp", "DLC Weapon 13" );
    spws_add_weapon( "iw5_ak12_mp", "AK12" );
    spws_add_weapon( "iw5_hmr9_mp", "HMR9" );
    spws_add_weapon( "iw5_arx160_mp", "ARX-160" );
    spws_add_weapon( "iw5_asaw_mp", "ASAW" );
    spws_add_weapon( "iw5_titan45_mp", "Titan 45" );
    spws_add_weapon( "iw5_dlcgun4_mp", "DLC Weapon 4" );
    spws_add_weapon( "iw5_pbw_mp", "PBW" );
    spws_add_weapon( "iw5_vbr_mp", "VBR" );
    spws_add_weapon( "iw5_uts19_mp", "UTS-19" );
    spws_add_weapon( "iw5_maul_mp", "Maul" );
    spws_add_weapon( "iw5_dlcgun8loot0_mp", "DLC Weapon 8" );
    spws_add_weapon( "iw5_combatknife_mp", "Combat Knife" );
    spws_add_weapon( "iw5_exocrossbow_mp", "Crossbow" );
    spws_add_weapon( "iw5_em1_mp", "EM1" );
    spws_add_weapon( "iw5_epm3_mp", "EPM3" );
    spws_add_weapon( "iw5_hbra3_mp", "HBRa3" );
    spws_add_weapon( "iw5_riotshieldt6_mp", "Riot Shield" );
    spws_add_weapon( "iw5_himar_mp", "Himar" );
    spws_add_weapon( "iw5_kf5_mp", "KF5" );
    spws_add_weapon( "iw5_dlcgun33_mp", "DLC Weapon 33" );
    spws_add_weapon( "iw5_gm6_mp", "GM6" );
    spws_add_weapon( "iw5_dlcgun23_mp", "DLC Weapon 23" );
    spws_add_weapon( "iw5_dlcgun3_mp", "DLC Weapon 3" );
    spws_add_weapon( "iw5_dlcgun8_mp", "DLC Weapon 8" );
    spws_add_weapon( "iw5_maaws_mp", "MAAWS" );
    spws_add_weapon( "iw5_mahem_mp", "MAHEM" );
    spws_add_weapon( "iw5_microdronelauncher_mp", "Micro Drone Launcher" );
    spws_add_weapon( "iw5_m990_mp", "M990" );
    spws_add_weapon( "iw5_mp11_mp", "MP11" );
    spws_add_weapon( "iw5_dlcgun18_mp", "DLC Weapon 18" );
    spws_add_weapon( "iw5_dlcgun2_mp", "DLC Weapon 2" );
    spws_add_weapon( "iw5_lsat_mp", "LSAT" );
    spws_add_weapon( "iw5_dlcgun38_mp", "DLC Weapon 38" );
    spws_add_weapon( "iw5_rhino_mp", "Rhino" );
    spws_add_weapon( "iw5_sac3_mp", "SAC3" );
    spws_add_weapon( "iw5_sn6_mp", "SN6" );
    spws_add_weapon( "iw5_dlcgun6_mp", "DLC Weapon 6" );
    spws_add_weapon( "iw5_dlcgun7_mp", "DLC Weapon 7" );
    spws_add_weapon( "iw5_stingerm7_mp", "Stinger M7" );
    spws_add_weapon( "iw5_dlcgun28_mp", "DLC Weapon 28" );
    spws_add_weapon( "iw5_asm1_mp", "ASM1" );
    spws_add_weapon( "iw5_m182spr_mp", "M182 SPR" );
    spws_add_weapon( "iw5_mors_mp", "MORS" );
    spws_add_weapon( "iw5_bal27_mp", "BAL-27" );
    spws_add_weapon( "iw5_rw1_mp", "RW1" );
    spws_add_weapon( "iw5_exoxmg_mp", "XMG" );
    spws_add_weapon( "iw5_thor_mp", "THOR" );

    spws_add_weapon( "iw5_rw1zm_mp", "RW1 (Exo Zombies)" );
    spws_add_weapon( "iw5_vbrzm_mp", "VBR (Exo Zombies)" );
    spws_add_weapon( "iw5_gm6zm_mp", "GM6 (Exo Zombies)" );
    spws_add_weapon( "iw5_rhinozm_mp", "Rhino (Exo Zombies)" );
    spws_add_weapon( "iw5_lsatzm_mp", "LSAT (Exo Zombies)" );
    spws_add_weapon( "iw5_asawzm_mp", "ASAW (Exo Zombies)" );
    spws_add_weapon( "iw5_ak12zm_mp", "AK12 (Exo Zombies)" );
    spws_add_weapon( "iw5_bal27zm_mp", "BAL-27 (Exo Zombies)" );
    spws_add_weapon( "iw5_himarzm_mp", "Himar (Exo Zombies)" );
    spws_add_weapon( "iw5_arx160zm_mp", "ARX-160 (Exo Zombies)" );
    spws_add_weapon( "iw5_hbra3zm_mp", "HBRa3 (Exo Zombies)" );
    spws_add_weapon( "iw5_m182sprzm_mp", "M182 SPR (Exo Zombies)" );
    spws_add_weapon( "iw5_mp11zm_mp", "MP11 (Exo Zombies)" );
    spws_add_weapon( "iw5_asm1zm_mp", "ASM1 (Exo Zombies)" );
    spws_add_weapon( "iw5_sn6zm_mp", "SN6 (Exo Zombies)" );
    spws_add_weapon( "iw5_sac3zm_mp", "SAC3 (Exo Zombies)" );
    spws_add_weapon( "iw5_hmr9zm_mp", "HMR9 (Exo Zombies)" );
    spws_add_weapon( "iw5_maulzm_mp", "Maul (Exo Zombies)" );
    spws_add_weapon( "iw5_uts19zm_mp", "UTS-19 (Exo Zombies)" );
    spws_add_weapon( "iw5_em1zm_mp", "EM1 (Wonder Weapon)" );
    spws_add_weapon( "iw5_titan45zm_mp", "Titan 45 (Exo Zombies)" );
    spws_add_weapon( "iw5_exocrossbowzm_mp", "Crossbow (Exo Zombies)" );
    spws_add_weapon( "iw5_mahemzm_mp", "MAHEM (Wonder Weapon)" );
    spws_add_weapon( "iw5_fusionzm_mp", "CEL-3 Cauterizer (Wonder Weapon)" );
    spws_add_weapon( "iw5_microwavezm_mp", "Microwave Gun (Wonder Weapon)" );
    spws_add_weapon( "iw5_linegunzm_mp", "Line Gun (Wonder Weapon)" );
    spws_add_weapon( "iw5_tridentzm_mp", "Trident (Wonder Weapon)" );
    spws_add_weapon( "iw5_dlcgun1zm_mp", "DLC Weapon 1 (Exo Zombies)" );
    spws_add_weapon( "iw5_dlcgun2zm_mp", "DLC Weapon 2 (Exo Zombies)" );
    spws_add_weapon( "iw5_dlcgun3zm_mp", "DLC Weapon 3 (Exo Zombies)" );
    spws_add_weapon( "iw5_dlcgun4zm_mp", "DLC Weapon 4 (Exo Zombies)" );
    spws_add_weapon( "iw5_exominigunzm_mp", "Exo Minigun (Wonder Weapon)" );
}

spws_add_weapon( weaponName, displayName )
{
    entry = spawnstruct();
    entry.weaponName = weaponName;
    entry.displayName = displayName;
    level.spws_weapons[level.spws_weapons.size] = entry;
}

spws_watch_players()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread spws_player_init();
    }
}

spws_player_init()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "spawned_player" );
        self thread spws_player_monitor();
    }
}

spws_player_monitor()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "spawned_player" );

    for ( ;; )
    {
        wait SPWS_POLL_INTERVAL;

        if ( getdvarint( "scr_sp_campaign_weapon_shop" ) <= 0 ||
             !isalive( self ) )
        {
            continue;
        }

        if ( isdefined( self.spws_shopOpen ) && self.spws_shopOpen )
        {
            continue;
        }

        if ( self adsbuttonpressed() && self meleebuttonpressed() )
        {
            spws_wait_for_release( self, "melee" );
            self thread spws_open_shop();
        }
    }
}

spws_open_shop()
{
    self endon( "disconnect" );

    if ( isdefined( self.spws_shopOpen ) && self.spws_shopOpen )
    {
        return;
    }

    self.spws_shopOpen = true;
    self.spws_shopIndex = 0;
    self freezecontrols( true );

    self.spws_hud = newclienthudelem( self );
    self.spws_hud.alignx = "center";
    self.spws_hud.aligny = "middle";
    self.spws_hud.horzalign = "center";
    self.spws_hud.vertalign = "middle";
    self.spws_hud.y = -40;
    self.spws_hud.fontscale = 1.8;
    self.spws_hud.foreground = true;
    self.spws_hud.sort = 10;

    self.spws_hint = newclienthudelem( self );
    self.spws_hint.alignx = "center";
    self.spws_hint.aligny = "middle";
    self.spws_hint.horzalign = "center";
    self.spws_hint.vertalign = "middle";
    self.spws_hint.y = 0;
    self.spws_hint.fontscale = 1.1;
    self.spws_hint.foreground = true;
    self.spws_hint.sort = 10;
    self.spws_hint settext( "[Attack] Next   [Melee] Prev   [Use] Get free   [Frag] Close" );

    spws_refresh_hud( self );
    idleStart = gettime();

    while ( self.spws_shopOpen && isalive( self ) )
    {
        wait SPWS_POLL_INTERVAL;

        if ( getdvarint( "scr_sp_campaign_weapon_shop" ) <= 0 ||
             ( gettime() - idleStart ) >= ( SPWS_IDLE_TIMEOUT_SECONDS * 1000 ) )
        {
            break;
        }

        if ( self fragbuttonpressed() )
        {
            break;
        }

        if ( self attackbuttonpressed() )
        {
            idleStart = gettime();
            self.spws_shopIndex = ( self.spws_shopIndex + 1 ) % level.spws_weapons.size;
            spws_refresh_hud( self );
            spws_wait_for_release( self, "attack" );
        }
        else if ( self meleebuttonpressed() )
        {
            idleStart = gettime();
            self.spws_shopIndex = self.spws_shopIndex - 1;
            if ( self.spws_shopIndex < 0 )
            {
                self.spws_shopIndex = level.spws_weapons.size - 1;
            }
            spws_refresh_hud( self );
            spws_wait_for_release( self, "melee" );
        }
        else if ( self usebuttonpressed() )
        {
            idleStart = gettime();
            spws_grant_weapon( self );
            spws_wait_for_release( self, "use" );
        }
    }

    spws_close_shop( self );
}

spws_wait_for_release( player, buttonName )
{
    while ( isdefined( player ) && spws_button_pressed( player, buttonName ) )
    {
        wait SPWS_POLL_INTERVAL;
    }
}

spws_button_pressed( player, buttonName )
{
    if ( buttonName == "attack" )
    {
        return player attackbuttonpressed();
    }

    if ( buttonName == "melee" )
    {
        return player meleebuttonpressed();
    }

    if ( buttonName == "use" )
    {
        return player usebuttonpressed();
    }

    return false;
}

spws_refresh_hud( player )
{
    if ( !isdefined( player.spws_hud ) )
    {
        return;
    }

    entry = level.spws_weapons[player.spws_shopIndex];
    player.spws_hud settext( "Free Campaign Weapon Shop - " + entry.displayName );
}

spws_grant_weapon( player )
{
    entry = level.spws_weapons[player.spws_shopIndex];
    attempts = 0;

    while ( !player loadweapons( entry.weaponName ) &&
            attempts < SPWS_LOAD_ATTEMPTS )
    {
        if ( !isdefined( player ) || !isalive( player ) )
        {
            return;
        }

        wait SPWS_POLL_INTERVAL;
        attempts++;
    }

    if ( attempts >= SPWS_LOAD_ATTEMPTS )
    {
        player iprintlnbold( entry.displayName + " is unavailable in the loaded Campaign assets." );
        println( "CampaignWeaponShop: unavailable weapon " + entry.weaponName );
        return;
    }

    player giveweapon( entry.weaponName );
    player givemaxammo( entry.weaponName );
    player switchtoweapon( entry.weaponName );
    player iprintln( "Added " + entry.displayName + " for free." );
    println( "CampaignWeaponShop: granted " + entry.weaponName );
    spws_close_shop( player );
}

spws_close_shop( player )
{
    if ( !isdefined( player ) )
    {
        return;
    }

    player.spws_shopOpen = false;

    if ( isdefined( player.spws_hud ) )
    {
        player.spws_hud destroy();
        player.spws_hud = undefined;
    }

    if ( isdefined( player.spws_hint ) )
    {
        player.spws_hint destroy();
        player.spws_hint = undefined;
    }

    player freezecontrols( false );
}

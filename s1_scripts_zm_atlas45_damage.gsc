/*
    Atlas 45 Mk2-Mk25 custom damage modifier
    Advanced Warfare Exo Zombies / S1-Mod / CBServers

    Place this file at:
        s1/scripts/zm/atlas45_damage.gsc

    Weapon:
        iw5_titan45zm_mp

    Damage progression:
        Mk1  = stock / vanilla damage
        Mk2  = 2,500 base damage
        Mk20 = 10,000 base damage
        Mk25 = 17,000 base damage

    Magazine capacity and reserve ammunition:
        Left unchanged; the normal Exo Zombies weapon-upgrade system
        controls those values.

    Hit locations:
        Left unchanged; the normal Exo Zombies damage system controls
        head, neck, helmet, and body multipliers.
*/

main()
{
    if(isdefined(level.atlas45_damage_started))
    {
        return;
    }

    level.atlas45_damage_started = 1;

    println("Atlas45: Zombies script initialized.");

    level thread atlas45_register_damage_modifier();
}

atlas45_register_damage_modifier()
{
    level endon("game_ended");

    /*
        Wait for the Zombies gametype to initialize the weapon-damage
        callback table.
    */
    for(i = 0; i < 600; i++)
    {
        if(isdefined(level.modifyweapondamage))
        {
            break;
        }

        wait 0.05;
    }

    if(!isdefined(level.modifyweapondamage))
    {
        println("Atlas45: ERROR - level.modifyweapondamage was never initialized.");
        return;
    }

    if(isdefined(level.atlas45_damage_registered))
    {
        return;
    }

    level.atlas45_damage_registered = 1;

    level.modifyweapondamage["iw5_titan45zm_mp"] =
        ::atlas45_modify_damage;

    println("Atlas45: damage modifier registered successfully.");
}

/*
    Weapon-damage callback.

    Returning the supplied damage preserves normal Mk1 behavior.
    Returning a custom base damage for Mk2-Mk25 leaves stock ammo and
    stock hit-location behavior under control of the Zombies system.
*/
atlas45_modify_damage(
    victim,
    attacker,
    damage,
    meansOfDeath,
    weapon,
    point,
    direction,
    hitLocation
)
{
    /*
        Only change damage caused by a player.
    */
    if(!isdefined(attacker) || !isplayer(attacker))
    {
        return damage;
    }

    weaponLevel = maps\mp\zombies\_util::getzombieweaponlevel(
        attacker,
        "iw5_titan45zm_mp"
    );

    /*
        Keep Mk1 completely vanilla.
    */
    if(!isdefined(weaponLevel) || weaponLevel < 2)
    {
        return damage;
    }

    if(weaponLevel > 25)
    {
        weaponLevel = 25;
    }

    /*
        Prevent the stock weapon-level damage increase from being applied
        in addition to this script's custom base-damage curve.

        This does not alter normal magazine-size or reserve-ammo upgrades.
    */
    if(isdefined(attacker.weaponstate) &&
       isdefined(attacker.weaponstate["iw5_titan45zm_mp"]))
    {
        attacker.weaponstate["iw5_titan45zm_mp"]
            ["weapon_level_increase"] = 0;
    }

    /*
        Do not process hitLocation here. This intentionally avoids custom
        head/neck/helmet multipliers so the game can retain its normal
        hit-location behavior.
    */
    return atlas45_get_base_damage(weaponLevel);
}

/*
    Piecewise-linear upgrade damage curve:

        Mk2  =  2,500
        Mk20 = 10,000
        Mk25 = 17,000

    Mk2 through Mk20:
        2500 + ((mark - 2) * 7500 / 18)

    Mk20 through Mk25:
        10000 + ((mark - 20) * 1400)
*/
atlas45_get_base_damage(mark)
{
    if(mark < 2)
    {
        mark = 2;
    }

    if(mark > 25)
    {
        mark = 25;
    }

    if(mark <= 20)
    {
        /*
            +9 rounds division to the nearest integer.
        */
        return 2500 + int(((((mark - 2) * 7500) + 9) / 18));
    }

    return 10000 + int((mark - 20) * 1400);
}
// ============================================================
// S1x Campaign - Veteran difficulty dvar (SP)
//
// Install: s1/scripts/sp/s1_scripts_sp_veteran_difficulty.gsc
// MP companion: s1_scripts_mp_veteran_difficulty.gsc (scripts/mp)
//
// Uses the same dvar as the combat training script:
//   scr_difficulty_override "veteran"
//       off          - keep the difficulty picked in the menu
//       recruit | regular | hardened | veteran
//                    - force that campaign difficulty (g_gameskill 0-3)
//       veteran_plus - force Veteran, then raise enemy accuracy by
//                      scr_difficulty_veteran_plus_accuracy
//   scr_difficulty_veteran_plus_accuracy "1.5"
//       1.0 - 3.0, multiplier for enemy AI baseaccuracy on veteran_plus
// ============================================================

main()
{
    initDvarDefault("scr_difficulty_override", "veteran");
    initDvarDefault("scr_difficulty_veteran_plus_accuracy", "1.5");

    // Set before _load runs so the level starts on the forced skill.
    skill = getForcedGameSkill();

    if (skill >= 0)
        setdvar("g_gameskill", skill);
}

init()
{
    initDvarDefault("scr_difficulty_override", "veteran");
    initDvarDefault("scr_difficulty_veteran_plus_accuracy", "1.5");

    level thread gameSkillMonitor();
    level thread veteranPlusMonitor();
}

initDvarDefault(dvar, value)
{
    if (getdvar(dvar) == "")
        setdvar(dvar, value);
}

getDifficultyProfile()
{
    profile = toLower(getdvar("scr_difficulty_override"));

    if (profile == "easy")
        profile = "recruit";
    else if (profile == "normal")
        profile = "regular";

    if (profile == "recruit" || profile == "regular" ||
        profile == "hardened" || profile == "veteran" ||
        profile == "veteran_plus")
        return profile;

    return "off";
}

// Returns -1 when the override is off.
getForcedGameSkill()
{
    profile = getDifficultyProfile();

    if (profile == "recruit")
        return 0;

    if (profile == "regular")
        return 1;

    if (profile == "hardened")
        return 2;

    if (profile == "veteran" || profile == "veteran_plus")
        return 3;

    return -1;
}

// Keeps g_gameskill / level.gameskill on the forced value, including
// after checkpoint restarts or if the menu lowers the difficulty.
gameSkillMonitor()
{
    level endon("game_ended");

    while (!isDefined(level.gameskill))
        wait 0.05;

    for (;;)
    {
        skill = getForcedGameSkill();

        if (skill >= 0 &&
            (getdvarint("g_gameskill") != skill || level.gameskill != skill))
        {
            setdvar("g_gameskill", skill);
            setdvar("saved_gameskill", skill);

            // Reloads the stock campaign difficulty tables
            // (enemy accuracy, player health/regen, grenades).
            maps\_gameskill::setskill(true);
        }

        wait 1.0;
    }
}

getVeteranPlusAccuracy()
{
    scale = getdvarfloat("scr_difficulty_veteran_plus_accuracy");

    if (scale < 1.0)
        scale = 1.0;

    if (scale > 3.0)
        scale = 3.0;

    return scale;
}

veteranPlusMonitor()
{
    level endon("game_ended");

    for (;;)
    {
        wait 0.5;

        if (getDifficultyProfile() != "veteran_plus")
            continue;

        scale = getVeteranPlusAccuracy();

        foreach (ai in getaiarray("axis"))
        {
            if (!isDefined(ai) || !isalive(ai))
                continue;

            // Only scale each AI once so the bonus never stacks.
            if (isDefined(ai.sdoVeteranPlusApplied))
                continue;

            ai.sdoVeteranPlusApplied = true;
            ai.baseaccuracy = ai.baseaccuracy * scale;
        }
    }
}

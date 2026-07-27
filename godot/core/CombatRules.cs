using System;

namespace LuodongLegendary.Core;

/// <summary>
/// Deterministic combat rules shared by offline simulation and a future authoritative server.
/// No rendering or scene nodes are referenced here.
/// </summary>
public static class CombatRules
{
    public static int CalculateDamage(int attack, int defense, float abilityRatio = 1.0f)
    {
        var rawDamage = (int)MathF.Round(attack * MathF.Max(0.1f, abilityRatio));
        return Math.Max(1, rawDamage - defense / 2);
    }

    public static int ClampHealth(int current, int maximum)
    {
        return Math.Clamp(current, 0, Math.Max(1, maximum));
    }

    public static bool CanCast(int innerPower, int cost, float cooldownRemaining)
    {
        return innerPower >= cost && cooldownRemaining <= 0.0f;
    }
}

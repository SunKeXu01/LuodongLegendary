namespace LuodongLegendary.Core;

/// <summary>
/// The stable boundary between mouse input and gameplay simulation.
/// Offline play executes these commands locally; a future online adapter serializes them.
/// </summary>
public enum PlayerCommandType
{
    Move,
    SelectTarget,
    CastAbility,
    Interact,
    Loot
}

public readonly record struct PlayerCommand(
    PlayerCommandType Type,
    float WorldX,
    float WorldZ,
    long TargetId = 0,
    string AbilityId = "");

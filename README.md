# Content Warning – Virality installer

Windows PowerShell script that installs the [Virality](https://thunderstore.io/c/content-warning/p/MaxWasUnavailable/Virality/) mod for Content Warning (bigger lobbies, late joining) including its dependencies (BepInExPack) from Thunderstore.

> **Proof of concept.** The code was written by Claude (AI). Use at your own risk, no warranty, no responsibility.
> No outside contributions (pull requests) are accepted.

## Usage

1. Close Content Warning.
2. Run in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-virality.ps1
```

The script finds the Steam install automatically. If not:

```powershell
.\install-virality.ps1 -GamePath "D:\Games\steamapps\common\Content Warning"
```

Remove the mod again (BepInEx stays):

```powershell
.\install-virality.ps1 -Uninstall
```

## Notes

- All players in the lobby need the mod.
- Mod settings: in-game under Settings > Mods > Virality.
- The game developers have blocked player-count mods before; if it stops working after a game update, the mod itself is the cause, not this script.
- This is an unofficial helper, not affiliated with the mod author or Thunderstore.

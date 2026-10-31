# Content Warning – Virality installer

Windows PowerShell script that installs the [Virality](https://thunderstore.io/c/content-warning/p/MaxWasUnavailable/Virality/) mod for Content Warning (bigger lobbies, late joining) including its dependencies (BepInExPack) from Thunderstore.

> **Proof of concept.** The code was written by Claude (AI). Use at your own risk, no warranty, no responsibility.
> No outside contributions (pull requests) are accepted.

## Usage

**Easy way:**

1. Click **Code > Download ZIP** on this page and extract the ZIP (right-click > Extract All).
2. Close Content Warning.
3. Double-click `install.bat`. Wait until it says "Done".

If Windows shows a blue "SmartScreen" warning, click **More info > Run anyway**.

**PowerShell way:**

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

## Linux (Fedora etc.)

Content Warning runs through Steam Play (Proton).

```bash
bash install-virality-linux.sh
```

Needs only `bash` and `python3` (preinstalled on Fedora). Options: `--game-path "<folder>"`, `--uninstall`.

One manual step remains: in Steam, right-click Content Warning > Properties > Launch Options and paste:

```
WINEDLLOVERRIDES="winhttp=n,b" %command%
```

## Notes

- All players in the lobby need the mod.
- Mod settings: in-game under Settings > Mods > Virality.
- The game developers have blocked player-count mods before; if it stops working after a game update, the mod itself is the cause, not this script.
- This is an unofficial helper, not affiliated with the mod author or Thunderstore.

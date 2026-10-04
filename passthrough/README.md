# Minecraft inside Red Dead 2

A passthrough mod: Red Dead Redemption 2 and Minecraft Java Edition run at the same
time, and a bridge lets you place and break Minecraft blocks in Red Dead's world.
It's built with Claude Code running on the PC that has both games.

**Red Dead Online stays off-limits.** Only play story mode with this installed, or
your account can be banned.

## Start a session

1. Install [Git for Windows](https://git-scm.com/downloads/win).
2. Install Claude Code. Open **PowerShell** and run:
   ```powershell
   irm https://claude.ai/install.ps1 | iex
   ```
   Then close PowerShell and open a new one.
3. Get this project and open it:
   ```powershell
   git clone -b claude/peaceful-cannon-ig0iky https://github.com/perwds/perwd.com.git
   cd perwd.com\passthrough
   claude
   ```
4. Type: `Read CLAUDE.md and STATUS.md, then start the next milestone.`

Next time, open PowerShell, run `cd perwd.com\passthrough` and then `claude`, and type
the same thing. `STATUS.md` remembers where you left off.

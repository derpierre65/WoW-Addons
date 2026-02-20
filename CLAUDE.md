# WoW Addons Workspace

## After every change to addon files

After every change to addon files, the modified addon must be copied to the WoW game directory:

1. Read the WoW game directory path from `MEMORY.md` in the project root.
   - If no path is stored: Ask the user for the full WoW installation path (e.g. `D:\Games\World of Warcraft\_classic_`) and save it to MEMORY.md.
2. Completely remove the target folder `<WoW-Path>\Interface\AddOns\<AddonName>`.
3. Copy the addon folder from this workspace to the target location.

PowerShell example:
```powershell
Remove-Item -Recurse -Force "<WoW-Path>\Interface\AddOns\<AddonName>"
Copy-Item -Recurse "<AddonName>" "<WoW-Path>\Interface\AddOns\<AddonName>"
```

## After bumping the version

When the version is bumped in a `.toc` file, run the build script to create a release zip:

```powershell
.\build.ps1 <AddonName>
```

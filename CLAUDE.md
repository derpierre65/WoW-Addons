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

## When the user asks to bump the version

1. Determine the version increment based on the changes since the last version bump:
   - **Patch version** (e.g. 1.1.0 → 1.1.1): Only bug fixes, no new features.
   - **Minor version** (e.g. 1.1.1 → 1.2.0): New features are included (regardless of whether bug fixes are also included).
2. Bump the version in all `.toc` files of the addon.
3. Run the build script to create a release zip:
   ```powershell
   .\build.ps1 <AddonName>
   ```
4. Output a changelog in English as text, summarizing all changes included in this version.

## Code style

- Never abbreviate variable names. Always write out full words (e.g. `checkbox` instead of `cb`, `button` instead of `btn`, `description` instead of `desc`, `label` instead of `lbl`).

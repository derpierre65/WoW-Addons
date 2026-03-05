local L = LibStub("AceLocale-3.0"):NewLocale("GuildFoundTools", "enUS", true)
if not L then return end

-- General
L["AddonTitle"] = "GuildFound Tools"
L["MinimapTooltip"] = "Click to open the window"
L["NotInGuild"] = "You are not in a guild."

-- Roles
L["RoleTank"] = "Tank"
L["RoleHealer"] = "Healer"
L["RoleDamageDealer"] = "Damage Dealer"
L["BeginnerFriendly"] = "New Players Welcome"
L["BeginnerFriendlyTooltip"] = "Indicates that you welcome new players into your group and are willing to act as a guide for them."

-- UI Tabs
L["TabGroupBrowser"] = "Group Browser"
L["TabCreateGroup"] = "Create Group"
L["TabMyGroup"] = "My Group"
L["TabProfessions"] = "Professions"

-- Group Browser
L["NoGroupsAvailable"] = "No groups available.\nCreate a group or wait for guild members."
L["ButtonSignUp"] = "Sign Up"
L["ButtonLeave"] = "Leave"
L["ContextMenuSendMessage"] = "Send Message"
L["ContextMenuInvitePlayer"] = "Invite Player"
L["TooltipMembersHeader"] = "Members:"
L["TooltipMembersSummary"] = "Members: |cffffffff%d/%s (%d/%d/%d)|r"

-- Create/Edit Group
L["LabelCategory"] = "Category:"
L["LabelDungeonRaid"] = "Dungeon/Raid:"
L["DropdownSelect"] = "-- Select --"
L["DropdownFreetext"] = "(Freetext in description)"
L["TabCreateGroupDisabled"] = "Only the party leader can create a group."
L["ValidationNoDungeonSelected"] = "No dungeon selected"
L["ValidationNoRaidSelected"] = "No raid selected"
L["LabelDescription"] = "Description (optional):"
L["LabelMaxMembers"] = "Max. Members:"
L["ButtonCreate"] = "Create"
L["ButtonRemoveGroup"] = "Remove Group"
L["ButtonEdit"] = "Edit"
L["ButtonBack"] = "Back"
L["ButtonSave"] = "Save"
L["NoSignupsYet"] = "No signups for your group yet.\nOnce guild members sign up, they will appear here."
L["MemberOfGroup"] = "You are in the group of %s."

-- Applicants
L["ButtonWithdraw"] = "Withdraw"
L["ButtonAccept"] = "Accept"
L["ButtonDecline"] = "Decline"
L["ApplicantsHeader"] = "Applicants:"
L["NoApplicantsYet"] = "No applicants yet."
L["ApplicationPending"] = "Application pending..."

-- Role Selection Popup
L["SelectRoleTitle"] = "Select Role"
L["SelectRolePrompt"] = "Which role do you want to play?"

-- Invite Confirmation
L["InviteConfirmTitle"] = "Group Invite"
L["InviteConfirmText"] = "%s wants to invite you to their group."
L["InviteConfirmLeaveWarning"] = "You will leave your current group if you accept."
L["InviteDeclinedMessage"] = "%s has declined the invite."
L["ButtonAcceptInvite"] = "Join"
L["ButtonDeclineInvite"] = "Decline"

-- Chat Messages
L["AlreadyHaveGroup"] = "You already have a group created."
L["GroupRemovedJoinedOther"] = "Your group was removed because you joined another group."

-- Professions
L["ButtonQueryProfessions"] = "Query Professions"
L["QuerySent"] = "Query sent..."
L["ResponsesReceived"] = "%d responses received"
L["OpenProfessionWindow"] = "Open profession window\nto share recipes"
L["LoadingItem"] = "Loading... (Item %d)"

-- Dungeons
L["DungeonRagefireChasm"] = "Ragefire Chasm"
L["DungeonWailingCaverns"] = "Wailing Caverns"
L["DungeonTheDeadmines"] = "The Deadmines"
L["DungeonShadowfangKeep"] = "Shadowfang Keep"
L["DungeonBlackfathomDeeps"] = "Blackfathom Deeps"
L["DungeonTheStockade"] = "The Stockade"
L["DungeonGnomeregan"] = "Gnomeregan"
L["DungeonRazorfenKraul"] = "Razorfen Kraul"
L["DungeonScarletMonasteryGraveyard"] = "Scarlet Monastery - Graveyard"
L["DungeonScarletMonasteryLibrary"] = "Scarlet Monastery - Library"
L["DungeonScarletMonasteryArmory"] = "Scarlet Monastery - Armory"
L["DungeonScarletMonasteryCathedral"] = "Scarlet Monastery - Cathedral"
L["DungeonRazorfenDowns"] = "Razorfen Downs"
L["DungeonUldaman"] = "Uldaman"
L["DungeonZulFarrak"] = "Zul'Farrak"
L["DungeonMaraudon"] = "Maraudon"
L["DungeonTheTempleOfAtalHakkar"] = "The Temple of Atal'Hakkar"
L["DungeonBlackrockDepths"] = "Blackrock Depths"
L["DungeonLowerBlackrockSpire"] = "Lower Blackrock Spire"
L["DungeonUpperBlackrockSpire"] = "Upper Blackrock Spire"
L["DungeonDireMaulEast"] = "Dire Maul East"
L["DungeonDireMaulWest"] = "Dire Maul West"
L["DungeonDireMaulNorth"] = "Dire Maul North"
L["DungeonScholomance"] = "Scholomance"
L["DungeonStratholmeMainGate"] = "Stratholme - Main Gate"
L["DungeonStratholmeServiceGate"] = "Stratholme - Service Gate"

-- Raids
L["RaidMoltenCore"] = "Molten Core"
L["RaidOnyxiasLair"] = "Onyxia's Lair"
L["RaidBlackwingLair"] = "Blackwing Lair"
L["RaidZulGurub"] = "Zul'Gurub"
L["RaidRuinsOfAhnQiraj"] = "Ruins of Ahn'Qiraj"
L["RaidTempleOfAhnQiraj"] = "Temple of Ahn'Qiraj"
L["RaidNaxxramas"] = "Naxxramas"

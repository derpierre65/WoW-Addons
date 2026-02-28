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
L["LabelDescription"] = "Description:"
L["LabelMaxMembers"] = "Max. Members:"
L["ButtonCreate"] = "Create"
L["ButtonRemoveGroup"] = "Remove Group"
L["ButtonEdit"] = "Edit"
L["ButtonBack"] = "Back"
L["ButtonSave"] = "Save"
L["NoSignupsYet"] = "No signups for your group yet.\nOnce guild members sign up, they will appear here."
L["MemberOfGroup"] = "You are in the group of %s."

-- Role Selection Popup
L["SelectRoleTitle"] = "Select Role"
L["SelectRolePrompt"] = "Which role do you want to play?"

-- Chat Messages
L["AlreadyHaveGroup"] = "You already have a group created."
L["GroupRemovedJoinedOther"] = "Your group was removed because you joined another group."

-- Professions
L["ButtonQueryProfessions"] = "Query Professions"
L["QuerySent"] = "Query sent..."
L["ResponsesReceived"] = "%d responses received"
L["OpenProfessionWindow"] = "Open profession window\nto share recipes"
L["LoadingItem"] = "Loading... (Item %d)"

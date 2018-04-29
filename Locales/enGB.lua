-- Default language template

print("Loading enGB")

local L = LibStub("AceLocale-3.0"):NewLocale("iWTB", "enGB", true)

-- General
L["Raider"] = true
L["Raid Leader"] = true
L["Expansion"] = true
L["Raid"] = true
L["Bosses"] = true
L["Select expansion"] = true
L["Select raid"] = true
L["Select boss"] = true
L["Select desirability"] = true
L["Send"] = true
L["Save & Send"] = true
L["Empty"] = true
L["Unknown desire"] = true
L["Reset DB"] = true
L["BiS"] = true
L["Need"] = true
L["Minor"] = true
L["Off spec"] = true
L["No need"] = true
L["No data"] = true
L["Remove data"] = true
L["Remove"] = true
L["Cancel"] = true
L["Close"] = true
L["Tutorial"] = true
L["Options"] = true
L["Out of raid players"] = true
L["Boss killed!"] = true
L["Add note"] = true
L["Edit note"] = true

-- Options
L["GUI"] = true
L["Data"] = true
L["Request an update from a player when they join the raid"] = true
L["Show on start"] = true
L["Hide minimap button"] = true
L["Hide the minimap button"] = true
L["Show on addon when UI loads"] = true
L["Request update on player join"] = true
L["Sync only with guild members"] = true
L["Sync only with members of your guild"] = true
L["Ignore all"] = true
L["Ignore all data sent from raiders"] = true
L["Sync only these guild ranks:"] = true
L["Sync with only players of a certain guild rank"] = true
L["Copy desire data"] = true
L["Copy desire data from one character to another"] = true
L["Show tutorial window"] = true
L["Show the tutorial window when first opened"] = true
L["Show popup on kill"] = true
L["Show a popup to change desire when boss is killed"] = true
L["Reset kill window"] = true
L["Reset the position of the boss kill popup window"] = true
L["Automatically hide"] = true
L["Automatically hide boss kill window"] = true
L["Hide kill window after:"] = true
L["Automatically hide boss kill window time (in secs)"] = true
L["Enter upto three numbers, e.g. 45, 60, 120"] = true
L["If checked, will automatically hide this window after the set interval"] = true

-- Status messages
L["Received update - "] = true
L["Removed data - "] = true
L["Sent data to raid group"] = true
L["Need to be in a raid group"] = true
L["Ignored non-guild member data - "] = true
L["Ignored data. Change in options to receive data"] = true
L["Failed to find boss name: "] = true

-- Confirmation boxes
L["Remove selected desire from ALL bosses?"] = true
L["Remove ALL raiders desire data?"] = true

-- Tutorial
L["How to use iWTB - I Want That Boss!"] = true
L["Select your \"desire\" for a raid boss from the dropdown menu. When you are in a raid group with your raid leader(s), click the \"send\" button for them to recieve the information."] = true
L["First make sure the option to \"Ignore All\" is |cffff4f5bNOT|r set (on by default)."] = true
L["If they've not already done so, ask your raiders to send their information. You will see the last message in the red bar (hover over to see more) in the Raid Leader tab."] = true
L["Select the raid boss from the dropdown menu to see raiders \"desire\". Any raider not in the raid group that you have information for will be shown in the \"Out of Raid\" window."] = true

iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
iwtb.L = LibStub("AceLocale-3.0"):GetLocale("iWTB")
local L = iwtb.L

local next = next
local wipe = wipe

--Define some vars
local db
local raiderDB
local raidLeaderDB
local rlProfileDB
local rankInfo = {} -- Guild rank info
local expacInfo = nil -- Expacs for dropdown
local raidsInfo = nil -- RaidID = ExpacID, for use on bosskillpopup
local tierRaidInstances = nil -- Raid instances for raider tab dropdown
local tierRLRaidInstances = nil 
iwtb.instanceBosses = nil -- Bosses for RL tab dropdown
local frame
local createMainFrame
local raiderBossListFrame -- main frame listing bosses (raider)
iwtb.rlRaiderListFrame = {} -- main frame listing raiders spots
iwtb.rlRaiderOverviewListFrame = {} -- overview pages
local bossKillPopup -- Pop up frame for changing desire on boss kill
local bossKillPopupSelectedDesireId = 0
iwtb.grpMemFrame = {} -- table containing each frame per group
iwtb.grpMemSlotFrame = {} -- table containing each frame per slot for each group
local bossFrame = {}-- table of frames containing each boss frame
local raiderBossesStr = "" -- raider boss desire seralised
iwtb.desire = {L["BiS"], L["Need"], L["Minor"], L["Off spec"], L["No need"]}
local bossDesire = nil
local bossKillInfo = {bossid = 0, desireid = 0, expacid = 0, instid = 0}
local gameTOCversion = 0
local raiderSelectedTier = {} -- Tier ID from dropdown Must be a better way but cba for now.
iwtb.rlSelectedTier = {} -- Must be a better way but cba for now.

--Dropdown menu frames
local expacButton = nil
local expacRLButton = nil
local instanceButton = nil
local instanceRLButton = nil
local bossesRLButton = nil

-- GUI dimensions
local GUIwindowSizeX = 850
local GUIwindowSizeY = 700
local GUItabWindowSizeX = 830
local GUItabWindowSizeY = 640
local GUItitleSizeX = 200
local GUItitleSizeY = 30
local GUItabButtonSizeX = 100
local GUItabButtonSizeY = 30
local GUIgrpSizeX = 579
local GUIgrpSizeY = 51
iwtb.GUIgrpSlotSizeX = 110
iwtb.GUIgrpSlotSizeY = 45
local GUIRStatusSizeX = 300 
local GUIRStatusSizeY = 15
local GUIkillWindowSizeX = 300
local GUIkillWindowSizeY = 160
  

-- API Calls and functions

--author: Alundaio (aka Revolucas)
function iwtb.print_table(node)
    if type(node) ~= "table" then
      print("print_table called on non-table")
      print(node)
      return
    end

    -- to make output beautiful
    local function tab(amt)
        local str = ""
        for i=1,amt do
            str = str .. "\t"
        end
        return str
    end
 
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"
 
    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end
 
        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then
               
                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end
 
                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""
               
                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end
 
                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. tab(depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v).."'"
                end
 
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                end
            end
 
            cur_index = cur_index + 1
        end
 
        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end
 
    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output,output_str)
    output_str = table.concat(output)
   
    print(output_str)
end
local print_table = iwtb.print_table

local function printTable(table)
  --print(type(table))
  if type(table) == "table" then
    for key, value in pairs(table) do
        print("k: " .. key .. " v: " .. value)
    end
  end
end

-- Iterate through the guild ranks and save index number and name in table
local function getGuildRanks() 
  local rinfo = {}
  for i=1,GuildControlGetNumRanks() do
    local rankName = GuildControlGetRankName(i)
    table.insert(rinfo, i, rankName)
  end
  return rinfo
end

-- Return expansions
local function getExpansions()
  if expacInfo == nil then
    expacInfo = {}
    for i=1, EJ_GetNumTiers() do
      local tierInfo = EJ_GetTierInfo(i)
      table.insert(expacInfo, tierInfo)
    end
  end
end

-- Return the raids per expansion
local function getInstances(expacID, isRL)
  if ( not EncounterJournal ) then
    EncounterJournal_LoadUI()
  end
  
  EJ_SelectTier(expacID)
  
  if isRL then
    tierRLRaidInstances = {}
    tierRLRaidInstances.raids = {}
    tierRLRaidInstances.order = {}
  else
    tierRaidInstances = {}
    tierRaidInstances.raids = {}
    tierRaidInstances.order = {}
  end
  
  local i = 1
  local raidCounter = 1
  local finished = false
  
  repeat
    local instanceInfoID = EJ_GetInstanceByIndex(i,true)  -- First return is instance ID
    if instanceInfoID == nil then finished = true
    else
      local _, raidTitle, _, _, _, _, _, _, _, isRaid = EJ_GetInstanceByIndex(i,true)
      if isRaid and instanceInfoID ~= 557 then -- Draenor is listed as a raid, it's not!
        if isRL then
            table.insert(tierRLRaidInstances.raids, instanceInfoID, raidTitle)
            table.insert(tierRLRaidInstances.order, raidCounter , instanceInfoID)
        else
          table.insert(tierRaidInstances.raids, instanceInfoID, raidTitle)
          table.insert(tierRaidInstances.order, raidCounter , instanceInfoID)
        end
        raidCounter = raidCounter + 1
      end
      i = i +1
      -- in case of emergency, break loop
      if i == 50 then finished = true end
    end
  until finished
end

-- Depreciated? (most likely removed for release)
-- Build raids per expansion
local function buildInstances()
  if ( not EncounterJournal ) then
    EncounterJournal_LoadUI()
  end
  
  local fullRaidInstances = {}
  
  for n=1, EJ_GetNumTiers() do
    EJ_SelectTier(n)
    local i = 1
    local raidCounter = 1
    local finished = false
    
    repeat
      local instanceInfoID = EJ_GetInstanceByIndex(i,true)  -- First return is instance ID
      if instanceInfoID == nil then finished = true
      else
        local _, _, _, _, _, _, _, _, _, isRaid = EJ_GetInstanceByIndex(i,true)
        if isRaid then
          table.insert(fullRaidInstances, instanceInfoID, n)
          raidCounter = raidCounter + 1
        end
        i = i +1
        -- in case of emergency, break loop
        if i == 50 then finished = true end
      end
    until finished
  end
  
  return fullRaidInstances
end

-- Return the bosses per raid.
local function getBosses(raidID, isRL)
  if ( not EncounterJournal ) then
    EncounterJournal_LoadUI()
  end
  
  EJ_SelectInstance(raidID)
  
  local raidBosses = {}
  raidBosses.bosses = {}
  raidBosses.order = {}
  local i = 1
  local finished = false
  
  repeat
    if EJ_GetEncounterInfoByIndex(i, raidID) == nil then finished = true
    else
      local bossName, _, bossID = EJ_GetEncounterInfoByIndex(i, raidID)
      table.insert(raidBosses.bosses, bossID, bossName)
      table.insert(raidBosses.order, i, bossID)
    end
    i = i + 1
    -- in case of emergency, break loop
    if i == 50 then finished = true end
  until finished
  
  if isRL then
    iwtb.instanceBosses = raidBosses
  else
    return raidBosses
  end
end

-- Depreciated (most likely removed for release)
local function dbSchemaCheck(level, expac)
  if raiderDB.char.expac and level == "expacs" then
    if expacInfo == nil then getExpansions() end
    for key, value in pairs(expacInfo) do -- can convert
      if raiderDB.char.expac[key] == nil then raiderDB.char.expac[key] = {} end
    end
  elseif raiderDB.char.expac and level == "inst" and type(expac) == "number" then
    for key, value in pairs(tierRaidInstances.raids) do
      if raiderDB.char.expac[expac].tier == nil then raiderDB.char.expac[expac].tier = {} end
      if raiderDB.char.expac[expac].tier[key] == nil then
        raiderDB.char.expac[expac].tier[key] = {}
        raiderDB.char.expac[expac].tier[key].bosses = {}
      end
    end
  end
end

local function dbBossValidate(instid, bossid)
  if raiderDB.char.raids[instid] == nil then raiderDB.char.raids[instid] = {} end
  if raiderDB.char.raids[instid][bossid] == nil then raiderDB.char.raids[instid][bossid] = {} end
end

local function dbCheckExists(instid, bossid, desire, note)
  if instid and bossid and desire and note then
    if raiderDB.char.raids[instid]
    and raiderDB.char.raids[instid][bossid]
    and raiderDB.char.raids[instid][bossid][desireid]
    and raiderDB.char.raids[instid][bossid][note]
    and raiderDB.char.raids[instid][bossid][note] ~= "" then
      return true
    else
      return false
    end
  elseif instid and bossid and desire then
    if raiderDB.char.raids[instid]
    and raiderDB.char.raids[instid][bossid]
    and raiderDB.char.raids[instid][bossid][desireid] then
      return true
    else
      return false
    end
  elseif instid and bossid and note then
    if raiderDB.char.raids[instid]
    and raiderDB.char.raids[instid][bossid]
    and raiderDB.char.raids[instid][bossid].note
    and raiderDB.char.raids[instid][bossid][note] ~= "" then
      return true
    else
      return false
    end
  elseif instid and bossid then
    if raiderDB.char.raids[instid]
    and raiderDB.char.raids[instid][bossid] then
      return true
    else
      return false
    end
  elseif instid then
    if raiderDB.char.raids[instid] then
      return true
    else
      return false
    end
  end
end
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------

function iwtb.convertDB(dbname)
  if dbname == "raider" then
    if raiderDB.char.expac then
      if raiderDB.char.raids == nil then raiderDB.char.raids = {} end
      wipe(raiderDB.char.raids)
      -- move all raidids to raiderDB.raids from raiderDB.expac.tier
      for expacid, expac in pairs (raiderDB.char.expac) do
        for kt,tier in pairs(expac) do
          for raidid, bosses in pairs(tier) do
            for kb, boss in pairs(bosses) do
              for bossid, desireid in pairs(boss) do
                if raiderDB.char.raids[raidid] == nil then raiderDB.char.raids[raidid] = {} end
                if raiderDB.char.raids[raidid][bossid] == nil then
                  raiderDB.char.raids[raidid][bossid] = {}
                  raiderDB.char.raids[raidid][bossid]["desireid"] = desireid
                end
              end
            end
          end
        end
      end
      --iwtb.setStatusText("raider", L["Updated raider DB"])
      print("iWTB: ", L["Updated raider DB"])
    end
  elseif dbname == "rl" then
    if iwtb.raidLeaderDB.char.raiders then
      if rlProfileDB.profile.raiders == nil then rlProfileDB.profile.raiders = {} end
      wipe(rlProfileDB.profile.raiders)
      for raider, data in pairs(iwtb.raidLeaderDB.char.raiders) do
        for expacid, expac in pairs (data.expac) do
          for kt,tier in pairs(expac) do
            for raidid, bosses in pairs(tier) do
              for kb, boss in pairs(bosses) do
                for bossid, desireid in pairs(boss) do
                  if rlProfileDB.profile.raiders[raider] == nil then rlProfileDB.profile.raiders[raider] = {} end
                  if rlProfileDB.profile.raiders[raider].raids == nil then rlProfileDB.profile.raiders[raider].raids = {} end
                  if rlProfileDB.profile.raiders[raider].raids[raidid] == nil then rlProfileDB.profile.raiders[raider].raids[raidid] = {} end
                  if rlProfileDB.profile.raiders[raider].raids[raidid][bossid] == nil then
                    rlProfileDB.profile.raiders[raider].raids[raidid][bossid] = {}
                    rlProfileDB.profile.raiders[raider].raids[raidid][bossid]["desireid"] = desireid
                  end
                end
              end
            end
          end
        end
      end
      --iwtb.setStatusText("raidleader", L["Updated raider DB"])
      print("iWTB: ", L["Updated raidleader DB"])
    end
  end
end

function iwtb.hideKillPopup()
  bossKillPopup:Hide()
end

-- For minimap icon
local iwtbLDB = LibStub("LibDataBroker-1.1"):NewDataObject("iwtb_icon", {
	type = "data source",
	text = "iWTB - I Want That Boss!",
	icon = "Interface\\Icons\\Achievement_BG_killingblow_startingrock",
  OnTooltipShow = function(tooltip)
		tooltip:AddLine("iWTB - I Want That Boss!");
	end,
	OnClick = function() 
    if iwtb.windowframe.title:IsShown() then
      iwtb.windowframe.title:Hide()
    else
      iwtb.windowframe.title:Show()
      iwtb.raidUpdate()
    end 
  end,})
local iwtbIcon = LibStub("LibDBIcon-1.0")

---------------------------------
function iwtb:OnInitialize()
---------------------------------
  
  local raiderDefaults = {
    char = {
      raids = {}, -- [raidid][desire] = n, [raidid][note] = text (plus possible later additions)
      bossListHash = "", -- this is the hash of all boss desires to be sent for comparison with the RL data (once implemented)
    },
  }
  
  -- Depreciated (most likely removed for release)
  local raidLeaderDefaults = { -- for future - boss required number tanks/healers/dps (dps is auto filled in assuming 20 or allow set max?)
    --char = {
      --raiders = {},
    --},
  }
  
  ----------------
  -- Profile DB --
  ----------------
  local rlProfileDefaults = { -- for future - boss required number tanks/healers/dps (dps is auto filled in assuming 20 or allow set max?)
    profile = {
      raiders = {},
    },
  }
  
  -- DB defaults
  local defaults = {
    char = {
        syncOnJoin = false,
        syncOnlyGuild = true,
        ignoreAll = true,
        showOnStart = false,
        syncGuildRank = {},
        showTutorial = true,
        showPopup = true,
        autoSendHash = true,
        autohideKillpopup = true,
        autohideKillTime = 60,
        killPopup = {
          anc = "RIGHT",
          x = -111,
          y = -140,
        },
        minimap = {
          hide = false,
        },
    },
  }
  
  iwtb.db = LibStub("AceDB-3.0"):New("iWTBDB", defaults)
  db = self.db
  iwtb.raiderDB = LibStub("AceDB-3.0"):New("iWTBRaiderDB", raiderDefaults)
  raiderDB = self.raiderDB
  
  -- Depreciated (most likely removed for release)
  iwtb.raidLeaderDB = LibStub("AceDB-3.0"):New("iWTBRaidLeaderDB", raidLeaderDefaults)
  raidLeaderDB = self.raidLeaderDB
  

  iwtb.rlProfileDB = LibStub("AceDB-3.0"):New("iWTBrlProfileDB", rlProfileDefaults)
  rlProfileDB = self.rlProfileDB
  
	iwtbIcon:Register("iwtb_icon", iwtbLDB, db.char.minimap)
  
  rankInfo = getGuildRanks()
  expacInfo = getExpansions()
  gameTOCversion = select(4, GetBuildInfo())
  
  local options = {
    type = "group",
    args = {
      settingsHeaderGUI = {
        name = L["GUI"],
        order = 1,
        type = "header",
      },
      settingsHeaderData = {
        name = L["Data"],
        order = 10,
        type = "header",
      },
      --[[syncOnJoin = { -- TODO
        name = L["Request update on player join"],
        order = 2,
        desc = L["Request an update from a player when they join the raid"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.syncOnJoin = true
                else 
                  db.char.syncOnJoin = false
                end 
                end,              
        get = function(info) return db.char.syncOnJoin end
      },]]
      showTutorial = {
        name = L["Show tutorial window"],
        order = 2,
        desc = L["Show the tutorial window when first opened"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.showTutorial = true
                else 
                  db.char.showTutorial = false
                end 
                end,              
        get = function(info) return db.char.showTutorial end
      },
      syncOnlyGuild = {
        name = L["Sync only with guild members"],
        order = 12,
        desc = L["Sync only with members of your guild"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.syncOnlyGuild = true
                else 
                  db.char.syncOnlyGuild = false
                end 
                end,              
        get = function(info) return db.char.syncOnlyGuild end
      },
      ignoreAll = {
        name = L["Ignore all"],
        order = 11,
        desc = L["Ignore all data sent from raiders"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.ignoreAll = true
                else 
                  db.char.ignoreAll = false
                end 
                end,              
        get = function(info) return db.char.ignoreAll end
      },
      autoSendHash = {
        name = L["Auto send on join"],
        order = 12,
        desc = L["Automatically send desires on raid join"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.autoSendHash = true
                else 
                  db.char.autoSendHash = false
                end 
                end,              
        get = function(info) return db.char.autoSendHash end
      },
      useProfileData = {
        name = L["Use raid leader data from:"],
        order = 14,
        desc = L["Use the raid leader data from another profile\/character"],
        width = "normal",
        type = "select",
        values = rlProfileDB:GetProfiles(),
        set = function(info, key, val)
                  rlProfileDB:SetProfile(rlProfileDB:GetProfiles()[key])
                end,
        get = function(info, key)
                local curProfile = rlProfileDB:GetCurrentProfile()
                local profiles, numProfiles = rlProfileDB:GetProfiles()
                for i=1, numProfiles do
                  if curProfile == profiles[i] then return i end
                end
              end
      },
      --[[showOnStart = {
        name = L["Show on start"],
        order = 3,
        desc = L["Show on addon when UI loads"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.showOnStart = true
                else 
                  db.char.showOnStart = false
                end 
                end,              
        get = function(info) return db.char.showOnStart end
      },]]
      showPopup = {
        name = L["Show popup on kill"],
        order = 5,
        desc = L["Show a popup to change desire when boss is killed"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.showPopup = true
                else 
                  db.char.showPopup = false
                end 
                end,              
        get = function(info) return db.char.showPopup end
      },
      autohideKillpopup = {
        name = L["Automatically hide boss kill window"],
        order = 6,
        desc = L["If checked, will automatically hide this window after the set interval"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.autohideKillpopup = true
                else 
                  db.char.autohideKillpopup = false
                end 
                end,              
        get = function(info) return db.char.autohideKillpopup end
      },
      autohideKillTime = {
        name = L["Hide kill window after:"],
        order = 7,
        width = "double",
        min = 15,
        max = 300,
        step = 1,
        desc = L["Automatically hide boss kill window time (in secs)"],
        type = "range",
        set = function(info,val)
                if val then 
                  db.char.autohideKillTime = val
                end 
              end,              
        get = function(info) return db.char.autohideKillTime end
      },
      resetPopup = {
        name = L["Reset kill window position"],
        order = 8,
        width = "double",
        desc = L["Reset the position of the boss kill popup window"],
        type = "execute",
        func = function()
          db.char.killPopup = {anc = "RIGHT", x = -111, y = -140}
          bossKillPopup:ClearAllPoints()
          bossKillPopup:SetPoint("RIGHT", -111, -140)
        end
      },
      showMiniBut = {
        name = L["Hide minimap button"],
        order = 3,
        desc = L["Hide the minimap button"],
        width = "double",
        type = "toggle",
        set = function(info,val)
                if val then 
                  db.char.minimap.hide = true
                  iwtbIcon:Hide("iwtb_icon")
                else 
                  db.char.minimap.hide = false
                  iwtbIcon:Show("iwtb_icon")
                end 
                end,              
        get = function(info) return db.char.minimap.hide end
      },
      --[[syncGuildRank = { -- TODO
        name = L["Sync only these guild ranks:"],
        order = 4,
        desc = L["Sync with only players of a certain guild rank"],
        width = "normal",
        type = "multiselect",
        values = rankInfo,
        set = function(info, key, val)
                  db.char.syncGuildRank[key] = val
                end,
        get = function(info, key)
                  if type(db.char.syncGuildRank) == "table" and db.char.syncGuildRank then
                    return db.char.syncGuildRank[key]
                  else
                    --reset table
                    local build = {}
                    for i=1, GuildControlGetNumRanks() do
                      table.insert(build, i, false)
                    end
                    db.char.syncGuildRank = build
                  end
                end
      },]]
      --[[copyRLdata = { -- TODO
        name = L["Copy desire data"],
        order = 5,
        desc = L["Copy desire data from one character to another"],
        width = "normal",
        type = "select",
        values = function()
                  local chars = {}
                  for k,v in pairs(raidLeaderDB) do
                    print(k,v)
                    table.insert(chars,k)
                  end
                  print_table(chars)
                  return chars
                 end,
        set = function(info, key, val)
                  print("Would copy key: " .. key)
                  print("Would copy val: " .. val)
                end,
        get = function(info, key)
                
                end
      },]]
    }
  }
  LibStub("AceConfig-3.0"):RegisterOptionsTable("iWTB", options, {"iwtb"})
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("iWTB")
  iwtb:RegisterChatCommand("iwtb", "ChatCommand")

  -- Show the GUI if no input is supplied, otherwise handle the chat input.
  function iwtb:ChatCommand(input)
    if not input or input:trim() == "" then
      if iwtb.windowframe.title:IsShown() then
        iwtb.windowframe.title:Hide()
      else
        iwtb.windowframe.title:Show()
        iwtb.raidUpdate()
      end
    else
      local cmd, arg = strsplit(" ", input)
      if cmd == "debugp" then
        --rlProfileDB:SetProfile("Renyou - Shadowsong")
        --iwtb.rlProfileDB = LibStub("AceDB-3.0"):New("iWTBrlProfileDB", rlProfileDefaults)
        --rlProfileDB = self.rlProfileDB
      else
        --print("cmd: ", cmd, " arg: ", arg)
        --LibStub("AceConfigCmd-3.0").HandleCommand(iwtb, "iwtb", "syncOnJoin", input)
      end
    end
  end
  
  -------------------------------------------------------------
  -- Move old data layout to new. [raidid][bossid]["desireid"], [raidid][bossid]["note"]
  -------------------------------------------------------------
  if next(raiderDB.char.raids) == nil then iwtb.convertDB("raider") end
  
  -------------------------------------------------------------
  -- Move old data layout to new and profile. ["profile"]["raiders"][raider][raidid][bossid]["desireid"]
  -------------------------------------------------------------
  if next(rlProfileDB.profile.raiders) == nil then iwtb.convertDB("rl") end
  
end

function iwtb:OnEnable()
  -- GUI stuff

  local fontstring
  local button
  local texture
  local raiderFrames = {}
  
  raidsInfo = buildInstances()

  --------------------------------------------------------------------
  -- DESIRABILITY MENU FUNCTIONS
  --------------------------------------------------------------------
  
  local function bossWantDropDown_OnClick(self, arg1, arg2, checked)
    -- arg1 = desire id, arg2 = boss id
    -- Desirability of the boss has changed: write to DB, change serialised string for comms, (if in the raid of the selected tier, resend to raid leader (and promoted?)?)
    --old data layout - raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[arg2] = arg1
    dbBossValidate(raiderSelectedTier.instid, arg2)
    raiderDB.char.raids[raiderSelectedTier.instid][arg2].desireid = arg1
    -- Is it too much overhead to do this each time? Have a button instead to serialises and send? Relies on raider to push a button and we know how hard they find that already!
    --raiderBossesStr = Serializer:Serialize(raiderDB.char.bosses)
    
    -- Set dropdown text to new selection
    L_UIDropDownMenu_SetSelectedID(bossFrame[arg2].dropdown, self:GetID())
    
    -- Update hash
    raiderDB.char.bossListHash = iwtb.hashData(raiderDB.char.raids) -- Do we want to hash here? Better to do it before sending or on request?
    print("raider-hash: ", raiderDB.char.bossListHash)
  end
    
  -- Fill menu with desirability list
  local function bossWantDropDown_Menu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
    local idofboss = string.match(frame:GetName(), "%d+")
    info.func = bossWantDropDown_OnClick
    for desireid, name in pairs(iwtb.desire) do
      info.text, info.arg1, info.arg2 = name, desireid, idofboss
      --if raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses ~= nil
      --and raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss] ~=nil
      --and raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss] == desireid then
      if raiderDB.char.raids[raiderSelectedTier.instid] ~= nil
      and raiderDB.char.raids[raiderSelectedTier.instid][idofboss] ~=nil
      and raiderDB.char.raids[raiderSelectedTier.instid][idofboss].desireid == desireid then
        info.checked = true
      else
        info.checked = false
      end
      L_UIDropDownMenu_AddButton(info)
    end
  end
  
  -- What to do when item is clicked
function iwtb.raidsDropdownMenuOnClick(self, arg1, arg2, checked)
    if arg2 == "expacbutton" then
      -- fill in raids with arg1 as expac id
      getInstances(arg1)
      raiderSelectedTier.expacid = arg1
      
      -- To enable selecting dropdowns programmatically
      L_UIDropDownMenu_SetText(expacButton, expacInfo[arg1])

      dbSchemaCheck("expacs")
      
    elseif arg2 == "expacrlbutton" then
      -- fill in raids with arg1 as expac id
      getInstances(arg1, true)
      iwtb.rlSelectedTier.expacid = arg1
      L_UIDropDownMenu_SetText(expacRLButton, expacInfo[arg1])
      
    elseif arg2 == "instancebutton" then
    L_UIDropDownMenu_SetText(instanceButton, tierRaidInstances.raids[arg1])
    raiderSelectedTier.instid = arg1
    dbSchemaCheck("inst", raiderSelectedTier.expacid)
      -- Generate boss frames within raiderBossListFrame
      local function genBossFrames(bossList)
        -- Create a frame for each boss with a desire dropdown.
          local i = 1
          local newColOn = 7
          local bheight, bwidth = 50, 365
          bwidth = (GUItabWindowSizeX - 50) /2
          for id, bossid in pairs(bossList.order) do -- can convert
            local y = -(bheight + 20) * i
            if i > newColOn then y = -(bheight + 20) * (i - newColOn) end
            local x = 10
            if i > newColOn then x = x + (bwidth + 10) end
            local idofboss = tostring(bossid) -- bossFrame[i] i is created with string. Fix?
            bossFrame[idofboss] = CreateFrame("Frame", "iwtbboss" .. idofboss, raiderBossListFrame)
            bossFrame[idofboss]:SetWidth(bwidth)
            bossFrame[idofboss]:SetHeight(bheight)
            bossFrame[idofboss]:SetPoint("TOP", 0, y)
            bossFrame[idofboss]:SetPoint("LEFT", raiderBossListFrame, x, 0)
            
            local creatureFrame = CreateFrame("Frame", "iwtbbosscreature" .. idofboss, bossFrame[idofboss])
            creatureFrame:SetAllPoints(creatureFrame:GetParent())
            creatureFrame:SetPoint("TOPLEFT", -65, 0)
            
            local _, bossName, _, _, bossImage = EJ_GetCreatureInfo(1, bossid)
            bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
            local creatureTex = creatureFrame:CreateTexture("iwtbcreaturetex" .. idofboss)
            creatureTex:SetPoint("TOPLEFT", 60, 13)
            creatureTex:SetTexture(bossImage)
            texture = bossFrame[idofboss]:CreateTexture("iwtbboss" .. idofboss)
            texture:SetAllPoints(bossFrame[idofboss])
            texture:SetColorTexture(0.2,0.2,0.8,0.7)
            
            -- Create a font frame to allow word-wrap
            bossFrame[idofboss].fontFrame = CreateFrame("Frame", "iwtbcreaturefontframe", bossFrame[idofboss])
            bossFrame[idofboss].fontFrame:ClearAllPoints()
            bossFrame[idofboss].fontFrame:SetHeight(bossFrame[idofboss]:GetHeight())
            bossFrame[idofboss].fontFrame:SetWidth(100)
            bossFrame[idofboss].fontFrame:SetPoint("TOPLEFT", 100, 0)
             
            fontstring = bossFrame[idofboss].fontFrame:CreateFontString("iwtbbosstext" .. idofboss)
            fontstring:SetAllPoints(bossFrame[idofboss].fontFrame)
            fontstring:SetFontObject("Game12Font")
            fontstring:SetJustifyH("LEFT")
            fontstring:SetJustifyV("MIDDLE")
            fontstring:SetText(bossList.bosses[bossid])
            
            -- Create a loot button to link to journel entry
            bossFrame[idofboss].loot = CreateFrame("Button", "iwtblootbut", bossFrame[idofboss])
            bossFrame[idofboss].loot:SetWidth(48/1.5)
            bossFrame[idofboss].loot:SetHeight(43/1.5)
            bossFrame[idofboss].loot:SetPoint("RIGHT", -135, 0)
            
            texture = bossFrame[idofboss].loot:CreateTexture("iwtblootbuttex")
            texture:SetAllPoints(texture:GetParent())
            texture:SetTexture("Interface\\EncounterJournal\\UI-EncounterJournalTextures")
            texture:SetTexCoord(0.73046875, 0.82421875, 0.61816406, 0.66015625)
            bossFrame[idofboss].loot.texture = texture
            
            bossFrame[idofboss].loot:RegisterForClicks("LeftButtonUp")
            bossFrame[idofboss].loot:SetScript("OnEnter", function(s) s:GetParent().loot.texture:SetTexCoord(0.63281250, 0.72656250, 0.61816406, 0.66015625) end)
            bossFrame[idofboss].loot:SetScript("OnLeave", function(s) s:GetParent().loot.texture:SetTexCoord(0.73046875, 0.82421875, 0.61816406, 0.66015625) end)
            bossFrame[idofboss].loot:SetScript("OnClick", function(s)
              -- Horrible fudge because I can't figure out how to go to the loot panel without an itemID...
              local difficulty = 16 -- Mythic
              -- Set to 10N for loot window
              if raiderSelectedTier.expacid < 5 then
                difficulty = 3
                EJ_SetDifficulty(3)
              elseif raiderSelectedTier.expacid == 5 and arg1 ~= 369 then
                -- Do some BS because Blizz changed to mythic on Mist last raid.
                difficulty = 3
                EJ_SetDifficulty(3)
              end
              
              EJ_SelectInstance(arg1)
              EJ_SelectEncounter(bossid)
              local itemID = EJ_GetLootInfoByIndex(1) -- Get the first item for the boss
              EncounterJournal_OpenJournal(difficulty, arg1, bossid, nil, nil, itemID)
            end)
            
            -- Create add note button
            bossFrame[idofboss].addNote = CreateFrame("Button", "iwtbaddnotebut", bossFrame[idofboss], "UIPanelButtonTemplate")
            bossFrame[idofboss].addNote:SetWidth(129)
            bossFrame[idofboss].addNote:SetHeight(20)
            bossFrame[idofboss].addNote:SetPoint("BOTTOMRIGHT", -3, 1)
            
            local bossHasNote = false
            if raiderDB.char.raids[raiderSelectedTier.instid]
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss]
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note ~= "" then -- TODO: use schema check instead
              bossHasNote = true
              bossFrame[idofboss].addNote:SetText(L["Edit note"])
            else
              bossFrame[idofboss].addNote:SetText(L["Add note"])
            end
            bossFrame[idofboss].addNote:Enable()
            bossFrame[idofboss].addNote:RegisterForClicks("LeftButtonUp")
            bossFrame[idofboss].addNote:SetScript("OnClick", function(s)
              local function saveNote(s, text)
                if s:GetText() ~= "" then
                  dbBossValidate(raiderSelectedTier.instid, idofboss)
                  raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note = s:GetText()
                  bossFrame[idofboss].addNote:SetText(L["Edit note"])
                  -- Update hash
                  raiderDB.char.bossListHash = iwtb.hashData(raiderDB.char.raids)
                end
                s:Hide()
              end
              
              local editbox = CreateFrame("EditBox", "iwtbaddnoteedit", bossFrame[idofboss].addNote, "InputBoxTemplate")
              editbox:SetSize(250, 15)
              editbox:SetPoint("BOTTOMRIGHT", 5, 0)
              editbox:HighlightText()
              editbox:SetFocus()
              
              local saveButton = CreateFrame("Button", "iwtbraidersavebutton", editbox, "UIPanelButtonTemplate")
              saveButton:SetSize(50, 15)
              saveButton:SetPoint("TOPRIGHT", 0, 0)
              saveButton:SetText(L["Save"])
              saveButton:RegisterForClicks("LeftButtonUp")
              saveButton:SetScript("OnClick", function(s)
                saveNote(s:GetParent())
              end)
              
              editbox:SetScript("OnEditFocusLost", function(s)
                s:Hide()
              end)
              
              if bossHasNote then
                local delButton = CreateFrame("Button", "iwtbraiderdelbutton", editbox, "UIPanelButtonTemplate")
                delButton:SetSize(50, 15)
                delButton:SetPoint("TOPRIGHT", -50, 0)
                delButton:SetText(L["Delete"])
                delButton:Enable()
                delButton:RegisterForClicks("LeftButtonUp")
                delButton:SetScript("OnClick", function(s)
                  raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note = ""
                  editbox:Hide()
                  bossFrame[idofboss].addNote:SetText(L["Add note"])
                end)
              end
              
              dbBossValidate(raiderSelectedTier.instid, idofboss)
              if raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note then
                editbox:SetText(raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note)
              end
              editbox:SetScript("OnKeyUp", function(s, key)
                        if key == "ESCAPE" or key == "ENTER" then
                          saveNote(s)
                        end
                      end)
              editbox:SetScript("OnEnterPressed", function(s)
                saveNote(s)
              end)
              bossFrame[idofboss].addNote.editbox = editbox
            end)
            bossFrame[idofboss].addNote:SetScript("OnEnter", function(s)
                                
                                if dbCheckExists(raiderSelectedTier.instid, idofboss, nil, true) then
                                  GameTooltip:SetOwner(s, "ANCHOR_CURSOR")
                                  GameTooltip:AddLine(raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note)
                                  GameTooltip:Show()
                                end
                              end)
            bossFrame[idofboss].addNote:SetScript("OnLeave", function(s) GameTooltip:Hide() end)
            
      
            -- add dropdown menu for need/minor/os etc.
            local bossWantdropdown = CreateFrame("Frame", "bossWantdropdown" .. bossid, bossFrame[idofboss], "L_UIDropDownMenuTemplate")
            bossWantdropdown:SetPoint("RIGHT", 12, 7)
            L_UIDropDownMenu_SetWidth(bossWantdropdown, 110)
            L_UIDropDownMenu_Initialize(bossWantdropdown, bossWantDropDown_Menu)
            bossFrame[idofboss].dropdown = bossWantdropdown
            
            --if raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses ~= nil
            --and raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss] ~= nil then
            if raiderDB.char.raids[raiderSelectedTier.instid] ~= nil
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss] ~= nil
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss].desireid then
              L_UIDropDownMenu_SetText(bossWantdropdown, iwtb.desire[raiderDB.char.raids[raiderSelectedTier.instid][idofboss].desireid])
            else
              L_UIDropDownMenu_SetText(bossWantdropdown, L["Select desirability"])
            end
            
            i = i +1
          end
        end
      
      -- Populate the raider boss list frame OR fill in the raid leader dropdown boss list

      -- get the boss list
      local bossList = getBosses(arg1)
      -- Because the frame may already be created we need to check
      
      if raiderBossListFrame:GetChildren() == nil then
        genBossFrames(bossList)
      else  
        -- We have frames in the boss list so check if they are the frames we want
        local childFrames = {raiderBossListFrame:GetChildren()}
        local haveList = false
        
        -- Search childFrames for the first boss id -- if found we should have the entire list
        -- Hide all boss frames as we are here
        for _, frame in ipairs(childFrames) do
          frame:Hide()
          if frame:GetName() == "iwtbboss" .. bossList.order[1] then haveList = true end
        end
        
        if haveList then
          -- Hide all boss frames
          for _, frame in ipairs(childFrames) do
            frame:Hide()
          end
          -- Interate over bosses and show needed frames
          for bossid, bossname in pairs(bossList.bosses) do
            local sFrameName = "iwtbboss" .. tostring(bossid)
            
            for _, frame in ipairs(childFrames) do
              -- See if we need to hide or show this frame
              if frame:GetName() == sFrameName then
                frame:Show()
              end
            end
          end
        else
          -- Hide current
          for _, frame in ipairs(childFrames) do
            frame:Hide()
          end
          -- Create a new list
          genBossFrames(bossList)
          
        end
      end
      
    elseif arg2 == "instancerlbutton" then
      L_UIDropDownMenu_SetText(instanceRLButton, tierRLRaidInstances.raids[arg1])
      iwtb.rlSelectedTier.instid = arg1
      getBosses(arg1, true)
    
    elseif arg2 == "bossesrlbutton" then -- only in RL tab
      L_UIDropDownMenu_SetText(bossesRLButton, self:GetText())
      iwtb.rlSelectedTier.bossid = arg1
      iwtb.raidUpdate()
    end
  end
  
  -- Fill menu with items
  local function raidsDropdownMenu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
    if frame:GetName() == "expacbutton" then
      -- Get expansions
      if expacInfo == nil then getExpansions() end
      info.func = iwtb.raidsDropdownMenuOnClick
      for key, value in pairs(expacInfo) do -- can convert
        info.text, info.notCheckable, info.arg1, info.arg2 = value, true, key, frame:GetName()
        L_UIDropDownMenu_AddButton(info)
      end
    
    elseif frame:GetName() == "expacrlbutton" then
      -- Get expansions
      if expacInfo == nil then getExpansions() end
      info.func = iwtb.raidsDropdownMenuOnClick
      for key, value in pairs(expacInfo) do -- can convert
        info.text, info.notCheckable, info.arg1, info.arg2 = value, true, key, frame:GetName()
        L_UIDropDownMenu_AddButton(info)
      end
      
    elseif frame:GetName() == "instancebutton" then
      -- Get raids for expac
      if tierRaidInstances ~= nil then
        info.func = iwtb.raidsDropdownMenuOnClick
        for key, value in pairs(tierRaidInstances.order) do -- Use .order as .raids is sorted by instanceid which is not in the correct order.
          info.text, info.notCheckable, info.arg1, info.arg2 = tierRaidInstances.raids[value], true, value, frame:GetName()
          L_UIDropDownMenu_AddButton(info)
        end
      end
    
    elseif frame:GetName() == "instancerlbutton" then
      -- Get raids for expac
      if tierRLRaidInstances ~= nil then
        info.func = iwtb.raidsDropdownMenuOnClick
        for key, value in pairs(tierRLRaidInstances.order) do -- Use .order as .raids is sorted by instanceid which is not in the correct order.
          info.text, info.notCheckable, info.arg1, info.arg2 = tierRLRaidInstances.raids[value], true, value, frame:GetName()
          L_UIDropDownMenu_AddButton(info)
        end
      end
      
    elseif frame:GetName() == "bossesrlbutton" then
      -- Get bosses for instance - RL only
      if iwtb.instanceBosses ~= nil then
        info.func = iwtb.raidsDropdownMenuOnClick
        for key, value in pairs(iwtb.instanceBosses.order) do -- Use .order as .raids is sorted by instanceid which is not in the correct order.
          info.text, info.notCheckable, info.arg1, info.arg2 = iwtb.instanceBosses.bosses[value], true, value, frame:GetName()
          L_UIDropDownMenu_AddButton(info)
        end
      end
    end
  end
  
  --------------------------------------------------------------------
  -- KILL POPUP BOSS MENU FUNCTIONS
  --------------------------------------------------------------------
  
  local function bossKillWantDropDown_OnClick(self, arg1, arg2, checked)
    -- arg1 = desire id, arg2 = boss id
    -- Set dropdown text to new selection
    if arg1 > 0 then
      --L_UIDropDownMenu_SetSelectedID(bossKillPopup.desireDrop, arg1) -- For "reasons" this sometimes doesn't work so SetText used instead.
      L_UIDropDownMenu_SetText(bossKillPopup.desireDrop, iwtb.desire[arg1])
    else
      L_UIDropDownMenu_SetText(bossKillPopup.desireDrop, L["Select desirability"])
    end
    bossKillPopupSelectedDesireId = self:GetID()
  end
    
  -- Fill menu with desirability list
  local function bossKillWantDropDown_Menu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
    info.func = bossKillWantDropDown_OnClick
    for desireid, name in pairs(iwtb.desire) do
      info.text, info.arg1, info.arg2 = name, desireid, bossKillPopupSelectedBossId
      if tonumber(bossKillInfo.bossid) > 0
      --and raiderDB.char.expac[bossKillInfo.expacid].tier[bossKillInfo.instid].bosses ~= nil
      --and raiderDB.char.expac[bossKillInfo.expacid].tier[bossKillInfo.instid].bosses[bossKillInfo.bossid] ~=nil
      --and raiderDB.char.expac[bossKillInfo.expacid].tier[bossKillInfo.instid].bosses[bossKillInfo.bossid] == desireid then
      and raiderDB.char.raids[bossKillInfo.instid] ~= nil
      and raiderDB.char.raids[bossKillInfo.instid][bossKillInfo.bossid] ~=nil
      and raiderDB.char.raids[bossKillInfo.instid][bossKillInfo.bossid].desireid == desireid then
        info.checked = true
      else
        info.checked = false
      end
      L_UIDropDownMenu_AddButton(info)
    end
  end
  
  ---------------------
  -- Event listeners --
  ---------------------
  
  -- BOSS_KILL
  local function bossKilled(e, id, name)
    local curInst = 0 -- EJ_GetCurrentInstance() -- 946, antorus - For 8.0 use EJ_GetInstanceForMap(C_Map.GetBestMapForUnit("player"))
    if gameTOCversion < 80000 then
      curInst = EJ_GetCurrentInstance()
    else
      curInst = EJ_GetInstanceForMap(C_Map.GetBestMapForUnit("player"))
    end
    
    --for testing
    if curInst == 0 then curInst = 946 end
    
    local function raidIdToExpacId(raidid)
      for k,v in pairs(raidsInfo) do
        if k == curInst then return v end
      end
    end
    local curExpac = raidIdToExpacId(curInst)
    
    -- As I can't find a way to cross relate these ids, we're using names...
    local function killIdToEncounterId(killid)
      local bossList = getBosses(curInst)
      for bossid, bossname in pairs(bossList.bosses) do
        if bossname == name then
          return bossid
        end
      end
      iwtb.setStatusText("raider", L["Failed to find boss name: "] .. tostring(name))
      return 0
    end
    local idofboss = tostring(killIdToEncounterId(id))
    
    if idofboss ~= "0" then
      local function bossDesire(bossid)
        if raiderDB.char.raids[curInst] ~= nil
        and raiderDB.char.raids[curInst][idofboss] ~=nil then
          bossKillPopupSelectedDesireId = raiderDB.char.raids[curInst][idofboss].desireid
          return raiderDB.char.raids[curInst][idofboss].desireid
        else
          return 0
        end
      end
      local desireofboss = bossDesire(idofboss)
      
      local _, bossName, _, _, bossImage = EJ_GetCreatureInfo(1, tonumber(idofboss))
      bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
      bossKillPopup.window.image:SetTexture(bossImage)
      bossKillPopup.window.text:SetText(name)
      
      bossKillInfo.bossid = idofboss
      bossKillInfo.desireid = desireofboss
      bossKillInfo.expacid = curExpac
      bossKillInfo.instid = curInst
      
      bossKillPopup:Show()
      bossKillWantDropDown_OnClick(bossKillPopup.desireDrop.Button, desireofboss, idofboss)
      
      -- Start timer to hide popup window
      if db.char.autohideKillpopup then self:ScheduleTimer("hideKillPopup", db.char.autohideKillTime) end
    end
  end
  
  -- Raid welcome
  local function enterInstance(e, name)
    local _, instType, diffId = GetInstanceInfo()
    if instType == "raid" and db.char.showPopup and diffId == 16 then
      iwtb:RegisterEvent("BOSS_KILL", bossKilled)
    end
  end
  
  local function joinGroup(e, arg1,arg2,arg3,arg4,arg5)
    if IsInRaid() then
      print("player in raid")
      -- Random delay between 10-30 secs to send hash to /raid
      if db.char.autoSendHash and raiderDB.char.bossListHash and raiderDB.char.bossListHash ~= "" and not iwtb.hashSentToRaid then
        print("Auto send hash to raid in 10-30 secs")
        self:ScheduleTimer("autoSendHash", math.random(10,30))
      end
    end
  end
  
  local function leftGroup()
    iwtb:UnregisterEvent("BOSS_KILL")
    iwtb.hashSentToRaid = false
  end
  
  local function playerEnteringWorld()
    -- Check if we are in a raid (having /reload etc.)
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "raid" then
      enterInstance("RAID_INSTANCE_WELCOME", "Unknown")
    end
  end
  
  -----------------------------------
  -- SLOT MENU
  -----------------------------------
  
  local function slotDropDown_OnClick(self, arg1, arg2, checked)
    -- arg1 = name, arg2 = raider id
    -- Set dropdown text to new selection
    --L_UIDropDownMenu_SetSelectedID(bossFrame[arg2]:GetChildren(), self:GetID())
  end
  
  
  -- title
  local title = CreateFrame("Button", "iwtbtitle", UIParent)
  title:SetWidth(GUItitleSizeX)
  title:SetHeight(GUItitleSizeY)
  title:SetPoint("TOP", 0, -150)
  title:SetFrameStrata("DIALOG")
  title:EnableMouse(true)
  title:SetMovable(true)
  title:RegisterForDrag("LeftButton")
  title:RegisterForClicks("LeftButtonUp")
  title:SetScript("OnDragStart", function(s) s:StartMoving() end)
  title:SetScript("OnDragStop", function(s) s:StopMovingOrSizing();end)
  title:SetScript("OnHide", function(s) s:StopMovingOrSizing() end)
  title:SetScript("OnDoubleClick", function(s)
    if iwtb.windowframe:IsShown() then iwtb.windowframe:Hide() else iwtb.windowframe:Show() end
  end)
  texture = title:CreateTexture("iwtbtitletex")
  texture:SetAllPoints(title)
  texture:SetColorTexture(0,0,0,1)
  fontstring = title:CreateFontString("iwtbtitletext")
  fontstring:SetPoint("CENTER", -5, 0)
  fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("iWTB - I Want That Boss!")
  
  button = CreateFrame("Button", "iwtbexit", title)
  button:SetWidth(12)
  button:SetHeight(12)
  button:SetPoint("CENTER", button:GetParent(), "TOPRIGHT", -8, -8)
  button:Enable()
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", function(s)
    iwtb.windowframe.title:Hide()
  end)
  button:SetScript("OnEnter", function(s) s.texture:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.5, 1, 1, 1, 1) end)
  button:SetScript("OnLeave", function(s) s.texture:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.5, 1, 1, 1, .7) end)
  --button:Show()
  
  texture = button:CreateTexture("iwtbclosebuttex")
  texture:SetTexture("Interface\\AddOns\\iWTB\\Media\\Textures\\close_white_16x16.tga")
  texture:SetSize(12,12)
  texture:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.5, 1, 1, 1, .7)
  texture:SetPoint("CENTER")
  --texture:Show()
  button.texture = texture
  
  -- Hide on esc
  tinsert(UISpecialFrames,"iwtbtitle")
  
  iwtb.windowframe = CreateFrame("Frame", "iwtbwindow", title)
  iwtb.windowframe:SetWidth(GUIwindowSizeX)
  iwtb.windowframe:SetHeight(GUIwindowSizeY)
  iwtb.windowframe:SetPoint("TOP", 0, -20)
  iwtb.windowframe:SetFrameStrata("DIALOG")
  iwtb.windowframe:SetMovable(true)
  iwtb.windowframe:EnableMouse(true)
  
  fontstring = iwtb.windowframe:CreateFontString("iwtbtitletext")
  fontstring:SetPoint("BOTTOMRIGHT", -10, 1)
  fontstring:SetTextColor(0.8,0.8,0.8,0.7)
  fontstring:SetFontObject("SystemFont_NamePlate")
  fontstring:SetText(L["Version: "] .. GetAddOnMetadata("iwtb", "version"))
  
  iwtb.windowframe.title = title

  texture = iwtb.windowframe:CreateTexture("iwtbframetexture")
  texture:SetAllPoints(texture:GetParent())
  texture:SetColorTexture(0,0,0,0.5)
  iwtb.windowframe.texture = texture
  
  -- Tutorial frame
  local tutorialFrame = CreateFrame("Frame", "iwtbtutorialframe", iwtb.windowframe)
  tutorialFrame:SetWidth(GUItabWindowSizeX-30)
  tutorialFrame:SetHeight(GUItabWindowSizeY-30)
  tutorialFrame:SetFrameStrata("FULLSCREEN")
  tutorialFrame:SetPoint("CENTER", 0, -20)
  texture = tutorialFrame:CreateTexture("iwtbtutorialtex")
  texture:SetAllPoints(tutorialFrame)
  texture:SetColorTexture(0.1,0.1,0.1,1)
  
  local tutorialHTML = CreateFrame("SimpleHTML", "iwtbtutorialhtml", tutorialFrame)
  tutorialHTML:SetWidth(GUItabWindowSizeX-100)
  tutorialHTML:SetHeight(GUItabWindowSizeY-100)
  tutorialHTML:SetPoint("CENTER", 0, 0)
  tutorialHTML:SetFontObject("Game12Font")
  tutorialHTML:SetFontObject('h1', Game20Font)
  tutorialHTML:SetFontObject('h2', Game18Font)
  tutorialHTML:SetFontObject('p', Game15Font)
  local htmlText = '<html><body>' ..
    '<h1 align="center">' .. L["How to use iWTB - I Want That Boss!"] .. '</h1>' ..
    '<br />' ..
    '<h2>|cffffde4c' .. L["Raider"] .. '|r</h2>' ..
    '<br /><p>' .. L["Select your \"desire\" for a raid boss from the dropdown menu. When you are in a raid group with your raid leader(s), click the \"send\" button for them to recieve the information."] .. '</p>' ..
    '<br /><h2>|cffffde4c' .. L["Raid Leader"] .. '|r</h2>' ..
    '<br /><p>' .. L["First make sure the option to \"Ignore All\" is |cffff4f5bNOT|r set (on by default)."] .. '</p>' ..
    '<br /><p>' .. L["If they've not already done so, ask your raiders to send their information. You will see the last message in the red bar (hover over to see more) in the Raid Leader tab."] .. '</p>' ..
    '<br /><p>' .. L["Select the raid boss from the dropdown menu to see raiders \"desire\". Any raider not in the raid group that you have information for will be shown in the \"Out of Raid\" window."] .. '</p>' ..
    '</body></html>'
  tutorialHTML:SetText(htmlText)
  
  -- Tutorial close button
  local tutorialCloseButton = CreateFrame("Button", "iwtbtutorialclosebutton", tutorialFrame, "UIPanelButtonTemplate")
  tutorialCloseButton:SetWidth(GUItabButtonSizeX)
  tutorialCloseButton:SetHeight(GUItabButtonSizeY)
  tutorialCloseButton:SetText(L["Close"])
  --tutorialCloseButton:SetFrameLevel(5)
  tutorialCloseButton:SetPoint("BOTTOMRIGHT", -10, 10)
  texture = tutorialCloseButton:CreateTexture("tutclosebuttex")
  texture:SetAllPoints(tutorialCloseButton)
  tutorialCloseButton:Enable()
  tutorialCloseButton:RegisterForClicks("LeftButtonUp")
  tutorialCloseButton:SetScript("OnClick", function(s)
    tutorialFrame:Hide()
  end)
  
  if not db.char.showTutorial then tutorialFrame:Hide() end

  -- Checkbox, hide show on start
  local tutorialCheckButton = CreateFrame("CheckButton", "iwtbtutorialcheckbutton", tutorialFrame, "ChatConfigCheckButtonTemplate")
  tutorialCheckButton:SetPoint("BOTTOMLEFT", 10, 10)
  tutorialCheckButton:SetChecked(db.char.showTutorial)
  iwtbtutorialcheckbuttonText:SetText(L["Show on start"])
  tutorialCheckButton.tooltip = L["Show the tutorial window when first opened"]
  tutorialCheckButton:SetScript("OnClick", 
    function(s)
      if not s:GetChecked() then db.char.showTutorial = false else db.char.showTutorial = true end
    end
  )
  
  ---------- 
  -- Tabs --
  ----------
  
  -- Raider tab
  iwtb.raiderTab = CreateFrame("Frame", "iwtbiwtb.raiderTab", iwtb.windowframe)
  iwtb.raiderTab:SetWidth(GUItabWindowSizeX)
  iwtb.raiderTab:SetHeight(GUItabWindowSizeY)
  iwtb.raiderTab:SetPoint("CENTER", 0, -20)
  texture = iwtb.raiderTab:CreateTexture("iwtbraidertex")
  texture:SetAllPoints(iwtb.raiderTab)
  texture:SetColorTexture(0,0,0,1)
  
  -- Raider status text panel
  raiderFrames.raiderStatusPanel = CreateFrame("Frame", "iwtbraiderstatuspanel", iwtb.raiderTab)
  raiderFrames.raiderStatusPanel:SetWidth(GUIRStatusSizeX)
  raiderFrames.raiderStatusPanel:SetHeight(GUIRStatusSizeY)
  raiderFrames.raiderStatusPanel:SetPoint("TOPRIGHT", -50, 20)
  texture = raiderFrames.raiderStatusPanel:CreateTexture("iwtbrstatusptex")
  texture:SetAllPoints(raiderFrames.raiderStatusPanel)
  texture:SetColorTexture(0.2,0,0,1)
  fontstring = raiderFrames.raiderStatusPanel:CreateFontString("iwtbrstatusptext")
  fontstring:SetAllPoints(raiderFrames.raiderStatusPanel)
  fontstring:SetFontObject("SpellFont_Small")
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  raiderFrames.raiderStatusPanel.text = fontstring
  
  raiderFrames.rStatusAnim = fontstring:CreateAnimationGroup()
  raiderFrames.rStatusAnim1 = raiderFrames.rStatusAnim:CreateAnimation("Alpha")
  raiderFrames.rStatusAnim1:SetFromAlpha(0)
  raiderFrames.rStatusAnim1:SetToAlpha(1)
  raiderFrames.rStatusAnim1:SetDuration(1.5)
  raiderFrames.rStatusAnim1:SetSmoothing("OUT")
  raiderFrames.raiderStatusPanel.anim = raiderFrames.rStatusAnim
  
  iwtb.raiderTab.raiderStatusPanel = raiderFrames.raiderStatusPanel
  
  -- made local at start because dropdown menu function uses it
  raiderBossListFrame = CreateFrame("Frame", "iwtbraiderbosslist", iwtb.raiderTab)
  raiderBossListFrame:SetWidth(GUItabWindowSizeX -20)
  raiderBossListFrame:SetHeight(GUItabWindowSizeY -20)
  raiderBossListFrame:SetPoint("CENTER", 0, 0)
  texture = raiderBossListFrame:CreateTexture("iwtbraiderbosslisttex")
  texture:SetAllPoints(raiderBossListFrame)
  texture:SetColorTexture(0.1,0.1,0.1,0.5)
  
  -- Raider send button
  raiderFrames.raiderSendButton = CreateFrame("Button", "iwtbraiderSendButton", iwtb.raiderTab, "UIPanelGoldButtonTemplate")
  raiderFrames.raiderSendButton:SetWidth(GUItabButtonSizeX+20)
  raiderFrames.raiderSendButton:SetHeight(GUItabButtonSizeY+1)
  raiderFrames.raiderSendButton:SetText(L["Send"])
  raiderFrames.raiderSendButton:SetFrameLevel(5)
  raiderFrames.raiderSendButton:SetPoint("BOTTOMRIGHT", -20, 27)
  raiderFrames.raiderSendButton:Enable()
  raiderFrames.raiderSendButton:RegisterForClicks("LeftButtonUp")
  raiderFrames.raiderSendButton:SetScript("OnClick", function(s)
    function iwtb:coolDownSend()
      s:Enable()
    end
    -- Send current desire list (to raid?)
    if not IsInRaid() then
      iwtb.setStatusText("raider", L["Need to be in a raid group"])
    else
      -- CD timer. 15 secs
      self:ScheduleTimer("coolDownSend", 15)
      iwtb.sendData("udata", raiderDB.char, "raid")
      s:Disable()
      iwtb.setStatusText("raider", L["Sent data to raid group"])
    end
  end)
  
  -- Raider test button
  local raiderTestButton = CreateFrame("Button", "iwtbraidertestbutton", iwtb.raiderTab, "UIMenuButtonStretchTemplate")
  raiderTestButton:SetWidth(GUItabButtonSizeX)
  --raiderTestButton:SetWidth(42)
  raiderTestButton:SetHeight(GUItabButtonSizeY)
  --raiderTestButton:SetHeight(40)
  raiderTestButton:SetText("Test")
  raiderTestButton:SetFrameLevel(5)
  raiderTestButton:SetPoint("BOTTOMLEFT", 270, 30)
  fontstring = raiderTestButton:CreateFontString("iwtbraidertestbuttontext")
  fontstring:SetAllPoints(raiderTestButton)
  fontstring:SetFontObject("Game18Font")
  fontstring:SetJustifyV("CENTER")
  --texture = raiderTestButton:CreateTexture("raidertestbuttex")
  --texture:SetAllPoints(raiderTestButton)
  --texture:SetPoint("TOPLEFT", 0, 0)
  --texture:SetTexture("Interface\\Buttons\\ActionBarFlyoutButton")
  --texture:SetTexCoord(0.015625,0.5859375,0.73828125,0.91796875)
  --texture:SetTexCoord(1,95,1,117,37,95,37,117)
  --texture:SetRotation(math.rad(90))
  --texture:SetSize(40,25)
  --raiderTestButton.texture = texture
  raiderTestButton:Enable()
  raiderTestButton:RegisterForClicks("LeftButtonUp")
  raiderTestButton:SetScript("OnClick", function(s)
    --iwtb.autoSendHash()
    print(iwtb.hashData(raiderDB.char.raids))
  end)
  --raiderTestButton:SetScript("OnEnter", function(s) print("enter"); s.texture:SetTexture(GlowBorderTemplate) end)
  --raiderTestButton:SetScript("OnLeave", function(s) s.texture:SetTexture(texture) end)
  --raiderTestButton:Hide()
  
  -- Raider close button
  raiderFrames.raiderCloseButton = CreateFrame("Button", "iwtbraiderCloseButton", iwtb.raiderTab, "UIPanelButtonTemplate")
  raiderFrames.raiderCloseButton:SetWidth(GUItabButtonSizeX)
  raiderFrames.raiderCloseButton:SetHeight(GUItabButtonSizeY)
  raiderFrames.raiderCloseButton:SetText(L["Close"])
  raiderFrames.raiderCloseButton:SetFrameLevel(5)
  raiderFrames.raiderCloseButton:SetPoint("BOTTOMLEFT", 20, 30)
  texture = raiderFrames.raiderCloseButton:CreateTexture("raiderclosebuttex")
  texture:SetAllPoints(raiderFrames.raiderCloseButton)
  raiderFrames.raiderCloseButton:Enable()
  raiderFrames.raiderCloseButton:RegisterForClicks("LeftButtonUp")
  raiderFrames.raiderCloseButton:SetScript("OnClick", function(s)
    iwtb.windowframe.title:Hide()
  end)
  
  -- Raider tutorial button
  local raiderTutorialButton = CreateFrame("Button", "iwtbraidertutorialbutton", iwtb.raiderTab, "UIPanelButtonTemplate")
  raiderTutorialButton:SetWidth(GUItabButtonSizeX)
  raiderTutorialButton:SetHeight(GUItabButtonSizeY)
  raiderTutorialButton:SetText(L["Tutorial"])
  raiderTutorialButton:SetFrameLevel(5)
  raiderTutorialButton:SetPoint("BOTTOMLEFT", 130, 30)
  texture = raiderTutorialButton:CreateTexture("raidertutbuttex")
  texture:SetAllPoints(raiderTutorialButton)
  raiderTutorialButton:Enable()
  raiderTutorialButton:RegisterForClicks("LeftButtonUp")
  raiderTutorialButton:SetScript("OnClick", function(s)
    tutorialFrame:Show()
  end)
  
  -- Raider reset DB button
  StaticPopupDialogs["IWTB_ResetRaiderDB"] = {
    text = L["Remove selected desire from ALL bosses?"],
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        raiderDB:ResetDB()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
  }
  
  local raiderResetDBButton = CreateFrame("Button", "iwtbraiderresetdbbutton", iwtb.raiderTab, "UIPanelButtonTemplate")
  raiderResetDBButton:SetWidth(GUItabButtonSizeX)
  raiderResetDBButton:SetHeight(GUItabButtonSizeY)
  raiderResetDBButton:SetText(L["Reset DB"])
  raiderResetDBButton:SetFrameLevel(5)
  raiderResetDBButton:SetPoint("BOTTOMRIGHT", -(GUItabButtonSizeX + 30), 30)
  texture = raiderResetDBButton:CreateTexture("raiderresetdbbuttex")
  texture:SetAllPoints(raiderResetDBButton)
  raiderResetDBButton:Enable()
  raiderResetDBButton:RegisterForClicks("LeftButtonUp")
  raiderResetDBButton:SetScript("OnClick", function(s)
    StaticPopup_Show("IWTB_ResetRaiderDB")
  end)
  
  --------------------
  -- Raider leader tab
  --------------------
  iwtb.rlTab = CreateFrame("Frame", "iwtbraidleadertab", iwtb.windowframe)
  iwtb.rlTab:SetWidth(GUItabWindowSizeX)
  iwtb.rlTab:SetHeight(GUItabWindowSizeY)
  iwtb.rlTab:SetPoint("CENTER", 0, -20)
  texture = iwtb.rlTab:CreateTexture("iwtbraidleadertex")
  texture:SetAllPoints(iwtb.rlTab)
  texture:SetColorTexture(0,0,0,1)
  
  ---------------------------
  -- Raid leader status text panel
  ---------------------------
  local rlStatusPanel = CreateFrame("Frame", "iwtbrlstatuspanel", iwtb.rlTab)
  rlStatusPanel:SetWidth(GUIRStatusSizeX)
  rlStatusPanel:SetHeight(GUIRStatusSizeY)
  rlStatusPanel:SetPoint("TOPRIGHT", -50, 20)
  
  rlStatusPanel:SetScript("OnEnter", function(s) for i=1, #iwtb.rlTab.rlStatusPanel.content do local v = iwtb.rlTab.rlStatusPanel.content[i] v:Show() end end)
  rlStatusPanel:SetScript("OnLeave", function(s) for i=1, #iwtb.rlTab.rlStatusPanel.content do local v = iwtb.rlTab.rlStatusPanel.content[i] v:Hide() end end)
    
  texture = rlStatusPanel:CreateTexture("iwtbrlstatusptex")
  texture:SetAllPoints(rlStatusPanel)
  texture:SetColorTexture(0.2,0,0,1)
  fontstring = rlStatusPanel:CreateFontString("iwtbrlstatusptext")
  fontstring:SetAllPoints(rlStatusPanel)
  fontstring:SetFontObject("SpellFont_Small")
  fontstring:SetJustifyV("CENTER")
  rlStatusPanel.text = fontstring
  
  local rlStatusAnim = fontstring:CreateAnimationGroup()
  local rlStatusAnim1 = rlStatusAnim:CreateAnimation("Alpha")
  rlStatusAnim1:SetFromAlpha(0)
  rlStatusAnim1:SetToAlpha(1)
  rlStatusAnim1:SetDuration(1.5)
  rlStatusAnim1:SetSmoothing("OUT")
  rlStatusPanel.anim = rlStatusAnim
  
  iwtb.rlTab.rlStatusPanel = rlStatusPanel
  
  -- Create 10 status lines
  local rlStatusPanelContent = {}
  for i=1,10 do
    rlStatusPanelContent[i] = CreateFrame("Frame", "iwtbrlStatusPanelContent[i]content" .. i, rlStatusPanel)
    rlStatusPanelContent[i]:SetWidth(GUIRStatusSizeX)
    rlStatusPanelContent[i]:SetHeight(GUIRStatusSizeY)
    rlStatusPanelContent[i]:SetPoint("TOPRIGHT", 0, -(GUIRStatusSizeY *i))
    rlStatusPanelContent[i]:SetFrameStrata("TOOLTIP")
    texture = rlStatusPanelContent[i]:CreateTexture("iwtbrlstatusptex")
    texture:SetAllPoints(texture:GetParent())
    texture:SetColorTexture(0.2,0,0,1)
    fontstring = rlStatusPanelContent[i]:CreateFontString("iwtbrlstatusptext")
    fontstring:SetAllPoints(rlStatusPanelContent[i])
    fontstring:SetFontObject("SpellFont_Small")
    fontstring:SetJustifyV("CENTER")
    rlStatusPanelContent[i].text = fontstring
    rlStatusPanelContent[i]:Hide()
  end
  iwtb.rlTab.rlStatusPanel.content = rlStatusPanelContent
  
  -- Raid Leader reset DB button
  StaticPopupDialogs["IWTB_ResetRaidLeaderDB"] = {
    text = L["Remove ALL raiders desire data for profile %s?"],
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        rlProfileDB:ResetDB()
        if raidLeaderDB then raidLeaderDB:ResetDB() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
  }

  -- iwtb.rlRaiderListFrame
  iwtb.rlRaiderListFrame = CreateFrame("Frame", "iwtbrlraiderlistframe", iwtb.rlTab)
  iwtb.rlRaiderListFrame:SetWidth(GUItabWindowSizeX -20)
  iwtb.rlRaiderListFrame:SetHeight(GUItabWindowSizeY -20)
  iwtb.rlRaiderListFrame:SetPoint("CENTER", 0, 0)
  texture = iwtb.rlRaiderListFrame:CreateTexture("iwtbrlraiderlistframetex")
  texture:SetAllPoints(iwtb.rlRaiderListFrame)
  texture:SetColorTexture(0.1,0.1,0.1,0.5)
  
  -- iwtb.rlRaiderOverviewFrame
  iwtb.rlRaiderOverviewFrame = CreateFrame("Frame", "iwtbrlraideroverviewframe", iwtb.rlTab)
  iwtb.rlRaiderOverviewFrame:SetWidth(GUItabWindowSizeX -20)
  iwtb.rlRaiderOverviewFrame:SetHeight(GUItabWindowSizeY -20)
  iwtb.rlRaiderOverviewFrame:SetPoint("CENTER", 0, 0)
  texture = iwtb.rlRaiderOverviewFrame:CreateTexture("iwtbrlraideroverviewframetex")
  texture:SetAllPoints(iwtb.rlRaiderOverviewFrame)
  texture:SetColorTexture(0.1,0.1,0.1,0.5)
  iwtb.rlRaiderOverviewFrame:Hide()
  
  -- Create frame for each raid spot
  for i=1, 8 do -- 8 groups of 5 slots
    local x = 20
    local y = (GUIgrpSizeY + 5) * i
    
    iwtb.grpMemFrame[i] = CreateFrame("Frame", "iwtbgrp" .. i, iwtb.rlRaiderListFrame)
    iwtb.grpMemFrame[i]:SetWidth(GUIgrpSizeX)
    iwtb.grpMemFrame[i]:SetHeight(GUIgrpSizeY)
    iwtb.grpMemFrame[i]:SetPoint("TOPLEFT",x, -y)
    local texture = iwtb.grpMemFrame[i]:CreateTexture("iwtbgrptex" .. i)
    texture:SetAllPoints(texture:GetParent())
    if i < 5 then
      texture:SetColorTexture(0,0.7,0,0.7)
    else
      texture:SetColorTexture(0.5,0.5,0.5,0.7)
    end
    iwtb.grpMemSlotFrame[i] = {}
    
    for n=1, 5 do -- 5 frames/slots per group
      local slotx = (iwtb.GUIgrpSlotSizeX * (n -1)) + (5 * n-1)
      iwtb.grpMemSlotFrame[i][n] = CreateFrame("Button", "iwtbgrpslot" .. i .. "-" .. n, iwtb.grpMemFrame[i])
      iwtb.grpMemSlotFrame[i][n]:SetWidth(iwtb.GUIgrpSlotSizeX)
      iwtb.grpMemSlotFrame[i][n]:SetHeight(iwtb.GUIgrpSlotSizeY)
      iwtb.grpMemSlotFrame[i][n]:ClearAllPoints()
      iwtb.grpMemSlotFrame[i][n]:SetAttribute("raidid", 0)
      iwtb.grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
      
      local texture = iwtb.grpMemSlotFrame[i][n]:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
      local fontstring = iwtb.grpMemSlotFrame[i][n]:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
      texture:SetAllPoints(texture:GetParent())
      texture:SetColorTexture(0.2, 0.2 ,0.2 ,1)
      iwtb.grpMemSlotFrame[i][n].texture = texture
      fontstring:SetPoint("CENTER", 0, 6)
      fontstring:SetWidth(iwtb.GUIgrpSlotSizeX - 25)
      fontstring:SetJustifyH("CENTER")
      fontstring:SetJustifyV("CENTER")
      fontstring:SetFontObject("Game12Font")
      fontstring:SetText(L["Empty"])
      iwtb.grpMemSlotFrame[i][n].nameText = fontstring
      
      iwtb.grpMemSlotFrame[i][n]:RegisterForDrag("LeftButton");
      iwtb.grpMemSlotFrame[i][n]:RegisterForClicks("RightButtonUp");
      iwtb.grpMemSlotFrame[i][n]:SetMovable(true);
      iwtb.grpMemSlotFrame[i][n]:EnableMouse(true);
      iwtb.grpMemSlotFrame[i][n]:SetScript("OnDragStart", function(s, ...) s:StartMoving() s:SetFrameStrata("TOOLTIP") end);
      iwtb.grpMemSlotFrame[i][n]:SetScript("OnDragStop", function(s, ...)
        s:StopMovingOrSizing()
        s:SetFrameStrata("FULLSCREEN")
        
        if not IsInRaid() then
          iwtb.setStatusText("raidleader", L["Need to be in a raid group"])
          iwtb.raidUpdate()
          return
        end
        
        local sourceGroup = tonumber(string.sub(s:GetName(), -3, -3))
        local mousex, mousey = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mousex = mousex / scale
        mousey = mousey / scale
        local targetgroup, targetmember = iwtb.MemberFrameContainsPoint(mousex, mousey)
        if targetgroup then
          if targetmember then
            if iwtb.grpHasEmpty(targetgroup) then
              -- Move to targetgroup
              SetRaidSubgroup(s:GetAttribute("raidid"), targetgroup)
            else
              -- Swap with targetmember
              SwapRaidSubgroup(s:GetAttribute("raidid"), iwtb.grpMemSlotFrame[targetgroup][targetmember]:GetAttribute("raidid"))
            end
          end
          
          -- Redraw group frames
          if targetgroup ~= sourceGroup then
            iwtb.raidUpdate()
          end
        end
        -- Redraw source group in case button is left outside our frames
        iwtb.raidUpdate()
      end)

      -- Context menu
      iwtb.grpMemSlotFrame[i][n].dropdown = CreateFrame("Frame", "iwtbslotcmenu" .. i .. "-" .. n , iwtb.grpMemSlotFrame[i][n], "L_UIDropDownMenuTemplate")
      iwtb.grpMemSlotFrame[i][n]:SetScript("OnClick", function(s) L_ToggleDropDownMenu(1, nil, s.dropdown, "cursor", -25, -10) end)
      L_UIDropDownMenu_Initialize(iwtb.grpMemSlotFrame[i][n].dropdown, iwtb.slotDropDown_Menu)

      -- role texture
      texture = iwtb.grpMemSlotFrame[i][n]:CreateTexture()
      texture:SetPoint("LEFT", -4, 17)
      texture:SetHeight(16)
      texture:SetWidth(16)
      texture:SetTexture("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.tga")
      texture:SetDrawLayer("OVERLAY", 7)
      iwtb.grpMemSlotFrame[i][n].roleTexture = texture
      iwtb.grpMemSlotFrame[i][n].roleTexture:Hide()
      
      -- desire label
      iwtb.grpMemSlotFrame[i][n].desireTag = CreateFrame("Frame", "iwtbgrpslotdesire" .. i .. "-" .. n, iwtb.grpMemSlotFrame[i][n])
      iwtb.grpMemSlotFrame[i][n].desireTag:SetWidth(iwtb.GUIgrpSlotSizeX - 4)
      iwtb.grpMemSlotFrame[i][n].desireTag:SetHeight((iwtb.GUIgrpSlotSizeY /2) - 6)
      iwtb.grpMemSlotFrame[i][n].desireTag:ClearAllPoints()
      iwtb.grpMemSlotFrame[i][n].desireTag:SetPoint("BOTTOM", 0, 0)
      
      local texture = iwtb.grpMemSlotFrame[i][n].desireTag:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
      iwtb.grpMemSlotFrame[i][n].desireTag.text = iwtb.grpMemSlotFrame[i][n].desireTag:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
      texture:SetAllPoints(texture:GetParent())
      texture:SetColorTexture(0,0,0.2,1)
      iwtb.grpMemSlotFrame[i][n].desireTag.text:SetPoint("CENTER")
      iwtb.grpMemSlotFrame[i][n].desireTag.text:SetJustifyH("CENTER")
      iwtb.grpMemSlotFrame[i][n].desireTag.text:SetJustifyV("BOTTOM")
      --iwtb.grpMemSlotFrame[i][n].desireTag.text:SetFont(GUIfont, 10, "")
      iwtb.grpMemSlotFrame[i][n].desireTag.text:SetFontObject("SpellFont_Small")
      iwtb.grpMemSlotFrame[i][n].desireTag.text:SetText(L["Unknown desire"])
      
      -- note
      iwtb.grpMemSlotFrame[i][n].note = CreateFrame("Frame", "iwtbgrpslotnote" .. n, iwtb.grpMemSlotFrame[i][n].desireTag)
      iwtb.grpMemSlotFrame[i][n].note:SetWidth(16)
      iwtb.grpMemSlotFrame[i][n].note:SetHeight(16)
      iwtb.grpMemSlotFrame[i][n].note:ClearAllPoints()
      iwtb.grpMemSlotFrame[i][n].note:SetPoint("BOTTOMRIGHT", 3, 0)
      
      texture = iwtb.grpMemSlotFrame[i][n].note:CreateTexture("iwtbgrpnotetex")
      texture:SetWidth(16)
      texture:SetHeight(16)
      texture:SetPoint("TOPLEFT", 0, 0)
      texture:SetDrawLayer("ARTWORK",7)
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
      iwtb.grpMemSlotFrame[i][n].note.texture = texture
      
      iwtb.grpMemSlotFrame[i][n].note:SetAttribute("hasNote", false)
      iwtb.grpMemSlotFrame[i][n].note:SetAttribute("noteTxt", "")
      iwtb.grpMemSlotFrame[i][n].note:SetScript("OnEnter", function(s)
                                  GameTooltip:SetOwner(s, "ANCHOR_CURSOR")
                                  if iwtb.grpMemSlotFrame[i][n].note:GetAttribute("hasNote") then
                                    GameTooltip:AddLine(iwtb.grpMemSlotFrame[i][n].note:GetAttribute("noteTxt"))
                                    GameTooltip:Show()
                                  end
                                end)
      iwtb.grpMemSlotFrame[i][n].note:SetScript("OnLeave", function(s) GameTooltip:Hide() end)
    end
  end
  
  local rlResetDBButton = CreateFrame("Button", "iwtbrlresetdbbutton", iwtb.rlRaiderListFrame, "UIPanelButtonTemplate")
  rlResetDBButton:SetWidth(GUItabButtonSizeX)
  rlResetDBButton:SetHeight(GUItabButtonSizeY)
  rlResetDBButton:SetText(L["Reset DB"])
  rlResetDBButton:SetPoint("BOTTOMRIGHT", -(iwtb.GUIgrpSlotSizeX + GUItabButtonSizeX + 60), 20)
  texture = rlResetDBButton:CreateTexture("rlresetdbbuttex")
  texture:SetAllPoints(rlResetDBButton)
  rlResetDBButton:Enable()
  rlResetDBButton:RegisterForClicks("LeftButtonUp")
  rlResetDBButton:SetScript("OnClick", function(s)
    StaticPopup_Show("IWTB_ResetRaidLeaderDB", rlProfileDB:GetCurrentProfile())
  end)
  
  -- Raid Leader test button
  local rlTestButton = CreateFrame("Button", "iwtbrltestbutton", iwtb.rlRaiderListFrame, "UIPanelButtonTemplate")
  rlTestButton:SetWidth(GUItabButtonSizeX)
  rlTestButton:SetHeight(GUItabButtonSizeY)
  rlTestButton:SetText("Refresh")
  rlTestButton:SetPoint("BOTTOMRIGHT", -(iwtb.GUIgrpSlotSizeX + 50), 20)
  texture = rlTestButton:CreateTexture("rltestbuttex")
  texture:SetAllPoints(rlTestButton)
  rlTestButton:Enable()
  rlTestButton:RegisterForClicks("LeftButtonUp")
  rlTestButton:SetScript("OnClick", function(s)
    iwtb.raidUpdate()
  end)
  
  -- Raid Leader Overview button
  local rlOverviewButton = CreateFrame("Button", "iwtbrloverviewbutton", iwtb.rlRaiderListFrame, "UIPanelButtonTemplate")
  rlOverviewButton:SetWidth(GUItabButtonSizeX)
  rlOverviewButton:SetHeight(GUItabButtonSizeY)
  rlOverviewButton:SetText(L["Overview"])
  rlOverviewButton:SetPoint("BOTTOMLEFT", (iwtb.GUIgrpSlotSizeX + 20), 20)
  rlOverviewButton:Enable()
  rlOverviewButton:RegisterForClicks("LeftButtonUp")
  rlOverviewButton:SetScript("OnClick", function(s)
    iwtb.rlRaiderListFrame:Hide()
    bossesRLButton:Hide()
    iwtb.drawOverviewColumnsHideAll()
    iwtb.drawOverviewColumns(iwtb.rlSelectedTier.instid)
    iwtb.overviewCreatureIconsHideAll()
    iwtb.overviewCreatureIconsHide(1)
    iwtb.drawOverviewSlotsAll()
    iwtb.rlRaiderOverviewFrame:Show()
  end)
  
  -- Raid Leader Raid view button
  local rlOverviewButton = CreateFrame("Button", "iwtbrlraidviewbutton", iwtb.rlRaiderOverviewFrame, "UIPanelButtonTemplate")
  rlOverviewButton:SetWidth(GUItabButtonSizeX)
  rlOverviewButton:SetHeight(GUItabButtonSizeY)
  rlOverviewButton:SetFrameLevel(12)
  rlOverviewButton:SetText(L["Raid view"])
  rlOverviewButton:SetPoint("BOTTOMLEFT", (iwtb.GUIgrpSlotSizeX + 20), 20)
  rlOverviewButton:Enable()
  rlOverviewButton:RegisterForClicks("LeftButtonUp")
  rlOverviewButton:SetScript("OnClick", function(s)
    iwtb.rlRaiderOverviewFrame:Hide()
    iwtb.rlRaiderListFrame:Show()
    bossesRLButton:Show()
  end)
  
  -- Raid leader overview close button
  local rlCloseButton = CreateFrame("Button", "iwtbrlovercloseButton", iwtb.rlRaiderOverviewFrame, "UIPanelButtonTemplate")
  rlCloseButton:SetWidth(GUItabButtonSizeX)
  rlCloseButton:SetHeight(GUItabButtonSizeY)
  rlCloseButton:SetFrameLevel(12)
  rlCloseButton:SetText(L["Close"])
  rlCloseButton:SetPoint("BOTTOMLEFT", 20, 20)
  rlCloseButton:Enable()
  rlCloseButton:RegisterForClicks("LeftButtonUp")
  rlCloseButton:SetScript("OnClick", function(s)
    iwtb.windowframe.title:Hide()
  end)
  
  -- Raid leader close button
  local rlCloseButton = CreateFrame("Button", "iwtbrlcloseButton", iwtb.rlRaiderListFrame, "UIPanelButtonTemplate")
  rlCloseButton:SetWidth(GUItabButtonSizeX)
  rlCloseButton:SetHeight(GUItabButtonSizeY)
  rlCloseButton:SetText(L["Close"])
  rlCloseButton:SetPoint("BOTTOMLEFT", 20, 20)
  texture = rlCloseButton:CreateTexture("rlclosebuttex")
  texture:SetAllPoints(rlCloseButton)
  rlCloseButton:Enable()
  rlCloseButton:RegisterForClicks("LeftButtonUp")
  rlCloseButton:SetScript("OnClick", function(s)
    iwtb.windowframe.title:Hide()
  end)
  
  ----------------------------
  -- Overview list (page 1)
  ---------------------------
  iwtb.rlRaiderOverviewListFrame[1] = CreateFrame("ScrollFrame", "iwtbrloverlistframe1", iwtb.rlRaiderOverviewFrame, "HybridScrollFrameTemplate") 
  iwtb.rlRaiderOverviewListFrame[1]:SetSize((iwtb.rlRaiderOverviewFrame:GetWidth() -10), (iwtb.rlRaiderOverviewFrame:GetHeight() -140))
  iwtb.rlRaiderOverviewListFrame[1]:SetPoint("TOPLEFT", iwtb.rlRaiderOverviewFrame, 0, -83)
  iwtb.rlRaiderOverviewListFrame[1]:SetClipsChildren(true)
  iwtb.rlRaiderOverviewListFrame[1]:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderOverviewListFrame[1].rlOverviewVScrollbar1:GetValue()
    iwtb.rlRaiderOverviewListFrame[1].rlOverviewVScrollbar1:SetValue(curV + -(v * 15))
  end)
  
  local texture = iwtb.rlRaiderOverviewListFrame[1]:CreateTexture("iwtboverviewlisttex1") 
  texture:SetAllPoints(texture:GetParent())
  texture:SetColorTexture(0, 0, 0, 0)
  
  fontstring = iwtb.rlRaiderOverviewListFrame[1]:CreateFontString("iwtboverviewlisttext")
  fontstring:SetPoint("CENTER",0,0)
  fontstring:SetFontObject("Game12Font")
  fontstring:SetWidth(iwtb.GUIgrpSlotSizeX -15)
  fontstring:SetJustifyV("CENTER")
  fontstring:SetTextColor(1, 1, 1, 0.8)
  fontstring:SetText(L["Raider Overview"])
  iwtb.rlRaiderOverviewListFrame[1].text = fontstring

  -- vert scrollbar 
  local rlOverviewVScrollbar1 = CreateFrame("Slider", "iwtbrloverviewvscrollbar1", iwtb.rlRaiderOverviewListFrame[1], "UIPanelScrollBarTemplate")
  rlOverviewVScrollbar1:SetPoint("TOPLEFT", iwtb.rlRaiderOverviewListFrame[1], "TOPRIGHT", -16, -63)
  rlOverviewVScrollbar1:SetPoint("BOTTOMLEFT", iwtb.rlRaiderOverviewListFrame[1], "BOTTOMRIGHT", -16, 16)
  rlOverviewVScrollbar1:SetMinMaxValues(1, 1)
  rlOverviewVScrollbar1:SetValueStep(20)
  rlOverviewVScrollbar1:SetValue(0)
  rlOverviewVScrollbar1:SetWidth(16)
  rlOverviewVScrollbar1:SetObeyStepOnDrag(true)
  rlOverviewVScrollbar1:SetScript("OnValueChanged",
  function (self, value)
    self:GetParent():SetVerticalScroll(value)
  end)
  local scrollbg = rlOverviewVScrollbar1:CreateTexture(nil, "BACKGROUND")
  scrollbg:SetAllPoints(rlOverviewVScrollbar1)
  scrollbg:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  iwtb.rlRaiderOverviewListFrame[1].rlOverviewVScrollbar1 = rlOverviewVScrollbar1
  
  -- Content frame
  local rlOverviewContent1 = CreateFrame("Frame", "iwtboverviewcontentlist1", iwtb.rlRaiderOverviewListFrame[1])
  rlOverviewContent1:SetWidth((rlOverviewContent1:GetParent():GetWidth()) -2)
  rlOverviewContent1:SetHeight(iwtb.rlRaiderOverviewListFrame[1]:GetHeight())
  --rlOverviewContent1:SetClipsChildren(true)--iwtb.rlRaiderOverviewListFrame[1]:GetHeight())
  rlOverviewContent1:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderOverviewListFrame[1].rlOverviewVScrollbar1:GetValue()
    iwtb.rlRaiderOverviewListFrame[1].rlOverviewVScrollbar1:SetValue(curV + -(v * 15))
  end)
  rlOverviewContent1:ClearAllPoints()
  rlOverviewContent1:SetPoint("TOPLEFT", 0, 0)
  local texture = rlOverviewContent1:CreateTexture()
  texture:SetAllPoints(texture:GetParent())

  iwtb.rlRaiderOverviewListFrame[1]:SetScrollChild(rlOverviewContent1)
  iwtb.rlRaiderOverviewListFrame[1].rlOverviewContent = rlOverviewContent1
  
  ----------------------------
  -- Overview list (page 2)
  ---------------------------
  iwtb.rlRaiderOverviewListFrame[2] = CreateFrame("ScrollFrame", "iwtbrloverlistframe2", iwtb.rlRaiderOverviewFrame) 
  iwtb.rlRaiderOverviewListFrame[2]:SetSize((iwtb.rlRaiderOverviewFrame:GetWidth() -20), (iwtb.rlRaiderOverviewFrame:GetHeight() -140))
  iwtb.rlRaiderOverviewListFrame[2]:SetPoint("TOPLEFT", iwtb.rlRaiderOverviewFrame, 0, -83)
  iwtb.rlRaiderOverviewListFrame[2]:SetClipsChildren(true)
  iwtb.rlRaiderOverviewListFrame[2]:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderOverviewListFrame[2].rlOverviewVScrollbar2:GetValue()
    iwtb.rlRaiderOverviewListFrame[2].rlOverviewVScrollbar2:SetValue(curV + -(v * 15))
  end)
  
  local texture = iwtb.rlRaiderOverviewListFrame[2]:CreateTexture("iwtboverviewlisttex2") 
  texture:SetAllPoints(texture:GetParent())
  texture:SetColorTexture(0, 0, 0, 0)

  -- vert scrollbar 
  local rlOverviewVScrollbar2 = CreateFrame("Slider", "iwtbrloverviewvscrollbar2", iwtb.rlRaiderOverviewListFrame[2], "UIPanelScrollBarTemplate")
  rlOverviewVScrollbar2:SetPoint("TOPLEFT", iwtb.rlRaiderOverviewListFrame[2], "TOPRIGHT", -16, -63)
  rlOverviewVScrollbar2:SetPoint("BOTTOMLEFT", iwtb.rlRaiderOverviewListFrame[2], "BOTTOMRIGHT", -16, 16)
  rlOverviewVScrollbar2:SetMinMaxValues(1, 200)
  rlOverviewVScrollbar2:SetValueStep(10)
  rlOverviewVScrollbar2:SetValue(0)
  rlOverviewVScrollbar2:SetWidth(16)
  rlOverviewVScrollbar2:SetObeyStepOnDrag(true)
  rlOverviewVScrollbar2:SetScript("OnValueChanged",
  function (self, value)
    self:GetParent():SetVerticalScroll(value)
  end)
  local scrollbg = rlOverviewVScrollbar2:CreateTexture(nil, "BACKGROUND")
  scrollbg:SetAllPoints(rlOverviewVScrollbar2)
  scrollbg:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  iwtb.rlRaiderOverviewListFrame[2].rlOverviewVScrollbar2 = rlOverviewVScrollbar2
  
  -- Content frame
  local rlOverviewContent2 = CreateFrame("Frame", "iwtboverviewcontentlist2", iwtb.rlRaiderOverviewListFrame[2])
  rlOverviewContent2:SetWidth((rlOverviewContent2:GetParent():GetWidth()) -2)
  rlOverviewContent2:SetHeight(iwtb.rlRaiderOverviewListFrame[2]:GetHeight())
  rlOverviewContent2:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderOverviewListFrame[2].rlOverviewVScrollbar2:GetValue()
    iwtb.rlRaiderOverviewListFrame[2].rlOverviewVScrollbar2:SetValue(curV + -(v * 15))
  end)
  rlOverviewContent2:ClearAllPoints()
  rlOverviewContent2:SetPoint("TOPLEFT", 0, 0)
  local texture = rlOverviewContent2:CreateTexture()
  texture:SetAllPoints(texture:GetParent())

  iwtb.rlRaiderOverviewListFrame[2]:SetScrollChild(rlOverviewContent2)
  iwtb.rlRaiderOverviewListFrame[2].rlOverviewContent = rlOverviewContent2
  
  iwtb.rlRaiderOverviewListFrame[2]:Hide()
  
  ----------------------------
  -- Overview list (page 3)
  ---------------------------
  iwtb.rlRaiderOverviewListFrame[3] = CreateFrame("ScrollFrame", "iwtbrloverlistframe3", iwtb.rlRaiderOverviewFrame) 
  iwtb.rlRaiderOverviewListFrame[3]:SetSize((iwtb.rlRaiderOverviewFrame:GetWidth() -20), (iwtb.rlRaiderOverviewFrame:GetHeight() -140))
  iwtb.rlRaiderOverviewListFrame[3]:SetPoint("TOPLEFT", iwtb.rlRaiderOverviewFrame, 0, -83)
  iwtb.rlRaiderOverviewListFrame[3]:SetClipsChildren(true)
  iwtb.rlRaiderOverviewListFrame[3]:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderOverviewListFrame[3].rlOverviewVScrollbar3:GetValue()
    iwtb.rlRaiderOverviewListFrame[3].rlOverviewVScrollbar3:SetValue(curV + -(v * 15))
  end)
  
  local texture = iwtb.rlRaiderOverviewListFrame[3]:CreateTexture("iwtboverviewlisttex3") 
  texture:SetAllPoints(texture:GetParent())
  texture:SetColorTexture(0, 0, 0, 0)

  -- vert scrollbar 
  local rlOverviewVScrollbar3 = CreateFrame("Slider", "iwtbrloverviewvscrollbar3", iwtb.rlRaiderOverviewListFrame[3], "UIPanelScrollBarTemplate")
  rlOverviewVScrollbar3:SetPoint("TOPLEFT", iwtb.rlRaiderOverviewListFrame[3], "TOPRIGHT", -16, -63)
  rlOverviewVScrollbar3:SetPoint("BOTTOMLEFT", iwtb.rlRaiderOverviewListFrame[3], "BOTTOMRIGHT", -16, 16)
  rlOverviewVScrollbar3:SetMinMaxValues(1, 200)
  rlOverviewVScrollbar3:SetValueStep(10)
  rlOverviewVScrollbar3:SetValue(0)
  rlOverviewVScrollbar3:SetWidth(16)
  rlOverviewVScrollbar3:SetObeyStepOnDrag(true)
  rlOverviewVScrollbar3:SetScript("OnValueChanged",
  function (self, value)
    self:GetParent():SetVerticalScroll(value)
  end)
  local scrollbg = rlOverviewVScrollbar3:CreateTexture(nil, "BACKGROUND")
  scrollbg:SetAllPoints(rlOverviewVScrollbar3)
  scrollbg:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  iwtb.rlRaiderOverviewListFrame[3].rlOverviewVScrollbar3 = rlOverviewVScrollbar3
  
  -- Content frame
  local rlOverviewContent3 = CreateFrame("Frame", "iwtboverviewcontentlist3", iwtb.rlRaiderOverviewListFrame[3])
  rlOverviewContent3:SetWidth((rlOverviewContent3:GetParent():GetWidth()) -2)
  rlOverviewContent3:SetHeight(iwtb.rlRaiderOverviewListFrame[3]:GetHeight())
  rlOverviewContent3:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderOverviewListFrame[3].rlOverviewVScrollbar3:GetValue()
    iwtb.rlRaiderOverviewListFrame[3].rlOverviewVScrollbar3:SetValue(curV + -(v * 15))
  end)
  rlOverviewContent3:ClearAllPoints()
  rlOverviewContent3:SetPoint("TOPLEFT", 0, 0)
  local texture = rlOverviewContent3:CreateTexture()
  texture:SetAllPoints(texture:GetParent())

  iwtb.rlRaiderOverviewListFrame[3]:SetScrollChild(rlOverviewContent3)
  iwtb.rlRaiderOverviewListFrame[3].rlOverviewContent = rlOverviewContent3
  
  iwtb.rlRaiderOverviewListFrame[3]:Hide()
  
  -- Raid leader overview prev button
  iwtb.rlOverviewPrevButton = CreateFrame("Button", "iwtbrlOverviewPrevButton", iwtb.rlRaiderOverviewFrame)
  iwtb.rlOverviewPrevButton:SetWidth(32)
  iwtb.rlOverviewPrevButton:SetHeight(32)
  iwtb.rlOverviewPrevButton:SetFrameLevel(12)
  iwtb.rlOverviewPrevButton:SetPoint("BOTTOMRIGHT", -65, 20)
  texture = iwtb.rlOverviewPrevButton:CreateTexture("rloverviewprevbuttex")
  texture:SetAllPoints(iwtb.rlOverviewPrevButton)
  texture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  iwtb.rlOverviewPrevButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
  iwtb.rlOverviewPrevButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
  iwtb.rlOverviewPrevButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
  
  iwtb.rlOverviewPrevButton:RegisterForClicks("LeftButtonUp")
  iwtb.rlOverviewPrevButton:SetScript("OnClick", function(s)
    if iwtb.rlRaiderOverviewListFrame[2]:IsShown() then
      iwtb.rlRaiderOverviewListFrame[2]:Hide()
      iwtb.rlRaiderOverviewListFrame[1]:Show()
      s:Disable()
      s:Hide()
      iwtb.rlOverviewNextButton:Enable()
      iwtb.rlOverviewNextButton:Show()
      iwtb.overviewCreatureIconsHideAll()
      iwtb.overviewCreatureIconsHide(1)
    elseif iwtb.rlRaiderOverviewListFrame[3]:IsShown() then
      iwtb.rlRaiderOverviewListFrame[3]:Hide()
      iwtb.rlRaiderOverviewListFrame[2]:Show()
      iwtb.rlOverviewNextButton:Enable()
      iwtb.rlOverviewNextButton:Show()
      iwtb.overviewCreatureIconsHideAll()
      iwtb.overviewCreatureIconsHide(2)
    end
  end)
  iwtb.rlOverviewPrevButton:Disable()
  iwtb.rlOverviewPrevButton:Hide()
  
  -- Raid leader overview next button
  iwtb.rlOverviewNextButton = CreateFrame("Button", "iwtbrloverviewnextButton", iwtb.rlRaiderOverviewFrame)
  iwtb.rlOverviewNextButton:SetWidth(32)
  iwtb.rlOverviewNextButton:SetHeight(32)
  iwtb.rlOverviewNextButton:SetFrameLevel(12)
  iwtb.rlOverviewNextButton:SetPoint("BOTTOMRIGHT", -30, 20)
  texture = iwtb.rlOverviewNextButton:CreateTexture("rloverviewnextbuttex")
  texture:SetAllPoints(iwtb.rlOverviewNextButton)
  texture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  iwtb.rlOverviewNextButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
  iwtb.rlOverviewNextButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  iwtb.rlOverviewNextButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
  
  iwtb.rlOverviewNextButton:Enable()
  iwtb.rlOverviewNextButton:RegisterForClicks("LeftButtonUp")
  iwtb.rlOverviewNextButton:SetScript("OnClick", function(s)
    if iwtb.rlRaiderOverviewListFrame[1]:IsShown() then
      iwtb.rlRaiderOverviewListFrame[1]:Hide()
      iwtb.rlRaiderOverviewListFrame[2]:Show()
      iwtb.rlOverviewPrevButton:Enable()
      iwtb.rlOverviewPrevButton:Show()
      iwtb.overviewCreatureIconsHideAll()
      iwtb.overviewCreatureIconsHide(2)
      -- check if there are 7 bosses and hide "next" if not. TODO: Fix when moving between tiers; Ant to Trial will still show next etc.
      if rlOverviewContent2:GetNumChildren() < 8 then
        s:Hide()
      end
    elseif iwtb.rlRaiderOverviewListFrame[2]:IsShown() then
      iwtb.rlRaiderOverviewListFrame[2]:Hide()
      iwtb.rlRaiderOverviewListFrame[3]:Show()
      s:Disable()
      s:Hide()
      iwtb.overviewCreatureIconsHideAll()
      iwtb.overviewCreatureIconsHide(3)
    end
  end)
  
  ----------------------------------------
  -- Out of raid scroll list for desire --
  ----------------------------------------
  iwtb.rlRaiderNotListFrame = CreateFrame("ScrollFrame", "iwtbrloorframe", iwtb.rlRaiderListFrame) 
  iwtb.rlRaiderNotListFrame:SetSize((iwtb.GUIgrpSlotSizeX +10), (iwtb.rlRaiderListFrame:GetHeight() -160))
  iwtb.rlRaiderNotListFrame:SetPoint("TOP", iwtb.rlRaiderListFrame, 0, -55)
  iwtb.rlRaiderNotListFrame:SetPoint("BOTTOMRIGHT", iwtb.rlRaiderListFrame, -30, 20)
  iwtb.rlRaiderNotListFrame:SetClipsChildren(true)
  iwtb.rlRaiderNotListFrame:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderNotListFrame.rlOoRscrollbar:GetValue()
    iwtb.rlRaiderNotListFrame.rlOoRscrollbar:SetValue(curV + -(v * 15))
  end)
  
  local texture = iwtb.rlRaiderNotListFrame:CreateTexture("iwtboorlisttex") 
  texture:SetAllPoints(texture:GetParent())
  texture:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  
  fontstring = iwtb.rlRaiderNotListFrame:CreateFontString("iwtboorlisttext")
  fontstring:SetPoint("CENTER",0,0)
  fontstring:SetFontObject("Game12Font")
  fontstring:SetWidth(iwtb.GUIgrpSlotSizeX -15)
  fontstring:SetJustifyV("CENTER")
  fontstring:SetTextColor(1, 1, 1, 0.8)
  fontstring:SetText(L["Out of raid players"])
  iwtb.rlRaiderNotListFrame.text = fontstring

  --scrollbar 
  local rlOoRscrollbar = CreateFrame("Slider", "iwtbrloorscrollbar", iwtb.rlRaiderNotListFrame, "UIPanelScrollBarTemplate")
  rlOoRscrollbar:SetPoint("TOPLEFT", iwtb.rlRaiderNotListFrame, "TOPRIGHT", 4, -16)
  rlOoRscrollbar:SetPoint("BOTTOMLEFT", iwtb.rlRaiderNotListFrame, "BOTTOMRIGHT", 4, 16)
  rlOoRscrollbar:SetMinMaxValues(1, 1)
  rlOoRscrollbar:SetValueStep(20)
  --rlOoRscrollbar.scrollStep = 10 
  rlOoRscrollbar:SetValue(0)
  rlOoRscrollbar:SetWidth(16)
  rlOoRscrollbar:SetObeyStepOnDrag(true)
  rlOoRscrollbar:SetScript("OnValueChanged",
  function (self, value)
    self:GetParent():SetVerticalScroll(value)
  end)
  local scrollbg = rlOoRscrollbar:CreateTexture(nil, "BACKGROUND")
  scrollbg:SetAllPoints(rlOoRscrollbar)
  scrollbg:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  iwtb.rlRaiderNotListFrame.rlOoRscrollbar = rlOoRscrollbar

  -- Content frame
  local rlOoRcontent = CreateFrame("Frame", "iwtbrloorlist", iwtb.rlRaiderNotListFrame)
  rlOoRcontent:SetWidth((rlOoRcontent:GetParent():GetWidth()) -2)
  rlOoRcontent:SetHeight(iwtb.rlRaiderNotListFrame:GetHeight())
  rlOoRcontent:SetScript("OnMouseWheel", function(s,v)
    local curV = iwtb.rlRaiderNotListFrame.rlOoRscrollbar:GetValue()
    iwtb.rlRaiderNotListFrame.rlOoRscrollbar:SetValue(curV + -(v * 15))
  end)
  rlOoRcontent:ClearAllPoints()
  rlOoRcontent:SetPoint("TOPLEFT", 0, 0)
  local texture = rlOoRcontent:CreateTexture()
  texture:SetAllPoints(texture:GetParent())

  iwtb.rlRaiderNotListFrame:SetScrollChild(rlOoRcontent)
  iwtb.rlRaiderNotListFrame.rlOoRcontent = rlOoRcontent
  
  ------------------------------------------------
  -- Dropdown buttons (for raid leader tab)
  ------------------------------------------------
  expacRLButton = CreateFrame("Frame", "expacrlbutton", iwtb.rlTab, "L_UIDropDownMenuTemplate")
  expacRLButton:SetPoint("TOPLEFT", 0, -20)
  L_UIDropDownMenu_SetWidth(expacRLButton, 200)
  L_UIDropDownMenu_Initialize(expacRLButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(expacRLButton, L["Select expansion"])
  
  instanceRLButton = CreateFrame("Frame", "instancerlbutton", iwtb.rlTab, "L_UIDropDownMenuTemplate")
  instanceRLButton:SetPoint("TOPLEFT", 250, -20)
  L_UIDropDownMenu_SetWidth(instanceRLButton, 200)
  L_UIDropDownMenu_Initialize(instanceRLButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(instanceRLButton, L["Select raid"])
  
  bossesRLButton = CreateFrame("Frame", "bossesrlbutton", iwtb.rlTab, "L_UIDropDownMenuTemplate")
  bossesRLButton:SetFrameLevel(7)
  bossesRLButton:SetPoint("TOPLEFT", 500, -20)
  L_UIDropDownMenu_SetWidth(bossesRLButton, 200)
  L_UIDropDownMenu_Initialize(bossesRLButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(bossesRLButton, L["Select boss"])
  
  --------------------------------------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------------------------
  
  -- Dropdown buttons (for raider tab)
  expacButton = CreateFrame("Frame", "expacbutton", iwtb.raiderTab, "L_UIDropDownMenuTemplate")
  expacButton:SetPoint("TOPLEFT", 0, -20)
  L_UIDropDownMenu_SetWidth(expacButton, 200) -- Use in place of dropDown:SetWidth
  L_UIDropDownMenu_Initialize(expacButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(expacButton, L["Select expansion"])
  
  instanceButton = CreateFrame("Frame", "instancebutton", iwtb.raiderTab, "L_UIDropDownMenuTemplate")
  instanceButton:SetPoint("TOPLEFT", 250, -20)
  L_UIDropDownMenu_SetWidth(instanceButton, 200) -- Use in place of dropDown:SetWidth
  L_UIDropDownMenu_Initialize(instanceButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(instanceButton, L["Select raid"])
  
  -- Add tab buttons
  local raiderButton = CreateFrame("Button", "$parentTab1", iwtb.windowframe, "TabButtonTemplate")
  raiderButton:SetWidth(GUItabButtonSizeX)
  raiderButton:SetHeight(GUItabButtonSizeY)
  PanelTemplates_TabResize(_G["iwtbwindowTab1"], 0, nil, GUItabButtonSizeX-30, GUItabButtonSizeY)
  raiderButton:SetText(L["Raider"])
  raiderButton:SetPoint("CENTER", raiderButton:GetParent(), "TOPLEFT", 70, -40)
  texture = raiderButton:CreateTexture("raiderbuttex")
  texture:SetAllPoints(raiderButton)
  texture:SetColorTexture(0, 0, 0, 1)
  raiderButton:Enable()
  raiderButton:RegisterForClicks("LeftButtonUp")
  raiderButton:SetScript("OnClick", function(s)
    PanelTemplates_SetTab(iwtb.windowframe, 1)
    iwtb.raiderTab:Show()
    iwtb.rlTab:Hide()
  end)
  
  local raidLeaderButton = CreateFrame("Button", "$parentTab2", iwtb.windowframe, "TabButtonTemplate")
  raidLeaderButton:SetWidth(GUItabButtonSizeX)
  raidLeaderButton:SetHeight(GUItabButtonSizeY)
  PanelTemplates_TabResize(_G["iwtbwindowTab2"], 0, nil, GUItabButtonSizeX-30, GUItabButtonSizeY)
  raidLeaderButton:SetText(L["Raid Leader"])
  raidLeaderButton:SetPoint("CENTER", raidLeaderButton:GetParent(), "TOPLEFT", 180, -40)
  texture = raidLeaderButton:CreateTexture("raiderbuttex")
  texture:SetAllPoints(raidLeaderButton)
  texture:SetColorTexture(0, 0, 0, 1)
  raidLeaderButton:Enable()
  raidLeaderButton:RegisterForClicks("LeftButtonUp")
  raidLeaderButton:SetScript("OnClick", function(s)
    PanelTemplates_SetTab(iwtb.windowframe, 2)     -- 1 because we want tab 1 selected.
    iwtb.rlTab:Show()  -- Hide all other pages (in this case only one).
    iwtb.raidUpdate()
    iwtb.raiderTab:Hide()  -- Show page 1.
  end)
  
  local optionsButton = CreateFrame("Button", "$parentTab3", iwtb.windowframe, "TabButtonTemplate")
  optionsButton:SetWidth(GUItabButtonSizeX)
  optionsButton:SetHeight(GUItabButtonSizeY)
  PanelTemplates_TabResize(_G["iwtbwindowTab3"], 0, nil, GUItabButtonSizeX-30, GUItabButtonSizeY)
  optionsButton:SetText(L["Options"])
  optionsButton:SetPoint("CENTER", optionsButton:GetParent(), "TOPLEFT", 290, -40)
  texture = optionsButton:CreateTexture("raiderbuttex")
  texture:SetAllPoints(optionsButton)
  texture:SetColorTexture(0, 0, 0, 1)
  optionsButton:Enable()
  optionsButton:RegisterForClicks("LeftButtonUp")
  optionsButton:SetScript("OnClick", function(s)
    iwtb.windowframe.title:Hide()
    InterfaceCategoryList_Update()
    InterfaceOptionsOptionsFrame_RefreshCategories()
    InterfaceAddOnsList_Update()
    InterfaceOptionsFrame_OpenToCategory("iWTB")
  end)
  
  -------------------------
  -- Kill boss window popup
  -------------------------
  
  bossKillPopup = CreateFrame("Frame", "iwtbkillpopup", UIParent)
  bossKillPopup:SetWidth(GUIkillWindowSizeX)
  bossKillPopup:SetHeight(23)
  bossKillPopup:SetPoint(db.char.killPopup.anc, db.char.killPopup.x, db.char.killPopup.y)
  bossKillPopup:SetFrameStrata("DIALOG")
  bossKillPopup:EnableMouse(true)
  bossKillPopup:SetMovable(true)
  bossKillPopup:RegisterForDrag("LeftButton")
  bossKillPopup:SetScript("OnDragStart", function(s) s:StartMoving() end)
  bossKillPopup:SetScript("OnDragStop", function(s) s:StopMovingOrSizing()
    _, _, db.char.killPopup.anc, db.char.killPopup.x, db.char.killPopup.y = s:GetPoint()
  end)
  bossKillPopup:SetScript("OnHide", function(s) s:StopMovingOrSizing() end)

  texture = bossKillPopup:CreateTexture("iwtbbosskillpopuptex")
  texture:SetAllPoints(bossKillPopup)
  texture:SetColorTexture(0,0,0,1)
  
  fontstring = bossKillPopup:CreateFontString("iwtbkillpopuptitletext")
  fontstring:SetPoint("LEFT", 10, 0)
  fontstring:SetFontObject("Game15Font")
  fontstring:SetTextColor(1, 1, 1, 0.8)
  fontstring:SetText(L["Boss killed!"])
  bossKillPopup.text = fontstring
  
  -- window frame
  local bossKillPopupWindow = CreateFrame("Frame", "iwtbkillpopupwindow", bossKillPopup)
  bossKillPopupWindow:SetWidth(GUIkillWindowSizeX)
  bossKillPopupWindow:SetHeight(GUIkillWindowSizeY)
  bossKillPopupWindow:SetPoint("TOP", 0, -23)
  bossKillPopupWindow:SetFrameStrata("DIALOG")
  
  texture = bossKillPopupWindow:CreateTexture("iwtbbossKillPopupWindowtex")
  texture:SetAllPoints(bossKillPopupWindow)
  texture:SetColorTexture(0,0,0,0.7)
  
  fontstring = bossKillPopupWindow:CreateFontString("iwtbkillpopuptitletext")
  fontstring:SetPoint("BOTTOMLEFT", 19, 70)
  fontstring:SetFontObject("Game15Font")
  fontstring:SetTextColor(1, 1, 1, 0.8)
  fontstring:SetText("test")
  bossKillPopupWindow.text = fontstring
  
  local creatureTex = bossKillPopupWindow:CreateTexture("iwtbkillpopupimagetex")
  creatureTex:SetPoint("TOPLEFT", 15, -5)
  creatureTex:SetTexCoord(0, 1, 0, 0.99)
  creatureTex:SetDrawLayer("ARTWORK",7)
  creatureTex:SetTexture("Interface\\EncounterJournal\\UI-EJ-BOSS-Default")
  
  bossKillPopupWindow.image = creatureTex
  
  bossKillPopup.window = bossKillPopupWindow
  
  -- close X button
  button = CreateFrame("Button", "iwtbkillpopupexit", bossKillPopup, "UIPanelCloseButton")
  button:SetWidth(40)
  button:SetHeight(40)
  button:SetPoint("TOPRIGHT", 9, 9)
  button:Enable()
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", function(s)
    bossKillPopup:Hide()
  end)
  
  -- Kill popup close button
  local bossKillPopupClose = CreateFrame("Button", "iwtbbosskillpopupclose", bossKillPopupWindow, "UIPanelButtonTemplate")
  bossKillPopupClose:SetWidth(GUItabButtonSizeX)
  bossKillPopupClose:SetHeight(GUItabButtonSizeY)
  bossKillPopupClose:SetText(L["Close"])
  bossKillPopupClose:SetPoint("BOTTOMLEFT", 15, 33)
  texture = bossKillPopupClose:CreateTexture("killclosebuttex")
  texture:SetAllPoints(bossKillPopupClose)
  bossKillPopupClose:Enable()
  bossKillPopupClose:RegisterForClicks("LeftButtonUp")
  bossKillPopupClose:SetScript("OnClick", function(s)
    bossKillPopup:Hide()
  end)
  
  -- Kill popup test button
  local bossKillPopupTest = CreateFrame("Button", "iwtbbosskillpopuptest", bossKillPopupWindow, "UIPanelButtonTemplate")
  bossKillPopupTest:SetWidth(GUItabButtonSizeX)
  bossKillPopupTest:SetHeight(GUItabButtonSizeY)
  bossKillPopupTest:SetText("test")
  bossKillPopupTest:SetPoint("TOPRIGHT", 10, -10)
  texture = bossKillPopupTest:CreateTexture("killtestbuttex")
  texture:SetAllPoints(bossKillPopupTest)
  bossKillPopupTest:Enable()
  bossKillPopupTest:RegisterForClicks("LeftButtonUp")
  bossKillPopupTest:SetScript("OnClick", function(s)
    bossKillPopup:ClearAllPoints()
    bossKillPopup:SetPoint("RIGHT", -80, -220)
    --buildInstances()
  end)
  bossKillPopupTest:Hide()
  
  -- Kill popup save and send button
  local bossKillPopupSend = CreateFrame("Button", "iwtbbossKillPopupSend", bossKillPopupWindow, "UIPanelButtonTemplate")
  bossKillPopupSend:SetWidth(GUItabButtonSizeX)
  bossKillPopupSend:SetHeight(GUItabButtonSizeY)
  bossKillPopupSend:SetText(L["Save & Send"])
  bossKillPopupSend:SetPoint("BOTTOMRIGHT", -15, 33)
  texture = bossKillPopupSend:CreateTexture("killtestbuttex")
  texture:SetAllPoints(bossKillPopupSend)
  bossKillPopupSend:Enable()
  bossKillPopupSend:RegisterForClicks("LeftButtonUp")
  bossKillPopupSend:SetScript("OnClick", function(s)
    if bossKillPopupSelectedDesireId > 0 then
      raiderDB.char.raids[bossKillInfo.instid][bossKillInfo.bossid].desireid = bossKillPopupSelectedDesireId -- setting this twice? Already done in kill function?
      L_UIDropDownMenu_SetSelectedID(bossFrame[bossKillInfo.bossid].dropdown, bossKillPopupSelectedDesireId)
      raiderDB.char.bossListHash = iwtb.hashData(raiderDB.char.raids)
      -- Send current desire list to raid
      if not IsInRaid() then
        iwtb.setStatusText("raider", L["Need to be in a raid group"])
      else
        iwtb.sendData("udata", raiderDB.char, "raid")
        iwtb.setStatusText("raider", L["Sent data to raid group"])
      end
    end
    bossKillPopup:Hide()
  end)
  
  -- Dropdown
  local bossKillPopupDesireDrop = CreateFrame("Frame", "bosskillpopupdesiredrop", bossKillPopupWindow, "L_UIDropDownMenuTemplate")
  bossKillPopupDesireDrop:SetPoint("TOPRIGHT", -10, -42)
  L_UIDropDownMenu_SetWidth(bossKillPopupDesireDrop, 100)
  L_UIDropDownMenu_Initialize(bossKillPopupDesireDrop, bossKillWantDropDown_Menu)
  L_UIDropDownMenu_SetText(bossKillPopupDesireDrop, L["Select desirability"])
  
  bossKillPopup.desireDrop = bossKillPopupDesireDrop
  
  -- Auto close tick box
  local bossKillPopupButton = CreateFrame("CheckButton", "iwtbkillcheckbutton", bossKillPopupWindow, "ChatConfigCheckButtonTemplate")
  bossKillPopupButton:SetPoint("BOTTOMLEFT", 15, 5)
  bossKillPopupButton:SetChecked(db.char.autohideKillpopup)
  iwtbkillcheckbuttonText:SetText(L["Automatically hide"])
  bossKillPopupButton.tooltip = L["If checked, will automatically hide this window after the set interval"]
  bossKillPopupButton:SetScript("OnClick", 
    function(s)
      if not s:GetChecked() then db.char.autohideKillpopup = false else db.char.autohideKillpopup = true end
    end
  )
  
  bossKillPopup:Hide()
  
  ----------------
  -- Register tabs
  ----------------
  PanelTemplates_SetNumTabs(iwtb.windowframe, 3)  -- 2 because there are 2 frames total.
  PanelTemplates_SetTab(iwtb.windowframe, 1)     -- 1 because we want tab 1 selected.
  iwtb.raiderTab:Show()  -- Show page 1.
  iwtb.rlTab:Hide()  -- Hide all other pages (in this case only one).
  
  -- Hide or show main window on start via options
  if db.char.showOnStart then
    iwtb.windowframe.title:Show()
  end
  
  -- Set the dropdowns programmatically. Allow this via options?
  iwtb.raidsDropdownMenuOnClick(expacButton.Button,7,"expacbutton")
  iwtb.raidsDropdownMenuOnClick(expacRLButton.Button,7,"expacrlbutton")
  iwtb.raidsDropdownMenuOnClick(instanceButton.Button,946,"instancebutton")
  iwtb.raidsDropdownMenuOnClick(instanceRLButton.Button,946,"instancerlbutton")
  
  -- Register listening events
  iwtb:RegisterEvent("GROUP_ROSTER_UPDATE", iwtb.raidUpdate)
  iwtb:RegisterEvent("RAID_INSTANCE_WELCOME", enterInstance)
  iwtb:RegisterEvent("GROUP_LEFT", leftGroup)
  iwtb:RegisterEvent("GROUP_JOINED", joinGroup)
  iwtb:RegisterEvent("PLAYER_ENTERING_WORLD", playerEnteringWorld)

end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
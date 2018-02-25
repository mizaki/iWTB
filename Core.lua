iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local AceGUI = LibStub("AceGUI-3.0")


--Define some vars

  
-- API Calls and functions

--http://lua-users.org/wiki/CsvUtils
function fromCSV (s)
  local seperator = ','
  s = s .. seperator        -- ending comma
  local t = {}        -- table to collect fields
  local fieldstart = 1
  repeat
    -- next field is quoted? (start with `"'?)
    if string.find(s, '^"', fieldstart) then
      local a, c
      local i  = fieldstart
      repeat
        -- find closing quote
        a, i, c = string.find(s, '"("?)', i+1)
      until c ~= '"'    -- quote not followed by quote?
      if not i then error('unmatched "') end
      local f = string.sub(s, fieldstart+1, i-1)
      table.insert(t, (string.gsub(f, '""', '"')))
      fieldstart = string.find(s, seperator, i) + 1
    else                -- unquoted; find next comma
      local nexti = string.find(s, seperator, fieldstart)
      table.insert(t, string.sub(s, fieldstart, nexti-1))
      fieldstart = nexti + 1
    end
  until fieldstart > string.len(s)
  return t
end

--Interate through the guild ranks and save index and name in table
local function getGuildRanks() 
  local numRanks = GuildControlGetNumRanks()
  local rinfo = {}

  for i=1,numRanks do
    local rankName = GuildControlGetRankName(i)
    table.insert(rinfo, i, rankName)
  end
  
  return rinfo
end

--Find and populate expansion info
local function getExpansions()
  local numExpac = EJ_GetNumTiers()
  local expacInfo = {}

  for i=1, numExpac do
    local tierInfo = EJ_GetTierInfo(i)
    table.insert(expacInfo, tierInfo)
  end
  
  return expacInfo
end

local function getInstances(expacID)
  EJ_SelectTier(expacID)
  local tierRaidInstances = {}
  tierRaidInstances.raids = {}
  tierRaidInstances.order = {}
  local i = 1
  local raidCounter = 1
  local finished = false
  
  repeat
    local instanceInfoID = EJ_GetInstanceByIndex(i,true)  -- Returns string ID _ONLY_
    
    if instanceInfoID == nil then finished = true
    else
      local isRaid = select("10",EJ_GetInstanceByIndex(i,true))
      local raidTitle = select("2",EJ_GetInstanceByIndex(i,true))
      
      if isRaid then
        table.insert(tierRaidInstances.raids, instanceInfoID, raidTitle)
        table.insert(tierRaidInstances.order, raidCounter , instanceInfoID)
        raidCounter = raidCounter + 1
      end
      
      i = i +1
      --break loop in case we fuck up
      if i == 30 then finished = true end
    end
    
  until finished
  
  return tierRaidInstances
end

local function getBosses(raidID)
  local raidBosses = {}
  raidBosses.bosses = {}
  raidBosses.order = {}
  local i = 1
  local finished = false
  
  repeat
    
    if EJ_GetEncounterInfoByIndex(i, raidID) == nil then finished = true
    else
      local bossName = select(1, EJ_GetEncounterInfoByIndex(i, raidID))
      local bossID = select(3, EJ_GetEncounterInfoByIndex(i, raidID))
      table.insert(raidBosses.bosses, bossID, bossName)
      table.insert(raidBosses.order, i, bossID)
      --print("BossID: " .. bossID .. " Boss: " .. bossName)
    end
    
    i = i + 1
    --break loop in case we fuck up
    if i == 30 then finished = true end
  until finished
  
  return raidBosses
end

function iwtb:OnInitialize()
  -- Called when the addon is loaded
  self:Print("Loading iWTB")
  
  local rankInfo = getGuildRanks()
  local expacsInfo = getExpansions()
  --[[for key, value in pairs(expacsInfo) do
    print(key, value)
  end
  self:Print(type(expacsInfo))]]
  
  -- DB defaults
  local defaults = {
    char = {
        syncOnJoin = true,
        syncOnlyGuild = true,
        syncGuildRank = 1,
        syncGuildRank = {false, false, false, false, false, false, false, false, false, false},
    },
  }
  
  self.db = LibStub("AceDB-3.0"):New("iWTBDB", defaults)
  local db = self.db
  local L = LibStub("AceLocale-3.0"):GetLocale("iWTB")
  
  options = {
    type = "group",
    args = {
      settingsHeader = {
        name = "Settings",
        order = 1,
        type = "header",
      },
      syncOnJoin = {
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
      },
      syncOnlyGuild = {
        name = L["Sync only with guild members"],
        order = 3,
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
      syncGuildRank = {
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
      },
    }
  }
  LibStub("AceConfig-3.0"):RegisterOptionsTable("iWTB", options, {"iwtb"})
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("iWTB")
  
  --self:RegisterChatCommand("iWTBrank", "getGuildRanks")
  
  -- GUI stuff
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("iWTB - I Want That Boss!")
  frame:SetStatusText("Container Frame")
  frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
  -- Fill Layout - the TabGroup widget will fill the whole frame
  frame:SetLayout("Fill")
  
  -- function that draws the widgets for the first tab
  local function DrawRaiderTab(container)
    local desc = AceGUI:Create("Label")
    desc:SetText(L["Raider"])
    desc:SetFullWidth(true)
    container:AddChild(desc)
    
    local bosses = AceGUI:Create("Dropdown")
    bosses:SetText(L["Bosses"])
    bosses:SetWidth(200)
    bosses:SetList({L["Select raid"]})
    bosses:SetCallback("OnValueChanged", function(boss)

    end)
    
    local raid = AceGUI:Create("Dropdown")
    raid:SetText(L["Raid"])
    raid:SetWidth(200)
    raid:SetList({L["Select expansion"]})
    raid:SetCallback("OnValueChanged", function(instance)
      local bossesInfo = getBosses(instance.value)

      bosses:SetList(bossesInfo.bosses, bossesInfo.order)
    
    end)
    
    local expansion = AceGUI:Create("Dropdown")
    expansion:SetText(L["Expansion"])
    expansion:SetWidth(200)
    expansion:SetList(expacsInfo)
    expansion:SetCallback("OnValueChanged", function(expac)
      local raidInfo = getInstances(expac.value)
      raid:SetList(raidInfo.raids, raidInfo.order)
    end)
    
    container:AddChild(expansion)
    container:AddChild(raid)
    container:AddChild(bosses)
    
    
    
    local dumpVar = AceGUI:Create("Button")
    dumpVar:SetText("Dump var")
    dumpVar:SetWidth(200)
    dumpVar:SetCallback("OnClick", function(but)
      local test = getInstances(7)
      for key, value in pairs(test.raids) do
          print(key, value)
      end
      for key, value in pairs(test.order) do
          print(key, value)
      end
      --self:Print(test[1])
      --self:Print(type(EJ_GetInstanceByIndex(1,true)))
      --self:Print(fromCSV(type(EJ_GetInstanceByIndex(1,true))))
      --self:Print(fromCSV(EJ_GetInstanceInfo(822))[1])
      --print(select("#", EJ_GetInstanceInfo(822)))
      --print(select(1, EJ_GetInstanceInfo(822)))
      --print(select(2, EJ_GetInstanceInfo(822)))
      --print(select(3, EJ_GetInstanceInfo(822)))
      --print(select(9, EJ_GetInstanceInfo(822)))
    end)
    container:AddChild(dumpVar)
  end

  -- function that draws the widgets for the second tab
  local function DrawRLTab(container)
    local desc = AceGUI:Create("Label")
    desc:SetText(L["Raid Leader"])
    desc:SetFullWidth(true)
    container:AddChild(desc)
    
    local button = AceGUI:Create("Button")
    button:SetText("Tab 2 Button")
    button:SetWidth(200)
    container:AddChild(button)
  end

  -- Callback function for OnGroupSelected
  local function SelectGroup(container, event, group)
     container:ReleaseChildren()
     if group == "raider" then
        DrawRaiderTab(container)
     elseif group == "raidleader" then
        DrawRLTab(container)
     end
  end


  -- Create the TabGroup
  local tab =  AceGUI:Create("TabGroup")
  tab:SetLayout("Flow")
  -- Setup which tabs to show
  tab:SetTabs({{text=L["Raider"], value="raider"}, {text=L["Raid Leader"], value="raidleader"}})
  -- Register callback
  tab:SetCallback("OnGroupSelected", SelectGroup)
  -- Set initial Tab (this will fire the OnGroupSelected callback)
  tab:SelectTab("raider")

  -- add to the frame container
  frame:AddChild(tab)
  
end

function iwtb:OnEnable()
    -- Called when the addon is enabled
    self:Print("I want that boss!")
end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
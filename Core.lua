iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local AceGUI = LibStub("AceGUI-3.0")


--Define some vars

  
-- API Calls and functions

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
  
  local i = 1
  while EJ_GetInstanceByIndex(i) do
    local instanceInfo = EJ_GetInstanceByIndex(i)
    if instanceInfo[10] then
      table.insert(tierRaidInstances, instanceInfo[1], instanceInfo[2])
    end
    
    i = i +1
  end
  
  return tierRaidInstances
end

local function getExpBosses(raidID)
  local expacBosses = {}

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
    
    local expansion = AceGUI:Create("Dropdown")
    expansion:SetText(L["Expansion"])
    expansion:SetWidth(200)
    expansion:SetList(expacsInfo)
    container:AddChild(expansion)
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
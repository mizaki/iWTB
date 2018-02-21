iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0")
local Serializer = LibStub("AceSerializer-3.0")

--Define some vars
local rankInfo = {}
  
-- API Calls and functions

--Interate through the guild ranks and save index and name in table
local function getGuildRanks() 
  local numRanks = GuildControlGetNumRanks()

  for i=1,numRanks do
    local rankName = GuildControlGetRankName(i)
    table.insert(rankInfo, i, rankName)
  end
  print("rankInfo")
  
  return rankInfo
end

function iwtb:OnInitialize()
  -- Called when the addon is loaded
  self:Print("Loading iWTB")
  
  rankinfo = getGuildRanks()
  
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
  db.char.syncGuildRank = "test"
  
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
                  --self:Print(tostring(key) .. tostring(val))
                  db.char.syncGuildRank["key"] = val
                end,
        get = function(info)
                  
                  --self:Print(Serializer:Serialize(rankInfo))
                  if type(db.char.syncGuildRank) == "table" and db.char.syncGuildRank ~= nil then
                    --self:Print(table.unpack(db.char.syncGuildRank))
                    --self:Print(db.char.syncGuildRank)
                    --self:Print(table.unpack(rankInfo))

                    return db.char.syncGuildRank
                  else
                    --reset table
                    db.char.syncGuildRank = {false, false, false, false, false, false, false, false, false, false}
                    self:Print("reset table rank info")
                    
                    for key, value in pairs(db.char.syncGuildRank) do
                        print(key, value)
                    end
                  end
                end
      },
    }
  }
  LibStub("AceConfig-3.0"):RegisterOptionsTable("iWTB", options, {"iwtb"})
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("iWTB")
  
  --self:RegisterChatCommand("iWTBrank", "getGuildRanks")
  
  
end

function iwtb:OnEnable()
    -- Called when the addon is enabled
    self:Print("I want that boss!")
end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
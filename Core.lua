iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0")

function iwtb:OnInitialize()
  -- Called when the addon is loaded
  
  -- DB defaults
  local defaults = {
    char = {
        syncOnJoin = true,
    },
  }
  
  self.db = LibStub("AceDB-3.0"):New("iWTBDB", defaults)
  local L = LibStub("AceLocale-3.0"):GetLocale("iWTB")
  
  self:Print("Loading iWTB")
  
  optionsTable = {
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
                  self.db.char.syncOnJoin = true
                else 
                  self.db.char.syncOnJoin = false
                end 
                --[[if BossList.frame.visible then
                  --BossList.frame:Show()
                --end]]
                end,              
        get = function(info) return self.db.char.syncOnJoin end
      },
    }
  }
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WelcomeHome", options, {"iwtb"})
end

function iwtb:OnEnable()
    -- Called when the addon is enabled
    self:Print("I want that boss!")
end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
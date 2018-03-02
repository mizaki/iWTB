iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("iWTB")

--Define some vars
local db
local raiderDB
local raidLeaderDB
local rankInfo = {}
local expacInfo = nil
local tierRaidInstances = nil
local frame
local windowframe
local raiderFrame
local rlMainFrame
local createMainFrame
local raiderBossListFrame
local desire = {L["BiS"], L["Need"], L["Minor"], L["Off spec"], L["No need"]}
local bossDesire = nil

--Dropdown menu frames
local expacButton = nil
local instanceButton = nil

-- GUI dimensions
local GUIwindowSizeX = 700
local GUIwindowSizeY = 600
local GUItabWindowSizeX = 680
local GUItabWindowSizeY = 540
local GUItitleSizeX = 200
local GUItitleSizeY = 30
local GUItabButtonSizeX = 100
local GUItabButtonSizeY = 30
  
-- API Calls and functions

local function printTable(table)
  --print(type(table))
  if type(table) == "table" then
    if table == nil then print("Empty table") end
    for key, value in pairs(table) do
        print(key, value)
    end
  end
end

--Interate through the guild ranks and save index number and name in table
local function getGuildRanks() 
  --local numRanks = GuildControlGetNumRanks()
  local rinfo = {}

  for i=1,GuildControlGetNumRanks() do
    local rankName = GuildControlGetRankName(i)
    table.insert(rinfo, i, rankName)
  end
  
  return rinfo
end

--Return expansions
local function getExpansions()
  --local numExpac = EJ_GetNumTiers()
  if expacInfo == nil then
    expacInfo = {}
    for i=1, EJ_GetNumTiers() do
      local tierInfo = EJ_GetTierInfo(i)
      table.insert(expacInfo, tierInfo)
    end
  end
  
  --return expacInfo
end

-- Return the raids per expansion
local function getInstances(expacID)
  EJ_SelectTier(expacID)
  tierRaidInstances = {}
  tierRaidInstances.raids = {}
  tierRaidInstances.order = {}
  local i = 1
  local raidCounter = 1
  local finished = false
  
  repeat
    local instanceInfoID = EJ_GetInstanceByIndex(i,true)  -- First return is instance ID
    
    if instanceInfoID == nil then finished = true
    else
      local isRaid = select(10,EJ_GetInstanceByIndex(i,true))
      local raidTitle = select(2,EJ_GetInstanceByIndex(i,true))
      
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
  
  --return tierRaidInstances
end

-- Return the bosses per raid.
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

  local raiderDefaults = {  -- bosses[id].desire
    char = {
      bosses = {},
    },
  }
  
  
  local raiderLeaderDefaults = { -- is there any? boss required number tanks/healers/dps (dps is auto filled in assuming 20 or allow set max?)
  
  }
  
  -- DB defaults
  local defaults = {
    char = {
        syncOnJoin = true,
        syncOnlyGuild = true,
        syncGuildRank = {false, false, false, false, false, false, false, false, false, false}, -- Is this correct?
    },
  }
  
  self.db = LibStub("AceDB-3.0"):New("iWTBDB", defaults)
  db = self.db
  raiderDB = LibStub("AceDB-3.0"):New("iWTBRaiderDB", raiderDefaults)
  raidLeaderDB = LibStub("AceDB-3.0"):New("iWTBRaidLeaderDB", raidLeaderDefaults)
  
  rankInfo = getGuildRanks()
  expacsInfo = getExpansions()
  
  --raiderDB:ResetDB()
  
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
  iwtb:RegisterChatCommand("iwtb", "ChatCommand")

  -- Show the GUI if no input is supplied, otherwise handle the chat input.
  function iwtb:ChatCommand(input)
    -- Assuming "MyOptions" is the appName of a valid options table
    if not input or input:trim() == "" then
      --LibStub("AceConfigDialog-3.0"):Open("iWTB")
      if windowframe:IsShown() then
        windowframe:Hide()
      else
        windowframe:Show()
      end
    else
      LibStub("AceConfigCmd-3.0").HandleCommand(iwtb, "iwtb", "syncOnJoin", input)
    end
  end
  
  --self:RegisterChatCommand("iWTBrank", "getGuildRanks")



end

function iwtb:OnEnable()
  -- Called when the addon is enabled
  -- GUI stuff

  --[[createMainFrame = function()
    frame = AceGUI:Create("Frame")
    frame:SetTitle("iWTB - I Want That Boss!")
    frame:SetStatusText("Container Frame")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    -- Fill Layout - the TabGroup widget will fill the whole frame
    frame:SetLayout("Fill")
    
    --Raider tab
    local function DrawRaiderTab(container)
      raiderFrame = AceGUI:Create("Frame")
      raiderFrame:SetStatusText("Raider frame")
      raiderFrame:SetLayout("List")
      raiderFrame:SetRelativeWidth(1)
      raiderFrame:SetFullHeight(true)
      raiderFrame:SetCallback("OnDragStart", function(s) print("drag start") end);
      
      
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
      container:AddChild(raiderFrame)
      
      
      local dumpVar = AceGUI:Create("Button")
      dumpVar:SetText("Dump var")
      dumpVar:SetWidth(200)
      dumpVar:SetCallback("OnClick", function(but)
        local test = getInstances(7)
        for key, value in pairs(iwtb) do
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

    -- Raid Leader tab
    local function DrawRLTab(container)
      local desc = AceGUI:Create("Label")
      desc:SetText(L["Raid Leader"])
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
        for key, value in pairs(iwtb) do
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
  
  createMainFrame()]]
  
  --AceGUI appears to be very basic so we can't use it to make draggable raid frames.
  local fontstring
  local button
  local texture
  
  -- What to do when item is clicked
  local function raidsDropdownMenuOnClick(self, arg1, arg2, checked)
    --[[for key, value in pairs(self:GetParent().dropdown.Button) do
        print(key, value)
    end]]
    --print(self:GetParent())
    --print("arg1: " .. tostring(arg1) .. " arg2: " .. tostring(arg2) .. " checked: " .. tostring(checked))
    
    if arg2 == "expacbutton" then
      -- fill in raids with arg1 as expac id
      getInstances(arg1)
      -- set text to selection
      printTable(self)
      UIDropDownMenu_SetText(expacButton, self:GetText())
      --UIDropDownMenu_SetSelectedID(expacButton, self:GetID())
    
    elseif arg2 == "instancebutton" then
    UIDropDownMenu_SetText(instanceButton, self:GetText())
      --UIDropDownMenu_SetSelectedID(instanceButton, self:GetID())
      --populate the raider boss list frame OR fill in the raid leader dropdown boss list

      -- get the boss list
      local bossList = getBosses(arg1)
      --print("bosslist")
      --printTable(bossList.bosses)
      
      -- Clear bossFrame
      --[[if bossFrame ~= nil then
        count = #bossFrame
        for i=0, count do bossFrame[i]=nil end
      end]]
      local bossFrame = {}
      
      -- assume raider tab for now
      
      print("--- raiderDB.char.bosses ---")
      printTable(raiderDB.char.bosses)
      print("--- end ---")
      local i = 1
      for bossid, bossname in pairs(bossList.bosses) do
        local y = -50 * i
        --print("y: " .. y)
        --print("bossid: " .. bossid .. " bossname: " .. bossname)
        bossFrame[i] = CreateFrame("Frame", "iwtbboss" .. bossid, raiderBossListFrame)
        bossFrame[i]:SetWidth(300)
        bossFrame[i]:SetHeight(50)
        bossFrame[i]:SetPoint("TOP", -50, y)
        
        local texture = bossFrame[i]:CreateTexture("iwtbboss" .. bossid)
        texture:SetAllPoints(bossFrame[i])
        texture:SetColorTexture(0.2,0.2,0.2,0.7)
        local fontstring = bossFrame[i]:CreateFontString("iwtbbosstext" .. bossid)
        fontstring:SetAllPoints(bossFrame[i])
        --fontstring:SetPoint("TOP", 0, y)
        if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
          print("Font not valid")
        end
        fontstring:SetJustifyH("LEFT")
        fontstring:SetJustifyV("CENTER")
        fontstring:SetText(bossname)
        
        --add dropdown menu for need/minor/os etc.
        local bossWantdropdown = CreateFrame("Frame", "bossWantdropdown" .. bossid, bossFrame[i], "UIDropDownMenuTemplate")
        bossWantdropdown:SetPoint("RIGHT", 0, 0)
        --expacButton:SetScript("OnClick", MyDropDownMenuButton_OnClick)
        UIDropDownMenu_SetWidth(bossWantdropdown, 100) -- Use in place of dropDown:SetWidth
        -- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
        UIDropDownMenu_Initialize(bossWantdropdown, bossWantDropDown_Menu)
        
        -- Set text to current selection if there is one otherwise default msg
        -- Need to change bossid to a string as that's how the table is created. Maybe we should create as a number? Depends on later use and which one is less hassle.
        local idofboss = tostring(bossid)

        if raiderDB.char.bosses[idofboss] ~= nil then
          UIDropDownMenu_SetText(bossWantdropdown, desire[raiderDB.char.bosses[idofboss]])
        else
          UIDropDownMenu_SetText(bossWantdropdown, L["Select desirability"])
        end
        
        i = i +1
      end
    
    elseif arg2 == "bossesbutton" then -- only in RL tab
    
    end
    --[[if arg1 == 1 then
    print("You can continue to believe whatever you want to believe.")
    elseif arg1 == 2 then
    print("Let's see how deep the rabbit hole goes.")
    end]]
  end
  
  -- Fill menu with items
  function raidsDropdownMenu(frame, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    --printTable(frame)
    if frame:GetName() == "expacbutton" then
      -- Get expansions
      --print("return expacs")
      if expacInfo == nil then getExpansions() end
      info.func = raidsDropdownMenuOnClick
      --info.checked = false
      for key, value in pairs(expacInfo) do
        --print(key .. ": " .. value)
        
        info.text, info.notCheckable, info.arg1, info.arg2 = value, true, key, frame:GetName()
        --if key == 7 then info.checked = true end
        UIDropDownMenu_AddButton(info)
      end
    elseif frame:GetName() == "instancebutton" then
      -- Get raids for expac
      if tierRaidInstances ~= nil then
        -- TODO: use tierRaidInstances.order to insert in order and not by instanceid
        info.func = raidsDropdownMenuOnClick
        --info.checked = false
        for key, value in pairs(tierRaidInstances.raids) do
          --print(key .. ": " .. value)
          
          info.text, info.notCheckable, info.arg1, info.arg2 = value, true, key, frame:GetName()
          
          UIDropDownMenu_AddButton(info)
        end
      end
    
    elseif frame:GetName() == "bossesbutton" then
      -- Get bosses for instance - RL only
      --getBosses(id)
      
    end
    
    --[[print("--------------")
    for key, value in pairs(frame["Button"]) do
        print(key, value)
    end]]
    
    --[[local info = UIDropDownMenu_CreateInfo()
    info.func = raidsDropdownMenuOnClick
    info.text, info.arg1 = "Blue Pill", 1
    UIDropDownMenu_AddButton(info)
    info.text, info.arg1 = "Red Pill", 2
    UIDropDownMenu_AddButton(info)]]
  end
  
  --------------------------------------------------------------------
  -- DESIRABILITY MENU FUNCTIONS
  --------------------------------------------------------------------
  
  local function bossWantDropDown_OnClick(self, arg1, arg2, checked)
    -- arg1 = desire id, arg2 = boss id
    --[[for key, value in pairs(self:GetParent().dropdown.Button) do
        print(key, value)
    end]]
    --print(self:GetParent())
    print("arg1: " .. tostring(arg1) .. " arg2: " .. tostring(arg2) .. " checked: " .. tostring(checked))
    
    raiderDB.char.bosses[arg2] = arg1
    --UIDropDownMenu_SetSelectedID(self:GetParent(), self:GetID())
    --print(raiderDB.char.bosses[arg2])
    
  end
    
  -- Fill menu with desirability list
  function bossWantDropDown_Menu(frame, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    
    --print(string.match(frame:GetName(), "%d+"))
    local idofboss = string.match(frame:GetName(), "%d+")
    --print(idofboss)
    --[[print(type(raiderDB.char))
    for key, value in pairs(raiderDB.char) do
      print(key, value)
    end]]
    
    info.func = bossWantDropDown_OnClick
    for desireid, name in pairs(desire) do
      --print(desireid .. ": " .. name)
      
      info.text, info.arg1, info.arg2 = name, desireid, idofboss
      --print(raiderDB.char.bosses[idofboss])
      if raiderDB.char.bosses[idofboss] ~=nil and raiderDB.char.bosses[idofboss] == desireid then
        print("desired: " .. desireid .. " bossid: " .. idofboss)
        info.checked = true
        --UIDropDownMenu_SetText(frame, name)
      else
        info.checked = false
      end
      
    
      UIDropDownMenu_AddButton(info)
    end
      
  end

  frame = CreateFrame("Frame", "iwtbframe", UIParent)
  --frame:SetFrameStrata("BACKGROUND")
 -- frame:SetWidth(500)
  --frame:SetHeight(500)
  --frame:SetPoint("CENTER", 0, 0)
  --frame:SetFrameStrata("FULLSCREEN")
  --frame:SetMovable(true)
  --frame:RegisterEvent("GROUP_ROSTER_UPDATE");
  --frame:RegisterEvent("CHAT_MSG_SYSTEM");
  --frame:SetScript("OnEvent", RSUM_OnEvent);
  --frame:SetScript("OnUpdate", RSUM_OnWindowUpdate);
  
  windowframe = CreateFrame("Frame", "iwtbwindow", UIParent)
  windowframe:SetWidth(GUIwindowSizeX)
  windowframe:SetHeight(GUIwindowSizeY)
  windowframe:SetPoint("CENTER", 0, 0)
  windowframe:SetFrameStrata("FULLSCREEN")
  windowframe:SetMovable(true)

  windowframetexture = windowframe:CreateTexture("iwtbframetexture")
  windowframetexture:SetAllPoints(windowframetexture:GetParent())
  windowframetexture:SetColorTexture(0,0,0,0.5)
  windowframe.texture = windowframetexture
  
  --[[fontstring = windowframe:CreateFontString("iwtbtesting")
  fontstring:SetAllPoints(windowframe)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("work?")]]
  
  --title
  local title = CreateFrame("Frame", "iwtbtitle", windowframe)
  title:SetWidth(GUItitleSizeX)
  title:SetHeight(GUItitleSizeY)
  title:SetPoint("CENTER", title:GetParent(), "TOP", 0, 0)
  title:EnableMouse(true)
  title:RegisterForDrag("LeftButton")
  title:SetScript("OnDragStart", function(s) s:GetParent():StartMoving() end)
  title:SetScript("OnDragStop", function(s) s:GetParent():StopMovingOrSizing();end)
  title:SetScript("OnHide", function(s) s:GetParent():StopMovingOrSizing() end)
  texture = windowframe:CreateTexture("iwtbtitletex")
  texture:SetAllPoints(title)
  texture:SetColorTexture(0,0,0,0.7)
  fontstring = windowframe:CreateFontString("iwtbtitletext")
  fontstring:SetAllPoints(title)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("iWTB - I Want That Boss!")
  
  button = CreateFrame("Button", "iwtbexit", windowframe, "UIPanelCloseButton")
  button:SetWidth(40)
  button:SetHeight(40)
  button:SetPoint("CENTER", button:GetParent(), "TOPRIGHT", 0, 0)
  button:Enable()
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", function(s) windowframe:Hide(); end)
  
  -- Tabs
  
  
  -- Raider tab
  local raiderTab = CreateFrame("Frame", "iwtbraidertab", windowframe)
  raiderTab:SetWidth(GUItabWindowSizeX)
  raiderTab:SetHeight(GUItabWindowSizeY)
  raiderTab:SetPoint("CENTER", 0, -20)
  texture = raiderTab:CreateTexture("iwtbraidertex")
  texture:SetAllPoints(raiderTab)
  texture:SetColorTexture(0,0,0,1)
  --[[fontstring = raiderTab:CreateFontString("iwtbraidertesting")
  fontstring:SetAllPoints(raiderTab)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("Raider")]]
  
  -- made local at start because dropdown menu function uses it
  raiderBossListFrame = CreateFrame("Frame", "iwtbraiderbosslist", raiderTab)
  raiderBossListFrame:SetWidth(GUItabWindowSizeX -20)
  raiderBossListFrame:SetHeight(GUItabWindowSizeY -20)
  raiderBossListFrame:SetPoint("CENTER", 0, 0)
  texture = raiderBossListFrame:CreateTexture("iwtbraiderbosslisttex")
  texture:SetAllPoints(raiderBossListFrame)
  texture:SetColorTexture(0,0,0,1)
  fontstring = raiderBossListFrame:CreateFontString("iwtbraidertesting")
  fontstring:SetAllPoints(raiderBossListFrame)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("Boss list")
  
  -- Raider leader tab
  local rlTab = CreateFrame("Frame", "iwtbraidleadertab", windowframe)
  rlTab:SetWidth(GUItabWindowSizeX)
  rlTab:SetHeight(GUItabWindowSizeY)
  rlTab:SetPoint("CENTER", 0, -20)
  texture = rlTab:CreateTexture("iwtbraidleadertex")
  texture:SetAllPoints(rlTab)
  texture:SetColorTexture(0,0,0,1)
  fontstring = rlTab:CreateFontString("iwtbrltabtesting")
  fontstring:SetAllPoints(rlTab)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("Raid Leader")
  
  -- Dropdown buttons
  expacButton = CreateFrame("Frame", "expacbutton", raiderTab, "UIDropDownMenuTemplate")
  expacButton:SetPoint("TOPLEFT", 0, -20)
  --expacButton:SetScript("OnClick", MyDropDownMenuButton_OnClick)
  UIDropDownMenu_SetWidth(expacButton, 200) -- Use in place of dropDown:SetWidth
  -- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
  UIDropDownMenu_Initialize(expacButton, raidsDropdownMenu)
  UIDropDownMenu_SetText(expacButton, L["Select expansion"])
  
  instanceButton = CreateFrame("Frame", "instancebutton", raiderTab, "UIDropDownMenuTemplate")
  instanceButton:SetPoint("TOPLEFT", 250, -20)
  --expacButton:SetScript("OnClick", MyDropDownMenuButton_OnClick)
  UIDropDownMenu_SetWidth(instanceButton, 200) -- Use in place of dropDown:SetWidth
  -- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
  UIDropDownMenu_Initialize(instanceButton, raidsDropdownMenu)
  UIDropDownMenu_SetText(instanceButton, L["Select raid"])
  
  -- Add tab buttons
  local raiderButton = CreateFrame("Button", "$parentTab1", windowframe, "TabButtonTemplate")
  raiderButton:SetWidth(GUItabButtonSizeX)
  raiderButton:SetHeight(GUItabButtonSizeY)
  raiderButton:SetText(L["Raider"])
  raiderButton:SetPoint("CENTER", raiderButton:GetParent(), "TOPLEFT", 70, -40)
  texture = raiderButton:CreateTexture("raiderbuttex")
  texture:SetAllPoints(raiderButton)
  texture:SetColorTexture(0, 0, 0, 1)
  raiderButton:Enable()
  raiderButton:RegisterForClicks("LeftButtonUp")
  raiderButton:SetScript("OnClick", function(s)
    PanelTemplates_SetTab(windowframe, 1)
    raiderTab:Show()
    rlTab:Hide()
  end)
  
  local raidLeaderButton = CreateFrame("Button", "$parentTab2", windowframe, "TabButtonTemplate")
  raidLeaderButton:SetWidth(GUItabButtonSizeX)
  raidLeaderButton:SetHeight(GUItabButtonSizeY)
  raidLeaderButton:SetText(L["Raid Leader"])
  raidLeaderButton:SetPoint("CENTER", raidLeaderButton:GetParent(), "TOPLEFT", 180, -40)
  texture = raidLeaderButton:CreateTexture("raiderbuttex")
  texture:SetAllPoints(raidLeaderButton)
  texture:SetColorTexture(0, 0, 0, 1)
  raidLeaderButton:Enable()
  raidLeaderButton:RegisterForClicks("LeftButtonUp")
  raidLeaderButton:SetScript("OnClick", function(s)
    PanelTemplates_SetTab(windowframe, 2)     -- 1 because we want tab 1 selected.
    rlTab:Show()  -- Hide all other pages (in this case only one).
    raiderTab:Hide()  -- Show page 1.
  end)
  
  --register tabs
  PanelTemplates_SetNumTabs(windowframe, 2)  -- 2 because there are 2 frames total.
  PanelTemplates_SetTab(windowframe, 1)     -- 1 because we want tab 1 selected.
  raiderTab:Show()  -- Show page 1.
  rlTab:Hide()  -- Hide all other pages (in this case only one).
  
  windowframe:Hide()
end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
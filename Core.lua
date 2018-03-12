iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
--local Serializer = LibStub("AceSerializer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("iWTB")

--Define some vars
local db
local raiderDB
local raidLeaderDB
local rankInfo = {} -- Guild rank info
local expacInfo = nil -- Expacs for dropdown
local tierRaidInstances = nil -- Raid instances for raider tab dropdown
local tierRLRaidInstances = nil 
local instanceBosses = nil -- Bosses for RL tab dropdown
local frame
local windowframe -- main frame
local raiderFrame -- raider tab frame
local rlMainFrame -- raid leader tab frame
local createMainFrame
local raiderBossListFrame -- main frame listing bosses (raider)
local rlRaiderListFrame -- main frame listing raiders spots
local grpMemFrame = {} -- table containing each frame per group
local grpMemSlotFrame = {} -- table containing each frame per slot for each group
local rlRaiderNotListFrame -- main frame listing raiders NOT in the raid but in the rl db
local bossFrame -- table of frames containing each boss frame
local raiderBossesStr = "" -- raider boss desire seralised
local desire = {L["BiS"], L["Need"], L["Minor"], L["Off spec"], L["No need"]}
local bossDesire = nil

local raiderSelectedTier = {} -- Tier ID from dropdown Must be a better way but cba for now.
local rlSelectedTier = {} -- Must be a better way but cba for now.

--Dropdown menu frames
local expacButton = nil
local expacRLButton = nil
local instanceButton = nil
local instanceRLButton = nil
local bossesRLButton = nil

-- GUI dimensions
local GUIwindowSizeX = 700
local GUIwindowSizeY = 600
local GUItabWindowSizeX = 680
local GUItabWindowSizeY = 540
local GUItitleSizeX = 200
local GUItitleSizeY = 30
local GUItabButtonSizeX = 100
local GUItabButtonSizeY = 30
local GUIgrpSizeX = 580
local GUIgrpSizeY = 50
local GUIgrpSlotSizeX = 110
local GUIgrpSlotSizeY = 45
  
-- API Calls and functions

--author: Alundaio (aka Revolucas)
function print_table(node)
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

local function printTable(table)
  --print(type(table))
  if type(table) == "table" then
    if table == nil then print("Empty table") end -- this won't work?
    for key, value in pairs(table) do
        print("k: " .. key .. " v: " .. value)
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
local function getInstances(expacID, isRL)
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
      local isRaid = select(10,EJ_GetInstanceByIndex(i,true))
      local raidTitle = select(2,EJ_GetInstanceByIndex(i,true))
      
      if isRaid then
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
      --break loop in case we fuck up
      if i == 30 then finished = true end
    end
    
  until finished
  
  --return tierRaidInstances
end

-- Return the bosses per raid.
local function getBosses(raidID, isRL)
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
  
  if isRL then
    instanceBosses = raidBosses
  else
    return raidBosses
  end
end

local function dbSchemaCheck(level, expac)
  print_table(raiderDB.char)
  if level == "expacs" then
    if expacInfo == nil then getExpansions() end
    for key, value in pairs(expacInfo) do
      if raiderDB.char.expac[key] == nil then raiderDB.char.expac[key] = {} end
    end
    print_table(raiderDB.char)
  elseif level == "inst" and type(expac) == "number" then
    for key, value in pairs(tierRaidInstances.raids) do
      if raiderDB.char.expac[expac].tier == nil then raiderDB.char.expac[expac].tier = {} end
      if raiderDB.char.expac[expac].tier[key] == nil then
        raiderDB.char.expac[expac].tier[key] = {}
        raiderDB.char.expac[expac].tier[key].bosses = {}
      end
    end
    print_table(raiderDB.char)
  end
end
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
-- Lovingly "inspired" by RSUM
local function FrameContainsPoint(frame, x, y)
	local left, bottom, width, height = frame:GetRect()
  print(frame:GetName() .. " - " .. frame:GetRect())
	if x >= left then
		if y >= bottom then
			if x <= left + width then
				if y <= bottom + height then
					return true;
				end
			end
		end
	end
	return false;
end

-- search for mouseover frame which is actually overlapped by the dragged frame - does not work correctly for slots in same grp if > dragged. Anchor point problem? Position on drag changes GetRect?
local function MemberFrameContainsPoint(x, y)
	if FrameContainsPoint(rlRaiderListFrame, x, y) then
		for i=1,8 do
			if FrameContainsPoint(grpMemFrame[i], x, y) then
				for member=1,5 do
					if FrameContainsPoint(grpMemSlotFrame[i][member], x, y) then
            print("grp: " .. i .. " slot: " .. member)
            print("x: " .. x .. " y: " ..y)
						return i, member;
					end
				end
				return i, nil;
			end
		end
	end
	return nil, nil;
end

local function redrawGroup(grp)
  for n=1, 5 do
    local slotx = (GUIgrpSlotSizeX +5) * (n -1)
    --print(grpMemSlotFrame[tgrp][n]:GetName())
    grpMemSlotFrame[grp][n]:ClearAllPoints()
    grpMemSlotFrame[grp][n]:SetParent(grpMemFrame[grp])
    grpMemSlotFrame[grp][n]:SetPoint("TOPLEFT", slotx, -3)
    --grpMemSlotFrame[tgrp][n]:
  end
  
end
---------------------------------
function iwtb:OnInitialize()
---------------------------------
  local raiderDefaults = {  -- bosses[id].desire
    char = {
      expac = {
        --[[tier = {
          bosses = {},
        },]]
      },
      bossListHash = "", -- this is the hash of all bosses to be sent for comparison with the RL data
    },
  }
  
  
  local raiderLeaderDefaults = { -- is there any? boss required number tanks/healers/dps (dps is auto filled in assuming 20 or allow set max?)
    char = {
      raiders = {
        --[[expac = {
          tier = {
            bosses = {},
          },
        },
        bossListHash = "",]]
      },
    },
  }
  
  -- DB defaults
  local defaults = {
    char = {
        syncOnJoin = true,
        syncOnlyGuild = true,
        syncGuildRank = {false, false, false, false, false, false, false, false, false, false}, -- Is this correct?
    },
  }
  
  iwtb.db = LibStub("AceDB-3.0"):New("iWTBDB", defaults)
  db = self.db
  iwtb.raiderDB = LibStub("AceDB-3.0"):New("iWTBRaiderDB", raiderDefaults)
  raiderDB = self.raiderDB
  iwtb.raidLeaderDB = LibStub("AceDB-3.0"):New("iWTBRaidLeaderDB", raidLeaderDefaults)
  raidLeaderDB = self.raidLeaderDB
  
  rankInfo = getGuildRanks()
  expacInfo = getExpansions()
  
  
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
      raiderSelectedTier.expacid = arg1
      L_UIDropDownMenu_SetText(expacButton, self:GetText())
      dbSchemaCheck("expacs")
      
    elseif arg2 == "expacrlbutton" then
      -- fill in raids with arg1 as expac id
      getInstances(arg1, true)
      rlSelectedTier.expacid = arg1
      L_UIDropDownMenu_SetText(expacRLButton, self:GetText())
      
    elseif arg2 == "instancebutton" then
    L_UIDropDownMenu_SetText(instanceButton, self:GetText())
    raiderSelectedTier.instid = arg1
    dbSchemaCheck("inst", raiderSelectedTier.expacid)
      -- Generate boss frames within raiderBossListFrame
      local function genBossFrames(bossList)
        -- Empty boss list to create the bosses frames
        bossFrame = {}
        
        --print("--- raiderDB.char.bosses ---")
        --printTable(raiderDB.char.bosses)
        --print("--- end ---")
        
        -- Create a frame for each boss with a desire dropdown.
          local i = 1
          for id, bossid in pairs(bossList.order) do
            local y = -50 * i
            local idofboss = tostring(bossid)
            --print("y: " .. y)
            --print("bossid: " .. idofboss .. " bossname: " .. bossname)
            bossFrame[idofboss] = CreateFrame("Frame", "iwtbboss" .. idofboss, raiderBossListFrame)
            bossFrame[idofboss]:SetWidth(300)
            bossFrame[idofboss]:SetHeight(50)
            bossFrame[idofboss]:SetPoint("TOP", -50, y)
            
            local texture = bossFrame[idofboss]:CreateTexture("iwtbboss" .. idofboss)
            texture:SetAllPoints(bossFrame[idofboss])
            texture:SetColorTexture(0.2,0.2,0.2,0.7)
            local fontstring = bossFrame[idofboss]:CreateFontString("iwtbbosstext" .. idofboss)
            fontstring:SetAllPoints(bossFrame[idofboss])
            --fontstring:SetPoint("TOP", 0, y)
            if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
              print("Font not valid")
            end
            fontstring:SetJustifyH("LEFT")
            fontstring:SetJustifyV("CENTER")
            fontstring:SetText(bossList.bosses[bossid])
            
            --add dropdown menu for need/minor/os etc.
            local bossWantdropdown = CreateFrame("Frame", "bossWantdropdown" .. bossid, bossFrame[idofboss], "L_UIDropDownMenuTemplate")
            bossWantdropdown:SetPoint("RIGHT", 0, 0)
            --expacButton:SetScript("OnClick", MyDropDownMenuButton_OnClick)
            L_UIDropDownMenu_SetWidth(bossWantdropdown, 100) -- Use in place of dropDown:SetWidth
            -- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
            L_UIDropDownMenu_Initialize(bossWantdropdown, bossWantDropDown_Menu)
            
            -- Set text to current selection if there is one otherwise default msg
            -- Need to change bossid to a string as that's how the table is created. Maybe we should create as a number? Depends on later use and which one is less hassle.
            

            --if raiderDB.char.bosses[idofboss] ~= nil then
            if raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses ~= nil
            and raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss] ~= nil then
              L_UIDropDownMenu_SetText(bossWantdropdown, desire[raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss]])
            else
              L_UIDropDownMenu_SetText(bossWantdropdown, L["Select desirability"])
            end
            
            i = i +1
          end
        end
      
      --UIDropDownMenu_SetSelectedID(instanceButton, self:GetID())
      
      -- Populate the raider boss list frame OR fill in the raid leader dropdown boss list

      -- get the boss list
      local bossList = getBosses(arg1)
      --printTable(bossList.bosses)
      
      -- Because the frame may already be created we need to check
      
      if raiderBossListFrame:GetChildren() == nil then
        genBossFrames(bossList)
      else  
        -- We have frames in the boss list so check if they are the frames we want
        --print("Children#: " .. raiderBossListFrame:GetNumChildren())
        --print(string.match(raiderBossListFrame:GetChildren():GetName(), "%d+"))
        --printTable(raiderBossListFrame:GetChildren())
        local childFrames = {raiderBossListFrame:GetChildren()}
        local haveList = false
        
        -- Search childFrames for the first boss id -- if found we should have the entire list
        -- Hide all boss frames as we are here
        for _, frame in ipairs(childFrames) do
          frame:Hide()
          if frame:GetName() == "iwtbboss" .. bossList.order[1] then haveList = true end
        end
        
        if haveList then
          
          --print("We already have this list")
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
            --print(frame:GetName())
            frame:Hide()
          end
          
          -- Create a new list
          genBossFrames(bossList)
          
        end
      end
      
    elseif arg2 == "instancerlbutton" then
      L_UIDropDownMenu_SetText(instanceRLButton, self:GetText())
      rlSelectedTier.instid = arg1
      -- get the boss list
      getBosses(arg1, true)
    
    elseif arg2 == "bossesrlbutton" then -- only in RL tab
      L_UIDropDownMenu_SetText(bossesRLButton, self:GetText())
      print(self:GetID() .. " : " .. self:GetName())
      print("expacid: " .. rlSelectedTier.expacid .. " tierid: " .. rlSelectedTier.instid)
      print("bossid: ", instanceBosses.order[self:GetID()])
      
      
    end
    --[[if arg1 == 1 then
    print("You can continue to believe whatever you want to believe.")
    elseif arg1 == 2 then
    print("Let's see how deep the rabbit hole goes.")
    end]]
  end
  
  -- Fill menu with items
  function raidsDropdownMenu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
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
        L_UIDropDownMenu_AddButton(info)
      end
    
    elseif frame:GetName() == "expacrlbutton" then
      -- Get expansions
      --print("return expacs")
      if expacInfo == nil then getExpansions() end
      info.func = raidsDropdownMenuOnClick
      --info.checked = false
      for key, value in pairs(expacInfo) do
        --print(key .. ": " .. value)
        
        info.text, info.notCheckable, info.arg1, info.arg2 = value, true, key, frame:GetName()
        --if key == 7 then info.checked = true end
        L_UIDropDownMenu_AddButton(info)
      end
      
    elseif frame:GetName() == "instancebutton" then
      -- Get raids for expac
      if tierRaidInstances ~= nil then
        info.func = raidsDropdownMenuOnClick
        --info.checked = false
        for key, value in pairs(tierRaidInstances.order) do -- Use .order as .raids is sorted by instanceid which is not in the correct order.
          --print(key .. ": " .. value)
          
          info.text, info.notCheckable, info.arg1, info.arg2 = tierRaidInstances.raids[value], true, value, frame:GetName()
          
          L_UIDropDownMenu_AddButton(info)
        end
      end
    
    elseif frame:GetName() == "instancerlbutton" then
      -- Get raids for expac
      if tierRLRaidInstances ~= nil then
        info.func = raidsDropdownMenuOnClick
        for key, value in pairs(tierRLRaidInstances.order) do -- Use .order as .raids is sorted by instanceid which is not in the correct order.
          info.text, info.notCheckable, info.arg1, info.arg2 = tierRLRaidInstances.raids[value], true, value, frame:GetName()
          
          L_UIDropDownMenu_AddButton(info)
        end
      end
      
    elseif frame:GetName() == "bossesrlbutton" then
      -- Get bosses for instance - RL only
      if instanceBosses ~= nil then
        info.func = raidsDropdownMenuOnClick
        for key, value in pairs(instanceBosses.order) do -- Use .order as .raids is sorted by instanceid which is not in the correct order.
          info.text, info.notCheckable, info.arg1, info.arg2 = instanceBosses.bosses[value], true, value, frame:GetName()
          L_UIDropDownMenu_AddButton(info)
        end
      end
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
    print("expacID: " .. raiderSelectedTier.expacid .. " tierID: " .. raiderSelectedTier.instid)
    -- Desirability of the boss has changed: write to DB, change serialised string for comms, (if in the raid of the selected tier, resend to raid leader (and promoted?)?)
    raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[arg2] = arg1
    -- Is it too much overhead to do this each time? Have a button instead to serialises and send? Relies on raider to push a button and we know how hard they find that already!
    --raiderBossesStr = Serializer:Serialize(raiderDB.char.bosses)
    --print("SerStr: " .. raiderBossesStr)
    
    -- Set dropdown text to new selection
    L_UIDropDownMenu_SetSelectedID(bossFrame[arg2]:GetChildren(), self:GetID())
    -- Update hash
    print("Old hash: " .. raiderDB.char.bossListHash)
    raiderDB.char.bossListHash = iwtb.encodeData("hash", raiderDB.char.expac) -- Do we want to hash here? Better to do it before sending or on request?
    --print(raiderDB.char.bosses[arg2])
    print("New hash: " .. raiderDB.char.bossListHash)
  end
    
  -- Fill menu with desirability list
  function bossWantDropDown_Menu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
    
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
      if raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses ~= nil
      and raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss] ~=nil
      and raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss] == desireid then
        --print("desired: " .. desireid .. " bossid: " .. idofboss)
        info.checked = true
        --UIDropDownMenu_SetText(frame, name)
      else
        info.checked = false
      end
      
    
      L_UIDropDownMenu_AddButton(info)
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
  
  -- Raider send button
  local raiderSendButton = CreateFrame("Button", "iwtbraidersendbutton", raiderTab, "UIPanelButtonTemplate")
  raiderSendButton:SetWidth(GUItabButtonSizeX)
  raiderSendButton:SetHeight(GUItabButtonSizeY)
  raiderSendButton:SetText(L["Send"])
  raiderSendButton:SetPoint("CENTER", raiderSendButton:GetParent(), "BOTTOMRIGHT", -100, 30)
  texture = raiderSendButton:CreateTexture("raidersendbuttex")
  texture:SetAllPoints(raiderSendButton)
  texture:SetColorTexture(0, 0, 0, 1)
  raiderSendButton:Enable()
  raiderSendButton:RegisterForClicks("LeftButtonUp")
  raiderSendButton:SetScript("OnClick", function(s)
    -- Send current desire list (to raid?)
    --local mydata = iwtb.encodeData("hash", raiderDB.char.bosses)
    print("Hash: " .. raiderDB.char.bossListHash)
    --iwtb.sendData("rhash", raiderDB.char.bossListHash, "raid")
    iwtb.sendData("rhash", "0123456789", "raid") -- junk hash for testing
  end)
  
  -- Raider reset DB button
  local raiderResetDBButton = CreateFrame("Button", "iwtbraiderresetdbbutton", raiderTab, "UIPanelButtonTemplate")
  raiderResetDBButton:SetWidth(GUItabButtonSizeX)
  raiderResetDBButton:SetHeight(GUItabButtonSizeY)
  raiderResetDBButton:SetText(L["Reset DB"])
  raiderResetDBButton:SetPoint("CENTER", raiderResetDBButton:GetParent(), "BOTTOMRIGHT", -250, 30)
  texture = raiderResetDBButton:CreateTexture("raiderresetdbbuttex")
  texture:SetAllPoints(raiderResetDBButton)
  texture:SetColorTexture(0, 0, 0, 1)
  raiderResetDBButton:Enable()
  raiderResetDBButton:RegisterForClicks("LeftButtonUp")
  raiderResetDBButton:SetScript("OnClick", function(s)
    raiderDB:ResetDB()
  end)
  
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
  
  -- rlRaiderListFrame
  rlRaiderListFrame = CreateFrame("Frame", "iwtbrlraiderlistframe", rlTab)
  rlRaiderListFrame:SetWidth(GUItabWindowSizeX -20)
  rlRaiderListFrame:SetHeight(GUItabWindowSizeY -20)
  rlRaiderListFrame:SetPoint("CENTER", 0, 0)
  texture = rlRaiderListFrame:CreateTexture("iwtbrlraiderlistframetex")
  texture:SetAllPoints(rlRaiderListFrame)
  texture:SetColorTexture(0.1,0.1,0.1,1)
  fontstring = rlRaiderListFrame:CreateFontString("iwtbrlraiderlistframetesting")
  fontstring:SetAllPoints(rlRaiderListFrame)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("Raider list")
  
  -- Create frame for each raid spot
  for i=1, 8 do -- 8 groups of 5 slots
    local x = 20
    local y = (GUIgrpSizeY + 5) * i
    
    --local y = 55 *i
    grpMemFrame[i] = CreateFrame("Frame", "iwtbgrp" .. i, rlRaiderListFrame)
    grpMemFrame[i]:SetWidth(GUIgrpSizeX)
    grpMemFrame[i]:SetHeight(GUIgrpSizeY)
    grpMemFrame[i]:SetPoint("TOPLEFT",x, -y)
    local texture = grpMemFrame[i]:CreateTexture("iwtbgrptex" .. i)
    texture:SetAllPoints(texture:GetParent())
    if i < 5 then
      texture:SetColorTexture(0,0.7,0,0.7)
    else
      texture:SetColorTexture(0.5,0.5,0.5,0.7)
    end
    grpMemSlotFrame[i] = {}
    
    for n=1, 5 do -- 5 frames per group
      local slotx = (GUIgrpSlotSizeX +5) * (n -1)
      --local sloty = (GUIgrpSlotSizeY * i) + 5
      grpMemSlotFrame[i][n] = CreateFrame("Button", "iwtbgrpslot" .. i .. "-" .. n, grpMemFrame[i])
      grpMemSlotFrame[i][n]:SetWidth(GUIgrpSlotSizeX)
      grpMemSlotFrame[i][n]:SetHeight(GUIgrpSlotSizeY)
      grpMemSlotFrame[i][n]:ClearAllPoints()
      --obj:SetPoint(point, relativeTo, relativePoint, ofsx, ofsy);
      --grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", "iwtbgrp" .. i, "CENTER", slotx, -sloty)
      grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
      local texture = grpMemSlotFrame[i][n]:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
      local fontstring = grpMemSlotFrame[i][n]:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
      texture:SetAllPoints(texture:GetParent())
      texture:SetColorTexture(0,0,0,1)
      --[[fontstring:SetPoint("TOP", 0, 0)
      fontstring:SetPoint("BOTTOM", 0, 0)
      fontstring:SetPoint("LEFT", fontstring:GetParent():GetHeight() + 4, 0)
      fontstring:SetPoint("RIGHT", -fontstring:GetParent():GetHeight() - 4, 0)]]
      fontstring:SetPoint("CENTER")
      fontstring:SetJustifyH("CENTER")
      fontstring:SetJustifyV("CENTER")
      local font_valid = fontstring:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
      if not font_valid then
        print("Font not valid")
      end
      fontstring:SetText("Raider " .. i .. " - " .. n)

      grpMemSlotFrame[i][n].nameText = fontstring
      
      grpMemSlotFrame[i][n]:RegisterForDrag("LeftButton");
      grpMemSlotFrame[i][n]:RegisterForClicks("RightButtonDown");
      grpMemSlotFrame[i][n]:SetMovable(true);
      grpMemSlotFrame[i][n]:EnableMouse(true);
      grpMemSlotFrame[i][n]:SetScript("OnDragStart", function(s, ...) s:StartMoving() s:SetFrameStrata("TOOLTIP") end);
      grpMemSlotFrame[i][n]:SetScript("OnDragStop", function(s, ...)
        --[[if ns.gm.MemberFrameEmpty(s) then
          s:StopMovingOrSizing();
          RSUM_ReturnSavedFramePosition();
          return;
        end]]
        s:StopMovingOrSizing();
        --s:ClearAllPoints()
        s:SetFrameStrata("FULLSCREEN");
        
        local sourceGroup = tonumber(string.sub(s:GetName(), -3, -3))
        local mousex, mousey = GetCursorPosition();
        local scale = UIParent:GetEffectiveScale();
        mousex = mousex / scale;
        mousey = mousey / scale;
        --print(mousex, mousey)
        local targetgroup, targetmember = MemberFrameContainsPoint(mousex, mousey);
        if targetgroup then
          --local sourcegroup, sourcemember = RSUM_GetGroupMemberByFrame(s)
          print("tgrp: " .. targetgroup .. " sbut: " .. s:GetName())
          
          if targetmember then
            print("slot: " .. targetmember)
            --[[if ns.gm.Member(targetgroup, targetmember) == nil then
              --ns.gm.Move(sourcegroup, sourcemember, targetgroup);
            else
              --ns.gm.Swap(sourcegroup, sourcemember, targetgroup, targetmember);
            end]]
          else
            --ns.gm.Move(sourcegroup, sourcemember, targetgroup);
          end
          
          -- Redraw group frames
          --print(string.sub(s:GetName(), -3, -3))
          
          if targetgroup ~= sourceGroup then
            print("redraw source")
            redrawGroup(targetgroup)
          end
          
          
          --RSUM_GroupSync(false);
          --RSUM_UpdateWindows();
        end
        -- Redraw source group in case button is left outside our frames
        redrawGroup(sourceGroup)
      end);

      grpMemSlotFrame[i][n]:SetScript("OnClick", function(s)
        print(s:GetName())
        s.nameText:SetText("click me!")
      end);
      
      --[[local texture = groupmemberframes[group][member]:CreateTexture("rsumgroup" .. group .. "memberwindowtexture" .. member);
      local fontstring = groupmemberframes[group][member]:CreateFontString("rsumgroup" .. group .. "memberwindowstring" .. member);
      texture:SetAllPoints(texture:GetParent());
      texture:SetColorTexture(unpack(groupmemberframecolor));
      texture:SetDrawLayer("BACKGROUND", 0);
      groupmemberframes[group][member].background = texture;
      
      fontstring:SetPoint("TOP", 0, 0);
      fontstring:SetPoint("BOTTOM", 0, 0);
      fontstring:SetPoint("LEFT", fontstring:GetParent():GetHeight() + 4, 0);
      fontstring:SetPoint("RIGHT", -fontstring:GetParent():GetHeight() - 4, 0);
      fontstring:SetJustifyH("CENTER");
      fontstring:SetJustifyV("CENTER");
      local font_valid = fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
      if not font_valid then
        print("Font not valid");
      end
      groupmemberframes[group][member].nameText = fontstring;
      
      texture = groupmemberframes[group][member]:CreateTexture();
      texture:SetPoint("LEFT", 4, 0);
      texture:SetPoint("RIGHT", texture:GetParent(), "LEFT", texture:GetParent():GetHeight() + 4, 0);
      texture:SetHeight(texture:GetParent():GetHeight());
      texture:SetTexture("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.tga");
      texture:SetDrawLayer("OVERLAY", 7);
      groupmemberframes[group][member].roleTexture = texture;
      texture:Hide();
      
      groupmemberframes[group][member]:SetFrameStrata("FULLSCREEN");
      groupmemberframes[group][member]:RegisterForDrag("LeftButton");
      groupmemberframes[group][member]:RegisterForClicks("RightButtonDown");
      groupmemberframes[group][member]:SetMovable(true);
      groupmemberframes[group][member]:EnableMouse(true);
      groupmemberframes[group][member]:SetScript("OnDragStart", RSUM_OnDragStart);
      groupmemberframes[group][member]:SetScript("OnDragStop", RSUM_OnDragStop);
      groupmemberframes[group][member]:SetScript("OnEnter", RSUM_OnEnter);
      groupmemberframes[group][member]:SetScript("OnLeave", RSUM_OnLeave);]]
    end
  
  end
  
  -- Dropdown buttons (for raid leader tab)
  expacRLButton = CreateFrame("Frame", "expacrlbutton", rlTab, "L_UIDropDownMenuTemplate")
  expacRLButton:SetPoint("TOPLEFT", 0, -20)
  L_UIDropDownMenu_SetWidth(expacRLButton, 200)
  L_UIDropDownMenu_Initialize(expacRLButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(expacRLButton, L["Select expansion"])
  
  instanceRLButton = CreateFrame("Frame", "instancerlbutton", rlTab, "L_UIDropDownMenuTemplate")
  instanceRLButton:SetPoint("TOPLEFT", 250, -20)
  L_UIDropDownMenu_SetWidth(instanceRLButton, 200)
  L_UIDropDownMenu_Initialize(instanceRLButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(instanceRLButton, L["Select raid"])
  
  bossesRLButton = CreateFrame("Frame", "bossesrlbutton", rlTab, "L_UIDropDownMenuTemplate")
  bossesRLButton:SetPoint("TOPLEFT", 500, -20)
  L_UIDropDownMenu_SetWidth(bossesRLButton, 200)
  L_UIDropDownMenu_Initialize(bossesRLButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(bossesRLButton, L["Select boss"])
  
  --------------------------------------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------------------------
  
  -- Dropdown buttons (for raider tab)
  expacButton = CreateFrame("Frame", "expacbutton", raiderTab, "L_UIDropDownMenuTemplate")
  expacButton:SetPoint("TOPLEFT", 0, -20)
  --expacButton:SetScript("OnClick", MyDropDownMenuButton_OnClick)
  L_UIDropDownMenu_SetWidth(expacButton, 200) -- Use in place of dropDown:SetWidth
  -- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
  L_UIDropDownMenu_Initialize(expacButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(expacButton, L["Select expansion"])
  
  instanceButton = CreateFrame("Frame", "instancebutton", raiderTab, "L_UIDropDownMenuTemplate")
  instanceButton:SetPoint("TOPLEFT", 250, -20)
  --expacButton:SetScript("OnClick", MyDropDownMenuButton_OnClick)
  L_UIDropDownMenu_SetWidth(instanceButton, 200) -- Use in place of dropDown:SetWidth
  -- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
  L_UIDropDownMenu_Initialize(instanceButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(instanceButton, L["Select raid"])
  
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
  
  --windowframe:Hide()
end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
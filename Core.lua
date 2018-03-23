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
local rlOoRcontentSlots = {} -- Out of Raid slots
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
local GUIwindowSizeX = 800
local GUIwindowSizeY = 700
local GUItabWindowSizeX = 780
local GUItabWindowSizeY = 640
local GUItitleSizeX = 200
local GUItitleSizeY = 30
local GUItabButtonSizeX = 100
local GUItabButtonSizeY = 30
local GUIgrpSizeX = 580
local GUIgrpSizeY = 50
local GUIgrpSlotSizeX = 110
local GUIgrpSlotSizeY = 45
  
local roleTexCoords = {DAMAGER = {left = 0.3125, right = 0.609375, top = 0.328125, bottom = 0.625}, HEALER = {left = 0.3125, right = 0.609375, top = 0.015625, bottom = 0.3125}, TANK = {left = 0, right = 0.296875, top = 0.328125, bottom = 0.625}, NONE = {left = 0.296875, right = 0.3, top = 0.625, bottom = 0.650}};

-- API Calls and functions

--author: Alundaio (aka Revolucas)
function print_table(node)
    if type(node) ~= "table" then
      print("print_table called on non-table")
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

local function printTable(table)
  --print(type(table))
  if type(table) == "table" then
    if table == nil then print("Empty table") end -- this won't work?
    for key, value in pairs(table) do
        print("k: " .. key .. " v: " .. value)
    end
  end
end

-- Iterate through the guild ranks and save index number and name in table
local function getGuildRanks() 
  --local numRanks = GuildControlGetNumRanks()
  local rinfo = {}

  for i=1,GuildControlGetNumRanks() do
    local rankName = GuildControlGetRankName(i)
    table.insert(rinfo, i, rankName)
  end
  
  return rinfo
end

-- Return expansions
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
  --print_table(raiderDB.char)
  if level == "expacs" then
    if expacInfo == nil then getExpansions() end
    for key, value in pairs(expacInfo) do
      if raiderDB.char.expac[key] == nil then raiderDB.char.expac[key] = {} end
    end
    --print_table(raiderDB.char)
  elseif level == "inst" and type(expac) == "number" then
    for key, value in pairs(tierRaidInstances.raids) do
      if raiderDB.char.expac[expac].tier == nil then raiderDB.char.expac[expac].tier = {} end
      if raiderDB.char.expac[expac].tier[key] == nil then
        raiderDB.char.expac[expac].tier[key] = {}
        raiderDB.char.expac[expac].tier[key].bosses = {}
      end
    end
    --print_table(raiderDB.char)
  end
end


----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
-- Lovingly "inspired" by RSUM
local function FrameContainsPoint(frame, x, y)
	local left, bottom, width, height = frame:GetRect()
  --print(frame:GetName() .. " - " .. frame:GetRect())
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
            --print("grp: " .. i .. " slot: " .. member)
            --print("x: " .. x .. " y: " ..y)
						return i, member;
					end
				end
				return i, nil;
			end
		end
	end
	return nil, nil;
end

-- Add/draw Out of Raid slot for raider entry.
local function drawOoR(ooRraiders)
  -- Find number of current slots
  local curSlots = rlRaiderNotListFrame.rlOoRcontent:GetNumChildren()
  local sloty = 0 -- This is the top padding
  
  -- Hide any current OoR slots
  --print("curSlots: ".. curSlots)
  for i=1,curSlots do
    --print_table(rlOoRcontentSlots[i])
    rlOoRcontentSlots[i]:Hide()
  end
  
  local function createOoRSlot(n, name, desireid)
    rlOoRcontentSlots[n] = CreateFrame("Button", "iwtbrloorslot" .. n, rlRaiderNotListFrame.rlOoRcontent) 
    rlOoRcontentSlots[n]:SetSize(GUIgrpSlotSizeX, GUIgrpSlotSizeY)
    rlOoRcontentSlots[n]:SetPoint("TOPLEFT", 4, -(GUIgrpSlotSizeY * (n-1)))
    
    rlOoRcontentSlots[n]:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
      tile = true, tileSize = 16, edgeSize = 16, 
      insets = { left = 0, right = 0, top = 4, bottom = 4 }
      })
   
    rlOoRcontentSlots[n]:SetBackdropColor(0.5,0,0,1)
    rlOoRcontentSlots[n]:SetBackdropBorderColor(0.5,0.5,0,1)
    --[[local texture = rlOoRcontentSlots[n]:CreateTexture("iwtbrloortexslot")
    texture:SetAllPoints()
    texture:SetColorTexture(0.5,0,0,1)]]
    
    local fontstring = rlOoRcontentSlots[n]:CreateFontString()
    --fontstring:SetAllPoints(rlOoRcontentSlots[1])
    fontstring:SetPoint("TOP", 0, -5)
    if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
      print("Font not valid")
    end
    fontstring:SetJustifyH("CENTER")
    fontstring:SetJustifyV("CENTER")
    fontstring:SetText(name)
    
    rlOoRcontentSlots[n].text = fontstring
    
      -- desire label
    rlOoRcontentSlots[n].desireTag = CreateFrame("Frame", "iwtboorslotdesire" .. n, rlOoRcontentSlots[n])
    rlOoRcontentSlots[n].desireTag:SetWidth(GUIgrpSlotSizeX - 8)
    rlOoRcontentSlots[n].desireTag:SetHeight((GUIgrpSlotSizeY /2) -4)
    rlOoRcontentSlots[n].desireTag:ClearAllPoints()
    rlOoRcontentSlots[n].desireTag:SetPoint("BOTTOM", 0, 4)
    
    local texture = rlOoRcontentSlots[n].desireTag:CreateTexture("iwtboorslottex")
    texture:SetAllPoints(texture:GetParent())
    texture:SetColorTexture(0,0,0.2,1)
    --[[rlOoRcontentSlots[n].desireTag:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
      tile = true, tileSize = 16, edgeSize = 16, 
      insets = { left = 4, right = 4, top = 4, bottom = 4 }})
    rlOoRcontentSlots[n].desireTag:SetBackdropColor(0,0.5,0,1)]]
    rlOoRcontentSlots[n].desireTag.text = rlOoRcontentSlots[n].desireTag:CreateFontString("iwtboorslotfont" .. n)
    rlOoRcontentSlots[n].desireTag.text:SetPoint("CENTER")
    rlOoRcontentSlots[n].desireTag.text:SetJustifyH("CENTER")
    rlOoRcontentSlots[n].desireTag.text:SetJustifyV("BOTTOM")
    local font_valid = rlOoRcontentSlots[n].desireTag.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    if not font_valid then
      print("Font not valid")
    end
    rlOoRcontentSlots[n].desireTag.text:SetText(desire[desireid])
    
    -- Context menu
    rlOoRcontentSlots[n]:RegisterForClicks("RightButtonUp")
    rlOoRcontentSlots[n]:SetScript("OnClick", function(s) L_ToggleDropDownMenu(1, nil, s.dropdown, "cursor", -25, -10) end)
    rlOoRcontentSlots[n].dropdown = CreateFrame("Frame", "iwtbcmenu" .. n , rlOoRcontentSlots[n], "L_UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(rlOoRcontentSlots[n].dropdown, slotDropDown_Menu)
  end
  
  if next(ooRraiders) ~= nil then
    local i = 1
    for name,desireid in pairs(ooRraiders) do
      --print("name: " .. name .. " desireid: ", desireid)
      if i > curSlots then
        -- Add another slot
        createOoRSlot(i, name, desireid)
      else
        -- Reuse slot
        rlOoRcontentSlots[i].text:SetText(name)
        rlOoRcontentSlots[i].desireTag.text:SetText(desire[desireid])
        rlOoRcontentSlots[i]:Show()
      end
      
      i = i +1
    end
  end
  
  
  --[[local function drawSlot(n)
    local slotx = (GUIgrpSlotSizeX +5) * (n -1)
    --local sloty = (GUIgrpSlotSizeY * i) + 5
    grpMemSlotFrame[i][n] = CreateFrame("Button", "iwtbgrpslot" .. i .. "-" .. n, grpMemFrame[i])
    grpMemSlotFrame[i][n]:SetWidth(GUIgrpSlotSizeX)
    grpMemSlotFrame[i][n]:SetHeight(GUIgrpSlotSizeY/2)
    grpMemSlotFrame[i][n]:ClearAllPoints()
    grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
    
    local texture = grpMemSlotFrame[i][n]:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
    local fontstring = grpMemSlotFrame[i][n]:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
    texture:SetAllPoints(texture:GetParent())
    texture:SetColorTexture(0,0,0,1)
    fontstring:SetPoint("TOP", 0, -5)
    fontstring:SetJustifyH("CENTER")
    fontstring:SetJustifyV("CENTER")
    local font_valid = fontstring:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    if not font_valid then
      print("Font not valid")
    end
    fontstring:SetText("Raider " .. i .. " - " .. n)

    grpMemSlotFrame[i][n].nameText = fontstring
    
    grpMemSlotFrame[i][n]:SetScript("OnClick", function(s)
      --print(s:GetName())
      s.nameText:SetText("click me!")
    end)
    
    -- desire label
    grpMemSlotFrame[i][n].desireTag = CreateFrame("Frame", "iwtbgrpslotdesire" .. i .. "-" .. n, grpMemSlotFrame[i][n])
    grpMemSlotFrame[i][n].desireTag:SetWidth(GUIgrpSlotSizeX - 4)
    grpMemSlotFrame[i][n].desireTag:SetHeight(GUIgrpSlotSizeY /2)
    grpMemSlotFrame[i][n].desireTag:ClearAllPoints()
    grpMemSlotFrame[i][n].desireTag:SetPoint("BOTTOM", 0, 0)
    
    local texture = grpMemSlotFrame[i][n].desireTag:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
    grpMemSlotFrame[i][n].desireTag.text = grpMemSlotFrame[i][n].desireTag:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
    texture:SetAllPoints(texture:GetParent())
    texture:SetColorTexture(0,0,0.2,1)
    grpMemSlotFrame[i][n].desireTag.text:SetPoint("CENTER")
    grpMemSlotFrame[i][n].desireTag.text:SetJustifyH("CENTER")
    grpMemSlotFrame[i][n].desireTag.text:SetJustifyV("BOTTOM")
    local font_valid = grpMemSlotFrame[i][n].desireTag.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    if not font_valid then
      print("Font not valid")
    end
    grpMemSlotFrame[i][n].desireTag.text:SetText(L["Unknown desire"])
      
  end]]
end

local function redrawGroup(grp)
  if type(grp) == "number" then
    for n=1, 5 do
      local slotx = (GUIgrpSlotSizeX +5) * (n -1)
      --print(grpMemSlotFrame[tgrp][n]:GetName())
      grpMemSlotFrame[grp][n]:ClearAllPoints()
      grpMemSlotFrame[grp][n]:SetParent(grpMemFrame[grp])
      grpMemSlotFrame[grp][n]:SetPoint("TOPLEFT", slotx, -3)
      grpMemSlotFrame[grp][n].nameText:SetText(L["Empty"])
      grpMemSlotFrame[grp][n].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      grpMemSlotFrame[grp][n].roleTexture:Hide()
      --grpMemSlotFrame[tgrp][n]:
    end
  else
    for i=1, 8 do
      for n=1, 5 do
      local slotx = (GUIgrpSlotSizeX +5) * (n -1)
      grpMemSlotFrame[i][n]:ClearAllPoints()
      grpMemSlotFrame[i][n]:SetParent(grpMemFrame[i])
      grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
      grpMemSlotFrame[i][n].nameText:SetText(L["Empty"])
      grpMemSlotFrame[i][n].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      grpMemSlotFrame[i][n].roleTexture:Hide()
    end
    end
  end
  
end

local function hasDesire(name, expac, tier, boss) -- compare the player name to the rl db to see if they have a desire for the selected boss
  -- First check if the player is in rl db
  for tname, rldb in pairs(raidLeaderDB.char.raiders) do
    if tname == name and rldb.expac ~= nil then
      for expacid,expacs in pairs(rldb.expac) do
        if expacid == expac then
          for tierid, tiers in pairs(expacs.tier) do
            if tierid == tier then
              for bossid, desire in pairs(tiers.bosses) do
                if bossid == boss then
                  return desire
                end
              end
            end
          end
        end
      end
    end
  end
  return nil
end

local function raidUpdate(self)
  -- Only update if frame is visible
  --if not rlMainFrame:IsShown() then return end
  
  local i = 1
  local raidMembers = {}
  while GetRaidRosterInfo(i) do
    local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
    --print(GetRaidRosterInfo(i))
    if raidMembers[subgroup] == nil then raidMembers[subgroup] = {} end
    tinsert(raidMembers[subgroup], { name= name, level = level, crole = combatRole, fileName = fileName})
    i = i +1
    if i > 40 then break end
  end
  -- Reset all frames
  redrawGroup()
  
  -- Compare raid list to RLDB for Out of Raid window - Is there a better way? Merge the two?
  local ooRraiders = {}
  local found = false
  local n = 1
  local ooRCount = 0
  for rldbName,v in pairs(raidLeaderDB.char.raiders) do
    --print(rldbName)
    found = false
    n = 1
    while GetRaidRosterInfo(n) do
      --print(rldbName)
      --print(select("1",GetRaidRosterInfo(n)))
      local name = GetRaidRosterInfo(n)
      --print(rldbName .. " : ".. name)
      if rldbName == name then
        --print("Found")
        found = true
        break
      end
      n = n +1
      if n > 40 then break end
    end
    if not found then
      -- Check desire for boss
      --print("name not found in raid")
      local desireid = hasDesire(rldbName, tonumber(rlSelectedTier.expacid), tonumber(rlSelectedTier.instid), tostring(rlSelectedTier.bossid))
      --print(desireid)
      if desireid then
        ooRraiders[rldbName] = desireid
        ooRCount = ooRCount +1
        --print("adding: " .. rldbName)
      end
    end
  end
  
  -- Send Out of raid raiders to be drawn
  if ooRCount > 0 then drawOoR(ooRraiders) end
  
  for subgrp,mem in pairs(raidMembers) do
    --grpMemSlotFrame[subgroup][n].nameText:SetText(name)
    --redrawGroup(subgrp)
    for k, player in ipairs(mem) do
      --print(player.name)
      local textColour = RAID_CLASS_COLORS[player.fileName]
      local desireid = hasDesire(player.name, tonumber(rlSelectedTier.expacid), tonumber(rlSelectedTier.instid), tostring(rlSelectedTier.bossid))
      --print("desireid: "  .. tostring(desireid))
      grpMemSlotFrame[subgrp][k].nameText:SetText(player.name)
      grpMemSlotFrame[subgrp][k].nameText:SetTextColor(textColour.r, textColour.g, textColour.b);
      grpMemSlotFrame[subgrp][k].roleTexture:SetTexCoord(roleTexCoords[player.crole].left, roleTexCoords[player.crole].right, roleTexCoords[player.crole].top, roleTexCoords[player.crole].bottom)
      grpMemSlotFrame[subgrp][k].roleTexture:Show()
      grpMemSlotFrame[subgrp][k].desireTag.text:SetText(desire[desireid] or L["Unknown desire"])
    end
  end
  --print_table(raidMembers)
end

local function removeRaiderData(f, name)
  --print("Removing data of: " .. name)
  raidLeaderDB.char.raiders[name] = nil
  raidUpdate()
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
  
  
  local raidLeaderDefaults = { -- is there any? boss required number tanks/healers/dps (dps is auto filled in assuming 20 or allow set max?)
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
        syncOnJoin = false,
        syncOnlyGuild = true,
        showOnStart = false,
        syncGuildRank = {}, -- Is this correct?
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
      showOnStart = {
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
    --[[print_table(self)
    print(type(self))
    print(self:GetObjectType())
    print(self:GetName())]]
    
    if arg2 == "expacbutton" then
      -- fill in raids with arg1 as expac id
      getInstances(arg1)
      raiderSelectedTier.expacid = arg1
      
      -- Horrible fudge to enable selecting dropdowns programmatically
      if self:GetName() ~= "expacbuttonButton" then L_UIDropDownMenu_SetText(expacButton, self:GetText()) end
      dbSchemaCheck("expacs")
      
    elseif arg2 == "expacrlbutton" then
      -- fill in raids with arg1 as expac id
      getInstances(arg1, true)
      rlSelectedTier.expacid = arg1
      if self:GetName() ~= "expacrlbuttonButton" then L_UIDropDownMenu_SetText(expacRLButton, self:GetText()) end
      
    elseif arg2 == "instancebutton" then
    if self:GetName() ~= "instancebuttonButton" then L_UIDropDownMenu_SetText(instanceButton, self:GetText()) end
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
          local newColOn = 7
          local bheight, bwidth = 50, 350
          for id, bossid in pairs(bossList.order) do
            local y = -(bheight + 20) * i
            if i > newColOn then y = -(bheight + 20) * (i - newColOn) end
            local x = 10
            if i > newColOn then x = x + (bwidth + 10) end
            local idofboss = tostring(bossid)
            --print("y: " .. y)
            --print("bossid: " .. idofboss .. " bossname: " .. bossname)
            bossFrame[idofboss] = CreateFrame("Frame", "iwtbboss" .. idofboss, raiderBossListFrame)
            bossFrame[idofboss]:SetWidth(bwidth)
            bossFrame[idofboss]:SetHeight(bheight)
            bossFrame[idofboss]:SetPoint("TOP", 0, y)
            bossFrame[idofboss]:SetPoint("LEFT", raiderBossListFrame, x, 0)
            

            
            local creatureFrame = CreateFrame("Frame", "iwtbbosscreature" .. idofboss, bossFrame[idofboss])
            
            --creatureFrame:SetWidth(128)
            --creatureFrame:SetHeight(64)
            creatureFrame:SetAllPoints(creatureFrame:GetParent())
            --creatureFrame:ClearAllPoints()
            
            creatureFrame:SetPoint("TOPLEFT", -65, 0)
            --creatureFrame:SetPoint("BOTTOM", 0, -50)
            
            local _, bossName, _, _, bossImage = EJ_GetCreatureInfo(1, bossid)
            bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
            --print(bossImage)
            -- I have no idea but I'm getting a number for boss icon?!?! Is this fileID and can be used?
            --[[if type(bossImage) == "number" then
              --bossImage = "Interface\\EncounterJournal\\UI-EJ-BOSS-" .. bossName
              bossImage = "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
            end]]
            --print(bossImage)
            local creatureTex = creatureFrame:CreateTexture("iwtbcreaturetex" .. idofboss)
            creatureTex:ClearAllPoints()
            creatureTex:SetPoint("CENTER", -85, 5)
            --creatureTex:SetPoint("LEFT", -20, 0)
            creatureTex:SetTexture(bossImage)
            --creatureTex:SetAllPoints(creatureFrame)
            --creatureTex:SetColorTexture(0.4,0.2,0.9,0.7)
            

            --local creatureTex = bossFrame[idofboss].creature:CreateTexture("iwtbcreaturetex" .. idofboss)
            --creatureTex:SetTexture(bossImage)
            --creatureTex:SetAllPoints(creatureTex:GetParent())
            --creatureTex:Show()
            
            local texture = bossFrame[idofboss]:CreateTexture("iwtbboss" .. idofboss)
            texture:SetAllPoints(bossFrame[idofboss])
            texture:SetColorTexture(0.2,0.2,0.8,0.7)
            
            -- Create a font frame to allow word-wrap
            bossFrame[idofboss].fontFrame = CreateFrame("Frame", "iwtbcreaturefontframe", bossFrame[idofboss])
            bossFrame[idofboss].fontFrame:ClearAllPoints()
            bossFrame[idofboss].fontFrame:SetHeight(bossFrame[idofboss]:GetHeight())
            bossFrame[idofboss].fontFrame:SetWidth(100)
            bossFrame[idofboss].fontFrame:SetPoint("TOPLEFT", 100, 0)
            --bossFrame[idofboss].fontFrame:SetPoint("BOTTOMRIGHT")
            
            --[[texture = bossFrame[idofboss].fontFrame:CreateTexture("iwtbbossfontframe" .. idofboss)
            texture:SetAllPoints(bossFrame[idofboss])
            texture:SetColorTexture(0.2,0.2,0.2,1)]]
             
            local fontstring = bossFrame[idofboss].fontFrame:CreateFontString("iwtbbosstext" .. idofboss)
            fontstring:SetAllPoints(bossFrame[idofboss].fontFrame)
            --fontstring:SetPoint("LEFT", 98, 0)
            if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
              print("Font not valid")
            end
            fontstring:SetJustifyH("LEFT")
            fontstring:SetJustifyV("MIDDLE")
            fontstring:SetText(bossList.bosses[bossid])
            
            --add dropdown menu for need/minor/os etc.
            local bossWantdropdown = CreateFrame("Frame", "bossWantdropdown" .. bossid, bossFrame[idofboss], "L_UIDropDownMenuTemplate")
            bossWantdropdown:SetPoint("RIGHT", 12, -2)
            --expacButton:SetScript("OnClick", MyDropDownMenuButton_OnClick)
            L_UIDropDownMenu_SetWidth(bossWantdropdown, 110) -- Use in place of dropDown:SetWidth
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
      if self:GetName() ~= "instancerlbuttonButton" then L_UIDropDownMenu_SetText(instanceRLButton, self:GetText()) end
      rlSelectedTier.instid = arg1
      -- get the boss list
      getBosses(arg1, true)
    
    elseif arg2 == "bossesrlbutton" then -- only in RL tab
      L_UIDropDownMenu_SetText(bossesRLButton, self:GetText())
      rlSelectedTier.bossid = arg1
      --print(self:GetID() .. " : " .. self:GetName())
      --print("expacid: " .. rlSelectedTier.expacid .. " tierid: " .. rlSelectedTier.instid)
      --print("bossid: ", instanceBosses.order[self:GetID()])
      --if IsInRaid() then raidUpdate() end
      raidUpdate()
      
      
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
    --print("arg1: " .. tostring(arg1) .. " arg2: " .. tostring(arg2) .. " checked: " .. tostring(checked))
    --print("expacID: " .. raiderSelectedTier.expacid .. " tierID: " .. raiderSelectedTier.instid)
    -- Desirability of the boss has changed: write to DB, change serialised string for comms, (if in the raid of the selected tier, resend to raid leader (and promoted?)?)
    raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[arg2] = arg1
    -- Is it too much overhead to do this each time? Have a button instead to serialises and send? Relies on raider to push a button and we know how hard they find that already!
    --raiderBossesStr = Serializer:Serialize(raiderDB.char.bosses)
    --print("SerStr: " .. raiderBossesStr)
    
    -- Set dropdown text to new selection
    L_UIDropDownMenu_SetSelectedID(bossFrame[arg2]:GetChildren(), self:GetID())
    -- Update hash
    --print("Old hash: " .. raiderDB.char.bossListHash)
    raiderDB.char.bossListHash = iwtb.hashData(raiderDB.char.expac) -- Do we want to hash here? Better to do it before sending or on request?
    --print(raiderDB.char.bosses[arg2])
    --print("New hash: " .. raiderDB.char.bossListHash)
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

  -----------------------------------
  -- SLOT MENU
  -----------------------------------
  
  local function slotDropDown_OnClick(self, arg1, arg2, checked)
    -- arg1 = name, arg2 = raider id
    
    -- Set dropdown text to new selection
    --L_UIDropDownMenu_SetSelectedID(bossFrame[arg2]:GetChildren(), self:GetID())
  end
  
  -- Right click menu for raid/OoR slots
  function slotDropDown_Menu(frame, level, menuList)
    --print(string.match(frame:GetName(), "%d+"))
    local name = frame:GetParent().text:GetText()
    local info
    info = L_UIDropDownMenu_CreateInfo()
    --info.func = slotDropDown_OnClick
    info.text = name
    info.isTitle = true
    info.notCheckable = true
    L_UIDropDownMenu_AddButton(info)
    
    info = L_UIDropDownMenu_CreateInfo()
    info.func = removeRaiderData --function(s, arg1, arg2, checked) print("remove data of..." .. name) end
    info.text = L["Remove data"]
    info.arg1 = name
    info.notCheckable = true
    L_UIDropDownMenu_AddButton(info)
    
    info = L_UIDropDownMenu_CreateInfo()
    info.text = "Cancel"
    info.notCheckable = true
    L_UIDropDownMenu_AddButton(info)
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
  windowframe:SetFrameStrata("DIALOG")
  windowframe:SetMovable(true)

  windowframetexture = windowframe:CreateTexture("iwtbframetexture")
  windowframetexture:SetAllPoints(windowframetexture:GetParent())
  windowframetexture:SetColorTexture(0,0,0,0.5)
  windowframe.texture = windowframetexture
  
  -- title
  local title = CreateFrame("Frame", "iwtbtitle", windowframe)
  title:SetWidth(GUItitleSizeX)
  title:SetHeight(GUItitleSizeY)
  title:SetPoint("CENTER", title:GetParent(), "TOP", 0, 0)
  title:EnableMouse(true)
  title:RegisterForDrag("LeftButton")
  title:SetScript("OnDragStart", function(s) s:GetParent():StartMoving() end)
  title:SetScript("OnDragStop", function(s) s:GetParent():StopMovingOrSizing();end)
  title:SetScript("OnHide", function(s) s:GetParent():StopMovingOrSizing() end)
  texture = title:CreateTexture("iwtbtitletex")
  texture:SetAllPoints(title)
  texture:SetColorTexture(0,0,0,0.7)
  fontstring = title:CreateFontString("iwtbtitletext")
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
  --[[fontstring = raiderBossListFrame:CreateFontString("iwtbraidertesting")
  fontstring:SetAllPoints(raiderBossListFrame)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("Boss list")]]
  
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
    --print("Hash: " .. raiderDB.char.bossListHash)
    -- TODO - Add CD timer. 30 secs?
    iwtb.sendData("udata", raiderDB.char, "raid")
    --iwtb.sendData("rhash", "0123456789", "raid") -- junk hash for testing
  end)
  
 -- Raider test button
  local raiderTestButton = CreateFrame("Button", "iwtbraidertestbutton", raiderTab, "UIPanelButtonTemplate")
  raiderTestButton:SetWidth(GUItabButtonSizeX)
  raiderTestButton:SetHeight(GUItabButtonSizeY)
  raiderTestButton:SetText("Test")
  raiderTestButton:SetPoint("CENTER", raiderTestButton:GetParent(), "BOTTOMRIGHT", -500, 30)
  texture = raiderTestButton:CreateTexture("raidertestbuttex")
  texture:SetAllPoints(raiderTestButton)
  texture:SetColorTexture(0, 0, 0, 1)
  raiderTestButton:Enable()
  raiderTestButton:RegisterForClicks("LeftButtonUp")
  raiderTestButton:SetScript("OnClick", function(s)
    --ToggleDropDownMenu(1,nil,expacButton)
    raidsDropdownMenuOnClick(expacButton.Button,7,"expacbutton")
    raidsDropdownMenuOnClick(instanceButton.Button,946,"instancebutton")
    --print_table(expacButton)
    --expacButton.Button:Click()
    --print_table(expacButton.Button)
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
  
  -- Raid Leader reset DB button
  local rlResetDBButton = CreateFrame("Button", "iwtbrlresetdbbutton", rlTab, "UIPanelButtonTemplate")
  rlResetDBButton:SetWidth(GUItabButtonSizeX)
  rlResetDBButton:SetHeight(GUItabButtonSizeY)
  rlResetDBButton:SetText(L["Reset DB"])
  rlResetDBButton:SetPoint("CENTER", rlResetDBButton:GetParent(), "BOTTOMRIGHT", -250, 30)
  texture = rlResetDBButton:CreateTexture("rlresetdbbuttex")
  texture:SetAllPoints(rlResetDBButton)
  texture:SetColorTexture(0, 0, 0, 1)
  rlResetDBButton:Enable()
  rlResetDBButton:RegisterForClicks("LeftButtonUp")
  rlResetDBButton:SetScript("OnClick", function(s)
    raidLeaderDB:ResetDB()
  end)
  
  -- Raid Leader test button
  local rlTestButton = CreateFrame("Button", "iwtbrltestbutton", rlTab, "UIPanelButtonTemplate")
  rlTestButton:SetWidth(GUItabButtonSizeX)
  rlTestButton:SetHeight(GUItabButtonSizeY)
  rlTestButton:SetText("Refresh")
  rlTestButton:SetPoint("CENTER", rlTestButton:GetParent(), "BOTTOMRIGHT", -450, 30)
  texture = rlTestButton:CreateTexture("rltestbuttex")
  texture:SetAllPoints(rlTestButton)
  texture:SetColorTexture(0, 0, 0, 1)
  rlTestButton:Enable()
  rlTestButton:RegisterForClicks("LeftButtonUp")
  rlTestButton:SetScript("OnClick", function(s)
    raidUpdate()
    --print(rlRaiderListFrame:GetWidth())
  end)
  
  -- rlRaiderListFrame
  rlRaiderListFrame = CreateFrame("Frame", "iwtbrlraiderlistframe", rlTab)
  rlRaiderListFrame:SetWidth(GUItabWindowSizeX -20)
  rlRaiderListFrame:SetHeight(GUItabWindowSizeY -20)
  rlRaiderListFrame:SetPoint("CENTER", 0, 0)
  texture = rlRaiderListFrame:CreateTexture("iwtbrlraiderlistframetex")
  texture:SetAllPoints(rlRaiderListFrame)
  texture:SetColorTexture(0.1,0.1,0.1,0.5)
  --[[fontstring = rlRaiderListFrame:CreateFontString("iwtbrlraiderlistframetesting")
  fontstring:SetAllPoints(rlRaiderListFrame)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("Raider list")]]
  
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
    
    for n=1, 5 do -- 5 frames/slots per group
      local slotx = ( (GUIgrpSlotSizeX +5) * (n -1) ) or 5 -- why you no work? should be if 0 then 5
      --local sloty = (GUIgrpSlotSizeY * i) + 5
      grpMemSlotFrame[i][n] = CreateFrame("Button", "iwtbgrpslot" .. i .. "-" .. n, grpMemFrame[i])
      grpMemSlotFrame[i][n]:SetWidth(GUIgrpSlotSizeX)
      grpMemSlotFrame[i][n]:SetHeight(GUIgrpSlotSizeY)
      grpMemSlotFrame[i][n]:ClearAllPoints()
      grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
      
      local texture = grpMemSlotFrame[i][n]:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
      local fontstring = grpMemSlotFrame[i][n]:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
      texture:SetAllPoints(texture:GetParent())
      texture:SetColorTexture(0,0,0,1)
      fontstring:SetPoint("TOP", 0, -5)
      fontstring:SetJustifyH("CENTER")
      fontstring:SetJustifyV("CENTER")
      local font_valid = fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
      if not font_valid then
        print("Font not valid")
      end
      --fontstring:SetText("Raider " .. i .. " - " .. n)
      fontstring:SetText(L["Empty"])

      grpMemSlotFrame[i][n].nameText = fontstring
      
      grpMemSlotFrame[i][n]:RegisterForDrag("LeftButton");
      grpMemSlotFrame[i][n]:RegisterForClicks("RightButtonDown");
      grpMemSlotFrame[i][n]:SetMovable(true);
      grpMemSlotFrame[i][n]:EnableMouse(true);
      grpMemSlotFrame[i][n]:SetScript("OnDragStart", function(s, ...) s:StartMoving() s:SetFrameStrata("TOOLTIP") end);
      grpMemSlotFrame[i][n]:SetScript("OnDragStop", function(s, ...)
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
          --print("tgrp: " .. targetgroup .. " sbut: " .. s:GetName())
          
          if targetmember then
            --print("slot: " .. targetmember)
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
            --print("redraw source")
            redrawGroup(targetgroup)
          end
          
          
          --RSUM_GroupSync(false);
          --RSUM_UpdateWindows();
        end
        -- Redraw source group in case button is left outside our frames
        redrawGroup(sourceGroup)
      end);

      grpMemSlotFrame[i][n]:SetScript("OnClick", function(s)
        --print(s:GetName())
        s.nameText:SetText("click me!")
      end)
      
      -- role texture
      texture = grpMemSlotFrame[i][n]:CreateTexture()
      texture:SetPoint("LEFT", 3, 12)
      --texture:SetPoint("RIGHT", texture:GetParent(), "LEFT", texture:GetParent():GetHeight() + 4, 0)
      texture:SetHeight(20)
      texture:SetWidth(20)
      texture:SetTexture("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.tga")
      texture:SetDrawLayer("OVERLAY", 7)
      grpMemSlotFrame[i][n].roleTexture = texture
      grpMemSlotFrame[i][n].roleTexture:Hide()
      
      -- desire label
      grpMemSlotFrame[i][n].desireTag = CreateFrame("Frame", "iwtbgrpslotdesire" .. i .. "-" .. n, grpMemSlotFrame[i][n])
      grpMemSlotFrame[i][n].desireTag:SetWidth(GUIgrpSlotSizeX - 4)
      grpMemSlotFrame[i][n].desireTag:SetHeight(GUIgrpSlotSizeY /2)
      grpMemSlotFrame[i][n].desireTag:ClearAllPoints()
      grpMemSlotFrame[i][n].desireTag:SetPoint("BOTTOM", 0, 0)
      
      local texture = grpMemSlotFrame[i][n].desireTag:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
      grpMemSlotFrame[i][n].desireTag.text = grpMemSlotFrame[i][n].desireTag:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
      texture:SetAllPoints(texture:GetParent())
      texture:SetColorTexture(0,0,0.2,1)
      grpMemSlotFrame[i][n].desireTag.text:SetPoint("CENTER")
      grpMemSlotFrame[i][n].desireTag.text:SetJustifyH("CENTER")
      grpMemSlotFrame[i][n].desireTag.text:SetJustifyV("BOTTOM")
      local font_valid = grpMemSlotFrame[i][n].desireTag.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
      if not font_valid then
        print("Font not valid")
      end
      grpMemSlotFrame[i][n].desireTag.text:SetText(L["Unknown desire"])
      
      --[[
      groupmemberframes[group][member]:SetFrameStrata("FULLSCREEN");
      groupmemberframes[group][member]:RegisterForDrag("LeftButton");
      groupmemberframes[group][member]:RegisterForClicks("RightButtonDown");

      groupmemberframes[group][member]:SetScript("OnEnter", RSUM_OnEnter);
      groupmemberframes[group][member]:SetScript("OnLeave", RSUM_OnLeave);]]
    end
  
  end
  
  -- Out of raid scroll list for desire
  --scrollframe 
  rlRaiderNotListFrame = CreateFrame("ScrollFrame", "iwtbrloorframe", rlRaiderListFrame) 
  --rlOoRframe:SetPoint("TOPRIGHT", rlRaiderListFrame, -25, -55)
  --rlOoRframe:SetPoint("CENTER", rlRaiderListFrame, 225, -55)
  --rlOoRframe:SetPoint("BOTTOMLEFT", rlRaiderListFrame, 0, -25)
  rlRaiderNotListFrame:SetSize((GUIgrpSlotSizeX +10), (rlRaiderListFrame:GetHeight() -160))
  --rlOoRframe:SetPoint("TOPLEFT", rlRaiderListFrame, 620, -20)
  rlRaiderNotListFrame:SetPoint("TOP", rlRaiderListFrame, 0, -55)
  --rlOoRframe:SetPoint("BOTTOMRIGHT", rlRaiderListFrame, -20, -20)
  rlRaiderNotListFrame:SetPoint("BOTTOMRIGHT", rlRaiderListFrame, -30, 20)
  
  local texture = rlRaiderNotListFrame:CreateTexture(nil, "BACKGROUND", 5) 
  texture:SetAllPoints(texture:GetParent())
  texture:SetTexture(0, 0.5, 0, 1)
  --[[local fontstring = rlRaiderNotListFrame:CreateFontString()
  fontstring:SetAllPoints(rlRaiderNotListFrame)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("scroll list")]]
  --frame.scrollframe = scrollframe 

  --scrollbar 
  local rlOoRscrollbar = CreateFrame("Slider", "iwtbrloorscrollbar", rlRaiderNotListFrame, "UIPanelScrollBarTemplate") 
  rlOoRscrollbar:SetPoint("TOPLEFT", rlRaiderNotListFrame, "TOPRIGHT", 4, -16) 
  rlOoRscrollbar:SetPoint("BOTTOMLEFT", rlRaiderNotListFrame, "BOTTOMRIGHT", 4, 16) 
  rlOoRscrollbar:SetMinMaxValues(1, 500) -- Need to set dynamically this according to slots slotsizey /2 ?
  rlOoRscrollbar:SetValueStep(1) 
  rlOoRscrollbar.scrollStep = 1 
  rlOoRscrollbar:SetValue(0) 
  rlOoRscrollbar:SetWidth(16) 
  rlOoRscrollbar:SetScript("OnValueChanged", 
  function (self, value) 
    self:GetParent():SetVerticalScroll(value) 
  end) 
  local scrollbg = rlOoRscrollbar:CreateTexture(nil, "BACKGROUND") 
  scrollbg:SetAllPoints(scrollbar) 
  scrollbg:SetTexture(0, 0, 0, 0.4) 
  rlRaiderNotListFrame.rlOoRscrollbar = rlOoRscrollbar 

  --content frame 
  local rlOoRcontent = CreateFrame("Frame", "iwtbrloorlist", rlRaiderNotListFrame) 
  rlOoRcontent:SetWidth((rlOoRcontent:GetParent():GetWidth()) -2)
  rlOoRcontent:SetHeight(1500) -- Need to set dynamically this according to slots slotsizey + 20?
  --rlOoRcontent:SetHeight(rlRaiderNotListFrame:GetHeight())
  rlOoRcontent:ClearAllPoints()
  rlOoRcontent:SetPoint("TOPLEFT", 0, 0)
  local texture = rlOoRcontent:CreateTexture() 
  texture:SetAllPoints(texture:GetParent()) 
  texture:SetTexture(0, 0, 0.5, 1) 
  --texture:SetTexture("Interface\\GLUES\\MainMenu\\Glues-BlizzardLogo") 
  --rlOoRcontent.texture = texture 
  --scrollframe.content = content 
  --[[local fontstring = rlOoRcontent:CreateFontString()
  fontstring:SetAllPoints(rlOoRcontent)
  if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
    print("Font not valid")
  end
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("content list")]]

  rlRaiderNotListFrame:SetScrollChild(rlOoRcontent)
  rlRaiderNotListFrame.rlOoRcontent = rlOoRcontent
  
  ------------------------------------------------
  -- Dropdown buttons (for raid leader tab)
  ------------------------------------------------
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
  L_UIDropDownMenu_Initialize(expacButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(expacButton, L["Select expansion"])
  
  instanceButton = CreateFrame("Frame", "instancebutton", raiderTab, "L_UIDropDownMenuTemplate")
  instanceButton:SetPoint("TOPLEFT", 250, -20)
  L_UIDropDownMenu_SetWidth(instanceButton, 200) -- Use in place of dropDown:SetWidth
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
    raidUpdate()
    raiderTab:Hide()  -- Show page 1.
  end)
  
  -- Register tabs
  PanelTemplates_SetNumTabs(windowframe, 2)  -- 2 because there are 2 frames total.
  PanelTemplates_SetTab(windowframe, 1)     -- 1 because we want tab 1 selected.
  raiderTab:Show()  -- Show page 1.
  rlTab:Hide()  -- Hide all other pages (in this case only one).
  
  -- Hide or show main window on start via options
  if not db.char.showOnStart then windowframe:Hide() end
  
  -- Trying to set the dropdowns programmatically. Allow this via options?
  raidsDropdownMenuOnClick(expacButton.Button,7,"expacbutton")
  raidsDropdownMenuOnClick(expacRLButton.Button,7,"expacrlbutton")
  raidsDropdownMenuOnClick(instanceButton.Button,946,"instancebutton")
  raidsDropdownMenuOnClick(instanceRLButton.Button,946,"instancerlbutton")
  
  -- Register listening events
  iwtb:RegisterEvent("GROUP_ROSTER_UPDATE", raidUpdate)
end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
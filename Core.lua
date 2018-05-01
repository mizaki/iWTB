iwtb = LibStub("AceAddon-3.0"):NewAddon("iWTB", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
iwtb.L = LibStub("AceLocale-3.0"):GetLocale("iWTB")
local L = iwtb.L

--Define some vars
local db
local raiderDB
local raidLeaderDB
local rankInfo = {} -- Guild rank info
local expacInfo = nil -- Expacs for dropdown
local raidsInfo = nil -- RaidID = ExpacID, for use on bosskillpopup
local tierRaidInstances = nil -- Raid instances for raider tab dropdown
local tierRLRaidInstances = nil 
local instanceBosses = nil -- Bosses for RL tab dropdown
local frame
local windowframe -- main frame
local raiderTab -- raider tab frame
local rlTab -- raid leader tab frame
local createMainFrame
local raiderBossListFrame -- main frame listing bosses (raider)
local rlRaiderListFrame -- main frame listing raiders spots
local bossKillPopup -- Pop up frame for changing desire on boss kill
local bossKillPopupSelectedDesireId = 0
local grpMemFrame = {} -- table containing each frame per group
local grpMemSlotFrame = {} -- table containing each frame per slot for each group
local rlRaiderNotListFrame -- main frame listing raiders NOT in the raid but in the rl db
local rlOoRcontentSlots = {} -- Out of Raid slots
local bossFrame = {}-- table of frames containing each boss frame
local raiderBossesStr = "" -- raider boss desire seralised
local desire = {L["BiS"], L["Need"], L["Minor"], L["Off spec"], L["No need"]}
local bossDesire = nil
local bossKillInfo = {bossid = 0, desireid = 0, expacid = 0, instid = 0}

local raiderSelectedTier = {} -- Tier ID from dropdown Must be a better way but cba for now.
local rlSelectedTier = {} -- Must be a better way but cba for now.

local rlStatusContent = {} -- RL status lines 1-10

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
local GUIgrpSizeX = 579
local GUIgrpSizeY = 51
local GUIgrpSlotSizeX = 110
local GUIgrpSlotSizeY = 45
local GUIRStatusSizeX = 300 
local GUIRStatusSizeY = 15
local GUIkillWindowSizeX = 300
local GUIkillWindowSizeY = 160
  
local roleTexCoords = {DAMAGER = {left = 0.3125, right = 0.609375, top = 0.328125, bottom = 0.625}, HEALER = {left = 0.3125, right = 0.609375, top = 0.015625, bottom = 0.3125}, TANK = {left = 0, right = 0.296875, top = 0.328125, bottom = 0.625}, NONE = {left = 0.296875, right = 0.3, top = 0.625, bottom = 0.650}};


-- API Calls and functions

--author: Alundaio (aka Revolucas)
local function print_table(node)
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
    instanceBosses = raidBosses
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

local function dbBossCheck(instid, bossid)
  if raiderDB.char.raids[instid] == nil then raiderDB.char.raids[instid] = {} end
  if raiderDB.char.raids[instid][bossid] == nil then raiderDB.char.raids[instid][bossid] = {} end
end

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
-- Lovingly "inspired" by RSUM
local function FrameContainsPoint(frame, x, y)
	local left, bottom, width, height = frame:GetRect()
	if x >= left then
		if y >= bottom then
			if x <= left + width then
				if y <= bottom + height then
					return true
				end
			end
		end
	end
	return false
end

-- search for mouseover frame which is actually overlapped by the dragged frame - does not work correctly for slots in same grp if > dragged. Anchor point problem? Position on drag changes GetRect?
local function MemberFrameContainsPoint(x, y)
	if FrameContainsPoint(rlRaiderListFrame, x, y) then
		for i=1,8 do
			if FrameContainsPoint(grpMemFrame[i], x, y) then
				for member=1,5 do
					if FrameContainsPoint(grpMemSlotFrame[i][member], x, y) then
						return i, member
					end
				end
				return i, nil
			end
		end
	end
	return nil, nil
end

local function slotIsEmpty(f)
  if f:GetAttribute("raidid") >0 then return false else return true end
end

local function grpHasEmpty(grp)
  local result = false
  for i=1, 5 do
    if slotIsEmpty(grpMemSlotFrame[grp][i]) then
      result = true
      break
    end
  end
  return result
end

function iwtb.isGuildMember(name)
  local _, onlineGmem = GetNumGuildMembers()
  if not string.find(name, "-") then name = name .. "-" .. GetRealmName() end -- Append realm name if missing
  for i=1, onlineGmem do
    if GetGuildRosterInfo(i) == name then return true end
  end
  return false
end

local function hasNote(name, tier, boss) -- compare the player name to the rl db to see if they have a note for the selected boss
  -- First check if the player is in rl db
  for tname, rldb in pairs(rlProfileDB.profile.raiders) do
    if tname == name and rldb.raids ~= nil then
      for tierid, tiers in pairs(rldb.raids) do
        if tierid == tier then
          for bossid, bosses in pairs(tiers) do
            if bossid == boss then
              if bosses.note and bosses.note ~= "" then return true, bosses.note end
            end
          end
        end
      end
    end
  end
  return false, ""
end

-- Add/draw Out of Raid slot for raider entry.
local function drawOoR(ooRraiders)
  -- Find number of current slots
  local curSlots = rlRaiderNotListFrame.rlOoRcontent:GetNumChildren()
  --local sloty = 0 -- This is the top padding
  
  -- Hide any current OoR slots
  for i=1,curSlots do
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
    
    local fontstring = rlOoRcontentSlots[n]:CreateFontString()
    fontstring:SetPoint("TOP", 0, -5)
    fontstring:SetFontObject("Game12Font")
    fontstring:SetJustifyH("CENTER")
    fontstring:SetJustifyV("CENTER")
    fontstring:SetText(name)
    
    rlOoRcontentSlots[n].nameText = fontstring
    
    -- desire label
    rlOoRcontentSlots[n].desireTag = CreateFrame("Frame", "iwtboorslotdesire" .. n, rlOoRcontentSlots[n])
    rlOoRcontentSlots[n].desireTag:SetWidth(GUIgrpSlotSizeX - 8)
    rlOoRcontentSlots[n].desireTag:SetHeight((GUIgrpSlotSizeY /2) -4)
    rlOoRcontentSlots[n].desireTag:ClearAllPoints()
    rlOoRcontentSlots[n].desireTag:SetPoint("BOTTOM", 0, 4)
    
    local texture = rlOoRcontentSlots[n].desireTag:CreateTexture("iwtboorslottex")
    texture:SetAllPoints(texture:GetParent())
    texture:SetColorTexture(0,0,0.2,1)
    rlOoRcontentSlots[n].desireTag.text = rlOoRcontentSlots[n].desireTag:CreateFontString("iwtboorslotfont" .. n)
    rlOoRcontentSlots[n].desireTag.text:SetPoint("CENTER")
    rlOoRcontentSlots[n].desireTag.text:SetJustifyH("CENTER")
    rlOoRcontentSlots[n].desireTag.text:SetJustifyV("BOTTOM")
    --rlOoRcontentSlots[n].desireTag.text:SetFont(GUIfont, 10, "")
    rlOoRcontentSlots[n].desireTag.text:SetFontObject("SpellFont_Small")
    rlOoRcontentSlots[n].desireTag.text:SetText(desire[desireid])
    
    -- note
    rlOoRcontentSlots[n].note = CreateFrame("Frame", "iwtboorslotnote" .. n, rlOoRcontentSlots[n].desireTag)
    rlOoRcontentSlots[n].note:SetWidth(16)
    rlOoRcontentSlots[n].note:SetHeight(16)
    rlOoRcontentSlots[n].note:ClearAllPoints()
    rlOoRcontentSlots[n].note:SetPoint("BOTTOMRIGHT", 0, 1)
    
    local hasNote, noteTxt = hasNote(name, tonumber(rlSelectedTier.instid), tostring(rlSelectedTier.bossid))
    texture = rlOoRcontentSlots[n].note:CreateTexture("iwtboornotetex")
    texture:SetWidth(16)
    texture:SetHeight(16)
    texture:SetPoint("TOPLEFT", 0, 0)
    texture:SetDrawLayer("ARTWORK",7)
    if hasNote then
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    else
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
    end
    rlOoRcontentSlots[n].note.texture = texture
    
    rlOoRcontentSlots[n].note:SetAttribute("hasNote", true)
    rlOoRcontentSlots[n].note:SetAttribute("noteTxt", noteTxt)
    rlOoRcontentSlots[n].note:SetScript("OnEnter", function(s)
                                GameTooltip:SetOwner(s)
                                if rlOoRcontentSlots[n].note:GetAttribute("hasNote") then
                                  GameTooltip:AddLine(rlOoRcontentSlots[n].note:GetAttribute("noteTxt"))
                                  GameTooltip:Show()
                                end
                              end)
		rlOoRcontentSlots[n].note:SetScript("OnLeave", function(s) GameTooltip:Hide() end)
    
    -- Context menu
    rlOoRcontentSlots[n]:RegisterForClicks("RightButtonUp")
    rlOoRcontentSlots[n]:SetScript("OnClick", function(s) L_ToggleDropDownMenu(1, nil, s.dropdown, "cursor", -25, -10) end)
    rlOoRcontentSlots[n].dropdown = CreateFrame("Frame", "iwtbcmenu" .. n , rlOoRcontentSlots[n], "L_UIDropDownMenuTemplate")
    L_UIDropDownMenu_Initialize(rlOoRcontentSlots[n].dropdown, slotDropDown_Menu)
  end
  
  if next(ooRraiders) ~= nil then
    local i = 1
    for name,desireid in pairs(ooRraiders) do -- [name] = desireid
      if i > curSlots then
        -- Add another slot
        createOoRSlot(i, name, desireid)
      else
        local hasNote, noteTxt = hasNote(name, tonumber(rlSelectedTier.instid), tostring(rlSelectedTier.bossid))
        -- Reuse slot
        rlOoRcontentSlots[i].nameText:SetText(name)
        rlOoRcontentSlots[i].desireTag.text:SetText(desire[desireid])
        
        if hasNote then
          rlOoRcontentSlots[i].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
          rlOoRcontentSlots[i].note:SetAttribute("hasNote", true)
          rlOoRcontentSlots[i].note:SetAttribute("noteTxt", noteTxt)
        else
          rlOoRcontentSlots[i].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
          rlOoRcontentSlots[i].note:SetAttribute("hasNote", false)
          rlOoRcontentSlots[i].note:SetAttribute("noteTxt", "")
        end
        rlOoRcontentSlots[i]:Show()
      end
      i = i +1
      if i > 5 then rlRaiderNotListFrame.text:Hide() else rlRaiderNotListFrame.text:Show() end
    end
  --rlRaiderNotListFrame.rlOoRcontent:SetHeight(GUIgrpSlotSizeY * i + 5)
  rlRaiderNotListFrame.rlOoRscrollbar:SetMinMaxValues(1, (i-1)*((GUIgrpSlotSizeY)/2))
  --rlRaiderNotListFrame.rlOoRscrollbar:SetValueStep(i)
  end
end

local function redrawGroup(grp)
  if type(grp) == "number" then
    for n=1, 5 do
      local slotx = (GUIgrpSlotSizeX * (n -1)) + (5 * n-1)
      grpMemSlotFrame[grp][n]:ClearAllPoints()
      grpMemSlotFrame[grp][n]:SetParent(grpMemFrame[grp])
      grpMemSlotFrame[grp][n]:SetPoint("TOPLEFT", slotx, -3)
      grpMemSlotFrame[grp][n].texture:SetColorTexture(0.2, 0.2 ,0.2 ,1)
      grpMemSlotFrame[grp][n].nameText:SetText(L["Empty"])
      grpMemSlotFrame[grp][n]:SetAttribute("raidid", 0)
      grpMemSlotFrame[grp][n].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      grpMemSlotFrame[grp][n].roleTexture:Hide()
    end
  else
    for i=1, 8 do
      for n=1, 5 do
      local slotx = (GUIgrpSlotSizeX * (n -1)) + (5 * n-1)
      grpMemSlotFrame[i][n]:ClearAllPoints()
      grpMemSlotFrame[i][n]:SetParent(grpMemFrame[i])
      grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
      grpMemSlotFrame[i][n].texture:SetColorTexture(0.2, 0.2 ,0.2 ,1)
      grpMemSlotFrame[i][n].nameText:SetText(L["Empty"])
      grpMemSlotFrame[i][n]:SetAttribute("raidid", 0)
      grpMemSlotFrame[i][n].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      grpMemSlotFrame[i][n].roleTexture:Hide()
    end
    end
  end
end

local function hasDesire(name, expac, tier, boss) -- compare the player name to the rl db to see if they have a desire for the selected boss - expac depreciated
  -- First check if the player is in rl db
  for tname, rldb in pairs(rlProfileDB.profile.raiders) do
    if tname == name and rldb.raids ~= nil then
      for tierid, tiers in pairs(rldb.raids) do
        if tierid == tier then
          for bossid, bosses in pairs(tiers) do
            if bossid == boss then
              if bosses.desireid then return bosses.desireid end
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
  if not windowframe:IsShown() or not rlTab:IsShown() then
    return
  end
  
  local i = 1
  local raidMembers = {}
  while GetRaidRosterInfo(i) do
    local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
    if raidMembers[subgroup] == nil then raidMembers[subgroup] = {} end
    tinsert(raidMembers[subgroup], { name= name, level = level, crole = combatRole, fileName = fileName, raidid = i, isDead = isDead, online = online }) -- level 0 == offline
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
  --for rldbName,v in pairs(raidLeaderDB.char.raiders) do -- can convert
  for rldbName,v in pairs(rlProfileDB.profile.raiders) do -- can convert
    found = false
    n = 1
    while GetRaidRosterInfo(n) do
      local name = GetRaidRosterInfo(n)
      if rldbName == name then
        found = true
        break
      end
      n = n +1
      if n > 40 then break end
    end
    if not found then
      -- Check desire for boss - expacid depreciated
      local desireid = hasDesire(rldbName, tonumber(rlSelectedTier.expacid), tonumber(rlSelectedTier.instid), tostring(rlSelectedTier.bossid))
      if desireid then
        ooRraiders[rldbName] = desireid
        ooRCount = ooRCount +1
      end
    end
  end
  
  -- Send Out of raid raiders to be drawn
  if ooRCount > 0 then drawOoR(ooRraiders) end
  
  for subgrp,mem in pairs(raidMembers) do -- can convert
    for k, player in ipairs(mem) do
      local textColour = RAID_CLASS_COLORS[player.fileName]
      local desireid = hasDesire(player.name, tonumber(rlSelectedTier.expacid), tonumber(rlSelectedTier.instid), tostring(rlSelectedTier.bossid))
      grpMemSlotFrame[subgrp][k]:SetAttribute("raidid", player.raidid) -- We can use this when changing player group
      grpMemSlotFrame[subgrp][k].texture:SetColorTexture(0, 0 ,0 ,1)
      grpMemSlotFrame[subgrp][k].nameText:SetText(player.name)
      if player.online then
        grpMemSlotFrame[subgrp][k].nameText:SetTextColor(textColour.r, textColour.g, textColour.b)
      else
        grpMemSlotFrame[subgrp][k].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      end
      grpMemSlotFrame[subgrp][k].roleTexture:SetTexCoord(roleTexCoords[player.crole].left, roleTexCoords[player.crole].right, roleTexCoords[player.crole].top, roleTexCoords[player.crole].bottom)
      grpMemSlotFrame[subgrp][k].roleTexture:Show()
      grpMemSlotFrame[subgrp][k].desireTag.text:SetText(desire[desireid] or L["Unknown desire"])
      
      local hasNote, noteTxt = hasNote(player.name, tonumber(rlSelectedTier.instid), tostring(rlSelectedTier.bossid))
      if hasNote then
        grpMemSlotFrame[subgrp][k].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        grpMemSlotFrame[subgrp][k].note:SetAttribute("hasNote", true)
        grpMemSlotFrame[subgrp][k].note:SetAttribute("noteTxt", noteTxt)
      else
        grpMemSlotFrame[subgrp][k].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
        grpMemSlotFrame[subgrp][k].note:SetAttribute("hasNote", false)
        grpMemSlotFrame[subgrp][k].note:SetAttribute("noteTxt", "")
      end
    end
  end
end

function iwtb.setStatusText(f, text)
  local curTop = rlTab.rlStatusPanel.text:GetText()
  local function churnContent(statuses)
    -- insert at top
    table.insert(statuses, 1, curTop)
    -- remove bottom
    if #statuses > 10 then table.remove(statuses) end
    return statuses
  end
  
  if f == "raider" then
    raiderTab.raiderStatusPanel.text:SetText(text)
    raiderTab.raiderStatusPanel.anim:Play()
  elseif f == "raidleader" then
    rlTab.rlStatusPanel.text:SetText(text) -- Set top to latest
    rlTab.rlStatusPanel.anim:Play()
    rlStatusContent = churnContent(rlStatusContent)
    for k,v in pairs(rlStatusContent) do -- can convert
      rlTab.rlStatusPanel.content[k].text:SetText(v)
    end
  end
end

local function removeRaiderData(f, name)
  --raidLeaderDB.char.raiders[name] = nil
  wipe(rlProfileDB.profile.raiders[name])
  iwtb.setStatusText("raidleader", L["Removed data - "] .. name)
  raidUpdate()
end

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
    if windowframe:IsShown() then
      windowframe:Hide()
      windowframe.title:Hide()
    else
      windowframe.title:Show()
      windowframe:Show()
      raidUpdate()
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
  
  options = {
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
      if windowframe:IsShown() then
        windowframe:Hide()
        windowframe.title:Hide()
      else
        windowframe.title:Show()
        windowframe:Show()
        raidUpdate()
      end
    else
      local cmd, arg = strsplit(" ", input)
      if cmd == "debugp" then
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
  
  raidsInfo = buildInstances()
  
  -- What to do when item is clicked
  local function raidsDropdownMenuOnClick(self, arg1, arg2, checked)
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
      rlSelectedTier.expacid = arg1
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
            local texture = bossFrame[idofboss]:CreateTexture("iwtbboss" .. idofboss)
            texture:SetAllPoints(bossFrame[idofboss])
            texture:SetColorTexture(0.2,0.2,0.8,0.7)
            
            -- Create a font frame to allow word-wrap
            bossFrame[idofboss].fontFrame = CreateFrame("Frame", "iwtbcreaturefontframe", bossFrame[idofboss])
            bossFrame[idofboss].fontFrame:ClearAllPoints()
            bossFrame[idofboss].fontFrame:SetHeight(bossFrame[idofboss]:GetHeight())
            bossFrame[idofboss].fontFrame:SetWidth(100)
            bossFrame[idofboss].fontFrame:SetPoint("TOPLEFT", 100, 0)
             
            local fontstring = bossFrame[idofboss].fontFrame:CreateFontString("iwtbbosstext" .. idofboss)
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
            if raiderDB.char.raids[raiderSelectedTier.instid]
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss]
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note ~= "" then
              bossFrame[idofboss].addNote:SetText(L["Edit note"])
            else
              bossFrame[idofboss].addNote:SetText(L["Add note"])
            end
            bossFrame[idofboss].addNote:Enable()
            bossFrame[idofboss].addNote:RegisterForClicks("LeftButtonUp")
            bossFrame[idofboss].addNote:SetScript("OnClick", function(s)
              local editbox = CreateFrame("EditBox", "iwtbaddnoteedit", bossFrame[idofboss].addNote, "InputBoxTemplate")
              editbox:SetSize(300, 15)
              editbox:SetPoint("BOTTOMRIGHT", 0, 0)
              editbox:HighlightText()
              
              dbBossCheck(raiderSelectedTier.instid, idofboss)
              if raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note then
                editbox:SetText(raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note)
              end
              editbox:SetScript("OnKeyUp", function(s, key)
                        if key == "ESCAPE" or key == "ENTER" then
                          if s:GetText() ~= "" then
                            dbBossCheck(raiderSelectedTier.instid, idofboss)
                            raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note = s:GetText()
                            bossFrame[idofboss].addNote:SetText(L["Edit note"])
                          end
                          s:Hide()
                        end
                      end)
              editbox:SetScript("OnEnterPressed", function(s)
                if s:GetText() ~= "" then
                  dbBossCheck(raiderSelectedTier.instid, idofboss)
                  raiderDB.char.raids[raiderSelectedTier.instid][idofboss].note = s:GetText()
                  bossFrame[idofboss].addNote:SetText(L["Edit note"])
                end
                s:ClearFocus()
                s:Hide()
              end)
              bossFrame[idofboss].addNote.editbox = editbox
            end)
            
            
      
            -- add dropdown menu for need/minor/os etc.
            local bossWantdropdown = CreateFrame("Frame", "bossWantdropdown" .. bossid, bossFrame[idofboss], "L_UIDropDownMenuTemplate")
            bossWantdropdown:SetPoint("RIGHT", 12, 7)
            L_UIDropDownMenu_SetWidth(bossWantdropdown, 110)
            L_UIDropDownMenu_Initialize(bossWantdropdown, bossWantDropDown_Menu)
            bossFrame[idofboss].dropdown = bossWantdropdown
            
            --if raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses ~= nil
            --and raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[idofboss] ~= nil then
            if raiderDB.char.raids[raiderSelectedTier.instid] ~= nil
            and raiderDB.char.raids[raiderSelectedTier.instid][idofboss] ~= nil then
              L_UIDropDownMenu_SetText(bossWantdropdown, desire[raiderDB.char.raids[raiderSelectedTier.instid][idofboss].desireid])
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
      rlSelectedTier.instid = arg1
      getBosses(arg1, true)
    
    elseif arg2 == "bossesrlbutton" then -- only in RL tab
      L_UIDropDownMenu_SetText(bossesRLButton, self:GetText())
      rlSelectedTier.bossid = arg1
      raidUpdate()
    end
  end
  
  -- Fill menu with items
  local function raidsDropdownMenu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
    if frame:GetName() == "expacbutton" then
      -- Get expansions
      if expacInfo == nil then getExpansions() end
      info.func = raidsDropdownMenuOnClick
      for key, value in pairs(expacInfo) do -- can convert
        info.text, info.notCheckable, info.arg1, info.arg2 = value, true, key, frame:GetName()
        L_UIDropDownMenu_AddButton(info)
      end
    
    elseif frame:GetName() == "expacrlbutton" then
      -- Get expansions
      if expacInfo == nil then getExpansions() end
      info.func = raidsDropdownMenuOnClick
      for key, value in pairs(expacInfo) do -- can convert
        info.text, info.notCheckable, info.arg1, info.arg2 = value, true, key, frame:GetName()
        L_UIDropDownMenu_AddButton(info)
      end
      
    elseif frame:GetName() == "instancebutton" then
      -- Get raids for expac
      if tierRaidInstances ~= nil then
        info.func = raidsDropdownMenuOnClick
        for key, value in pairs(tierRaidInstances.order) do -- Use .order as .raids is sorted by instanceid which is not in the correct order.
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
  end
  
  --------------------------------------------------------------------
  -- DESIRABILITY MENU FUNCTIONS
  --------------------------------------------------------------------
  
  local function bossWantDropDown_OnClick(self, arg1, arg2, checked)
    -- arg1 = desire id, arg2 = boss id
    -- Desirability of the boss has changed: write to DB, change serialised string for comms, (if in the raid of the selected tier, resend to raid leader (and promoted?)?)
    --old data layout - raiderDB.char.expac[raiderSelectedTier.expacid].tier[raiderSelectedTier.instid].bosses[arg2] = arg1
    dbBossCheck(raiderSelectedTier.instid, arg2)
    raiderDB.char.raids[raiderSelectedTier.instid][arg2].desireid = arg1
    -- Is it too much overhead to do this each time? Have a button instead to serialises and send? Relies on raider to push a button and we know how hard they find that already!
    --raiderBossesStr = Serializer:Serialize(raiderDB.char.bosses)
    
    -- Set dropdown text to new selection
    L_UIDropDownMenu_SetSelectedID(bossFrame[arg2].dropdown, self:GetID())
    
    -- Update hash
    raiderDB.char.bossListHash = iwtb.hashData(raiderDB.char.raids) -- Do we want to hash here? Better to do it before sending or on request?
  end
    
  -- Fill menu with desirability list
  function bossWantDropDown_Menu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
    local idofboss = string.match(frame:GetName(), "%d+")
    info.func = bossWantDropDown_OnClick
    for desireid, name in pairs(desire) do
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

  --------------------------------------------------------------------
  -- KILL POPUP BOSS MENU FUNCTIONS
  --------------------------------------------------------------------
  
  local function bossKillWantDropDown_OnClick(self, arg1, arg2, checked)
    -- arg1 = desire id, arg2 = boss id
    -- Set dropdown text to new selection
    if arg1 > 0 then
      --L_UIDropDownMenu_SetSelectedID(bossKillPopup.desireDrop, arg1) -- For "reasons" this sometimes doesn't work so SetText used instead.
      L_UIDropDownMenu_SetText(bossKillPopup.desireDrop, desire[arg1])
    else
      L_UIDropDownMenu_SetText(bossKillPopup.desireDrop, L["Select desirability"])
    end
    bossKillPopupSelectedDesireId = self:GetID()
  end
    
  -- Fill menu with desirability list
  local function bossKillWantDropDown_Menu(frame, level, menuList)
    local info = L_UIDropDownMenu_CreateInfo()
    info.func = bossKillWantDropDown_OnClick
    for desireid, name in pairs(desire) do
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
    local curInst = EJ_GetCurrentInstance() -- 946, antorus
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
      self:ScheduleTimer("hideKillPopup", db.char.autohideKillTime)
    end
  end
  
  -- Raid welcome
  local function enterInstance(e, name)
    if db.char.showPopup and GetRaidDifficultyID() == 16 then
      iwtb:RegisterEvent("BOSS_KILL", bossKilled)
    end
  end
  
  local function leftGroup()
    iwtb:UnregisterEvent("BOSS_KILL")
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
  
  -- Right click menu for raid/OoR slots
  function slotDropDown_Menu(frame, level, menuList)
    local fname = string.match(frame:GetName(), "%a+")
    if fname == "iwtbslotcmenu" and slotIsEmpty(frame:GetParent()) then
      return
    else
      local name = frame:GetParent().nameText:GetText()
      local info
      info = L_UIDropDownMenu_CreateInfo()
      info.text = name
      info.isTitle = true
      info.notCheckable = true
      L_UIDropDownMenu_AddButton(info)
      
      info = L_UIDropDownMenu_CreateInfo()
      info.func = removeRaiderData
      info.text = L["Remove data"]
      info.arg1 = name
      info.notCheckable = true
      L_UIDropDownMenu_AddButton(info)
      
      if fname == "iwtbslotcmenu" then
        info = L_UIDropDownMenu_CreateInfo()
        info.func = function(s, arg1, arg2, checked) UninviteUnit(name) end
        info.text = L["Remove"]
        info.arg1 = name
        info.notCheckable = true
        L_UIDropDownMenu_AddButton(info)
      end
      
      info = L_UIDropDownMenu_CreateInfo()
      info.text = L["Cancel"]
      info.notCheckable = true
      L_UIDropDownMenu_AddButton(info)
    end
  end
  
  windowframe = CreateFrame("Frame", "iwtbwindow", UIParent)
  windowframe:SetWidth(GUIwindowSizeX)
  windowframe:SetHeight(GUIwindowSizeY)
  windowframe:SetPoint("CENTER", 0, 0)
  windowframe:SetFrameStrata("DIALOG")
  windowframe:SetMovable(true)
  
  --tinsert(UISpecialFrames,"iwtbwindow")

  windowframetexture = windowframe:CreateTexture("iwtbframetexture")
  windowframetexture:SetAllPoints(windowframetexture:GetParent())
  windowframetexture:SetColorTexture(0,0,0,0.5)
  windowframe.texture = windowframetexture
  
  -- title
  local title = CreateFrame("Button", "iwtbtitle", UIParent)
  title:SetWidth(GUItitleSizeX)
  title:SetHeight(GUItitleSizeY)
  title:SetPoint("CENTER", windowframe, "TOP", 0, 0)
  title:SetFrameStrata("DIALOG")
  title:EnableMouse(true)
  title:RegisterForDrag("LeftButton")
  title:RegisterForClicks("LeftButtonUp")
  title:SetScript("OnDragStart", function(s) windowframe:StartMoving() end)
  title:SetScript("OnDragStop", function(s) windowframe:StopMovingOrSizing();end)
  title:SetScript("OnHide", function(s) windowframe:StopMovingOrSizing() end)
  title:SetScript("OnDoubleClick", function(s)
    if windowframe:IsShown() then windowframe:Hide() else windowframe:Show() end
  end)
  texture = title:CreateTexture("iwtbtitletex")
  texture:SetAllPoints(title)
  texture:SetColorTexture(0,0,0,1)
  fontstring = title:CreateFontString("iwtbtitletext")
  fontstring:SetAllPoints(title)
  fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  fontstring:SetText("iWTB - I Want That Boss!")
  windowframe.title = title
  
  button = CreateFrame("Button", "iwtbexit", title, "UIPanelCloseButton")
  button:SetWidth(40)
  button:SetHeight(40)
  button:SetPoint("CENTER", button:GetParent(), "TOPRIGHT", 0, 0)
  button:Enable()
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", function(s)
    windowframe:Hide()
    windowframe.title:Hide()
  end)
  
  --tinsert(UISpecialFrames,"title")
  
  -- Tabs
  
  -- Tutorial frame
  tutorialFrame = CreateFrame("Frame", "iwtbtutorialframe", windowframe)
  tutorialFrame:SetWidth(GUItabWindowSizeX-30)
  tutorialFrame:SetHeight(GUItabWindowSizeY-30)
  tutorialFrame:SetFrameStrata("FULLSCREEN")
  tutorialFrame:SetPoint("CENTER", 0, -20)
  texture = tutorialFrame:CreateTexture("iwtbtutorialtex")
  texture:SetAllPoints(tutorialFrame)
  texture:SetColorTexture(0.1,0.1,0.1,1)
  
  tutorialHTML = CreateFrame("SimpleHTML", "iwtbtutorialhtml", tutorialFrame)
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
  tutorialCheckButton = CreateFrame("CheckButton", "iwtbtutorialcheckbutton", tutorialFrame, "ChatConfigCheckButtonTemplate")
  tutorialCheckButton:SetPoint("BOTTOMLEFT", 10, 10)
  tutorialCheckButton:SetChecked(db.char.showTutorial)
  iwtbtutorialcheckbuttonText:SetText(L["Show on start"])
  tutorialCheckButton.tooltip = L["Show the tutorial window when first opened"]
  tutorialCheckButton:SetScript("OnClick", 
    function(s)
      if not s:GetChecked() then db.char.showTutorial = false else db.char.showTutorial = true end
    end
  )
  
  -- Raider tab
  raiderTab = CreateFrame("Frame", "iwtbraidertab", windowframe)
  raiderTab:SetWidth(GUItabWindowSizeX)
  raiderTab:SetHeight(GUItabWindowSizeY)
  raiderTab:SetPoint("CENTER", 0, -20)
  texture = raiderTab:CreateTexture("iwtbraidertex")
  texture:SetAllPoints(raiderTab)
  texture:SetColorTexture(0,0,0,1)
  
  -- Raider status text panel
  local raiderStatusPanel = CreateFrame("Frame", "iwtbraiderstatuspanel", raiderTab)
  raiderStatusPanel:SetWidth(GUIRStatusSizeX)
  raiderStatusPanel:SetHeight(GUIRStatusSizeY)
  raiderStatusPanel:SetPoint("TOPRIGHT", -50, 20)
  texture = raiderStatusPanel:CreateTexture("iwtbrstatusptex")
  texture:SetAllPoints(raiderStatusPanel)
  texture:SetColorTexture(0.2,0,0,1)
  fontstring = raiderStatusPanel:CreateFontString("iwtbrstatusptext")
  fontstring:SetAllPoints(raiderStatusPanel)
  fontstring:SetFontObject("SpellFont_Small")
  fontstring:SetJustifyH("CENTER")
  fontstring:SetJustifyV("CENTER")
  raiderStatusPanel.text = fontstring
  
  local rStatusAnim = fontstring:CreateAnimationGroup()
  local rStatusAnim1 = rStatusAnim:CreateAnimation("Alpha")
  rStatusAnim1:SetFromAlpha(0)
  rStatusAnim1:SetToAlpha(1)
  rStatusAnim1:SetDuration(1.5)
  rStatusAnim1:SetSmoothing("OUT")
  raiderStatusPanel.anim = rStatusAnim
  
  raiderTab.raiderStatusPanel = raiderStatusPanel
  
  -- made local at start because dropdown menu function uses it
  raiderBossListFrame = CreateFrame("Frame", "iwtbraiderbosslist", raiderTab)
  raiderBossListFrame:SetWidth(GUItabWindowSizeX -20)
  raiderBossListFrame:SetHeight(GUItabWindowSizeY -20)
  raiderBossListFrame:SetPoint("CENTER", 0, 0)
  texture = raiderBossListFrame:CreateTexture("iwtbraiderbosslisttex")
  texture:SetAllPoints(raiderBossListFrame)
  texture:SetColorTexture(0.1,0.1,0.1,0.5)
  
  -- Raider send button
  local raiderSendButton = CreateFrame("Button", "iwtbraidersendbutton", raiderTab, "UIPanelButtonTemplate")
  raiderSendButton:SetWidth(GUItabButtonSizeX)
  raiderSendButton:SetHeight(GUItabButtonSizeY)
  raiderSendButton:SetText(L["Send"])
  raiderSendButton:SetFrameLevel(5)
  raiderSendButton:SetPoint("BOTTOMRIGHT", -20, 30)
  texture = raiderSendButton:CreateTexture("raidersendbuttex")
  texture:SetAllPoints(raiderSendButton)
  raiderSendButton:Enable()
  raiderSendButton:RegisterForClicks("LeftButtonUp")
  raiderSendButton:SetScript("OnClick", function(s)
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
  local raiderTestButton = CreateFrame("Button", "iwtbraidertestbutton", raiderTab, "UIPanelButtonTemplate")
  raiderTestButton:SetWidth(GUItabButtonSizeX)
  raiderTestButton:SetHeight(GUItabButtonSizeY)
  raiderTestButton:SetText("Test")
  raiderTestButton:SetFrameLevel(5)
  raiderTestButton:SetPoint("BOTTOMLEFT", 270, 30)
  texture = raiderTestButton:CreateTexture("raidertestbuttex")
  texture:SetAllPoints(raiderTestButton)
  raiderTestButton:Enable()
  raiderTestButton:RegisterForClicks("LeftButtonUp")
  raiderTestButton:SetScript("OnClick", function(s)
    --iwtb.setStatusText("raider", "Testing")
    bossKilled("BOSS_KILL", 2070, "Antoran High Command") -- "Felhounds of Sargeras", 1712, 1987 - engageId = 2074
    --print("autohideTime: ",db.char.autohideKillTime)
    --bossKillPopup:Show()
  end)
  raiderTestButton:Hide()
  
  -- Raider close button
  local raiderCloseButton = CreateFrame("Button", "iwtbraiderclosebutton", raiderTab, "UIPanelButtonTemplate")
  raiderCloseButton:SetWidth(GUItabButtonSizeX)
  raiderCloseButton:SetHeight(GUItabButtonSizeY)
  raiderCloseButton:SetText(L["Close"])
  raiderCloseButton:SetFrameLevel(5)
  raiderCloseButton:SetPoint("BOTTOMLEFT", 20, 30)
  texture = raiderCloseButton:CreateTexture("raiderclosebuttex")
  texture:SetAllPoints(raiderCloseButton)
  raiderCloseButton:Enable()
  raiderCloseButton:RegisterForClicks("LeftButtonUp")
  raiderCloseButton:SetScript("OnClick", function(s)
    windowframe:Hide()
    windowframe.title:Hide()
  end)
  
  -- Raider tutorial button
  local raiderTutorialButton = CreateFrame("Button", "iwtbraidertutorialbutton", raiderTab, "UIPanelButtonTemplate")
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
  
  local raiderResetDBButton = CreateFrame("Button", "iwtbraiderresetdbbutton", raiderTab, "UIPanelButtonTemplate")
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
  rlTab = CreateFrame("Frame", "iwtbraidleadertab", windowframe)
  rlTab:SetWidth(GUItabWindowSizeX)
  rlTab:SetHeight(GUItabWindowSizeY)
  rlTab:SetPoint("CENTER", 0, -20)
  texture = rlTab:CreateTexture("iwtbraidleadertex")
  texture:SetAllPoints(rlTab)
  texture:SetColorTexture(0,0,0,1)
  
  ---------------------------
  -- Raid leader status text panel
  ---------------------------
  local rlStatusPanel = CreateFrame("Frame", "iwtbrlstatuspanel", rlTab)
  rlStatusPanel:SetWidth(GUIRStatusSizeX)
  rlStatusPanel:SetHeight(GUIRStatusSizeY)
  rlStatusPanel:SetPoint("TOPRIGHT", -50, 20)
  
  rlStatusPanel:SetScript("OnEnter", function(s) for i=1, #rlTab.rlStatusPanel.content do local v = rlTab.rlStatusPanel.content[i] v:Show() end end)
  rlStatusPanel:SetScript("OnLeave", function(s) for i=1, #rlTab.rlStatusPanel.content do local v = rlTab.rlStatusPanel.content[i] v:Hide() end end)
    
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
  
  rlTab.rlStatusPanel = rlStatusPanel
  
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
  rlTab.rlStatusPanel.content = rlStatusPanelContent
  
  -- Raid Leader reset DB button
  StaticPopupDialogs["IWTB_ResetRaidLeaderDB"] = {
    text = L["Remove ALL raiders desire data?"],
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        raidLeaderDB:ResetDB()
        rlProfileDB:ResetDB()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
  }

  -- rlRaiderListFrame
  rlRaiderListFrame = CreateFrame("Frame", "iwtbrlraiderlistframe", rlTab)
  rlRaiderListFrame:SetWidth(GUItabWindowSizeX -20)
  rlRaiderListFrame:SetHeight(GUItabWindowSizeY -20)
  rlRaiderListFrame:SetPoint("CENTER", 0, 0)
  texture = rlRaiderListFrame:CreateTexture("iwtbrlraiderlistframetex")
  texture:SetAllPoints(rlRaiderListFrame)
  texture:SetColorTexture(0.1,0.1,0.1,0.5)
  
  -- Create frame for each raid spot
  for i=1, 8 do -- 8 groups of 5 slots
    local x = 20
    local y = (GUIgrpSizeY + 5) * i
    
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
      local slotx = (GUIgrpSlotSizeX * (n -1)) + (5 * n-1)
      grpMemSlotFrame[i][n] = CreateFrame("Button", "iwtbgrpslot" .. i .. "-" .. n, grpMemFrame[i])
      grpMemSlotFrame[i][n]:SetWidth(GUIgrpSlotSizeX)
      grpMemSlotFrame[i][n]:SetHeight(GUIgrpSlotSizeY)
      grpMemSlotFrame[i][n]:ClearAllPoints()
      grpMemSlotFrame[i][n]:SetAttribute("raidid", 0)
      grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
      
      local texture = grpMemSlotFrame[i][n]:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
      local fontstring = grpMemSlotFrame[i][n]:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
      texture:SetAllPoints(texture:GetParent())
      texture:SetColorTexture(0.2, 0.2 ,0.2 ,1)
      grpMemSlotFrame[i][n].texture = texture
      fontstring:SetPoint("CENTER", 0, 6)
      fontstring:SetWidth(GUIgrpSlotSizeX - 25)
      fontstring:SetJustifyH("CENTER")
      fontstring:SetJustifyV("CENTER")
      fontstring:SetFontObject("Game12Font")
      fontstring:SetText(L["Empty"])
      grpMemSlotFrame[i][n].nameText = fontstring
      
      grpMemSlotFrame[i][n]:RegisterForDrag("LeftButton");
      grpMemSlotFrame[i][n]:RegisterForClicks("RightButtonUp");
      grpMemSlotFrame[i][n]:SetMovable(true);
      grpMemSlotFrame[i][n]:EnableMouse(true);
      grpMemSlotFrame[i][n]:SetScript("OnDragStart", function(s, ...) s:StartMoving() s:SetFrameStrata("TOOLTIP") end);
      grpMemSlotFrame[i][n]:SetScript("OnDragStop", function(s, ...)
        s:StopMovingOrSizing()
        s:SetFrameStrata("FULLSCREEN")
        
        if not IsInRaid() then
          iwtb.setStatusText("raidleader", L["Need to be in a raid group"])
          raidUpdate()
          return
        end
        
        local sourceGroup = tonumber(string.sub(s:GetName(), -3, -3))
        local mousex, mousey = GetCursorPosition();
        local scale = UIParent:GetEffectiveScale();
        mousex = mousex / scale;
        mousey = mousey / scale;
        local targetgroup, targetmember = MemberFrameContainsPoint(mousex, mousey);
        if targetgroup then
          if targetmember then
            if grpHasEmpty(targetgroup) then
              -- Move to targetgroup
              SetRaidSubgroup(s:GetAttribute("raidid"), targetgroup)
            else
              -- Swap with targetmember
              SwapRaidSubgroup(s:GetAttribute("raidid"), grpMemSlotFrame[targetgroup][targetmember]:GetAttribute("raidid"))
            end
          end
          
          -- Redraw group frames
          if targetgroup ~= sourceGroup then
            raidUpdate()
          end
        end
        -- Redraw source group in case button is left outside our frames
        raidUpdate()
      end)

      -- Context menu
      grpMemSlotFrame[i][n].dropdown = CreateFrame("Frame", "iwtbslotcmenu" .. i .. "-" .. n , grpMemSlotFrame[i][n], "L_UIDropDownMenuTemplate")
      grpMemSlotFrame[i][n]:SetScript("OnClick", function(s) L_ToggleDropDownMenu(1, nil, s.dropdown, "cursor", -25, -10) end)
      L_UIDropDownMenu_Initialize(grpMemSlotFrame[i][n].dropdown, slotDropDown_Menu)

      -- role texture
      texture = grpMemSlotFrame[i][n]:CreateTexture()
      texture:SetPoint("LEFT", -4, 17)
      texture:SetHeight(16)
      texture:SetWidth(16)
      texture:SetTexture("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.tga")
      texture:SetDrawLayer("OVERLAY", 7)
      grpMemSlotFrame[i][n].roleTexture = texture
      grpMemSlotFrame[i][n].roleTexture:Hide()
      
      -- desire label
      grpMemSlotFrame[i][n].desireTag = CreateFrame("Frame", "iwtbgrpslotdesire" .. i .. "-" .. n, grpMemSlotFrame[i][n])
      grpMemSlotFrame[i][n].desireTag:SetWidth(GUIgrpSlotSizeX - 4)
      grpMemSlotFrame[i][n].desireTag:SetHeight((GUIgrpSlotSizeY /2) - 6)
      grpMemSlotFrame[i][n].desireTag:ClearAllPoints()
      grpMemSlotFrame[i][n].desireTag:SetPoint("BOTTOM", 0, 0)
      
      local texture = grpMemSlotFrame[i][n].desireTag:CreateTexture("iwtbgrpslottex" .. i .. "-" .. n)
      grpMemSlotFrame[i][n].desireTag.text = grpMemSlotFrame[i][n].desireTag:CreateFontString("iwtbgrpslotfont" .. i .. "-" .. n)
      texture:SetAllPoints(texture:GetParent())
      texture:SetColorTexture(0,0,0.2,1)
      grpMemSlotFrame[i][n].desireTag.text:SetPoint("CENTER")
      grpMemSlotFrame[i][n].desireTag.text:SetJustifyH("CENTER")
      grpMemSlotFrame[i][n].desireTag.text:SetJustifyV("BOTTOM")
      --grpMemSlotFrame[i][n].desireTag.text:SetFont(GUIfont, 10, "")
      grpMemSlotFrame[i][n].desireTag.text:SetFontObject("SpellFont_Small")
      grpMemSlotFrame[i][n].desireTag.text:SetText(L["Unknown desire"])
      
      -- note
      grpMemSlotFrame[i][n].note = CreateFrame("Frame", "iwtbgrpslotnote" .. n, grpMemSlotFrame[i][n].desireTag)
      grpMemSlotFrame[i][n].note:SetWidth(16)
      grpMemSlotFrame[i][n].note:SetHeight(16)
      grpMemSlotFrame[i][n].note:ClearAllPoints()
      grpMemSlotFrame[i][n].note:SetPoint("BOTTOMRIGHT", 3, 0)
      
      texture = grpMemSlotFrame[i][n].note:CreateTexture("iwtbgrpnotetex")
      texture:SetWidth(16)
      texture:SetHeight(16)
      texture:SetPoint("TOPLEFT", 0, 0)
      texture:SetDrawLayer("ARTWORK",7)
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
      grpMemSlotFrame[i][n].note.texture = texture
      
      grpMemSlotFrame[i][n].note:SetAttribute("hasNote", false)
      grpMemSlotFrame[i][n].note:SetAttribute("noteTxt", "")
      grpMemSlotFrame[i][n].note:SetScript("OnEnter", function(s)
                                  GameTooltip:SetOwner(s)
                                  if grpMemSlotFrame[i][n].note:GetAttribute("hasNote") then
                                    GameTooltip:AddLine(grpMemSlotFrame[i][n].note:GetAttribute("noteTxt"))
                                    GameTooltip:Show()
                                  end
                                end)
      grpMemSlotFrame[i][n].note:SetScript("OnLeave", function(s) GameTooltip:Hide() end)
    end
  end
  
  local rlResetDBButton = CreateFrame("Button", "iwtbrlresetdbbutton", rlRaiderListFrame, "UIPanelButtonTemplate")
  rlResetDBButton:SetWidth(GUItabButtonSizeX)
  rlResetDBButton:SetHeight(GUItabButtonSizeY)
  rlResetDBButton:SetText(L["Reset DB"])
  rlResetDBButton:SetPoint("BOTTOMRIGHT", -(GUIgrpSlotSizeX + GUItabButtonSizeX + 60), 20)
  texture = rlResetDBButton:CreateTexture("rlresetdbbuttex")
  texture:SetAllPoints(rlResetDBButton)
  rlResetDBButton:Enable()
  rlResetDBButton:RegisterForClicks("LeftButtonUp")
  rlResetDBButton:SetScript("OnClick", function(s)
    StaticPopup_Show("IWTB_ResetRaidLeaderDB")
  end)
  
  -- Raid Leader test button
  local rlTestButton = CreateFrame("Button", "iwtbrltestbutton", rlRaiderListFrame, "UIPanelButtonTemplate")
  rlTestButton:SetWidth(GUItabButtonSizeX)
  rlTestButton:SetHeight(GUItabButtonSizeY)
  rlTestButton:SetText("Refresh")
  rlTestButton:SetPoint("BOTTOMRIGHT", -(GUIgrpSlotSizeX + 50), 20)
  texture = rlTestButton:CreateTexture("rltestbuttex")
  texture:SetAllPoints(rlTestButton)
  rlTestButton:Enable()
  rlTestButton:RegisterForClicks("LeftButtonUp")
  rlTestButton:SetScript("OnClick", function(s)
    raidUpdate()
  end)
  
  -- Raid leader close button
  local rlCloseButton = CreateFrame("Button", "iwtbrlcloseButton", rlRaiderListFrame, "UIPanelButtonTemplate")
  rlCloseButton:SetWidth(GUItabButtonSizeX)
  rlCloseButton:SetHeight(GUItabButtonSizeY)
  rlCloseButton:SetText(L["Close"])
  rlCloseButton:SetPoint("BOTTOMLEFT", 20, 20)
  texture = rlCloseButton:CreateTexture("rlclosebuttex")
  texture:SetAllPoints(rlCloseButton)
  rlCloseButton:Enable()
  rlCloseButton:RegisterForClicks("LeftButtonUp")
  rlCloseButton:SetScript("OnClick", function(s)
    windowframe:Hide()
    windowframe.title:Hide()
  end)
  
  -- Out of raid scroll list for desire
  rlRaiderNotListFrame = CreateFrame("ScrollFrame", "iwtbrloorframe", rlRaiderListFrame) 
  rlRaiderNotListFrame:SetSize((GUIgrpSlotSizeX +10), (rlRaiderListFrame:GetHeight() -160))
  rlRaiderNotListFrame:SetPoint("TOP", rlRaiderListFrame, 0, -55)
  rlRaiderNotListFrame:SetPoint("BOTTOMRIGHT", rlRaiderListFrame, -30, 20)
  rlRaiderNotListFrame:SetScript("OnMouseWheel", function(s,v)
    local curV = rlRaiderNotListFrame.rlOoRscrollbar:GetValue()
    rlRaiderNotListFrame.rlOoRscrollbar:SetValue(curV + -(v * 15))
  end)
  
  local texture = rlRaiderNotListFrame:CreateTexture("iwtboorlisttex") 
  texture:SetAllPoints(texture:GetParent())
  texture:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  
  fontstring = rlRaiderNotListFrame:CreateFontString("iwtboorlisttext")
  fontstring:SetPoint("CENTER",0,0)
  fontstring:SetFontObject("Game12Font")
  fontstring:SetWidth(GUIgrpSlotSizeX -15)
  fontstring:SetJustifyV("CENTER")
  fontstring:SetTextColor(1, 1, 1, 0.8)
  fontstring:SetText(L["Out of raid players"])
  rlRaiderNotListFrame.text = fontstring

  --scrollbar 
  local rlOoRscrollbar = CreateFrame("Slider", "iwtbrloorscrollbar", rlRaiderNotListFrame, "UIPanelScrollBarTemplate")
  rlOoRscrollbar:SetPoint("TOPLEFT", rlRaiderNotListFrame, "TOPRIGHT", 4, -16)
  rlOoRscrollbar:SetPoint("BOTTOMLEFT", rlRaiderNotListFrame, "BOTTOMRIGHT", 4, 16)
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
  scrollbg:SetAllPoints(scrollbar)
  scrollbg:SetTexture(0, 0, 0, 0.4)
  rlRaiderNotListFrame.rlOoRscrollbar = rlOoRscrollbar

  -- Content frame
  local rlOoRcontent = CreateFrame("Frame", "iwtbrloorlist", rlRaiderNotListFrame)
  rlOoRcontent:SetWidth((rlOoRcontent:GetParent():GetWidth()) -2)
  rlOoRcontent:SetHeight(rlRaiderNotListFrame:GetHeight())
  rlOoRcontent:SetScript("OnMouseWheel", function(s,v)
    local curV = rlRaiderNotListFrame.rlOoRscrollbar:GetValue()
    rlRaiderNotListFrame.rlOoRscrollbar:SetValue(curV + -(v * 15))
  end)
  rlOoRcontent:ClearAllPoints()
  rlOoRcontent:SetPoint("TOPLEFT", 0, 0)
  local texture = rlOoRcontent:CreateTexture()
  texture:SetAllPoints(texture:GetParent())
  texture:SetTexture(0, 0, 0.5, 1)

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
  bossesRLButton:SetFrameLevel(7)
  bossesRLButton:SetPoint("TOPLEFT", 500, -20)
  L_UIDropDownMenu_SetWidth(bossesRLButton, 200)
  L_UIDropDownMenu_Initialize(bossesRLButton, raidsDropdownMenu)
  L_UIDropDownMenu_SetText(bossesRLButton, L["Select boss"])
  
  --------------------------------------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------------------------
  
  -- Dropdown buttons (for raider tab)
  expacButton = CreateFrame("Frame", "expacbutton", raiderTab, "L_UIDropDownMenuTemplate")
  expacButton:SetPoint("TOPLEFT", 0, -20)
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
  
  local optionsButton = CreateFrame("Button", "$parentTab3", windowframe, "TabButtonTemplate")
  optionsButton:SetWidth(GUItabButtonSizeX)
  optionsButton:SetHeight(GUItabButtonSizeY)
  optionsButton:SetText(L["Options"])
  optionsButton:SetPoint("CENTER", optionsButton:GetParent(), "TOPLEFT", 290, -40)
  texture = optionsButton:CreateTexture("raiderbuttex")
  texture:SetAllPoints(optionsButton)
  texture:SetColorTexture(0, 0, 0, 1)
  optionsButton:Enable()
  optionsButton:RegisterForClicks("LeftButtonUp")
  optionsButton:SetScript("OnClick", function(s)
    windowframe:Hide()
    windowframe.title:Hide()
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
    print(bossKillInfo.bossid)
    print(bossKillPopupSelectedDesireId)
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
  bossKillPopupButton = CreateFrame("CheckButton", "iwtbkillcheckbutton", bossKillPopupWindow, "ChatConfigCheckButtonTemplate")
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
  PanelTemplates_SetNumTabs(windowframe, 3)  -- 2 because there are 2 frames total.
  PanelTemplates_SetTab(windowframe, 1)     -- 1 because we want tab 1 selected.
  raiderTab:Show()  -- Show page 1.
  rlTab:Hide()  -- Hide all other pages (in this case only one).
  
  -- Hide on esc
  --tinsert(UISpecialFrames,"iwtbwindow")
  --tinsert(UISpecialFrames,"iwtbtitle")
  
  -- Hide or show main window on start via options
  if not db.char.showOnStart then
    windowframe:Hide()
    windowframe.title:Hide()
  end
  
  -- Set the dropdowns programmatically. Allow this via options?
  raidsDropdownMenuOnClick(expacButton.Button,7,"expacbutton")
  raidsDropdownMenuOnClick(expacRLButton.Button,7,"expacrlbutton")
  raidsDropdownMenuOnClick(instanceButton.Button,946,"instancebutton")
  raidsDropdownMenuOnClick(instanceRLButton.Button,946,"instancerlbutton")
  
  -- Register listening events
  iwtb:RegisterEvent("GROUP_ROSTER_UPDATE", raidUpdate)
  iwtb:RegisterEvent("RAID_INSTANCE_WELCOME", enterInstance)
  iwtb:RegisterEvent("GROUP_LEFT", leftGroup)
  iwtb:RegisterEvent("GROUP_JOINED", eventfired)
  iwtb:RegisterEvent("PLAYER_ENTERING_WORLD", playerEnteringWorld)

end

function iwtb:OnDisable()
    -- Called when the addon is disabled
end
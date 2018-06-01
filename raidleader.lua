local L = iwtb.L
local rlOoRcontentSlots = {} -- Out of Raid slots
local rlRaiderOverviewFrameSlots = {} -- raid leader overview slots
local rlRaiderOverviewFrameColumns = {} -- overview columns
local overviewCreatureFrame = {} -- Boss icon for overview columns
local roleTexCoords = {DAMAGER = {left = 0.3125, right = 0.609375, top = 0.328125, bottom = 0.625}, HEALER = {left = 0.3125, right = 0.609375, top = 0.015625, bottom = 0.3125}, TANK = {left = 0, right = 0.296875, top = 0.328125, bottom = 0.625}, NONE = {left = 0.296875, right = 0.3, top = 0.625, bottom = 0.650}};
local rlStatusContent = {} -- RL status lines 1-10

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
function iwtb.MemberFrameContainsPoint(x, y)
	if FrameContainsPoint(iwtb.rlRaiderListFrame, x, y) then
		for i=1,8 do
			if FrameContainsPoint(iwtb.grpMemFrame[i], x, y) then
				for member=1,5 do
					if FrameContainsPoint(iwtb.grpMemSlotFrame[i][member], x, y) then
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

function iwtb.grpHasEmpty(grp)
  local result = false
  for i=1, 5 do
    if slotIsEmpty(iwtb.grpMemSlotFrame[grp][i]) then
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

local function removeRaiderData(f, name)
  --raidLeaderDB.char.raiders[name] = nil
  wipe(iwtb.rlProfileDB.profile.raiders[name])
  iwtb.setStatusText("raidleader", L["Removed data - "] .. name)
  iwtb.raidUpdate()
end

-- Right click menu for raid/OoR slots
function iwtb.slotDropDown_Menu(frame, level, menuList)
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
      
      info = L_UIDropDownMenu_CreateInfo()
      info.func = function(s, arg1, arg2, checked) iwtb.sendData("rdata", "", name) end
      info.text = L["Request data"]
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
  
local function hasNote(name, tier, boss) -- compare the player name to the rl db to see if they have a note for the selected boss
  -- First check if the player is in rl db
  for tname, rldb in pairs(iwtb.rlProfileDB.profile.raiders) do
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

function iwtb.overviewCreatureIconsHideAll()
  -- Hide all
  if overviewCreatureFrame then
    for i=1, #overviewCreatureFrame do
      overviewCreatureFrame[i]:Hide()
    end
  end
end

function iwtb.overviewCreatureIconsHide(curPage)
  local showMax = #overviewCreatureFrame
  
  if #overviewCreatureFrame > 7 and curPage == 1 then
    showMax = 7
  elseif #overviewCreatureFrame > 14 and curPage == 2 then
    showMax = 14
  end
  
  if curPage == 1 then
    for i=1, showMax do
      if rlRaiderOverviewFrameColumns[i]:IsShown() then
        overviewCreatureFrame[i]:Show()
      end
    end
  elseif curPage == 2 then
    --print("in curPage2")
    for i=8, showMax do
      if rlRaiderOverviewFrameColumns[i]:IsShown() then
        overviewCreatureFrame[i]:Show()
      end
    end
  elseif curPage == 3 then
    for i=15, showMax do
      if rlRaiderOverviewFrameColumns[i]:IsShown() then
        overviewCreatureFrame[i]:Show()
      end
    end
  end
end

function iwtb.overviewCreatureIcons(i, bossid, columnX)
  if overviewCreatureFrame[i] == nil then
    -- Create a frame to go over the top of the scroll raider list
    overviewCreatureFrame[i] = CreateFrame("Frame", "iwtboverviewcreature" .. i, iwtb.rlRaiderOverviewFrame)
    overviewCreatureFrame[i]:SetSize(iwtb.GUIgrpSlotSizeX, 75)
    overviewCreatureFrame[i]:SetPoint("TOPLEFT", columnX, -48)
    overviewCreatureFrame[i]:SetFrameLevel(11)
    
    overviewCreatureFrame[i].bg = CreateFrame("Frame", "iwtboverviewcreature" .. i, overviewCreatureFrame[i])
    overviewCreatureFrame[i].bg:SetSize(iwtb.GUIgrpSlotSizeX, 80)
    overviewCreatureFrame[i].bg:SetPoint("TOPLEFT", columnX, -48)
    overviewCreatureFrame[i].bg:SetFrameLevel(10)
    
    local texture = overviewCreatureFrame[i].bg:CreateTexture("iwtboverviewcreaturebgtex" .. i)
    texture:SetSize(iwtb.GUIgrpSlotSizeX, 75)
    texture:SetAllPoints(overviewCreatureFrame[i])
    texture:SetColorTexture(0.1,0.1,0.6,1)
    
    local _, bossName, _, _, bossImage = EJ_GetCreatureInfo(1, bossid)
    bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
    
    local creatureTex = overviewCreatureFrame[i]:CreateTexture("iwtboverviewcreaturetex" .. i)
    creatureTex:SetSize(iwtb.GUIgrpSlotSizeX, 64)
    creatureTex:SetPoint("TOPLEFT", 0, 0)
    creatureTex:SetTexture(bossImage)
    overviewCreatureFrame[i].texture = creatureTex
    
    -- Create a font frame to allow word-wrap
    overviewCreatureFrame[i].fontFrame = CreateFrame("Frame", "iwtbcreaturefontframe", overviewCreatureFrame[i])
    overviewCreatureFrame[i].fontFrame:ClearAllPoints()
    overviewCreatureFrame[i].fontFrame:SetHeight(30)
    overviewCreatureFrame[i].fontFrame:SetWidth(iwtb.GUIgrpSlotSizeX)
    overviewCreatureFrame[i].fontFrame:SetPoint("CENTER", 0, -25)
    
    texture = overviewCreatureFrame[i].fontFrame:CreateTexture("iwtboverviewcreaturetexttex" .. i)
    texture:SetSize(100, 20)
    texture:SetAllPoints(overviewCreatureFrame[i].fontFrame)
    texture:SetColorTexture(0, 0, 0, 0.4)
    
    local fontstring = overviewCreatureFrame[i].fontFrame:CreateFontString("iwtboverviewbosstext" .. i)
    fontstring:SetAllPoints(overviewCreatureFrame[i].fontFrame)
    fontstring:SetFontObject("Game12Font")
    fontstring:SetJustifyH("MIDDLE")
    fontstring:SetJustifyV("MIDDLE")
    fontstring:SetText(iwtb.instanceBosses.bosses[iwtb.instanceBosses.order[i]])
    overviewCreatureFrame[i].fontFrame.text = fontstring
    
    -- Hide if not on first frame
    if i > 7 then
      overviewCreatureFrame[i]:Hide()
    end
  else
    -- Reuse frames
    local _, bossName, _, _, bossImage = EJ_GetCreatureInfo(1, bossid)
    bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
    overviewCreatureFrame[i].texture:SetTexture(bossImage)
    overviewCreatureFrame[i].fontFrame.text:SetText(iwtb.instanceBosses.bosses[iwtb.instanceBosses.order[i]])
    
    overviewCreatureFrame[i]:Show()
    overviewCreatureFrame[i].bg:Show()
  end
end

function iwtb.drawOverviewColumnsHideAll()
  -- Hide all
  if #rlRaiderOverviewFrameColumns then
    for i=1, #rlRaiderOverviewFrameColumns do
      rlRaiderOverviewFrameColumns[i]:Hide()
    end
  end
end

-- Draw Overview rows (1 row per boss)
function iwtb.drawOverviewColumns(instid)
  local curPage = 1
  for i=1, #iwtb.instanceBosses.order do
    if i > 7 and i < 15 then
      curPage = 2
    elseif i > 14 then
      curPage = 3
    end
    local bossid = iwtb.instanceBosses.order[i]
    if rlRaiderOverviewFrameColumns[i] then -- we have this column redraw or leave as is.
      if rlRaiderOverviewFrameColumns[i]:GetAttribute("bossid") ~= bossid then
        rlRaiderOverviewFrameColumns[i]:SetAttribute("bossid", bossid)
      end
      iwtb.overviewCreatureIcons(i,bossid,columnX)
      rlRaiderOverviewFrameColumns[i]:Show()
    else -- don't have column, create it.
      -- horrible way for now
      local columnX = (iwtb.GUIgrpSlotSizeX * (i -1)) + (2 * i-1)
      if curPage == 2 then
        columnX = (iwtb.GUIgrpSlotSizeX * (i -8)) + (2 * i-8)
      elseif curPage == 3 then
        columnX = (iwtb.GUIgrpSlotSizeX * (i -15)) + (2 * i-15)
      end
      
      rlRaiderOverviewFrameColumns[i] = CreateFrame("Frame", "iwtbrloverviewcolumn" .. i, iwtb.rlRaiderOverviewListFrame[curPage].rlOverviewContent)
      rlRaiderOverviewFrameColumns[i]:SetAttribute("bossid", bossid)
      rlRaiderOverviewFrameColumns[i]:SetSize(iwtb.GUIgrpSlotSizeX, (iwtb.rlRaiderOverviewFrame:GetHeight() -130))
      rlRaiderOverviewFrameColumns[i]:SetPoint("TOPLEFT", columnX, 0)
      rlRaiderOverviewFrameColumns[i].texture = rlRaiderOverviewFrameColumns[i]:CreateTexture("iwtboverviewcoltex" .. i)
      rlRaiderOverviewFrameColumns[i].texture:SetAllPoints(rlRaiderOverviewFrameColumns[i])
      rlRaiderOverviewFrameColumns[i].texture:SetColorTexture(0.1, 0.1 ,0.1 ,1)

      iwtb.overviewCreatureIcons(i,bossid,columnX)
    end
  end
end

function iwtb.drawOverviewSlotsAll()
  local curSlots = 0
  
  -- Hide any current slots
  if rlRaiderOverviewFrameColumns and #rlRaiderOverviewFrameColumns > 0 then
    for n=1, #rlRaiderOverviewFrameColumns do
      curSlots = rlRaiderOverviewFrameColumns[n]:GetNumChildren()
      if curSlots > 0 then
        for i=1, curSlots do
          if rlRaiderOverviewFrameSlots[n][i] then
            rlRaiderOverviewFrameSlots[n][i]:Hide()
          end
        end
      end
    end
  end
  
  for i=1, #iwtb.instanceBosses.order do
    iwtb.drawOverviewSlots(iwtb.rlSelectedTier.instid, iwtb.instanceBosses.order[i], i)
    i=i+1
  end
end

-- Draw Overview slots
function iwtb.drawOverviewSlots(instid, bossid, c)
  -- Find number of current slots
  local curSlots = 0
  
  local function createOverviewSlot(n, name, desireid, notetxt)
    if not rlRaiderOverviewFrameSlots[c] then rlRaiderOverviewFrameSlots[c] = {} end
    rlRaiderOverviewFrameSlots[c][n] = CreateFrame("Button", "iwtbrloverviewslot" .. n, rlRaiderOverviewFrameColumns[c])
    rlRaiderOverviewFrameSlots[c][n]:SetSize(iwtb.GUIgrpSlotSizeX, iwtb.GUIgrpSlotSizeY)
    rlRaiderOverviewFrameSlots[c][n]:SetPoint("TOPLEFT", 0, -(iwtb.GUIgrpSlotSizeY * (n)))
    
    rlRaiderOverviewFrameSlots[c][n]:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
      tile = true, tileSize = 16, edgeSize = 16, 
      insets = { left = 0, right = 0, top = 4, bottom = 4 }
    })
   
    rlRaiderOverviewFrameSlots[c][n]:SetBackdropColor(0.5,0,0,1)
    rlRaiderOverviewFrameSlots[c][n]:SetBackdropBorderColor(0.5,0.5,0,1)
    
    local fontstring = rlRaiderOverviewFrameSlots[c][n]:CreateFontString()
    fontstring:SetPoint("TOP", 0, -5)
    fontstring:SetFontObject("Game12Font")
    fontstring:SetJustifyH("CENTER")
    fontstring:SetJustifyV("CENTER")
    fontstring:SetText(name)
    
    rlRaiderOverviewFrameSlots[c][n].nameText = fontstring
    
    -- desire label
    rlRaiderOverviewFrameSlots[c][n].desireTag = CreateFrame("Frame", "iwtboverviewslotdesire" .. n, rlRaiderOverviewFrameSlots[c][n])
    rlRaiderOverviewFrameSlots[c][n].desireTag:SetWidth(iwtb.GUIgrpSlotSizeX - 8)
    rlRaiderOverviewFrameSlots[c][n].desireTag:SetHeight((iwtb.GUIgrpSlotSizeY /2) -4)
    rlRaiderOverviewFrameSlots[c][n].desireTag:ClearAllPoints()
    rlRaiderOverviewFrameSlots[c][n].desireTag:SetPoint("BOTTOM", 0, 4)
    
    local texture = rlRaiderOverviewFrameSlots[c][n].desireTag:CreateTexture("iwtboverviewslottex")
    texture:SetAllPoints(texture:GetParent())
    texture:SetColorTexture(0,0,0.2,1)
    rlRaiderOverviewFrameSlots[c][n].desireTag.text = rlRaiderOverviewFrameSlots[c][n].desireTag:CreateFontString("iwtboverviewslotfont" .. n)
    rlRaiderOverviewFrameSlots[c][n].desireTag.text:SetPoint("CENTER")
    rlRaiderOverviewFrameSlots[c][n].desireTag.text:SetJustifyH("CENTER")
    rlRaiderOverviewFrameSlots[c][n].desireTag.text:SetJustifyV("BOTTOM")
    rlRaiderOverviewFrameSlots[c][n].desireTag.text:SetFontObject("SpellFont_Small")
    rlRaiderOverviewFrameSlots[c][n].desireTag.text:SetText(iwtb.desire[desireid] or L["Unknown desire"])
    
    -- note
    rlRaiderOverviewFrameSlots[c][n].note = CreateFrame("Frame", "iwtboverviewslotnote" .. n, rlRaiderOverviewFrameSlots[c][n].desireTag)
    rlRaiderOverviewFrameSlots[c][n].note:SetWidth(16)
    rlRaiderOverviewFrameSlots[c][n].note:SetHeight(16)
    rlRaiderOverviewFrameSlots[c][n].note:ClearAllPoints()
    rlRaiderOverviewFrameSlots[c][n].note:SetPoint("BOTTOMRIGHT", 0, 1)
    
    texture = rlRaiderOverviewFrameSlots[c][n].note:CreateTexture("iwtboverviewnotetex")
    texture:SetWidth(16)
    texture:SetHeight(16)
    texture:SetPoint("TOPLEFT", 0, 0)
    texture:SetDrawLayer("ARTWORK",7)
    if notetxt and notetxt ~= "" then
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
      rlRaiderOverviewFrameSlots[c][n].note:SetAttribute("hasNote", true)
      rlRaiderOverviewFrameSlots[c][n].note:SetAttribute("noteTxt", notetxt)
    else
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
    end
    rlRaiderOverviewFrameSlots[c][n].note.texture = texture
    
    rlRaiderOverviewFrameSlots[c][n].note:SetScript("OnEnter", function(s)
                                GameTooltip:SetOwner(s, "ANCHOR_CURSOR")
                                if rlRaiderOverviewFrameSlots[c][n].note:GetAttribute("hasNote") then
                                  GameTooltip:AddLine(rlRaiderOverviewFrameSlots[c][n].note:GetAttribute("noteTxt"))
                                  GameTooltip:Show()
                                end
                              end)
    rlRaiderOverviewFrameSlots[c][n].note:SetScript("OnLeave", function(s) GameTooltip:Hide() end)
    
    -- Context menu
    rlRaiderOverviewFrameSlots[c][n]:RegisterForClicks("RightButtonUp")
    rlRaiderOverviewFrameSlots[c][n]:SetScript("OnClick", function(s) L_ToggleDropDownMenu(1, nil, s.dropdown, "cursor", -25, -10) end)
    rlRaiderOverviewFrameSlots[c][n].dropdown = CreateFrame("Frame", "iwtbcmenu" .. n , rlRaiderOverviewFrameSlots[c][n], "L_UIDropDownMenuTemplate")
    L_UIDropDownMenu_Initialize(rlRaiderOverviewFrameSlots[c][n].dropdown, iwtb.slotDropDown_Menu)
  end
  
  if next(iwtb.rlProfileDB.profile.raiders) ~= nil then -- check in case we have an empty table
    local i = 1
    for name,nametbl in pairs(iwtb.rlProfileDB.profile.raiders) do -- [name] = desireid
      if nametbl.raids then
        for raidid, raidtbl in pairs(nametbl.raids) do
          if instid == raidid then
            for bossident, bosstbl in pairs(raidtbl) do
              if tonumber(bossident) == bossid then
                if i > curSlots then
                  -- Add another slot
                  if not bosstbl.desireid and bosstbl.note and bosstbl.note == "" then
                    -- Don't show slot
                  else
                    createOverviewSlot(i, name, bosstbl.desireid, bosstbl.note)
                  end
                else
                  -- Reuse slot
                  rlRaiderOverviewFrameSlots[c][i].nameText:SetText(name)
                  rlRaiderOverviewFrameSlots[c][i].desireTag.text:SetText(iwtb.desire[bosstbl.desireid] or L["Unknown desire"])
                  
                  if bosstbl.note and bosstbl.note ~= "" then
                    rlRaiderOverviewFrameSlots[c][i].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
                    rlRaiderOverviewFrameSlots[c][i].note:SetAttribute("hasNote", true)
                    rlRaiderOverviewFrameSlots[c][i].note:SetAttribute("noteTxt", bosstbl.note)
                  else
                    rlRaiderOverviewFrameSlots[c][i].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
                    rlRaiderOverviewFrameSlots[c][i].note:SetAttribute("hasNote", false)
                    rlRaiderOverviewFrameSlots[c][i].note:SetAttribute("noteTxt", "")
                  end
                  rlRaiderOverviewFrameSlots[c][i]:Show()
                end
              end
            end
          end
        end
      else
        i = i -1 -- To avoid empty slots
      end
      
      i = i +1
      if i > 5 then iwtb.rlRaiderOverviewListFrame[1].text:Hide() else iwtb.rlRaiderOverviewListFrame[1].text:Show() end
    end
  iwtb.rlRaiderOverviewListFrame[1].rlOverviewVScrollbar1:SetMinMaxValues(1, (i)*((iwtb.GUIgrpSlotSizeY)/1.5))
  iwtb.rlRaiderOverviewListFrame[2].rlOverviewVScrollbar2:SetMinMaxValues(1, (i)*((iwtb.GUIgrpSlotSizeY)/1.5))
  iwtb.rlRaiderOverviewListFrame[3].rlOverviewVScrollbar3:SetMinMaxValues(1, (i)*((iwtb.GUIgrpSlotSizeY)/1.5))
  end
end

-- Add/draw Out of Raid slot for raider entry.
local function drawOoR(ooRraiders)
  -- Find number of current slots
  local curSlots = iwtb.rlRaiderNotListFrame.rlOoRcontent:GetNumChildren()
  --local sloty = 0 -- This is the top padding
  
  -- Hide any current OoR slots
  for i=1,curSlots do
    rlOoRcontentSlots[i]:Hide()
  end
  
  local function createOoRSlot(n, name, desireid, notetxt)
    rlOoRcontentSlots[n] = CreateFrame("Button", "iwtbrloorslot" .. n, iwtb.rlRaiderNotListFrame.rlOoRcontent) 
    rlOoRcontentSlots[n]:SetSize(iwtb.GUIgrpSlotSizeX, iwtb.GUIgrpSlotSizeY)
    rlOoRcontentSlots[n]:SetPoint("TOPLEFT", 4, -(iwtb.GUIgrpSlotSizeY * (n-1)))
    
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
    rlOoRcontentSlots[n].desireTag:SetWidth(iwtb.GUIgrpSlotSizeX - 8)
    rlOoRcontentSlots[n].desireTag:SetHeight((iwtb.GUIgrpSlotSizeY /2) -4)
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
    rlOoRcontentSlots[n].desireTag.text:SetText(iwtb.desire[desireid] or L["Unknown desire"])
    
    -- note
    rlOoRcontentSlots[n].note = CreateFrame("Frame", "iwtboorslotnote" .. n, rlOoRcontentSlots[n].desireTag)
    rlOoRcontentSlots[n].note:SetWidth(16)
    rlOoRcontentSlots[n].note:SetHeight(16)
    rlOoRcontentSlots[n].note:ClearAllPoints()
    rlOoRcontentSlots[n].note:SetPoint("BOTTOMRIGHT", 0, 1)
    
    texture = rlOoRcontentSlots[n].note:CreateTexture("iwtboornotetex")
    texture:SetWidth(16)
    texture:SetHeight(16)
    texture:SetPoint("TOPLEFT", 0, 0)
    texture:SetDrawLayer("ARTWORK",7)
    if notetxt then
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
      rlOoRcontentSlots[n].note:SetAttribute("hasNote", true)
      rlOoRcontentSlots[n].note:SetAttribute("noteTxt", notetxt)
    else
      texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
    end
    rlOoRcontentSlots[n].note.texture = texture
    
    rlOoRcontentSlots[n].note:SetScript("OnEnter", function(s)
                                GameTooltip:SetOwner(s, "ANCHOR_CURSOR")
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
    L_UIDropDownMenu_Initialize(rlOoRcontentSlots[n].dropdown, iwtb.slotDropDown_Menu)
  end
  
  if next(ooRraiders) ~= nil then
    local i = 1
    for name,nametbl in pairs(ooRraiders) do -- [name] = desireid
      if i > curSlots then
        -- Add another slot
        createOoRSlot(i, name, nametbl.desireid, nametbl.notetxt)
      else
        -- Reuse slot
        rlOoRcontentSlots[i].nameText:SetText(name)
        rlOoRcontentSlots[i].desireTag.text:SetText(iwtb.desire[nametbl.desireid] or L["Unknown desire"])
        
        if nametbl.notetxt then
          rlOoRcontentSlots[i].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
          rlOoRcontentSlots[i].note:SetAttribute("hasNote", true)
          rlOoRcontentSlots[i].note:SetAttribute("noteTxt", nametbl.notetxt)
        else
          rlOoRcontentSlots[i].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
          rlOoRcontentSlots[i].note:SetAttribute("hasNote", false)
          rlOoRcontentSlots[i].note:SetAttribute("noteTxt", "")
        end
        rlOoRcontentSlots[i]:Show()
      end
      i = i +1
      if i > 5 then iwtb.rlRaiderNotListFrame.text:Hide() else iwtb.rlRaiderNotListFrame.text:Show() end
    end
  --iwtb.rlRaiderNotListFrame.rlOoRcontent:SetHeight(iwtb.GUIgrpSlotSizeY * i + 5)
  iwtb.rlRaiderNotListFrame.rlOoRscrollbar:SetMinMaxValues(1, (i-1)*((iwtb.GUIgrpSlotSizeY)/2))
  --iwtb.rlRaiderNotListFrame.rlOoRscrollbar:SetValueStep(i)
  end
end

local function redrawGroup(grp)
  if type(grp) == "number" then
    for n=1, 5 do
      local slotx = (iwtb.GUIgrpSlotSizeX * (n -1)) + (5 * n-1)
      iwtb.grpMemSlotFrame[grp][n]:ClearAllPoints()
      iwtb.grpMemSlotFrame[grp][n]:SetParent(iwtb.grpMemFrame[grp])
      iwtb.grpMemSlotFrame[grp][n]:SetPoint("TOPLEFT", slotx, -3)
      iwtb.grpMemSlotFrame[grp][n].texture:SetColorTexture(0.2, 0.2 ,0.2 ,1)
      iwtb.grpMemSlotFrame[grp][n].nameText:SetText(L["Empty"])
      iwtb.grpMemSlotFrame[grp][n]:SetAttribute("raidid", 0)
      iwtb.grpMemSlotFrame[grp][n].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      iwtb.grpMemSlotFrame[grp][n].roleTexture:Hide()
    end
  else
    for i=1, 8 do
      for n=1, 5 do
      local slotx = (iwtb.GUIgrpSlotSizeX * (n -1)) + (5 * n-1)
      iwtb.grpMemSlotFrame[i][n]:ClearAllPoints()
      iwtb.grpMemSlotFrame[i][n]:SetParent(iwtb.grpMemFrame[i])
      iwtb.grpMemSlotFrame[i][n]:SetPoint("TOPLEFT", slotx, -3)
      iwtb.grpMemSlotFrame[i][n].texture:SetColorTexture(0.2, 0.2 ,0.2 ,1)
      iwtb.grpMemSlotFrame[i][n].nameText:SetText(L["Empty"])
      iwtb.grpMemSlotFrame[i][n]:SetAttribute("raidid", 0)
      iwtb.grpMemSlotFrame[i][n].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      iwtb.grpMemSlotFrame[i][n].roleTexture:Hide()
    end
    end
  end
end

local function hasDesire(name, expac, tier, boss) -- compare the player name to the rl db to see if they have a desire for the selected boss - expac depreciated
  -- First check if the player is in rl db
  for tname, rldb in pairs(iwtb.rlProfileDB.profile.raiders) do
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

function iwtb.raidUpdate(self)
  -- Only update if frame is visible
  if not iwtb.windowframe:IsShown() or not iwtb.rlTab:IsShown() then
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
  for rldbName,v in pairs(iwtb.rlProfileDB.profile.raiders) do -- can convert
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
      local desireid = hasDesire(rldbName, tonumber(iwtb.rlSelectedTier.expacid), tonumber(iwtb.rlSelectedTier.instid), tostring(iwtb.rlSelectedTier.bossid))
      local hasNote, noteTxt = hasNote(rldbName, tonumber(iwtb.rlSelectedTier.instid), tostring(iwtb.rlSelectedTier.bossid))
      if desireid or hasNote then
        ooRraiders[rldbName] = {}
        if desireid then ooRraiders[rldbName].desireid = desireid end
        if hasNote then ooRraiders[rldbName].notetxt = noteTxt end
        ooRCount = ooRCount +1
      end
    end
  end
  
  -- Send Out of raid raiders to be drawn
  if ooRCount > 0 then drawOoR(ooRraiders) end
  
  for subgrp,mem in pairs(raidMembers) do -- can convert
    for k, player in ipairs(mem) do
      local textColour = RAID_CLASS_COLORS[player.fileName]
      local desireid = hasDesire(player.name, tonumber(iwtb.rlSelectedTier.expacid), tonumber(iwtb.rlSelectedTier.instid), tostring(iwtb.rlSelectedTier.bossid))
      iwtb.grpMemSlotFrame[subgrp][k]:SetAttribute("raidid", player.raidid) -- We can use this when changing player group
      iwtb.grpMemSlotFrame[subgrp][k].texture:SetColorTexture(0, 0 ,0 ,1)
      iwtb.grpMemSlotFrame[subgrp][k].nameText:SetText(player.name)
      if player.online then
        iwtb.grpMemSlotFrame[subgrp][k].nameText:SetTextColor(textColour.r, textColour.g, textColour.b)
      else
        iwtb.grpMemSlotFrame[subgrp][k].nameText:SetTextColor(0.8,0.8,0.8,0.7)
      end
      iwtb.grpMemSlotFrame[subgrp][k].roleTexture:SetTexCoord(roleTexCoords[player.crole].left, roleTexCoords[player.crole].right, roleTexCoords[player.crole].top, roleTexCoords[player.crole].bottom)
      iwtb.grpMemSlotFrame[subgrp][k].roleTexture:Show()
      iwtb.grpMemSlotFrame[subgrp][k].desireTag.text:SetText(iwtb.desire[desireid] or L["Unknown desire"])
      
      local hasNote, noteTxt = hasNote(player.name, tonumber(iwtb.rlSelectedTier.instid), tostring(iwtb.rlSelectedTier.bossid))
      if hasNote then
        iwtb.grpMemSlotFrame[subgrp][k].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        iwtb.grpMemSlotFrame[subgrp][k].note:SetAttribute("hasNote", true)
        iwtb.grpMemSlotFrame[subgrp][k].note:SetAttribute("noteTxt", noteTxt)
      else
        iwtb.grpMemSlotFrame[subgrp][k].note.texture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
        iwtb.grpMemSlotFrame[subgrp][k].note:SetAttribute("hasNote", false)
        iwtb.grpMemSlotFrame[subgrp][k].note:SetAttribute("noteTxt", "")
      end
    end
  end
end

function iwtb.setStatusText(f, text)
  local curTop = iwtb.rlTab.rlStatusPanel.text:GetText()
  local function churnContent(statuses)
    -- insert at top
    table.insert(statuses, 1, curTop)
    -- remove bottom
    if #statuses > 10 then table.remove(statuses) end
    return statuses
  end
  
  if f == "raider" then
    iwtb.raiderTab.raiderStatusPanel.text:SetText(text)
    iwtb.raiderTab.raiderStatusPanel.anim:Play()
  elseif f == "raidleader" then
    iwtb.rlTab.rlStatusPanel.text:SetText(text) -- Set top to latest
    iwtb.rlTab.rlStatusPanel.anim:Play()
    rlStatusContent = churnContent(rlStatusContent)
    for k,v in pairs(rlStatusContent) do -- can convert
      iwtb.rlTab.rlStatusPanel.content[k].text:SetText(v)
    end
  end
end


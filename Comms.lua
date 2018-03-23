local AceTimer = LibStub("AceTimer-3.0")
local AceComm = LibStub("AceComm-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local Compressor = LibStub("LibCompress")
local Encoder = Compressor:GetAddonEncodeTable()

local commSpec = 1 -- communication spec, to be changed with data layout revisions that will effect the comms channel data.

local function printTable(table)
  --print(type(table))
  if type(table) == "table" then
    if table == nil then print("Empty table") end -- this won't work?
    for key, value in pairs(table) do
        print("k: " .. key .. " v: " .. value)
    end
  end
end

-- Comms channel prefixes
XFER_HASH = "IWTB_XFER_HASH"
REQUEST_DATA = "IWTB_REQ_DATA"
--UPDATE_HASH = "IWTB_UPDATE_HASH"
XFER_DATA = "IWTB_XFER_DATA"

iwtb.hashData = function (data)
  local serData = Serializer:Serialize(data)
      
  local hash = Compressor:fcs32init()
  hash = Compressor:fcs32update(hash, serData)
  hash = Compressor:fcs32final(hash)
  hash = string.format("%010s", tostring(hash)) -- Pad the hash
  
  return hash
end

iwtb.encodeData = function (data)
  --data.commSpec = commSpec
  local serData = Serializer:Serialize(data)
      
  local hash = Compressor:fcs32init()
  hash = Compressor:fcs32update(hash, serData)
  hash = Compressor:fcs32final(hash)
  hash = string.format("%010s", tostring(hash)) -- Pad the hash
  
  -- Compressing the hash?
  serData = serData .. hash
  
  local compData = Compressor:CompressHuffman(serData)
  local encData = Encoder:Encode(compData)
  
  return encData
end

iwtb.decodeData = function (text)
  local compData = Encoder:Decode(text)
  
  -- Decompress
  local data, msg = Compressor:Decompress(compData)
  if data == nil then
    print("Decompress failed: " .. msg)
    return false;
  end
  
  -- Extract hash
  local msgHash = strsub(data, strlen(data) - 9)
  msgHash = tonumber(msgHash)
  
  if msgHash ~= nil then -- Nil when the number conversion fails, either due to corruption or it being missing
    local hash = Compressor:fcs32init()
    hash = Compressor:fcs32update(hash, strsub(data, 1, strlen(data) - 10))
    hash = Compressor:fcs32final(hash)
    
    if hash ~= msgHash then
      print("Msg hash mismatch!")
      return false
    end
  end  
  
  local success, data = Serializer:Deserialize(data)  
  if not success then
    print("Decode failed: " .. data)
    return false
  end
  
  return true, data
end

-- Send data
iwtb.sendData = function (prefix, data, target) 
  --data.commSpec = commSpec
  local odata = data
  --local outdata
  local sType
  
  --if prefix == "uhash" then
    --sType = UPDATE_HASH
  if prefix == "rhash" then
    sType = XFER_HASH
  elseif prefix == "udata" then
    sType = XFER_DATA
    odata.commSpec = commSpec
    odata = iwtb.encodeData(odata)
  elseif prefix == "rdata" then
    sType = REQUEST_DATA
  end
  
  -- Targets are /w, raid (and guild?)
  if target == "raid" then
    AceComm:SendCommMessage(sType, odata, "RAID")
  elseif target == "guild" then
    AceComm:SendCommMessage(sType, odata, "GUILD")
  elseif target ~= "" then -- Presume target is char name
    AceComm:SendCommMessage(sType, odata, "WHISPER", target)
  end
  
end

------------------------------------
-- Listening functions
------------------------------------

local function dbRLRaiderCheck(raider, expac, tier)
  if iwtb.raidLeaderDB.char.raiders[raider] == nil then
    iwtb.raidLeaderDB.char.raiders[raider] = {}
    iwtb.raidLeaderDB.char.raiders[raider].bossListHash = ""
    --iwtb.raidLeaderDB.char.raiders[raider].expac = {}
  end
  -- Below is for when we update only say an expac, tier or boss (if enabling loot item selection). For now we just send the whole lot!
  --[[if iwtb.raidLeaderDB.raiders[raider].expac[expac] == nil then iwtb.raidLeaderDB.raiders[raider].expac[expac] = {} end
  if iwtb.raidLeaderDB.raiders[raider].expac[expac].tier[tier] == nil then iwtb.raidLeaderDB.raiders[raider].expac[expac].tier[tier] = {} end
  if iwtb.raidLeaderDB.raiders[raider].expac[expac].tier[tier].bosses == nil then iwtb.raidLeaderDB.raiders[raider].expac[expac].tier[tier].bosses = {} end]]
end

-- new data from raider
local function xferData(prefix, text, distribution, sender)
  --sender = StripRealm(sender)
  --if sender == playerName or tContains(sessionBlacklist, sender) then
    --return
  --end
  
  -- Do some check if we care about data. Requires promoted? In raid? Have an option to ignore all data?
  
  --print("Received update - "  .. sender)
  local success, data = iwtb.decodeData(text)
  
  --[[if not(success) then
    return AceComm:SendCommMessage(REQUEST_MSG_PREFIX, BossList.lastUpdates[sender], "WHISPER", sender)
  end]]
  
  if data.commSpec == nil or data.commSpec < commSpec then
    --tinsert(sessionBlacklist, sender)
    --print("Old comm spec: " .. sender)
    iwtb.setStatusText("raidleader", "Older comm spec: " .. sender)
    return
  elseif data.commSpec > commSpec then
    --if not(gottenUpdateMessage) then
      --print("Newer comm spec: " .. sender)
      iwtb.setStatusText("raidleader", "Newer comm spec: " .. sender)
      --gottenUpdateMessage = true
    --end
    return
  else
    --print("Update data")
    --print_table(data.expac)
    dbRLRaiderCheck(sender)
    iwtb.raidLeaderDB.char.raiders[sender].expac = data.expac
    iwtb.raidLeaderDB.char.raiders[sender].bossListHash = iwtb.hashData(data.expac)
    iwtb.setStatusText("raidleader", "Received update - " .. sender)
    --print(iwtb.hashData(data.expac))
    --print_table(data.expac)
    --print(data)
    --print("RLDB: " .. iwtb.raidLeaderDB.char.raiders[sender].bossListHash)
  end
  
  -- Update local data
  --BossList.MergeData(table, sender)
end

local function requestData(prefix, text, distribution, sender)
  --sender = StripRealm(sender)
  --if sender == playerName or tContains(sessionBlacklist, sender) then
    --return
  --end
  
  --print("Received update - " .. prefix .. " from " .. sender)
  local success, data = iwtb.decodeData(text)
  
  --[[if not(success) then
    return AceComm:SendCommMessage(REQUEST_MSG_PREFIX, BossList.lastUpdates[sender], "WHISPER", sender)
  end]]
  
  if data.commSpec == nil or data.commSpec < commSpec then
    --tinsert(sessionBlacklist, sender)
    print("Old comm spec: " .. sender)
    return
  elseif data.commSpec > commSpec then
    --if not(gottenUpdateMessage) then
      print("Newer comm spec: " .. sender)
      --gottenUpdateMessage = true
    --end
    return
  else
    --data.commSpec = nil
  end
  --iwtb.setStatusText("raidleader","Received update - " .. prefix .. " from " .. sender)
  -- Update local data
  --BossList.MergeData(table, sender)
end

--[[local function updateHash(prefix, text, distribution, sender)
  print("Received hash - " .. prefix .. " from " .. sender)
  
  if data.commSpec == nil or data.commSpec < commSpec then
    --tinsert(sessionBlacklist, sender)
    print("Old/absent comm spec: " .. sender)
    return
  elseif data.commSpec > commSpec then
    --if not(gottenUpdateMessage) then
      print("Newer comm spec: " .. sender)
      --gottenUpdateMessage = true
    --end
    return
  else
    --data.commSpec = nil
  end
  
  -- Update local hash
end]]

-- RL sends the boss list hash they currently have. If it's different to the raiders, they send updated data.
local function xferHash(prefix, text, distribution, sender)
  --print("Request hash - " .. sender .. " Dist: " .. distribution)
  dbRLRaiderCheck(sender)
  print("Their hash: " .. text .. " Your hash: " .. tostring(iwtb.raidLeaderDB.char.raiders[sender].bossListHash))
  
  -- Temp statement for testing
  if text ~= iwtb.raidLeaderDB.char.raiders[sender].bossListHash then
  -- Final statement if RL sends (may change)
  --if text ~= iwtb.raiderDB.char.bossListHash then
    -- Send current boss list
    print("Boss list hash mismatch - sending updated data")
    iwtb.sendData("udata", iwtb.raiderDB.char, sender)
  end
  
end

AceComm:RegisterComm(XFER_DATA, xferData)
AceComm:RegisterComm(REQUEST_DATA, requestData)
--AceComm:RegisterComm(UPDATE_HASH, updateHash)
AceComm:RegisterComm(XFER_HASH, xferHash)
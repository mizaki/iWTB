local AceTimer = LibStub("AceTimer-3.0")
local AceComm = LibStub("AceComm-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local Compressor = LibStub("LibCompress")
local Encoder = Compressor:GetAddonEncodeTable()
local L = iwtb.L

local commSpec = 2 -- communication spec, to be changed with data layout revisions that will effect the comms channel data.

-- Comms channel prefixes
local XFER_HASH = "IWTB_XFER_HASH" -- Send hash of raider boss list
local REQUEST_DATA = "IWTB_REQ_DATA" -- Request data from raider
local REQUEST_HASH = "IWTB_REQ_HASH" -- Request hash from raider
local XFER_DATA = "IWTB_XFER_DATA" -- Send raider data

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
  if iwtb.rlProfileDB.profile.raiders[raider] == nil then
    iwtb.rlProfileDB.profile.raiders[raider] = {}
    iwtb.rlProfileDB.profile.raiders[raider].bossListHash = ""
  end
end

-- new data from raider
local function xferData(prefix, text, distribution, sender)
  -- Do some check if we care about data. Requires promoted?
  local success, data = iwtb.decodeData(text)
  
  if data.commSpec == nil or data.commSpec < commSpec then
    iwtb.setStatusText("raidleader", "Older comm spec: " .. sender)
    return
  elseif data.commSpec > commSpec then
    iwtb.setStatusText("raidleader", "Newer comm spec: " .. sender)
    return
  elseif iwtb.db.char.ignoreAll then
    iwtb.setStatusText("raidleader", L["Ignored data. Change in options to receive data"])
    return
  else
    if not iwtb.db.char.syncOnlyGuild or (iwtb.db.char.syncOnlyGuild and iwtb.isGuildMember(sender)) then
      dbRLRaiderCheck(sender)
      --iwtb.raidLeaderDB.char.raiders[sender].expac = data.expac
      iwtb.rlProfileDB.profile.raiders[sender].raids = data.raids
      iwtb.rlProfileDB.profile.raiders[sender].bossListHash = iwtb.hashData(data.raids)
      --iwtb.raidLeaderDB.char.raiders[sender].bossListHash = iwtb.hashData(data.expac)
      iwtb.setStatusText("raidleader", L["Received update - "] .. sender)
    else
      iwtb.setStatusText("raidleader", L["Ignored non-guild member data - "] .. sender)
    end
  end
end

-- TODO
local function requestData(prefix, text, distribution, sender)
    iwtb.sendData("udata", iwtb.raiderDB.char, sender)
    iwtb.setStatusText("raider", L["Sent data to "] .. sender)
end

-- TODO: RL sends the boss list hash they currently have. If it's different to the raiders, they send updated data.
local function xferHash(prefix, text, distribution, sender)
  dbRLRaiderCheck(sender)
  --print("Their hash: " .. text .. " Your hash: " .. tostring(iwtb.raidLeaderDB.char.raiders[sender].bossListHash))
  
  -- Temp statement for testing
  if text ~= iwtb.rlProfileDB.profile.raiders[sender].bossListHash then
  -- Final statement if RL sends (may change)
  --if text ~= iwtb.raiderDB.char.bossListHash then
    -- Send current boss list
    --print("Boss list hash mismatch - sending updated data")
    iwtb.sendData("udata", iwtb.raiderDB.char, sender)
  end
  
end

AceComm:RegisterComm(XFER_DATA, xferData)
AceComm:RegisterComm(REQUEST_DATA, requestData)
--AceComm:RegisterComm(UPDATE_HASH, updateHash)
AceComm:RegisterComm(XFER_HASH, xferHash)
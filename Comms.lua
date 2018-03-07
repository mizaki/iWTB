local AceTimer = LibStub("AceTimer-3.0")
local AceComm = LibStub("AceComm-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local Compressor = LibStub("LibCompress")
local Encoder = Compressor:GetAddonEncodeTable()

-- Comms channel prefixes
REQUEST_HASH = "IWTB_REQUEST_HASH"
REQUEST_DATA = "IWTB_REQUEST_DATA"
UPDATE_HASH = "IWTB_UPDATE_HASH"
UPDATE_DATA = "IWTB_UPDATE_DATA"

iwtb.encodeData = function (rType, data)
  -- rType (not the game!) is if we return just the HASH or the full compressed/hashed data
  if rType == "hash" then
    -- Just the hash (man)
      local serData = Serializer:Serialize(data)
      
      local hash = Compressor:fcs32init()
      hash = Compressor:fcs32update(hash, serData)
      hash = Compressor:fcs32final(hash)
      hash = string.format("%010s", tostring(hash)) -- Pad the hash
      print(hash)
      print("hash: " .. hash)
      return hash
  else
    -- Do the full beans
      local serData = Serializer:Serialize(data)
      
      local hash = Compressor:fcs32init()
      hash = Compressor:fcs32update(hash, serData)
      hash = Compressor:fcs32final(hash)
      hash = string.format("%010s", tostring(hash)) -- Pad the hash
      -- Compressing the hash?
      data = data .. hash
      
      local compData = Compressor:CompressHuffman(data)
      local encData = Encoder:Encode(compData)
      
      return encData
  end
end

local function decodeData(text)
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
      print("Hash mismatch!")
      return false
    end
  end  
  
  local succes, data = Serializer:Deserialize(data)  
  if not succes then
    print("Deserialize failed: " .. data)
    return false
  end
  
  return true, data
end

-- Send data
local function SendData(prefix, data, target) 
  data.commSpec = commSpec
  
  local data = encodeData(data)
  
  -- Targets are /w, raid (and guild?)
  if target == "raid" then
    AceComm:SendCommMessage(prefix, data, "RAID")
  elseif target == "whisper" then
    AceComm:SendCommMessage(prefix, data, "WHISPER", target)
  elseif target == "guild" then
    AceComm:SendCommMessage(prefix, data, "GUILD", target)
  end
  
end

local function UpdateData(prefix, text, distribution, sender)
  --sender = StripRealm(sender)
  --if sender == playerName or tContains(sessionBlacklist, sender) then
    --return
  --end
  
  print("Received update - " .. prefix .. " from " .. sender)
  local succes, data = decodeData(text)
  
  --[[if not(succes) then
    return AceComm:SendCommMessage(REQUEST_MSG_PREFIX, BossList.lastUpdates[sender], "WHISPER", sender)
  end]]
  
  if data.commSpec == nil or data.commSpec < commSpec then
    --tinsert(sessionBlacklist, sender)
    print("BossList: Received message from older version from " .. sender .. ". Please tell him/her to update.")
    return
  elseif data.commSpec > BossList.REVISION then
    if not(gottenUpdateMessage) then
      print("BossList: Received message from newer version. Please update your BossList")
      gottenUpdateMessage = true
    end
    return
  else
    --data.commSpec = nil
  end
  
  -- Update local data
  --BossList.MergeData(table, sender)
end



--AceComm:RegisterComm(STATE_MSG_PREFIX, MessageHandler)
--AceComm:RegisterComm(REQUEST_MSG_PREFIX, RequestHandler)
AceComm:RegisterComm(UPDATE_DATA, UpdateData)
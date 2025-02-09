PocketMoneyRankings = PocketMoneyRankings or {}
local lastRequestTime = {}
local hasRequestedInitialData = false
local updateTimer

-- Helper Functions
local function debug(msg)
  DEFAULT_CHAT_FRAME:AddMessage("PCM Debug: " .. tostring(msg), 1, 1, 0)
end

local function getNameWithoutRealm(fullName)
  return fullName:match("([^-]+)")
end

local function SafeAmbiguate(name)
  if not name or name == "" then return nil end

  if not name:find("-") then
    name = name .. "-" .. GetRealmName():gsub("%s+", "")
  end
  
  return Ambiguate(name, "short")
end

local MessageBuffers = {
  buffers = {},
  timeouts = {}
}

function MessageBuffers:Clear(sender)
  if self.timeouts[sender] then
    self.timeouts[sender]:Cancel()
    self.timeouts[sender] = nil
  end
  self.buffers[sender] = nil
end

function MessageBuffers:AddChunk(sender, chunkNum, totalChunks, chunk)
  -- Initialize buffer for this sender
  if not self.buffers[sender] then
    self.buffers[sender] = {
      chunks = {},
      totalChunks = totalChunks,
      messageType = nil
    }
  end

  -- Reset timeout
  if self.timeouts[sender] then
    self.timeouts[sender]:Cancel()
  end
  
  self.timeouts[sender] = C_Timer.NewTimer(5, function()
    self:Clear(sender)
  end)

  -- Store chunk
  self.buffers[sender].chunks[chunkNum] = chunk

  -- Check if message is complete
  local complete = true
  for i = 1, totalChunks do
    if not self.buffers[sender].chunks[i] then
      complete = false
      break
    end
  end

  return complete
end

function MessageBuffers:GetCompleteMessage(sender)
  if not self.buffers[sender] then return nil end
  
  local fullMessage = ""
  for i = 1, self.buffers[sender].totalChunks do
    fullMessage = fullMessage .. (self.buffers[sender].chunks[i] or "")
  end
  
  -- Clean up after getting complete message
  self:Clear(sender)
  
  return fullMessage
end

function QueueUIUpdate()
  if updateTimer then
    updateTimer:Cancel()
  end
  updateTimer = C_Timer.NewTimer(0.5, function()
    PocketMoneyRankings.UpdateUI()
    updateTimer = nil
  end)
end

-- AUDITS
-- Audit the knownRogues Table
function PocketMoneyRankings.AuditKnownRogues(realmName, mainChar, isAltUpdate, messageData)
  -- Ensure basic data structure exists
  if not PocketMoneyDB[realmName] or not PocketMoneyDB[realmName].knownRogues then return end

  -- If we have message data, handle alts and main relationships
  if messageData then
    if isAltUpdate then
      if PocketMoneyDB[realmName].knownRogues[mainChar] then
        -- Initialize or update main character data
        local mainData = PocketMoneyDB[realmName].knownRogues[mainChar]
        mainData.gold = mainData.gold or 0
        mainData.junk = mainData.junk or 0
        mainData.boxValue = mainData.boxValue or 0
        mainData.timestamp = mainData.timestamp or GetServerTime()
        mainData.lastSeen = mainData.lastSeen or GetServerTime()
        mainData.main = true
        mainData.Alts = mainData.Alts or {}
        mainData.Vers = mainData.Vers or "Unknown"

        -- Process alt relationships
        for rogueName, rogueData in pairs(PocketMoneyDB[realmName].knownRogues) do
          if rogueData.AltOf == mainChar then
            PocketMoneyDB[realmName].knownRogues[mainChar].Alts[rogueName] = rogueData
            PocketMoneyDB[realmName].knownRogues[rogueName] = nil
          end
        end
      end
    else
      -- When handling main's data
      if messageData.main and messageData.Alts then
        -- Initialize or update main character data
        PocketMoneyDB[realmName].knownRogues[mainChar] = PocketMoneyDB[realmName].knownRogues[mainChar] or {}
        local mainData = PocketMoneyDB[realmName].knownRogues[mainChar]
        mainData.gold = mainData.gold or 0
        mainData.junk = mainData.junk or 0
        mainData.boxValue = mainData.boxValue or 0
        mainData.timestamp = mainData.timestamp or GetServerTime()
        mainData.lastSeen = mainData.lastSeen or GetServerTime()
        mainData.main = true
        mainData.Alts = mainData.Alts or {}
        mainData.Vers = mainData.Vers or "Unknown"

        -- Process alts
        for altName, altData in pairs(messageData.Alts) do
          if PocketMoneyDB[realmName].knownRogues[altName] then
            if not mainData.Alts[altName] then
              mainData.Alts[altName] = PocketMoneyDB[realmName].knownRogues[altName]
            end
            PocketMoneyDB[realmName].knownRogues[altName] = nil
          end
        end
      end
    end
  -- No message data means we're just validating data structure during DB upgrade
  else
    if PocketMoneyDB[realmName].knownRogues[mainChar] then
      local data = PocketMoneyDB[realmName].knownRogues[mainChar]
      data.gold = data.gold or 0
      data.junk = data.junk or 0
      data.boxValue = data.boxValue or 0
      data.timestamp = data.timestamp or GetServerTime()
      data.lastSeen = data.lastSeen or GetServerTime()
      data.main = data.main or false
      data.Alts = data.Alts or {}
      data.Vers = data.Vers or "Unknown"
      
      -- Also validate alt data if this is a main character
      if data.Alts then
        for altName, altData in pairs(data.Alts) do
          altData.gold = altData.gold or 0
          altData.junk = altData.junk or 0
          altData.boxValue = altData.boxValue or 0
          altData.timestamp = altData.timestamp or GetServerTime()
          altData.lastSeen = altData.lastSeen or GetServerTime()
          altData.AltOf = mainChar
          altData.Vers = altData.Vers or "Unknown"
        end
      end
    end
  end
end

-- Audit Whoe DB
function PocketMoneyRankings.AuditDB()
  if PocketMoneyDB[realmName].main then
    local mainChar = PocketMoneyDB[realmName].main
    PocketMoneyDB[realmName][mainChar].main = true
    PocketMoneyDB[realmName][mainChar].Alts = PocketMoneyDB[realmName][mainChar].Alts or {}

    -- Move data to Alts table if it's not already there
    for charName, charData in pairs(PocketMoneyDB[realmName]) do
      if type(charData) == "table" and charData.AltOf == mainChar then
        if not PocketMoneyDB[realmName][mainChar].Alts[charName] then
          PocketMoneyDB[realmName][mainChar].Alts[charName] = {
            AltOf = mainChar,
            Guild = charData.Guild,
            lifetimeJunk = charData.lifetimeJunk,
            lifetimeGold = charData.lifetimeGold,
            lifetimeBoxValue = charData.lifetimeBoxValue,
            class = charData.class,
            Main = false,
            Vers = charData.Vers  -- Changed from charName.Vers to charData.Vers
          }
          -- Remove only this specific character's entry
          PocketMoneyDB[realmName][charName] = nil
        end
      end
    end

    -- Update checksums for all alts after moving data
    for altName, _ in pairs(PocketMoneyDB[realmName][mainChar].Alts) do
      if PocketMoneyCore.updateChecksum then
        PocketMoneyCore.updateChecksum(mainChar, altName)
      end
    end
    QueueUIUpdate()
  end

  -- Verify alt relationships
  for charName, data in pairs(PocketMoneyDB[realmName].knownRogues) do
    if data.Alts and next(data.Alts) then
      data.main = true
    end
    if data.main then
      for altName, altData in pairs(data.Alts) do
        if not altData.AltOf or altData.AltOf ~= charName then
          altData.AltOf = charName
        end
      end
    end
  end

  -- Clean up old fields
  for realmName, realmData in pairs(PocketMoneyDB) do
    if type(realmData) == "table" then
      -- Remove deprecated fields
      realmData.transactions = nil
      realmData.guildRankings = nil

      if realmData.knownRogues then
        for rogueName, rogueData in pairs(realmData.knownRogues) do
          -- Check if the rogue is a local character
          if realmData[rogueName] then
            realmData.knownRogues[rogueName] = nil
          end
        end
      end
    end
  end
  print("Old fields removed successfully.")
end

-- DATA HANDLING SECTION
-- Send OUR values to whoever requests
function PocketMoneyRankings.SendUpdate(target)
  local currentMain = PocketMoneyDB[realmName].main
  local dbLocation
  local guildName = PocketMoneyCore.GetPlayerGuild(playerName)
  if PocketMoneyCore.IsAltCharacter(playerName) then
    dbLocation = PocketMoneyDB[realmName][currentMain].Alts[playerName]
  else
    dbLocation = PocketMoneyDB[realmName][playerName]
  end

  local messageData = {
    type = "PLAYER_UPDATE",
    player = UnitName("player"),
    realm = GetRealmName(),
    gold = dbLocation.lifetimeGold or 0,
    junk = dbLocation.lifetimeJunk or 0,
    boxValue = dbLocation.lifetimeBoxValue or 0,
    guild = guildName,
    timestamp = GetServerTime(),
    main = dbLocation.main or false,
    AltOf = PocketMoneyCore.IsAltCharacter(playerName) and currentMain or nil,
    Alts = not PocketMoneyCore.IsAltCharacter(playerName) and (dbLocation.Alts or {}) or nil,
    Vers = PocketMoneyDB.lastSeenVersion
  }
 
  local LibSerialize = LibStub("LibSerialize")
  local success, serialized = pcall(function() 
    return LibSerialize:Serialize(messageData) 
  end)
  
  if success then
    if target then
      -- Split message if needed
      if #serialized <= 255 then
        -- Send normally if under limit
        PocketMoneyCore.SendMessage(serialized, target)
      else
        -- Split into chunks and send
        local chunks = {}
        local messageLen = #serialized
        local numChunks = math.ceil(messageLen / 250)  -- Leave room for chunk info
        
        for i = 1, numChunks do
          local start = (i-1) * 250 + 1
          local chunk = serialized:sub(start, start + 249)
          -- Add chunk metadata
          chunk = string.format("CHUNK:%d:%d:", i, numChunks) .. chunk
          table.insert(chunks, chunk)
        end

        -- Send chunks with delay to prevent flooding
        for i, chunk in ipairs(chunks) do
          C_Timer.After((i-1) * 0.2, function()
            PocketMoneyCore.SendMessage(chunk, target)
          end)
        end
      end
    end
  else
    print("Serialization failed")
  end
end

-- You'll also need to update the message handler:
local messageBuffer = {}

-- Add this to your CHAT_MSG_ADDON event handler:
if prefix == ADDON_PREFIX then
  -- Check if this is a chunked message
  local isChunk, chunkNum, totalChunks, message = text:match("^CHUNK:(%d+):(%d+):(.+)$")
  
  if isChunk then
    -- Handle chunked message
    chunkNum = tonumber(chunkNum)
    totalChunks = tonumber(totalChunks)
    
    if not messageBuffer[sender] then
      messageBuffer[sender] = {
        chunks = {},
        timeout = C_Timer.NewTimer(5, function()
          messageBuffer[sender] = nil
        end)
      }
    else
      -- Reset timeout
      messageBuffer[sender].timeout:Cancel()
      messageBuffer[sender].timeout = C_Timer.NewTimer(5, function()
        messageBuffer[sender] = nil
      end)
    end
    
    messageBuffer[sender].chunks[chunkNum] = message
    
    -- Check if we have all chunks
    local complete = true
    local fullMessage = ""
    for i = 1, totalChunks do
      if not messageBuffer[sender].chunks[i] then
        complete = false
        break
      end
      fullMessage = fullMessage .. messageBuffer[sender].chunks[i]
    end
    
    if complete then
      -- Process the complete message
      local LibSerialize = LibStub("LibSerialize")
      local success, messageData = pcall(function() 
        local decoded, result = LibSerialize:Deserialize(fullMessage)
        return result
      end)
      if success then
        PocketMoneyRankings.ProcessUpdate(sender, messageData)
      else
        debug("Deserialization failed")
      end
      -- Clean up
      messageBuffer[sender].timeout:Cancel()
      messageBuffer[sender] = nil
    end
  else
    -- Handle normal message
    local LibSerialize = LibStub("LibSerialize")
    local success, messageData = pcall(function() 
      local decoded, result = LibSerialize:Deserialize(text)
      return result
    end)
    if success then
      PocketMoneyRankings.ProcessUpdate(sender, messageData)
    else
      debug("Deserialization failed")
    end
  end
end

-- Annouce Our Presence To Players Joining PCMSync Channel
function PocketMoneyRankings.AnnouncePresence(target)

  local messageData = {
    type = "PLAYER_ACTIVE",
    player = UnitName("player"),
    realm = GetRealmName(),
    timestamp = GetServerTime()
  }

  local LibSerialize = LibStub("LibSerialize")
    local success, serialized = pcall(function() 
        return LibSerialize:Serialize(messageData) 
    end)

    if success then
        if target then
            PocketMoneyCore.SendMessage(serialized, target)
        end
    end
end

-- Request Data from other players
function PocketMoneyRankings.RequestLatestData(targetPlayer)
  local now = GetServerTime()

  local messageData = {
    type = "DATA_REQUEST",
    player = UnitName("player"),
    realm = GetRealmName(),
    timestamp = GetServerTime()
  }

  local LibSerialize = LibStub("LibSerialize")
  local success, serialized = pcall(function() 
    return LibSerialize:Serialize(messageData) 
  end)

  if success then
    if targetPlayer then
      PocketMoneyCore.SendMessage(serialized, targetPlayer)
      lastRequestTime[targetPlayer] = now
    else
      for player in pairs(PocketMoneyDB.tempData.onlinePlayers) do
        PocketMoneyCore.SendMessage(serialized, player)
        lastRequestTime[player] = now
      end
    end
  end
end

-- Recieving Data From Other Players
function PocketMoneyRankings.ProcessUpdate(sender, messageData, isChunked, chunkInfo)
  print(sender, messageData)
  if isChunked then
    local complete = MessageBuffers:AddChunk(sender, chunkInfo.number, chunkInfo.total, messageData)
    if not complete then return end -- Wait for more chunks
    
    -- Get complete message and deserialize
    local fullMessage = MessageBuffers:GetCompleteMessage(sender)
    local LibSerialize = LibStub("LibSerialize")
    local success, messageData = pcall(function() 
      local decoded, result = LibSerialize:Deserialize(fullMessage)
      return result
    end)
    
    if not success then
      print("Failed to deserialize complete message from:", sender)
      return
    end
  end

  if not messageData or type(messageData) ~= "table" then
    print()
    print("Invalid message data from:", sender)
    return
  end

  if messageData.player == playerName then 
    return 
  end

  -- Handle Player Presence
  if messageData.type == "PLAYER_ACTIVE" then
    PocketMoneyDB.tempData.onlinePlayers[messageData.player] = true
  end

  -- Handle DATA_REQUEST type
  if messageData.type == "DATA_REQUEST" then
    PocketMoneyDB.tempData.onlinePlayers[messageData.player] = true
    PocketMoneyRankings.SendUpdate(messageData.player)
    return
  end

  -- Handle a Player Changing Their Main
  if messageData.type == "MAIN_CHANGE" then
    local realmName = messageData.realm 
    if messageData.oldMain then
      PocketMoneyDB[realmName].knownRogues[messageData.oldMain] = nil
    end
    PocketMoneyDB[realmName].knownRogues[messageData.newMain] = messageData.mainData
    AuditKnownRogues(realmName, messageData.newMain, false, messageData.mainData)
    PocketMoneyRankings.UpdateUI()
    return
  end

  -- Handle Up Player Updates
  if messageData.type == "PLAYER_UPDATE" then
    local realmName = messageData.realm
    local senderName = messageData.player
    local guildName = messageData.guild or PocketMoneyCore.GetPlayerGuild(senderName)
    if not messageData.AltOf then
      PocketMoneyDB[realmName].knownRogues[senderName] = PocketMoneyDB[realmName].knownRogues[senderName] or {}
      local rogueData = PocketMoneyDB[realmName].knownRogues[senderName]
      rogueData.gold = messageData.gold or rogueData.gold or 0
      rogueData.junk = messageData.junk or rogueData.junk or 0
      rogueData.boxValue = messageData.boxValue or rogueData.boxValue or 0
      rogueData.timestamp = messageData.timestamp or GetServerTime()
      rogueData.lastSeen = GetServerTime()
      rogueData.Guild = guildName
      rogueData.main = messageData.main or false
      rogueData.Alts = rogueData.Alts or {}
      rogueData.Vers = messageData.Vers or "Unknown"
      if messageData.Alts then
        for altName, altData in pairs(messageData.Alts) do
            rogueData.Alts[altName] = altData
        end
      end
    else
      local mainChar = messageData.AltOf
      if not PocketMoneyDB[realmName].knownRogues[mainChar] then
        PocketMoneyDB[realmName].knownRogues[mainChar] = {
          Alts = {},
          main = true
        }
      end
      PocketMoneyDB[realmName].knownRogues[mainChar].Alts = PocketMoneyDB[realmName].knownRogues[mainChar].Alts or {}
      PocketMoneyDB[realmName].knownRogues[mainChar].Alts[senderName] = {
        gold = messageData.gold or 0,
        junk = messageData.junk or 0,
        boxValue = messageData.boxValue or 0,
        timestamp = messageData.timestamp or 0,
        lastSeen = GetServerTime(),
        Guild = guildName or nil,
        AltOf = messageData.AltOf or mainChar,
        Vers = messageData.Vers or "Unknown"
      }
    end
    if messageData.AltOf then
      PocketMoneyRankings.AuditKnownRogues(realmName, messageData.AltOf, true, messageData)
    else
      PocketMoneyRankings.AuditKnownRogues(realmName, senderName, false, messageData)
    end
    QueueUIUpdate()
  end
end

function PocketMoneyRankings.BroadcastMainChange(oldMain, newMain)

  local updateData = {
    type = "MAIN_CHANGE",
    realm = realmName,
    oldMain = oldMain,
    newMain = newMain,
    mainData = PocketMoneyDB[realmName][newMain],
    timestamp = GetServerTime()
  }

  local LibSerialize = LibStub("LibSerialize")
  local success, serialized = pcall(function() 
    return LibSerialize:Serialize(updateData) 
  end)

  if success then
    for player in pairs(PocketMoneyDB.tempData.onlinePlayers) do
      PocketMoneyCore.SendMessage(serialized, player)
    end
  end
end

local rankingsFrame = CreateFrame("Frame")
rankingsFrame:RegisterEvent("CHAT_MSG_ADDON")
rankingsFrame:RegisterEvent("ADDON_LOADED")
rankingsFrame:RegisterEvent("CHAT_MSG_CHANNEL")
rankingsFrame:RegisterEvent("CHAT_MSG_CHANNEL_JOIN")
rankingsFrame:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
rankingsFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, sender = ...
    if prefix == ADDON_PREFIX then
      local isChunk, chunkNum, totalChunks, message = text:match("^CHUNK:(%d+):(%d+):(.+)$")
      
      if isChunk then
        PocketMoneyRankings.ProcessUpdate(sender, message, true, {
          number = tonumber(chunkNum),
          total = tonumber(totalChunks)
        })
      else
        -- Handle regular messages
        local LibSerialize = LibStub("LibSerialize")
        local success, messageData = pcall(function() 
          local decoded, result = LibSerialize:Deserialize(text)
          return result
        end)
        if success then
          PocketMoneyRankings.ProcessUpdate(sender, messageData, false)
        else
          debug("Deserialization failed")
        end
      end
    end
  elseif event == "CHAT_MSG_CHANNEL_JOIN" then
    local _, playerJoined, _, _, _, _, _, _, channelBaseName = ...
    local playerNew = getNameWithoutRealm(playerJoined)
    if channelBaseName == PocketMoneyCore.CHANNEL_NAME then
      PocketMoneyRankings.AnnouncePresence(playerNew)
      PocketMoneyDB.tempData.onlinePlayers[playerNew] = true
    end
  elseif event == "CHAT_MSG_CHANNEL_LEAVE" then
    local _, playerLeft, _, _, _, _, _, _, channelBaseName = ...
    local playerNew = getNameWithoutRealm(playerLeft)
    if channelBaseName == PocketMoneyCore.CHANNEL_NAME then
      PocketMoneyDB.tempData.onlinePlayers[playerNew] = nil
    end
  end
end)
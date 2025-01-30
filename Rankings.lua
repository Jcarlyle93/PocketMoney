PocketMoneyRankings = PocketMoneyRankings or {}
local lastRequestTime = {}
local hasRequestedInitialData = false

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

-- AUDITS
-- Audit the knownRogues Table
local function AuditKnownRogues(realmName, mainChar, isAltUpdate, messageData)
  -- When handling alt data
  if isAltUpdate then
    if PocketMoneyDB[realmName].knownRogues[mainChar] then
      PocketMoneyDB[realmName].knownRogues[mainChar].Alts = PocketMoneyDB[realmName].knownRogues[mainChar].Alts or {}
      PocketMoneyDB[realmName].knownRogues[mainChar].main = true
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
      for altName, altData in pairs(messageData.Alts) do
        if PocketMoneyDB[realmName].knownRogues[altName] then
          if not PocketMoneyDB[realmName].knownRogues[mainChar].Alts[altName] then
            PocketMoneyDB[realmName].knownRogues[mainChar].Alts[altName] = PocketMoneyDB[realmName].knownRogues[altName]
          end
          PocketMoneyDB[realmName].knownRogues[altName] = nil
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
            Vers = charName.Vers
          }
        end
      end
    end
    if not PocketMoneyDB[realmName][mainChar].Alts[charName] then
      return
    else
      PocketMoneyDB[realmName][playerName] = nil
    end
    PocketMoneyCore.updateChecksum(mainChar, charName)
    PocketMoneyRankings.UpdateUI()
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
  for realmName, realmData in pairs(PocketMoneyDB) do
    if type(realmData) == "table" then
        if realmData.transactions then
            realmData.transactions = nil
        end

        -- Remove outdated 'guildRankings' field in realm-specific data
        if realmData.guildRankings then
            realmData.guildRankings = nil
        end

        if realmData.knownRogues then
          for rogueName, rogueData in pairs(realmData.knownRogues) do
              -- Check if the rogue is a local character (in PocketMoneyDB)
              if realmData[rogueName]then
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
      PocketMoneyCore.SendMessage(serialized, target)
    end
  else
    print("Serialization failed")
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
function PocketMoneyRankings.ProcessUpdate(sender, messageData)

  if not messageData or type(messageData) ~= "table" then
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
      PocketMoneyDB[realmName].knownRogues[senderName] = {
        gold = messageData.gold or 0,
        junk = messageData.junk or 0,
        boxValue = messageData.boxValue or 0,
        timestamp = messageData.timestamp or GetServerTime(),
        lastSeen = GetServerTime(),
        Guild = guildName or nil,
        main = messageData.main or false,
        Alts = messageData.Alts or {},
        Vers = messageData.Vers or "Unknown"
      }
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
      AuditKnownRogues(realmName, messageData.AltOf, true, messageData)
    else
      AuditKnownRogues(realmName, senderName, false, messageData)
    end
    PocketMoneyRankings.UpdateUI()
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
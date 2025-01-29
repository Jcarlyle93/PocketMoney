PocketMoneyRankings = PocketMoneyRankings or {}
local lastRequestTime = {}
local ADDON_PREFIX = "PMRank"
local hasRequestedInitialData = false
local realmName = GetRealmName()
local playerName = UnitName("player")
local mainPC = PocketMoneyCore.mainPC

-- Helper Functions
local function debug(msg)
  DEFAULT_CHAT_FRAME:AddMessage("PCM Debug: " .. tostring(msg), 1, 1, 0)
end

local function getNameWithoutRealm(fullName)
  return fullName:match("([^-]+)")
end

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

-- Send Data
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
    print("Data Serialize failed for player: ", target)
  end
end

-- Request Data
function PocketMoneyRankings.RequestLatestData(targetPlayer)
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
    local now = GetServerTime()
    if targetPlayer then
      if lastRequestTime[targetPlayer] and (now - lastRequestTime[targetPlayer]) < 60 then
        return
      end
      PocketMoneyCore.SendMessage(serialized, targetPlayer)
      lastRequestTime[targetPlayer] = now
    else
      for player in pairs(PocketMoneyDB.tempData.onlinePlayers) do
        if lastRequestTime[player] and (now - lastRequestTime[player]) > 60 then
          PocketMoneyCore.SendMessage(serialized, player)
          lastRequestTime[player] = now
        end
      end
    end
  end
end

-- Recieve Data
function PocketMoneyRankings.ProcessUpdate(sender, messageData)
  if not messageData or type(messageData) ~= "table" then
    return
  end

  PocketMoneyDB = PocketMoneyDB or {}
  PocketMoneyDB.tempData = PocketMoneyDB.tempData or {}
  PocketMoneyDB.tempData.onlinePlayers = PocketMoneyDB.tempData.onlinePlayers or {}

  local senderName = sender:match("^([^-]+)")
  if senderName == playerName then return end -- Ignore our own message

  -- Handle DATA_REQUEST type
  if messageData.type == "DATA_REQUEST" then
    PocketMoneyDB.tempData.onlinePlayers[senderName] = true
    PocketMoneyRankings.SendUpdate(senderName)
    return
  end

  if messageData.type == "MAIN_CHANGE" then
    local realmName = messageData.realm 
    if messageData.oldMain then
      PocketMoneyDB[realmName].knownRogues[messageData.oldMain] = nil
    end
    PocketMoneyDB[realmName].knownRogues[messageData.newMain] = messageData.mainData
    AuditKnownRogues(realmName, messageData.newMain, false, messageData.mainData)
    return
  end

  local realmName = messageData.realm
  local senderName = messageData.player
  local guildName = messageData.guild
  if not guildName or guildName == "NoGuild" then
    guildName = PocketMoneyCore.GetPlayerGuild(senderName)
  end

  PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
  PocketMoneyDB[realmName].knownRogues = PocketMoneyDB[realmName].knownRogues or {}

  if not messageData.AltOf then
    if not PocketMoneyDB[realmName].knownRogues[senderName] then
      PocketMoneyDB[realmName].knownRogues[senderName] = {}
    end

    PocketMoneyDB[realmName].knownRogues[senderName] = {
      gold = messageData.gold,
      junk = messageData.junk,
      boxValue = messageData.boxValue,
      timestamp = messageData.timestamp,
      lastSeen = GetServerTime(),
      Guild = guildName,
      main = messageData.main,
      Alts = messageData.Alts or {},
      Vers = messageData.Vers
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
      gold = messageData.gold,
      junk = messageData.junk,
      boxValue = messageData.boxValue,
      timestamp = messageData.timestamp,
      lastSeen = GetServerTime(),
      Guild = guildName,
      AltOf = messageData.AltOf,
      Vers = messageData.Vers
    }
  end
  if messageData.AltOf then
    AuditKnownRogues(realmName, messageData.AltOf, true, messageData)
  else
    AuditKnownRogues(realmName, senderName, false, messageData)
  end
end

-- Update the rankings list
function PocketMoneyRankings.ShowRankings()
  local rankings = {}

  for player, data in pairs(PocketMoneyDB[realmName].guildRankings or {}) do
    if player == playerName then
      local myData = PocketMoneyDB[realmName][playerName]
      local total = (myData.lifetimeGold or 0) + (myData.lifetimeJunk or 0) + (myData.lifetimeBoxValue or 0)
      table.insert(rankings, {
        player = playerName,
        total = total,
        gold = myData.lifetimeGold or 0,
        junk = myData.lifetimeJunk or 0,
        boxValue = myData.lifetimeBoxValue or 0
      })
    else
      local total = (data.gold or 0) + (data.junk or 0) + (data.boxValue or 0)
      table.insert(rankings, {
        player = player, 
        total = total,
        gold = data.gold or 0,
        junk = data.junk or 0,
        boxValue = data.boxValue or 0
      })
    end
  end

  for _, data in ipairs(rankings) do
    print(data.player, "Total:", data.total)
  end
  
  table.sort(rankings, function(a, b) return a.total > b.total end)
  
  for i, data in ipairs(rankings) do
    if i <= 10 then
      print(string.format("%d. %s - %s", i, data.player, 
        PocketMoneyCore.FormatMoney(data.total)))
    end
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
      return -- don't delete as it's not moved.
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
            print("Removing outdated 'transactions' for realm:", realmName)
            realmData.transactions = nil
        end

        -- Remove outdated 'guildRankings' field in realm-specific data
        if realmData.guildRankings then
            print("Removing outdated 'guildRankings' for realm:", realmName)
            realmData.guildRankings = nil
        end

        if realmData.knownRogues then
          for rogueName, rogueData in pairs(realmData.knownRogues) do
              -- Check if the rogue is a local character (in PocketMoneyDB)
              if realmData[rogueName]then
                  print("Removing local character from 'knownRogues':", rogueName)
                  realmData.knownRogues[rogueName] = nil
              end
          end
      end
    end
end

print("Old fields removed successfully.")
end

local rankingsFrame = CreateFrame("Frame")
rankingsFrame:RegisterEvent("CHAT_MSG_ADDON")
rankingsFrame:RegisterEvent("ADDON_LOADED")
rankingsFrame:RegisterEvent("CHAT_MSG_CHANNEL")
rankingsFrame:RegisterEvent("CHAT_MSG_CHANNEL_JOIN")
rankingsFrame:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
rankingsFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "PocketMoney" then
      C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    end
  elseif event == "CHAT_MSG_ADDON" then
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
    local _, playerName, _, _, _, _, _, _, channelBaseName = ...
    local playerNew = getNameWithoutRealm(playerName)
    local simplifiedJoiningPlayer = Ambiguate(playerJoining, "short")
    local simplifiedLocalPlayer = Ambiguate(localPlayerName, "short")
    if channelBaseName == PocketMoneyCore.CHANNEL_NAME then
      PocketMoneyDB.tempData.onlinePlayers[playerNew] = true
      PocketMoneyRankings.RequestLatestData(playerNew)
    end
    if simplifiedJoiningPlayer == simplifiedLocalPlayer and channelName == PocketMoneyCore.CHANNEL_NAME then
      C_Timer.After(1, function()
        PocketMoneyRankings.RequestLatestData()
      end)
    end
  elseif event == "CHAT_MSG_CHANNEL_LEAVE" then
    local _, playerName, _, _, _, _, _, _, channelBaseName = ...
    local playerNew = getNameWithoutRealm(playerName)
    if channelBaseName == PocketMoneyCore.CHANNEL_NAME then
      PocketMoneyDB.tempData.onlinePlayers[playerNew] = nil
    end
  end
end)

local cleanupFrame = CreateFrame("Frame")
cleanupFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
cleanupFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LEAVING_WORLD" then
      PocketMoneyDB.tempData.onlinePlayers = {}
    end
end)

PocketMoneyRankings = PocketMoneyRankings or {}

local ADDON_PREFIX = "PMRank"
local hasRequestedInitialData = false
local realmName = GetRealmName()
local playerName = UnitName("player")
local onlinePlayers = {}

local function debug(msg)
  DEFAULT_CHAT_FRAME:AddMessage("PCM Debug: " .. tostring(msg), 1, 1, 0)
end

-- Send Data
function PocketMoneyRankings.SendUpdate(target)
  local messageData = {
    type = "PLAYER_UPDATE",
    player = UnitName("player"),
    realm = GetRealmName(),
    gold = PocketMoneyDB[realmName][playerName].lifetimeGold or 0,
    junk = PocketMoneyDB[realmName][playerName].lifetimeJunk or 0,
    boxValue = PocketMoneyDB[realmName][playerName].lifetimeBoxValue or 0,
    timestamp = GetServerTime()
  }
 
  local LibSerialize = LibStub("LibSerialize")
  local success, serialized = pcall(function() 
    return LibSerialize:Serialize(messageData) 
  end)
 
  if success then
    if target then
      PocketMoneyCore.SendMessage(serialized, name)
    end
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
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
    if targetPlayer then
      PocketMoneyCore.SendMessage(serialized, targetPlayer)
    else
      for player in pairs(onlinePlayers) do
        PocketMoneyCore.SendMessage(serialized, player)
      end
    end
  end
end

-- Recieve Data
function PocketMoneyRankings.ProcessUpdate(sender, messageData)

  if not messageData or type(messageData) ~= "table" then
    debug("Recieved Invalid message data")
    return
  end

  local senderName = sender:match("^([^-]+)")

  if senderName == playerName then return end -- Ignore our own message

  -- Handle DATA_REQUEST type
  if messageData.type == "DATA_REQUEST" then
    onlinePlayers[senderName] = true
    PocketMoneyRankings.SendUpdate(senderName)
    return
  end

  if not success or 
    (messageData.type ~= "PLAYER_UPDATE" and messageData.type ~= "DATA_REQUEST") or 
    type(messageData) ~= "table" then
      debug("Recieved Invalid message data from " .. toString(sender))
   return
  end

  local realmName = messageData.realm
  local senderName = messageData.player
  
  PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
  PocketMoneyDB[realmName].guildRankings = PocketMoneyDB[realmName].guildRankings or {}
  PocketMoneyDB[realmName].knownRogues = PocketMoneyDB[realmName].knownRogues or {}

  local isGuildRogue = false
  local numMembers = GetNumGuildMembers()
  
  for i = 1, numMembers do
    local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
    local guildMemberName = name:match("^([^-]+)")
    
    if guildMemberName == messageData.player and class == "ROGUE" then
      isGuildRogue = true
      break
    end
  end

  if isGuildRogue then
    local existingData = PocketMoneyDB[realmName].guildRankings[senderName]
    if not existingData or existingData.timestamp < messageData.timestamp then
      PocketMoneyDB[realmName].guildRankings[senderName] = {
        gold = messageData.gold,
        junk = messageData.junk,
        boxValue = messageData.boxValue,
        timestamp = messageData.timestamp
      }
    end
  else
    if not PocketMoneyDB[realmName].knownRogues[senderName] then
      PocketMoneyDB[realmName].knownRogues[senderName] = {
        gold = messageData.gold,
        junk = messageData.junk,
        boxValue = messageData.boxValue,
        timestamp = messageData.timestamp,
        lastSeen = GetServerTime()
      }
    else
      PocketMoneyDB[realmName].knownRogues[senderName] = {
        gold = messageData.gold,
        junk = messageData.junk,
        boxValue = messageData.boxValue,
        timestamp = messageData.timestamp,
        lastSeen = GetServerTime()
      }
    end
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

function PocketMoneyRankings.AuditGuildRankings()
  local realmName = GetRealmName()
  print("PCM Debug: Starting guild rankings audit...")
  local guildRogues = {}
  local numMembers = GetNumGuildMembers()
  for i = 1, numMembers do
    local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
    local guildMemberName = name:match("^([^-]+)")
    if class == "ROGUE" then
      guildRogues[guildMemberName] = true
    end
  end
  for player, data in pairs(PocketMoneyDB[realmName].guildRankings) do
    if not guildRogues[player] then
      print("PCM Debug: Moving", player, "to known rogues (not in guild)")
      PocketMoneyDB[realmName].knownRogues[player] = data
      PocketMoneyDB[realmName].guildRankings[player] = nil
    end
  end
  print("PCM Debug: Audit complete")
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
        return LibSerialize:Deserialize(text)
      end)
      
      if success then
        PocketMoneyRankings.ProcessUpdate(sender, messageData)
      else
        debug("Deserialization failed")
      end
    end
  elseif event == "CHAT_MSG_CHANNEL_JOIN" then
    local _, playerName, _, channelName = ...
    if channelName == PocketMoneyCore.CHANNEL_NAME then
      onlinePlayers[playerName] = true
      PocketMoneyRankings.RequestLatestData(playerName)
    end
  elseif event == "CHAT_MSG_CHANNEL_LEAVE" then
    local _, playerName, _, channelName = ...
    if channelName == PocketMoneyCore.CHANNEL_NAME then
      onlinePlayers[playerName] = nil
    end
  end
end)
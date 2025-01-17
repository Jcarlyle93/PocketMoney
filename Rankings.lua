PocketMoneyRankings = {}
local ADDON_PREFIX = "PMRank"

function PocketMoneyRankings.SendUpdate()
  local currentTime = GetTime()
  local realmName = GetRealmName()
  local playerName = UnitName("player")
  local playerNameWithoutRealm, _ = strsplit("-", playerName)

  if currentTime - (lastUpdateSent or 0) < 300 then
    return
  end

  if not PocketMoneyDB[realmName] or not PocketMoneyDB[realmName][playerName] then
    print("PCM Debug: No data to send")
    return
  end

  local messageData = {
    type = "PLAYER_UPDATE",
    player = playerName,
    realm = realmName,
    gold = PocketMoneyDB[realmName][playerName].lifetimeGold,
    timestamp = GetServerTime(),
    checksum = PocketMoneySecurity.generateChecksum(
      PocketMoneyDB[realmName][playerName].lifetimeGold,
      PocketMoneyDB[realmName][playerName].lifetimeJunk
    )
  }

  local LibSerialize = LibStub("LibSerialize")
  local success, serialized = pcall(function() return LibSerialize:Serialize(messageData) end)
  if success then
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
    print("PCM Debug: Sent player update for", playerName)
    lastUpdateSent = GetTime()
  else
    print("PCM Debug: Failed to serialize message")
  end
end

function PocketMoneyRankings.RequestLatestData()
  local messageData = {
    type = "DATA_REQUEST",
    player = UnitName("player"),
    realm = GetRealmName(),
    timestamp = GetServerTime()
  }

  local LibSerialize = LibStub("LibSerialize")
  local success, serialized = pcall(function() return LibSerialize:Serialize(messageData) end)
  if success then
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
    print("PCM Debug: Sent data request to guild")
  else
    print("PCM Debug: Failed to serialize data request")
  end
end

function PocketMoneyRankings.ProcessUpdate(sender, data)
  
  if not data:find(ADDON_PREFIX) then
    return
  end

  local LibSerialize = LibStub("LibSerialize")
  local success, messageData = pcall(function() return LibSerialize:Deserialize(data) end)
  
  if not success or type(messageData) ~= "table" then
    print("PCM Debug: Failed to deserialize message")
    return
  end

  if messageData.type == "DATA_REQUEST" then
    print("PCM Debug: Received data request from", sender)
    PocketMoneyRankings.SendUpdate()
    return
  end

  if messageData.type ~= "PLAYER_UPDATE" then
    return
  end

  local senderName, senderRealm = strsplit("-", sender)
  local realmName = messageData.realm
  local playerName = messageData.player

  -- Verify data integrity
  if not PocketMoneySecurity.verifyIntegrity(messageData.gold, 0, messageData.checksum) then
    print("PCM Debug: Data integrity check failed")
    return
  end

  local isRogue = false
  local numMembers = GetNumGuildMembers()
  for i = 1, numMembers do
    local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
    if name and name:match("^([^-]+)") == playerName and class == "Rogue" then
      isRogue = true
      break
    end
  end

  if not isRogue then
    print("PCM Debug: Sender is not a Rogue or not in guild")
    return
  end

  PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
  PocketMoneyDB[realmName].guildRankings = PocketMoneyDB[realmName].guildRankings or {}

  local existingData = PocketMoneyDB[realmName].guildRankings[playerName]
  if not existingData or existingData.timestamp < messageData.timestamp then
    PocketMoneyDB[realmName].guildRankings[playerName] = {
      gold = messageData.gold,
      timestamp = messageData.timestamp
    }
    print("PCM Debug: Updated rankings for", playerName)
  end
end

function PocketMoneyRankings.ShowRankings()
  local rankings = {}
  local realmName = GetRealmName()

  for player, data in pairs(PocketMoneyDB[realmName].guildRankings or {}) do
    table.insert(rankings, {player = player, gold = data.gold})
  end
  
  table.sort(rankings, function(a, b) return a.gold > b.gold end)
  
  for i, data in ipairs(rankings) do
    if i <= 10 then
      print(string.format("%d. %s - %s", i, data.player, 
        PocketMoneyCore.FormatMoney(data.gold)))
    end
  end
end

local rankingsFrame = CreateFrame("Frame")
rankingsFrame:RegisterEvent("CHAT_MSG_ADDON")
rankingsFrame:RegisterEvent("PLAYER_LOGOUT")
rankingsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
rankingsFrame:RegisterEvent("ADDON_LOADED")

rankingsFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "PocketMoney" then
      if not C_ChatInfo.IsAddonMessagePrefixRegistered(ADDON_PREFIX) then
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
      end
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    if channel == "GUILD" then
        PocketMoneyRankings.ProcessUpdate(sender, message)
    end
  elseif event == "PLAYER_LOGOUT" then
    PocketMoneyRankings.SendUpdate()
  elseif event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(5, function()
      PocketMoneyRankings.SendUpdate()
      PocketMoneyRankings.RequestLatestData()
    end)
  end
end)

function PocketMoneyRankings.ToggleUI()
  PocketMoneyRankings.ShowRankings()
end
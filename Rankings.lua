local ADDON_PREFIX = "PMRank"
PocketMoneyRankings = PocketMoneyRankings or {}

local function RegisterAddonPrefix()
  if not C_ChatInfo.IsAddonMessagePrefixRegistered(ADDON_PREFIX) then
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
  end
end

-- Send
function PocketMoneyRankings.SendUpdate()
  local currentTime = GetTime()
  local realmName = GetRealmName()
  local playerName = UnitName("player")
  local playerNameWithoutRealm = playerName

  local messageData = {
    type = "PLAYER_UPDATE",
    player = playerName,
    realm = realmName,
    gold = PocketMoneyDB[realmName][playerNameWithoutRealm].lifetimeGold,
    timestamp = GetServerTime()
  }

  local LibSerialize = LibStub("LibSerialize")
  local success, serialized = pcall(function() 
    return LibSerialize:Serialize(messageData) 
  end)

  if success then
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
  end
end

-- Request
function PocketMoneyRankings.RequestLatestData()
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
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
  else
    print("PCM Debug: Failed to serialize data request")
  end
end

-- Recieve
function PocketMoneyRankings.ProcessUpdate(sender, data)
  print("PCM Debug: 1. Received message from", sender)
  if sender:match("^" .. UnitName("player") .. "-") then
    print("PCM Debug: 2. Ignoring own message")
    return
  end
  
  local LibSerialize = LibStub("LibSerialize")
  local success, messageData = pcall(function() 
    local decoded, result = LibSerialize:Deserialize(data)
    print("PCM Debug: Deserialized data contains:")
    print("  Player:", result.player)
    print("  Realm:", result.realm)
    print("  Gold:", result.gold)
    return result
  end)
  
  if not success then
    print("PCM Debug: 4. Deserialization failed")
    return
  end

  if type(messageData) ~= "table" then
    print("PCM Debug: 5. Invalid message format")
    return
  end

  if messageData.type == "DATA_REQUEST" then
    print("PCM Debug: 6. Got data request")
    PocketMoneyRankings.SendUpdate()
    return
  end

  if messageData.type ~= "PLAYER_UPDATE" then
    print("PCM Debug: 7. Invalid message type:", messageData.type)
    return
  end

  local isRogue = false
  local numMembers = GetNumGuildMembers()
  print("PCM Debug: 8. Checking", numMembers, "guild members")
  print("PCM Debug: Looking for player:", messageData.player)
  
  for i = 1, numMembers do
      local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
      local guildMemberName = name:match("^([^-]+)")
      
      if guildMemberName == messageData.player and class == "ROGUE" then
          print("PCM Debug: 9. Found rogue:", name)
          isRogue = true
          break
      end
  end

  if not isRogue then
    print("PCM Debug: 10. Not a rogue")
    return
  end

  local realmName = messageData.realm
  local playerName = messageData.player

  print("PCM Debug: 11. Adding rogue data:", playerName, messageData.gold)
  print("PCM Debug: Storing data for", playerName, "in realm", realmName)

  -- Initialize realm data structure if needed
  PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
  PocketMoneyDB[realmName].guildRankings = PocketMoneyDB[realmName].guildRankings or {}

  print("PCM Debug: Current rankings table contents:")
  for player, data in pairs(PocketMoneyDB[realmName].guildRankings) do
    print(player, data.gold)
  end

  local existingData = PocketMoneyDB[realmName].guildRankings[playerName]
  if not existingData or existingData.timestamp < messageData.timestamp then
    PocketMoneyDB[realmName].guildRankings[playerName] = {
      gold = messageData.gold,
      timestamp = messageData.timestamp
    }
    print("PCM Debug: Successfully stored data for", playerName)
  end
end

function PocketMoneyRankings.ShowRankings()
  local rankings = {}
  local realmName = GetRealmName()
  print("PCM Debug: Showing rankings for realm:", realmName)
  print("PCM Debug: Rankings table contents:")
  if PocketMoneyDB[realmName] and PocketMoneyDB[realmName].guildRankings then
    for player, data in pairs(PocketMoneyDB[realmName].guildRankings) do
      print(player, data.gold)
    end
  else
    print("No rankings data found")
  end

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

local hasRequestedInitialData = false
local rankingsFrame = CreateFrame("Frame")
rankingsFrame:RegisterEvent("CHAT_MSG_ADDON")
rankingsFrame:RegisterEvent("PLAYER_LOGOUT")
rankingsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
rankingsFrame:RegisterEvent("ADDON_LOADED")
rankingsFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "PocketMoney" then
      RegisterAddonPrefix()
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    if prefix == ADDON_PREFIX and channel == "GUILD" then
      PocketMoneyRankings.ProcessUpdate(sender, message)
    end
  elseif event == "PLAYER_LOGOUT" then
    PocketMoneyRankings.SendUpdate()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if not hasRequestedInitialData then
      C_Timer.After(5, function()
        PocketMoneyRankings.SendUpdate()
        PocketMoneyRankings.RequestLatestData()
        hasRequestedInitialData = true
      end)
    end
  end
end)

function PocketMoneyRankings.ToggleUI()
  PocketMoneyRankings.ShowRankings()
end
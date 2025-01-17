PocketMoneyRankings = {}

local ADDON_PREFIX = "PMRank"

local function InitializeRankings()
  local realmName = GetRealmName()
  local playerName = UnitName("player")
  local _, playerClass = UnitClass("player")

  PocketMoneyDB = PocketMoneyDB or {}
  PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
  PocketMoneyDB[realmName].guildRankings = PocketMoneyDB[realmName].guildRankings or {}
  
  PocketMoneyDB[realmName][playerName] = PocketMoneyDB[realmName][playerName] or {
    lifetimeGold = 0,
    lifetimeJunk = 0
  }

  if playerClass == "ROGUE" then
    PocketMoneyDB[realmName].guildRankings[playerName] = PocketMoneyDB[realmName].guildRankings[playerName] or {
      gold = PocketMoneyDB[realmName][playerName].lifetimeGold,
      timestamp = GetServerTime()
    }
  end
end

local updateCooldown = 300
local lastUpdateSent = 0
if not C_ChatInfo.IsAddonMessagePrefixRegistered(ADDON_PREFIX) then
  C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
end

function PocketMoneyRankings.SendUpdate()
  local currentTime = GetTime()
  local realmName = GetRealmName()
  local playerName = UnitName("player")
  local playerNameWithoutRealm, _ = strsplit("-", playerName)

  if currentTime - lastUpdateSent < updateCooldown then
    return
  end

  if not PocketMoneyDB[realmName] or not PocketMoneyDB[realmName][playerNameWithoutRealm] then
    print("PCM Debug: No data to send")
    return
  end

  local messageData = {
    player = playerName,
    realm = realmName,
    gold = PocketMoneyDB[realmName][playerNameWithoutRealm].lifetimeGold,
    timestamp = GetServerTime(),
    checksum = PocketMoneySecurity.generateChecksum(
      PocketMoneyDB[realmName][playerNameWithoutRealm].lifetimeGold,
      PocketMoneyDB[realmName][playerNameWithoutRealm].lifetimeJunk
    )
  }

  print("PCM Debug: Sending message data:", messageData.player, messageData.gold)
  local LibSerialize = LibStub("LibSerialize")
    local success, serialized = pcall(function() return LibSerialize:Serialize(messageData) end)
    if success then
      C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
      print("PCM Debug: Message serialized and sent")
    else
      print("PCM Debug: Failed to serialize message")
    end
    lastUpdateSent = GetTime()
end

function PocketMoneyRankings.ProcessUpdate(sender, data)

  if not data:find(ADDON_PREFIX) then
    return
  end

  local LibSerialize = LibStub("LibSerialize")
  local success, messageData = pcall(function() return LibSerialize:Deserialize(data) end)
  local senderName, senderRealm = strsplit("-", sender)

  if not success or type(messageData) ~= "table" then
    print("PCM Debug: Failed to deserialize message data or data is not a table.")
    return
  end
  
  print("PCM Debug: Deserialized Data -", messageData)

  local realmName = messageData.realm
  local playerName = messageData.player

  print("PCM Debug: Checking integrity. Sent checksum:", messageData.checksum)
  print("PCM Debug: Calculated checksum:", PocketMoneySecurity.generateChecksum(messageData.gold, 0))

  if not PocketMoneySecurity.verifyIntegrity(messageData.gold, 0, messageData.checksum) then
    print("PCM Debug: Data integrity check failed")
    return
  end

  if senderName == messageData.player then
    print("PCM Debug: Found matching sender:", senderName)

    local realmName = messageData.realm
    local playerName = messageData.player

    if realmName and playerName and messageData.gold then
      local numMembers = GetNumGuildMembers()
      local isRogue = false

      for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
        if name and name:match("^([^-]+)") == playerName then
          if class == "Rogue" then
            isRogue = true
            print("PCM Debug: Processing rogue data from", playerName, "Gold:", messageData.gold)
            break
          end
        end
      end

      if isRogue then
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
    end
  else
    print("PCM Debug: Ignoring message from non-addon player:", sender)
  end
end

function PocketMoneyRankings.ShowRankings()
  local rankings = {}
  local realmName = GetRealmName()

  for player, data in pairs(PocketMoneyDB[realmName].guildRankings) do
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
      InitializeRankings()
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    if channel == "GUILD" then
        PocketMoneyRankings.ProcessUpdate(sender, message)
    end
  elseif event == "PLAYER_LOGOUT" then
    PocketMoneyRankings.SendUpdate()
  elseif event == "PLAYER_ENTERING_WORLD" then
    InitializeRankings()
    C_Timer.After(5, PocketMoneyRankings.SendUpdate)
  end
end)
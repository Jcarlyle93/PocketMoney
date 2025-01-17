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
  if sender:match("^" .. UnitName("player") .. "-") then
    return
  end
  
  local LibSerialize = LibStub("LibSerialize")
  local success, messageData = pcall(function() 
    local decoded, result = LibSerialize:Deserialize(data)
    return result
  end)
  
  if not success then
    return
  end

  if type(messageData) ~= "table" then
    return
  end

  if messageData.type == "DATA_REQUEST" then
    PocketMoneyRankings.SendUpdate()
    return
  end

  if messageData.type ~= "PLAYER_UPDATE" then
    return
  end

  local isRogue = false
  local numMembers = GetNumGuildMembers()
  
  for i = 1, numMembers do
      local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
      local guildMemberName = name:match("^([^-]+)")
      
      if guildMemberName == messageData.player and class == "ROGUE" then
          isRogue = true
          break
      end
  end

  if not isRogue then
    return
  end

  local realmName = messageData.realm
  local playerName = messageData.player

  PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
  PocketMoneyDB[realmName].guildRankings = PocketMoneyDB[realmName].guildRankings or {}

  local existingData = PocketMoneyDB[realmName].guildRankings[playerName]
  if not existingData or existingData.timestamp < messageData.timestamp then
    PocketMoneyDB[realmName].guildRankings[playerName] = {
      gold = messageData.gold,
      timestamp = messageData.timestamp
    }
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
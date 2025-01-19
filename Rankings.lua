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
      junk = messageData.junk,
      boxValue = messageData.boxValue,
      timestamp = messageData.timestamp
    }
  end
end

function PocketMoneyRankings.ShowRankings()
  local rankings = {}
  local realmName = GetRealmName()
  local playerName = UnitName("player")

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
  if RankingsUI:IsShown() then
    RankingsUI:Hide()
  else
    PocketMoneyRankings.SendUpdate()
    PocketMoneyRankings.RequestLatestData()
    PocketMoneyRankings.ShowRankings()
    C_Timer.After(0.5, function()
      RankingsUI:Show()
      PocketMoneyRankings.ShowRankings()
    end)
  end
end
PocketMoneyRankings = {}

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
local ADDON_PREFIX = "PMRank"
if not C_ChatInfo.IsAddonMessagePrefixRegistered(ADDON_PREFIX) then
  C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
end

function PocketMoneyRankings.SendUpdate()
  local currentTime = GetTime()
  local realmName = GetRealmName()
  local playerName = UnitName("player")

  if currentTime - lastUpdateSent < updateCooldown then
    return
  end

  if not PocketMoneyDB[realmName] or not PocketMoneyDB[realmName][playerName] then
    return
  end

  local messageData = {
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
    end
    lastUpdateSent = GetTime()
end

function PocketMoneyRankings.ProcessUpdate(sender, data)
  local LibSerialize = LibStub("LibSerialize")
  local success, messageData = pcall(function() return LibSerialize:Deserialize(data) end)
  
  if not success or type(messageData) ~= "table" then
    return
  end
  
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
      end
    end
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
PocketMoneyRankings = {}

local function InitializeRankings()
  PocketMoneyDB = PocketMoneyDB or {}
  PocketMoneyDB.guildRankings = PocketMoneyDB.guildRankings or {}
  local playerName = UnitName("player")
  local _, playerClass = UnitClass("player")
  print(playerClass)
  if playerClass == "ROGUE" then
    print(playerClass)
    if not PocketMoneyDB.guildRankings[playerName] then
        PocketMoneyDB.guildRankings[playerName] = {
            gold = PocketMoneyDB.lifetimeGold or 0,
            timestamp = GetServerTime()
        }
    end
  end
end

local updateCooldown = 300
local lastUpdateSent = 0

local ADDON_PREFIX = "PMRank"
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

function PocketMoneyRankings.SendUpdate()
  local currentTime = GetTime()
  if currentTime - lastUpdateSent < updateCooldown then
    return
  end

  local messageData = {
    player = UnitName("player"),
    gold = PocketMoneyDB.lifetimeGold,
    timestamp = GetServerTime(),
    checksum = PocketMoneySecurity.generateChecksum(PocketMoneyDB.lifetimeGold, PocketMoneyDB.lifetimeJunk) 
  }

  local serialized = LibStub("LibSerialize"):Serialize(messageData)
  C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
  lastUpdateSent = currentTime
end

function PocketMoneyRankings.ProcessUpdate(sender, data)
  local success, messageData = LibStub("LibSerialize"):Deserialize(data)
  if not success then 
    return 
  end

  if not PocketMoneySecurity.verifyIntegrity(messageData.gold, 0, messageData.checksum) then
    return
  end

  local existingData = PockMoneyDB.guildRankings[messageData.player]
  if not existingData or existingData.timestamp < messageData.timestemp then
    PocketMoneyDB.guildRanking[messageData.player] = {
      gold = messageData.gold,
      timestamp = messageData.timestamp
    }
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
      if prefix == ADDON_PREFIX and channel == "GUILD" then
        PocketMoneyRankings.ProcessUpdate(sender, message)
      end
  elseif event == "PLAYER_LOGOUT" then
    PocketMoneyRankings.SendUpdate()
  elseif event == "PLAYER_ENTERING_WORLD" then
    InitializeRankings()
    C_Timer.After(5, PocketMoneyRankings.SendUpdate)
  end
end)

function PocketMoneyRankings.ShowRankings()
  print("|cFFFFD700Guild Pickpocket Rankings:|r")
  
  local rankings = {}
  for player, data in pairs(PocketMoneyDB.guildRankings) do
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
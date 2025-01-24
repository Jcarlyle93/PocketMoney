local ADDON_PREFIX = "PMRank"
PocketMoneyRankings = PocketMoneyRankings or {}
local CHANNEL_NAME = "PCMSync"
local CHANNEL_PASSWORD = "pm" .. GetRealmName()

local function RegisterAddonPrefix()
  if not C_ChatInfo.IsAddonMessagePrefixRegistered(ADDON_PREFIX) then
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
  end
end

-- Send
function PocketMoneyRankings.SendUpdate()
  SendChatMessage("PCM Debug Test Message", "CHANNEL", nil, GetChannelName(CHANNEL_NAME))
  local realmName = GetRealmName()
  local playerName = UnitName("player")
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
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "GUILD")
    if PocketMoneyDB.settings and PocketMoneyDB.settings.includeAllRogues then
      C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "CHANNEL", GetChannelName(CHANNEL_NAME))
    end
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
    if PocketMoneyDB.settings and PocketMoneyDB.settings.includeAllRogues then
      C_ChatInfo.SendAddonMessage(ADDON_PREFIX, serialized, "CHANNEL", GetChannelName(CHANNEL_NAME))
    end
  end
 end

-- Recieve
function PocketMoneyRankings.ProcessUpdate(sender, data, channel)
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

  local name = sender:match("^([^-]+)")

  if messageData.type == "ADDON_CHECK" or messageData.type == "DATA_REQUEST" then
    PocketMoneyRankings.SendUpdate("WHISPER", sender)
    return
  end

  if messageData.type ~= "PLAYER_UPDATE" then
    return
  end


  local realmName = messageData.realm
  local playerName = messageData.player
  
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
    local existingData = PocketMoneyDB[realmName].guildRankings[playerName]
    if not existingData or existingData.timestamp < messageData.timestamp then
      PocketMoneyDB[realmName].guildRankings[playerName] = {
        gold = messageData.gold,
        junk = messageData.junk,
        boxValue = messageData.boxValue,
        timestamp = messageData.timestamp
      }
    end
  else
    PocketMoneyDB[realmName].knownRogues[playerName] = {
      gold = messageData.gold,
      junk = messageData.junk,
      boxValue = messageData.boxValue,
      timestamp = messageData.timestamp,
      lastSeen = GetServerTime()
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
    if prefix == ADDON_PREFIX then
      if channel == "GUILD" or 
         (channel == "CHANNEL" and PocketMoneyDB.settings.includeAllRogues) then
        PocketMoneyRankings.ProcessUpdate(sender, message, channel)
      end
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
    RankingsUI:Show()
  end
end
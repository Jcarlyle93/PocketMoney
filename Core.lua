local PocketMoney = CreateFrame("Frame")
PocketMoney:RegisterEvent("ADDON_LOADED")
PocketMoney:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
PocketMoney:RegisterEvent("LOOT_READY")
PocketMoney:RegisterEvent("LOOT_OPENED")
PocketMoney:RegisterEvent("LOOT_SLOT_CLEARED")
PocketMoney:RegisterEvent("LOOT_CLOSED")
PocketMoney:RegisterEvent("CHAT_MSG_SYSTEM")
PocketMoney:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")

local PICKPOCKET_LOCKBOXES = {
  [16885] = "Heavy Junkbox",
  [16884] = "Sturdy Junkbox",
  [16882] = "Battered Junkbox",
  [16883] = "Worn Junkbox"
}

local function debug(msg)
  print("PCM Debug: " .. tostring(msg))
end

local realmName = GetRealmName()
local playerName = UnitName("player")
local _, playerClass = UnitClass("player")
local isRogue = playerClass == "ROGUE"
local pendingLootSlots = {}
local CHANNEL_NAME = "PCMSync"
local CHANNEL_PASSWORD = "pm" .. GetRealmName()

LeaveChannelByName(CHANNEL_NAME, CHANNEL_PASSWORD)
JoinChannelByName(CHANNEL_NAME, CHANNEL_PASSWORD)

local function OnChatChannelJoin()
  print("PCM Debug: OnChatChannelJoin triggered")
  local channels = { GetChannelList() }
  print("PCM Debug: Retrieved channel list, length = " .. #channels)

  for i = 1, #channels, 3 do
      print("PCM Debug: Channel index " .. i .. " -> ID: " .. channels[i] .. ", Name: " .. channels[i + 1])
      if channels[i + 1] == CHANNEL_NAME then
          print("Joined hidden channel: " .. CHANNEL_NAME)
          return
      end
  end
  print("Failed to join hidden channel: " .. CHANNEL_NAME)
end

PocketMoneyCore = {}
PocketMoneyDB = PocketMoneyDB or {}
PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
if isRogue then
  PocketMoneyDB[realmName][playerName] = PocketMoneyDB[realmName][playerName] or {
    lifetimeGold = 0,
    lifetimeJunk = 0,
    lifetimeBoxValue = 0,
    checksum = nil,
    class = playerClass
  }
end

PocketMoneyDB[realmName].guildRankings = PocketMoneyDB[realmName].guildRankings or {}
PocketMoneyDB[realmName].knownRogues = PocketMoneyDB[realmName].knownRogues or {}

local CURRENT_DB_VERSION = 1.3

local function UpgradeDatabase()
  PocketMoneyDB[realmName][playerName] = PocketMoneyDB[realmName][playerName] or {
    lifetimeGold = 0,
    lifetimeJunk = 0,
    lifetimeBoxValue = 0,
    checksum = nil,
    class = playerClass
  }

  if not PocketMoneyDB[realmName][playerName].dbVersion or PocketMoneyDB[realmName][playerName].dbVersion < CURRENT_DB_VERSION then
    local existingGold = PocketMoneyDB[realmName][playerName].lifetimeGold or 0
    local existingJunk = PocketMoneyDB[realmName][playerName].lifetimeJunk or 0
    local existingBoxValue = PocketMoneyDB[realmName][playerName].lifetimeBoxValue or 0

    PocketMoneyDB[realmName][playerName] = {
      lifetimeGold = existingGold,
      lifetimeJunk = existingJunk,
      lifetimeBoxValue = existingBoxValue,
      dbVersion = CURRENT_DB_VERSION,
      checksum = nil,
      class = playerClass
    }
  end
end

function PocketMoneyCore.FormatMoney(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local copperRem = copper % 100
  local str = ""
  if gold > 0 then str = str .. "|cFFFFD700" .. gold .. "g|r " end
  if silver > 0 or gold > 0 then str = str .. "|cFFC0C0C0" .. silver .. "s|r " end
  str = str .. "|cFFB87333" .. copperRem .. "c|r"
  
  return str
end

local sessionGold = 0
local sessionJunk = 0
local sessionBoxValue = 0
local isPickpocketLoot = false
local lastProcessedMoney = nil
local lastProcessedItems = {}
local lastLootTime = 0
local sessionStartTime = GetServerTime()
local maxGoldPerHour = 100 * 10000
local pickpocketedBoxes = {}
local isOpeningJunkbox = false
local currentJunkboxType = nil

local function updateValues(gold, junk)
  PocketMoneyDB[realmName][playerName].lifetimeGold = gold
  PocketMoneyDB[realmName][playerName].lifetimeJunk = junk
  PocketMoneyDB[realmName][playerName].checksum = PocketMoneySecurity.generateChecksum(
    PocketMoneyDB[realmName][playerName].lifetimeGold, 
    PocketMoneyDB[realmName][playerName].lifetimeJunk
  )
end

local function parseMoneyString(moneyStr)
  local copper = 0
  
  local gold = moneyStr:match("(%d+) [Gg]old")
  local silver = moneyStr:match("(%d+) [Ss]ilver")
  local copperMatch = moneyStr:match("(%d+) [Cc]opper")
  
  if gold then copper = copper + (tonumber(gold) * 10000) end
  if silver then copper = copper + (tonumber(silver) * 100) end
  if copperMatch then copper = copper + tonumber(copperMatch) end
  
  return copper
end

local function updateBoxValue(value, debug_source)
  sessionBoxValue = sessionBoxValue + value
  PocketMoneyDB[realmName][playerName].lifetimeBoxValue = PocketMoneyDB[realmName][playerName].lifetimeBoxValue + value
end

local function ProcessPickpocketLoot(lootSlotType, itemLink, item, quantity)
  if lootSlotType == 1 then
    if itemLink and not lastProcessedItems[itemLink] then
      local itemID = GetItemInfoInstant(itemLink)
      local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
      if PICKPOCKET_LOCKBOXES[itemID] then
        lastProcessedItems[itemLink] = true
      elseif itemSellPrice then
        local totalValue = itemSellPrice * (quantity or 1)
        sessionJunk = sessionJunk + totalValue
        PocketMoneyDB[realmName][playerName].lifetimeJunk = PocketMoneyDB[realmName][playerName].lifetimeJunk + totalValue
        lastProcessedItems[itemLink] = true
      end
    end
  elseif lootSlotType == 2 then
    if item and item ~= lastProcessedMoney then
      local copper = parseMoneyString(item)
      sessionGold = sessionGold + copper
      PocketMoneyDB[realmName][playerName].lifetimeGold = PocketMoneyDB[realmName][playerName].lifetimeGold + copper
      lastProcessedMoney = item
      PocketMoneyDB[realmName].guildRankings[playerName] = {
        gold = PocketMoneyDB[realmName][playerName].lifetimeGold,
        timestamp = GetServerTime()
      }
    end
  end
end

local function ProcessJunkboxLoot(lootSlotType, itemLink, item, quantity)
  if not isOpeningJunkbox or not currentJunkboxType then
    return
  end
  if lootSlotType == 1 then  -- Item loot
    if itemLink and not lastProcessedItems[itemLink] then
      local itemID = GetItemInfoInstant(itemLink)
      local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
      
      if itemSellPrice then
        local totalValue = itemSellPrice * (quantity or 1)
        updateBoxValue(totalValue, "Junkbox Item")
        lastProcessedItems[itemLink] = true
      end
    end
  elseif lootSlotType == 2 then  -- Money loot
    if item and item ~= lastProcessedMoney then
      local copper = parseMoneyString(item)
      if copper > 0 then
        updateBoxValue(copper, "Junkbox Money")
        lastProcessedMoney = item
      end
    end
  end
end

PocketMoney:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "PocketMoney" then
      print("PickPocket loaded")
      UpgradeDatabase()
      PocketMoneyWhatsNew.CheckUpdateNotification()
    end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, castGUID, spellID = ...
    if unit == "player" and spellID == 921 then
      isPickpocketLoot = true
      wipe(lastProcessedItems)
      C_Timer.After(1, function()
        isPickpocketLoot = false
        lastProcessedMoney = nil
        wipe(lastProcessedItems)
      end)
    end
  elseif event == "LOOT_READY" then  
    local currentTime = GetTime()
    if currentTime - lastLootTime < 0.1 then
      return
    end
    lastLootTime = currentTime
    wipe(pendingLootSlots)

    if not isPickpocketLoot and GameTooltip:IsVisible() then
      local itemName = GameTooltip:GetItem()
      local isValidJunkbox = false
      for id, name in pairs(PICKPOCKET_LOCKBOXES) do
        if itemName == name then
          isValidJunkbox = true
          isOpeningJunkbox = true
          currentJunkboxType = name
          break
        end
      end

      if not isValidJunkbox then
        isOpeningJunkbox = false
        currentJunkboxType = nil
      end
    end
  
    local numItems = GetNumLootItems()
  
    for i = 1, numItems do
      local lootSlotType = GetLootSlotType(i)
      local itemLink = GetLootSlotLink(i)
      local _, item, quantity = GetLootSlotInfo(i)
  
      if isOpeningJunkbox then
        pendingLootSlots[i] = {
          type = lootSlotType,
          link = itemLink,
          item = item,
          quantity = quantity
        }
        
        if lootSlotType == 1 then
          local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
        end
      elseif isPickpocketLoot then
        ProcessPickpocketLoot(lootSlotType, itemLink, item, quantity)
      end
    end
  elseif event == "LOOT_SLOT_CLEARED" then
    local slotIndex = ...
    if isOpeningJunkbox and pendingLootSlots[slotIndex] then
      local lootInfo = pendingLootSlots[slotIndex]     
      ProcessJunkboxLoot(lootInfo.type, lootInfo.link, lootInfo.item, lootInfo.quantity)
      pendingLootSlots[slotIndex] = nil
    end
  elseif event == "LOOT_CLOSED" then

    isOpeningJunkbox = false
    currentJunkboxType = nil
    wipe(pendingLootSlots)

    isPickpocketLoot = false
    lastProcessedMoney = nil
    wipe(lastProcessedItems)
  end
end)

SLASH_POCKETMONEY1 = "/pm"
SlashCmdList["POCKETMONEY"] = function(msg)
  if msg == "clear" then
    PocketMoneyDB[realmName][playerName].lifetimeGold = 0
    PocketMoneyDB[realmName][playerName].lifetimeJunk = 0
    PocketMoneyDB[realmName][playerName].lifetimeBoxValue = 0
    sessionGold = 0
    sessionJunk = 0
    PocketMoneyDB[realmName][playerName].checksum = PocketMoneySecurity.generateChecksum(0, 0)
    print("Pocket Money: All statistics cleared!")
    return
  elseif msg == "rankings" or msg == "rank" then
    PocketMoneyRankings.ToggleUI()
    return
  elseif msg == "help" then
    print("Pocket Money Commands:")
    print("  /pm - Show current statistics")
    print("  /pm rankings - Show guild rankings")
    print("  /pm clear - Reset all statistics")
    return
  elseif msg == "audit" then
    PocketMoneyRankings.AuditGuildRankings()
    return
  end
  if not isRogue then
    print("You're not a rogue!")
    return
  end
  print("----------------------------------------")
  print("|cFF9370DB[Lifetime]|r:")
  print("  Raw Gold: " .. PocketMoneyCore.FormatMoney(PocketMoneyDB[realmName][playerName].lifetimeGold))
  print("  Junk Items: " .. PocketMoneyCore.FormatMoney(PocketMoneyDB[realmName][playerName].lifetimeJunk))
  print("  Junk Box Value: " .. PocketMoneyCore.FormatMoney(PocketMoneyDB[realmName][playerName].lifetimeBoxValue))
  print("|cFF00FF00[Session]|r:")
  print("  Raw Gold: " .. PocketMoneyCore.FormatMoney(sessionGold))
  print("  Junk Items: " .. PocketMoneyCore.FormatMoney(sessionJunk))
  print("  Junk Box Value: " .. PocketMoneyCore.FormatMoney(sessionBoxValue))
  print("----------------------------------------")
  print("Use '/pm rank' to see how you compare!")
end
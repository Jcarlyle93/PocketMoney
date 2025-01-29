PocketMoneyCore = {}
local ADDON_PREFIX = "PMRank"
local PocketMoney = CreateFrame("Frame")
local CTL = _G.ChatThrottleLib

-- Variable Initialisation 
local pendingLootSlots = {}
local MAX_JOIN_ATTEMPTS = 3
local joinAttempts = 0
local joinTimer = nil
local PREFERRED_CHANNEL = 9
local isPickpocketLoot = false
local lastProcessedMoney = nil
local lastProcessedItems = {}
local lastLootTime = 0
local sessionStartTime = GetServerTime()
local maxGoldPerHour = 100 * 10000
local pickpocketedBoxes = {}
local isOpeningJunkbox = false
local currentJunkboxType = nil
local PICKPOCKET_LOCKBOXES = {
  [16885] = "Heavy Junkbox",
  [16884] = "Sturdy Junkbox",
  [16882] = "Battered Junkbox",
  [16883] = "Worn Junkbox"
}

-- Global Vars
sessionGold = 0
sessionJunk = 0
sessionBoxValue = 0

-- Get Player Details
local realmName = GetRealmName()
local playerName = UnitName("player")
local _, playerClass = UnitClass("player")
local isRogue = playerClass == "ROGUE"
function PocketMoneyCore.GetCharacterGuild(Name)
  local guildName = GetGuildInfo(Name)
  return guildName or "NoGuild"
end

-- Database Initialisation
local CURRENT_DB_VERSION = 2.0

PocketMoneyDB = PocketMoneyDB or {}
PocketMoneyDB.AutoFlag = PocketMoneyDB.AutoFlag or false
PocketMoneyDB.UsePopoutDisplay  = PocketMoneyDB.UsePopoutDisplay or false
PocketMoneyDB.popoutPosition = PocketMoneyDB.popoutPosition or nil
PocketMoneyDB.tempData = PocketMoneyDB.tempData or {}
PocketMoneyDB.tempData.onlinePlayers = PocketMoneyDB.tempData.onlinePlayers or {}
PocketMoneyDB.dbVersion = PocketMoneyDB.dbVersion or CURRENT_DB_VERSION
PocketMoneyDB[realmName] = PocketMoneyDB[realmName] or {}
PocketMoneyDB[realmName].main = PocketMoneyDB[realmName].main or nil
PocketMoneyDB[realmName].knownRogues = PocketMoneyDB[realmName].knownRogues or {}
PocketMoneyCore.mainPC = PocketMoneyDB[realmName].main or nil

PocketMoneyDB[realmName][playerName] = PocketMoneyDB[realmName][playerName] or nil
if PocketMoneyCore.mainPC then
  PocketMoneyDB[realmName][PocketMoneyCore.mainPC].Alts[playerName] = PocketMoneyDB[realmName][PocketMoneyCore.mainPC].Alts[playerName]
end

if isRogue then
  if PocketMoneyDB[realmName][playerName] and PocketMoneyDB[realmName][PocketMoneyCore.mainPC].Alts[playerName] == nil then
    PocketMoneyDB[realmName][playerName] = PocketMoneyDB[realmName][playerName] or {
      lifetimeGold = 0,
      lifetimeJunk = 0,
      lifetimeBoxValue = 0,
      Guild = PocketMoneyCore.GetCharacterGuild(playerName),
      checksum = nil,
      class = playerClass
    }
    if PocketMoneyDB.AutoFlag and PocketMoneyDB[realmName].main then
      PocketMoneyCore.SetAsAlt(playerName)
    end
  end
end

local function UpgradeDatabase()
  if not PocketMoneyDB then
    print("Error: Database not initialized")
    return
  end
  local currentVersion = PocketMoneyDB.dbVersion
  local targetLocation
  if PocketMoneyCore.IsAltCharacter(playerName) then
    local mainChar = PocketMoneyDB[realmName][playerName].AltOf
    targetLocation = PocketMoneyDB[realmName][mainChar].Alts[playerName]
  else
    targetLocation = PocketMoneyDB[realmName][playerName]
  end
  if not targetLocation then
    print("Error: Database not initialized")
    return
  end
  if currentVersion < CURRENT_DB_VERSION then
    -- Latest Schema
    local schema = {
      lifetimeGold = 0,
      lifetimeJunk = 0,
      lifetimeBoxValue = 0,
      Guild = PocketMoneyCore.GetCharacterGuild(playerName),
      main = false,
      AltOf = nil,
      checksum = nil,
      class = playerClass,
    }

    -- Remove fields not in the schema
    for key in pairs(targetLocation) do
      if schema[key] == nil then
          targetLocation[key] = nil
      end
    end

    PocketMoneyRankings.AuditDB()
    print("UPGRADING DATABASE!")
    for key, defaultValue in pairs(schema) do
      targetLocation[key] = targetLocation[key] or defaultValue
    end
    PocketMoneyDB.dbVersion = CURRENT_DB_VERSION
  end
end

-- Helper Functions
local function debug(msg)
  DEFAULT_CHAT_FRAME:AddMessage("PCM Debug: " .. tostring(msg), 1, 1, 0)
end

function PocketMoneyCore.SendMessage(message, target)
  CTL:SendAddonMessage(
    "NORMAL",
    ADDON_PREFIX,
    message,
    "WHISPER",
    target
  )
end

PocketMoneyCore.IsAltCharacter = function(name)
  local mainPC = PocketMoneyDB[realmName].main
  if not mainPC or not PocketMoneyDB[realmName][mainPC] then
    return false
  end
  if not PocketMoneyDB[realmName][mainPC].Alts then
    PocketMoneyDB[realmName][mainPC].Alts = {}
  end
  return PocketMoneyDB[realmName][mainPC].Alts[name] ~= nil
end

PocketMoneyCore.GetPlayerGuild = function(playerName)
  local guildName
  if playerName then
    local name = playerName:match("([^-]+)")
    guildName = GetGuildInfo(name)
  end
  return guildName or "NoGuild"
end

local function updateChecksum(targetCharacter, altCharacter)
  if altCharacter then
    local gold = PocketMoneyDB[realmName][targetCharacter].Alts[altCharacter].lifetimeGold or 0
    local junk = PocketMoneyDB[realmName][targetCharacter].Alts[altCharacter].lifetimeJunk or 0
    PocketMoneyDB[realmName][targetCharacter].Alts[altCharacter].checksum = PocketMoneySecurity.generateChecksum(gold, junk)
  else
    PocketMoneyDB[realmName][targetCharacter].checksum = PocketMoneySecurity.generateChecksum(
      PocketMoneyDB[realmName][targetCharacter].lifetimeGold,
      PocketMoneyDB[realmName][targetCharacter].lifetimeJunk
    )
  end
end

local function FilterChannelMessages(_, event, ...)
  if event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHAT_MSG_CHANNEL_NOTICE_USER" then
    local channelType = select(4, ...)
    if channelType == PocketMoneyCore.CHANNEL_NAME then
      return true
    end
  end
  if event == "CHAT_MSG_SYSTEM" then
    local message = ...
    if message and message:find(PocketMoneyCore.CHANNEL_NAME) then
      return true
    end
  end
  return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", FilterChannelMessages)
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE_USER", FilterChannelMessages)

-- Managing Alts
function PocketMoneyCore.SetAsAlt(characterName)
  if not characterName then characterName = playerName end
  
  if not isRogue then
    return false
  end
  
  if not PocketMoneyDB[realmName].main then
    return false
  end
  
  if characterName == PocketMoneyDB[realmName].main then
    return false
  end

  PocketMoneyDB[realmName][characterName].AltOf = PocketMoneyDB[realmName].main
  PocketMoneyRankings.AuditDB()
  print("Set " .. characterName .. " as alt of " .. PocketMoneyDB[realmName].main)
  return true
end

function PocketMoneyCore.RemoveAlt(characterName)
  if not characterName then characterName = playerName end
  
  if not PocketMoneyCore.IsAltCharacter(characterName) then
    return false
  end
  
  local mainChar = PocketMoneyDB[realmName].main
  if PocketMoneyDB[realmName][mainChar] and 
     PocketMoneyDB[realmName][mainChar].Alts and 
     PocketMoneyDB[realmName][mainChar].Alts[characterName] then
    PocketMoneyDB[realmName][mainChar].Alts[characterName] = nil
  end
  
  if PocketMoneyDB[realmName][characterName] then
    PocketMoneyDB[realmName][characterName].AltOf = nil
  end
  
  PocketMoneyRankings.AuditDB()
  print("Removed " .. characterName .. " as alt")
  return true
end

local function TransferAlts(oldMain, newMain)
  if PocketMoneyDB[realmName][oldMain] and PocketMoneyDB[realmName][oldMain].Alts then
    PocketMoneyDB[realmName][newMain].Alts = PocketMoneyDB[realmName][newMain].Alts or {}
    for altName, altData in pairs(PocketMoneyDB[realmName][oldMain].Alts) do
      PocketMoneyDB[realmName][newMain].Alts[altName] = altData
      altData.AltOf = newMain
    end   
    PocketMoneyDB[realmName][oldMain].Alts = {}
    PocketMoneyDB[realmName][oldMain].main = false
    print("Transferred alts from " .. oldMain .. " to " .. newMain)
  end
end

-- Manage Main Character Change!
function PocketMoneyCore.SetNewMain(newMainName)
  if not newMainName or not PocketMoneyDB[realmName][newMainName] then
    return false, "Invalid character name"
  end

  -- Temporary storage for alts
  local tempAltHolder = {}
  local currentMain = PocketMoneyDB[realmName].main

  -- Step 1: Store current alts if there's a main
  if currentMain and PocketMoneyDB[realmName][currentMain] then
    if PocketMoneyDB[realmName][currentMain].Alts then
      for altName, altData in pairs(PocketMoneyDB[realmName][currentMain].Alts) do
        tempAltHolder[altName] = altData
      end
      -- Clear the alts table from current main
      PocketMoneyDB[realmName][currentMain].Alts = nil
    end

    -- Step 2: Convert current main to alt
    PocketMoneyDB[realmName][currentMain].main = false
    PocketMoneyDB[realmName][currentMain].AltOf = newMainName
    tempAltHolder[currentMain] = PocketMoneyDB[realmName][currentMain]
  end

  -- Step 3: Handle new main if it was an alt
  if tempAltHolder[newMainName] then
    local newMainData = PocketMoneyDB[realmName][newMainName]
    newMainData.AltOf = nil
    tempAltHolder[newMainName] = nil
  end

  -- Step 4: Set up new main
  PocketMoneyDB[realmName].main = newMainName
  PocketMoneyDB[realmName][newMainName].main = true
  PocketMoneyDB[realmName][newMainName].Alts = {}

  -- Step 5: Move alts to new main
  for altName, altData in pairs(tempAltHolder) do
    PocketMoneyDB[realmName][newMainName].Alts[altName] = altData
    altData.AltOf = newMainName
  end

  wipe(tempAltHolder)
  PocketMoneyRankings.AuditDB()
  PocketMoneyRankings.BroadcastMainChange(currentMain, newMainName)
  return true, "Successfully set " .. newMainName .. " as main character"
end

-- Chat Channel Initialisation
PocketMoneyCore.CHANNEL_PASSWORD = "pm" .. GetRealmName()
PocketMoneyCore.CHANNEL_NAME = "PCMSync"

PocketMoneyCore.attemptChannelJoin = function()
  if joinAttempts >= MAX_JOIN_ATTEMPTS then
    debug("Failed to join after " .. MAX_JOIN_ATTEMPTS .. " attempts")
     return
  end
  joinAttempts = joinAttempts + 1

  if GetChannelName(PocketMoneyCore.CHANNEL_NAME) > 0 then
    LeaveChannelByName(PocketMoneyCore.CHANNEL_NAME)
    C_Timer.After(5, function()
      JoinChannelByName(PocketMoneyCore.CHANNEL_NAME, PocketMoneyCore.CHANNEL_PASSWORD)
      local id = GetChannelName(PocketMoneyCore.CHANNEL_NAME)
      if id > 0 then
        ChatFrame_RemoveChannel(DEFAULT_CHAT_FRAME, PocketMoneyCore.CHANNEL_NAME)
        for i=1, NUM_CHAT_WINDOWS do
          local frame = _G["ChatFrame"..i]
          if frame then
            ChatFrame_RemoveChannel(frame, PocketMoneyCore.CHANNEL_NAME)
          end
        end
      end
    end)
  else
    JoinChannelByName(PocketMoneyCore.CHANNEL_NAME, PocketMoneyCore.CHANNEL_PASSWORD)
    C_Timer.After(0.5, function()
      local id = GetChannelName(PocketMoneyCore.CHANNEL_NAME)
      if id > 0 then
        ChatFrame_RemoveChannel(DEFAULT_CHAT_FRAME, PocketMoneyCore.CHANNEL_NAME)
        for i=1, NUM_CHAT_WINDOWS do
          local frame = _G["ChatFrame"..i]
          if frame then
            ChatFrame_RemoveChannel(frame, PocketMoneyCore.CHANNEL_NAME)
          end
        end
      end
    end)
  end

  joinTimer = C_Timer.NewTimer(10, function()
    local channel_num = GetChannelName(PocketMoneyCore.CHANNEL_NAME)
      
    if channel_num == 0 then
      CHANNEL_NAME = CHANNEL_NAME .. "b"
      PocketMoneyCore.attemptChannelJoin()
    else
      if channel_num ~= PREFERRED_CHANNEL then
        JoinChannelByName(PocketMoneyCore.CHANNEL_NAME, PocketMoneyCore.CHANNEL_PASSWORD, true, PocketMoneyCore.PREFERRED_CHANNEL)
      end
    end
  end)
end

local function checkChannelStatus()
  return GetChannelName(PocketMoneyCore.CHANNEL_NAME) ~= 0
end

-- Formatting Values
function PocketMoneyCore.FormatMoney(copper)
  if not copper or type(copper) ~= "number" then
    return "0c"
  end

  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local copperRem = copper % 100
  local str = ""
  if gold > 0 then str = str .. "|cFFFFD700" .. gold .. "g|r " end
  if silver > 0 or gold > 0 then str = str .. "|cFFC0C0C0" .. silver .. "s|r " end
  str = str .. "|cFFB87333" .. copperRem .. "c|r"
  
  return str
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

-- Managing PP Value updates
local function ProcessPickpocketLoot(lootSlotType, itemLink, item, quantity)
  local targetCharacter = playerName
  local isAlt = PocketMoneyDB[realmName][playerName].AltOf
  
  if isAlt then
    targetCharacter = PocketMoneyDB[realmName][playerName].AltOf
  end

  if lootSlotType == 1 then
    if itemLink and not lastProcessedItems[itemLink] then
      local itemID = GetItemInfoInstant(itemLink)
      local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
      if PICKPOCKET_LOCKBOXES[itemID] then
        lastProcessedItems[itemLink] = true
      elseif itemSellPrice then
        local totalValue = itemSellPrice * (quantity or 1)
        sessionJunk = sessionJunk + totalValue
        
        if isAlt then
          PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeJunk = 
            (PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeJunk or 0) + totalValue
        else
          PocketMoneyDB[realmName][playerName].lifetimeJunk = 
            PocketMoneyDB[realmName][playerName].lifetimeJunk + totalValue
        end
        
        lastProcessedItems[itemLink] = true
      end
    end
  elseif lootSlotType == 2 then
    if item and item ~= lastProcessedMoney then
      local copper = parseMoneyString(item)
      sessionGold = sessionGold + copper
      
      if isAlt then
        PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeGold = 
          (PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeGold or 0) + copper
      else
        PocketMoneyDB[realmName][playerName].lifetimeGold = PocketMoneyDB[realmName][playerName].lifetimeGold + copper
      end
      
      lastProcessedMoney = item
    end
  end

  if isAlt then
    updateChecksum(targetCharacter, playerName)
  else 
    updateChecksum(playerName)
  end
end

local function updateBoxValue(value, debug_source)
  sessionBoxValue = sessionBoxValue + value
  local targetCharacter = playerName
  local isAlt = PocketMoneyDB[realmName][playerName].AltOf
  
  if isAlt then
    targetCharacter = PocketMoneyDB[realmName][playerName].AltOf
    PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeBoxValue = 
      (PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeBoxValue or 0) + value
  else
    PocketMoneyDB[realmName][playerName].lifetimeBoxValue = 
      PocketMoneyDB[realmName][playerName].lifetimeBoxValue + value
  end
end

local function ProcessJunkboxLoot(lootSlotType, itemLink, item, quantity)
  if not isOpeningJunkbox or not currentJunkboxType then
    return
  end
 
  local targetCharacter = playerName
  local isAlt = PocketMoneyDB[realmName][playerName].AltOf
  if isAlt then
    targetCharacter = PocketMoneyDB[realmName][playerName].AltOf
  end
 
  if lootSlotType == 1 then
    if itemLink and not lastProcessedItems[itemLink] then
      local itemID = GetItemInfoInstant(itemLink)
      local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
      
      if itemSellPrice then
        local totalValue = itemSellPrice * (quantity or 1)
        if isAlt then
          PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeBoxValue = 
            (PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeBoxValue or 0) + totalValue
        else
          PocketMoneyDB[realmName][playerName].lifetimeBoxValue = 
            PocketMoneyDB[realmName][playerName].lifetimeBoxValue + totalValue
        end
        sessionBoxValue = sessionBoxValue + totalValue
        lastProcessedItems[itemLink] = true
      end
    end
  elseif lootSlotType == 2 then
    if item and item ~= lastProcessedMoney then
      local copper = parseMoneyString(item)
      if copper > 0 then
        if isAlt then
          PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeBoxValue = 
            (PocketMoneyDB[realmName][targetCharacter].Alts[playerName].lifetimeBoxValue or 0) + copper
        else
          PocketMoneyDB[realmName][playerName].lifetimeBoxValue = 
            PocketMoneyDB[realmName][playerName].lifetimeBoxValue + copper
        end
        sessionBoxValue = sessionBoxValue + copper
        lastProcessedMoney = item
      end
    end
  end
 
  if isAlt then
    updateChecksum(targetCharacter, playerName)
  else 
    updateChecksum(playerName)
  end
end

-- Event Registration
PocketMoney:RegisterEvent("ADDON_LOADED")
PocketMoney:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
PocketMoney:RegisterEvent("LOOT_READY")
PocketMoney:RegisterEvent("LOOT_OPENED")
PocketMoney:RegisterEvent("LOOT_SLOT_CLEARED")
PocketMoney:RegisterEvent("LOOT_CLOSED")
PocketMoney:RegisterEvent("CHAT_MSG_SYSTEM")

PocketMoney:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
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
C_Timer.NewTicker(30, function()
  if not checkChannelStatus() then
    debug("Channel join failed - attempting rejoin")
    PocketMoneyCore.attemptChannelJoin()
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
  elseif msg == "setmain" then
    if not isRogue then
      print("Only rogues can be set as a main!")
      return
    end
    if PocketMoneyDB[realmName][playerName].AltOf then
      print("Alt characters cannot be set as main!")
      return
    end
    if PocketMoneyDB[realmName].main then
      local currentMain = PocketMoneyDB[realmName].main
      TransferAlts(currentMain, playerName)
    else
      PocketMoneyDB[realmName].main = playerName
      PocketMoneyDB[realmName][playerName].main = true
    end
    print("Set " .. playerName .. " as your main character.")
    return
  elseif msg == "setalt" then
    if not isRogue then
      print("Only rogues can be set as alts!")
      return
    end
    if not PocketMoneyDB[realmName].main then
      print("No main character set - use /pm setmain first!")
      return
    end
    if playerName == PocketMoneyDB[realmName].main then
      print("Can't set a main as an alt!")
      return
    end
    PocketMoneyDB[realmName][playerName].AltOf = PocketMoneyDB[realmName].main
    PocketMoneyRankings.AuditDB()
    print("Set " .. playerName .. " as alt of " .. PocketMoneyDB[realmName].main)
    PocketMoneyRankings.AuditDB()
    return
  elseif msg == "help" then
    print("Pocket Money Commands:")
    print("  /pm - Show current statistics")
    print("  /pm rankings - Show rankings")
    print("  /pm setmain - Set current character as main")
    print("  /pm setalt - Set current character as alt of main")
    print("  /pm clear - Reset all statistics")
    return
  elseif msg == "audit" then
    PocketMoneyRankings.AuditDB()
    return
  end
  if not isRogue then
    print("You're not a rogue!")
    return
  end
  local statsData
  if PocketMoneyCore.IsAltCharacter(playerName) then
      local mainChar = PocketMoneyDB[realmName][playerName].AltOf
      statsData = PocketMoneyDB[realmName][mainChar].Alts[playerName]
  else
      statsData = PocketMoneyDB[realmName][playerName]
  end

  if PocketMoneyDB.UsePopoutDisplay then
    PocketMoneyPopoutUI.Toggle()
    return
  else
    print("----------------------------------------")
    print("|cFF9370DB[Lifetime]|r:")
    print("  Raw Gold: " .. PocketMoneyCore.FormatMoney(statsData.lifetimeGold))
    print("  Junk Items: " .. PocketMoneyCore.FormatMoney(statsData.lifetimeJunk))
    print("  Junk Box Value: " .. PocketMoneyCore.FormatMoney(statsData.lifetimeBoxValue))
    print("|cFF00FF00[Session]|r:")
    print("  Raw Gold: " .. PocketMoneyCore.FormatMoney(sessionGold))
    print("  Junk Items: " .. PocketMoneyCore.FormatMoney(sessionJunk))
    print("  Junk Box Value: " .. PocketMoneyCore.FormatMoney(sessionBoxValue))
    print("----------------------------------------")
    print("Use '/pm rank' to see how you compare!")
  end
end
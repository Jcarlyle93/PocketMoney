local PocketMoney = CreateFrame("Frame")
PocketMoney:RegisterEvent("ADDON_LOADED")
PocketMoney:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
PocketMoney:RegisterEvent("LOOT_READY")

local function debug(msg)
  print("PCM Debug: " .. tostring(msg))
end

PocketMoneyDB = PocketMoneyDB or {
  lifetimeGold = 0,
  lifetimeJunk = 0,
  checksum = nil
}

local sessionGold = 0
local sessionJunk = 0
local isPickpocketLoot = false
local lastProcessedMoney = nil
local lastProcessedItems = {}
local lastLootTime = 0
local sessionStartTime = GetServerTime()
local maxGoldPerHour = 100 * 10000 

local function updateValues(gold, junk)
  PocketMoneyDB.lifetimeGold = gold
  PocketMoneyDB.lifetimeJunk = junk
  PocketMoneyDB.checksum = Security.generateChecksum(gold, junk)
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

PocketMoney:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
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

  elseif event == "LOOT_READY" and isPickpocketLoot then
    local currentTime = GetTime()
    if currentTime - lastLootTime < 0.1 then
      return
    end
    lastLootTime = currentTime

    local numItems = GetNumLootItems()
 
    for i = 1, numItems do
      local lootSlotType = GetLootSlotType(i)
      local itemLink = GetLootSlotLink(i)
      local _, item, quantity = GetLootSlotInfo(i)
      
      if lootSlotType == 1 then
        if itemLink and not lastProcessedItems[itemLink] then
          local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
          if itemSellPrice then
            local totalValue = itemSellPrice * (quantity or 1)
            sessionJunk = sessionJunk + totalValue
            PocketMoneyDB.lifetimeJunk = PocketMoneyDB.lifetimeJunk + totalValue
            lastProcessedItems[itemLink] = true
          end
        end
      elseif lootSlotType == 2 then
        if item and item ~= lastProcessedMoney then
          local copper = parseMoneyString(item)
          sessionGold = sessionGold + copper
          PocketMoneyDB.lifetimeGold = PocketMoneyDB.lifetimeGold + copper
          lastProcessedMoney = item

          PocketMoneyDB.guildRankings = PocketMoneyDB.guildRankings or {}
          PocketMoneyDB.guildRankings[UnitName("player")] = {
            gold = PocketMoneyDB.lifetimeGold,
            timestamp = GetServerTime()
          }
        end
      end
    end
  end
end)

PocketMoneyCore = {}  -- Create core table

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

-- Modify the slash command to handle rankings
SLASH_POCKETMONEY1 = "/pm"
SlashCmdList["POCKETMONEY"] = function(msg)
  if msg == "clear" then
    PocketMoneyDB.lifetimeGold = 0
    PocketMoneyDB.lifetimeJunk = 0
    sessionGold = 0
    sessionJunk = 0
    PocketMoneyDB.checksum = PocketMoneySecurity.generateChecksum(0, 0)
    print("Pocket Money: All statistics cleared!")
    return
  elseif msg == "rankings" or msg == "rank" then
    PocketMoneyRankings.ToggleUI()
    return
  elseif msg == "testrank" then
    -- Add fake data
    PocketMoneyDB.guildRankings = PocketMoneyDB.guildRankings or {}
    PocketMoneyDB.guildRankings["Stabby"] = {
        gold = 250000,  -- 25g
        timestamp = GetServerTime()
    }
    PocketMoneyDB.guildRankings["Sneakster"] = {
        gold = 100000,  -- 10g
        timestamp = GetServerTime()
    }
    PocketMoneyDB.guildRankings["ShadowBlade"] = {
        gold = 500000,  -- 50g
        timestamp = GetServerTime()
    }
    PocketMoneyDB.guildRankings["PocketPicker"] = {
        gold = 150000,  -- 15g
        timestamp = GetServerTime()
    }
    print("Added test ranking data")
    PocketMoneyRankings.ToggleUI()
    return
  elseif msg == "help" then
    print("Pocket Money Commands:")
    print("  /pm - Show current statistics")
    print("  /pm rankings - Show guild rankings")
    print("  /pm clear - Reset all statistics")
    return
  end

  print("----------------------------------------")
  print("|cFF9370DB[Lifetime]|r:")
  print("  Raw Gold: " .. PocketMoneyCore.FormatMoney(PocketMoneyDB.lifetimeGold))
  print("  Junk Items: " .. PocketMoneyCore.FormatMoney(PocketMoneyDB.lifetimeJunk))
  print("|cFF00FF00[Session]|r:")
  print("  Raw Gold: " .. PocketMoneyCore.FormatMoney(sessionGold))
  print("  Junk Items: " .. PocketMoneyCore.FormatMoney(sessionJunk))
  print("----------------------------------------")
end
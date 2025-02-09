PocketMoneySecurity = {}

function PocketMoneySecurity.generateSalt()
  local playerGUID = UnitGUID("player")
  local realmName = GetRealmName()
  local characterName = UnitName("player")
  local characterLevel = UnitLevel("player")
  local baseString = "PM" .. playerGUID .. realmName .. characterName .. characterLevel
  local complexSalt = ""
  local reversed = string.reverse(baseString)
  
  for i = 1, #baseString do
    if i % 2 == 0 then
      complexSalt = complexSalt .. string.sub(baseString, i, i)
    else
      complexSalt = complexSalt .. string.sub(reversed, i, i)
    end
  end
  
  return complexSalt
end

function PocketMoneySecurity.generateChecksum(gold, junk)
  local salt = PocketMoneySecurity.generateSalt()
  local combined = gold .. ":" .. junk .. ":" .. salt
  local hash = 5381
  for i = 1, #combined do
    hash = ((hash * 33) + string.byte(combined, i)) % 4294967296
  end
  
  return {
    hash = tostring(hash),
    salt = salt
  }
end

function PocketMoneySecurity.verifyIntegrity(gold, junk, storedChecksum)
  if not storedChecksum or not storedChecksum.hash or not storedChecksum.salt then
    return false
  end
  
  local combined = gold .. ":" .. junk .. ":" .. storedChecksum.salt
  local hash = 5381
  for i = 1, #combined do
    hash = ((hash * 33) + string.byte(combined, i)) % 4294967296
  end
  
  return tostring(hash) == storedChecksum.hash
end

function PocketMoneySecurity.logTransaction(realmName, playerName, amount, type, timestamp)
  local realmData = PocketMoneyDB[realmName] or {}
  realmData.transactions = realmData.transactions or {}
  table.insert(realmData.transactions, {
    amount = amount,
    type = type,
    timestamp = timestamp,
    player = playerName,
    playerLevel = UnitLevel("player"),
    zone = GetRealZoneText()
  })
end
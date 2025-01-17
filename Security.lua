PocketMoneySecurity = {}

function PocketMoneySecurity.generateSalt()
  local serverTime = GetServerTime()
  local playerGUID = UnitGUID("player")
  local realmName = GetRealmName()
  local characterName = UnitName("player")
  local characterLevel = UnitLevel("player")
  local baseString = "PM" .. playerGUID .. realmName .. characterName .. characterLevel .. serverTime
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
  return LibStub("SHA256-1.0"):Hash(combined)
end

function PocketMoneySecurity.verifyIntegrity(gold, junk, checksum)
  local currentChecksum = PocketMoneySecurity.generateChecksum(gold, junk)
  return currentChecksum == checksum
end

function PocketMoneySecurity.logTransaction(amount, type, timestamp)
  PocketMoneyDB.transactions = PocketMoneyDB.transactions or {}
  table.insert(PocketMoneyDB.transactions, {
    amount = amount,
    type = type,
    timestamp = timestamp,
    playerLevel = UnitLevel("player"),
    zone = GetRealZoneText()
  })
end
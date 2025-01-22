-- AchievementGenerator.lua
local json = require("json")  -- You'll need a Lua JSON lib for local testing

-- More secure encryption function
local function Encrypt(data)
    local result = ""
    -- Use a more complex key
    local key = "YourComplexKey123!@#" -- We should make this more secure
    
    -- Convert achievement data to string
    local dataString = json.encode(data)
    
    -- More complex encryption (This is still simple, but better than plain XOR)
    for i = 1, #dataString do
        local byte = string.byte(dataString, i)
        local keyByte = string.byte(key, ((i-1) % #key) + 1)
        local salt = (i * 13) % 256  -- Add some salt
        result = result .. string.char(bit.bxor(bit.bxor(byte, keyByte), salt))
    end
    
    return result
end

local function GenerateDatabase()
    -- Read the achievements.json file
    local file = io.open("achievements.json", "r")
    local content = file:read("*all")
    file:close()
    
    local data = json.decode(content)
    local encryptedDB = {}
    
    -- Encrypt each achievement
    for _, achievement in ipairs(data.achievements) do
        encryptedDB[achievement.id] = Encrypt(achievement)
    end
    
    -- Generate the Lua file
    local output = io.open("EncryptedAchievements.lua", "w")
    
    -- Write the file header
    output:write("-- This file is auto-generated. Do not edit manually!\n\n")
    output:write("PocketMoneyEncryptedAchievements = {\n")
    
    -- Write each encrypted achievement
    for id, encrypted in pairs(encryptedDB) do
        output:write(string.format('    ["%s"] = "%s",\n', id, encrypted))
    end
    
    output:write("}\n\n")
    
    -- Add the decryption function
    output:write([[
local function Decrypt(encryptedData)
    local result = ""
    local key = "YourComplexKey123!@#"  -- Must match encryption key
    
    for i = 1, #encryptedData do
        local byte = string.byte(encryptedData, i)
        local keyByte = string.byte(key, ((i-1) % #key) + 1)
        local salt = (i * 13) % 256
        result = result .. string.char(bit.bxor(bit.bxor(byte, keyByte), salt))
    end
    
    return json.decode(result)
end

-- Decrypt achievements on load
for id, encrypted in pairs(PocketMoneyEncryptedAchievements) do
    PocketMoneyEncryptedAchievements[id] = Decrypt(encrypted)
end
]])
    
    output:close()
end

-- Run the generator
GenerateDatabase()
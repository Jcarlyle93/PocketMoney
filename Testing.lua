-- Testing.lua
-- Advanced testing for PocketMoney addon rankings system

local function generateTestPlayerData(playerName)
    local testData = {
        type = "PLAYER_UPDATE",
        player = playerName,
        realm = GetRealmName(),
        gold = math.random(100, 10000),
        junk = math.random(50, 5000),
        boxValue = math.random(25, 2500),
        guild = "Test Guild",
        timestamp = GetServerTime(),
        main = true,
        Alts = {}
    }

    -- Generate some alt data
    local numAlts = math.random(0, 3)
    for i = 1, numAlts do
        local altName = playerName .. "Alt" .. i
        testData.Alts[altName] = {
            gold = math.random(10, 1000),
            junk = math.random(5, 500),
            boxValue = math.random(5, 250),
            AltOf = playerName
        }
    end

    return testData
end

local function simulateRankingsUpdate()
    print("Starting Rankings Update Simulation...")
    
    -- Generate test data for multiple players
    local testPlayers = {
        "Rogue1",
        "Rogue2",
        "Rogue3",
        "Rogue4",
        "Rogue5"
    }

    local LibSerialize = LibStub("LibSerialize")
    local realmName = GetRealmName()

    -- Clear existing known rogues
    PocketMoneyDB[realmName].knownRogues = {}

    for _, playerName in ipairs(testPlayers) do
        local testData = generateTestPlayerData(playerName)
        
        -- Serialize the test data
        local success, serialized = pcall(function() 
            return LibSerialize:Serialize(testData) 
        end)

        if success then
            -- Simulate chunking for larger messages
            if #serialized > 255 then
                local chunks = {}
                local messageLen = #serialized
                local numChunks = math.ceil(messageLen / 250)
                
                for i = 1, numChunks do
                    local start = (i-1) * 250 + 1
                    local chunk = serialized:sub(start, start + 249)
                    chunk = string.format("CHUNK:%d:%d:", i, numChunks) .. chunk
                    table.insert(chunks, chunk)
                end

                print(string.format("Player %s: Generated %d chunks", playerName, numChunks))

                -- Simulate processing chunked message
                local fullMessage = ""
                for _, chunk in ipairs(chunks) do
                    local isChunk, chunkNum, totalChunks, message = chunk:match("^CHUNK:(%d+):(%d+):(.+)$")
                    fullMessage = fullMessage .. message
                end

                -- Deserialize and process
                local success, messageData = pcall(function() 
                    local decoded, result = LibSerialize:Deserialize(fullMessage)
                    return result
                end)

                if success then
                    PocketMoneyRankings.ProcessUpdate(playerName, messageData)
                else
                    print("Deserialization failed for " .. playerName)
                end
            else
                -- Process non-chunked message
                PocketMoneyRankings.ProcessUpdate(playerName, testData)
            end
        else
            print("Serialization failed for " .. playerName)
        end
    end

    -- Trigger UI update to show results
    PocketMoneyRankings.UpdateUI()
    
    print("Rankings Update Simulation Complete.")
    print("Total Known Rogues: " .. table.getn(PocketMoneyDB[realmName].knownRogues))
end

local function verifyRankingsData()
    local realmName = GetRealmName()
    print("Verifying Rankings Data...")
    
    if not PocketMoneyDB[realmName].knownRogues then
        print("No known rogues found.")
        return
    end

    print("Known Rogues Breakdown:")
    for rogueName, rogueData in pairs(PocketMoneyDB[realmName].knownRogues) do
        print(string.format("Rogue: %s", rogueName))
        print(string.format("  Gold: %d", rogueData.gold or 0))
        print(string.format("  Junk: %d", rogueData.junk or 0))
        print(string.format("  Box Value: %d", rogueData.boxValue or 0))
        
        if rogueData.Alts and next(rogueData.Alts) then
            print("  Alts:")
            for altName, altData in pairs(rogueData.Alts) do
                print(string.format("    Alt: %s", altName))
                print(string.format("      Gold: %d", altData.gold or 0))
                print(string.format("      Junk: %d", altData.junk or 0))
                print(string.format("      Box Value: %d", altData.boxValue or 0))
            end
        end
    end
end

local function cleanupTestRogues()
    local realmName = GetRealmName()
    print("Cleaning up test rogues...")
    
    -- Remove test rogues from knownRogues
    local testPlayers = {
        "Rogue1",
        "Rogue2",
        "Rogue3",
        "Rogue4",
        "Rogue5"
    }

    for _, playerName in ipairs(testPlayers) do
        if PocketMoneyDB[realmName].knownRogues[playerName] then
            PocketMoneyDB[realmName].knownRogues[playerName] = nil
            print("Removed " .. playerName)
        end

        -- Remove potential alt entries
        for altName in pairs(PocketMoneyDB[realmName].knownRogues) do
            if altName:match("^" .. playerName .. "Alt") then
                PocketMoneyDB[realmName].knownRogues[altName] = nil
                print("Removed alt " .. altName)
            end
        end
    end

    -- Trigger UI update to reflect changes
    PocketMoneyRankings.UpdateUI()
    
    print("Test rogues cleanup complete.")
end

SLASH_PMTEST1 = "/pmtest"
SlashCmdList["PMTEST"] = function(msg)
    if msg == "update" then
        simulateRankingsUpdate()
    elseif msg == "verify" then
        verifyRankingsData()
    elseif msg == "cleanup" then
        cleanupTestRogues()
    else
        print("PocketMoney Test Commands:")
        print("  /pmtest update - Simulate rankings update")
        print("  /pmtest verify - Verify rankings data")
        print("  /pmtest cleanup - Remove test rogues")
    end
end
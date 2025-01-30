-- Testing.lua
-- Test functions for PocketMoney addon
-- Do not release

SLASH_PMTEST1 = "/pmtest"
SlashCmdList["PMTEST"] = function()
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    
    -- Setup test data request
    print("Starting self-test sequence...")
    
    -- Clear any existing test data
    if PocketMoneyDB[realmName].knownRogues["TESTDATA"] then
        PocketMoneyDB[realmName].knownRogues["TESTDATA"] = nil
    end
    
    -- Send a request to ourselves
    print("Sending data request to self...")
    PocketMoneyRankings.RequestLatestData(playerName)
    
    -- Set a timer to check if data was saved
    C_Timer.After(1, function()
        print("Checking if data was processed...")
        
        -- Check if our data exists in knownRogues
        if PocketMoneyDB[realmName].knownRogues[playerName] then
            print("Test SUCCESS: Found player data in knownRogues")
            print("Data received:")
            print("  Gold:", PocketMoneyDB[realmName].knownRogues[playerName].gold)
            print("  Junk:", PocketMoneyDB[realmName].knownRogues[playerName].junk)
            print("  Box Value:", PocketMoneyDB[realmName].knownRogues[playerName].boxValue)
        else
            print("Test FAILED: No data found in knownRogues")
        end
        
        -- Clean up test data
        print("Cleaning up test data...")
        if PocketMoneyDB[realmName].knownRogues["TESTDATA"] then
            PocketMoneyDB[realmName].knownRogues["TESTDATA"] = nil
        end
    end)
end
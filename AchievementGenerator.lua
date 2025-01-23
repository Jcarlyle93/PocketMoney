-- AchievementGenerator.lua
local function GenerateDatabase()
    local output = io.open("EncryptedAchievements.lua", "w")
    
    output:write([[
 -- This file is auto-generated. Do not edit manually!
 PocketMoneyEncryptedAchievements = {
 ]])
    
    local achievements = {
        ["PICKPOCKET_100"] = {
            name = "Amateur Thief",
            description = "Pickpocket 100 targets.",
            points = 10,
            icon = 921,
            criteria = {type = "PICKPOCKET_COUNT", count = 100}
        },
        ["PICKPOCKET_1000"] = {
            name = "Professional Pickpocket",
            description = "Pickpocket 1,000 targets. You're getting good at this!",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_COUNT", count = 1000}
        },
        ["PICKPOCKET_5000"] = {
            name = "Master of Coin",
            description = "Pickpocket 5,000 targets. Your fingers have grown nimble indeed.",
            points = 50,
            icon = 921,
            criteria = {type = "PICKPOCKET_COUNT", count = 5000}
        },
        ["PICKPOCKET_9001"] = {
            name = "It's Over 9000!",
            description = "Pickpocket 9,001 targets. Your power level... it's incredible!",
            points = 100,
            icon = 921,
            criteria = {type = "PICKPOCKET_COUNT", count = 9001}
        },
        ["JUNKBOX_10"] = {
            name = "Boxed In",
            description = "Successfully pick open 10 Junkboxes.",
            points = 10,
            icon = 16885,
            criteria = {type = "JUNKBOX_OPEN", count = 10}
        },
        ["JUNKBOX_100"] = {
            name = "Box Collector",
            description = "Successfully pick open 100 Junkboxes. What treasures await?",
            points = 25,
            icon = 16885,
            criteria = {type = "JUNKBOX_OPEN", count = 100}
        },
        ["JUNKBOX_500"] = {
            name = "Master Locksmith",
            description = "Successfully pick open 500 Junkboxes. You could do this in your sleep!",
            points = 50,
            icon = 16885,
            criteria = {type = "JUNKBOX_OPEN", count = 500}
        },
        ["JUNKBOX_1000"] = {
            name = "Grand Master of Locks",
            description = "Successfully pick open 1,000 Junkboxes. No lock can resist your skill!",
            points = 100,
            icon = 16885,
            criteria = {type = "JUNKBOX_OPEN", count = 1000}
        },
        ["RAID_ZG_JEKLIK"] = {
            name = "High Priestess's Pockets",
            description = "Successfully pickpocket High Priestess Jeklik in Zul'Gurub.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_BOSS", npcID = 14517, count = 1}
        },
        ["RAID_ZG_VENOXIS"] = {
            name = "Snake Charmer",
            description = "Successfully pickpocket High Priest Venoxis in Zul'Gurub.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_BOSS", npcID = 14507, count = 1}
        },
        ["RAID_ZG_MARLI"] = {
            name = "Spider's Purse",
            description = "Successfully pickpocket High Priestess Mar'li in Zul'Gurub.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_BOSS", npcID = 14510, count = 1}
        },
        ["RAID_ZG_THEKAL"] = {
            name = "Tiger's Treasury",
            description = "Successfully pickpocket High Priest Thekal in Zul'Gurub.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_BOSS", npcID = 14509, count = 1}
        },
        ["RAID_ZG_ARLOKK"] = {
            name = "Panther's Pockets",
            description = "Successfully pickpocket High Priestess Arlokk in Zul'Gurub.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_BOSS", npcID = 14515, count = 1}
        },
        ["RAID_NAXX_RAZUVIOUS"] = {
            name = "Instructor's Instruction",
            description = "Successfully pickpocket Instructor Razuvious in Naxxramas.",
            points = 50,
            icon = 921,
            criteria = {type = "PICKPOCKET_BOSS", npcID = 16061, count = 1}
        },
        ["RAID_NAXX_GOTHIK"] = {
            name = "Harvester's Hoard",
            description = "Successfully pickpocket Gothik the Harvester in Naxxramas.",
            points = 50,
            icon = 921,
            criteria = {type = "PICKPOCKET_BOSS", npcID = 16060, count = 1}
        },
        ["RAID_ZG_MASTER"] = {
            name = "Zul'Gurub Master Thief",
            description = "Successfully pickpocket all possible bosses in Zul'Gurub.",
            points = 100,
            icon = 921,
            criteria = {type = "PICKPOCKET_RAID_COMPLETE", raid = "ZG", requiredBosses = {14517, 14507, 14510, 14509, 14515}}
        },
        ["RAID_NAXX_MASTER"] = {
            name = "Death's Pickpocket",
            description = "Successfully pickpocket all possible bosses in Naxxramas.",
            points = 100,
            icon = 921,
            criteria = {type = "PICKPOCKET_RAID_COMPLETE", raid = "NAXX", requiredBosses = {16061, 16060}}
        },
        ["DUNGEON_RFC_ALL"] = {
            name = "Ragefire Robber",
            description = "Pickpocket all possible bosses in Ragefire Chasm.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "RFC", requiredBosses = {11517, 11520}}
        },
        ["DUNGEON_WC_ALL"] = {
            name = "Wailing Caverns Bandit",
            description = "Pickpocket all possible bosses in Wailing Caverns.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "WC", requiredBosses = {3673, 3669}}
        },
        ["DUNGEON_DM_ALL"] = {
            name = "Deadmines Pickpocket",
            description = "Pickpocket all possible bosses in The Deadmines.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "DM", requiredBosses = {639, 3586, 642, 645}}
        },
        ["DUNGEON_SFK_ALL"] = {
            name = "Shadowfang Thief",
            description = "Pickpocket all possible bosses in Shadowfang Keep.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "SFK", requiredBosses = {3887, 3886, 4278, 3914}}
        },
        ["DUNGEON_BFD_ALL"] = {
            name = "Blackfathom Burglar",
            description = "Pickpocket all possible bosses in Blackfathom Deeps.",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "BFD", requiredBosses = {4887, 4831}}
        },
        ["DUNGEON_STOCKS_ALL"] = {
            name = "Stockades Swindler",
            description = "Pickpocket all possible bosses in The Stockades",
            points = 25,
            icon = 921,
            criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "STOCKS", requiredBosses = {1716, 1717, 1663, 1666}}
        },
        ["DUNGEON_GNOMER_ALL"] = {
        name = "Gnomeregan Grifter", 
        description = "Pickpocket all possible bosses in Gnomeregan",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "GNOMER", requiredBosses = {7361, 7800}}
        },
        ["DUNGEON_RFK_ALL"] = {
        name = "Razorfen Rogue",
        description = "Pickpocket all possible bosses in Razorfen Kraul",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "RFK", requiredBosses = {4424, 4428, 4420}}
        },
        ["DUNGEON_SM_ALL"] = {
        name = "Monastery Miscreant",
        description = "Pickpocket all possible bosses in Scarlet Monastery",
        points = 50,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "SM", requiredBosses = {3983, 4543, 3977, 3976, 4542, 3974, 4539}}
        },
        ["DUNGEON_RFD_ALL"] = {
        name = "Downs Desperado",
        description = "Pickpocket all possible bosses in Razorfen Downs",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "RFD", requiredBosses = {7355}}
        },
        ["DUNGEON_ULD_ALL"] = {
        name = "Uldaman Underground",
        description = "Pickpocket all possible bosses in Uldaman",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "ULD", requiredBosses = {6910, 7228}}
        },
        ["DUNGEON_ZF_ALL"] = {
        name = "Zul'Farrak Zipper",
        description = "Pickpocket all possible bosses in Zul'Farrak",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "ZF", requiredBosses = {7267, 7271, 7272, 7275}}
        },
        ["DUNGEON_MARA_ALL"] = {
        name = "Maraudon Mugger",
        description = "Pickpocket all possible bosses in Maraudon",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "MARA", requiredBosses = {13282}}
        },
        ["DUNGEON_ST_ALL"] = {
        name = "Sunken Temple Stealer",
        description = "Pickpocket all possible bosses in Temple of Atal'Hakkar",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "ST", requiredBosses = {5713, 5715, 5714, 5717, 5712}}
        },
        ["DUNGEON_BRD_ALL"] = {
        name = "Blackrock Bandit",
        description = "Pickpocket all possible bosses in Blackrock Depths",
        points = 50,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "BRD", requiredBosses = {9019, 9018, 9033, 9034, 9035, 9037, 8983}}
        },
        ["DUNGEON_LBRS_ALL"] = {
        name = "Lower Blackrock Sneak",
        description = "Pickpocket all possible bosses in Lower Blackrock Spire",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "LBRS", requiredBosses = {9196, 9236, 9237, 9956}}
        },
        ["DUNGEON_UBRS_ALL"] = {
        name = "Upper Blackrock Sneak",
        description = "Pickpocket all possible bosses in Upper Blackrock Spire",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "UBRS", requiredBosses = {10363, 10429, 10339}}
        },
        ["DUNGEON_SCHOLO_ALL"] = {
        name = "Scholomance Snatcher",
        description = "Pickpocket all possible bosses in Scholomance",
        points = 50,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "SCHOLO", requiredBosses = {10503, 10505, 10502, 10504, 10508, 10901, 10507}}
        },
        ["DUNGEON_STRAT_ALL"] = {
        name = "Stratholme Stealth",
        description = "Pickpocket all possible bosses in Stratholme",
        points = 50,
        icon = 921,
        criteria = {type = "PICKPOCKET_DUNGEON_COMPLETE", dungeon = "STRAT", requiredBosses = {10436, 10437, 10438, 10435, 11032, 10809}}
        },
        ["DUNGEON_MASTER"] = {
        name = "Master of Shadows",
        description = "Complete all dungeon pickpocketing achievements",
        points = 100,
        icon = 921,
        criteria = {
            type = "META_ACHIEVEMENT",
            achievements = {
                "DUNGEON_RFC_ALL", "DUNGEON_WC_ALL", "DUNGEON_DM_ALL", "DUNGEON_SFK_ALL", "DUNGEON_BFD_ALL", 
                "DUNGEON_STOCKS_ALL", "DUNGEON_GNOMER_ALL", "DUNGEON_RFK_ALL", "DUNGEON_SM_ALL", "DUNGEON_RFD_ALL",
                "DUNGEON_ULD_ALL", "DUNGEON_ZF_ALL", "DUNGEON_MARA_ALL", "DUNGEON_ST_ALL", "DUNGEON_BRD_ALL",
                "DUNGEON_LBRS_ALL", "DUNGEON_UBRS_ALL", "DUNGEON_SCHOLO_ALL", "DUNGEON_STRAT_ALL"
            }
        }
        },
        ["ELITE_DUSKWOOD"] = {
        name = "Lord of the Manor",
        description = "Pickpocket Mor'Ladim in Duskwood while he's not in combat",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_ELITE", npcID = 522, requiresOutOfCombat = true}
        },
        ["ELITE_WESTFALL"] = {
        name = "Defias Highwayman",
        description = "Pickpocket Klaven Mortwake in Westfall while he's not in combat",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_ELITE", npcID = 7053, requiresOutOfCombat = true}
        },
        ["ELITE_WETLANDS"] = {
        name = "Dragon Hunter",
        description = "Pickpocket Dragonmaw Warlord in Wetlands while he's not in combat",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_ELITE", npcID = 2447, requiresOutOfCombat = true}
        },
        ["ELITE_TIRISFAL"] = {
        name = "Scarlet Pickpocket",
        description = "Pickpocket High Protector Lorik while he's not in combat",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_ELITE", npcID = 1843, requiresOutOfCombat = true}
        },
        ["ELITE_ORGRIMMAR"] = {
        name = "Get Gammon",
        description = "Pickpocket Gammon",
        points = 25,
        icon = 921,
        criteria = {type = "PICKPOCKET_ELITE", npcID = 3428, requiresOutOfCombat = true}
        }
    }
 
    -- Simple table serializer
    local function SerializeTable(tbl, indent)
        indent = indent or ""
        local result = "{\n"
        for k, v in pairs(tbl) do
            result = result .. indent .. "    "
            if type(k) == "string" then
                result = result .. '["' .. k .. '"] = '
            else
                result = result .. "[" .. k .. "] = "
            end
            if type(v) == "table" then
                result = result .. SerializeTable(v, indent .. "    ")
            elseif type(v) == "string" then
                result = result .. '"' .. v .. '"'
            else
                result = result .. tostring(v)
            end
            result = result .. ",\n"
        end
        return result .. indent .. "}"
    end
 
    -- Write achievements
    output:write(SerializeTable(achievements))
    output:write("\n")
    output:close()
 end
 
 GenerateDatabase()
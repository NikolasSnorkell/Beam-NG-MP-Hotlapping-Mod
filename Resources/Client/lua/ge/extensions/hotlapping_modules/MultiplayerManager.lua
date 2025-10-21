-- MultiplayerManager.lua
-- Manages BeamMP multiplayer functionality and server communication
-- Author: NikolasSnorkell
-- Version: 1.0.0

local M = {}

local debugMode = true

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[MultiplayerManager][%s] %s", level, message))
    end
end

-- BeamMP detection functions
function M.isInMP()
    -- Проверяем наличие MP API для BeamNG Drive мультиплеера
    return MP ~= nil and type(MP.GetPlayerName) == "function"
end

function M.isBeamMPConnected()
    -- Дополнительная проверка для BeamMP лаунчера
    if MPGameNetwork and type(MPGameNetwork.launcherConnected) == "function" then
        return MPGameNetwork.launcherConnected()
    end
    return false
end

function M.getOperationMode()
    if M.isInMP() then
        return "multiplayer"
    else
        return "singleplayer"
    end
end

-- Player information functions
function M.getLocalPlayerName()
    if M.isInMP() and MP and type(MP.GetPlayerName) == "function" then
        return MP.GetPlayerName(MP.GetPlayerServerID())
    else
        -- Fallback для одиночной игры
        return "LocalPlayer"
    end
end

-- Server communication functions
function M.sendLapTimeToServer(time, vehicle, isNewBest, mapName)
    if not M.isInMP() then
        log("Not in multiplayer mode, skipping server sync", "DEBUG")
        return false
    end
    
    local playerName = M.getLocalPlayerName()
    
    local message = {
        event = "hotlapping_lap_time",
        mapName = mapName,
        playerName = playerName,
        time = time,
        vehicle = vehicle,
        isNewBest = isNewBest,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    -- TODO: Implement actual server communication
    -- TriggerServerEvent("HotlappingEvent", jsonEncode(message))
    log(string.format("Would send to server: %s completed lap %.3fs (best: %s) on %s", 
        playerName, time, tostring(isNewBest), mapName), "DEBUG")
    
    return true
end

function M.requestLeaderboardFromServer(mapName)
    if not M.isInMP() then
        log("Not in multiplayer mode, skipping leaderboard request", "DEBUG")
        return false
    end
    
    local message = {
        event = "hotlapping_request_leaderboard",
        mapName = mapName
    }
    
    -- TODO: Implement actual server communication
    -- TriggerServerEvent("HotlappingEvent", jsonEncode(message))
    log(string.format("Would request leaderboard from server for map: %s", mapName), "DEBUG")
    
    return true
end

-- Enable/disable debug mode
function M.setDebugMode(enabled)
    debugMode = enabled
end

return M
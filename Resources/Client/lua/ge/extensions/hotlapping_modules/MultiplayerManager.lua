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
    -- return MP ~= nil and type(MP.GetPlayerName) == "function"
    return true
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
    -- local name = MP.GetPlayerName(MP.GetPlayerServerID())

    if name and name ~= "" then
        return name
    else
        -- Fallback для одиночной игры
        return "LocalPlayer"
    end
end

function M.sendLapTimeToServer(time, vehicle, isNewBest, mapName, lapNumber)
    log("========== sendLapTimeToServer() CALLED ==========", "INFO")
    log(string.format("Parameters: time=%.3f, vehicle=%s, mapName=%s, lapNumber=%s", 
        time, tostring(vehicle), tostring(mapName), tostring(lapNumber)))
    
    if not M.isInMP() then
        log("Not in multiplayer mode", "WARN")
        return false
    end
    
    log("In multiplayer mode, preparing message...")
    
    local playerName = 'LocalPlayer'
    log("Player name: " .. tostring(playerName))
    
    local message = {
        event = "hotlapping_lap_time",
        mapName = mapName,
        playerName = playerName,
        time = time,
        vehicle = vehicle,
        isNewBest = isNewBest,
        lapNumber = lapNumber,
        timestamp = os.time()
    }
    
    log("Message prepared, encoding to JSON...")
    local jsonMessage = jsonEncode(message)
    log("JSON encoded, length: " .. tostring(#jsonMessage))
    
    log("Triggering server event 'onHotlappingRequest'...")
    TriggerServerEvent("onHotlappingRequest", jsonMessage)
    
    log(string.format("Lap time sent to server: %s completed lap %.3fs (lap #%d) on %s", 
        playerName, time, lapNumber or 0, mapName), "INFO")
    log("========== sendLapTimeToServer() FINISHED ==========", "INFO")
    
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
    
    TriggerServerEvent("onHotlappingRequest", jsonEncode(message))
    log(string.format("Would request leaderboard from server for map: %s", message.mapName), "DEBUG")
    
    return true
end

function M.clearMyLeaderboardTimes()
      if not M.isInMP() then
        log("Not in multiplayer mode, skipping hotlapping_clear_user_leaderboard request", "DEBUG")
        return false
    end
    
    local message = {
        event = "hotlapping_clear_user_leaderboard"
    }
    
    TriggerServerEvent("onHotlappingRequest", jsonEncode(message))
    
    return true
end
-- Enable/disable debug mode
function M.setDebugMode(enabled)
    debugMode = enabled
end

return M
-- Hotlapping.lua
-- Main extension file for Hotlapping mod (Refactored)
-- Author: NikolasSnorkell
-- Version: 0.2.0

local M = {}
M.dependencies = { "ui_imgui" }

-- Module state
local isActive = false
local debugMode = false

-- Sub-modules
local waypointManager = nil
local crossingDetector = nil
local lapTimer = nil
local storageManager = nil
local multiplayerManager = nil
local leaderboardManager = nil
local uiManager = nil

-- Current vehicle
local currentVehicle = nil
local currentVehicleID = nil

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[Hotlapping][%s] %s", level, message))
    end
end

-- Helper function to check if vehicle belongs to local player (multiplayer-safe)
local function isMyVehicle(vehicleId)
    if not vehicleId then 
        return false 
    end
    
    local myVehicle = be:getPlayerVehicle(0)
    if not myVehicle then 
        return false 
    end
    
    local myVehicleId = myVehicle:getID()
    return (myVehicleId == vehicleId)
end

-- Load all sub-modules
local function loadModules()
    log("Loading sub-modules...")
    
    waypointManager = require('hotlapping_modules/WaypointManager')
    log("WaypointManager loaded")
    
    crossingDetector = require('hotlapping_modules/CrossingDetector')
    log("CrossingDetector loaded")
    
    lapTimer = require('hotlapping_modules/LapTimer')
    log("LapTimer loaded")
    
    storageManager = require('hotlapping_modules/StorageManager')
    log("StorageManager loaded")
    
    multiplayerManager = require('hotlapping_modules/MultiplayerManager')
    log("MultiplayerManager loaded")
    
    leaderboardManager = require('hotlapping_modules/LeaderboardManager')
    log("LeaderboardManager loaded")
    
    uiManager = require('hotlapping_modules/UIManager')
    log("UIManager loaded")
    
    -- Setup dependencies for UIManager
    uiManager.setDependencies({
        waypointManager = waypointManager,
        lapTimer = lapTimer,
        multiplayerManager = multiplayerManager,
        leaderboardManager = leaderboardManager
    })
    
    -- Setup debug mode for all modules
    if debugMode then
        storageManager.setDebugMode(true)
        multiplayerManager.setDebugMode(true)
        leaderboardManager.setDebugMode(true)
        uiManager.setDebugMode(true)
    end
end

-- UI callback handlers
local function setPointA()
    if not waypointManager then return end
    
    if uiManager then
        uiManager.setStatus(uiManager.getStatusEnum().SETTING_POINT_A)
    end
    log("Setting Point A...")
    
    local vehicle = be:getPlayerVehicle(0)
    if vehicle then
        local position = vehicle:getPosition()
        waypointManager.setPointA(position)
        
        if uiManager then
            uiManager.updateStatus()
        end
        
        -- Auto-save waypoints
        if storageManager then
            local pointA = waypointManager.getPointA()
            local pointB = waypointManager.getPointB()
            if pointA then
                storageManager.saveFinishLine(pointA, pointB)
            end
        end
        
        log(string.format("Point A set at: x=%.2f, y=%.2f, z=%.2f", position.x, position.y, position.z))
        guihooks.message("Точка А установлена", 3, "")
    else
        log("No vehicle found for setting Point A", "ERROR")
        if uiManager then
            uiManager.setStatus(uiManager.getStatusEnum().NOT_CONFIGURED)
        end
    end
end

local function setPointB()
    if not waypointManager then return end
    
    if uiManager then
        uiManager.setStatus(uiManager.getStatusEnum().SETTING_POINT_B)
    end
    log("Setting Point B...")
    
    local vehicle = be:getPlayerVehicle(0)
    if vehicle then
        local position = vehicle:getPosition()
        waypointManager.setPointB(position)
        
        if uiManager then
            uiManager.updateStatus()
        end
        
        -- Auto-save waypoints
        if storageManager then
            local pointA = waypointManager.getPointA()
            local pointB = waypointManager.getPointB()
            if pointA and pointB then
                storageManager.saveFinishLine(pointA, pointB)
            end
        end
        
        log(string.format("Point B set at: x=%.2f, y=%.2f, z=%.2f", position.x, position.y, position.z))
        guihooks.message("Точка Б установлена", 3, "")
    else
        log("No vehicle found for setting Point B", "ERROR")
        if uiManager then
            uiManager.setStatus(uiManager.getStatusEnum().POINT_A_SET)
        end
    end
end

local function clearPoints()
    if not waypointManager then return end
    
    log("Clearing all points...")
    
    waypointManager.clearPoints()
    if uiManager then
        uiManager.setStatus(uiManager.getStatusEnum().NOT_CONFIGURED)
    end
    
    -- Clear saved waypoints
    if storageManager then
        storageManager.deleteFinishLine()
    end
    
    -- Stop lap timer if running
    if lapTimer and lapTimer.isRunning() then
        lapTimer.stopLap()
        log("Lap timer stopped due to point clearing")
    end
    
    log("All points cleared")
    guihooks.message("Точки очищены", 3, "")
end

-- Setup lap completion callback for multiplayer integration
local function setupLapCompletedCallback()
    if not lapTimer then return end
    
    lapTimer.setOnLapCompletedCallback(function(lapRecord)
        log(string.format("Lap completed callback: %.3fs", lapRecord.time))
        
        -- Update local leaderboard data
        if multiplayerManager and leaderboardManager then
            local playerName = multiplayerManager.getLocalPlayerName()
            if playerName then
                local isNewBest = leaderboardManager.updatePlayerBestTime(playerName, lapRecord.time, lapRecord.vehicle)
                leaderboardManager.addPlayerRecentTime(playerName, lapRecord.time, lapRecord.vehicle)
                
                -- Send to server if in multiplayer mode
                if multiplayerManager.isInMP() then
                    local mapName = storageManager and storageManager.getCurrentMapName() or "unknown"
                    multiplayerManager.sendLapTimeToServer(lapRecord.time, lapRecord.vehicle, isNewBest, mapName)
                end
            end
        end
    end)
end

-- Main extension lifecycle functions
local function onExtensionLoaded()
    log("Extension loading...")
    
    -- Load sub-modules
    loadModules()
    
    -- Setup UI callbacks
    if uiManager then
        uiManager.setCallbacks({
            onSetPointA = setPointA,
            onSetPointB = setPointB,
            onClearPoints = clearPoints,
            onDebugModeChanged = function(enabled)
                M.setDebugMode(enabled)
            end
        })
    end
    
    -- Setup lap completed callback for multiplayer integration
    setupLapCompletedCallback()
    
    -- Setup crossing detector callback
    if crossingDetector then
        crossingDetector.setOnLineCrossedCallback(function(direction)
            log(string.format("Line crossed! Direction: %s", direction))
            
            -- Only count forward crossings
            if direction == "forward" then
                log("Valid lap crossing detected!")
                
                -- Manage lap timer
                if lapTimer then
                    if lapTimer.isRunning() then
                        -- Complete current lap
                        local lapRecord = lapTimer.completeLap()
                        if lapRecord then
                            log(string.format("Lap #%d completed: %s", lapRecord.lapNumber, lapTimer.formatTime(lapRecord.time)))
                            
                            -- Show notification
                            local message = string.format("Круг завершен: %s", lapTimer.formatTime(lapRecord.time))
                            if lapRecord.time == lapTimer.getBestLapTime() then
                                message = message .. " [Новый рекорд!]"
                            end
                            guihooks.message(message, 5, "")
                            
                            -- Auto-save lap history after each lap
                            if storageManager then
                                local allLaps = lapTimer.getLapHistory()
                                storageManager.saveLapHistory(allLaps)
                                log("Lap history auto-saved")
                            end
                        end
                        
                        -- Start new lap immediately
                        lapTimer.startLap()
                        log("New lap started automatically")
                    else
                        -- Start first lap
                        lapTimer.startLap()
                        log("First lap started")
                        guihooks.message("Круг начат!", 3, "")
                    end
                end
            else
                log("Backward crossing ignored")
            end
        end)
    end
    
    -- Request current vehicle info
    currentVehicle = be:getPlayerVehicle(0)
    if currentVehicle then
        currentVehicleID = currentVehicle:getID()
        local vehicleName = currentVehicle:getJBeamFilename() or "unknown"
        log(string.format("Current vehicle: %s (ID: %s)", vehicleName, tostring(currentVehicleID)))
        
        -- Set vehicle name for lap timer
        if lapTimer and lapTimer.setCurrentVehicle then
            lapTimer.setCurrentVehicle(vehicleName)
        end
    else
        currentVehicleID = nil
    end
    
    isActive = true
    log("Extension loaded successfully!")
end

local function onExtensionUnloaded()
    log("Extension unloading...")
    
    -- Auto-save data before unloading
    if storageManager and lapTimer then
        local allLaps = lapTimer.getLapHistory()
        if #allLaps > 0 then
            storageManager.saveLapHistory(allLaps)
            log("Final lap history saved")
        end
    end
    
    isActive = false
    log("Extension unloaded")
end

-- Game event handlers
local function onUpdate(dt)
    if not isActive then return end
    
    -- Check for vehicle changes by ID (not object comparison)
    local vehicle = be:getPlayerVehicle(0)
    local newVehicleID = vehicle and vehicle:getID() or nil
    
    if currentVehicleID ~= newVehicleID then
        log(string.format("Vehicle change detected: %s -> %s", 
            currentVehicleID and tostring(currentVehicleID) or "nil",
            newVehicleID and tostring(newVehicleID) or "nil"), "DEBUG")
        
        -- Only reset timer if we're actually switching between vehicles, not from nil to vehicle
        local shouldResetTimer = currentVehicleID ~= nil and newVehicleID ~= nil and lapTimer and lapTimer.isRunning()
        
        -- Update stored references
        currentVehicle = vehicle
        currentVehicleID = newVehicleID
        
        if vehicle then
            local vehicleName = vehicle:getJBeamFilename() or "unknown"
            log(string.format("Vehicle changed to: %s (ID: %s)", vehicleName, tostring(vehicle:getID())))
            
            -- Set vehicle name for lap timer
            if lapTimer and lapTimer.setCurrentVehicle then
                lapTimer.setCurrentVehicle(vehicleName)
            end
            
            -- Reset lap timer only when switching between vehicles, not on initial spawn
            if shouldResetTimer and lapTimer and lapTimer.reset then
                lapTimer.reset(false) -- Don't clear history
                log("Lap timer reset due to vehicle change")
            end
        else
            log("No vehicle detected")
        end
    end
    
    -- Draw waypoint visualization (only in debug mode)
    if waypointManager and debugMode then
        waypointManager.drawVisualization()
    end
    
    -- Update crossing detector
    if crossingDetector and waypointManager then
        local lineConfigured = waypointManager.getPointA() and waypointManager.getPointB()
        
        if lineConfigured and vehicle and isMyVehicle(vehicle:getID()) then
            crossingDetector.update(vehicle, waypointManager.getPointA(), waypointManager.getPointB())
            
            -- Draw debug visualization if enabled
            if debugMode then
                crossingDetector.drawDebugVisualization(vehicle)
            end
        end
    end
    
    -- Update lap timer
    if lapTimer then
        lapTimer.update(dt)
    end
end

local function onPreRender(dt)
    if not isActive then return end
    if uiManager then
        uiManager.renderUI(dt)
    end
end

-- Load default waypoints from JSON file
local function loadDefaultWaypoints(mapName)
    local filePath = "/lua/ge/extensions/hotlapping/data/default_waypoints.json"
    
    if not FS.Exists(filePath) then
        log("Default waypoints file not found: " .. filePath, "WARN")
        return nil
    end
    
    local file = io.open(filePath, "r")
    if not file then
        log("Failed to open default waypoints file", "ERROR")
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    local success, data = pcall(function()
        return jsonDecode(content)
    end)
    
    if not success then
        log("Failed to parse default waypoints JSON: " .. tostring(data), "ERROR")
        return nil
    end
    
    return data[mapName]
end

-- Called when mission starts (entering map)
local function onClientStartMission(levelPath)
    log("Mission started: " .. tostring(levelPath))
    
    -- Small delay to ensure everything is loaded
    local function delayedInitialization()
        if not storageManager then
            log("StorageManager not available during mission start", "WARN")
            return
        end
        
        -- Load saved waypoints for this map
        local waypointsLoaded = false
        
        if waypointManager then
            local savedWaypoints = storageManager.loadFinishLine()
            
            if savedWaypoints and savedWaypoints.pointA and savedWaypoints.pointB then
                log("Loading saved waypoints...")
                
                waypointManager.setPointA(savedWaypoints.pointA)
                waypointManager.setPointB(savedWaypoints.pointB)
                
                -- Update UI status
                if uiManager then
                    uiManager.updateStatus()
                end
                
                log("Finish line loaded successfully!")
                guihooks.message("Финишная линия загружена с диска", 3, "")
                waypointsLoaded = true
            end
        end
        
        -- If no saved waypoints, try loading defaults from JSON
        if not waypointsLoaded then
            log("No saved finish line found, checking default waypoints...")
            
            local mapName = storageManager.getCurrentMapName()
            local defaultWaypoints = loadDefaultWaypoints(mapName)
            
            if defaultWaypoints and defaultWaypoints.pointA and defaultWaypoints.pointB then
                log("Loading default waypoints for map: " .. mapName)
                
                if waypointManager then
                    waypointManager.setPointA(defaultWaypoints.pointA)
                    waypointManager.setPointB(defaultWaypoints.pointB)
                end
                
                -- Update UI status
                if uiManager then
                    uiManager.updateStatus()
                end
                
                log("Default waypoints loaded: " .. (defaultWaypoints.description or ""))
                guihooks.message("Загружены стандартные точки для карты", 3, "")
            else
                log("No default waypoints found for this map")
                -- Ensure status is NOT_CONFIGURED if no data at all
                if uiManager then
                    uiManager.setStatus(uiManager.getStatusEnum().NOT_CONFIGURED)
                end
            end
        end
        
        -- Load lap history for this map
        if storageManager and lapTimer then
            local savedHistory = storageManager.loadLapHistory()
            
            if savedHistory and savedHistory.laps then
                log(string.format("Loading lap history: %d laps, best: %.3fs", 
                    #savedHistory.laps, savedHistory.bestLapTime or 0))
                
                log("Lap history loaded successfully!")
            else
                log("No saved lap history found for this map")
            end
        end
        
        -- Request leaderboard from server if in multiplayer
        if multiplayerManager and multiplayerManager.isInMP() and storageManager then
            local mapName = storageManager.getCurrentMapName()
            if mapName then
                multiplayerManager.requestLeaderboardFromServer(mapName)
            end
        end
    end
    
    -- Delay the initialization to ensure all systems are ready
    obj:queueGameEngineLua(string.format("extensions.%s.onClientStartMission(%q)", 
        string.gsub(debug.getinfo(1, 'S').source, '^@', ''):match("([^/\\]+)%.lua$"):gsub('%.lua$', ''), 
        levelPath))
end

-- Called when mission ends (leaving map)
local function onClientEndMission()
    log("Mission ended")
    
    -- Stop running lap before saving
    if lapTimer and lapTimer.isRunning() then
        lapTimer.stopLap()
        log("Current lap aborted due to mission end")
    end
    
    -- Save current lap history
    if storageManager and lapTimer then
        local allLaps = lapTimer.getLapHistory()
        if #allLaps > 0 then
            storageManager.saveLapHistory(allLaps)
            log("Lap history saved before mission end")
        end
    end
end

-- Vehicle switch handler
local function onVehicleSwitched(oldVehicle, newVehicle, player)
    -- Only handle local player vehicle switches
    if player ~= 0 then return end
    
    -- Safe ID extraction - oldVehicle and newVehicle can be numbers or vehicle objects
    local oldID = "none"
    local newID = "none"
    
    if oldVehicle then
        if type(oldVehicle) == "number" then
            oldID = tostring(oldVehicle)
        elseif oldVehicle.getID then
            oldID = tostring(oldVehicle:getID())
        end
    end
    
    if newVehicle then
        if type(newVehicle) == "number" then
            newID = tostring(newVehicle)
        elseif newVehicle.getID then
            newID = tostring(newVehicle:getID())
        end
    end
    
    log(string.format("Vehicle switched: %s -> %s", oldID, newID))
    
    -- Get actual vehicle object if newVehicle is just an ID
    local actualVehicle = newVehicle
    if type(newVehicle) == "number" then
        actualVehicle = be:getPlayerVehicle(0) -- Get the actual vehicle object
    end
    
    currentVehicle = actualVehicle
    currentVehicleID = actualVehicle and actualVehicle:getID() or nil
    
    if actualVehicle and actualVehicle.getJBeamFilename then
        local vehicleName = actualVehicle:getJBeamFilename() or "unknown"
        log(string.format("Switched to vehicle: %s", vehicleName))
        
        -- Set vehicle name for lap timer
        if lapTimer and lapTimer.setCurrentVehicle then
            lapTimer.setCurrentVehicle(vehicleName)
        end
        
        -- Reset lap timer when vehicle changes
        if lapTimer and lapTimer.isRunning() then
            lapTimer.reset(false) -- Don't clear history
            log("Lap timer reset due to vehicle switch")
        end
    end
end

-- Public API
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onUpdate = onUpdate
M.onPreRender = onPreRender
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onVehicleSwitched = onVehicleSwitched

-- Debug functions
M.setDebugMode = function(enabled)
    debugMode = enabled
    log("Debug mode " .. (enabled and "enabled" or "disabled"))
    
    -- Propagate to sub-modules
    if storageManager then storageManager.setDebugMode(enabled) end
    if multiplayerManager then multiplayerManager.setDebugMode(enabled) end
    if leaderboardManager then leaderboardManager.setDebugMode(enabled) end
    if uiManager then uiManager.setDebugMode(enabled) end
    if crossingDetector then crossingDetector.setDebugMode(enabled) end
end

M.getDebugMode = function()
    return debugMode
end

return M
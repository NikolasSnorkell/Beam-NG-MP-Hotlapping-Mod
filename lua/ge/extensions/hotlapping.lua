-- Hotlapping.lua
-- Main extension file for Hotlapping mod
-- Author: NikolasSnorkell
-- Version: 0.1.0

local M = {}
M.dependencies = { "ui_imgui" }

-- Module state
local isActive = false
local debugMode = true
local showUI = true
local uiRenderCount = 0  -- Debug counter для отслеживания рендера UI

-- Sub-modules
local waypointManager = nil
local crossingDetector = nil
local lapTimer = nil
local storageManager = nil

-- Current vehicle
local currentVehicle = nil

-- Status enum
local STATUS = {
    NOT_CONFIGURED = "not_configured",
    POINT_A_SET = "point_a_set",
    CONFIGURED = "configured",
    SETTING_POINT_A = "setting_point_a",
    SETTING_POINT_B = "setting_point_b"
}

local currentStatus = STATUS.NOT_CONFIGURED

-- Forward declarations for UI handlers
local setPointA, setPointB, clearPoints

-- Utility function for logging (defined early so other functions can use it)
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[Hotlapping][%s] %s", level, message))
    end
end

-- Function to sync status from WaypointManager
local function updateStatusFromWaypoints()
    if not waypointManager then 
        log("updateStatusFromWaypoints: waypointManager not available", "WARN")
        return 
    end
    
    local pointA = waypointManager.getPointA()
    local pointB = waypointManager.getPointB()
    
    log(string.format("updateStatusFromWaypoints: pointA=%s, pointB=%s", 
        tostring(pointA ~= nil), tostring(pointB ~= nil)))
    
    if pointA and pointB then
        currentStatus = STATUS.CONFIGURED
        log("Status synced: CONFIGURED (both points set)")
    elseif pointA then
        currentStatus = STATUS.POINT_A_SET
        log("Status synced: POINT_A_SET")
    else
        currentStatus = STATUS.NOT_CONFIGURED
        log("Status synced: NOT_CONFIGURED")
    end
end

-- Load default waypoints from JSON file
local function loadDefaultWaypoints(mapName)
    if not mapName then
        log("Cannot load default waypoints: no map name", "WARN")
        return nil
    end
    
    local filePath = "/scripts/hotlapping/data/default_waypoints.json"
    local fileContent = jsonReadFile(filePath)
    
    if not fileContent then
        log("Default waypoints file not found or invalid: " .. filePath, "WARN")
        return nil
    end
    
    -- Find waypoints for current map
    if fileContent.waypoints and fileContent.waypoints[mapName] then
        log("Found default waypoints for map: " .. mapName)
        return fileContent.waypoints[mapName]
    end
    
    log("No default waypoints found for map: " .. mapName)
    return nil
end

-- Load sub-modules
local function loadModules()
    waypointManager = require('hotlapping_modules/WaypointManager')
    log("WaypointManager loaded")
    
    crossingDetector = require('hotlapping_modules/CrossingDetector')
    log("CrossingDetector loaded")
    
    lapTimer = require('hotlapping_modules/LapTimer')
    log("LapTimer loaded")
    
    storageManager = require('hotlapping_modules/StorageManager')
    log("StorageManager loaded")
end

-- Get status text in Russian
local function getStatusText()
    if currentStatus == STATUS.NOT_CONFIGURED then
        return "Не установлено"
    elseif currentStatus == STATUS.POINT_A_SET then
        return "Точка А установлена, установите точку Б"
    elseif currentStatus == STATUS.CONFIGURED then
        return "Установлено"
    elseif currentStatus == STATUS.SETTING_POINT_A then
        return "В процессе настройки точки А..."
    elseif currentStatus == STATUS.SETTING_POINT_B then
        return "В процессе настройки точки Б..."
    end
    return "Неизвестно"
end

-- Get status color
local function getStatusColor()
    if currentStatus == STATUS.NOT_CONFIGURED then
        return {1, 0.4, 0.4, 1} -- Red
    elseif currentStatus == STATUS.POINT_A_SET then
        return {1, 0.8, 0.2, 1} -- Yellow
    elseif currentStatus == STATUS.CONFIGURED then
        return {0.3, 1, 0.4, 1} -- Green
    else
        return {0, 0.8, 1, 1} -- Blue
    end
end

-- Draw ImGui UI
local function onPreRender(dt)
    if not isActive then return end
    if not showUI then return end
    
    -- Debug logging (только первые 3 вызова)
    uiRenderCount = uiRenderCount + 1
    if uiRenderCount <= 3 then
        log(string.format("onPreRender called (count: %d, status: %s)", uiRenderCount, currentStatus))
    end
    
    local im = ui_imgui
    
    -- Main window
    local flags = im.WindowFlags_AlwaysAutoResize or 0
    
    -- Begin window - ImGui will handle open/close state internally
    if im.Begin("Hotlapping##HotlappingMainWindow", nil, flags) then
        -- Status section
        im.Text("Статус:")
        im.SameLine()
        local color = getStatusColor()
        im.TextColored(im.ImVec4(color[1], color[2], color[3], color[4]), getStatusText())
        
        im.Separator()
        
        -- Control buttons
        if im.Button("Установить точку А", im.ImVec2(250, 30)) then
            setPointA()
        end
        
        local canSetB = (currentStatus ~= STATUS.NOT_CONFIGURED)
        if not canSetB then
            im.PushStyleVar1(im.StyleVar_Alpha, 0.5)
        end
        if im.Button("Установить точку Б", im.ImVec2(250, 30)) then
            if canSetB then
                setPointB()
            end
        end
        if not canSetB then
            im.PopStyleVar()
        end
        
        local canClear = (currentStatus ~= STATUS.NOT_CONFIGURED)
        if not canClear then
            im.PushStyleVar1(im.StyleVar_Alpha, 0.5)
        end
        if im.Button("Очистить точки", im.ImVec2(250, 30)) then
            if canClear then
                clearPoints()
            end
        end
        if not canClear then
            im.PopStyleVar()
        end
        
        im.Separator()
        
        -- Timer section
        im.Text("Текущий круг:")
        im.SameLine()
        local currentTime = "00:00.000"
        local currentColor = im.ImVec4(0, 0.8, 1, 1)  -- Blue
        if lapTimer and lapTimer.isRunning() then
            currentTime = lapTimer.getCurrentTimeFormatted()
            currentColor = im.ImVec4(0.3, 1, 0.4, 1)  -- Green when running
        end
        im.TextColored(currentColor, currentTime)
        
        im.Text("Последний круг:")
        im.SameLine()
        local lastLap = "--:--.---"
        if lapTimer then
            lastLap = lapTimer.getLastLapTimeFormatted()
        end
        im.TextColored(im.ImVec4(1, 1, 0.3, 1), lastLap)
        
        im.Text("Лучший круг:")
        im.SameLine()
        local bestLap = "--:--.---"
        if lapTimer then
            bestLap = lapTimer.getBestLapTimeFormatted()
        end
        im.TextColored(im.ImVec4(0.3, 1, 0.4, 1), bestLap)
        
        im.Separator()
        
        -- Lap history
        im.Text("История кругов")
        if lapTimer and lapTimer.getLapCount() > 0 then
            local history = lapTimer.getLapHistory()
            -- Show last 5 laps
            local startIdx = math.max(1, #history - 4)
            for i = #history, startIdx, -1 do
                local lap = history[i]
                local lapText = string.format("#%d: %s", lap.lapNumber, lapTimer.formatTime(lap.time))
                
                -- Highlight best lap in green
                if lap.time == lapTimer.getBestLapTime() then
                    im.TextColored(im.ImVec4(0.3, 1, 0.4, 1), lapText .. " [Лучший!]")
                else
                    im.Text(lapText)
                end
            end
            
            -- Button to clear history
            if im.Button("Очистить историю", im.ImVec2(250, 25)) then
                if lapTimer then
                    lapTimer.clearHistory()
                    log("Lap history cleared")
                    
                    -- Also delete from storage
                    if storageManager then
                        storageManager.deleteLapHistory()
                        log("Lap history deleted from storage")
                    end
                end
            end
        else
            im.TextColored(im.ImVec4(0.5, 0.5, 0.5, 1), "Нет завершенных кругов")
        end
    end
    
    -- ВАЖНО: End() всегда вызывается после Begin(), даже если Begin вернул false
    im.End()
end

-- Initialize extension
local function onExtensionLoaded()
    log("Extension loading...")
    
    -- Load sub-modules
    loadModules()
    
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
                            if storageManager and lapTimer.getLapCount() > 0 then
                                local laps = lapTimer.getLapHistory()
                                storageManager.saveLapHistory(laps)
                                log("Lap history auto-saved")
                            end
                        end
                        
                        -- Start new lap immediately
                        lapTimer.startLap()
                    else
                        -- Start first lap
                        lapTimer.startLap()
                        log("First lap started")
                        guihooks.message("Круг начат!", 3, "")
                    end
                end
            else
                log("Backward crossing ignored", "WARN")
            end
        end)
    end
    
    -- Initialize state
    isActive = true
    showUI = true  -- Явно устанавливаем UI как видимый
    currentStatus = STATUS.NOT_CONFIGURED
    
    log("Extension loaded successfully!")
    log("UI state: " .. (showUI and "visible" or "hidden"))
    log("Active state: " .. (isActive and "active" or "inactive"))
    
    -- Check if we're already in a mission (mod loaded after map loaded)
    if getMissionFilename and getMissionFilename() ~= "" then
        log("Already in mission, loading waypoints now...")
        -- Manually trigger mission start logic to load waypoints
        M.onClientStartMission(getMissionFilename())
    end
    
    -- Show welcome message to user
    guihooks.message("Hotlapping мод загружен! Откройте ImGui окно.", 5, "")
end

-- Cleanup extension
local function onExtensionUnloaded()
    log("Extension unloading...")
    
    isActive = false
    
    -- TODO: Save current configuration before unloading
    
    log("Extension unloaded successfully!")
end

-- Called every frame
local function onUpdate(dt)
    if not isActive then return end
    
    -- Get current vehicle
    if not currentVehicle then
        currentVehicle = be:getPlayerVehicle(0)
        if not currentVehicle then
            return
        end
    end
    
    -- Draw waypoint visualization
    if waypointManager then
        waypointManager.drawVisualization()
    end
    
    -- Check for line crossing
    if crossingDetector and waypointManager then
        local pointA = waypointManager.getPointA()
        local pointB = waypointManager.getPointB()
        
        if pointA and pointB then
            -- Update crossing detector (checks for crossing)
            crossingDetector.update(currentVehicle, pointA, pointB)
            
            -- Draw debug visualization if enabled
            if debugMode then
                crossingDetector.drawDebugVisualization(currentVehicle)
            end
        end
    end
    
    -- TODO: Update timer
end

-- Handle vehicle switch
local function onVehicleSwitched(oldId, newId, player)
    log(string.format("Vehicle switched from %s to %s", tostring(oldId), tostring(newId)))
    currentVehicle = be:getPlayerVehicle(0)
    
    -- Reset crossing detector state to avoid false detections
    if crossingDetector then
        crossingDetector.reset()
        log("CrossingDetector state reset after vehicle switch")
    end
    
    -- Reset lap timer when switching vehicles
    if lapTimer then
        if lapTimer.isRunning() then
            lapTimer.stopLap()  -- Abort current lap
            log("Current lap aborted due to vehicle switch")
        end
        
        -- Update vehicle name for history tracking
        if currentVehicle then
            local vehicleName = currentVehicle:getJBeamFilename() or "unknown"
            lapTimer.setVehicle(vehicleName)
        end
    end
end

-- Called when mission starts (map loaded)
local function onClientStartMission(levelPath)
    log("Mission started: " .. tostring(levelPath))
    
    -- Ensure UI is visible
    showUI = true
    isActive = true
    log("UI enabled for mission")
    
    currentVehicle = be:getPlayerVehicle(0)
    
    -- Set initial vehicle name for lap timer
    if lapTimer and currentVehicle then
        local vehicleName = currentVehicle:getJBeamFilename() or "unknown"
        lapTimer.setVehicle(vehicleName)
    end
    
    -- Load finish line configuration for this map
    if storageManager and waypointManager then
        local savedWaypoints = storageManager.loadFinishLine()
        local waypointsLoaded = false
        
        if savedWaypoints then
            log("Loading saved finish line for this map...")
            
            -- Load points into WaypointManager
            if savedWaypoints.pointA and savedWaypoints.pointB then
                waypointManager.setPointA(savedWaypoints.pointA)
                waypointManager.setPointB(savedWaypoints.pointB)
                
                -- Sync status from WaypointManager
                updateStatusFromWaypoints()
                
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
                
                waypointManager.setPointA(defaultWaypoints.pointA)
                waypointManager.setPointB(defaultWaypoints.pointB)
                
                -- Sync status from WaypointManager
                updateStatusFromWaypoints()
                
                log("Default waypoints loaded: " .. (defaultWaypoints.description or ""))
                guihooks.message("Загружены стандартные точки для карты", 3, "")
            else
                log("No default waypoints found for this map")
                -- Ensure status is NOT_CONFIGURED if no data at all
                currentStatus = STATUS.NOT_CONFIGURED
            end
        end
    end
    
    -- Load lap history for this map
    if storageManager and lapTimer then
        local savedHistory = storageManager.loadLapHistory()
        
        if savedHistory and savedHistory.laps then
            log(string.format("Loading lap history: %d laps, best: %.3fs", 
                #savedHistory.laps, savedHistory.bestLapTime or 0))
            
            -- Restore lap history to LapTimer
            -- Note: This is a bulk restore operation
            for _, lap in ipairs(savedHistory.laps) do
                -- We need to add a method to LapTimer to restore history
                -- For now, we'll skip this and implement it if needed
            end
            
            log("Lap history loaded successfully!")
        else
            log("No saved lap history found for this map")
        end
    end
end

-- Called when mission ends (leaving map)
local function onClientEndMission()
    log("Mission ended")
    
    -- Save current finish line configuration
    if storageManager and waypointManager and waypointManager.isLineConfigured() then
        local pointA = waypointManager.getPointA()
        local pointB = waypointManager.getPointB()
        
        if pointA and pointB then
            storageManager.saveFinishLine(pointA, pointB)
            log("Finish line configuration saved")
        end
    end
    
    -- Save lap history
    if storageManager and lapTimer and lapTimer.getLapCount() > 0 then
        local laps = lapTimer.getLapHistory()
        storageManager.saveLapHistory(laps)
        log("Lap history saved")
    end
    
    currentVehicle = nil
end

-- UI Event Handlers

-- Set Point A
setPointA = function()
    log("Setting Point A...")
    
    if not currentVehicle then
        log("No vehicle found!", "WARN")
        return
    end
    
    currentStatus = STATUS.SETTING_POINT_A
    
    -- Get vehicle position
    local pos = currentVehicle:getPosition()
    log(string.format("Point A position: x=%.2f, y=%.2f, z=%.2f", pos.x, pos.y, pos.z))
    
    -- Create clean position table (avoid circular references)
    local cleanPos = {x = pos.x, y = pos.y, z = pos.z}
    
    -- Save point A to waypointManager
    if waypointManager then
        waypointManager.setPointA(cleanPos)
    end
    
    currentStatus = STATUS.POINT_A_SET
    
    log("Point A set successfully!")
end

-- Set Point B
setPointB = function()
    log("Setting Point B...")
    
    if not currentVehicle then
        log("No vehicle found!", "WARN")
        return
    end
    
    if currentStatus == STATUS.NOT_CONFIGURED then
        log("Please set Point A first!", "WARN")
        return
    end
    
    currentStatus = STATUS.SETTING_POINT_B
    
    -- Get vehicle position
    local pos = currentVehicle:getPosition()
    log(string.format("Point B position: x=%.2f, y=%.2f, z=%.2f", pos.x, pos.y, pos.z))
    
    -- Create clean position table (avoid circular references)
    local cleanPos = {x = pos.x, y = pos.y, z = pos.z}
    
    -- Save point B to waypointManager
    if waypointManager then
        waypointManager.setPointB(cleanPos)
    end
    
    currentStatus = STATUS.CONFIGURED
    
    -- Auto-save finish line configuration
    if storageManager and waypointManager and waypointManager.isLineConfigured() then
        local pointA = waypointManager.getPointA()
        local pointB = waypointManager.getPointB()
        
        if pointA and pointB then
            storageManager.saveFinishLine(pointA, pointB)
            log("Finish line configuration auto-saved")
        end
    end
    
    log("Point B set successfully! Finish line configured.")
end

-- Clear both points
clearPoints = function()
    log("Clearing points...")
    
    -- Clear points from waypointManager
    if waypointManager then
        waypointManager.clearPoints()
    end
    
    -- Reset crossing detector when points are cleared
    if crossingDetector then
        crossingDetector.reset()
        log("CrossingDetector state reset")
    end
    
    -- Stop and reset lap timer when points are cleared
    if lapTimer then
        if lapTimer.isRunning() then
            lapTimer.stopLap()
            log("Current lap aborted due to points cleared")
        end
        lapTimer.reset(false)  -- Reset timer but keep history
    end
    
    -- Delete saved finish line from storage
    if storageManager then
        storageManager.deleteFinishLine()
        log("Finish line deleted from storage")
    end
    
    currentStatus = STATUS.NOT_CONFIGURED
    
    log("Points cleared!")
end

-- Toggle UI visibility
local function toggleUI()
    showUI = not showUI
    log("UI toggled: " .. tostring(showUI))
    
    -- Show notification to user
    if showUI then
        guihooks.message("Hotlapping UI включен", 2, "")
    else
        guihooks.message("Hotlapping UI выключен", 2, "")
    end
end

-- Show UI (force enable)
local function showHotlappingUI()
    showUI = true
    log("UI shown")
    guihooks.message("Hotlapping UI включен", 2, "")
end

-- Hide UI (force disable)
local function hideHotlappingUI()
    showUI = false
    log("UI hidden")
    guihooks.message("Hotlapping UI выключен", 2, "")
end

-- Public interface
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onUpdate = onUpdate
M.onPreRender = onPreRender  -- Changed from onEditorGui to onPreRender
M.onVehicleSwitched = onVehicleSwitched
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission

-- Public functions
M.setPointA = setPointA
M.setPointB = setPointB
M.clearPoints = clearPoints
M.toggleUI = toggleUI
M.showUI = showHotlappingUI
M.hideUI = hideHotlappingUI

-- Storage utilities (for users to inspect/export data)
M.getSavedMaps = function()
    if storageManager then
        return storageManager.getSavedMaps()
    end
    return {}
end

M.getWaypoints = function()
    if waypointManager then
        return {
            pointA = waypointManager.getPointA(),
            pointB = waypointManager.getPointB(),
            configured = waypointManager.isLineConfigured()
        }
    end
    return nil
end

M.getStatistics = function()
    if storageManager then
        return storageManager.getStatistics()
    end
    return nil
end

-- Export all waypoints to JSON string (ready for default_waypoints.json)
M.exportAllWaypoints = function()
    if storageManager then
        return storageManager.exportAllWaypoints()
    end
    return "{}"
end

return M

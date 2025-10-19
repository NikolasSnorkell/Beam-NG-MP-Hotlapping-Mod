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

-- Utility function for logging (defined early so loadModules can use it)
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[Hotlapping][%s] %s", level, message))
    end
end

-- Load sub-modules
local function loadModules()
    waypointManager = require('hotlapping_modules/WaypointManager')
    log("WaypointManager loaded")
    
    crossingDetector = require('hotlapping_modules/CrossingDetector')
    log("CrossingDetector loaded")
    
    lapTimer = require('hotlapping_modules/LapTimer')
    log("LapTimer loaded")
    
    -- TODO: Load other modules when ready
    -- storageManager = require('hotlapping_modules/StorageManager')
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
    if not showUI then return end
    if not isActive then return end
    
    local im = ui_imgui
    
    -- Main window
    local windowOpen = im.BoolPtr(true)
    local flags = im.WindowFlags_AlwaysAutoResize or 0
    
    if im.Begin("Hotlapping", windowOpen, flags) then
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
    currentStatus = STATUS.NOT_CONFIGURED
    
    log("Extension loaded successfully!")
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
    
    -- TODO: Load finish line configuration for this map
    -- TODO: Load lap history for this map
    
    currentVehicle = be:getPlayerVehicle(0)
    
    -- Set initial vehicle name for lap timer
    if lapTimer and currentVehicle then
        local vehicleName = currentVehicle:getJBeamFilename() or "unknown"
        lapTimer.setVehicle(vehicleName)
    end
end

-- Called when mission ends (leaving map)
local function onClientEndMission()
    log("Mission ended")
    
    -- TODO: Save current configuration
    -- TODO: Save lap history
    
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
    
    -- Save point A to waypointManager
    if waypointManager then
        waypointManager.setPointA(pos)
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
    
    -- Save point B to waypointManager
    if waypointManager then
        waypointManager.setPointB(pos)
    end
    
    currentStatus = STATUS.CONFIGURED
    
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
    
    currentStatus = STATUS.NOT_CONFIGURED
    
    log("Points cleared!")
end

-- Toggle UI visibility
local function toggleUI()
    showUI = not showUI
    log("UI toggled: " .. tostring(showUI))
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

return M

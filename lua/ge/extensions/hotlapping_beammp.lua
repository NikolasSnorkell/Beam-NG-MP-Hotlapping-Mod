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

-- Load sub-modules
local function loadModules()
    waypointManager = require('hotlapping_modules/WaypointManager')
    log("WaypointManager loaded")
    
    -- TODO: Load other modules when ready
    -- crossingDetector = require('hotlapping_modules/CrossingDetector')
    -- lapTimer = require('hotlapping_modules/LapTimer')
    -- storageManager = require('hotlapping_modules/StorageManager')
end

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

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[Hotlapping][%s] %s", level, message))
    end
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
        
        -- Timer section (placeholder)
        im.Text("Текущий круг:")
        im.SameLine()
        im.TextColored(im.ImVec4(0, 0.8, 1, 1), "00:00.000")
        
        im.Text("Лучший круг:")
        im.SameLine()
        im.TextColored(im.ImVec4(0.3, 1, 0.4, 1), "--:--.---")
        
        im.Separator()
        
        -- Lap history (placeholder)
        im.Text("История кругов")
        im.TextColored(im.ImVec4(0.5, 0.5, 0.5, 1), "Нет завершенных кругов")
    end
    
    -- ВАЖНО: End() всегда вызывается после Begin(), даже если Begin вернул false
    im.End()
end

-- Initialize extension
local function onExtensionLoaded()
    log("Extension loading...")
    
    -- Load sub-modules
    loadModules()
    
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
    
    -- TODO: Check for line crossing
    -- TODO: Update timer
end

-- Handle vehicle switch
local function onVehicleSwitched(oldId, newId, player)
    log(string.format("Vehicle switched from %s to %s", tostring(oldId), tostring(newId)))
    currentVehicle = be:getPlayerVehicle(0)
    
    -- TODO: Reset lap timer if running
end

-- Called when mission starts (map loaded)
local function onClientStartMission(levelPath)
    log("Mission started: " .. tostring(levelPath))
    
    -- TODO: Load finish line configuration for this map
    -- TODO: Load lap history for this map
    
    currentVehicle = be:getPlayerVehicle(0)
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

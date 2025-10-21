-- StorageManager.lua
-- Manages local storage for finish lines and lap history per map
-- Author: NikolasSnorkell
-- Version: 1.0.0

local M = {}

-- Settings keys
local SETTINGS_PREFIX = "hotlapping_"
local WAYPOINTS_KEY = SETTINGS_PREFIX .. "waypoints"
local LAP_HISTORY_KEY = SETTINGS_PREFIX .. "lap_history"
local SETTINGS_KEY = SETTINGS_PREFIX .. "settings"

-- Storage limits
local MAX_LAP_HISTORY_PER_MAP = 100 -- Maximum number of laps to keep per map

local debugMode = true

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[StorageManager][%s] %s", level, message))
    end
end

-- Safe JSON decoder wrapper for BeamNG's built-in jsonDecode
function M.safeJsonDecode(str)
    if not str or str == "" then
        return nil
    end

    -- BeamNG имеет встроенную глобальную функцию jsonDecode
    -- Оборачиваем в pcall для безопасности
    local success, result = pcall(function()
        return jsonDecode(str)
    end)

    if success and result then
        return result
    end

    log("Failed to decode JSON: " .. tostring(result), "ERROR")
    if debugMode and str then
        log("Attempted to decode: " .. str:sub(1, 100) .. "...", "DEBUG")
    end
    return nil
end

-- Safe JSON encoder wrapper for BeamNG's built-in jsonEncode
local function safeJsonEncode(data)
    if data == nil then
        return "null"
    end

    -- BeamNG имеет встроенную глобальную функцию jsonEncode
    -- Она уже защищена от циклических ссылок
    local success, result = pcall(function()
        return jsonEncode(data)
    end)

    if success and result then
        return result
    end

    log("Failed to encode JSON: " .. tostring(result), "ERROR")
    return nil
end

-- Get current map name
local function getCurrentMapName()
    -- Get the level path and extract map name
    local levelPath = getMissionFilename()

    if not levelPath or levelPath == "" then
        log("No mission loaded, cannot get map name", "WARN")
        return nil
    end

    -- Extract map name from path
    -- Example: "levels/west_coast_usa/main.level.json" -> "west_coast_usa"
    local mapName = levelPath:match("levels/([^/]+)/")

    if not mapName then
        log("Could not extract map name from: " .. tostring(levelPath), "WARN")
        return "unknown"
    end

    log("Current map: " .. mapName)
    return mapName
end

-- Load all waypoints data from storage
local function loadAllWaypoints()
    local dataStr = settings.getValue(WAYPOINTS_KEY)

    if not dataStr or dataStr == "" then
        log("No waypoints data found in storage")
        return {}
    end

    local data = M.safeJsonDecode(dataStr)

    if not data then
        log("Failed to parse waypoints data", "ERROR")
        return {}
    end

    log(string.format("Loaded waypoints for %d maps", table.getn(data) or 0))
    return data
end

-- Save all waypoints data to storage
local function saveAllWaypoints(data)
    -- Debug: print structure before encoding
    if debugMode then
        log("=== Attempting to save waypoints ===")
        for mapName, waypoints in pairs(data) do
            log(string.format("Map: %s", mapName))
            if waypoints.pointA then
                log(string.format("  pointA: x=%.2f, y=%.2f, z=%.2f",
                    waypoints.pointA.x or 0, waypoints.pointA.y or 0, waypoints.pointA.z or 0))
            end
            if waypoints.pointB then
                log(string.format("  pointB: x=%.2f, y=%.2f, z=%.2f",
                    waypoints.pointB.x or 0, waypoints.pointB.y or 0, waypoints.pointB.z or 0))
            end
        end
    end

    -- Try to encode with error handling
    local dataStr = safeJsonEncode(data)

    if not dataStr then
        log("Failed to encode waypoints data", "ERROR")
        return false
    end

    settings.setValue(WAYPOINTS_KEY, dataStr)
    log("Waypoints data saved to storage")
    return true
end

-- Load all lap history data from storage
local function loadAllLapHistory()
    local dataStr = settings.getValue(LAP_HISTORY_KEY)

    if not dataStr or dataStr == "" then
        log("No lap history data found in storage")
        return {}
    end

    local data = M.safeJsonDecode(dataStr)

    if not data then
        log("Failed to parse lap history data", "ERROR")
        return {}
    end

    log(string.format("Loaded lap history for %d maps", table.getn(data) or 0))
    return data
end

-- Save all lap history data to storage
local function saveAllLapHistory(data)
    -- Try to encode with error handling
    local dataStr = safeJsonEncode(data)

    if not dataStr then
        log("Failed to encode lap history data", "ERROR")
        return false
    end

    settings.setValue(LAP_HISTORY_KEY, dataStr)
    log("Lap history data saved to storage")
    return true
end

-- Save finish line configuration for current map
---@param pointA table Point A coordinates {x, y, z}
---@param pointB table Point B coordinates {x, y, z}
---@param mapName string|nil Optional map name (uses current map if not provided)
---@return boolean Success status
function M.saveFinishLine(pointA, pointB, mapName)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot save finish line: no map name", "ERROR")
        return false
    end

    if not pointA or not pointB then
        log("Cannot save finish line: missing points", "ERROR")
        return false
    end

    -- Load all waypoints
    local allWaypoints = loadAllWaypoints()

    -- Save waypoints for this map
    allWaypoints[mapName] = {
        pointA = {
            x = pointA.x,
            y = pointA.y,
            z = pointA.z
        },
        pointB = {
            x = pointB.x,
            y = pointB.y,
            z = pointB.z
        },
        savedAt = os.date("%Y-%m-%d %H:%M:%S")
    }

    -- Save back to storage
    local success = saveAllWaypoints(allWaypoints)

    if success then
        log(string.format("Finish line saved for map: %s", mapName))
    end

    return success
end

-- Load finish line configuration for current map
---@param mapName string|nil Optional map name (uses current map if not provided)
---@return table|nil Waypoints data {pointA, pointB} or nil if not found
function M.loadFinishLine(mapName)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot load finish line: no map name", "ERROR")
        return nil
    end

    -- Load all waypoints
    local allWaypoints = loadAllWaypoints()
    if not allWaypoints then
        log(string.format("No waypoints found in storage"), "ERROR")
        return nil
    end
    -- Get waypoints for this map
    local waypoints = allWaypoints[mapName]

    if not waypoints then
        log(string.format("No finish line found for map: %s", mapName))
        return nil
    end

    log(string.format("Finish line loaded for map: %s (saved at: %s)",
        mapName, waypoints.savedAt or "unknown"))

    return {
        pointA = waypoints.pointA,
        pointB = waypoints.pointB
    }
end

-- Delete finish line configuration for current map
---@param mapName string|nil Optional map name (uses current map if not provided)
---@return boolean Success status
function M.deleteFinishLine(mapName)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot delete finish line: no map name", "ERROR")
        return false
    end

    -- Load all waypoints
    local allWaypoints = loadAllWaypoints()

    -- Remove waypoints for this map
    allWaypoints[mapName] = nil

    -- Save back to storage
    local success = saveAllWaypoints(allWaypoints)

    if success then
        log(string.format("Finish line deleted for map: %s", mapName))
    end

    return success
end

-- Save lap history for current map
---@param laps table Array of lap records
---@param mapName string|nil Optional map name (uses current map if not provided)
---@return boolean Success status
function M.saveLapHistory(laps, mapName)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot save lap history: no map name", "ERROR")
        return false
    end

    if not laps or type(laps) ~= "table" then
        log("Cannot save lap history: invalid laps data", "ERROR")
        return false
    end

    -- Load all lap history
    local allHistory = loadAllLapHistory()

    -- Limit number of laps stored
    local lapsToSave = {}
    local startIdx = math.max(1, #laps - MAX_LAP_HISTORY_PER_MAP + 1)

    for i = startIdx, #laps do
        table.insert(lapsToSave, laps[i])
    end

    -- Calculate best lap
    local bestLapTime = nil
    for _, lap in ipairs(laps) do
        if not bestLapTime or lap.time < bestLapTime then
            bestLapTime = lap.time
        end
    end

    -- Save history for this map
    allHistory[mapName] = {
        laps = lapsToSave,
        bestLapTime = bestLapTime,
        totalLaps = #laps,
        savedAt = os.date("%Y-%m-%d %H:%M:%S")
    }

    -- Save back to storage
    local success = saveAllLapHistory(allHistory)

    if success then
        log(string.format("Lap history saved for map: %s (%d laps, best: %.3fs)",
            mapName, #lapsToSave, bestLapTime or 0))
    end

    return success
end

-- Load lap history for current map
---@param mapName string|nil Optional map name (uses current map if not provided)
---@return table|nil Lap history data {laps, bestLapTime, totalLaps} or nil if not found
function M.loadLapHistory(mapName)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot load lap history: no map name", "ERROR")
        return nil
    end

    -- Load all lap history
    local allHistory = loadAllLapHistory()

    -- Get history for this map
    local history = allHistory[mapName]

    if not history then
        log(string.format("No lap history found for map: %s", mapName))
        return nil
    end

    log(string.format("Lap history loaded for map: %s (%d laps, best: %.3fs)",
        mapName, #(history.laps or {}), history.bestLapTime or 0))

    return history
end

-- Delete lap history for current map
---@param mapName string|nil Optional map name (uses current map if not provided)
---@return boolean Success status
function M.deleteLapHistory(mapName)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot delete lap history: no map name", "ERROR")
        return false
    end

    -- Load all lap history
    local allHistory = loadAllLapHistory()

    -- Remove history for this map
    allHistory[mapName] = nil

    -- Save back to storage
    local success = saveAllLapHistory(allHistory)

    if success then
        log(string.format("Lap history deleted for map: %s", mapName))
    end

    return success
end

-- Get list of all maps with saved data
---@return table List of map names with saved waypoints or lap history
function M.getSavedMaps()
    local allWaypoints = loadAllWaypoints()
    local allHistory = loadAllLapHistory()

    local maps = {}
    local mapSet = {}

    -- Add maps with waypoints
    for mapName, _ in pairs(allWaypoints) do
        if not mapSet[mapName] then
            table.insert(maps, mapName)
            mapSet[mapName] = true
        end
    end

    -- Add maps with lap history
    for mapName, _ in pairs(allHistory) do
        if not mapSet[mapName] then
            table.insert(maps, mapName)
            mapSet[mapName] = true
        end
    end

    table.sort(maps)

    log(string.format("Found %d maps with saved data", #maps))
    return maps
end

-- Export lap history to JSON file
---@param mapName string|nil Optional map name (uses current map if not provided)
---@param filePath string|nil Optional file path (default: "hotlapping_export_<mapname>.json")
---@return boolean Success status
function M.exportLapHistory(mapName, filePath)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot export lap history: no map name", "ERROR")
        return false
    end

    -- Load history for this map
    local history = M.loadLapHistory(mapName)

    if not history then
        log("No lap history to export", "WARN")
        return false
    end

    -- Generate default file path if not provided
    filePath = filePath or string.format("/hotlapping_export_%s.json", mapName)

    -- Prepare export data
    local exportData = {
        map = mapName,
        exportedAt = os.date("%Y-%m-%d %H:%M:%S"),
        totalLaps = history.totalLaps,
        bestLapTime = history.bestLapTime,
        laps = history.laps
    }

    -- Encode to JSON
    local jsonData = safeJsonEncode(exportData)

    if not jsonData then
        log("Failed to encode export data", "ERROR")
        return false
    end

    -- Write to file
    local file = io.open(filePath, "w")
    if not file then
        log(string.format("Failed to open file for writing: %s", filePath), "ERROR")
        return false
    end

    file:write(jsonData)
    file:close()

    log(string.format("Lap history exported to: %s", filePath))
    return true
end

-- Import lap history from JSON file
---@param filePath string Path to JSON file
---@param mapName string|nil Optional map name (uses current map if not provided)
---@return boolean Success status
function M.importLapHistory(filePath, mapName)
    mapName = mapName or getCurrentMapName()

    if not mapName then
        log("Cannot import lap history: no map name", "ERROR")
        return false
    end

    -- Read file
    local file = io.open(filePath, "r")
    if not file then
        log(string.format("Failed to open file for reading: %s", filePath), "ERROR")
        return false
    end

    local jsonData = file:read("*all")
    file:close()

    -- Decode JSON
    local importData = M.safeJsonDecode(jsonData)

    if not importData or not importData.laps then
        log("Invalid import data", "ERROR")
        return false
    end

    -- Save imported history
    local success = M.saveLapHistory(importData.laps, mapName)

    if success then
        log(string.format("Lap history imported from: %s (%d laps)", filePath, #importData.laps))
    end

    return success
end

-- Save mod settings
---@param settingsData table Settings to save
---@return boolean Success status
function M.saveSettings(settingsData)
    if not settingsData or type(settingsData) ~= "table" then
        log("Cannot save settings: invalid data", "ERROR")
        return false
    end

    local dataStr = safeJsonEncode(settingsData)

    if not dataStr then
        log("Failed to encode settings data", "ERROR")
        return false
    end

    settings.setValue(SETTINGS_KEY, dataStr)
    log("Mod settings saved")
    return true
end

-- Load mod settings
---@return table|nil Settings data or nil if not found
function M.loadSettings()
    local dataStr = settings.getValue(SETTINGS_KEY)

    if not dataStr or dataStr == "" then
        log("No settings data found")
        return nil
    end

    local data = M.safeJsonDecode(dataStr)

    if not data then
        log("Failed to parse settings data", "ERROR")
        return nil
    end

    log("Mod settings loaded")
    return data
end

-- Clear all stored data (waypoints, lap history, settings)
---@return boolean Success status
function M.clearAllData()
    settings.setValue(WAYPOINTS_KEY, "")
    settings.setValue(LAP_HISTORY_KEY, "")
    settings.setValue(SETTINGS_KEY, "")

    log("All stored data cleared")
    return true
end

-- Export all waypoints to default_waypoints.json format
---@return string JSON string with all waypoints
function M.exportAllWaypoints()
    local allWaypoints = loadAllWaypoints()

    local exportData = {
        version = "1.0",
        description = "Exported waypoint configurations",
        waypoints = {}
    }

    local mapCount = 0
    for mapName, waypoints in pairs(allWaypoints) do
        exportData.waypoints[mapName] = {
            displayName = mapName, -- Можно заменить на человекочитаемое имя
            pointA = waypoints.pointA,
            pointB = waypoints.pointB,
            description = "Auto-exported from saved waypoints"
        }
        mapCount = mapCount + 1
    end

    local jsonData = safeJsonEncode(exportData)
    log(string.format("Exported waypoints for %d maps", mapCount))

    return jsonData or ""
end

-- Export all waypoints to file
---@param filePath string|nil Optional file path (default: /temp/exported_waypoints.json)
---@return boolean Success status
function M.exportAllWaypointsToFile(filePath)
    filePath = filePath or "/temp/exported_waypoints.json"

    local jsonData = M.exportAllWaypoints()

    -- Write to file
    local file = io.open(filePath, "w")
    if not file then
        log(string.format("Failed to open file for writing: %s", filePath), "ERROR")
        return false
    end

    file:write(jsonData)
    file:close()

    log(string.format("All waypoints exported to: %s", filePath))
    return true
end

-- Enable/disable debug mode
---@param enabled boolean Enable or disable debug logging
function M.setDebugMode(enabled)
    debugMode = enabled
end

-- Get current map name (public API)
---@return string|nil Map name or nil if no mission loaded
function M.getCurrentMapName()
    return getCurrentMapName()
end

-- Get storage statistics
---@return table Statistics about stored data
function M.getStatistics()
    local allWaypoints = loadAllWaypoints()
    local allHistory = loadAllLapHistory()

    local waypointCount = 0
    local historyCount = 0
    local totalLaps = 0

    for _, _ in pairs(allWaypoints) do
        waypointCount = waypointCount + 1
    end

    for _, history in pairs(allHistory) do
        historyCount = historyCount + 1
        totalLaps = totalLaps + (history.totalLaps or 0)
    end

    return {
        mapsWithWaypoints = waypointCount,
        mapsWithHistory = historyCount,
        totalStoredLaps = totalLaps,
        savedMaps = M.getSavedMaps()
    }
end

return M

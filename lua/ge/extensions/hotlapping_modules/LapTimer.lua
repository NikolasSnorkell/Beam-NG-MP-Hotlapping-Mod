-- LapTimer.lua
-- Manages lap timing and lap history
-- Author: NikolasSnorkell

local M = {}

-- Timer states
local TimerState = {
    STOPPED = "stopped",
    RUNNING = "running",
    PAUSED = "paused"
}

-- State variables
local currentState = TimerState.STOPPED
local lapStartTime = 0
local currentLapTime = 0
local lapHistory = {}
local lapCounter = 0
local bestLapTime = nil
local lastLapTime = nil
local debugMode = true

-- Current vehicle name (for history tracking)
local currentVehicleName = "unknown"

-- Callbacks
local onLapCompletedCallback = nil
local onLapStartedCallback = nil

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[LapTimer][%s] %s", level, message))
    end
end

-- Format time as MM:SS.mmm
---@param seconds number Time in seconds
---@return string Formatted time string
local function formatTime(seconds)
    if not seconds or seconds < 0 then
        return "00:00.000"
    end
    
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    
    return string.format("%02d:%06.3f", minutes, secs)
end

-- Calculate time delta (difference between two times)
---@param time1 number First time in seconds
---@param time2 number Second time in seconds
---@return string Formatted delta string with +/- sign
local function formatDelta(time1, time2)
    if not time1 or not time2 then
        return "+0.000"
    end
    
    local delta = time1 - time2
    local sign = delta >= 0 and "+" or ""
    
    return string.format("%s%.3f", sign, delta)
end

-- Get current timestamp as string
---@return string Timestamp in format "YYYY-MM-DD HH:MM:SS"
local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Start a new lap
function M.startLap()
    if currentState == TimerState.RUNNING then
        log("Lap already running, ignoring startLap call", "WARN")
        return false
    end
    
    lapStartTime = os.clock()
    currentState = TimerState.RUNNING
    currentLapTime = 0
    lapCounter = lapCounter + 1
    
    log(string.format("Lap #%d started", lapCounter))
    
    -- Trigger callback
    if onLapStartedCallback then
        onLapStartedCallback(lapCounter)
    end
    
    return true
end

-- Complete current lap and record the time
function M.completeLap()
    if currentState ~= TimerState.RUNNING then
        log("Timer not running, cannot complete lap", "WARN")
        return nil
    end
    
    -- Calculate lap time
    local endTime = os.clock()
    local lapTime = endTime - lapStartTime
    
    -- Create lap record
    local lapRecord = {
        lapNumber = lapCounter,
        time = lapTime,
        timestamp = getTimestamp(),
        vehicle = currentVehicleName
    }
    
    -- Add to history
    table.insert(lapHistory, lapRecord)
    
    -- Update best lap
    if not bestLapTime or lapTime < bestLapTime then
        bestLapTime = lapTime
        log(string.format("New best lap! Time: %s", formatTime(lapTime)))
    end
    
    lastLapTime = lapTime
    
    log(string.format("Lap #%d completed: %s", lapCounter, formatTime(lapTime)))
    
    -- Trigger callback
    if onLapCompletedCallback then
        onLapCompletedCallback(lapRecord)
    end
    
    -- Reset for next lap
    currentState = TimerState.STOPPED
    
    return lapRecord
end

-- Stop current lap without recording (abort)
function M.stopLap()
    if currentState ~= TimerState.RUNNING then
        log("Timer not running", "WARN")
        return false
    end
    
    currentState = TimerState.STOPPED
    currentLapTime = 0
    log("Lap stopped (aborted)")
    
    return true
end

-- Pause the timer
function M.pause()
    if currentState ~= TimerState.RUNNING then
        log("Timer not running, cannot pause", "WARN")
        return false
    end
    
    -- Save current lap time
    currentLapTime = os.clock() - lapStartTime
    currentState = TimerState.PAUSED
    log("Timer paused")
    
    return true
end

-- Resume the timer from paused state
function M.resume()
    if currentState ~= TimerState.PAUSED then
        log("Timer not paused, cannot resume", "WARN")
        return false
    end
    
    -- Adjust start time to account for paused duration
    lapStartTime = os.clock() - currentLapTime
    currentState = TimerState.RUNNING
    log("Timer resumed")
    
    return true
end

-- Get current lap time (updates in real-time while running)
---@return number|nil Current lap time in seconds, or nil if not running
function M.getCurrentTime()
    if currentState == TimerState.RUNNING then
        return os.clock() - lapStartTime
    elseif currentState == TimerState.PAUSED then
        return currentLapTime
    else
        return nil
    end
end

-- Get formatted current lap time
---@return string Formatted time string
function M.getCurrentTimeFormatted()
    local time = M.getCurrentTime()
    if time then
        return formatTime(time)
    else
        return "00:00.000"
    end
end

-- Reset timer and optionally clear history
---@param clearHistory boolean|nil If true, also clears lap history
function M.reset(clearHistory)
    currentState = TimerState.STOPPED
    lapStartTime = 0
    currentLapTime = 0
    lapCounter = 0
    lastLapTime = nil
    
    if clearHistory then
        lapHistory = {}
        bestLapTime = nil
        log("Timer reset with history cleared")
    else
        log("Timer reset (history preserved)")
    end
end

-- Get current timer state
---@return string State: "stopped", "running", or "paused"
function M.getState()
    return currentState
end

-- Check if timer is running
---@return boolean True if timer is running
function M.isRunning()
    return currentState == TimerState.RUNNING
end

-- Check if timer is paused
---@return boolean True if timer is paused
function M.isPaused()
    return currentState == TimerState.PAUSED
end

-- Get lap history
---@return table Array of lap records
function M.getLapHistory()
    return lapHistory
end

-- Get specific lap by number
---@param lapNumber number Lap number to retrieve
---@return table|nil Lap record or nil if not found
function M.getLap(lapNumber)
    for _, lap in ipairs(lapHistory) do
        if lap.lapNumber == lapNumber then
            return lap
        end
    end
    return nil
end

-- Get best lap record
---@return table|nil Best lap record or nil if no laps completed
function M.getBestLap()
    if not bestLapTime then
        return nil
    end
    
    -- Find the lap with best time
    for _, lap in ipairs(lapHistory) do
        if lap.time == bestLapTime then
            return lap
        end
    end
    
    return nil
end

-- Get best lap time
---@return number|nil Best lap time in seconds, or nil if no laps
function M.getBestLapTime()
    return bestLapTime
end

-- Get best lap time formatted
---@return string Formatted best lap time
function M.getBestLapTimeFormatted()
    if bestLapTime then
        return formatTime(bestLapTime)
    else
        return "--:--.---"
    end
end

-- Get last lap time
---@return number|nil Last lap time in seconds, or nil if no laps
function M.getLastLapTime()
    return lastLapTime
end

-- Get last lap time formatted
---@return string Formatted last lap time
function M.getLastLapTimeFormatted()
    if lastLapTime then
        return formatTime(lastLapTime)
    else
        return "--:--.---"
    end
end

-- Get lap count
---@return number Total number of completed laps
function M.getLapCount()
    return #lapHistory
end

-- Get current lap number
---@return number Current lap number (starts at 1)
function M.getCurrentLapNumber()
    return lapCounter
end

-- Clear lap history
function M.clearHistory()
    lapHistory = {}
    bestLapTime = nil
    lastLapTime = nil
    lapCounter = 0
    log("Lap history cleared")
end

-- Set vehicle name for history tracking
---@param vehicleName string Name of the vehicle
function M.setVehicle(vehicleName)
    currentVehicleName = vehicleName or "unknown"
    log(string.format("Vehicle set to: %s", currentVehicleName))
end

-- Get statistics
---@return table Statistics table with various metrics
function M.getStatistics()
    local totalLaps = #lapHistory
    
    if totalLaps == 0 then
        return {
            totalLaps = 0,
            bestTime = nil,
            averageTime = nil,
            totalTime = 0
        }
    end
    
    -- Calculate total and average time
    local totalTime = 0
    for _, lap in ipairs(lapHistory) do
        totalTime = totalTime + lap.time
    end
    
    local averageTime = totalTime / totalLaps
    
    return {
        totalLaps = totalLaps,
        bestTime = bestLapTime,
        averageTime = averageTime,
        totalTime = totalTime,
        bestTimeFormatted = formatTime(bestLapTime),
        averageTimeFormatted = formatTime(averageTime),
        totalTimeFormatted = formatTime(totalTime)
    }
end

-- Set callback for lap completion
---@param callback function Function to call when lap is completed
function M.setOnLapCompletedCallback(callback)
    onLapCompletedCallback = callback
end

-- Set callback for lap start
---@param callback function Function to call when lap is started
function M.setOnLapStartedCallback(callback)
    onLapStartedCallback = callback
end

-- Enable/disable debug mode
---@param enabled boolean Enable or disable debug logging
function M.setDebugMode(enabled)
    debugMode = enabled
end

-- Export format time function for external use
M.formatTime = formatTime
M.formatDelta = formatDelta

-- Export state enum
M.TimerState = TimerState

return M

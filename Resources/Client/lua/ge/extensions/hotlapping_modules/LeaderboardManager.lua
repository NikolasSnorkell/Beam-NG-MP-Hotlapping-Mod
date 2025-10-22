-- LeaderboardManager.lua
-- Manages leaderboard data and server communication for multiplayer
-- Author: NikolasSnorkell
-- Version: 1.0.0

local M = {}

local debugMode = true

-- Leaderboard data structures
local leaderboardData = {
    bestTimes = {},   -- Лучшие времена игроков: {playerName: {time, vehicle, timestamp}}
    recentTimes = {}, -- Последние 3 круга каждого игрока: {playerName: [{time, vehicle, timestamp}...]}
    lastUpdate = 0    -- Timestamp последнего обновления
}

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[LeaderboardManager][%s] %s", level, message))
    end
end

-- Functions for leaderboard data management
function M.updatePlayerBestTime(data)
    if not data then
        log("No data provided for updating best time", "WARN")
        return false
    end


    for playerName, lapData in pairs(data.leaderboard) do
        leaderboardData.bestTimes[playerName] = { time = lapData.time, vehicle = lapData.vehicle }
        print("[LeaderboardManager] Server data " .. playerName .. " time: " .. lapData.time .. " vehicle: " .. lapData.vehicle)
    end
    print("[LeaderboardManager] Best times updated from server data ")
    return false
    -- if not leaderboardData.bestTimes[playerName] or
    --     leaderboardData.bestTimes[playerName].time > time then
    --     leaderboardData.bestTimes[playerName] = {
    --         time = time,
    --         vehicle = vehicle,
    --         timestamp = os.date("%Y-%m-%d %H:%M:%S")
    --     }
    --     leaderboardData.lastUpdate = os.time()
    --     log(string.format("Updated best time for %s: %.3fs", playerName, time))
    --     return true -- Новый рекорд
    -- end
    -- return false
end

function M.addPlayerRecentTime(playerName, time, vehicle)
    if not leaderboardData.recentTimes[playerName] then
        leaderboardData.recentTimes[playerName] = {}
    end

    local recentList = leaderboardData.recentTimes[playerName]
    table.insert(recentList, {
        time = time,
        vehicle = vehicle,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    })

    -- Ограничиваем до 3 последних кругов
    while #recentList > 3 do
        table.remove(recentList, 1)
    end

    leaderboardData.lastUpdate = os.time()
    log(string.format("Added recent time for %s: %.3fs", playerName, time))
end

function M.clearLeaderboardData()
    leaderboardData.bestTimes = {}
    leaderboardData.recentTimes = {}
    leaderboardData.lastUpdate = os.time()
    log("Leaderboard data cleared")
end

-- Getters for leaderboard data
function M.getBestTimes()
    return leaderboardData.bestTimes
end

function M.getRecentTimes()
    return leaderboardData.recentTimes
end

function M.getLastUpdate()
    return leaderboardData.lastUpdate
end

-- JSON formats for server communication
function M.createLeaderboardUpdateMessage(mapName, playerName, time, vehicle, isNewBest)
    return {
        event = "hotlapping_lap_time",
        mapName = mapName,
        playerName = playerName,
        time = time,
        vehicle = vehicle,
        isNewBest = isNewBest,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
end

function M.createLeaderboardRequestMessage(mapName)
    return {
        event = "hotlapping_request_leaderboard",
        mapName = mapName
    }
end

-- Server response data processing
function M.processLeaderboardUpdate(data)
    if not data or not data.leaderboard then
        log("Invalid leaderboard data received", "ERROR")
        return false
    end

    -- Обновляем локальные данные лидерборда
    if data.leaderboard.bestTimes then
        for playerName, record in pairs(data.leaderboard.bestTimes) do
            leaderboardData.bestTimes[playerName] = record
        end
    end

    if data.leaderboard.recentTimes then
        for playerName, records in pairs(data.leaderboard.recentTimes) do
            leaderboardData.recentTimes[playerName] = records
        end
    end

    leaderboardData.lastUpdate = os.time()
    log("Leaderboard updated from server")
    return true
end

-- Get sorted leaderboard for display
function M.getSortedBestTimes()
    local sorted = {}

    for playerName, record in pairs(leaderboardData.bestTimes) do
        table.insert(sorted, {
            playerName = playerName,
            time = record.time,
            vehicle = record.vehicle,
            timestamp = record.timestamp
        })
    end

    -- Сортируем по времени (лучшие сверху)
    table.sort(sorted, function(a, b)
        return a.time < b.time
    end)

    return sorted
end

-- Get formatted leaderboard data for UI display
function M.getFormattedBestTimes(maxCount)
    maxCount = maxCount or 10
    local sorted = M.getSortedBestTimes()
    local formatted = {}

    for i = 1, math.min(#sorted, maxCount) do
        local record = sorted[i]
        table.insert(formatted, {
            position = i,
            playerName = record.playerName,
            timeText = string.format("%.3f", record.time),
            vehicle = record.vehicle,
            timestamp = record.timestamp,
            deltaText = i == 1 and "" or string.format("+%.3f", record.time - sorted[1].time)
        })
    end

    return formatted
end

-- Enable/disable debug mode
function M.setDebugMode(enabled)
    debugMode = enabled
end

return M

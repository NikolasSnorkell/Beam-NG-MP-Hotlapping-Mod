-- UIManager.lua
-- Manages all ImGui user interface functionality for Hotlapping mod
-- Author: NikolasSnorkell
-- Version: 1.0.0

local M = {}

local debugMode = false
local showUI = true
local uiRenderCount = 0

-- Dependencies (will be injected)
local waypointManager = nil
local lapTimer = nil
local multiplayerManager = nil
local leaderboardManager = nil

local LEADERBOARD_TABS = {
    BEST_TIMES = 1,
    RECENT_LAPS = 2
}

local currentLeaderboardTab = LEADERBOARD_TABS.BEST_TIMES

-- Status enum
local STATUS = {
    NOT_CONFIGURED = "not_configured",
    POINT_A_SET = "point_a_set",
    CONFIGURED = "configured",
    SETTING_POINT_A = "setting_point_a",
    SETTING_POINT_B = "setting_point_b"
}

local currentStatus = STATUS.NOT_CONFIGURED

-- Callbacks for UI actions (will be set by main module)
local onSetPointA = nil
local onSetPointB = nil
local onClearPoints = nil
local onDebugModeChanged = nil

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[UIManager][%s] %s", level, message))
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

-- Get status color based on current status
local function getStatusColor()
    if currentStatus == STATUS.NOT_CONFIGURED then
        return { 0.8, 0.8, 0.8, 1 } -- Gray
    elseif currentStatus == STATUS.POINT_A_SET then
        return { 1, 0.8, 0, 1 }     -- Orange
    elseif currentStatus == STATUS.CONFIGURED then
        return { 0, 1, 0, 1 }       -- Green
    elseif currentStatus == STATUS.SETTING_POINT_A or currentStatus == STATUS.SETTING_POINT_B then
        return { 1, 1, 0, 1 }       -- Yellow
    end
    return { 1, 1, 1, 1 }           -- White fallback
end

-- Update status from WaypointManager
local function updateStatusFromWaypoints()
    if not waypointManager then
        log("updateStatusFromWaypoints: waypointManager not available", "WARN")
        return
    end

    local pointA = waypointManager.getPointA()
    local pointB = waypointManager.getPointB()

    if not pointA and not pointB then
        currentStatus = STATUS.NOT_CONFIGURED
    elseif pointA and not pointB then
        currentStatus = STATUS.POINT_A_SET
    elseif pointA and pointB then
        currentStatus = STATUS.CONFIGURED
    end

    log(string.format("Status updated from waypoints: %s", currentStatus))
end

-- Main UI rendering function
function M.renderUI(dt)
    if not showUI then return end

    -- Debug logging (только первые 3 вызова)
    uiRenderCount = uiRenderCount + 1
    if uiRenderCount <= 3 then
        log(string.format("renderUI called (count: %d, status: %s)", uiRenderCount, currentStatus))
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

        -- Multiplayer status
        if multiplayerManager then
            local mpMode = multiplayerManager.getOperationMode()
            local mpColor = mpMode == "multiplayer" and { 0, 1, 0, 1 } or { 0.7, 0.7, 0.7, 1 }
            im.Text("Режим:")
            im.SameLine()
            im.TextColored(im.ImVec4(mpColor[1], mpColor[2], mpColor[3], mpColor[4]),
                mpMode == "multiplayer" and "Мультиплеер" or "Одиночная игра")
        end

        im.Separator()

        M.renderControlButtons(im)
        M.renderTimerSection(im)
        M.renderLapHistorySection(im)
    end
    im.End()


    -- Leaderboard window
    -- if im.Begin("Hotlapping##HotlappingLeaderboard", nil, flags) then
    --     -- Leaderboard content goes here
    --     im.Text("Таблица лидеров:")
    --     im.Separator()
    --     -- Example leaderboard entries
    --     -- for i = 1, 5 do
    --         im.Text(string.format("Игрок %d: %d секунд", 1, 70))
    --     -- end

    --     -- Multiplayer status
    --     if multiplayerManager and leaderboardManager then
    --         local bestTimes = leaderboardManager.getBestTimes()
    --         local index = 1
    --         for playerName, data in pairs(bestTimes) do

    --             -- log(string.format("[UI Manager] Leaderboard entry: %s - %d seconds (%s)", playerName, data.time, data.vehicle))
    --             -- leaderboardData.bestTimes[playerName] = record
    --             --   bestTimes[playerName] = { time = lapData.time, vehicle = lapData.vehicle }
    --                im.Text("#"..index.." Игрок: " .. playerName .. " Время: " .. data.time .. " Транспорт: " .. data.vehicle)
    --                index = index + 1
    --         end
    --         -- im.SameLine()
    --         -- im.TextColored(im.ImVec4(mpColor[1], mpColor[2], mpColor[3], mpColor[4]),
    --         --     mpMode == "multiplayer" and "Мультиплеер" or "Одиночная игра")
    --     end

    --     -- im.Separator()
    -- end


    -- Leaderboard window
    if im.Begin("Hotlapping Leaderboard##HotlappingLeaderboard", nil, flags) then
        -- Tabs
        if im.BeginTabBar("LeaderboardTabs") then
            -- Tab 1: Best Times
            if im.BeginTabItem("Лучшие времена") then
                currentLeaderboardTab = LEADERBOARD_TABS.BEST_TIMES
                M.renderBestTimesTab(im)
                im.EndTabItem()
            end

            -- Tab 2: Recent Laps
            if im.BeginTabItem("Последние круги") then
                currentLeaderboardTab = LEADERBOARD_TABS.RECENT_LAPS
                M.renderRecentLapsTab(im)
                im.EndTabItem()
            end

            im.EndTabBar()
        end
    end
    im.End()

end

-- Render Best Times tab
function M.renderBestTimesTab(im)
    if not leaderboardManager then
        im.Text("Leaderboard не доступен")
        return
    end
    
    local bestTimes = leaderboardManager.getBestTimesArray()
    
    if not bestTimes or #bestTimes == 0 then
        im.Text("Нет данных")
        return
    end
    
    -- Table header
    if im.BeginTable("BestTimesTable", 4, im.TableFlags_Borders) then
        im.TableSetupColumn("#", im.TableColumnFlags_WidthFixed, 30)
        im.TableSetupColumn("Игрок", im.TableColumnFlags_WidthFixed, 150)
        im.TableSetupColumn("Время", im.TableColumnFlags_WidthFixed, 100)
        im.TableSetupColumn("Транспорт", im.TableColumnFlags_WidthFixed, 120)
        im.TableHeadersRow()
        
        -- Table rows
        for i, entry in ipairs(bestTimes) do
            im.TableNextRow()
            
            im.TableNextColumn()
            im.Text(tostring(i))
            
            im.TableNextColumn()
            im.Text(entry.playerName or "Unknown")
            
            im.TableNextColumn()
            local color = i == 1 and im.ImVec4(0, 1, 0, 1) or im.ImVec4(1, 1, 1, 1)
            -- im.TextColored(color, string.format("%.3f", entry.time))
            im.TextColored(color, lapTimer.formatTime(entry.time) )
            
            im.TableNextColumn()
            im.Text(entry.vehicle or "N/A")
        end
        
        im.EndTable()
    end
end

-- Render Recent Laps tab
function M.renderRecentLapsTab(im)
    if not leaderboardManager then
        im.Text("Leaderboard не доступен")
        return
    end
    
    local recentLaps = leaderboardManager.getRecentLapsArray()
    
    if not recentLaps or not next(recentLaps) then
        im.Text("Нет последних кругов")
        return
    end
    
    -- Display each player's recent laps
    for playerName, laps in pairs(recentLaps) do
        im.Text("Игрок: " .. playerName)
        im.Indent(20)
        
        for i, lap in ipairs(laps) do
            -- im.Text(string.format("  Круг #%d: %.3f мин (%s)", 
            --     lap.lapNumber or i, 
            --     string.format("%.3f", lap.time), 
            --     lap.vehicle or "N/A"))
             im.Text("Круг #" .. (lap.lapNumber or i) .. " Время: " .. lapTimer.formatTime(lap.time) .. " Авто: " .. (lap.vehicle or "N/A"))   
        end
        
        im.Unindent(20)
        im.Separator()
    end
end

-- Render control buttons section
function M.renderControlButtons(im)
    -- Control buttons
    if im.Button("Установить точку А", im.ImVec2(250, 30)) then
        if onSetPointA then onSetPointA() end
    end

    local canSetB = (currentStatus ~= STATUS.NOT_CONFIGURED)
    if not canSetB then
        im.PushStyleVar1(im.StyleVar_Alpha, 0.5)
    end
    if im.Button("Установить точку Б", im.ImVec2(250, 30)) then
        if canSetB and onSetPointB then onSetPointB() end
    end
    if not canSetB then
        im.PopStyleVar()
    end

    local canClear = (currentStatus ~= STATUS.NOT_CONFIGURED)
    if not canClear then
        im.PushStyleVar1(im.StyleVar_Alpha, 0.5)
    end
    if im.Button("Очистить точки", im.ImVec2(250, 30)) then
        if canClear and onClearPoints then onClearPoints() end
    end
    if not canClear then
        im.PopStyleVar()
    end

    im.Separator()

    -- Debug mode checkbox
    local debugEnabled = im.BoolPtr(debugMode)
    if im.Checkbox("Debug визуализация", debugEnabled) then
        debugMode = debugEnabled[0]
        log("Debug mode toggled: " .. tostring(debugMode))

        -- Propagate to main module via callback
        if onDebugModeChanged then
            onDebugModeChanged(debugMode)
        end
    end
end

-- Render timer section
function M.renderTimerSection(im)
    -- Timer section
    im.Text("Текущий круг:")
    im.SameLine()
    local currentTime = "00:00.000"
    local currentColor = im.ImVec4(0, 0.8, 1, 1) -- Blue

    if lapTimer and lapTimer.isRunning() then
        currentTime = lapTimer.getCurrentTimeFormatted()
        currentColor = im.ImVec4(0.3, 1, 0.4, 1) -- Green when running
    end

    im.TextColored(currentColor, currentTime)

    -- Last lap time
    if lapTimer then
        local lastLap = lapTimer.getLastLapTime()
        if lastLap then
            im.Text("Последний круг:")
            im.SameLine()
            im.TextColored(im.ImVec4(1, 1, 0.3, 1), lapTimer.formatTime(lastLap))
        end

        -- Best lap time
        local bestLap = lapTimer.getBestLapTime()
        if bestLap then
            im.Text("Лучший круг:")
            im.SameLine()
            im.TextColored(im.ImVec4(0.3, 1, 0.3, 1), lapTimer.formatTime(bestLap))
        end
    end

    im.Separator()
end

-- Render lap history section
function M.renderLapHistorySection(im)
    if not lapTimer then return end

    im.Text("История кругов:")

    local laps = lapTimer.getLapHistory()
    local bestTime = lapTimer.getBestLapTime()

    if #laps == 0 then
        im.Text("Пока нет завершенных кругов")
    else
        -- Show last 5 laps
        local startIndex = math.max(1, #laps - 4)

        for i = startIndex, #laps do
            local lap = laps[i]
            local color = im.ImVec4(0.8, 0.8, 0.8, 1) -- Default gray

            -- Highlight best lap
            if bestTime and math.abs(lap.time - bestTime) < 0.001 then
                color = im.ImVec4(0, 1, 0, 1) -- Green for best
            end

            local text = string.format("#%d: %s (%s)",
                lap.lapNumber,
                lapTimer.formatTime(lap.time),
                lap.vehicle or "unknown")

            im.TextColored(color, text)
        end

        -- Clear history button
        if im.Button("Очистить историю", im.ImVec2(200, 25)) then
            if lapTimer.clearHistory then
                lapTimer.clearHistory()
                log("Lap history cleared by user")
            end
        end
    end
end

-- Public API functions
function M.setDependencies(deps)
    waypointManager = deps.waypointManager
    lapTimer = deps.lapTimer
    multiplayerManager = deps.multiplayerManager
    leaderboardManager = deps.leaderboardManager
end

function M.setCallbacks(callbacks)
    onSetPointA = callbacks.onSetPointA
    onSetPointB = callbacks.onSetPointB
    onClearPoints = callbacks.onClearPoints
    onDebugModeChanged = callbacks.onDebugModeChanged
end

function M.updateStatus()
    updateStatusFromWaypoints()
end

function M.setStatus(status)
    currentStatus = status
    log(string.format("Status manually set to: %s", status))
end

function M.getStatus()
    return currentStatus
end

function M.getStatusEnum()
    return STATUS
end

function M.setShowUI(show)
    showUI = show
end

function M.getShowUI()
    return showUI
end

function M.setDebugMode(enabled)
    debugMode = enabled
end

return M

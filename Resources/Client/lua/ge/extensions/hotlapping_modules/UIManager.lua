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
local storageManager = nil

local HOTLAPPING_TABS = {
    TIMES = 1,
    SETTINGS = 2
}

local LEADERBOARD_TABS = {
    BEST_TIMES = 1,
    RECENT_LAPS = 2
}

local uiSettings = {
    backgroundOpacity = 100, -- От 0 до 100
    fontSize = 1             -- 1 = маленький, 2 = средний, 3 = большой
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

-- Функция для получения размера шрифта
local function getFontScale()
    if uiSettings.fontSize == 1 then
        return 1.0 -- Текущий размер (маленький)
    elseif uiSettings.fontSize == 2 then
        return 1.2 -- Средний (+20%)
    else
        return 1.4 -- Большой (+40%)
    end
end

-- Функция для получения прозрачности фона окна
local function getWindowAlpha()
    return uiSettings.backgroundOpacity / 100.0
end

-- Функция для применения стилей перед отрисовкой
local function applyUIStyles(im)
    -- Применяем масштаб шрифта
    local fontScale = getFontScale()
    im.SetWindowFontScale(fontScale)

    -- Применяем прозрачность фона окна
    local alpha = getWindowAlpha()
    im.PushStyleColor2(im.Col_WindowBg, im.GetStyleColorVec4(im.Col_WindowBg))
    local bgColor = im.GetStyleColorVec4(im.Col_WindowBg)
    bgColor.w = alpha * 0.9 -- Базовая прозрачность окна
    im.PopStyleColor()
    im.PushStyleColor2(im.Col_WindowBg, bgColor)
end

-- Функция для сброса стилей после отрисовки
local function resetUIStyles(im)
    im.PopStyleColor() -- Убираем изменение WindowBg
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

    -- applyUIStyles(im)
    if im.StyleVar_WindowShadowSize then
        im.PushStyleVar1(im.StyleVar_WindowShadowSize, 0.0)
    end

    if im.StyleVar_WindowBorderSize then
        im.PushStyleVar1(im.StyleVar_WindowBorderSize, 0.0)
    end
    -- Применяем прозрачность ДО всех окон
    local alpha = getWindowAlpha()
    local bgColor = im.GetStyleColorVec4(im.Col_WindowBg)
    bgColor.w = alpha * 0.9
    im.PushStyleColor2(im.Col_WindowBg, bgColor)

    -- Main window
    local flags = im.WindowFlags_AlwaysAutoResize or 0

    -- Begin window - ImGui will handle open/close state internally
    if im.Begin("Hot_Times##HotlappingMainWindow", nil, flags) then
        im.SetWindowFontScale(getFontScale())
        if im.BeginTabBar("HotlappingTabs") then
            -- Tab 1: Timer
            if im.BeginTabItem("Times") then
                currentLeaderboardTab = HOTLAPPING_TABS.TIMES

                M.renderTimerTab(im)

                im.EndTabItem()
            end

            -- Tab 2: Settings
            if im.BeginTabItem("Settings") then
                currentLeaderboardTab = HOTLAPPING_TABS.SETTINGS

                M.renderSettingsTab(im)

                im.EndTabItem()
            end

            im.EndTabBar()
        end
    end
    im.End()



    -- Leaderboard window
    if im.Begin("Hot_Leaderboard(Server)##HotlappingLeaderboard", nil, flags) then
        im.SetWindowFontScale(getFontScale())
        -- Tabs
        if im.BeginTabBar("LeaderboardTabs") then
            -- Tab 1: Best Times
            if im.BeginTabItem("Best times") then
                currentLeaderboardTab = LEADERBOARD_TABS.BEST_TIMES
                M.renderBestTimesTab(im)
                im.EndTabItem()
            end

            -- Tab 2: Recent Laps
            if im.BeginTabItem("Recent laps") then
                currentLeaderboardTab = LEADERBOARD_TABS.RECENT_LAPS
                M.renderRecentLapsTab(im)
                im.EndTabItem()
            end

            im.EndTabBar()
        end
    end
    im.End()

    -- resetUIStyles(im)
    im.PopStyleColor(1)
    if im.StyleVar_WindowBorderSize then
        im.PopStyleVar(1)
    end

    if im.StyleVar_WindowShadowSize then
        im.PopStyleVar(1)
    end
end

function M.renderSettingsTab(im)
    -- Status section
    im.Text("Status:")
    im.SameLine()
    local color = getStatusColor()
    im.TextColored(im.ImVec4(color[1], color[2], color[3], color[4]), getStatusText())

    -- Multiplayer status
    if multiplayerManager then
        local mpMode = multiplayerManager.getOperationMode()
        local mpColor = mpMode == "multiplayer" and { 0, 1, 0, 1 } or { 0.7, 0.7, 0.7, 1 }
        im.Text("Mode:")
        im.SameLine()
        im.TextColored(im.ImVec4(mpColor[1], mpColor[2], mpColor[3], mpColor[4]),
            mpMode == "multiplayer" and "Multiplayer" or "Singleplayer")
    end

    im.Separator()

    -- if im.BeginChild1("Start/Finish Line Controls") then
    --     im.Indent(10)

        M.renderControlButtons(im)

    --     im.Unindent(10)
    -- end


    -- if im.BeginChild1("UI Settings") then
    --     im.Indent(10) -- Отступ для визуальной вложенности
        im.Separator()

        im.Text("UI Settings:")

        -- Background opacity
        im.Text("Background opacity:")
        local opacityPtr = im.IntPtr(uiSettings.backgroundOpacity)
        if im.SliderInt("##opacity", opacityPtr, 0, 100, "%d%%") then
            uiSettings.backgroundOpacity = opacityPtr[0]
            -- Сохраняем изменения
            if storageManager then
                storageManager.saveUISettings(uiSettings)
            end
            log("Background opacity changed to: " .. uiSettings.backgroundOpacity)
        end

        -- Font size
        im.Text("Font size:")
        local fontSizePtr = im.IntPtr(uiSettings.fontSize)
        if im.SliderInt("##fontSize", fontSizePtr, 1, 3,
                uiSettings.fontSize == 1 and "Small" or
                (uiSettings.fontSize == 2 and "Medium" or "Large")) then
            uiSettings.fontSize = fontSizePtr[0]
            -- Сохраняем изменения
            if storageManager then
                storageManager.saveUISettings(uiSettings)
            end
            log("Font size changed to: " .. uiSettings.fontSize)
        end
    --     im.Unindent(10)
    -- end
end

function M.renderTimerTab(im)
    M.renderTimerSection(im)
    M.renderLapHistorySection(im)
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
            im.TextColored(color, lapTimer.formatTime(entry.time))

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
    -- for playerName, laps in pairs(recentLaps) do
    --     im.Text("Игрок: " .. playerName)
    --     im.Indent(20)

    --     for i, lap in ipairs(laps) do
    --         -- im.Text(string.format("  Круг #%d: %.3f мин (%s)",
    --         --     lap.lapNumber or i,
    --         --     string.format("%.3f", lap.time),
    --         --     lap.vehicle or "N/A"))
    --         im.Text("Круг #" ..
    --             (lap.lapNumber or i) ..
    --             " Время: " .. lapTimer.formatTime(lap.time) .. " Авто: " .. (lap.vehicle or "N/A"))
    --     end

    --     im.Unindent(20)
    --     im.Separator()
    -- end

    if im.BeginTable("RecentTimesTable", 4, im.TableFlags_Borders) then
        im.TableSetupColumn("#", im.TableColumnFlags_WidthFixed, 30)
        im.TableSetupColumn("Игрок", im.TableColumnFlags_WidthFixed, 150)
        im.TableSetupColumn("Время", im.TableColumnFlags_WidthFixed, 100)
        im.TableSetupColumn("Транспорт", im.TableColumnFlags_WidthFixed, 120)
        im.TableHeadersRow()

        for playerName, laps in pairs(recentLaps) do
            -- im.Text("Игрок: " .. playerName)
            -- im.Indent(20)

            for i, lap in ipairs(laps) do
                -- im.Text(string.format("  Круг #%d: %.3f мин (%s)",
                --     lap.lapNumber or i,
                --     string.format("%.3f", lap.time),
                --     lap.vehicle or "N/A"))
                -- im.Text("Круг #" ..
                -- (lap.lapNumber or i) ..
                -- " Время: " .. lapTimer.formatTime(lap.time) .. " Авто: " .. (lap.vehicle or "N/A"))

                im.TableNextRow()

                im.TableNextColumn()
                im.Text(tostring(i))

                im.TableNextColumn()
                im.Text(playerName or "Unknown")

                im.TableNextColumn()
                -- local color = i == 1 and im.ImVec4(0, 1, 0, 1) or im.ImVec4(1, 1, 1, 1)
                -- im.TextColored(color, string.format("%.3f", entry.time))
                im.Text(lapTimer.formatTime(lap.time))

                im.TableNextColumn()
                im.Text(lap.vehicle or "N/A")
            end

            -- im.Unindent(20)
            -- im.Separator()
        end

        -- Table rows
        -- for i, entry in ipairs(bestTimes) do
        --     im.TableNextRow()

        --     im.TableNextColumn()
        --     im.Text(tostring(i))

        --     im.TableNextColumn()
        --     im.Text(entry.playerName or "Unknown")

        --     im.TableNextColumn()
        --     local color = i == 1 and im.ImVec4(0, 1, 0, 1) or im.ImVec4(1, 1, 1, 1)
        --     -- im.TextColored(color, string.format("%.3f", entry.time))
        --     im.TextColored(color, lapTimer.formatTime(entry.time))

        --     im.TableNextColumn()
        --     im.Text(entry.vehicle or "N/A")
        -- end

        im.EndTable()
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
        -- if im.BeginChild1("Clear buttons") then
        --     im.Indent(10)

            if im.Button("Clear history", im.ImVec2(200, 25)) then
                if lapTimer.clearHistory then
                    lapTimer.clearHistory()
                    log("Lap history cleared by user")
                end
            end
            if im.Button("Clear my Leaderboard times", im.ImVec2(200, 25)) then
                if multiplayerManager then
                    multiplayerManager.clearMyLeaderboardTimes()
                    log("Leaderboard user times cleared by user")
                end
            end
        --     im.Unindent(10)
        -- end
    end
end

-- Public API functions
function M.setDependencies(deps)
    waypointManager = deps.waypointManager
    lapTimer = deps.lapTimer
    multiplayerManager = deps.multiplayerManager
    leaderboardManager = deps.leaderboardManager
    storageManager = deps.storageManager

    -- Загружаем UI настройки при инициализации
    if storageManager then
        local loadedSettings = storageManager.loadUISettings()
        if loadedSettings then
            uiSettings = loadedSettings
            log("UI settings loaded from storage")
        end
    end
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

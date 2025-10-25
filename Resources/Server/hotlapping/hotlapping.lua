local HOT_LEADERBOARD_LAPS = "Resources/Server/hotlapping/data/hot_leaderboard_laps.json"
local HOT_LEADERS          = {}

-- Объявляем локальные функции заранее
local loadData, saveData

function onInit()
    print("Hotlapping loaded successfully!")
    -- Регистрируем события с уникальными именами
    MP.RegisterEvent("onPlayerJoin", "hotlappingOnPlayerJoinFunc")
    MP.RegisterEvent("onRequestDataForPlayer", "hotlappingGetDataForPlayerFunc")
    MP.RegisterEvent("onHotlappingRequest", "hotlappingRequestHubFunc")

    -- Загружаем данные при инициализации
    loadData()
end

loadData = function()
    print("[Hotlapping] Loading leaderboard data from file...")
    local handle = io.open(HOT_LEADERBOARD_LAPS, "r")
    if not handle then
        print("[Hotlapping] No leaderboard data found, returning empty table.")
        HOT_LEADERS = {}
        return {}
    end

    local data = Util.JsonDecode(handle:read("*all"))
    handle:close()

    -- Проверяем что данные загрузились корректно
    if not data then
        print("[Hotlapping] Invalid data format, returning empty table.")
        HOT_LEADERS = {}
        return {}
    end

    -- Очищаем старые данные
    HOT_LEADERS = {}
    for playerName, lapData in pairs(data) do
        HOT_LEADERS[playerName] = lapData
    end
    -- for playerName, lapData in pairs(data.leaderboard) do
    --     HOT_LEADERS[playerName] = { time = lapData.time, vehicle = lapData.vehicle }
    -- end

    -- Возвращаем загруженные данные
    return data
end

saveData = function()
    -- Сохраняем текущие данные HOT_LEADERS в файл
    print("[Hotlapping] Saving leaderboard data to file...")
    if next(HOT_LEADERS) ~= nil then -- Проверяем что таблица не пустая
        -- local data = {}
        -- data["leaderboard"] = HOT_LEADERS
        

        local handle = io.open(HOT_LEADERBOARD_LAPS, "w")
        if handle then
            handle:write(Util.JsonEncode(HOT_LEADERS))
            handle:close()
            print("[Hotlapping] Data saved successfully")
        else
            print("[Hotlapping] Error: Could not open file for writing")
        end
    else
        print("[Hotlapping] No data to save")
    end
end

-- Получить лучшие времена всех игроков (топ-10)
local function getBestTimesLeaderboard()
    local leaderboard = {}
    for playerName, data in pairs(HOT_LEADERS) do
        if data.bestTime then
            table.insert(leaderboard, {
                playerName = playerName,
                time = data.bestTime.time,
                vehicle = data.bestTime.vehicle,
                timestamp = data.bestTime.timestamp
            })
        end
    end
    
    -- Сортировка по времени
    table.sort(leaderboard, function(a, b) return a.time < b.time end)
    
    -- Ограничить до 10 записей
    local top10 = {}
    for i = 1, math.min(10, #leaderboard) do
        table.insert(top10, leaderboard[i])
    end
    
    return top10
end

-- Получить последние 3 круга каждого игрока
local function getRecentLapsLeaderboard()
    local recentLaps = {}
    
    for playerName, data in pairs(HOT_LEADERS) do
        if data.allLaps and #data.allLaps > 0 then
            local playerRecent = {}
            local startIndex = math.max(1, #data.allLaps - 2) -- Последние 3
            
            for i = startIndex, #data.allLaps do
                table.insert(playerRecent, {
                    playerName = playerName,
                    time = data.allLaps[i].time,
                    vehicle = data.allLaps[i].vehicle,
                    timestamp = data.allLaps[i].timestamp,
                    lapNumber = data.allLaps[i].lapNumber
                })
            end
            
            recentLaps[playerName] = playerRecent
        end
    end
    
    return recentLaps
end

-- Игрок присоединился
function hotlappingOnPlayerJoinFunc(playerId)
    local playerName = MP.GetPlayerName(playerId)




    print('[Hotlapping] Player joined: ' .. playerName .. ' (ID: ' .. playerId .. ')')

    -- Отправляем состояние игры новому игроку
    sendLapsToPlayer(playerId)
end

-- Игрок присоединился
function hotlappingGetDataForPlayerFunc(playerId, mapName)
    local playerName = MP.GetPlayerName(playerId)


    print('[Hotlapping] Player requested data for map ' .. mapName .. ' : ' .. playerName .. ' (ID: ' .. playerId .. ')')

    -- Отправляем состояние игры новому игроку
    sendLapsToPlayer(playerId)
end

-- function sendLapsToPlayer(playerId)
--     local leaderboard = loadData()

--     -- Дополнительная проверка на случай если данные не загрузились
--     if not leaderboard then
--         leaderboard = {}
--         print("[Hotlapping] Warning: no leaderboard data available, sending empty data")
--     end

--     local data = Util.JsonEncode(leaderboard)
--     print('Send hotlapping data to Player')

--     MP.TriggerClientEvent(playerId, "onHotlappingLapsFromServer", data)
-- end

function sendLapsToPlayer(playerId)
    local bestTimes = getBestTimesLeaderboard()
    local recentLaps = getRecentLapsLeaderboard()
    
    local data = {
        bestTimes = bestTimes,
        recentLaps = recentLaps,
        timestamp = os.time()
    }
    
    local jsonData = Util.JsonEncode(data)
    MP.TriggerClientEvent(playerId, "onHotlappingLapsFromServer", jsonData)
    
    print('[Hotlapping] Sent leaderboard data to player ID: ' .. playerId)
end

function broadcastLeaderboardUpdate()
 local bestTimes = getBestTimesLeaderboard()
    local recentLaps = getRecentLapsLeaderboard()
    
    local data = {
        bestTimes = bestTimes,
        recentLaps = recentLaps,
        timestamp = os.time()
    }
    
    local jsonData = Util.JsonEncode(data)
    MP.TriggerClientEvent(-1, "onHotlappingLapsFromServer", jsonData)
    print('[Hotlapping] Broadcasted leaderboard update to all players')
end

function addNewLapToAllLaps(playerName, lapTime, vehicle)
    local newLap = {
        time = lapTime,
        vehicle = vehicle,
        timestamp = os.time()
    }

    table.insert(HOT_LEADERS[playerName].allLaps, newLap)
end

function updateBestLapIfNeeded(playerName, lapTime)
    local currentBest = HOT_LEADERS[playerName].bestTime

    if not currentBest or lapTime < currentBest then
        HOT_LEADERS[playerName].bestTime = lapTime
        print('[Hotlapping] New best time for player ' .. playerName .. ': ' .. lapTime)
    end
end

-- function updateLapsInStorage(playerName, lapTime, vehicle)
--     print('[Hotlapping] Updating lap time for player: ' .. playerName .. ' Time: ' .. lapTime .. ' Vehicle: ' .. vehicle)

--     -- Обновляем данные в таблице
--     -- HOT_LEADERS[playerName] = { time = lapTime, vehicle = vehicle }
    
--     -- Инициализируем структуру, если её нет
--     if not HOT_LEADERS[playerName] then
--         HOT_LEADERS[playerName] = {
--             bestTime = nil,
--             allLaps = {}
--         }
--     end

--     -- Создаём новый элемент круга
--    addNewLapToAllLaps(playerName, lapTime, vehicle)

--     -- Обновляем bestTime, если новый круг лучше
--    updateBestLapIfNeeded(playerName, lapTime)

--     -- Сохраняем обновленные данные
--     saveData()
-- end

function updateLapsInStorage(playerId, lapTime, vehicle, lapNumber)

    local playerName = MP.GetPlayerName(playerId)

    print('[Hotlapping] Updating lap for: ' .. playerName .. 
          ' Time: ' .. lapTime .. ' Vehicle: ' .. vehicle)
    
    -- Инициализируем структуру если игрока нет
    if not HOT_LEADERS[playerName] then
        HOT_LEADERS[playerName] = {
            bestTime = nil,
            allLaps = {}
        }
    end
    
    local playerData = HOT_LEADERS[playerName]
    
    -- Добавляем новый круг в историю
    table.insert(playerData.allLaps, {
        time = lapTime,
        vehicle = vehicle,
        lapNumber = lapNumber or (#playerData.allLaps + 1),
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    })
    
    -- Обновляем лучшее время если нужно
    if not playerData.bestTime or lapTime < playerData.bestTime.time then
        playerData.bestTime = {
            time = lapTime,
            vehicle = vehicle,
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        }
        print('[Hotlapping] New best time for ' .. playerName .. ': ' .. lapTime)
    end
    HOT_LEADERS[playerName] = playerData
    -- Сохраняем на диск
    saveData()
end

function clearPlayerLeaderboardTimes(playerId)
    local playerName = MP.GetPlayerName(playerId)

    print('[Hotlapping] Clearing times for: ' .. playerName )
    
    -- Чистим данные игрока
        HOT_LEADERS[playerName] = {
            bestTime = nil,
            allLaps = {}
        }
    
    
    -- Сохраняем на диск
    saveData()

end

function hotlappingRequestHubFunc(playerId, data)
    print('[Hotlapping] Player requested hotlapping hub data')
    data = Util.JsonDecode(data)
    if not data.event then
        print('[Hotlapping] Warning: no event specified in hotlapping hub request')
        return
    end

    if data.event == "hotlapping_request_leaderboard" then
        -- Здесь можно реализовать логику обработки запроса лидерборда
        print('[Hotlapping] Processing leaderboard request from player ID: ' .. playerId)
        sendLapsToPlayer(playerId)
    elseif data.event == "hotlapping_lap_time" then
        print('[Hotlapping] Processing lap time submission from player ID: ' .. playerId)
         
        updateLapsInStorage(playerId, data.time, data.vehicle,data.lapNumber)
           -- Рассылаем обновление ВСЕМ игрокам
        broadcastLeaderboardUpdate()
    elseif data.event == "hotlapping_clear_user_leaderboard" then
        print('[Hotlapping] Processing leaderboard clearing from player ID: ' .. playerId)
         
        clearPlayerLeaderboardTimes(playerId)
           -- Рассылаем обновление ВСЕМ игрокам
        broadcastLeaderboardUpdate()
    end

    -- Здесь можно реализовать логику обработки запроса от игрока
    -- Например, отправить ему текущие данные лидерборда или другую информацию
end

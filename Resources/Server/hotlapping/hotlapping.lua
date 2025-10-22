local HOT_LEADERBOARD_LAPS  = "Resources/Server/hotlapping/data/hot_leaderboard_laps.json"
local HOT_LEADERS = {}

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
	local handle = io.open(HOT_LEADERBOARD_LAPS, "r")
    if not handle then
        print("[Hotlapping] No leaderboard data found, returning empty table.")
        HOT_LEADERS = {}
        return {}
    end
    
	local data = Util.JsonDecode(handle:read("*all"))
	handle:close()
    
    -- Проверяем что данные загрузились корректно
    if not data or not data.leaderboard then
        print("[Hotlapping] Invalid data format, returning empty table.")
        HOT_LEADERS = {}
        return {}
    end

	-- Очищаем старые данные
	HOT_LEADERS = {}
	
	for playerName, lapData in pairs(data.leaderboard) do
		HOT_LEADERS[playerName] = { time = lapData.time, vehicle = lapData.vehicle }
	end
	
	-- Возвращаем загруженные данные
	return data
end

saveData = function()
	-- Сохраняем текущие данные HOT_LEADERS в файл
	if next(HOT_LEADERS) ~= nil then  -- Проверяем что таблица не пустая
		local data = {}
		data["leaderboard"] = HOT_LEADERS
	
		local handle = io.open(HOT_LEADERBOARD_LAPS, "w")
		if handle then
			handle:write(Util.JsonEncode(data))
			handle:close()
			print("[Hotlapping] Data saved successfully")
		else
			print("[Hotlapping] Error: Could not open file for writing")
		end
	else
		print("[Hotlapping] No data to save")
	end
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

function sendLapsToPlayer(playerId)
    local leaderboard = loadData()
    
    -- Дополнительная проверка на случай если данные не загрузились
    if not leaderboard then
        leaderboard = {}
        print("[Hotlapping] Warning: no leaderboard data available, sending empty data")
    end
    
    local data = Util.JsonEncode(leaderboard)
    print('Send hotlapping data to Player')

    MP.TriggerClientEvent(playerId, "onHotlappingLapsFromServer", data)
end

function updateLapsInStorage(playerName, lapTime, vehicle)
    print('[Hotlapping] Updating lap time for player: ' .. playerName .. ' Time: ' .. lapTime .. ' Vehicle: ' .. vehicle)

    -- Обновляем данные в таблице
    HOT_LEADERS[playerName] = { time = lapTime, vehicle = vehicle }
    
    -- Сохраняем обновленные данные
    saveData()
end

function hotlappingRequestHubFunc(playerId,data)
    print('[Hotlapping] Player requested hotlapping hub data')

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
            updateLapsInStorage(data.playerName, data.time, data.vehicle)
            sendLapsToPlayer(playerId)
        end

    -- Здесь можно реализовать логику обработки запроса от игрока
    -- Например, отправить ему текущие данные лидерборда или другую информацию
end
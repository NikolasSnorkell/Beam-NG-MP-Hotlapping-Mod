# Этап 4: Система таймера и учета кругов - Реализация

## Дата завершения: 18 октября 2025

## Описание

Реализован полнофункциональный модуль `LapTimer.lua` для управления таймингом кругов, хранения истории и отображения статистики.

## Реализованные компоненты

### 1. LapTimer.lua

Основной модуль управления таймером, расположенный в:
```
lua/ge/extensions/hotlapping_modules/LapTimer.lua
```

#### Состояния таймера:

- **STOPPED** - Таймер остановлен (начальное состояние)
- **RUNNING** - Таймер идет (круг в процессе)
- **PAUSED** - Таймер на паузе (опционально, для будущего использования)

#### Основные функции:

##### Управление таймером:

1. **`startLap()`**
   - Начинает новый круг
   - Устанавливает время старта
   - Увеличивает счетчик кругов
   - Вызывает callback `onLapStartedCallback`
   - Возвращает: `boolean` (успешность операции)

2. **`completeLap()`**
   - Завершает текущий круг
   - Рассчитывает время круга
   - Создает запись в истории
   - Обновляет лучшее время если необходимо
   - Вызывает callback `onLapCompletedCallback`
   - Возвращает: `lapRecord` (таблица с данными круга)

3. **`stopLap()`**
   - Останавливает текущий круг без записи (отмена)
   - Используется при смене автомобиля или очистке точек
   - Возвращает: `boolean`

4. **`pause()` / `resume()`**
   - Пауза и продолжение таймера
   - Полезно для будущих фич (например, пауза игры)
   - Возвращают: `boolean`

5. **`reset(clearHistory)`**
   - Сбрасывает таймер
   - Опционально очищает историю кругов
   - Параметр: `clearHistory` (boolean)

##### Получение данных:

6. **`getCurrentTime()`**
   - Возвращает текущее время круга в секундах
   - Обновляется в реальном времени пока таймер работает
   - Возвращает: `number|nil`

7. **`getCurrentTimeFormatted()`**
   - Возвращает отформатированное текущее время
   - Формат: "MM:SS.mmm"
   - Возвращает: `string`

8. **`getBestLapTime()` / `getBestLapTimeFormatted()`**
   - Возвращает лучшее время круга
   - Возвращает: `number|nil` или `string`

9. **`getLastLapTime()` / `getLastLapTimeFormatted()`**
   - Возвращает время последнего завершенного круга
   - Возвращает: `number|nil` или `string`

10. **`getLapHistory()`**
    - Возвращает массив всех завершенных кругов
    - Возвращает: `table` (array)

11. **`getBestLap()`**
    - Возвращает запись о лучшем круге
    - Возвращает: `table|nil` (lapRecord)

12. **`getLap(lapNumber)`**
    - Получает конкретный круг по номеру
    - Параметр: `lapNumber` (number)
    - Возвращает: `table|nil` (lapRecord)

13. **`getStatistics()`**
    - Возвращает сводную статистику:
      - Общее количество кругов
      - Лучшее время
      - Среднее время
      - Общее время
      - Отформатированные версии всех времен
    - Возвращает: `table` (статистика)

##### Состояние:

14. **`getState()`**
    - Возвращает текущее состояние таймера
    - Возвращает: `string` ("stopped", "running", "paused")

15. **`isRunning()` / `isPaused()`**
    - Проверяют состояние таймера
    - Возвращают: `boolean`

16. **`getLapCount()` / `getCurrentLapNumber()`**
    - Получение счетчиков кругов
    - Возвращают: `number`

##### Управление:

17. **`setVehicle(vehicleName)`**
    - Устанавливает имя автомобиля для записей в истории
    - Параметр: `vehicleName` (string)

18. **`clearHistory()`**
    - Очищает всю историю кругов
    - Сбрасывает лучшее время

19. **`setOnLapCompletedCallback(callback)`**
    - Устанавливает callback при завершении круга
    - Callback получает: `lapRecord`

20. **`setOnLapStartedCallback(callback)`**
    - Устанавливает callback при старте круга
    - Callback получает: `lapNumber`

21. **`setDebugMode(enabled)`**
    - Включает/выключает debug логирование
    - Параметр: `enabled` (boolean)

##### Утилиты:

22. **`formatTime(seconds)`**
    - Форматирует время в "MM:SS.mmm"
    - Параметр: `seconds` (number)
    - Возвращает: `string`
    - Доступна как публичная функция для внешнего использования

23. **`formatDelta(time1, time2)`**
    - Вычисляет и форматирует разницу между временами
    - Параметры: `time1`, `time2` (number)
    - Возвращает: `string` (например, "+1.234" или "-0.567")

### 2. Структура записи круга (Lap Record)

```lua
{
    lapNumber = 1,              -- Номер круга
    time = 65.432,              -- Время в секундах
    timestamp = "2025-10-18 14:30:00",  -- Timestamp завершения
    vehicle = "etk800"          -- Имя автомобиля
}
```

### 3. Интеграция с главным модулем

#### Обновления в `hotlapping.lua`:

##### Загрузка модуля:
```lua
lapTimer = require('hotlapping_modules/LapTimer')
log("LapTimer loaded")
```

##### Callback при пересечении линии:
```lua
crossingDetector.setOnLineCrossedCallback(function(direction)
    if direction == "forward" then
        if lapTimer then
            if lapTimer.isRunning() then
                -- Завершить текущий круг
                local lapRecord = lapTimer.completeLap()
                if lapRecord then
                    local message = string.format("Круг завершен: %s", 
                        lapTimer.formatTime(lapRecord.time))
                    if lapRecord.time == lapTimer.getBestLapTime() then
                        message = message .. " [Новый рекорд!]"
                    end
                    guihooks.message(message, 5, "")
                end
                -- Начать новый круг сразу
                lapTimer.startLap()
            else
                -- Начать первый круг
                lapTimer.startLap()
                guihooks.message("Круг начат!", 3, "")
            end
        end
    end
end)
```

##### UI отображение:

**Текущий круг (обновляется в реальном времени):**
```lua
im.Text("Текущий круг:")
im.SameLine()
local currentTime = "00:00.000"
local currentColor = im.ImVec4(0, 0.8, 1, 1)  -- Blue
if lapTimer and lapTimer.isRunning() then
    currentTime = lapTimer.getCurrentTimeFormatted()
    currentColor = im.ImVec4(0.3, 1, 0.4, 1)  -- Green when running
end
im.TextColored(currentColor, currentTime)
```

**Последний и лучший круг:**
```lua
im.Text("Последний круг:")
im.SameLine()
im.TextColored(im.ImVec4(1, 1, 0.3, 1), lapTimer.getLastLapTimeFormatted())

im.Text("Лучший круг:")
im.SameLine()
im.TextColored(im.ImVec4(0.3, 1, 0.4, 1), lapTimer.getBestLapTimeFormatted())
```

**История кругов (последние 5):**
```lua
if lapTimer and lapTimer.getLapCount() > 0 then
    local history = lapTimer.getLapHistory()
    local startIdx = math.max(1, #history - 4)
    for i = #history, startIdx, -1 do
        local lap = history[i]
        local lapText = string.format("#%d: %s", 
            lap.lapNumber, lapTimer.formatTime(lap.time))
        
        if lap.time == lapTimer.getBestLapTime() then
            im.TextColored(im.ImVec4(0.3, 1, 0.4, 1), 
                lapText .. " [Лучший!]")
        else
            im.Text(lapText)
        end
    end
end
```

**Кнопка очистки истории:**
```lua
if im.Button("Очистить историю", im.ImVec2(250, 25)) then
    if lapTimer then
        lapTimer.clearHistory()
    end
end
```

##### Обработка смены автомобиля:
```lua
local function onVehicleSwitched(oldId, newId, player)
    if lapTimer then
        if lapTimer.isRunning() then
            lapTimer.stopLap()  -- Прервать текущий круг
        end
        
        -- Обновить имя автомобиля
        if currentVehicle then
            local vehicleName = currentVehicle:getJBeamFilename() or "unknown"
            lapTimer.setVehicle(vehicleName)
        end
    end
end
```

##### Обработка очистки точек:
```lua
clearPoints = function()
    if lapTimer then
        if lapTimer.isRunning() then
            lapTimer.stopLap()  -- Прервать круг
        end
        lapTimer.reset(false)  -- Сбросить, но сохранить историю
    end
end
```

##### Инициализация при загрузке карты:
```lua
local function onClientStartMission(levelPath)
    currentVehicle = be:getPlayerVehicle(0)
    
    if lapTimer and currentVehicle then
        local vehicleName = currentVehicle:getJBeamFilename() or "unknown"
        lapTimer.setVehicle(vehicleName)
    end
end
```

## Особенности реализации

### 1. Точность времени
- Используется `os.clock()` для высокоточного измерения времени
- Поддерживает миллисекундную точность (3 знака после запятой)

### 2. Автоматический запуск следующего круга
- После завершения круга автоматически начинается новый
- Первый круг начинается при первом пересечении линии
- Плавный переход между кругами без потери времени

### 3. Уведомления
- При завершении круга показывается время
- При новом рекорде добавляется метка "[Новый рекорд!]"
- Уведомления через `guihooks.message()`

### 4. Цветовая индикация в UI
- **Синий** - таймер не запущен
- **Зеленый** - таймер работает
- **Желтый** - последний круг
- **Зеленый** - лучший круг (в истории)

### 5. Обработка граничных случаев
- Смена автомобиля → прерывание текущего круга
- Очистка точек → прерывание текущего круга
- Телепортация → сброс детектора (в CrossingDetector)
- История сохраняется при сбросе (опционально)

## Производительность

- **Алгоритм**: O(1) для всех основных операций
- **Память**: Минимальное потребление (история кругов в памяти)
- **UI обновление**: Только при изменении или каждый кадр для текущего времени
- **Оптимизация**: Форматирование времени вызывается только для отображения

## Тестирование

### Базовая функциональность:
1. ✅ Установить финишную линию
2. ✅ Проехать через линию → таймер должен начаться
3. ✅ Проехать через линию снова → круг должен завершиться
4. ✅ Проверить отображение времени в UI
5. ✅ Проверить историю кругов

### Лучшее время:
1. ✅ Завершить несколько кругов
2. ✅ Убедиться, что лучшее время корректно определяется
3. ✅ Проверить метку "[Лучший!]" в истории
4. ✅ Проверить уведомление "[Новый рекорд!]"

### Обработка событий:
1. ✅ Сменить автомобиль во время круга → должен прерваться
2. ✅ Очистить точки во время круга → должен прерваться
3. ✅ Проверить, что история сохраняется после очистки точек
4. ✅ Проверить отображение имени автомобиля в истории

### UI:
1. ✅ Текущее время обновляется в реальном времени
2. ✅ История показывает последние 5 кругов
3. ✅ Кнопка "Очистить историю" работает
4. ✅ Цвета корректно отображаются

## Известные ограничения

1. **Хранение истории**: История хранится только в оперативной памяти
   - При выходе из игры история теряется
   - Решение: Этап 5 - LocalStorage для постоянного хранения

2. **История на карту**: История не привязана к конкретной карте
   - Все круги хранятся вместе независимо от карты
   - Решение: Этап 5 - раздельное хранение по картам

3. **Формат времени**: Фиксированный формат MM:SS.mmm
   - Для кругов длиннее часа будет некорректное отображение
   - Для большинства гоночных кругов это не проблема

## Следующие шаги

- **Этап 5**: Система локального хранилища (StorageManager)
  - Сохранение конфигурации финишной линии
  - Сохранение истории кругов по картам
  - Автоматическая загрузка при старте карты
  - Настройки мода (цвета, опции)

## Статистика реализации

- **Строк кода**: ~420 строк в LapTimer.lua
- **Функций**: 23+ публичных функций
- **Callback'ов**: 2 (onLapCompleted, onLapStarted)
- **Состояний**: 3 (stopped, running, paused)
- **Интеграция**: Полная интеграция с hotlapping.lua и CrossingDetector

## Заметки разработчика

- Код хорошо документирован с LuaDoc аннотациями
- Все функции имеют типы параметров и возвращаемых значений
- Модуль полностью независимый и может использоваться отдельно
- Debug режим помогает отслеживать работу таймера
- Готов к интеграции с системой хранилища (Этап 5)

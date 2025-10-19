# Исправления - Этап 4 (18 октября 2025)

## Проблемы, которые были исправлены:

### 1. ❌ Функция `log` определена после `loadModules()`
**Проблема**: В hotlapping.lua функция `log()` вызывалась внутри `loadModules()`, но определялась только после неё.

**Исправление**: Переместил определение функции `log()` перед `loadModules()` с комментарием:
```lua
-- Utility function for logging (defined early so loadModules can use it)
local function log(message, level)
    ...
end

-- Load sub-modules
local function loadModules()
    ...
end
```

### 2. ❌ CrossingDetector не передавал параметр `direction` в callback
**Проблема**: 
- CrossingDetector.lua: `onLineCrossedCallback()` - вызывался без параметров
- hotlapping.lua: `function(direction)` - ожидал параметр `direction`
- Результат: параметр `direction` был всегда `nil`, поэтому таймер никогда не запускался

**Исправление**: 
1. Добавлен расчет направления пересечения в CrossingDetector.lua:
   - Вычисление нормали к линии старт-финиш
   - Вычисление вектора движения автомобиля
   - Определение направления через dot product
   - Передача параметра `direction` ("forward" или "backward") в callback

2. Добавлена переменная `previousCenter` для точного расчета направления движения

3. Обновлена функция `reset()` для сброса `previousCenter`

### 3. ✅ Дублирование функции `loadModules()`
**Проблема**: Функция `loadModules()` была определена дважды в hotlapping.lua

**Исправление**: Удалена старая версия функции

## Детали исправлений:

### hotlapping.lua:
```lua
-- БЫЛО:
local function loadModules()
    waypointManager = require('hotlapping_modules/WaypointManager')
    log("WaypointManager loaded")  -- ❌ log еще не определен!
    ...
end

local function log(message, level)
    ...
end

-- СТАЛО:
local function log(message, level)
    ...
end

local function loadModules()
    waypointManager = require('hotlapping_modules/WaypointManager')
    log("WaypointManager loaded")  -- ✅ log уже определен
    ...
end
```

### CrossingDetector.lua:
```lua
-- БЫЛО:
if crossed then
    log("Line crossing detected!")
    if onLineCrossedCallback then
        onLineCrossedCallback()  -- ❌ Нет параметра direction!
    end
end

-- СТАЛО:
if crossed then
    log("Line crossing detected!")
    
    -- Determine crossing direction
    pointA = vec3(pointA)
    pointB = vec3(pointB)
    local lineVec = pointB - pointA
    local lineNormal = vec3(-lineVec.y, lineVec.x, 0)  -- Perpendicular
    lineNormal = lineNormal:normalized()
    
    -- Calculate movement vector
    local currentCenter = (currentFront + currentBack) * 0.5
    local movementVec = currentCenter - previousCenter
    
    -- Determine direction via dot product
    local dot = lineNormal:dot(movementVec)
    local direction = "forward"
    if dot < 0 then
        direction = "backward"
    end
    
    log(string.format("Crossing direction: %s (dot: %.3f)", direction, dot))
    
    if onLineCrossedCallback then
        onLineCrossedCallback(direction)  -- ✅ Передаем direction!
    end
end
```

## Что должно работать теперь:

1. ✅ **Загрузка модулей**: Все модули загружаются с логами
2. ✅ **Детектирование пересечения**: CrossingDetector определяет пересечение линии
3. ✅ **Определение направления**: Корректно определяется forward/backward
4. ✅ **Запуск таймера**: При пересечении "forward" таймер запускается
5. ✅ **Завершение круга**: При повторном пересечении "forward" круг завершается
6. ✅ **Игнорирование backward**: Движение назад через линию игнорируется
7. ✅ **UI обновление**: Текущее время обновляется в реальном времени
8. ✅ **Уведомления**: Показываются уведомления о старте и завершении круга

## Тестирование:

### Шаг 1: Проверка загрузки
1. Запустить BeamNG.drive с модом
2. Открыть консоль (backtick `)
3. Проверить логи:
   ```
   [Hotlapping][INFO] Extension loading...
   [Hotlapping][INFO] WaypointManager loaded
   [Hotlapping][INFO] CrossingDetector loaded
   [Hotlapping][INFO] LapTimer loaded
   [Hotlapping][INFO] Extension loaded successfully!
   ```

### Шаг 2: Установка финишной линии
1. Открыть UI мода (F11 → Hotlapping)
2. Установить точку A
3. Установить точку B
4. Проверить визуализацию линии

### Шаг 3: Тест пересечения
1. Проехать через линию вперед
2. Должны появиться логи:
   ```
   [CrossingDetector][INFO] Line crossing detected!
   [CrossingDetector][INFO] Crossing direction: forward (dot: X.XXX)
   [Hotlapping][INFO] Line crossed! Direction: forward
   [Hotlapping][INFO] Valid lap crossing detected!
   [LapTimer][INFO] Lap #1 started
   ```
3. Уведомление: "Круг начат!"
4. В UI должно начаться время: 00:00.XXX (зеленым цветом)

### Шаг 4: Тест завершения круга
1. Проехать круг и пересечь линию снова
2. Должны появиться логи:
   ```
   [CrossingDetector][INFO] Line crossing detected!
   [CrossingDetector][INFO] Crossing direction: forward (dot: X.XXX)
   [Hotlapping][INFO] Line crossed! Direction: forward
   [Hotlapping][INFO] Valid lap crossing detected!
   [LapTimer][INFO] Lap #1 completed: MM:SS.mmm
   [LapTimer][INFO] Lap #2 started
   ```
3. Уведомление: "Круг завершен: MM:SS.mmm"
4. В UI:
   - Текущий круг: сброшено и начинается новый отсчет
   - Последний круг: показывает время завершенного круга
   - Лучший круг: показывает лучшее время
   - История: добавлен новый круг в список

### Шаг 5: Тест движения назад
1. Проехать через линию задом
2. Должны появиться логи:
   ```
   [CrossingDetector][INFO] Line crossing detected!
   [CrossingDetector][INFO] Crossing direction: backward (dot: -X.XXX)
   [Hotlapping][INFO] Line crossed! Direction: backward
   [Hotlapping][WARN] Backward crossing ignored
   ```
3. Таймер НЕ должен реагировать

## Если что-то не работает:

### Логи не появляются при пересечении:
- Проверьте, что точки A и B установлены
- Проверьте, что debugMode = true в CrossingDetector и hotlapping
- Проверьте, что линия видна (клетчатый паттерн)

### Таймер не запускается:
- Проверьте логи - должен быть "Valid lap crossing detected!"
- Проверьте, что direction = "forward"
- Проверьте, что lapTimer загружен

### UI не обновляется:
- Проверьте, что UI открыт (F11 → Hotlapping)
- Проверьте, что showUI = true
- Перезагрузите расширение: Ctrl+L → "reload Hotlapping"

## Следующие шаги:
После успешного тестирования можно переходить к **Этапу 5: Локальное хранилище (StorageManager)** для сохранения конфигурации и истории кругов.

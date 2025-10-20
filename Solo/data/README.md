# Default Waypoints Configuration

Этот файл содержит предустановленные точки финишной линии для различных карт BeamNG.drive.

## Формат JSON

```json
{
  "version": "1.0",
  "description": "Default waypoint configurations for popular maps",
  "waypoints": {
    "map_internal_name": {
      "displayName": "Human-readable map name",
      "pointA": {
        "x": 0.0,
        "y": 0.0,
        "z": 0.0
      },
      "pointB": {
        "x": 10.0,
        "y": 0.0,
        "z": 0.0
      },
      "description": "Optional description of finish line location"
    }
  }
}
```

## Как добавить новую карту

1. Загрузите карту в BeamNG.drive
2. Установите точки финишной линии вручную через UI мода
3. Проверьте консоль для получения координат точек
4. Узнайте внутреннее имя карты (оно отображается в логах при загрузке карты)
5. Добавьте новую секцию в файл `default_waypoints.json`

## Пример добавления карты "West Coast USA"

```json
"west_coast_usa": {
  "displayName": "West Coast USA",
  "pointA": {
    "x": 123.45,
    "y": 678.90,
    "z": 12.34
  },
  "pointB": {
    "x": 234.56,
    "y": 789.01,
    "z": 23.45
  },
  "description": "Main highway finish line"
}
```

## Приоритет загрузки

Мод использует следующий порядок загрузки точек:

1. **Сохраненные пользователем точки** (из BeamNG settings) - наивысший приоритет
2. **Дефолтные точки из JSON** - если нет сохраненных пользователем
3. **Нет точек** - пользователь должен установить вручную

Это означает, что пользователь всегда может переопределить дефолтные точки, установив свои собственные.

## Получение координат

Чтобы получить текущие координаты точек, выполните в консоли BeamNG:

```lua
extensions.load('hotlapping')
dump(extensions.hotlapping.getWaypoints())
```

Или просто установите точки через UI мода и проверьте логи - координаты будут выведены автоматически.

## Внутренние имена карт

Некоторые популярные карты и их внутренние имена:

- `gridmap_v2` - GridMap V2
- `utah` - Utah (USA)
- `italy` - Italy
- `automation_test_track` - Automation Test Track
- `west_coast_usa` - West Coast USA
- `industrial` - Industrial
- `small_island` - Small Island
- `east_coast_usa` - East Coast USA
- `jungle_rock_island` - Jungle Rock Island

Чтобы узнать точное имя текущей карты, проверьте логи при загрузке - мод выводит: `"Mission started: /levels/название_карты/..."`

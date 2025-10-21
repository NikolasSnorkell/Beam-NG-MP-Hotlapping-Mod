-- WaypointManager.lua
-- Manages the two waypoints (Point A and Point B) that define the finish line
-- Author: NikolasSnorkell

local M = {}

-- State
local pointA = nil
local pointB = nil
local isConfigured = false

-- Visual settings
local VISUAL_CONFIG = {
    pointRadius = 0.5,             -- Radius of sphere markers (уменьшен с 1.5)
    pointAColor = {1, 0, 0, 0.7},  -- Red for Point A (RGBA)
    pointBColor = {0, 0, 1, 0.7},  -- Blue for Point B (RGBA)
    lineColor = {0, 1, 0, 0.8},    -- Green for finish line (RGBA)
    lineThickness = 0.3,           -- Thickness of the line
    heightOffset = 0.5,            -- Height offset for visual line (опущен с 2.0 до 0.5м над землей)
}

local debugMode = false

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[WaypointManager][%s] %s", level, message))
    end
end

-- Set Point A
function M.setPointA(position)
    if not position then
        log("Invalid position for Point A", "ERROR")
        return false
    end
    
    pointA = {
        x = position.x,
        y = position.y,
        z = position.z
    }
    
    log(string.format("Point A set: x=%.2f, y=%.2f, z=%.2f", pointA.x, pointA.y, pointA.z))
    
    -- Update configuration status
    M.updateConfigurationStatus()
    
    return true
end

-- Set Point B
function M.setPointB(position)
    if not position then
        log("Invalid position for Point B", "ERROR")
        return false
    end
    
    -- Validate position has required fields
    if not position.x or not position.y or not position.z then
        log(string.format("Point B position missing coordinates: x=%s, y=%s, z=%s", 
            tostring(position.x), tostring(position.y), tostring(position.z)), "ERROR")
        return false
    end
    
    pointB = {
        x = position.x,
        y = position.y,
        z = position.z
    }
    
    log(string.format("Point B set: x=%.2f, y=%.2f, z=%.2f", pointB.x, pointB.y, pointB.z))
    
    -- Update configuration status
    M.updateConfigurationStatus()
    
    return true
end

-- Get Point A
function M.getPointA()
    if not pointA then return nil end
    -- Return a clean copy to avoid external modifications
    return {
        x = pointA.x,
        y = pointA.y,
        z = pointA.z
    }
end

-- Get Point B
function M.getPointB()
    if not pointB then return nil end
    -- Return a clean copy to avoid external modifications
    return {
        x = pointB.x,
        y = pointB.y,
        z = pointB.z
    }
end

-- Clear both points
function M.clearPoints()
    log("Clearing all waypoints")
    pointA = nil
    pointB = nil
    isConfigured = false
    return true
end

-- Update configuration status
function M.updateConfigurationStatus()
    isConfigured = (pointA ~= nil and pointB ~= nil)
    
    if isConfigured then
        log("Finish line configured!")
    end
    
    return isConfigured
end

-- Check if line is configured
function M.isLineConfigured()
    return isConfigured
end

-- Get finish line data (both points)
function M.getFinishLine()
    if not isConfigured then
        return nil
    end
    
    return {
        pointA = pointA,
        pointB = pointB,
        length = M.getLineLength()
    }
end

-- Calculate distance between the two points (line length)
function M.getLineLength()
    if not isConfigured then
        return 0
    end
    
    local dx = pointB.x - pointA.x
    local dy = pointB.y - pointA.y
    local dz = pointB.z - pointA.z
    
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Get midpoint of the finish line
function M.getMidpoint()
    if not isConfigured then
        return nil
    end
    
    return {
        x = (pointA.x + pointB.x) / 2,
        y = (pointA.y + pointB.y) / 2,
        z = (pointA.z + pointB.z) / 2
    }
end

-- Draw visualization of waypoints and finish line
function M.drawVisualization()
    if not pointA and not pointB then
        return
    end
    
    -- Draw Point A if set
    if pointA and pointA.x and pointA.y and pointA.z then
        -- Additional validation to ensure values are numbers
        if type(pointA.x) ~= "number" or type(pointA.y) ~= "number" or type(pointA.z) ~= "number" then
            log("Point A has non-numeric coordinates!", "ERROR")
            return
        end
        
        local colorA = ColorF(
            VISUAL_CONFIG.pointAColor[1],
            VISUAL_CONFIG.pointAColor[2],
            VISUAL_CONFIG.pointAColor[3],
            VISUAL_CONFIG.pointAColor[4]
        )
        
        local posA = Point3F(pointA.x, pointA.y, pointA.z + VISUAL_CONFIG.heightOffset)
        debugDrawer:drawSphere(posA, VISUAL_CONFIG.pointRadius, colorA)
        
        -- Draw label "A" - temporarily disabled due to API compatibility issues
        -- TODO: Find correct API for drawing text in BeamNG
    end
    
    -- Draw Point B if set
    if pointB and pointB.x and pointB.y and pointB.z then
        -- Additional validation to ensure values are numbers
        if type(pointB.x) ~= "number" or type(pointB.y) ~= "number" or type(pointB.z) ~= "number" then
            log("Point B has non-numeric coordinates!", "ERROR")
            return
        end
        
        local colorB = ColorF(
            VISUAL_CONFIG.pointBColor[1],
            VISUAL_CONFIG.pointBColor[2],
            VISUAL_CONFIG.pointBColor[3],
            VISUAL_CONFIG.pointBColor[4]
        )
        
        local posB = Point3F(pointB.x, pointB.y, pointB.z + VISUAL_CONFIG.heightOffset)
        debugDrawer:drawSphere(posB, VISUAL_CONFIG.pointRadius, colorB)
        
        -- Draw label "B" - temporarily disabled due to API compatibility issues
        -- TODO: Find correct API for drawing text in BeamNG
    end
    
    -- Draw finish line if both points are set
    if isConfigured and pointA and pointB and 
       pointA.x and pointA.y and pointA.z and 
       pointB.x and pointB.y and pointB.z then
        local colorLine = ColorF(
            VISUAL_CONFIG.lineColor[1],
            VISUAL_CONFIG.lineColor[2],
            VISUAL_CONFIG.lineColor[3],
            VISUAL_CONFIG.lineColor[4]
        )
        
        local posA = Point3F(pointA.x, pointA.y, pointA.z + VISUAL_CONFIG.heightOffset)
        local posB = Point3F(pointB.x, pointB.y, pointB.z + VISUAL_CONFIG.heightOffset)
        
        -- Draw thick line
        debugDrawer:drawLine(posA, posB, colorLine)
        
        -- Draw additional parallel lines to make it more visible (create thickness effect)
        local offsetVec = M.getPerpendicularVector(pointA, pointB, VISUAL_CONFIG.lineThickness)
        
        if offsetVec then
            local posA1 = Point3F(
                pointA.x + offsetVec.x,
                pointA.y + offsetVec.y,
                pointA.z + VISUAL_CONFIG.heightOffset
            )
            local posB1 = Point3F(
                pointB.x + offsetVec.x,
                pointB.y + offsetVec.y,
                pointB.z + VISUAL_CONFIG.heightOffset
            )
            
            local posA2 = Point3F(
                pointA.x - offsetVec.x,
                pointA.y - offsetVec.y,
                pointA.z + VISUAL_CONFIG.heightOffset
            )
            local posB2 = Point3F(
                pointB.x - offsetVec.x,
                pointB.y - offsetVec.y,
                pointB.z + VISUAL_CONFIG.heightOffset
            )
            
            debugDrawer:drawLine(posA1, posB1, colorLine)
            debugDrawer:drawLine(posA2, posB2, colorLine)
        end
        
        -- Draw checkered pattern on the line (for visual effect)
        M.drawCheckeredLine(posA, posB, colorLine)
    end
end

-- Get perpendicular vector for line thickness
function M.getPerpendicularVector(p1, p2, distance)
    -- Calculate direction vector
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    
    -- Get perpendicular vector (rotate 90 degrees in 2D)
    local perpX = -dy
    local perpY = dx
    
    -- Normalize
    local length = math.sqrt(perpX * perpX + perpY * perpY)
    if length == 0 then
        return nil
    end
    
    perpX = perpX / length * distance
    perpY = perpY / length * distance
    
    return {x = perpX, y = perpY, z = 0}
end

-- Draw checkered pattern on finish line
function M.drawCheckeredLine(posA, posB, color)
    local segments = 10  -- Number of checkered segments
    
    for i = 0, segments do
        -- Alternate colors (white/transparent)
        if i % 2 == 0 then
            local t1 = i / segments
            local t2 = math.min((i + 1) / segments, 1.0)
            
            local pos1 = Point3F(
                posA.x + (posB.x - posA.x) * t1,
                posA.y + (posB.y - posA.y) * t1,
                posA.z + (posB.z - posA.z) * t1
            )
            
            local pos2 = Point3F(
                posA.x + (posB.x - posA.x) * t2,
                posA.y + (posB.y - posA.y) * t2,
                posA.z + (posB.z - posA.z) * t2
            )
            
            local whiteColor = ColorF(1, 1, 1, 0.9)
            debugDrawer:drawLine(pos1, pos2, whiteColor)
        end
    end
end

-- Save waypoints to storage (to be called from main extension)
function M.serialize()
    if not isConfigured then
        return nil
    end
    
    return {
        pointA = pointA,
        pointB = pointB,
        configured = isConfigured
    }
end

-- Load waypoints from storage (to be called from main extension)
function M.deserialize(data)
    if not data then
        log("No data to deserialize", "WARN")
        return false
    end
    
    if data.pointA then
        pointA = data.pointA
        log(string.format("Loaded Point A: x=%.2f, y=%.2f, z=%.2f", pointA.x, pointA.y, pointA.z))
    end
    
    if data.pointB then
        pointB = data.pointB
        log(string.format("Loaded Point B: x=%.2f, y=%.2f, z=%.2f", pointB.x, pointB.y, pointB.z))
    end
    
    M.updateConfigurationStatus()
    
    return isConfigured
end

-- Reset module
function M.reset()
    log("Resetting WaypointManager")
    pointA = nil
    pointB = nil
    isConfigured = false
end

return M

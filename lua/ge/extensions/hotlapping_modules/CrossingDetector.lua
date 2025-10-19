-- CrossingDetector.lua
-- Detects when vehicle crosses the finish line
-- Based on BeamJoy's RaceWaypointManager intersection algorithm
-- Author: NikolasSnorkell

local M = {}

-- State
local previousFront = nil
local previousBack = nil
local previousCenter = nil  -- Store previous center position for direction calculation
local debugMode = true

-- Cooldown to prevent multiple detections during single crossing
local lastCrossingTime = 0
local crossingCooldown = 5.0  -- seconds

-- Crossing callback
local onLineCrossedCallback = nil

-- Utility function for logging
local function log(message, level)
    level = level or "INFO"
    if debugMode then
        print(string.format("[CrossingDetector][%s] %s", level, message))
    end
end

-- Get vehicle front and back points
-- Returns two points: front center and back center of the vehicle
local function getVehicleFrontBack(vehicle)
    if not vehicle then
        return nil, nil
    end
    
    -- getPosition() already returns a vec3 object
    local pos = vehicle:getPosition()
    
    -- Get vehicle rotation (this is stable and doesn't depend on steering)
    local rot = vehicle:getRotation()
    if not rot then
        log("Could not get vehicle rotation", "WARN")
        return nil, nil
    end
    
    -- Get vehicle's forward direction from rotation
    -- Use getDirectionVector instead of manual quaternion multiplication
    local forward = vehicle:getDirectionVector()
    if not forward then
        log("Could not get vehicle direction", "WARN")
        return nil, nil
    end
    
    -- Use a fixed half-length that works well for most vehicles
    -- This is simpler and more reliable than trying to get bounding box dimensions
    local halfLength = 2.5
    
    -- Calculate front and back points along vehicle's longitudinal axis
    local frontPoint = pos + forward * halfLength
    local backPoint = pos - forward * halfLength
    
    return frontPoint, backPoint
end

-- Check if two line segments intersect (2D intersection, ignoring Z)
-- Algorithm: Two segments AB and CD intersect if:
-- 1. A and B are on opposite sides of line CD
-- 2. C and D are on opposite sides of line AB
-- Uses cross product to determine which side of a line a point is on
---@param a vec3 Point A of first line segment
---@param b vec3 Point B of first line segment
---@param c vec3 Point C of second line segment
---@param d vec3 Point D of second line segment
---@return boolean
local function segmentsIntersect(a, b, c, d)
    -- This is the core algorithm from BeamJoy's RaceWaypointManager
    -- Convert parameters to vec3 objects to support arithmetic operations
    -- Parameters might be regular Lua tables, so we ensure they're vec3 cdata
    a = vec3(a)
    b = vec3(b)
    c = vec3(c)
    d = vec3(d)
    
    local ab = b - a
    local ac = c - a
    local ad = d - a
    local cd = d - c
    local ca = a - c
    local cb = b - c
    
    -- Check if segments intersect using cross product
    -- If the signs of cross products are opposite, points are on different sides
    local cross_ac = ab:cross(ac).z
    local cross_ad = ab:cross(ad).z
    local cross_ca = cd:cross(ca).z
    local cross_cb = cd:cross(cb).z
    
    local cross1 = cross_ac * cross_ad
    local cross2 = cross_ca * cross_cb
    
    return cross1 < 0 and cross2 < 0
end

-- Check if vehicle crossed the finish line
-- Uses vehicle's front and back center points to detect crossing
---@param vehicle table BeamNG vehicle object
---@param pointA vec3 First point of finish line
---@param pointB vec3 Second point of finish line
---@return boolean crossingDetected
function M.checkLineCrossing(vehicle, pointA, pointB)
    if not vehicle or not pointA or not pointB then
        return false
    end
    
    -- Get current vehicle front and back points
    local currentFront, currentBack = getVehicleFrontBack(vehicle)
    if not currentFront or not currentBack then
        return false
    end
    
    -- Need previous position to detect crossing
    if not previousFront or not previousBack then
        previousFront = currentFront
        previousBack = currentBack
        previousCenter = (currentFront + currentBack) * 0.5
        return false
    end
    
    -- Check if vehicle trajectory crossed the finish line
    -- We check both front and back point trajectories
    local crossed = segmentsIntersect(pointA, pointB, previousFront, currentFront) or
                    segmentsIntersect(pointA, pointB, previousBack, currentBack)
    
    if crossed then
        -- Check cooldown to prevent multiple detections during single crossing
        local currentTime = os.clock()
        local timeSinceLastCrossing = currentTime - lastCrossingTime
        
        if timeSinceLastCrossing < crossingCooldown then
            log(string.format("Crossing detected but in cooldown (%.2fs since last)", timeSinceLastCrossing), "DEBUG")
            -- Update previous state but don't trigger callback
            previousFront = currentFront
            previousBack = currentBack
            previousCenter = (currentFront + currentBack) * 0.5
            return false
        end
        
        log("Line crossing detected!")
        
        -- Determine crossing direction
        -- Calculate line vector and its normal
        pointA = vec3(pointA)
        pointB = vec3(pointB)
        local lineVec = pointB - pointA
        local lineNormal = vec3(-lineVec.y, lineVec.x, 0)  -- Perpendicular to line
        lineNormal = lineNormal:normalized()  -- Normalize
        
        -- Calculate movement vector (from previous center to current center)
        local currentCenter = (currentFront + currentBack) * 0.5
        local movementVec = currentCenter - previousCenter
        
        -- Use dot product to determine direction
        local dot = lineNormal:dot(movementVec)
        local direction = "forward"
        if dot < 0 then
            direction = "backward"
        end
        
        log(string.format("Crossing direction: %s (dot: %.3f)", direction, dot))
        
        -- Update last crossing time
        lastCrossingTime = currentTime
        
        -- Trigger callback if set
        if onLineCrossedCallback then
            onLineCrossedCallback(direction)
        end
    end
    
    -- Update previous state
    previousFront = currentFront
    previousBack = currentBack
    previousCenter = (currentFront + currentBack) * 0.5
    
    return crossed
end

-- Update detector state (call this every frame)
---@param vehicle table BeamNG vehicle object
---@param pointA vec3|nil First point of finish line
---@param pointB vec3|nil Second point of finish line
function M.update(vehicle, pointA, pointB)
    if not vehicle then
        return
    end
    
    -- If no finish line configured, just update position tracking
    if not pointA or not pointB then
        local front, back = getVehicleFrontBack(vehicle)
        previousFront = front
        previousBack = back
        return
    end
    
    -- Check for line crossing
    M.checkLineCrossing(vehicle, pointA, pointB)
end

-- Set callback function to be called when line is crossed
---@param callback function Callback function()
function M.setOnLineCrossedCallback(callback)
    onLineCrossedCallback = callback
    log("Line crossed callback set")
end

-- Reset detector state (call when vehicle respawns or teleports)
function M.reset()
    log("Resetting CrossingDetector state")
    previousFront = nil
    previousBack = nil
    previousCenter = nil
    lastCrossingTime = 0  -- Reset cooldown
end

-- Draw debug visualization
---@param vehicle table BeamNG vehicle object
function M.drawDebugVisualization(vehicle)
    if not vehicle then return end
    
    local front, back = getVehicleFrontBack(vehicle)
    if not front or not back then return end
    
    -- Draw line connecting front and back points
    local lineColor = ColorF(0, 1, 1, 0.8)  -- Cyan
    debugDrawer:drawLine(
        Point3F(front.x, front.y, front.z),
        Point3F(back.x, back.y, back.z),
        lineColor
    )
    
    -- Draw front point (green sphere)
    local frontColor = ColorF(0, 1, 0, 0.9)  -- Green
    debugDrawer:drawSphere(
        Point3F(front.x, front.y, front.z),
        0.3,
        frontColor
    )
    
    -- Draw back point (red sphere)
    local backColor = ColorF(1, 0, 0, 0.9)  -- Red
    debugDrawer:drawSphere(
        Point3F(back.x, back.y, back.z),
        0.3,
        backColor
    )
end

-- Enable/disable debug mode
---@param enabled boolean
function M.setDebugMode(enabled)
    debugMode = enabled
    log("Debug mode: " .. tostring(enabled))
end

return M

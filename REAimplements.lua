-- ===========================================================
-- REA Implements FS25 – Realistic Implements Physics v1.0.5
-- Werte: 2.5 / 2.8 / 2.6 + Helfer-Boost
-- ===========================================================

REAimplements = {}
REAimplements.version = "1.0.5"

-- Realismus-Faktoren (aus deiner Vorgabe)
REAimplements.ImplementResistance = 2.6   -- Grundwiderstand der Anbaugeräte
REAimplements.PullForceScale      = 2.8   -- Zugkraft-Faktor (wie „schwer“ es zieht)
REAimplements.SoilSinkFactor      = 2.5   -- wie „weich“ der Boden für Geräte ist

REAimplements.HelperWeightFactor  = 2.4   -- Helfer fühlt mehr Gewicht
REAimplements.HelperGripBoost     = 1.8   -- mehr Grip für Helfer-Räder unter Last

REAimplements.Debug = false

----------------------------------------------------------------
-- Hilfsfunktionen
----------------------------------------------------------------
local function isHelperActive(vehicle)
    if vehicle.getIsAIActive ~= nil then
        return vehicle:getIsAIActive()
    end
    return false
end

local function hasWorkingImplement(vehicle)
    if vehicle.getAttachedImplements == nil then
        return false
    end

    for _, impl in ipairs(vehicle:getAttachedImplements()) do
        local object = impl.object
        if object ~= nil and object.spec_workArea ~= nil then
            if object.getIsWorkAreaActive ~= nil and object:getIsWorkAreaActive() then
                return true
            end
        end
    end

    return false
end

----------------------------------------------------------------
-- Haupt-Update
----------------------------------------------------------------
function REAimplements:update(dt)
    if g_currentMission == nil or g_currentMission.vehicles == nil then
        return
    end

    for _, vehicle in ipairs(g_currentMission.vehicles) do
        self:updateVehicleImplements(vehicle, dt)
    end
end

----------------------------------------------------------------
-- Physik für ein Fahrzeug + seine Anbaugeräte
----------------------------------------------------------------
function REAimplements:updateVehicleImplements(vehicle, dt)
    if vehicle.getAttachedImplements == nil then
        return
    end

    local impls = vehicle:getAttachedImplements()
    if impls == nil or #impls == 0 then
        return
    end

    local isHelper = isHelperActive(vehicle)
    local anyWorking = hasWorkingImplement(vehicle)

    -- nur arbeiten, wenn wirklich ein Gerät aktiv ist
    if not anyWorking then
        return
    end

    ----------------------------------------------------------------
    -- 1. Zusätzliche Zugkraft / Widerstand
    ----------------------------------------------------------------
    local activeAreaCount = 0

    for _, impl in ipairs(impls) do
        local object = impl.object
        if object ~= nil and object.spec_workArea ~= nil then
            if object.getIsWorkAreaActive ~= nil and object:getIsWorkAreaActive() then
                -- einfach: jedes aktive WorkArea-Tool zählt
                activeAreaCount = activeAreaCount + 1
            end
        end
    end

    if activeAreaCount > 0 and vehicle.components ~= nil and vehicle.components[1] ~= nil then
        local comp = vehicle.components[1]

        -- Grundkraft
        local baseForce = activeAreaCount * REAimplements.ImplementResistance

        -- hochskalieren
        local force = baseForce * REAimplements.PullForceScale

        -- Helfer boost
        if isHelper then
            force = force * REAimplements.HelperWeightFactor
        end

        -- Kraft in Fahrtrichtung entgegengesetzt ansetzen
        local dirX, dirY, dirZ = localDirectionToWorld(comp.node, 0, 0, -1)
        local px, py, pz = getWorldTranslation(comp.node)

        addForce(comp.node, dirX * force, dirY * force, dirZ * force, px, py, pz, true)

        -- Debug optional
        if REAimplements.Debug then
            DebugUtil.drawDebugTextAtWorldPos(px, py + 2, pz,
                string.format("REA Implements: Areas=%d Force=%.1f", activeAreaCount, force),
                0, 1, 0, 1)
        end
    end

    ----------------------------------------------------------------
    -- 2. Bodenwiderstand / Grip-Anpassung an Rädern
    ----------------------------------------------------------------
    if vehicle.spec_wheels ~= nil and vehicle.spec_wheels.wheels ~= nil then
        for _, wheel in ipairs(vehicle.spec_wheels.wheels) do
            -- Basis-Friction
            wheel.frictionScale = wheel.frictionScale or 1.0

            -- Mehr Widerstand durch „weichen“ Boden unter Gerät
            local soilFactor = 1.0 + (REAimplements.SoilSinkFactor * 0.10)
            wheel.frictionScale = wheel.frictionScale * soilFactor

            -- Helfer bekommt mehr Grip unter Last
            if isHelper then
                wheel.frictionScale = wheel.frictionScale * REAimplements.HelperGripBoost
            end
        end
    end
end

----------------------------------------------------------------
-- FS25 Event-Hooks
----------------------------------------------------------------
function REAimplements:loadMap()
    print(string.format("REAimplements v%s geladen (Realismus 2.5 / 2.8 / 2.6, Helfer aktiv)", REAimplements.version))
end

function REAimplements:deleteMap() end
function REAimplements:mouseEvent(posX, posY, isDown, isUp, button) end
function REAimplements:keyEvent(unicode, sym, modifier, isDown) end
function REAimplements:updateTick(dt) end

addModEventListener(REAimplements)

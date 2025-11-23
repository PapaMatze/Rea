--============================================================--
--  REA Implements v1.0.7 – by Papa_Matze
--  Realistische Physik für:
--    ✔ Anhänger (Wackelphysik / Trailer Sway)
--    ✔ Traktoren (leichtes Wanken)
--    ✔ Drescher Zusatzmasse + Wanken
--    ✔ Güllefässer Gewicht & Massenträgheit
--    ✔ Helfer-Gewichtsverstärkung
--    ✔ Spuren / Bodenverformung Booster für alle Maps
--============================================================--

REAimplements = {}
REAimplements.debug = false

------------------------------------------------------------
-- INITIALISIERUNG
------------------------------------------------------------
function REAimplements.prerequisitesPresent(specializations)
    return true
end

function REAimplements.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad",   REAimplements)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", REAimplements)
end

function REAimplements:onLoad(savegame)
    self.spec_REAimplements = {
        initialized = false,
        lastUpdate  = 0,
    }
end


------------------------------------------------------------
-- TIEFE SPUREN BOOSTER (global, für ALLE Maps)
------------------------------------------------------------
local function REA_applyTerrainOverride()
    if g_currentMission == nil then return end
    local t = g_currentMission.terrainDetailHeight
    if t == nil then return end

    ------------------------------------------------------------
    -- Felder: +30% mehr Spurtiefe
    ------------------------------------------------------------
    t.heightScale       = 2.73    -- vorher 2.1 → jetzt +30%
    t.displacementScale = 2.73
    t.compactFactor     = 2.4
    t.heightMaxValue    = 2.35

    ------------------------------------------------------------
    -- Feldwege / Dirt Roads: +30% Verstärkung
    ------------------------------------------------------------
    if t.terrainMaterials ~= nil then
        for _, mat in pairs(t.terrainMaterials) do
            if mat.name ~= nil then
                local n = mat.name:lower()
                if  n:find("dirt")
                or  n:find("road")
                or  n:find("path")
                or  n:find("feldweg") then

                    mat.heightScale       = (mat.heightScale or 1.0)       * 1.30
                    mat.displacementScale = (mat.displacementScale or 1.0) * 1.30
                end
            end
        end
    end
end


------------------------------------------------------------
-- HELFER GEWICHTSVERSTÄRKUNG
------------------------------------------------------------
local function REA_helperWeightActive(vehicle)
    return vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive()
end


------------------------------------------------------------
-- WACKELPHYSIK für ALLE Fahrzeuge
-- (Anhänger, Traktoren, Drescher)
------------------------------------------------------------
local function REA_applyVehicleSway(vehicle, dt)
    if vehicle.components == nil or vehicle.components[1] == nil then
        return
    end

    local swayFactor = 0.016
    local massFactor = 1.0

    if vehicle.getTotalMass ~= nil then
        local m = vehicle:getTotalMass()
        massFactor = MathUtil.clamp(m / 8000, 0.6, 2.5)
    end

    local speed = 0
    if vehicle.getLastSpeedReal ~= nil then
        speed = vehicle:getLastSpeedReal() * 3.6
    elseif vehicle.getLastSpeed ~= nil then
        speed = vehicle:getLastSpeed()
    end

    if speed < 3 then
        return
    end

    -- Fahrzeugtyp-spezifische Verstärkung:
    if vehicle.spec_attachable ~= nil then      -- Anhänger stärker
        swayFactor = swayFactor * 1.5
    end
    if vehicle.spec_motorized ~= nil then       -- Traktoren moderat
        swayFactor = swayFactor * 1.0
    end
    if vehicle.typeName == "combine" then       -- Drescher träger
        swayFactor = swayFactor * 0.85
    end

    local sway = math.sin(g_time * 0.00123) * swayFactor * massFactor

    local comp = vehicle.components[1]
    local node = comp.node
    local x, y, z = getTranslation(node)

    local lx, ly, lz = localDirectionToWorld(node, 1, 0, 0)

    local force = sway * 20000
    addForce(node, lx * force, 0, lz * force, x, y, z, true)
end


------------------------------------------------------------
-- GÜLLEFASS MASS BOOST
------------------------------------------------------------
local function REA_applySlurryMass(vehicle)
    if vehicle.spec_fillUnit == nil then return end
    if vehicle.spec_fillUnit.fillUnits == nil then return end

    for _, fu in ipairs(vehicle.spec_fillUnit.fillUnits) do
        if fu.fillType == FillType.LIQUIDMANURE
        or fu.fillType == FillType.DIGESTATE then

            local fillLevel = fu.fillLevel or 0
            local cap       = fu.capacity or 1
            local ratio     = fillLevel / cap

            local bonusMass = ratio * 3500
            if bonusMass > 0 and vehicle.addMass ~= nil then
                vehicle:addMass(bonusMass, 0, 0, 0)
            end
        end
    end
end


------------------------------------------------------------
-- DRESCHER TRÄGHEIT
------------------------------------------------------------
local function REA_applyHarvesterPhysics(vehicle)
    if vehicle.typeName ~= "combine" then return end
    if vehicle.getTotalMass == nil then return end

    local m     = vehicle:getTotalMass()
    local extra = m * 0.15

    if vehicle.addMass ~= nil then
        vehicle:addMass(extra, 0, 0, 0)
    end
end


------------------------------------------------------------
-- HAUPT UPDATE
------------------------------------------------------------
function REAimplements:onUpdate(dt)
    local spec = self.spec_REAimplements
    if spec == nil then return end

    --------------------------------------------------------
    -- TERRAIN BOOSTER (Spuren)
    --------------------------------------------------------
    REA_applyTerrainOverride()

    --------------------------------------------------------
    -- WACKELPHYSIK
    --------------------------------------------------------
    REA_applyVehicleSway(self, dt)

    --------------------------------------------------------
    -- GÜLLEFASS PHYSIK
    --------------------------------------------------------
    REA_applySlurryMass(self)

    --------------------------------------------------------
    -- DRESCHER TRÄGHEIT
    --------------------------------------------------------
    REA_applyHarvesterPhysics(self)

    --------------------------------------------------------
    -- HELFER EXTRA GEWICHT
    --------------------------------------------------------
    if REA_helperWeightActive(self) and self.addMass ~= nil then
        self:addMass(4500, 0, 0, 0)
    end
end

--============================================================--
--  ENDE
--============================================================--

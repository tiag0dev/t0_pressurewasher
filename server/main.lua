-- Autorité serveur : niveau d'eau, consommation, lavage des véhicules, remplissage (bouteilles d'eau).
-- Le client n'envoie que des intentions (jet actif, cible visée) ; tout est revalidé ici.

local inv = exports.ox_inventory
local sessions = {}  -- [src] = { slot, water, spraying, lastTick, lastMsg, lastFlush, dirty, aim }
local refills = {}   -- [src] = { slot, start, duration, pos }

local ITEM = Config.Item
local CAPACITY = Config.Tank.capacity
local MAX_WASH_DIST = Config.Jet.range + 1.5   -- joueur -> point d'impact
local MAX_VEH_DIST = Config.Jet.range + 4.0    -- joueur -> centre du véhicule
local MAX_AIM_TO_VEH = 6.0                      -- point d'impact -> centre du véhicule

-- L'arme doit être déclarée dans ox_inventory/data/weapons.lua (voir install/weapons.lua).
CreateThread(function()
    Wait(1000)
    if inv:Items(ITEM) then return end
    print(('^1[t0_pressurewasher] %s is missing from ox_inventory/data/weapons.lua.^7'):format(ITEM))
    print('^3Paste this entry into the Weapons table, then restart ox_inventory:^7')
    print(LoadResourceFile(GetCurrentResourceName(), 'install/weapons.lua') or '')
end)

local function getWater(metadata)
    local water = metadata and tonumber(metadata.water)
    if not water then return CAPACITY end      -- item neuf : réservoir plein
    return math.max(0.0, math.min(CAPACITY, water))
end

local function validSlot(slot)
    return type(slot) == 'number' and slot >= 1 and slot <= 200 and math.floor(slot) == slot
end

local function getWasher(src, slot)
    local item = inv:GetSlot(src, slot)
    if item and item.name == ITEM then return item end
end

local function setState(src, value)
    Player(src).state:set('t0_washer', value, true)
end

local function flush(src, s)
    if not s.dirty then return end
    local item = getWasher(src, s.slot)
    if not item then return end
    local metadata = item.metadata or {}
    metadata.water = math.floor(s.water * 10 + 0.5) / 10
    metadata.description = Config.Locale.tank:format(math.floor(s.water / CAPACITY * 100 + 0.5))
    inv:SetMetadata(src, s.slot, metadata)
    s.dirty = false
    s.lastFlush = GetGameTimer()
end

local function endSession(src, notifyClient)
    local s = sessions[src]
    if not s then return end
    pcall(flush, src, s)
    sessions[src] = nil
    setState(src, nil)
    if notifyClient then TriggerClientEvent('t0_pressurewasher:forceUnequip', src) end
end

lib.callback.register('t0_pressurewasher:equip', function(src, slot)
    if not validSlot(slot) then return false end
    local item = getWasher(src, slot)
    if not item then return false end
    if sessions[src] then endSession(src, false) end
    refills[src] = nil

    local now = GetGameTimer()
    sessions[src] = {
        slot = slot, water = getWater(item.metadata), spraying = false,
        lastTick = now, lastMsg = 0, lastFlush = now, dirty = false,
    }
    setState(src, { on = true, spray = false })
    return sessions[src].water
end)

RegisterNetEvent('t0_pressurewasher:unequip', function()
    local src = source
    if src <= 0 then return end
    endSession(src, false)
end)

local function washVehicle(src, ped, netId, aim, dt)
    if type(netId) ~= 'number' or netId <= 0 then return end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end

    local pedCoords = GetEntityCoords(ped)
    local vehCoords = GetEntityCoords(veh)
    if #(pedCoords - vehCoords) > MAX_VEH_DIST or #(aim - vehCoords) > MAX_AIM_TO_VEH then return end

    -- Efficacité selon la distance buse -> impact (approchée par joueur -> impact).
    local dist = #(pedCoords - aim)
    local factor
    if dist < Config.Jet.minDistance or dist > Config.Jet.range then
        factor = 0.0
    elseif dist <= Config.Jet.effective then
        factor = 1.0
    else
        factor = 1.0 - (dist - Config.Jet.effective) / (Config.Jet.range - Config.Jet.effective)
    end
    if factor <= 0.0 then return end

    local dirt = GetVehicleDirtLevel(veh)
    if dirt <= 0.0 then return end
    -- Native serveur : appliquée par le propriétaire réseau actuel du véhicule, puis synchronisée.
    SetVehicleDirtLevel(veh, math.max(0.0, dirt - Config.Wash.speed * dt * factor))
end

RegisterNetEvent('t0_pressurewasher:spray', function(on, netId, aim)
    local src = source
    if src <= 0 then return end
    local s = sessions[src]
    if not s then return end

    local now = GetGameTimer()
    on = on == true
    -- Anti-spam : un message par TickMs environ ; un arrêt est toujours accepté.
    if on and now - s.lastMsg < Config.TickMs * 0.5 then return end
    s.lastMsg = now

    if not getWasher(src, s.slot) then return endSession(src, true) end

    local dt = 0.0
    if s.spraying then
        dt = math.min(now - s.lastTick, Config.TickMs * 2) / 1000.0
    end
    s.lastTick = now

    if dt > 0.0 then
        s.water = math.max(0.0, s.water - dt * Config.Tank.consumption)
        s.dirty = true
    end

    if not on or s.water <= 0.0 or refills[src] then
        local wasEmpty = s.water <= 0.0
        s.spraying = false
        flush(src, s)
        setState(src, { on = true, spray = false })
        if wasEmpty and on then TriggerClientEvent('t0_pressurewasher:empty', src) end
        return
    end

    if type(aim) ~= 'vector3' then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - aim) > MAX_WASH_DIST then return end

    if dt > 0.0 then washVehicle(src, ped, netId, aim, dt) end

    if not s.spraying or not s.aim or #(s.aim - aim) > 0.35 then
        setState(src, { on = true, spray = true, aim = aim })
        s.aim = aim
    end
    s.spraying = true

    if now - s.lastFlush >= Config.FlushMs then flush(src, s) end
end)

---------------------------------------------------------------------------
-- Remplissage
---------------------------------------------------------------------------

-- Une bouteille (Config.Refill.item) ajoute Config.Refill.percentPerItem % du réservoir.
local PER_ITEM = CAPACITY * Config.Refill.percentPerItem / 100

lib.callback.register('t0_pressurewasher:refillStart', function(src, slot)
    if refills[src] then return false, 'busy' end
    if not validSlot(slot) then return false end
    local item = getWasher(src, slot)
    if not item then return false, 'no_washer' end

    local ped = GetPlayerPed(src)
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'busy' end

    local s = sessions[src]
    if s and s.spraying then return false, 'busy' end

    local water = (s and s.slot == slot) and s.water or getWater(item.metadata)
    if CAPACITY - water < 0.5 then return false, 'full' end
    if (inv:GetItemCount(src, Config.Refill.item) or 0) < 1 then return false, 'no_bottle' end

    local duration = Config.Refill.seconds
    refills[src] = { slot = slot, start = GetGameTimer(), duration = duration * 1000, pos = GetEntityCoords(ped) }
    return duration
end)

lib.callback.register('t0_pressurewasher:refillFinish', function(src)
    local r = refills[src]
    refills[src] = nil
    if not r then return false end
    if GetGameTimer() - r.start < r.duration - 300 then return false end

    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - r.pos) > 2.5 then return false end
    local item = getWasher(src, r.slot)
    if not item then return false end

    local s = sessions[src]
    local current = (s and s.slot == r.slot) and s.water or getWater(item.metadata)
    if CAPACITY - current < 0.5 then return false end
    -- La bouteille est retirée avant d'ajouter l'eau : pas d'eau sans item consommé.
    if not inv:RemoveItem(src, Config.Refill.item, 1) then return false end
    local water = math.min(CAPACITY, current + PER_ITEM)

    if s and s.slot == r.slot then
        s.water = water
        s.dirty = true
        flush(src, s)
    else
        local metadata = item.metadata or {}
        metadata.water = math.floor(water * 10 + 0.5) / 10
        metadata.description = Config.Locale.tank:format(math.floor(water / CAPACITY * 100 + 0.5))
        inv:SetMetadata(src, r.slot, metadata)
    end
    return water
end)

RegisterNetEvent('t0_pressurewasher:refillCancel', function()
    local src = source
    if src <= 0 then return end
    refills[src] = nil
end)

---------------------------------------------------------------------------
-- Nettoyage
---------------------------------------------------------------------------

-- Client muet (lag, crash) pendant un jet : on coupe l'état visible par les autres.
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for src, s in pairs(sessions) do
            if s.spraying and now - s.lastMsg > Config.TickMs * 4 then
                s.spraying = false
                flush(src, s)
                setState(src, { on = true, spray = false })
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    refills[src] = nil
    local s = sessions[src]
    if s then
        pcall(flush, src, s)
        sessions[src] = nil
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src, s in pairs(sessions) do
        pcall(flush, src, s)
        setState(src, nil)
    end
end)

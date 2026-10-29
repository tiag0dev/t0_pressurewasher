-- Nettoyeur haute pression : jet, raycast, effets, envoi des intentions au serveur.
-- Arme addon WEAPON_PRESSUREWASHER (data/*.meta) équipée par ox_inventory : postures, visée et
-- caméra de fusil natives. Aucun dégât (DamageType/FireType NONE) et tir bloqué par le script.

PW = {
    equipped = nil,    -- { slot, water, prop (entité de l'arme), ptfx, spraying, ... }
    refilling = false,
}

local ITEM = Config.Item
local HASH = joaat(ITEM)
local RAY_FLAGS = 1 | 2 | 16   -- carte, véhicules, objets

local function notify(msg, kind)
    lib.notify({ description = msg, type = kind or 'inform' })
end

local function rotToDir(rot)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(rx))
    return vec3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

-- Repère local d'un prop -> rotation (degrés) qui oriente l'axe +Y d'un effet selon `localDir`.
function PW.localRotation(localDir)
    local pitch = math.deg(math.asin(math.max(-1.0, math.min(1.0, localDir.z))))
    local yaw = math.deg(math.atan(-localDir.x, localDir.y))
    local o = Config.Jet.rotOffset
    return pitch + o.x, o.y, yaw + o.z
end

-- Direction monde -> repère du prop (sans dépendre de l'ordre des vecteurs de GetEntityMatrix).
function PW.toLocalDir(prop, origin, dir)
    local a = GetOffsetFromEntityGivenWorldCoords(prop, origin.x, origin.y, origin.z)
    local b = GetOffsetFromEntityGivenWorldCoords(prop, origin.x + dir.x, origin.y + dir.y, origin.z + dir.z)
    return b - a
end

-- Entité du nettoyeur en main (0 si le ped tient autre chose ou si l'arme n'est pas encore créée).
function PW.weaponEntity(ped)
    if GetSelectedPedWeapon(ped) ~= HASH then return 0 end
    return GetCurrentPedWeaponEntityIndex(ped)
end

-- Le jet est une liste d'effets superposés (Config.Jet.effects) : on manipule la liste des handles.
function PW.startJet(prop)
    local n = Config.NozzleOffset
    local list = {}
    for _, fx in ipairs(Config.Jet.effects) do
        for _ = 1, fx.layers or 1 do
            UseParticleFxAsset(Config.Jet.asset)
            local handle = StartParticleFxLoopedOnEntity(fx.effect, prop, n.x, n.y, n.z, 0.0, 0.0, 0.0,
                fx.scale, false, false, false)
            if fx.alpha then SetParticleFxLoopedAlpha(handle, fx.alpha) end
            list[#list + 1] = { handle = handle, rot = fx.rot or vec3(0.0, 0.0, 0.0) }
        end
    end
    return list
end

function PW.aimJet(ptfx, prop, nozzle, target)
    local dir = target - nozzle
    if #dir < 0.01 then return end
    local rx, ry, rz = PW.localRotation(PW.toLocalDir(prop, nozzle, dir / #dir))
    local n = Config.NozzleOffset
    for _, fx in ipairs(ptfx) do
        SetParticleFxLoopedOffsets(fx.handle, n.x, n.y, n.z, rx + fx.rot.x, ry + fx.rot.y, rz + fx.rot.z)
    end
end

function PW.stopJet(ptfx)
    if not ptfx then return end
    for _, fx in ipairs(ptfx) do StopParticleFxLooped(fx.handle, false) end
end

-- L'effet d'extincteur s'épuise de lui-même : on le relance à intervalle régulier, le nouveau avant
-- d'arrêter l'ancien pour ne pas laisser de trou. Retourne la liste à utiliser et la prochaine échéance.
function PW.keepJet(ptfx, prop, due, now)
    if ptfx and now < due then return ptfx, due end
    local fresh = PW.startJet(prop)
    PW.stopJet(ptfx)
    return fresh, now + Config.Jet.refreshMs
end

function PW.splash(coords)
    for _, fx in ipairs(Config.Jet.impactEffects) do
        UseParticleFxAsset(Config.Jet.asset)
        StartParticleFxNonLoopedAtCoord(fx.effect, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0,
            fx.scale, false, false, false)
    end
end

function PW.sound(id, on, gain)
    if not Config.Sound.enabled then return end
    SendNUIMessage({ action = 'sound', id = id, on = on, gain = gain or 1.0 })
end

local function gauge(show, water)
    SendNUIMessage({ action = 'gauge', show = show, value = water and water / Config.Tank.capacity or 0 })
end

---------------------------------------------------------------------------
-- Visée : caméra -> point visé, puis buse -> point visé (pas de lavage à travers les murs)
---------------------------------------------------------------------------

local function probe(from, to, ignore)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z,
        RAY_FLAGS, ignore, 7)
    local _, hit, coords, _, entity = GetShapeTestResult(handle)
    return hit == 1, coords, entity
end

local function computeJet(ped, nozzle, camCoords, camRot)
    local camDir = rotToDir(camRot)
    local camReach = #(camCoords - nozzle) + Config.Jet.range
    local hit, aimPoint = probe(camCoords, camCoords + camDir * camReach, ped)
    if not hit then aimPoint = camCoords + camDir * camReach end

    local dir = aimPoint - nozzle
    local len = #dir
    if len < 0.01 then dir, len = camDir, 1.0 end
    dir = dir / len

    local jetEnd = nozzle + dir * Config.Jet.range
    local jetHit, impact, entity = probe(nozzle, jetEnd, ped)
    if not jetHit then return false, jetEnd, 0 end
    return true, impact, entity
end

---------------------------------------------------------------------------
-- Équiper / ranger
---------------------------------------------------------------------------

local function stopSpraying(e, tellServer)
    if not e.spraying then return end
    e.spraying = false
    PW.stopJet(e.ptfx)
    e.ptfx = nil
    PW.sound('self', false)
    if tellServer then TriggerServerEvent('t0_pressurewasher:spray', false) end
end

function PW.unequip(tellServer)
    local e = PW.equipped
    if not e then return end
    PW.equipped = nil
    stopSpraying(e, false)
    gauge(false)
    if tellServer then TriggerServerEvent('t0_pressurewasher:unequip') end
end

local function equipLoop()
    local ped = cache.ped
    local disable = Config.Controls.disable
    local nextTick, nextImpact, nextGauge = 0, 0, 0
    local lastNet, lastAim = 0, nil

    while PW.equipped do
        local e = PW.equipped
        local now = GetGameTimer()
        ped = cache.ped

        -- Arme rangée, changée ou retirée par ox_inventory (mort, inventaire...).
        if IsEntityDead(ped) or GetSelectedPedWeapon(ped) ~= HASH then
            PW.unequip(true)
            break
        end
        e.prop = PW.weaponEntity(ped)

        -- Pas de tir GTA : le clic gauche ne sert qu'au jet.
        for i = 1, #disable do DisableControlAction(0, disable[i], true) end
        DisablePlayerFiring(cache.playerId, true)

        -- Recharge (R, désactivée ci-dessus) : une bouteille d'eau.
        if not PW.refilling and not e.spraying and IsDisabledControlJustPressed(0, Config.Refill.key)
            and not IsPauseMenuActive() then
            CreateThread(PW.refill)
        end

        -- Visée et caméra natives de l'arme (posture fusil).
        local camRot = GetGameplayCamRot(2)
        local camCoords = GetGameplayCamCoord()
        local aiming = not PW.refilling and IsPlayerFreeAiming(cache.playerId)

        local wantSpray = e.prop ~= 0 and not PW.refilling and e.water > 0.0
            and (aiming or not Config.Aim.requireAim) and not IsPedInAnyVehicle(ped, false)
            and IsDisabledControlPressed(0, Config.Controls.spray) and not IsPauseMenuActive()

        if wantSpray then
            if not e.spraying then
                e.spraying = true
                e.ptfx = nil
                PW.sound('self', true, 1.0)
                nextTick = 0
            end
            e.ptfx, e.jetDue = PW.keepJet(e.ptfx, e.prop, e.jetDue or 0, now)
            if not aiming then SetEntityHeading(ped, camRot.z) end

            local nozzle = GetOffsetFromEntityInWorldCoords(e.prop, Config.NozzleOffset.x, Config.NozzleOffset.y,
                Config.NozzleOffset.z)
            local hit, impact, entity = computeJet(ped, nozzle, camCoords, camRot)
            PW.aimJet(e.ptfx, e.prop, nozzle, impact)

            if hit and now >= nextImpact then
                PW.splash(impact)
                nextImpact = now + Config.Jet.impactInterval
            end

            e.water = math.max(0.0, e.water - GetFrameTime() * Config.Tank.consumption)

            if now >= nextTick then
                local netId = 0
                if hit and entity ~= 0 and GetEntityType(entity) == 2 and NetworkGetEntityIsNetworked(entity) then
                    netId = VehToNet(entity)
                end
                lastNet, lastAim = netId, impact
                TriggerServerEvent('t0_pressurewasher:spray', true, netId, impact)
                nextTick = now + Config.TickMs
            end

            if Config.Debug then
                DrawMarker(28, nozzle.x, nozzle.y, nozzle.z, 0, 0, 0, 0, 0, 0, 0.03, 0.03, 0.03, 0, 200, 255, 200,
                    false, false, 2, false, nil, nil, false)
                DrawMarker(28, impact.x, impact.y, impact.z, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12,
                    hit and 0 or 255, hit and 255 or 0, 0, 160, false, false, 2, false, nil, nil, false)
            end
        elseif e.spraying then
            stopSpraying(e, true)
            if e.water <= 0.0 then notify(Config.Locale.empty, 'error') end
        end

        if now >= nextGauge then
            gauge(true, e.water)
            nextGauge = now + 250
        end

        Wait(0)
    end
end

-- Appelé quand ox_inventory a sorti l'arme WEAPON_PRESSUREWASHER (slot validé par le serveur).
local function equip(slot)
    local water = lib.callback.await('t0_pressurewasher:equip', false, slot)
    if not water then return notify(Config.Locale.busy, 'error') end

    lib.requestNamedPtfxAsset(Config.Jet.asset, 5000)
    local ped = cache.ped
    if GetSelectedPedWeapon(ped) ~= HASH then
        TriggerServerEvent('t0_pressurewasher:unequip')
        return
    end

    -- Pas de munitions réelles : munition infinie pour que la visée reste possible.
    SetPedInfiniteAmmo(ped, true, HASH)
    SetPedAmmo(ped, HASH, 1)
    SendNUIMessage({ action = 'volume', value = Config.Sound.volume })
    PW.equipped = { slot = slot, water = water, prop = 0, spraying = false }
    if water <= 0.0 then notify(Config.Locale.empty, 'error') end
    CreateThread(equipLoop)
end

---------------------------------------------------------------------------
-- Événements : serveur, inventaire, arrêt de la ressource
---------------------------------------------------------------------------

RegisterNetEvent('t0_pressurewasher:forceUnequip', function()
    PW.unequip(false)
end)

RegisterNetEvent('t0_pressurewasher:empty', function()
    local e = PW.equipped
    if not e then return end
    e.water = 0.0
    stopSpraying(e, false)
    notify(Config.Locale.empty, 'error')
end)

-- Item retiré, déplacé ou modifié (le serveur réécrit aussi les métadonnées : niveau d'eau).
AddEventHandler('ox_inventory:updateInventory', function(changes)
    local e = PW.equipped
    if not e or type(changes) ~= 'table' then return end
    local item = changes[e.slot]
    if item == nil then return end
    if not item or item.name ~= ITEM then return PW.unequip(true) end
    local water = item.metadata and tonumber(item.metadata.water)
    if water and not e.spraying then e.water = water end
end)

AddEventHandler('ox_inventory:itemCount', function(name, count)
    if name == ITEM and count == 0 and PW.equipped then PW.unequip(true) end
end)

-- ox_inventory sort ou range une arme : le nettoyeur suit l'arme en main.
AddEventHandler('ox_inventory:currentWeapon', function(weapon)
    local e = PW.equipped
    if weapon and weapon.name == ITEM then
        if e and e.slot == weapon.slot then return end
        if e then PW.unequip(true) end
        equip(weapon.slot)
    elseif e then
        PW.unequip(true)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    PW.unequip(false)
    RemoveNamedPtfxAsset(Config.Jet.asset)
end)

---------------------------------------------------------------------------
-- Debug : réglage de la prise en main
---------------------------------------------------------------------------

if Config.Debug then
    -- /pwfx <effet core> <échelle> : remplace l'effet d'impact pour l'essayer. /pwfx reset : config.
    local defaultImpact = Config.Jet.impactEffects
    RegisterCommand('pwfx', function(_, args)
        if args[1] == 'reset' or not args[1] then
            Config.Jet.impactEffects = defaultImpact
        else
            Config.Jet.impactEffects = { { effect = args[1], scale = tonumber(args[2]) or 1.0 } }
        end
        print(('impact : %s'):format(json.encode(Config.Jet.impactEffects)))
    end, false)

    RegisterCommand('pwpos', function()
        local c = GetEntityCoords(cache.ped)
        print(('vec3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z))
    end, false)
end

-- /pwjet <taille> <opacité> <couches> [pitch] : règle le premier effet du jet (au prochain appui).
-- /pwjet reset : config. Rendu local uniquement (les autres joueurs gardent la config).
if Config.Jet.tuneCommand then
    local defaultJet = lib.table.deepclone(Config.Jet.effects)
    RegisterCommand('pwjet', function(_, args)
        if args[1] == 'reset' or not args[1] then
            Config.Jet.effects = lib.table.deepclone(defaultJet)
        else
            local fx = Config.Jet.effects[1]
            fx.scale = tonumber(args[1]) or fx.scale
            fx.alpha = tonumber(args[2]) or fx.alpha
            fx.layers = math.max(1, math.min(5, math.floor(tonumber(args[3]) or fx.layers or 1)))
            if tonumber(args[4]) then fx.rot = vec3(tonumber(args[4]), 0.0, 0.0) end
        end
        local fx = Config.Jet.effects[1]
        local msg = ('scale = %.2f, alpha = %.2f, layers = %d, pitch = %.0f'):format(fx.scale, fx.alpha or 1.0,
            fx.layers or 1, fx.rot and fx.rot.x or 0.0)
        print('jet : ' .. msg)
        lib.notify({ title = 'Brume', description = msg, type = 'inform' })
    end, false)
end

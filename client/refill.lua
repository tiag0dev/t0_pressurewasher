-- Remplissage du réservoir avec des bouteilles d'eau (Config.Refill.item), nettoyeur en main.
-- Touche Config.Refill.key (R) : une bouteille consommée par appui, le serveur fait le calcul.

local KEEP = { 1, 2, 199, 200 } -- caméra et menu pause restent actifs pendant le remplissage
local bottle

local function deleteBottle()
    if bottle and DoesEntityExist(bottle) then DeleteEntity(bottle) end
    bottle = nil
end

-- Anim de versement + bouteille en main + illustration NUI. Renvoie false si annulé.
local function pourScene(ms, from, to)
    local ped = cache.ped
    local a, p = Config.Refill.anim, Config.Refill.prop
    local animOk = a and pcall(lib.requestAnimDict, a.dict, 2000)
    if animOk then TaskPlayAnim(ped, a.dict, a.clip, 3.0, 3.0, -1, a.flag, 0.0, false, false, false) end

    if p and pcall(lib.requestModel, p.model, 2000) then
        local c = GetEntityCoords(ped)
        bottle = CreateObject(p.model, c.x, c.y, c.z, false, false, false)
        AttachEntityToEntity(bottle, ped, GetPedBoneIndex(ped, p.bone), p.pos.x, p.pos.y, p.pos.z,
            p.rot.x, p.rot.y, p.rot.z, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(p.model)
    end

    SendNUIMessage({ action = 'refill', show = true, from = from, to = to, duration = ms,
        label = Config.Locale.refilling, cancel = Config.Locale.cancel })

    local ok, ends = true, GetGameTimer() + ms
    while GetGameTimer() < ends do
        DisableAllControlActions(0)
        for i = 1, #KEEP do EnableControlAction(0, KEEP[i], true) end
        if IsDisabledControlJustPressed(0, Config.Refill.cancelKey) or IsEntityDead(ped)
            or IsPedInAnyVehicle(ped, false) or not PW.equipped then
            ok = false
            break
        end
        Wait(0)
    end

    SendNUIMessage({ action = 'refill', show = false })
    if animOk then
        StopAnimTask(ped, a.dict, a.clip, 2.0)
        RemoveAnimDict(a.dict)
    end
    deleteBottle()
    return ok
end

function PW.refill()
    if PW.refilling then return end
    local e = PW.equipped
    local ped = cache.ped
    if not e or e.spraying or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end

    PW.refilling = true   -- posé avant l'appel serveur : pas de double déclenchement
    local duration, reason = lib.callback.await('t0_pressurewasher:refillStart', false, e.slot)
    if not duration then
        PW.refilling = false
        return lib.notify({ description = Config.Locale[reason or 'busy'] or Config.Locale.busy, type = 'error', style = Config.NotifyStyle })
    end

    SetPedCurrentWeaponVisible(ped, false, false, false, false)

    -- Niveaux affichés seulement : le serveur recalcule l'eau réelle.
    local cap = Config.Tank.capacity
    local from = e.water / cap
    local to = math.min(1.0, from + Config.Refill.percentPerItem / 100)
    local ok = pourScene(math.floor(duration * 1000), from, to)

    local water
    if ok then
        water = lib.callback.await('t0_pressurewasher:refillFinish', false)
    else
        TriggerServerEvent('t0_pressurewasher:refillCancel')
    end

    e = PW.equipped
    if e then
        SetPedCurrentWeaponVisible(cache.ped, true, false, false, false)
        if water then e.water = water end
    end
    PW.refilling = false

    if water then
        lib.notify({ description = Config.Locale.refilled:format(math.floor(water / Config.Tank.capacity * 100 + 0.5)), type = 'success', style = Config.NotifyStyle })
    end
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    deleteBottle()
end)

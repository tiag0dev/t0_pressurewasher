-- Rendu du jet des autres joueurs à partir du state bag `t0_washer` ({ on, spray, aim }) posé par
-- le serveur. L'arme elle-même est synchronisée par GTA ; le jet part de son entité.

local remotes = {}   -- [serverId] = { ped, prop (entité de l'arme), ptfx, aim, spray, nextSplash }

local function clear(sid)
    local r = remotes[sid]
    if not r then return end
    PW.stopJet(r.ptfx)
    PW.sound('r' .. sid, false)
    remotes[sid] = nil
end

local assetsReady = false
local function ensureAssets()
    if not assetsReady then
        lib.requestNamedPtfxAsset(Config.Jet.asset, 5000)
        assetsReady = true
    end
end

local drawing = false

local function drawLoop()
    drawing = true
    while true do
        local any = false
        local myCoords = GetEntityCoords(cache.ped)
        local now = GetGameTimer()
        for sid, r in pairs(remotes) do
            local weapon = PW.weaponEntity(r.ped)
            if weapon ~= r.prop then PW.stopJet(r.ptfx); r.ptfx = nil; r.prop = weapon end
            if r.spray and r.aim and r.prop ~= 0 and DoesEntityExist(r.prop) then
                any = true
                local n = Config.NozzleOffset
                local nozzle = GetOffsetFromEntityInWorldCoords(r.prop, n.x, n.y, n.z)
                r.ptfx, r.jetDue = PW.keepJet(r.ptfx, r.prop, r.jetDue or 0, now)
                PW.aimJet(r.ptfx, r.prop, nozzle, r.aim)
                if now >= r.nextSplash then
                    PW.splash(r.aim)
                    r.nextSplash = now + Config.Jet.impactInterval * 2
                end
                local d = #(myCoords - nozzle)
                PW.sound('r' .. sid, d < Config.Sound.maxDistance,
                    math.max(0.0, 1.0 - d / Config.Sound.maxDistance))
            elseif r.ptfx then
                PW.stopJet(r.ptfx)
                r.ptfx = nil
                PW.sound('r' .. sid, false)
            end
        end
        if not any then break end
        Wait(0)
    end
    drawing = false
end

CreateThread(function()
    local myId = cache.serverId
    while true do
        local myCoords = GetEntityCoords(cache.ped)
        local seen = {}
        local anySpray = false

        for _, pid in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(pid)
            if sid ~= myId then
                local state = Player(sid).state.t0_washer
                local ped = GetPlayerPed(pid)
                if state and state.on and ped ~= 0 and #(GetEntityCoords(ped) - myCoords) <= Config.Remote.drawDistance
                    and not IsPedInAnyVehicle(ped, false) then
                    seen[sid] = true
                    local r = remotes[sid]
                    if r and r.ped ~= ped then clear(sid); r = nil end
                    if not r then
                        ensureAssets()
                        r = { ped = ped, prop = 0, nextSplash = 0 }
                        remotes[sid] = r
                    end
                    r.spray = state.spray == true and type(state.aim) == 'vector3'
                    r.aim = state.aim
                    if r.spray then anySpray = true end
                end
            end
        end

        for sid in pairs(remotes) do
            if not seen[sid] then clear(sid) end
        end

        if anySpray and not drawing then CreateThread(drawLoop) end
        Wait(next(remotes) and 300 or 1000)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for sid in pairs(remotes) do clear(sid) end
end)

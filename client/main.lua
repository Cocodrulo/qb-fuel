-- ====================|| VARIABLES || ==================== --

QBCore = exports['qb-core']:GetCoreObject()
CurrentPump = nil
CurrentObjects = { nozzle = nil, rope = nil }
-- ====================|| FUNCTIONS || ==================== --

local refuelVehicle = function (veh)
    if not veh or not DoesEntityExist(veh) then return QBCore.Functions.Notify(Lang:t('error.no_vehicle')) end
    local ped = PlayerPedId()
    local canLiter = GetAmmoInPedWeapon(ped, `WEAPON_PETROLCAN`)
    local vehFuel = math.floor(GetFuel(veh) or 0)
    if canLiter == 0 then return QBCore.Functions.Notify(Lang:t('error.no_fuel_can'), 'error') end
    if vehFuel == 100 then return QBCore.Functions.Notify(Lang:t('error.vehicle_full'), 'error') end
    local liter = canLiter + vehFuel > 100 and 100 - vehFuel or canLiter

    QBCore.Functions.LoadAnimDict('timetable@gardener@filling_can')
    TaskPlayAnim(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 2.0, 8.0, -1, 50, 0, false, false, false)

    QBCore.Functions.Progressbar('fueling_vehicle', Lang:t('progress.refueling'), Config.RefillTimePerLitre * liter * 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('qb-fuel:server:setCanFuel', canLiter - liter)
        SetPedAmmo(ped, `WEAPON_PETROLCAN`, canLiter - liter)
        SetFuel(veh, vehFuel + liter)
        QBCore.Functions.Notify(Lang:t('success.refueled'), 'success')
    end, function() end)
end

local grabFuelFromPump = function()
    if not CurrentPump then return end
	local ped = PlayerPedId()
	local pump = GetEntityCoords(CurrentPump)
    QBCore.Functions.LoadAnimDict('anim@am_hold_up@male')
    TaskPlayAnim(ped, 'anim@am_hold_up@male', 'shoplift_high', 2.0, 8.0, -1, 50, 0, false, false, false)
    Wait(300)
    CurrentObjects.nozzle = CreateObject('prop_cs_fuel_nozle', 0, 0, 0, true, true, true)
    AttachEntityToEntity(CurrentObjects.nozzle, ped, GetPedBoneIndex(ped, 0x49D9), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)
    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
    end
    CurrentObjects.rope = AddRope(pump.x, pump.y, pump.z, 0.0, 0.0, 0.0, 3.0, 1, 1000.0, 0.0, 1.0, false, false, false, 1.0, true)
    ActivatePhysics(CurrentObjects.rope)
    Wait(50)
    local nozzlePos = GetOffsetFromEntityInWorldCoords(CurrentObjects.nozzle, 0.0, -0.033, -0.195)
    AttachEntitiesToRope(CurrentObjects.rope, CurrentPump, CurrentObjects.nozzle, pump.x, pump.y, pump.z + 1.45, nozzlePos.x, nozzlePos.y, nozzlePos.z, 5.0, false, false, '', '')
end

local removeObjects = function ()
    if CurrentObjects.nozzle then
        DeleteEntity(CurrentObjects.nozzle)
        CurrentObjects.nozzle = nil
    end
    if CurrentObjects.rope then
        DeleteRope(CurrentObjects.rope)
        RopeUnloadTextures()
        CurrentObjects.rope = nil
    end
end

local refillVehicleFuel = function (liter)
    if QBCore.PlayerData.money[Config.MoneyType] < liter * Config.FuelPrice then return QBCore.Functions.Notify(Lang:t('error.no_money'), 'error') end
    if not CurrentPump then return end
    local veh, dis = QBCore.Functions.GetClosestVehicle()
    if not veh or veh == -1 or not DoesEntityExist(veh) then return end
    if dis > 5 then return end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, veh, 1000)
    Wait(1000)
    grabFuelFromPump()
    QBCore.Functions.LoadAnimDict('timetable@gardener@filling_can')
    TaskPlayAnim(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 2.0, 8.0, -1, 50, 0, false, false, false)

    QBCore.Functions.Progressbar('fueling_vehicle', Lang:t('progress.refueling'), Config.RefillTimePerLitre * liter * 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        removeObjects()
        local success = QBCore.Functions.TriggerCallback('qb-fuel:server:refillVehicle', liter)

        if not success then return QBCore.Functions.Notify(Lang:t('error.no_money'), 'error') end
        SetFuel(veh, math.floor(GetFuel(veh) or 0) + liter)
        QBCore.Functions.Notify(Lang:t('success.refueled'), 'success')
    end, function()
        removeObjects()
    end)
end

local showFuelMenu = function (ent)
    CurrentPump = ent
    local veh, dis = QBCore.Functions.GetClosestVehicle()
    if not veh or veh == -1 then return QBCore.Functions.Notify(Lang:t('error.no_vehicle')) end
    if dis > 5 then return QBCore.Functions.Notify(Lang:t('error.no_vehicle')) end
    SendNUIMessage({
        action = 'show',
        price = Config.FuelPrice,
        currentFuel = math.floor(GetFuel(veh) or 0),
    })
    SetNuiFocus(true, true)
end

local hideFuelMenu = function ()
    SendNUIMessage({
        action = 'hide'
    })
    SetNuiFocus(false, false)
end

local displayBlips = function ()
    for _, station in ipairs(Config.GasStations) do
        local blip = AddBlipForCoord(station.x, station.y, station.z)
        SetBlipSprite(blip, Config.Blip.Sprite)
        SetBlipColour(blip, Config.Blip.Color)
        SetBlipScale(blip, Config.Blip.Scale)
        SetBlipDisplay(blip, Config.Blip.Display)
        SetBlipAsShortRange(blip, Config.Blip.ShortRange)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Blip.Text)
        EndTextCommandSetBlipName(blip)
    end
end

local setUpTarget = function ()
    for _, hash in pairs(Config.PumpModels) do
        exports['qb-target']:AddTargetModel(hash, {
            options = {
                {
                    num = 1,
                    icon = 'fa-solid fa-gas-pump',
                    label = Lang:t('target.put_fuel'),
                    action = showFuelMenu
                },
                {
                    num = 2,
                    type = 'server',
                    event = 'qb-fuel:server:buyJerryCan',
                    icon = 'fa-solid fa-jar',
                    label = Lang:t('target.buy_jerrycan', { price = Config.JerryCanCost }),
                },
                {
                    num = 3,
                    type = 'server',
                    event = 'qb-fuel:server:refillJerryCan',
                    icon = 'fa-solid fa-arrows-rotate',
                    label = Lang:t('target.refill_jerrycan', { price = Config.JerryCanCost }),
                    canInteract = function()
                        return GetSelectedPedWeapon(PlayerPedId()) == `WEAPON_PETROLCAN`
                    end
                }
            },
            distance = 1.5
        })
    end

    exports['qb-target']:AddGlobalVehicle({
        options = {
            {
                num = 1,
                icon = 'fa-solid fa-gas-pump',
                label = Lang:t('target.refill_fuel'),
                action = refuelVehicle,
                canInteract = function()
                    return GetSelectedPedWeapon(PlayerPedId()) == `WEAPON_PETROLCAN`
                end
            }
        },
        distance = 3
    })
end

local init = function ()
    SetFuelConsumptionState(true)
    SetFuelConsumptionRateMultiplier(Config.GlobalFuelConsumptionMultiplier)

    displayBlips()
    setUpTarget()
end

-- ====================|| NUI CALLBACKS || ==================== --

RegisterNuiCallback('close', function (_, cb)
    hideFuelMenu()
    cb('ok')
end)

RegisterNuiCallback('refill', function (data, cb)
    hideFuelMenu()
    refillVehicleFuel(data.liter)
    cb('ok')
end)

-- ====================|| EVENTS || ==================== --

AddEventHandler('onResourceStop', function (res)
    if GetCurrentResourceName() ~= res then return end
    removeObjects()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(pData)
    QBCore.PlayerData = pData
end)

-- ====================|| INITIALIZATION || ==================== --

init()

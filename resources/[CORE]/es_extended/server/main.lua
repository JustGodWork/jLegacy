SetMapName("San Andreas")
SetGameType("ESX Legacy")

local oneSyncState = GetConvar("onesync", "off")
local newPlayer = "INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `group` = ?"
local loadPlayer = "SELECT `accounts`, `job`, `job2`, `job_grade`, `job2_grade`, `group`, `position`, `inventory`, `skin`, `loadout`, `metadata`"

if Config.Multichar then
    newPlayer = newPlayer .. ", `firstname` = ?, `lastname` = ?, `dateofbirth` = ?, `sex` = ?, `height` = ?"
end

if Config.StartingInventoryItems then
    newPlayer = newPlayer .. ", `inventory` = ?"
end

if Config.Multichar or Config.Identity then
    loadPlayer = loadPlayer .. ", `firstname`, `lastname`, `dateofbirth`, `sex`, `height`"
end

loadPlayer = loadPlayer .. " FROM `users` WHERE identifier = ?"

if Config.Multichar then
    AddEventHandler("esx:onPlayerJoined", function(src, char, data)
        while not next(ESX.Jobs) do
            Wait(50)
        end

        if not ESX.Players[src] then
            local identifier = char .. ":" .. ESX.GetIdentifier(src)
            if data then
                createESXPlayer(identifier, src, data)
            else
                loadESXPlayer(identifier, src, false)
            end
        end
    end)
else
    RegisterNetEvent("esx:onPlayerJoined")
    AddEventHandler("esx:onPlayerJoined", function()
        local _source = source
        while not next(ESX.Jobs) do
            Wait(50)
        end

        if not ESX.Players[_source] then
            onPlayerJoined(_source)
        end
    end)
end

function onPlayerJoined(playerId)
    local identifier = ESX.GetIdentifier(playerId)
    if identifier then
        if ESX.GetPlayerFromIdentifier(identifier) then
            DropPlayer(
                playerId,
                ("there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s"):format(
                    identifier
                )
            )
        else
            local result = MySQL.scalar.await("SELECT 1 FROM users WHERE identifier = ?", { identifier })
            if result then
                loadESXPlayer(identifier, playerId, false)
            else
                createESXPlayer(identifier, playerId)
            end
        end
    else
        DropPlayer(playerId, "there was an error loading your character!\nError code: identifier-missing-ingame\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.")
    end
end

function createESXPlayer(identifier, playerId, data)
    local accounts = {}

    for account, money in pairs(Config.StartingAccountMoney) do
        accounts[account] = money
    end

    local defaultGroup = "user"
    if Core.IsPlayerAdmin(playerId) then
        print(("[^2INFO^0] Player ^5%s^0 Has been granted admin permissions via ^5Ace Perms^7."):format(playerId))
        defaultGroup = "admin"
    end

    local parameters = Config.Multichar and { json.encode(accounts), identifier, defaultGroup, data.firstname, data.lastname, data.dateofbirth, data.sex, data.height } or { json.encode(accounts), identifier, defaultGroup }

    if Config.StartingInventoryItems then
        table.insert(parameters, json.encode(Config.StartingInventoryItems))
    end

    MySQL.prepare(newPlayer, parameters, function()
        loadESXPlayer(identifier, playerId, true)
    end)
end

if not Config.Multichar then
    AddEventHandler("playerConnecting", function(_, _, deferrals)
        deferrals.defer()
        local playerId = source
        local identifier = ESX.GetIdentifier(playerId)

        if oneSyncState == "off" or oneSyncState == "legacy" then
            return deferrals.done(("[ESX] ESX Requires Onesync Infinity to work. This server currently has Onesync set to: %s"):format(oneSyncState))
        end

        if not Core.DatabaseConnected then
            return deferrals.done("[ESX] OxMySQL Was Unable To Connect to your database. Please make sure it is turned on and correctly configured in your server.cfg")
        end

        if identifier then
            if ESX.GetPlayerFromIdentifier(identifier) then
                return deferrals.done(
                    ("[ESX] There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same account.\n\nYour identifier: %s"):format(identifier)
                )
            else
                return deferrals.done()
            end
        else
            return deferrals.done("[ESX] There was an error loading your character!\nError code: identifier-missing\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.")
        end
    end)
end

--@param jobType string
---@param job string
---@param grade string | number
---@return table
local function LoadJob(jobType, job, grade)

	local isMain = jobType == "job";
	local default = jobType == "job" and "unemployed" or "unemployed2";
	local data = {};

	local obj, obj_grade = nil, nil;

	if ESX.DoesJobExist(job, grade) then
		obj, obj_grade = ESX.Jobs[job], ESX.Jobs[job].grades[grade];
	else

		console.warn(('Ignoring invalid %s for ^5%s^7 [job: ^5%s^7, grade: ^5%s^7]'):format(isMain and "job" or "job2", identifier, job, grade))
		job, grade = default, '0';
		obj, obj_grade = ESX.Jobs[job], ESX.Jobs[job].grades[grade];

	end

	data.id = obj.id;
	data.name = obj.name;
	data.label = obj.label;

	data.grade = tonumber(grade);
	data.grade_name = obj_grade.name;
	data.grade_label = obj_grade.label;
	data.grade_salary = obj_grade.salary;

	data.skin_male = {};
	data.skin_female = {};

	if (obj_grade.skin_male) then
		data.skin_male = json.decode(obj_grade.skin_male);
	end
	if (obj_grade.skin_female) then
		data.skin_female = json.decode(obj_grade.skin_female);
	end

	return data;

end

function loadESXPlayer(identifier, playerId, isNew)
    local userData = {
        accounts = {},
        inventory = {},
        loadout = {},
        weight = 0,
        identifier = identifier,
        firstName = "John",
        lastName = "Doe",
        dateofbirth = "01/01/2000",
        height = 120,
        dead = false,
    }

    local result = MySQL.prepare.await(loadPlayer, { identifier })
    local job, job_grade = result.job, tostring(result.job_grade);
	local job2, job2_grade = result.job2, tostring(result.job2_grade);

    -- Accounts
    local accounts = result.accounts
    accounts = (accounts and accounts ~= "") and json.decode(accounts) or {}

    for account, data in pairs(Config.Accounts) do
        data.round = data.round or data.round == nil

        local index = #userData.accounts + 1
        userData.accounts[index] = {
            name = account,
            money = accounts[account] or Config.StartingAccountMoney[account] or 0,
            label = data.label,
            round = data.round,
            index = index,
        }
    end

    -- Jobs
	userData.job = LoadJob("job", job, job_grade);
	userData.job2 = LoadJob("job2", job2, job2_grade);

    -- Inventory
    if not Config.OxInventory and not Config.QSInventory then
        local inventory = (result.inventory and result.inventory ~= "") and json.decode(result.inventory) or {}

        for name, item in pairs(ESX.Items) do
            local count = inventory[name] or 0
            userData.weight += (count * item.weight)

            userData.inventory[#userData.inventory + 1] = {
                name = name,
                count = count,
                label = item.label,
                weight = item.weight,
                usable = Core.UsableItemsCallbacks[name] ~= nil,
                rare = item.rare,
                canRemove = item.canRemove,
            }
        end
        table.sort(userData.inventory, function(a, b)
            return a.label < b.label
        end)
    elseif result.inventory and result.inventory ~= "" then
        userData.inventory = json.decode(result.inventory)
    end

    -- Group
    if result.group then
        if result.group == "superadmin" then
            userData.group = "admin"
            print("[^3WARNING^7] ^5Superadmin^7 detected, setting group to ^5admin^7")
        else
            userData.group = result.group
        end
    else
        userData.group = "user"
    end

    -- Loadout
    if not Config.OxInventory and not Config.QSInventory then
        if result.loadout and result.loadout ~= "" then
            local loadout = json.decode(result.loadout)

            for name, weapon in pairs(loadout) do
                local label = ESX.GetWeaponLabel(name)

                if label then
                    userData.loadout[#userData.loadout + 1] = {
                        name = name,
                        ammo = weapon.ammo,
                        label = label,
                        components = weapon.components or {},
                        tintIndex = weapon.tintIndex or 0,
                    }
                end
            end
        end
    end

    -- Position
    userData.coords = json.decode(result.position) or Config.DefaultSpawns[math.random(#Config.DefaultSpawns)]

    -- Skin
    userData.skin = (result.skin and result.skin ~= "") and json.decode(result.skin) or { sex = userData.sex == "f" and 1 or 0 }

    -- Metadata
    userData.metadata = (result.metadata and result.metadata ~= "") and json.decode(result.metadata) or {}

    -- xPlayer Creation
    local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.group, userData.accounts, userData.inventory, userData.weight, userData.job, userData.job2, userData.loadout, GetPlayerName(playerId), userData.coords, userData.metadata)
    ESX.Players[playerId] = xPlayer
    Core.playersByIdentifier[identifier] = xPlayer

    -- Identity
    if result.firstname and result.firstname ~= "" then
        userData.firstName = result.firstname
        userData.lastName = result.lastname

        xPlayer.set("firstName", result.firstname)
        xPlayer.set("lastName", result.lastname)
        xPlayer.setName(("%s %s"):format(result.firstname, result.lastname))

        if result.dateofbirth then
            userData.dateofbirth = result.dateofbirth
            xPlayer.set("dateofbirth", result.dateofbirth)
        end
        if result.sex then
            userData.sex = result.sex
            xPlayer.set("sex", result.sex)
        end
        if result.height then
            userData.height = result.height
            xPlayer.set("height", result.height)
        end
    end

    TriggerEvent("esx:playerLoaded", playerId, xPlayer, isNew)
    userData.money = xPlayer.getMoney()
    userData.maxWeight = xPlayer.getMaxWeight()
    xPlayer.triggerEvent("esx:playerLoaded", userData, isNew, userData.skin)

    if Config.OxInventory then
        exports.ox_inventory:setPlayerInventory(xPlayer, userData.inventory)
        if isNew then
            local shared = json.decode(GetConvar("inventory:accounts", '["money"]'))

            for i = 1, #shared do
                local name = shared[i]
                local account = Config.StartingAccountMoney[name]
                if account then
                    exports.ox_inventory:AddItem(playerId, name, account)
                end
            end
        end
    else
        xPlayer.triggerEvent("esx:createMissingPickups", Core.Pickups)
    end
    xPlayer.triggerEvent("esx:registerSuggestions", Core.RegisteredCommands)
    print(('[^2INFO^0] Player ^5"%s"^0 has connected to the server. ID: ^5%s^7'):format(xPlayer.getName(), playerId))
end

AddEventHandler("chatMessage", function(playerId, _, message)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if message:sub(1, 1) == "/" and playerId > 0 then
        CancelEvent()
        local commandName = message:sub(1):gmatch("%w+")()
        xPlayer.showNotification(TranslateCap("commanderror_invalidcommand", commandName))
    end
end)

AddEventHandler("playerDropped", function(reason)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if xPlayer then
        TriggerEvent("esx:playerDropped", playerId, reason)
        local job = xPlayer.getJob().name
        local job2 = xPlayer.getJob2().name
        local currentJob = ESX.JobsPlayerCount[job]
        local currentJob2 = ESX.JobsPlayerCount[job2]
        ESX.JobsPlayerCount[job] = ((currentJob and currentJob > 0) and currentJob or 1) - 1
        ESX.JobsPlayerCount[job2] = ((currentJob2 and currentJob2 > 0) and currentJob2 or 1) - 1
        GlobalState[("%s:count"):format(job)] = ESX.JobsPlayerCount[job]
        GlobalState[("%s:count"):format(job2)] = ESX.JobsPlayerCount[job2]
        Core.playersByIdentifier[xPlayer.identifier] = nil
        Core.SavePlayer(xPlayer, function()
            ESX.Players[playerId] = nil
        end)
    end
end)

AddEventHandler("esx:playerLoaded", function(_, xPlayer)
    local job = xPlayer.getJob().name
    local job2 = xPlayer.getJob2().name
    local jobKey = ("%s:count"):format(job)
    local job2Key = ("%s:count"):format(job2)

    ESX.JobsPlayerCount[job] = (ESX.JobsPlayerCount[job] or 0) + 1
    ESX.JobsPlayerCount[job2] = (ESX.JobsPlayerCount[job2] or 0) + 1
    GlobalState[jobKey] = ESX.JobsPlayerCount[job]
    GlobalState[job2Key] = ESX.JobsPlayerCount[job2]
end)

---@param lastJob table
---@param job table
local function updatePlayersInJob(lastJob, job)
    local lastJobKey = ("%s:count"):format(lastJob.name)
    local jobKey = ("%s:count"):format(job.name)
    local currentLastJob = ESX.JobsPlayerCount[lastJob.name]

    ESX.JobsPlayerCount[lastJob.name] = ((currentLastJob and currentLastJob > 0) and currentLastJob or 1) - 1
    ESX.JobsPlayerCount[job.name] = (ESX.JobsPlayerCount[job.name] or 0) + 1

    GlobalState[lastJobKey] = ESX.JobsPlayerCount[lastJob.name]
    GlobalState[jobKey] = ESX.JobsPlayerCount[job.name]
end

AddEventHandler("esx:setJob", function(_, job, lastJob)
    updatePlayersInJob(lastJob, job);
end)

AddEventHandler("esx:setJob2", function(_, job, lastJob)
    updatePlayersInJob(lastJob, job);
end)

AddEventHandler("esx:playerLogout", function(playerId, cb)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        TriggerEvent("esx:playerDropped", playerId)

        Core.playersByIdentifier[xPlayer.identifier] = nil
        Core.SavePlayer(xPlayer, function()
            ESX.Players[playerId] = nil
            if cb then
                cb()
            end
        end)
    end
    TriggerClientEvent("esx:onPlayerLogout", playerId)
end)

if not Config.OxInventory and not Config.QSInventory then
    RegisterNetEvent("esx:updateWeaponAmmo")
    AddEventHandler("esx:updateWeaponAmmo", function(weaponName, ammoCount)
        local xPlayer = ESX.GetPlayerFromId(source)

        if xPlayer then
            xPlayer.updateWeaponAmmo(weaponName, ammoCount)
        end
    end)

    RegisterNetEvent("esx:giveInventoryItem")
    AddEventHandler("esx:giveInventoryItem", function(target, itemType, itemName, itemCount)
        local playerId = source
        local sourceXPlayer = ESX.GetPlayerFromId(playerId)
        local targetXPlayer = ESX.GetPlayerFromId(target)
        local distance = #(GetEntityCoords(GetPlayerPed(playerId)) - GetEntityCoords(GetPlayerPed(target)))
        if not sourceXPlayer or not targetXPlayer or distance > Config.DistanceGive then
            print(("[^3WARNING^7] Player Detected Cheating: ^5%s^7"):format(GetPlayerName(playerId)))
            return
        end

        if itemType == "item_standard" then
            local sourceItem = sourceXPlayer.getInventoryItem(itemName)

            if itemCount > 0 and sourceItem.count >= itemCount then
                if targetXPlayer.canCarryItem(itemName, itemCount) then
                    sourceXPlayer.removeInventoryItem(itemName, itemCount)
                    targetXPlayer.addInventoryItem(itemName, itemCount)

                    sourceXPlayer.showNotification(TranslateCap("gave_item", itemCount, sourceItem.label, targetXPlayer.name))
                    targetXPlayer.showNotification(TranslateCap("received_item", itemCount, sourceItem.label, sourceXPlayer.name))
                else
                    sourceXPlayer.showNotification(TranslateCap("ex_inv_lim", targetXPlayer.name))
                end
            else
                sourceXPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
            end
        elseif itemType == "item_account" then
            if itemCount > 0 and sourceXPlayer.getAccount(itemName).money >= itemCount then
                sourceXPlayer.removeAccountMoney(itemName, itemCount, "Gave to " .. targetXPlayer.name)
                targetXPlayer.addAccountMoney(itemName, itemCount, "Received from " .. sourceXPlayer.name)

                sourceXPlayer.showNotification(TranslateCap("gave_account_money", ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName].label, targetXPlayer.name))
                targetXPlayer.showNotification(TranslateCap("received_account_money", ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName].label, sourceXPlayer.name))
            else
                sourceXPlayer.showNotification(TranslateCap("imp_invalid_amount"))
            end
        elseif itemType == "item_weapon" then
            if sourceXPlayer.hasWeapon(itemName) then
                local weaponLabel = ESX.GetWeaponLabel(itemName)
                if not targetXPlayer.hasWeapon(itemName) then
                    local _, weapon = sourceXPlayer.getWeapon(itemName)
                    local _, weaponObject = ESX.GetWeapon(itemName)
                    itemCount = weapon.ammo
                    local weaponComponents = ESX.Table.Clone(weapon.components)
                    local weaponTint = weapon.tintIndex
                    if weaponTint then
                        targetXPlayer.setWeaponTint(itemName, weaponTint)
                    end
                    if weaponComponents then
                        for _, v in pairs(weaponComponents) do
                            targetXPlayer.addWeaponComponent(itemName, v)
                        end
                    end
                    sourceXPlayer.removeWeapon(itemName)
                    targetXPlayer.addWeapon(itemName, itemCount)

                    if weaponObject.ammo and itemCount > 0 then
                        local ammoLabel = weaponObject.ammo.label
                        sourceXPlayer.showNotification(TranslateCap("gave_weapon_withammo", weaponLabel, itemCount, ammoLabel, targetXPlayer.name))
                        targetXPlayer.showNotification(TranslateCap("received_weapon_withammo", weaponLabel, itemCount, ammoLabel, sourceXPlayer.name))
                    else
                        sourceXPlayer.showNotification(TranslateCap("gave_weapon", weaponLabel, targetXPlayer.name))
                        targetXPlayer.showNotification(TranslateCap("received_weapon", weaponLabel, sourceXPlayer.name))
                    end
                else
                    sourceXPlayer.showNotification(TranslateCap("gave_weapon_hasalready", targetXPlayer.name, weaponLabel))
                    targetXPlayer.showNotification(TranslateCap("received_weapon_hasalready", sourceXPlayer.name, weaponLabel))
                end
            end
        elseif itemType == "item_ammo" then
            if sourceXPlayer.hasWeapon(itemName) then
                local _, weapon = sourceXPlayer.getWeapon(itemName)

                if targetXPlayer.hasWeapon(itemName) then
                    local _, weaponObject = ESX.GetWeapon(itemName)

                    if weaponObject.ammo then
                        local ammoLabel = weaponObject.ammo.label

                        if weapon.ammo >= itemCount then
                            sourceXPlayer.removeWeaponAmmo(itemName, itemCount)
                            targetXPlayer.addWeaponAmmo(itemName, itemCount)

                            sourceXPlayer.showNotification(TranslateCap("gave_weapon_ammo", itemCount, ammoLabel, weapon.label, targetXPlayer.name))
                            targetXPlayer.showNotification(TranslateCap("received_weapon_ammo", itemCount, ammoLabel, weapon.label, sourceXPlayer.name))
                        end
                    end
                else
                    sourceXPlayer.showNotification(TranslateCap("gave_weapon_noweapon", targetXPlayer.name))
                    targetXPlayer.showNotification(TranslateCap("received_weapon_noweapon", sourceXPlayer.name, weapon.label))
                end
            end
        end
    end)

    RegisterNetEvent("esx:removeInventoryItem")
    AddEventHandler("esx:removeInventoryItem", function(itemType, itemName, itemCount)
        local playerId = source
        local xPlayer = ESX.GetPlayerFromId(playerId)

        if itemType == "item_standard" then
            if itemCount == nil or itemCount < 1 then
                xPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
            else
                local xItem = xPlayer.getInventoryItem(itemName)

                if itemCount > xItem.count or xItem.count < 1 then
                    xPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
                else
                    xPlayer.removeInventoryItem(itemName, itemCount)
                    local pickupLabel = ("%s [%s]"):format(xItem.label, itemCount)
                    ESX.CreatePickup("item_standard", itemName, itemCount, pickupLabel, playerId)
                    xPlayer.showNotification(TranslateCap("threw_standard", itemCount, xItem.label))
                end
            end
        elseif itemType == "item_account" then
            if itemCount == nil or itemCount < 1 then
                xPlayer.showNotification(TranslateCap("imp_invalid_amount"))
            else
                local account = xPlayer.getAccount(itemName)

                if itemCount > account.money or account.money < 1 then
                    xPlayer.showNotification(TranslateCap("imp_invalid_amount"))
                else
                    xPlayer.removeAccountMoney(itemName, itemCount, "Threw away")
                    local pickupLabel = ("%s [%s]"):format(account.label, TranslateCap("locale_currency", ESX.Math.GroupDigits(itemCount)))
                    ESX.CreatePickup("item_account", itemName, itemCount, pickupLabel, playerId)
                    xPlayer.showNotification(TranslateCap("threw_account", ESX.Math.GroupDigits(itemCount), string.lower(account.label)))
                end
            end
        elseif itemType == "item_weapon" then
            itemName = string.upper(itemName)

            if xPlayer.hasWeapon(itemName) then
                local _, weapon = xPlayer.getWeapon(itemName)
                local _, weaponObject = ESX.GetWeapon(itemName)
                local components, pickupLabel = ESX.Table.Clone(weapon.components)
                xPlayer.removeWeapon(itemName)

                if weaponObject.ammo and weapon.ammo > 0 then
                    local ammoLabel = weaponObject.ammo.label
                    pickupLabel = ("%s [%s %s]"):format(weapon.label, weapon.ammo, ammoLabel)
                    xPlayer.showNotification(TranslateCap("threw_weapon_ammo", weapon.label, weapon.ammo, ammoLabel))
                else
                    pickupLabel = ("%s"):format(weapon.label)
                    xPlayer.showNotification(TranslateCap("threw_weapon", weapon.label))
                end

                ESX.CreatePickup("item_weapon", itemName, weapon.ammo, pickupLabel, playerId, components, weapon.tintIndex)
            end
        end
    end)

    RegisterNetEvent("esx:useItem")
    AddEventHandler("esx:useItem", function(itemName)
        local source = source
        local xPlayer = ESX.GetPlayerFromId(source)
        local count = xPlayer.getInventoryItem(itemName).count

        if count > 0 then
            ESX.UseItem(source, itemName)
        else
            xPlayer.showNotification(TranslateCap("act_imp"))
        end
    end)

    RegisterNetEvent("esx:onPickup")
    AddEventHandler("esx:onPickup", function(pickupId)
        local pickup, xPlayer, success = Core.Pickups[pickupId], ESX.GetPlayerFromId(source)

        if pickup then
            local playerPickupDistance = #(pickup.coords - xPlayer.getCoords(true))
            if playerPickupDistance > 5.0 then
                print(("[^3WARNING^7] Player Detected Cheating (Out of range pickup): ^5%s^7"):format(xPlayer.getIdentifier()))
                return
            end

            if pickup.type == "item_standard" then
                if xPlayer.canCarryItem(pickup.name, pickup.count) then
                    xPlayer.addInventoryItem(pickup.name, pickup.count)
                    success = true
                else
                    xPlayer.showNotification(TranslateCap("threw_cannot_pickup"))
                end
            elseif pickup.type == "item_account" then
                success = true
                xPlayer.addAccountMoney(pickup.name, pickup.count, "Picked up")
            elseif pickup.type == "item_weapon" then
                if xPlayer.hasWeapon(pickup.name) then
                    xPlayer.showNotification(TranslateCap("threw_weapon_already"))
                else
                    success = true
                    xPlayer.addWeapon(pickup.name, pickup.count)
                    xPlayer.setWeaponTint(pickup.name, pickup.tintIndex)

                    for _, v in ipairs(pickup.components) do
                        xPlayer.addWeaponComponent(pickup.name, v)
                    end
                end
            end

            if success then
                Core.Pickups[pickupId] = nil
                TriggerClientEvent("esx:removePickup", -1, pickupId)
            end
        end
    end)
end

ESX.RegisterServerCallback("esx:getPlayerData", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    cb({
        identifier = xPlayer.identifier,
        accounts = xPlayer.getAccounts(),
        inventory = xPlayer.getInventory(),
        job = xPlayer.getJob(),
        loadout = xPlayer.getLoadout(),
        money = xPlayer.getMoney(),
        position = xPlayer.getCoords(true),
        metadata = xPlayer.getMeta(),
    })
end)

ESX.RegisterServerCallback("esx:isUserAdmin", function(source, cb)
    cb(Core.IsPlayerAdmin(source))
end)

ESX.RegisterServerCallback("esx:getGameBuild", function(_, cb)
    cb(tonumber(GetConvar("sv_enforceGameBuild", 1604)))
end)

ESX.RegisterServerCallback("esx:getOtherPlayerData", function(_, cb, target)
    local xPlayer = ESX.GetPlayerFromId(target)

    cb({
        identifier = xPlayer.identifier,
        accounts = xPlayer.getAccounts(),
        inventory = xPlayer.getInventory(),
        job = xPlayer.getJob(),
        job2 = xPlayer.getJob2(),
        loadout = xPlayer.getLoadout(),
        money = xPlayer.getMoney(),
        position = xPlayer.getCoords(true),
        metadata = xPlayer.getMeta(),
    })
end)

ESX.RegisterServerCallback("esx:getPlayerNames", function(source, cb, players)
    players[source] = nil

    for playerId, _ in pairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)

        if xPlayer then
            players[playerId] = xPlayer.getName()
        else
            players[playerId] = nil
        end
    end

    cb(players)
end)

ESX.RegisterServerCallback("esx:spawnVehicle", function(source, cb, vehData)
    local ped = GetPlayerPed(source)
    ESX.OneSync.SpawnVehicle(vehData.model or `ADDER`, vehData.coords or GetEntityCoords(ped), vehData.coords.w or 0.0, vehData.props or {}, function(id)
        if vehData.warp then
            local vehicle = NetworkGetEntityFromNetworkId(id)
            local timeout = 0
            while GetVehiclePedIsIn(ped) ~= vehicle and timeout <= 15 do
                Wait(0)
                TaskWarpPedIntoVehicle(ped, vehicle, -1)
                timeout += 1
            end
        end
        cb(id)
    end)
end)

AddEventHandler("txAdmin:events:scheduledRestart", function(eventData)
    if eventData.secondsRemaining == 60 then
        CreateThread(function()
            Wait(50000)
            Core.SavePlayers()
        end)
    end
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
    Core.SavePlayers()
end)

local DoNotUse = {
    ["essentialmode"] = true,
    ["es_admin2"] = true,
    ["basic-gamemode"] = true,
    ["mapmanager"] = true,
    ["fivem-map-skater"] = true,
    ["fivem-map-hipster"] = true,
    ["qb-core"] = true,
    ["default_spawnpoint"] = true,
}

AddEventHandler("onResourceStart", function(key)
    if DoNotUse[string.lower(key)] then
        while GetResourceState(key) ~= "started" do
            Wait(0)
        end

        StopResource(key)
        print(("[^1ERROR^7] WE STOPPED A RESOURCE THAT WILL BREAK ^1ESX^7, PLEASE REMOVE ^5%s^7"):format(key))
    end
end)

for key in pairs(DoNotUse) do
    if GetResourceState(key) == "started" or GetResourceState(key) == "starting" then
        StopResource(key)
        print(("[^1ERROR^7] WE STOPPED A RESOURCE THAT WILL BREAK ^1ESX^7, PLEASE REMOVE ^5%s^7"):format(key))
    end
end

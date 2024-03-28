ESX = {}
ESX.Players = {}
ESX.Jobs = {}
ESX.Items = {}
Core = {}
Core.UsableItemsCallbacks = {}
Core.RegisteredCommands = {}
Core.Pickups = {}
Core.PickupId = 0
Core.PlayerFunctionOverrides = {}
Core.DatabaseConnected = false
Core.playersByIdentifier = {}

Core.vehicleTypesByModel = {}

AddEventHandler("esx:getSharedObject", function(cb)
	local use_deprecated = Config.EnableDeprecated;
	local invoke = GetInvokingResource();

	if (use_deprecated) then
		cb(ESX);
		return;
	end
	console.err(("Resource ^5%s^7 Used the ^5getSharedObject^7 Event,"):format(invoke));
	console.err("this event ^1no longer exists!^7");
	console.err("Visit https://documentation.esx-framework.org/tutorials/tutorials-esx/sharedevent for how to fix!");
end)

exports('getSharedObject', function()
  	return ESX
end)

if GetResourceState('ox_inventory') ~= 'missing' then
	Config.OxInventory = true
	Config.PlayerFunctionOverride = 'OxInventory'
	SetConvarReplicated('inventory:framework', 'esx')
	SetConvarReplicated('inventory:weight', Config.MaxWeight * 1000)
end

if (GetResourceState('qs-inventory') ~= 'missing') then
	Config.QSInventory = true;
	Config.PlayerFunctionOverride = 'QSInventory';
end

local function StartDBSync()
	CreateThread(function()
		while true do
		Wait(10 * 60 * 1000)
		Core.SavePlayers()
		end
	end)
end

MySQL.ready(function()
  	Core.DatabaseConnected = true;
	if (Config.QSInventory) then
		ESX.Items = exports['qs-inventory']:GetItemList();
	elseif (Config.OxInventory) then
		TriggerEvent('__cfx_export_ox_inventory_Items', function(ref)
			if ref then
				ESX.Items = ref()
			end
		end)

		AddEventHandler('ox_inventory:itemList', function(items)
			ESX.Items = items
		end)

		while not next(ESX.Items) do
			Wait(0);
		end
	else
		local items = MySQL.query.await('SELECT * FROM items')
		for k, v in ipairs(items) do
		ESX.Items[v.name] = {label = v.label, weight = v.weight, rare = v.rare, canRemove = v.can_remove}
		end
	end

	ESX.RefreshJobs();

	console.log(('^5jLegacy ^7(^6%s^7)^0 initialized!'):format(GetResourceMetadata(GetCurrentResourceName(), "version", 0)))

	StartDBSync()
  	if Config.EnablePaycheck then
		StartPayCheck()
	end
end)

RegisterServerEvent('esx:clientLog')
AddEventHandler('esx:clientLog', function(msg)
	if Config.EnableDebug then
		console.warn(('%s^7'):format(msg))
	end
end)

RegisterNetEvent("esx:ReturnVehicleType", function(Type, Request)
	if Core.ClientCallbacks[Request] then
		Core.ClientCallbacks[Request](Type)
		Core.ClientCallbacks[Request] = nil
	end
end)

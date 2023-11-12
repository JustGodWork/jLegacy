exports('getSharedObject', function()
	return ESX
end)

if GetResourceState('ox_inventory') ~= 'missing' then
	Config.OxInventory = true
end

if GetResourceState('qs-inventory') ~= 'missing' then
	Config.QSInventory = true
end

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
end);

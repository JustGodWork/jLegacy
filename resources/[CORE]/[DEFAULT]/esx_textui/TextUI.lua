Debug = ESX.GetConfig().EnableDebug
local isShowing = false
---@param message string
---@param typ string
local function TextUI(message, typ)
    isShowing = true
    SendNUIMessage({
        action = 'show',
        message = message and message or 'ESX-TextUI',
        type = type(typ) == "string" and typ or 'info'
    })
end

local function HideUI()
   if not isShowing then return end
   isShowing = false
    SendNUIMessage({
        action = 'hide'
    })
end

exports('TextUI', TextUI)
exports('HideUI', HideUI)
RegisterNetEvent('ESX:TextUI', TextUI)
RegisterNetEvent('ESX:HideUI', HideUI)

if Debug then
    RegisterCommand("textuierror", function()
        ESX.TextUI("i ~r~love~s~ donuts", "error")
    end)

    RegisterCommand("textuisuccess", function()
        ESX.TextUI("i ~g~love~s~ donuts", "success")
    end)

    RegisterCommand("textuiinfo", function()
        ESX.TextUI("i ~b~love~s~ donuts", "info")
    end)

    RegisterCommand("textuihide", function()
        ESX.HideUI()
    end)
end

local RequestId = 0
local serverRequests = {}

local clientCallbacks = {}

---@param eventName string
---@param callback function
---@param ... any
ESX.TriggerServerCallback = function(eventName, callback, ...)
  serverRequests[RequestId] = callback
  
  TriggerServerEvent('esx:triggerServerCallback', eventName, RequestId, GetInvokingResource() or "unknown", ...)

  RequestId = RequestId + 1
end

RegisterNetEvent('esx:serverCallback', function(requestId, invoker, ...)
  if not serverRequests[requestId] then
    return console.err(('Server Callback with requestId ^5%s^7 Was Called by ^5%s^7 but does not exist.'):format(requestId, invoker))
  end

  serverRequests[requestId](...)
  serverRequests[requestId] = nil
end)

---@param eventName string
---@param callback function
ESX.RegisterClientCallback = function(eventName, callback)
  clientCallbacks[eventName] = callback
end

RegisterNetEvent('esx:triggerClientCallback', function(eventName, requestId, invoker, ...)
  if not clientCallbacks[eventName] then
    return console.err(('Client Callback not registered, name: ^5%s^7, invoker resource: ^5%s^7'):format(eventName, invoker))
  end

  clientCallbacks[eventName](function(...)
    TriggerServerEvent('esx:clientCallback', requestId, invoker, ...)
  end, ...)
end)
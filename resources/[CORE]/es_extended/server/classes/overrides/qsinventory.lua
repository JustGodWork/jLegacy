Core.PlayerFunctionOverrides.QSInventory = {
  getInventory = function(self)
    return function(minimal)
      local inventory = exports['qs-inventory']:GetInventory(self.source)
      if not inventory then return {} end
      for k,v in pairs(inventory) do
        v.count = v.amount
      end
      return inventory
    end
  end,

  getLoadout = function(self)
    return function()
      return {}
    end
  end,

  getInventoryItem = function(self)
    return function(name,metadata)
      local item = exports['qs-inventory']:GetItemByName(self.source, name)
			if not item then 
        return {
          count = 0,
        } 
      end
			item.count = item.amount
			return item
    end
  end,

  getAccount = function(self)
    return function(account)
      for i=1, #self.accounts do
        if self.accounts[i].name == account then
          local accounts = exports['qs-inventory']:GetAccounts()
          if accounts[account] then
            self.accounts[i].money = exports['qs-inventory']:GetItemTotalAmount(self.source, account)
          end
          return self.accounts[i]
        end
      end
    end
  end,

  setAccountMoney = function(self)
    return function(accountName,money, reason)
      reason = reason or 'unknown'
      if money >= 0 then
        local account = self.getAccount(accountName)

        if account then
          money = account.round and ESX.Math.Round(money) or money
          self.accounts[account.index].money = money

          self.triggerEvent('esx:setAccountMoney', account)
          TriggerEvent('esx:setAccountMoney', self.source, accountName, money, reason)
          local accounts = exports['qs-inventory']:GetAccounts()
          if accounts[accountName] and reason ~= 'dropped' then
            exports['qs-inventory']:SetInventoryItems(self.source, accountName, money)
          end
        end
      end
    end
  end,

  addAccountMoney = function(self)
    return function(accountName,money, reason)
      reason = reason or 'unknown'
      if money > 0 then
        local account = self.getAccount(accountName)

        if account then
				money = account.round and ESX.Math.Round(money) or money
				self.accounts[account.index].money += money
        self.triggerEvent('esx:setAccountMoney', account)
        TriggerEvent('esx:addAccountMoney', self.source, accountName, money, reason)
          local accounts = exports['qs-inventory']:GetAccounts()
            if accounts[accountName] then
            exports['qs-inventory']:AddItem(self.source, accountName, money)
          end
        end
      end
    end
  end,

  removeAccountMoney = function(self)
    return function(accountName,money, reason)
      reason = reason or 'unknown'
      if money > 0 then
        local account = self.getAccount(accountName)

        if account then
          money = account.round and ESX.Math.Round(money) or money
          self.accounts[account.index].money -= money
          self.triggerEvent('esx:setAccountMoney', account)
          TriggerEvent('esx:removeAccountMoney', self.source, accountName, money, reason)
          local accounts = exports['qs-inventory']:GetAccounts()
          if accounts[accountName] then
            exports['qs-inventory']:RemoveItem(self.source, accountName, money)
          end
        end
      end
    end
  end,

  addInventoryItem = function(self)
    return function(name,count,metadata,slot)
      return exports['qs-inventory']:AddItem(self.source, name, count or 1, slot, metadata)
    end
  end,

  removeInventoryItem = function(self)
    return function(name,count,metadata,slot)
      return exports['qs-inventory']:RemoveItem(self.source, name, count or 1, slot, metadata)
    end
  end,

  setInventoryItem = function(self)
    return function(name,count,metadata)
      return exports['qs-inventory']:SetInventoryItem(self.source, name, count, metadata)
    end
  end,

  canCarryItem = function(self)
    return function(name,count,metadata)
      return exports['qs-inventory']:CanCarryItem(self.source, name, count)
    end
  end,

  canSwapItem = function(self)
    return function(firstItem, firstItemCount, testItem, testItemCount)
      return true
    end
  end,

  setMaxWeight = function(self)
    return function() end
  end,

  addWeapon = function(self)
    return function(weaponName, ammo)
      return exports['qs-inventory']:GiveWeaponToPlayer(self.source, weaponName, ammo)
    end
  end,

  addWeaponComponent = function(self)
    return function() end
  end,

  addWeaponAmmo = function(self)
    return function() end
  end,

  updateWeaponAmmo = function(self)
    return function() end
  end,

  setWeaponTint = function(self)
    return function() end
  end,

  getWeaponTint = function(self)
    return function() end
  end,

  removeWeapon = function(self)
    return function() end
  end,

  removeWeaponComponent = function(self)
    return function() end
  end,

  removeWeaponAmmo = function(self)
    return function() end
  end,

  hasWeaponComponent = function(self)
    return function()
      return false
    end
  end,

  hasWeapon = function(self)
    return function()
      return false
    end
  end,

  hasItem = function(self)
    return function(name,metadata)
      return exports['qs-inventory']:GetItemByName(self.source, name)
    end
  end,

  getWeapon = function(self)
    return function() end
  end
}
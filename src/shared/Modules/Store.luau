-- Robux store rules both server and client use (Addendum 2 step 12a, Config.Monetization).
-- The server (StoreService) publishes the game passes a player owns as the Player attribute Passes (";VIP;PetSlots;");
-- every perk reads it through here, so a perk only works while the store is switched on.
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)

local MONEY = Config.Monetization

local Store = {}

local passes = {}
for _, pass in MONEY.Passes do
	passes[pass.Id] = pass
end
local products = {}
for _, product in MONEY.Products do
	products[product.Id] = product
end

-- True when the store is on: the real switch, or Studio's free preview (never in the live game)
function Store.Active(): boolean
	return MONEY.Enabled == true or (RunService:IsStudio() and MONEY.StudioPreview == true)
end

-- True when buying is free and fake (Studio preview with the real switch off)
function Store.IsPreview(): boolean
	return MONEY.Enabled ~= true and RunService:IsStudio() and MONEY.StudioPreview == true
end

function Store.Pass(id: string)
	return passes[id]
end

function Store.Product(id: string)
	return products[id]
end

-- True when this player owns this game pass (and the store is on)
function Store.Owns(player: Player, passId: string): boolean
	if not Store.Active() then
		return false
	end
	local text = player:GetAttribute("Passes")
	return type(text) == "string" and string.find(text, ";" .. passId .. ";", 1, true) ~= nil
end

-- Coin multiplier from owned passes (2X COINS x2, VIP x1.1, together x2.2)
function Store.CoinMultiplier(player: Player): number
	local multiplier = 1
	for _, pass in MONEY.Passes do
		if pass.Coins and Store.Owns(player, pass.Id) then
			multiplier *= pass.Coins
		end
	end
	return multiplier
end

-- Extra pet slots from owned passes
function Store.PetSlots(player: Player): number
	local extra = 0
	for _, pass in MONEY.Passes do
		if pass.PetSlots and Store.Owns(player, pass.Id) then
			extra += pass.PetSlots
		end
	end
	return extra
end

-- "R$ 399"
function Store.PriceText(robux: number): string
	return "R$ " .. tostring(robux)
end

return Store

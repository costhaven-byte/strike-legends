-- Robux store (Addendum 2 section 7, step 12a): game passes and developer products, all behind
-- Config.Monetization.Enabled (the owner flips it). While it's off this service does nothing in the live game.
-- Passes: checked with Roblox when a player joins and when they buy one; published as the Player attribute Passes
-- (";DoubleCoins;VIP;"), which every perk reads through Shared.Modules.Store.
-- Products: handed out in ProcessReceipt. Each purchase id is saved (Purchases), so a purchase is never given twice,
-- and the save is written straight away before Roblox is told it went through.
-- Starter Pack: offered once (StarterOffered), after StarterAfterMinutes of play in total, at a quiet moment.
-- Ladder products (COIN BOOST / XP BOOST) are bought in order: each step boosts more, up to x2
-- (CoinBoostLevel / XpBoostLevel).
-- Looks (Cosmetic = a Config.Cosmetics Id): bought once, handed to CosmeticService (step 12b).
-- VIP: DailyGems once a day (VipGiftDay), given on join or when the day changes.
-- Studio preview (StudioPreview, switch off): BUY gives the item for free straight away; Studio tests never save.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Modules.Calendar)
local Store = require(Shared.Modules.Store)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local CosmeticService = require(script.Parent.CosmeticService)
local Cosmetics = require(Shared.Modules.Cosmetics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PotionService = require(script.Parent.PotionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local MONEY = Config.Monetization
local OFFER_CHECK = 15 -- seconds between Starter Pack and VIP gift checks

local StoreService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local resultEvent: RemoteEvent? = nil

local passByNumber = {}
for _, pass in MONEY.Passes do
	if pass.PassId > 0 then
		passByNumber[pass.PassId] = pass
	end
end
local productByNumber = {}
for _, product in MONEY.Products do
	if product.ProductId > 0 then
		productByNumber[product.ProductId] = product
	end
end

local function publish(player: Player)
	local parts = {}
	for _, pass in MONEY.Passes do
		if owned[player] and owned[player][pass.Id] then
			table.insert(parts, pass.Id)
		end
	end
	player:SetAttribute("Passes", if #parts > 0 then ";" .. table.concat(parts, ";") .. ";" else "")
end

local function givePass(player: Player, pass)
	owned[player] = owned[player] or {}
	if owned[player][pass.Id] then
		return
	end
	owned[player][pass.Id] = true
	publish(player)
end

-- Asks Roblox which passes this player owns (a failed check counts as not owned until they rejoin)
local function checkPasses(player: Player)
	owned[player] = owned[player] or {}
	for _, pass in MONEY.Passes do
		if pass.PassId > 0 then
			local ok, has =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.PassId)
			if ok and has then
				owned[player][pass.Id] = true
			end
		end
	end
	publish(player)
end

-- Hands out one developer product (the purchase itself was checked by the caller)
local function grantProduct(player: Player, product)
	if product.Gems then
		PlayerDataService.Add(player, "Gems", product.Gems)
		Analytics.Currency(player, "Gems", product.Gems, "IAP", product.Id)
	end
	if product.Boost then
		PotionService.AddBoost(player, product.Boost.Potion, product.Boost.Minutes * 60)
	end
	if product.Ball then
		BallService.GiveBall(player, product.Ball)
	end
	if product.Cosmetic then
		CosmeticService.Give(player, product.Cosmetic) -- a look (Config.Cosmetics), worn straight away
	end
	if product.Ladder then
		-- A ladder step: never lower than what's already bought (a step bought twice just keeps the level)
		local key = Store.LadderKeys[product.Ladder]
		PlayerDataService.Set(player, key, math.max(PlayerDataService.Get(player, key) or 0, product.Step))
	end
	if product.Once then
		PlayerDataService.Set(player, product.Id, 1) -- StarterPack = 1
	end
	Analytics.Purchase(player, "Robux", product.Id)
	SessionLog.Moment(player, ("Robux purchase: %s"):format(product.Id))
	if resultEvent then
		local text = if product.Ladder == "Coins"
			then "COIN BOOST is now " .. Store.MultText(Store.BoostMultiplier(player))
			elseif product.Ladder == "Xp" then "XP BOOST is now " .. Store.MultText(
				Store.XpBoostMultiplier(player)
			)
			else product.Name .. " is yours"
		resultEvent:FireClient(player, { Id = product.Id, Text = text })
	end
end

-- VIP daily gems: once per day (days change at midnight UTC, like the daily reward)
local function vipGift(player: Player)
	local today = Calendar.Day()
	if (PlayerDataService.Get(player, "VipGiftDay") or 0) == today then
		return
	end
	for _, pass in MONEY.Passes do
		if pass.DailyGems and Store.Owns(player, pass.Id) then
			PlayerDataService.Set(player, "VipGiftDay", today)
			PlayerDataService.Add(player, "Gems", pass.DailyGems)
			Analytics.Currency(player, "Gems", pass.DailyGems, "Gameplay", "VipDaily")
			if resultEvent then
				resultEvent:FireClient(
					player,
					{ Id = pass.Id, Title = pass.Name .. " DAILY GIFT", Text = ("+%d gems"):format(pass.DailyGems) }
				)
			end
			return
		end
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local product = productByNumber[info.ProductId]
	if not player or not product or not PlayerDataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox asks again later (next join)
	end
	local done = PlayerDataService.Get(player, "Purchases")
	if type(done) ~= "table" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(done, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end
	grantProduct(player, product)
	table.insert(done, info.PurchaseId)
	while #done > MONEY.KeepPurchaseIds do
		table.remove(done, 1)
	end
	if not PlayerDataService.SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- the id is kept in memory, so no double grant this visit
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- The client's BUY button
local function onBuy(player: Player, id: any)
	if type(id) ~= "string" or not RateLimit.Allow(player, "StoreBuy") or not PlayerDataService.IsLoaded(player) then
		return
	end
	local pass = Store.Pass(id)
	local product = Store.Product(id)
	if not pass and not product then
		return
	end
	if pass and owned[player] and owned[player][pass.Id] then
		return
	end
	if product and product.Once and (PlayerDataService.Get(player, product.Id) or 0) > 0 then
		return
	end
	if product and product.Cosmetic and Cosmetics.Owns(player, product.Cosmetic) then
		return -- a look is bought once
	end
	if product and product.Ladder and Store.NextStep(player, product.Ladder) ~= product then
		return -- ladder steps are bought in order, once each
	end
	if Store.IsPreview() then
		-- Studio preview: free and instant (nothing is real, and Studio tests don't save)
		if pass then
			givePass(player, pass)
			if resultEvent then
				resultEvent:FireClient(player, { Id = pass.Id, Text = pass.Name .. " is yours" })
			end
		else
			grantProduct(player, product)
		end
		return
	end
	local number = if pass then pass.PassId else product.ProductId
	if number <= 0 then
		warn(
			("[StoreService] %s has no %s yet (Config.Monetization)"):format(id, if pass then "PassId" else "ProductId")
		)
		return
	end
	if pass then
		MarketplaceService:PromptGamePassPurchase(player, number)
	else
		MarketplaceService:PromptProductPurchase(player, number)
	end
end

-- Starter Pack popup: once, after enough play, never for someone who bought it
local function checkOffer(player: Player)
	if
		(PlayerDataService.Get(player, "StarterPack") or 0) > 0
		or (PlayerDataService.Get(player, "StarterOffered") or 0) > 0
		or Analytics.MinutesPlayed(player) < MONEY.StarterAfterMinutes
	then
		return
	end
	PlayerDataService.Set(player, "StarterOffered", 1)
	local offer = ReplicatedStorage.Remotes:FindFirstChild("StarterOffer") :: RemoteEvent?
	if offer then
		offer:FireClient(player)
	end
end

function StoreService:Start()
	if not Store.Active() then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buy = Instance.new("RemoteEvent")
	buy.Name = "StoreBuy"
	buy.OnServerEvent:Connect(function(player, id)
		local ok, err = pcall(onBuy, player, id)
		if not ok then
			warn("[StoreService] " .. tostring(err))
		end
	end)
	buy.Parent = remotes
	local result = Instance.new("RemoteEvent")
	result.Name = "StoreResult"
	result.Parent = remotes
	resultEvent = result
	local offer = Instance.new("RemoteEvent")
	offer.Name = "StarterOffer"
	offer.Parent = remotes

	if not Store.IsPreview() then
		MarketplaceService.ProcessReceipt = processReceipt
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passNumber, purchased)
			local pass = passByNumber[passNumber]
			if purchased and pass then
				givePass(player, pass)
				Analytics.Purchase(player, "Robux", pass.Id)
				SessionLog.Moment(player, ("Robux purchase: %s"):format(pass.Id))
				result:FireClient(player, { Id = pass.Id, Text = pass.Name .. " is yours" })
			end
		end)
	elseif RunService:IsStudio() then
		warn("[StoreService] Studio store preview: BUY is free and instant, nothing is real (Config.Monetization)")
	end

	PlayerDataService.OnLoaded(function(player)
		publish(player)
		task.spawn(checkPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(OFFER_CHECK)
			for _, player in Players:GetPlayers() do
				if PlayerDataService.IsLoaded(player) then
					pcall(vipGift, player)
					local ok, err = pcall(checkOffer, player)
					if not ok then
						warn("[StoreService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return StoreService

-- Global and weekly leaderboards, stored in OrderedDataStores.
-- Writes each player's scores every Config.Leaderboards.WriteInterval and when they leave (never per throw),
-- and reads the top scores every RefreshInterval. Results go to ReplicatedStorage.Leaderboards as attributes
-- (one JSON string per board) so every client can draw the boards and work out its own position.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Modules.Calendar)
local Currency = require(Shared.Modules.Currency)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LB = Config.Leaderboards

local LeaderboardService = {}

local folder: Folder
local enabled = true -- switched off if DataStores aren't available (unpublished place in Studio)
local lastWritten: { [Player]: { [string]: number } } = {} -- store name -> value last saved
local names: { [number]: string } = {} -- display name cache

local function storeName(board): string
	local store = board.Store .. (Config.Leaderboards.StoreSuffix or "")
	return if board.Weekly then store .. "_W" .. Calendar.Week() else store
end

local function getStore(board): OrderedDataStore?
	if not enabled then
		return nil
	end
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, storeName(board))
	if not ok then
		enabled = false
		warn("[LeaderboardService] Leaderboards are OFF: " .. tostring(store))
		return nil
	end
	return store
end

-- Start a fresh weekly total when a new week has begun
local function checkWeek(player: Player)
	local week = Calendar.Week()
	if PlayerDataService.Get(player, "WeeklyCoinsWeek") ~= week then
		PlayerDataService.Set(player, "WeeklyCoins", 0)
		PlayerDataService.Set(player, "WeeklyCoinsWeek", week)
	end
end

-- Called by ThrowService when a throw pays out
function LeaderboardService.RecordThrow(player: Player, pins: number, coins: number)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	checkWeek(player)
	PlayerDataService.Add(player, "LifetimePins", pins)
	PlayerDataService.Add(player, "WeeklyCoins", Currency.Round(coins))
end

-- The scores to save right now (read straight away, before anything can yield)
local function snapshot(player: Player): { { store: string, board: any, value: number } }
	local list = {}
	if PlayerDataService.IsTestSession(player) then
		return list -- Studio test progress never reaches the real leaderboards
	end
	for _, board in LB.Boards do
		local value = PlayerDataService.Get(player, board.Stat)
		if board.Weekly and PlayerDataService.Get(player, "WeeklyCoinsWeek") ~= Calendar.Week() then
			value = 0
		end
		if type(value) == "number" and value > 0 then
			-- (OrderedDataStores take whole numbers under 2^63; pins are uncapped since Addendum 5 A1, so clamp)
			table.insert(list, { store = storeName(board), board = board, value = math.floor(math.min(value, 2 ^ 53)) })
		end
	end
	return list
end

local function writeScores(player: Player, scores)
	local written = lastWritten[player] or {}
	lastWritten[player] = written
	for _, score in scores do
		if written[score.store] ~= score.value then
			local store = getStore(score.board)
			if not store then
				return
			end
			local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), score.value)
			if ok then
				written[score.store] = score.value
			else
				warn("[LeaderboardService] Write failed: " .. tostring(err))
			end
		end
	end
end

local function fetchNames(userIds: { number })
	local missing = {}
	for _, id in userIds do
		if not names[id] and id > 0 then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
	for _, id in missing do
		if not names[id] then
			local okName, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
			names[id] = if okName then name else "Player"
		end
	end
end

local function refreshBoard(board)
	local store = getStore(board)
	if not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, LB.FetchSize):GetCurrentPage()
	end)
	if not ok then
		warn("[LeaderboardService] Read failed: " .. tostring(page))
		return
	end

	local entries = {}
	local topIds = {}
	for _, item in page do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { userId, item.value })
			if #topIds < LB.ShowTop then
				table.insert(topIds, userId)
			end
		end
	end
	fetchNames(topIds)
	local topNames = {}
	for _, id in topIds do
		topNames[tostring(id)] = names[id] or "Player"
	end

	folder:SetAttribute(
		board.Id,
		HttpService:JSONEncode({
			Entries = entries, -- { {userId, score}, ... } best first
			Names = topNames,
			Full = #page >= LB.FetchSize, -- more scores exist below the last entry
			UpdatedAt = workspace:GetServerTimeNow(), -- for the "Updated 12s ago" label
		})
	)
end

local function refreshAll()
	for _, board in LB.Boards do
		refreshBoard(board)
	end
end

function LeaderboardService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = ReplicatedStorage

	PlayerDataService.OnLoaded(checkWeek)
	Players.PlayerRemoving:Connect(function(player)
		writeScores(player, snapshot(player))
		lastWritten[player] = nil
	end)

	-- Write scores of everyone in the server
	task.spawn(function()
		while true do
			task.wait(LB.WriteInterval)
			for _, player in Players:GetPlayers() do
				if PlayerDataService.IsLoaded(player) then
					checkWeek(player)
					task.spawn(writeScores, player, snapshot(player))
				end
			end
		end
	end)

	-- Read the boards
	task.spawn(function()
		while true do
			refreshAll()
			task.wait(LB.RefreshInterval)
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			if PlayerDataService.Get(player, "XP") ~= nil then
				pending += 1
				task.spawn(function()
					writeScores(player, snapshot(player))
					pending -= 1
				end)
			end
		end
		local waited = 0
		while pending > 0 and waited < 10 do
			waited += task.wait()
		end
	end)
end

return LeaderboardService

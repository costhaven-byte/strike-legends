-- Draws the leaderboard boards in the lounge (Workspace.Leaderboards, built in Studio).
-- The server shares the top scores in ReplicatedStorage.Leaderboards; this script adds your own live
-- score on top, so your row and position update right away instead of waiting for the next refresh.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Modules.Calendar)

local player = Players.LocalPlayer

local LB = Config.Leaderboards
local ME_COLOR = Color3.fromRGB(60, 230, 255)
local PLACE_COLORS = {
	Color3.fromRGB(255, 210, 50),
	Color3.fromRGB(220, 225, 240),
	Color3.fromRGB(255, 150, 70),
}
local ROW_COLOR = Color3.fromRGB(255, 255, 255)

local LeaderboardController = {}

-- 1234567 -> "1.23M", 12345 -> "12,345"
local function formatNumber(n: number): string
	n = math.floor(n)
	if n >= 1e9 then
		return ("%.2fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.2fM"):format(n / 1e6)
	end
	local text = tostring(n)
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- Your current score for a board, straight from your Player attributes
local function myScore(board): number
	if board.Weekly and player:GetAttribute("WeeklyCoinsWeek") ~= Calendar.Week(Workspace:GetServerTimeNow()) then
		return 0
	end
	return math.floor(player:GetAttribute(board.Stat) or 0)
end

local function setupBoard(board, surface: SurfaceGui, data: Folder)
	local rows = surface:WaitForChild("Rows") :: Frame
	local template = surface:WaitForChild("RowTemplate") :: Frame
	local you = surface:WaitForChild("You") :: Frame
	local subtitle = surface:WaitForChild("Subtitle") :: TextLabel
	local loading = surface:WaitForChild("Loading") :: TextLabel
	surface:WaitForChild("Title").Text = board.Title
	template.Visible = false

	local rowFrames = {}
	for i = 1, LB.ShowTop do
		local row = template:Clone()
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Visible = false
		row.Parent = rows
		rowFrames[i] = row
	end

	local function render()
		local raw = data:GetAttribute(board.Id)
		local ok, decoded = pcall(function()
			return if raw then HttpService:JSONDecode(raw) else nil
		end)
		if not ok or not decoded then
			loading.Visible = true
			loading.Text = if raw then "Leaderboard unavailable" else "Loading..."
			return
		end
		loading.Visible = false

		-- Server list with your own entry swapped for your live score
		local entries = {}
		for _, entry in decoded.Entries do
			if entry[1] ~= player.UserId then
				table.insert(entries, { UserId = entry[1], Score = entry[2] })
			end
		end
		local score = myScore(board)
		if score > 0 then
			table.insert(entries, { UserId = player.UserId, Score = score, Me = true })
		end
		table.sort(entries, function(a, b)
			if a.Score ~= b.Score then
				return a.Score > b.Score
			end
			return a.Me == true -- ties: you first, so your own number never looks "behind"
		end)

		local myPlace = nil
		for i, entry in entries do
			if entry.Me then
				myPlace = i
				break
			end
		end
		-- The server only reads the top scores, so a place below the last of them isn't known exactly
		if myPlace and decoded.Full and myPlace > #decoded.Entries then
			myPlace = nil
		end

		for i, row in rowFrames do
			local entry = entries[i]
			row.Visible = entry ~= nil
			if entry then
				local color = if entry.Me then ME_COLOR else PLACE_COLORS[i] or ROW_COLOR
				row.Rank.Text = "#" .. i
				row.Rank.TextColor3 = PLACE_COLORS[i] or ROW_COLOR
				row.PlayerName.Text = if entry.Me
					then player.DisplayName
					else decoded.Names[tostring(entry.UserId)] or "Player"
				row.PlayerName.TextColor3 = color
				row.Score.Text = formatNumber(entry.Score)
				row.Score.TextColor3 = color
				row.Highlight.Visible = entry.Me == true
			end
		end

		you.Rank.Text = if score <= 0 then "-" elseif myPlace then "#" .. myPlace else "#" .. LB.FetchSize .. "+"
		you.PlayerName.Text = "YOU"
		you.Score.Text = formatNumber(score)
	end

	local function renderSubtitle()
		if board.Weekly then
			local left = Calendar.SecondsUntilNextWeek(Workspace:GetServerTimeNow())
			subtitle.Text = "RESETS IN " .. Calendar.FormatCountdown(left):upper()
		else
			subtitle.Text = "ALL TIME"
		end
	end

	data:GetAttributeChangedSignal(board.Id):Connect(render)
	player:GetAttributeChangedSignal(board.Stat):Connect(render)
	if board.Weekly then
		player:GetAttributeChangedSignal("WeeklyCoinsWeek"):Connect(render)
	end
	render()
	renderSubtitle()
	task.spawn(function()
		while true do
			task.wait(30)
			renderSubtitle()
		end
	end)
end

function LeaderboardController:Start()
	local data = ReplicatedStorage:WaitForChild("Leaderboards") :: Folder
	local boards = Workspace:WaitForChild("Leaderboards")
	for _, board in LB.Boards do
		local part = boards:WaitForChild(board.Id, 10)
		local surface = part and part:WaitForChild("Board", 10) :: SurfaceGui?
		if surface then
			task.spawn(setupBoard, board, surface, data)
		else
			warn("[LeaderboardController] Missing board in Workspace.Leaderboards: " .. board.Id)
		end
	end
end

return LeaderboardController

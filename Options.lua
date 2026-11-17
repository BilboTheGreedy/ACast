local _, ns = ...
local UI = ns.UI

local anchor

local SIZES = {
	player = { { 200, 260, 320, 380 }, { 16, 22, 28 } },
	target = { { 160, 220, 280 }, { 14, 18, 24 } },
	focus = { { 160, 200, 260 }, { 12, 16, 22 } },
	pet = { { 120, 160, 220 }, { 10, 14, 18 } },
}

local function sizes(title, key, field, values)
	local entries = { { text = title, title = true } }
	for _, v in ipairs(values) do
		entries[#entries + 1] = {
			text = tostring(v), checked = ns.db[key][field] == v,
			func = function()
				ns.db[key][field] = v
				ns.Apply()
			end,
		}
	end
	return entries
end

function ns.Options()
	local db = ns.db
	local entries = {
		{ text = "ACast", title = true },
		{ text = db.locked and "Unlock to move the bars" or "Lock the bars", func = function() ns.SetLocked(not db.locked) end },
		{ text = "Show a test cast", func = ns.Test },
		{ text = "Reset positions", func = ns.Reset },
		{ text = "Bars", title = true },
	}
	for _, key in ipairs(ns.KEYS) do
		entries[#entries + 1] = UI.Check(db[key], "show", ns.LABELS[key], ns.Apply)
	end
	local more = {
		{ text = "Options", title = true },
		UI.Check(db, "icon", "Spell icon", ns.Apply),
		UI.Check(db, "time", "Time text"),
		UI.Check(db, "targetName", "Name of the cast target on the player bar"),
		UI.Check(db, "rank", "Spell rank"),
		UI.Check(db, "latency", "Latency zone on the player bar"),
		UI.Check(db, "hideBlizzard", "Hide the default cast bars", function(on)
			if on then ns.Apply() else ns.Print("the default cast bars come back after /reload") end
		end),
	}
	local function add(list)
		for _, e in ipairs(list) do entries[#entries + 1] = e end
	end
	add(more)
	for _, key in ipairs(ns.KEYS) do
		local label = ns.LABELS[key]
		add(sizes(label .. " width", key, "width", SIZES[key][1]))
		add(sizes(label .. " height", key, "height", SIZES[key][2]))
	end
	add(UI.ScaleEntries({ scale = db.player.scale }, function(s)
		for _, key in ipairs(ns.KEYS) do db[key].scale = s end
		ns.Apply()
	end))
	return entries
end

function ns.OpenMenu()
	if not ns.db or not ns.bars.player then return end
	if not anchor then
		anchor = CreateFrame("Frame", nil, UIParent)
		anchor:SetSize(1, 1)
		anchor:SetPoint("CENTER", UIParent, "CENTER", -90, 160)
	end
	UI.Menu(anchor, ns.Options())
end

SLASH_ACAST1 = "/acast"
SlashCmdList["ACAST"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if not ns.db or not ns.bars.player then return end
	if msg == "unlock" then
		ns.SetLocked(false)
		ns.Print("bars unlocked, drag them and type /acast lock")
	elseif msg == "lock" then
		ns.SetLocked(true)
	elseif msg == "test" then
		ns.Test()
	elseif msg == "reset" then
		ns.Reset()
	else
		ns.OpenMenu()
	end
end

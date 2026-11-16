local _, ns = ...
local UI = ns.UI

local anchor

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

function ns.OpenMenu()
	if not ns.db or not ns.bars.player then return end
	if not anchor then
		anchor = CreateFrame("Frame", nil, UIParent)
		anchor:SetSize(1, 1)
		anchor:SetPoint("CENTER", UIParent, "CENTER", -90, 160)
	end
	local db = ns.db
	local entries = {
		{ text = "ACast", title = true },
		{ text = db.locked and "Unlock to move the bars" or "Lock the bars", func = function() ns.SetLocked(not db.locked) end },
		{ text = "Show a test cast", func = ns.Test },
		{ text = "Reset positions", func = ns.Reset },
		{ text = "Options", title = true },
		UI.Toggle(db.player, "show", "Player cast bar", ns.Apply),
		UI.Toggle(db.target, "show", "Target cast bar", ns.Apply),
		UI.Toggle(db, "icon", "Spell icon", ns.Apply),
		UI.Toggle(db, "time", "Time text"),
		UI.Toggle(db, "latency", "Latency zone on the player bar"),
		UI.Toggle(db, "hideBlizzard", "Hide the default cast bar", function(on)
			if on then ns.Apply() else ns.Print("the default cast bar comes back after /reload") end
		end),
	}
	local function add(list)
		for _, e in ipairs(list) do entries[#entries + 1] = e end
	end
	add(sizes("Player width", "player", "width", { 200, 260, 320, 380 }))
	add(sizes("Player height", "player", "height", { 16, 22, 28 }))
	add(sizes("Target width", "target", "width", { 160, 220, 280 }))
	add(sizes("Target height", "target", "height", { 14, 18, 24 }))
	add(UI.ScaleEntries(db, ns.Apply))
	UI.Menu(anchor, entries)
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

local ADDON, ns = ...

local defaults = {
	locked = true,
	hideBlizzard = true,
	latency = true,
	icon = true,
	time = true,
	targetName = true,
	rank = false,
	player = { show = true, width = 260, height = 22, default = { "CENTER", "CENTER", 0, -210 } },
	target = { show = true, width = 220, height = 18, default = { "CENTER", "CENTER", 0, -120 } },
	focus = { show = true, width = 200, height = 16, default = { "CENTER", "CENTER", 0, -90 } },
	pet = { show = true, width = 160, height = 14, default = { "CENTER", "CENTER", 0, -244 } },
}
ns.defaults = defaults
ns.KEYS = { "player", "target", "focus", "pet" }

ACore.New(ADDON, ns, { db = "ACastDB", defaults = defaults, profile = true })

ACore.Register({
	name = "ACast",
	title = "ACast",
	slash = "/acast",
	desc = "cast bars",
	toggle = function() ns.OpenMenu() end,
	options = function()
		if not ns.db or not ns.Options or not ns.bars.player then return {} end
		return ns.Options()
	end,
})

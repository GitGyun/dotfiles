-- Bootstrap lazynvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)

-- mapleader / maplocalleader is included in keymaps
-- vim.g.mapleader = ","
-- vim.g.maplocalleader = ","

require("config.keymaps")
require("config.options")
require("config.autocmds")

-- The core installer writes this marker so only selected plugins are loaded.
local core_profile = vim.fn.filereadable(vim.fn.expand("~/.config/nvim-core-profile")) == 1
local plugin_spec

if core_profile then
	plugin_spec = {}
	for _, module in ipairs({
		"plugins.sonokai",
		"plugins.lualine",
		"plugins.telescope",
		"plugins.nvim-tree",
	}) do
		local spec = require(module)
		if type(spec[1]) == "table" then
			vim.list_extend(plugin_spec, spec)
		else
			table.insert(plugin_spec, spec)
		end
	end
else
	plugin_spec = {
		{ import = "plugins" },
	}
end

-- Setup lazy.nvim
require("lazy").setup({
	spec = plugin_spec,
	-- Configure any other settings here. See the documentation for more details.
	-- automatically check for plugin updates
	checker = { enabled = true },
	change_detection = { enabled = false },
})

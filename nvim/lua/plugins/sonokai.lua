return {
	"sainnhe/sonokai",
	lazy = false,
	priority = 1000,
	config = function()
		vim.g.sonokai_style = "andromeda"
		vim.g.sonokai_enable_italic = 1
		vim.g.sonokai_disable_italic_comment = 1
	end,
	init = function()
		vim.cmd.colorscheme("sonokai")
		vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2a2a2a" })
	end,
}

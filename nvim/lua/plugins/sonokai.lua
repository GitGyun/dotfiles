return {
	"sainnhe/sonokai",
	lazy = false,
	priority = 1000,
	config = function()
		vim.g.sonokai_style = "andromeda"
		vim.g.sonokai_enable_italic = 1
		vim.g.sonokai_disable_italic_comment = 1
	end,
	-- To use sonokai instead of OceanicNext, uncomment below and
	-- comment out the colorscheme line in oceanic-next.lua:
	-- init = function()
	-- 	vim.cmd.colorscheme("sonokai")
	-- end,
}

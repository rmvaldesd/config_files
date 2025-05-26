return {
	"saghen/blink.cmp",
	optional = true,
	dependencies = {
		"fang2hou/blink-copilot",
		opts = {
			max_completions = 1, -- Global default for max completions
			max_attempts = 2, -- Global default for max attempts
		},
	},
	opts = {
		sources = {
			default = { "copilot" },
			providers = {
				copilot = {
					name = "copilot",
					module = "blink-copilot",
					score_offset = 100,
					async = true,
					opts = {
						-- Local options override global ones
						max_completions = 3, -- Override global max_completions

						-- Final settings:
						-- * max_completions = 3
						-- * max_attempts = 2
						-- * all other options are default
					},
				},
			},
		},
	},
}

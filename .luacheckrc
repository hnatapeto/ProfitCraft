-- luacheck pre WoW addon ProfitCraft
std = "lua51"
max_line_length = false
exclude_files = { ".claude/**" }

-- WoW API je obrovske - pristup k neznamym globalom ignorujeme,
-- ale ZAPIS do neznamych globalov (zabudnute "local") hlasime.
ignore = {
    "113", -- accessing undefined variable (WoW API)
    "212", -- unused argument (self, event...)
    "432", -- shadowing upvalue argument
}

globals = {
    "ProfitCraft",
    "ProfitCraftDB",
    "ProfitCraft_OnAddonCompartmentClick",
    "SlashCmdList",
    "SLASH_PROFITCRAFT1", "SLASH_PROFITCRAFT2",
    "SLASH_CRAFTTIMER1", "SLASH_CRAFTTIMER2",
    "UISpecialFrames",
}

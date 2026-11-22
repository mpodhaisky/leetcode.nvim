local fzf = require("fzf-lua")
local contest_picker = require("leetcode.picker.contest")
local Picker = require("leetcode.picker")

local deli = "\t"

return function(contests, attended, mode)
    local items = contest_picker.items(contests, attended, mode)
    local by_slug = {}

    local lines = {}
    for _, item in ipairs(items) do
        by_slug[item.value.title_slug] = item.value
        table.insert(lines, Picker.normalize({ item })[1] .. deli .. item.value.title_slug)
    end

    fzf.fzf_exec(lines, {
        prompt = contest_picker.title(mode) .. "> ",
        winopts = {
            height = contest_picker.height,
            width = contest_picker.width,
        },
        fzf_opts = {
            ["--delimiter"] = deli,
            ["--with-nth"] = "1",
        },
        actions = {
            ["default"] = function(selected)
                local slug = Picker.hidden_field(selected[1], deli)
                contest_picker.select(by_slug[slug], mode)
            end,
        },
    })
end

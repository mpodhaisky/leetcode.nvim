local log = require("leetcode.logger")
local contest_picker = require("leetcode.picker.contest")

local picker = require("mini.pick")

return function(contests, attended, mode)
    local items = contest_picker.items(contests, attended, mode)
    local ns_id = vim.api.nvim_create_namespace("MiniPick LeetCode Contest Picker")
    local finder_items = {}
    local completed = false

    for _, item in ipairs(items) do
        table.insert(finder_items, {
            entry = item.entry,
            text = contest_picker.ordinal(item.value),
            item = item,
        })
    end

    local res = picker.start({
        source = {
            items = finder_items,
            name = contest_picker.title(mode),
            choose = function(item)
                if completed then
                    return
                end
                completed = true
                vim.schedule(function()
                    contest_picker.select(item.item.value, mode)
                end)
            end,
            show = function(buf_id, items_)
                require("leetcode.picker.mini_pick_utils").show_items(buf_id, ns_id, items_)
            end,
        },
        window = {
            config = {
                width = contest_picker.width,
                height = math.floor(vim.o.lines * contest_picker.height),
            },
        },
    })

    if res == nil then
        if completed then
            return
        end
        completed = true
        log.warn("No selection")
    end
end

local log = require("leetcode.logger")
local contest_picker = require("leetcode.picker.contest")

local picker = require("snacks.picker")

return function(contests, attended, mode)
    local items = contest_picker.items(contests, attended, mode)
    local finder_items = {}
    local completed = false

    for _, item in ipairs(items) do
        table.insert(finder_items, {
            text = contest_picker.ordinal(item.value),
            item = item,
        })
    end

    picker.pick({
        items = finder_items,
        format = function(item)
            local ret = {}
            for _, col in ipairs(item.item.entry) do
                ret[#ret + 1] = col
                ret[#ret + 1] = { " " }
            end
            return ret
        end,
        title = contest_picker.title(mode),
        layout = {
            preset = "select",
            preview = false,
            layout = {
                height = contest_picker.height,
                width = contest_picker.width,
            },
        },
        actions = {
            confirm = function(p, item)
                if completed then
                    return
                end
                completed = true
                p:close()
                vim.schedule(function()
                    contest_picker.select(item.item.value, mode)
                end)
            end,
        },
        on_close = function()
            if completed then
                return
            end
            completed = true
            log.warn("No selection")
        end,
    })
end

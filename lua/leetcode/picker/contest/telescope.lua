local log = require("leetcode.logger")
local contest_picker = require("leetcode.picker.contest")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

local entry_display = require("telescope.pickers.entry_display")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local displayer = entry_display.create({
    separator = " ",
    items = {
        { width = 1 },
        { width = 40 },
        { remaining = true },
    },
})

local function entry_maker(item)
    return {
        value = item.value,
        display = function()
            return displayer(item.entry)
        end,
        ordinal = contest_picker.ordinal(item.value),
    }
end

local theme = require("telescope.themes").get_dropdown({
    layout_config = {
        width = contest_picker.width,
        height = contest_picker.height,
    },
})

return function(contests, attended, mode)
    local items = contest_picker.items(contests, attended, mode)

    pickers
        .new(theme, {
            prompt_title = contest_picker.title(mode),
            finder = finders.new_table({
                results = items,
                entry_maker = entry_maker,
            }),
            sorter = conf.generic_sorter(theme),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    if not selection then
                        log.warn("No selection")
                        return
                    end
                    actions.close(prompt_bufnr)
                    contest_picker.select(selection.value, mode)
                end)
                return true
            end,
        })
        :find()
end

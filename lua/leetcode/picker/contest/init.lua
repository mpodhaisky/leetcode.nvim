local log = require("leetcode.logger")
local config = require("leetcode.config")

---@class leet.Picker.Contest
local P = {}

P.width = 70
P.height = 0.6

local CLOCK = "󰥔"

---@param contest lc.api.Contest
local function display_status(contest, attended)
    if contest.start_time > os.time() then
        return { CLOCK, "leetcode_info" }
    end
    if attended[contest.title_slug] then
        return config.icons.hl.status.ac
    end
    return { " " }
end

---@param contest lc.api.Contest
local function display_date(contest)
    local upcoming = contest.start_time > os.time()
    local fmt = upcoming and "%a %Y-%m-%d %H:%M" or "%Y-%m-%d"
    return { os.date(fmt, contest.start_time), upcoming and "leetcode_info" or "leetcode_alt" }
end

---@param contest lc.api.Contest
function P.entry(contest, attended)
    return {
        display_status(contest, attended),
        { ("%-30s"):format(contest.title) },
        display_date(contest),
    }
end

---@param contest lc.api.Contest
function P.ordinal(contest)
    return ("%s %s"):format(contest.title, contest.title_slug)
end

---@param contests lc.api.Contest[]
---@param attended table<string, boolean>
---@param mode "open"|"virtual"
---@return { entry: any, value: lc.api.Contest }[]
function P.items(contests, attended, mode)
    local items = {}
    for _, contest in ipairs(contests) do
        local upcoming = contest.start_time > os.time()
        -- upcoming contests can't be done virtually, but are listed for info
        if not (mode == "virtual" and upcoming) then
            table.insert(items, { entry = P.entry(contest, attended), value = contest })
        end
    end
    return items
end

---@param mode "open"|"virtual"
function P.title(mode)
    return mode == "virtual" and "Start a Virtual Contest" or "Select a Contest"
end

---@param contest lc.api.Contest
---@param mode "open"|"virtual"
function P.select(contest, mode)
    if not contest then
        return log.warn("No selection")
    end
    local contests = require("leetcode.contest")
    if mode == "virtual" then
        contests.start_virtual(contest)
    else
        contests.open(contest)
    end
end

return P

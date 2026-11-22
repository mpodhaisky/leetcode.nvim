local utils = require("leetcode.api.utils")
local queries = require("leetcode.api.queries")
local config = require("leetcode.config")

---@class lc.api.Contest
---@field title string
---@field title_slug string
---@field start_time integer
---@field duration integer

---@class lc.api.ContestQuestion
---@field title string
---@field title_slug string
---@field credit integer
---@field id string
---@field is_ac boolean

---@class lc.ContestApi
local Contest = {}

---All contests (upcoming and past), newest first.
---@return lc.api.Contest[]|nil, lc.err|nil
function Contest.all()
    local res, err = utils.query(queries.contests, {})
    if err then
        return nil, err
    end
    -- LeetCode serves this query from a cache that ignores field aliases
    return vim.tbl_map(function(c)
        return {
            title = c.title,
            title_slug = c.title_slug or c.titleSlug,
            start_time = c.start_time or c.startTime,
            duration = c.duration,
        }
    end, res.data.contests or res.data.allContests or {})
end

---Questions of a contest in contest order (Q1..Q4).
---@param title_slug string
---@return lc.api.ContestQuestion[]|nil, lc.err|nil
function Contest.questions(title_slug)
    local res, err = utils.query(queries.contest_questions, { contestSlug = title_slug })
    if err then
        return nil, err
    end
    local questions = res.data.questions
    if questions == vim.NIL or not questions or vim.tbl_isempty(questions) then
        return nil, { msg = ("No questions found for contest `%s`"):format(title_slug) }
    end
    return questions
end

---Slugs of the contests the signed-in user took part in.
---@return table<string, boolean>
function Contest.attended()
    local res, err = utils.query(queries.contest_history, { username = config.auth.name })
    local attended = {}
    if err or not res.data or res.data.history == vim.NIL then
        return attended
    end
    for _, h in ipairs(res.data.history or {}) do
        if h.attended then
            attended[h.contest.title_slug] = true
        end
    end
    return attended
end

return Contest

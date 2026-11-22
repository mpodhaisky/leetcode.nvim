---Contests: open all questions of a contest side by side in tabs, and run
---local virtual contests (timer, submission tracking, score and penalty).
---
---LeetCode's own virtual contest registration and live ranking live behind
---Cloudflare-protected endpoints, so virtual contests are tracked locally and
---do not show up on the LeetCode profile.

local log = require("leetcode.logger")
local config = require("leetcode.config")

---@class lc.contest.Problem
---@field title string
---@field title_slug string
---@field credit integer
---@field solved_at? integer seconds since the start of the contest
---@field wrong integer rejected submissions (penalised once the problem is accepted)
---@field is_ac? boolean solved before (practice mode)

---@class lc.contest.State
---@field title string
---@field title_slug string
---@field virtual boolean
---@field started_at? integer
---@field duration? integer
---@field ended? boolean
---@field problems lc.contest.Problem[]

---@class lc.Contest
local M = {}

-- Penalty per rejected submission of a problem that is accepted later.
M.PENALTY = 5 * 60

-- Verdicts that LeetCode does not penalise.
local NO_PENALTY = {
    [16] = true, -- internal error
    [20] = true, -- compile error
}

---@type lc.contest.State|nil  virtual contest (persisted)
M.virtual = nil
---@type table<string, lc.contest.State>  contests opened in practice mode, by slug
M.practice = {}

local timer = nil
local loaded = false

local function state_file()
    return config.storage.cache:joinpath("contest.json")
end

local function save()
    local file = state_file()
    if M.virtual then
        file:write(vim.json.encode(M.virtual), "w")
    elseif file:exists() then
        pcall(file.rm, file)
    end
end

local function load()
    if loaded then
        return
    end
    loaded = true

    local file = state_file()
    if not file:exists() then
        return
    end
    local ok, state = pcall(vim.json.decode, file:read())
    if ok and type(state) == "table" and state.title_slug then
        M.virtual = state
    end
end

---@param secs integer
local function fmt_duration(secs)
    secs = math.max(0, math.floor(secs))
    return ("%d:%02d:%02d"):format(math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60)
end
M.fmt_duration = fmt_duration

---Human friendly "time until", e.g. `3d 4h` or `2h 05m`.
---@param secs integer
function M.fmt_until(secs)
    local d = math.floor(secs / 86400)
    local h, m = math.floor(secs % 86400 / 3600), math.floor(secs % 3600 / 60)
    if d > 0 then
        return ("%dd %dh"):format(d, h)
    end
    return ("%dh %02dm"):format(h, m)
end

---@param state lc.contest.State
function M.elapsed(state)
    return os.time() - state.started_at
end

---@param state lc.contest.State
function M.remaining(state)
    return state.duration - M.elapsed(state)
end

---@param state lc.contest.State
---@return { solved: integer, points: integer, max_points: integer, finish: integer|nil }
function M.score(state)
    local s = { solved = 0, points = 0, max_points = 0, finish = nil }
    local last, penalty = nil, 0
    for _, p in ipairs(state.problems) do
        s.max_points = s.max_points + p.credit
        if p.solved_at then
            s.solved = s.solved + 1
            s.points = s.points + p.credit
            last = math.max(last or 0, p.solved_at)
            penalty = penalty + p.wrong * M.PENALTY
        end
    end
    if last then
        s.finish = last + penalty
    end
    return s
end

---@return lc.contest.State|nil, integer|nil
local function find_problem(title_slug)
    -- practice states first: reopening a finished virtual contest practises it
    local states = {}
    for _, s in pairs(M.practice) do
        table.insert(states, s)
    end
    table.insert(states, M.virtual)
    for _, state in ipairs(states) do
        for i, p in ipairs(state.problems) do
            if p.title_slug == title_slug then
                return state, i
            end
        end
    end
end

---@param state lc.contest.State
function M.is_running(state)
    return state and state.virtual and not state.ended and M.remaining(state) > 0
end

------------------------------------------------------------------------------
-- Winbar
------------------------------------------------------------------------------

local function esc(s)
    return (s:gsub("%%", "%%%%"))
end

---Winbar for contest question windows.
---@param winid? integer the window the winbar belongs to
function M.winbar(winid)
    winid = winid or vim.g.statusline_winid
    local q
    for _, question in ipairs(_Lc_state.questions) do
        if question.winid == winid then
            q = question
            break
        end
    end
    if not q then
        return ""
    end

    local state, idx = find_problem(q.q.title_slug)
    if not state then
        return ""
    end

    -- most important first: if the window is too narrow, the title gets cut
    local parts = {}

    if state.virtual then
        if M.is_running(state) then
            local left = M.remaining(state)
            local hl = left < 10 * 60 and "leetcode_error" or "leetcode_ref"
            table.insert(parts, ("%%#%s#󰔟 %s left%%*"):format(hl, fmt_duration(left)))
        else
            table.insert(parts, "%#leetcode_alt#󰔟 ended%*")
        end
        local s = M.score(state)
        table.insert(parts, ("%%#leetcode_info#%d/%d pts%%*"):format(s.points, s.max_points))
    else
        table.insert(parts, ("%%#leetcode_alt#%d pts%%*"):format(state.problems[idx].credit))
    end

    for i, p in ipairs(state.problems) do
        local label = "Q" .. i
        local hl = "leetcode_alt"
        if p.solved_at or (not state.virtual and p.is_ac) then
            hl = "leetcode_ok"
            label = label .. " " .. config.icons.status.ac
        elseif p.wrong > 0 then
            hl = "leetcode_error"
            label = ("%s %s%d"):format(label, config.icons.status.notac, p.wrong)
        end
        if i == idx then
            label = "[" .. label .. "]"
            if hl == "leetcode_alt" then
                hl = "leetcode_normal"
            end
        end
        table.insert(parts, ("%%#%s#%s%%*"):format(hl, label))
    end

    local bar = " " .. table.concat(parts, "  ")
    local used = vim.api.nvim_eval_statusline(bar, { winid = winid, maxwidth = 1000 }).width
    if used + #state.title + 2 <= vim.api.nvim_win_get_width(winid) then
        bar = bar .. "  %#leetcode_header#" .. esc(state.title) .. "%*"
    end
    return bar
end

-- the window id is baked in: `g:statusline_winid` is not reliably set for winbars
local WINBAR = "%%{%%v:lua.require'leetcode.contest'.winbar(%d)%%}"

---@param q lc.ui.Question
local function attach_winbar(q)
    if q.winid and vim.api.nvim_win_is_valid(q.winid) then
        vim.wo[q.winid].winbar = WINBAR:format(q.winid)
    end
end

------------------------------------------------------------------------------
-- Timer
------------------------------------------------------------------------------

local function stop_timer()
    if timer then
        timer:stop()
        timer:close()
        timer = nil
    end
end

local function tick()
    local state = M.virtual
    if not state or state.ended then
        return stop_timer()
    end

    local left = M.remaining(state)
    if left <= 0 then
        M.finish("Time's up!")
    elseif left == 10 * 60 or left == 60 then
        log.warn(("%s: %s left"):format(state.title, fmt_duration(left)))
    end
    vim.cmd("redrawstatus!")
end

local function start_timer()
    stop_timer()
    timer = (vim.uv or vim.loop).new_timer()
    timer:start(1000, 1000, vim.schedule_wrap(tick))
end

------------------------------------------------------------------------------
-- Summary
------------------------------------------------------------------------------

---@param state lc.contest.State
function M.summary(state)
    local s = M.score(state)
    local lines = {
        ("%s (virtual)"):format(state.title),
        ("Score: %d/%d   Solved: %d/%d   Finish time: %s"):format(
            s.points,
            s.max_points,
            s.solved,
            #state.problems,
            s.finish and fmt_duration(s.finish) or "-"
        ),
    }
    for i, p in ipairs(state.problems) do
        local verdict
        if p.solved_at then
            verdict = ("accepted at %s"):format(fmt_duration(p.solved_at))
            if p.wrong > 0 then
                verdict = verdict .. (" (+%d wrong, +%d min)"):format(p.wrong, p.wrong * 5)
            end
        else
            verdict = p.wrong > 0 and ("%d wrong"):format(p.wrong) or "-"
        end
        table.insert(lines, ("Q%d [%d] %s: %s"):format(i, p.credit, p.title, verdict))
    end
    if M.is_running(state) then
        table.insert(lines, ("Time left: %s"):format(fmt_duration(M.remaining(state))))
    end
    return table.concat(lines, "\n")
end

---End the running virtual contest.
---@param reason string
function M.finish(reason)
    local state = M.virtual
    if not state or state.ended then
        return
    end
    state.ended = true
    save()
    stop_timer()
    log.info(reason .. "\n\n" .. M.summary(state))
    vim.cmd("redrawstatus!")
end

------------------------------------------------------------------------------
-- Submissions
------------------------------------------------------------------------------

---Record a judged submission. Called for every submission result.
---@param title_slug string
---@param item lc.interpreter_response
function M.on_submission(title_slug, item)
    local state, idx = find_problem(title_slug)
    if not state then
        return
    end
    local p = state.problems[idx]
    local accepted = item.status_code == 10

    if not state.virtual then
        p.is_ac = p.is_ac or accepted
        return vim.cmd("redrawstatus!")
    end

    if not M.is_running(state) or p.solved_at then
        return
    end

    if accepted then
        p.solved_at = M.elapsed(state)
        local s = M.score(state)
        log.info(
            ("Q%d accepted at %s  (+%d, %d/%d pts)"):format(
                idx,
                fmt_duration(p.solved_at),
                p.credit,
                s.points,
                s.max_points
            )
        )
    elseif not NO_PENALTY[item.status_code] then
        p.wrong = p.wrong + 1
    end
    save()

    if M.score(state).solved == #state.problems then
        M.finish("All problems solved!")
    end
    vim.cmd("redrawstatus!")
end

------------------------------------------------------------------------------
-- Opening contests
------------------------------------------------------------------------------

---@param cq lc.api.ContestQuestion|lc.contest.Problem
---@return lc.cache.Question
local function cache_entry(cq)
    local problemlist = require("leetcode.cache.problemlist")
    local ok, entry = pcall(problemlist.get_by_title_slug, cq.title_slug)
    if ok and entry then
        return entry
    end
    -- brand-new contest questions may not be in the cached problem list yet
    return {
        title = cq.title,
        title_slug = cq.title_slug,
        title_cn = "",
        frontend_id = "",
        status = cq.is_ac and "ac" or "todo",
        paid_only = false,
        link = ("https://leetcode.%s/problems/%s/"):format(config.domain, cq.title_slug),
        difficulty = "Medium",
        ac_rate = 0,
        topic_tags = {},
    }
end

---Open every question of `state` in its own tab, in contest order.
---@param state lc.contest.State
---@param reset_code? boolean reset existing solutions to the default snippet
local function open_tabs(state, reset_code)
    local Question = require("leetcode-ui.question")
    local utils = require("leetcode.utils")

    local first_tab, reset = nil, {}
    for i, p in ipairs(state.problems) do
        local existing = utils.detect_duplicate_question(p.title_slug, config.lang)
        local ok, q = pcall(function()
            return Question(cache_entry(p)):mount()
        end)

        if not ok then
            log.error(("Q%d %s: %s"):format(i, p.title, q))
        else
            local mounted
            for _, question in ipairs(_Lc_state.questions) do
                if question.q and question.q.title_slug == p.title_slug then
                    mounted = question
                end
            end
            if mounted then
                attach_winbar(mounted)
                first_tab = first_tab or utils.question_tabp(mounted)

                if reset_code and not existing and mounted.bufnr then
                    local range = mounted:editor_section_range("code")
                    local snippet = mounted:snippet(true)
                    if range.complete and snippet then
                        local code = table.concat(range.lines, "\n", range.start_i, range.end_i)
                        if vim.trim(code) ~= vim.trim(snippet) then
                            mounted:editor_reset_code()
                            table.insert(reset, "Q" .. i)
                        end
                    end
                end
            end
        end
    end

    if first_tab then
        pcall(vim.api.nvim_set_current_tabpage, first_tab)
    end
    if not vim.tbl_isempty(reset) then
        log.info(
            ("Reset previous code of %s to the default snippet. Undo with `u`."):format(
                table.concat(reset, ", ")
            )
        )
    end
    vim.cmd("redrawstatus!")
end

---@param contest lc.api.Contest
---@param virtual boolean
---@return lc.contest.State|nil
local function build_state(contest, virtual)
    local api = require("leetcode.api.contest")
    local questions, err = api.questions(contest.title_slug)
    if not questions then
        log.err(err)
        return
    end

    local problems = {}
    for _, q in ipairs(questions) do
        table.insert(problems, {
            title = q.title,
            title_slug = q.title_slug,
            credit = q.credit,
            wrong = 0,
            is_ac = q.is_ac == true,
        })
    end

    return {
        title = contest.title,
        title_slug = contest.title_slug,
        virtual = virtual,
        duration = contest.duration,
        problems = problems,
    }
end

---@param contest lc.api.Contest
local function not_started(contest)
    if contest.start_time > os.time() then
        log.warn(
            ("%s hasn't started yet. It starts on %s (in %s)."):format(
                contest.title,
                os.date("%a %Y-%m-%d %H:%M", contest.start_time),
                M.fmt_until(contest.start_time - os.time())
            )
        )
        return true
    end
end

---Open all questions of a contest (practice mode, no timer).
---@param contest lc.api.Contest
function M.open(contest)
    load()
    if not_started(contest) then
        return
    end
    if M.virtual and M.virtual.title_slug == contest.title_slug and M.is_running(M.virtual) then
        return M.resume()
    end

    local state = build_state(contest, false)
    if not state then
        return
    end
    M.practice[contest.title_slug] = state
    open_tabs(state)
end

---Start a virtual contest: open all questions and start the clock.
---@param contest lc.api.Contest
function M.start_virtual(contest)
    load()
    if not_started(contest) then
        return
    end
    if contest.start_time + contest.duration > os.time() then
        return log.warn(contest.title .. " is still running. Take part in it on leetcode.com.")
    end

    if M.is_running(M.virtual) then
        local choice = vim.fn.confirm(
            ("Virtual contest `%s` is still running. Abandon it?"):format(M.virtual.title),
            "&Yes\n&No",
            2
        )
        if choice ~= 1 then
            return
        end
    end

    local choice = vim.fn.confirm(
        ("Start virtual %s now? (%d min)"):format(contest.title, math.floor(contest.duration / 60)),
        "&Start\n&Cancel",
        1
    )
    if choice ~= 1 then
        return
    end

    local state = build_state(contest, true)
    if not state then
        return
    end
    M.practice[contest.title_slug] = nil

    open_tabs(state, true)
    -- start the clock once the questions are loaded
    state.started_at = os.time()
    M.virtual = state
    save()
    start_timer()

    log.info(
        ("Virtual %s started: %d questions, %s. Good luck!"):format(
            state.title,
            #state.problems,
            fmt_duration(state.duration)
        )
    )
end

---Reopen the tabs of the running virtual contest (e.g. after restarting Neovim).
function M.resume()
    load()
    if not M.is_running(M.virtual) then
        return false
    end
    open_tabs(M.virtual)
    start_timer()
    return true
end

---@return lc.contest.State|nil
function M.get_virtual()
    load()
    if M.virtual and M.virtual.virtual and not M.virtual.ended and M.remaining(M.virtual) <= 0 then
        M.finish("Time's up!")
    end
    return M.virtual
end

---Stop the running virtual contest early.
function M.stop()
    if not M.is_running(M.get_virtual()) then
        return log.warn("No virtual contest is running")
    end
    local choice = vim.fn.confirm(
        ("End virtual contest `%s` now?"):format(M.virtual.title),
        "&End\n&Cancel",
        2
    )
    if choice == 1 then
        M.finish("Virtual contest ended.")
    end
end

---Print the scoreboard of the current or last virtual contest.
function M.status()
    local state = M.get_virtual()
    if not state then
        return log.warn("No virtual contest yet. Start one with `:Leet contest virtual`.")
    end
    log.info(M.summary(state))
end

---Tell the user about a virtual contest that is still running (on startup).
function M.notify_running()
    local state = M.get_virtual()
    if M.is_running(state) then
        start_timer()
        log.info(
            ("Virtual %s is running (%s left). Reopen it with `:Leet contest virtual`."):format(
                state.title,
                fmt_duration(M.remaining(state))
            )
        )
    end
end

return M

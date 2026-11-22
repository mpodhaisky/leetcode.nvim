local cmd = require("leetcode.command")

local Title = require("leetcode-ui.lines.title")
local Button = require("leetcode-ui.lines.button.menu")
local BackButton = require("leetcode-ui.lines.button.menu.back")
local Buttons = require("leetcode-ui.group.buttons.menu")
local Page = require("leetcode-ui.group.page")

local footer = require("leetcode-ui.lines.footer")
local header = require("leetcode-ui.lines.menu-header")

local page = Page()

page:insert(header)

page:insert(Title({ "Menu" }, "Contests"))

local list = Button("List", {
    icon = "",
    sc = "o",
    on_press = cmd.contest,
})

local virtual = Button("Virtual", {
    icon = "󰔟",
    sc = "v",
    on_press = cmd.contest_virtual,
})

local status = Button("Status", {
    icon = "󰄪",
    sc = "s",
    on_press = cmd.contest_status,
})

local stop = Button("Stop virtual", {
    icon = "",
    sc = "x",
    on_press = cmd.contest_stop,
})

local back = BackButton("menu")

page:insert(Buttons({
    list,
    virtual,
    status,
    stop,
    back,
}))

page:insert(footer)

return page

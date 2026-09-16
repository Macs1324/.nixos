hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("clipse -listen")
end)

hl.workspace_rule({ workspace = "special:notes", on_created_empty = "rnote" })
hl.window_rule({ name = "clipse", match = { class = "clipse" }, float = true, size = "622 652" })
hl.layer_rule({ name = "notifications", match = { namespace = "notifications" }, animation = "slide" })

hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("ease", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "ease", style = "slidefadevert" })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "overshot", style = "gnomed" })

hl.bind("SUPER + Q", hl.dsp.exec_cmd(apps.terminal))
hl.bind("SUPER + O", hl.dsp.exec_cmd(apps.launcher))
hl.bind("SUPER + E", hl.dsp.exec_cmd(apps.fileManager))
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + V", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + SHIFT + V", hl.dsp.layout("swapsplit"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))
hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd(apps.lock))
hl.bind("SUPER + A", hl.dsp.workspace.toggle_special("notes"))
hl.bind("SUPER + CTRL + V", hl.dsp.exec_cmd("kitty --class clipse -e clipse"))
hl.bind("SUPER + S", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.float({ action = "toggle" }))

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = direction }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end
for key, delta in pairs({ h = { -50, 0 }, j = { 0, 50 }, k = { 0, -50 }, l = { 50, 0 } }) do
    hl.bind("SUPER + CTRL + " .. key, hl.dsp.window.resize({ x = delta[1], y = delta[2], relative = true }))
end
for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER + ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })

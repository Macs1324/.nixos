{...}: {
  extraConfigLua = ''
    -- Display
    vim.opt.linespace = 1

    vim.g.neovide_scale_factor = 1.0
    vim.g.neovide_padding_top = 6
    vim.g.neovide_padding_bottom = 6
    vim.g.neovide_padding_left = 6
    vim.g.neovide_padding_right = 6

    -- Floating windows
    vim.g.neovide_floating_blur_amount_x = 2.0
    vim.g.neovide_floating_blur_amount_y = 2.0
    vim.g.neovide_floating_shadow = true
    vim.g.neovide_floating_corner_radius = 0.2

    -- Keep motion responsive while retaining Neovide's visual polish.
    vim.g.neovide_position_animation_length = 0.12
    vim.g.neovide_scroll_animation_length = 0.20
    vim.g.neovide_scroll_animation_far_lines = 1
    vim.g.neovide_cursor_animation_length = 0.08
    vim.g.neovide_cursor_short_animation_length = 0.03
    vim.g.neovide_cursor_trail_size = 0.7
    vim.g.neovide_cursor_animate_in_insert_mode = false
    vim.g.neovide_cursor_animate_command_line = true
    vim.g.neovide_cursor_smooth_blink = true

    -- Window and input behavior
    vim.g.neovide_confirm_quit = true
    vim.g.neovide_hide_mouse_when_typing = true
    vim.g.neovide_remember_window_size = true

    local function change_scale(delta)
      local scale = vim.g.neovide_scale_factor or 1.0
      vim.g.neovide_scale_factor = math.max(0.5, math.min(2.0, scale + delta))
    end

    local map_opts = { silent = true }
    local modes = { "n", "v", "i" }

    vim.keymap.set(modes, "<C-=>", function()
      change_scale(0.1)
    end, vim.tbl_extend("force", map_opts, { desc = "Increase Neovide scale" }))

    vim.keymap.set(modes, "<C-->", function()
      change_scale(-0.1)
    end, vim.tbl_extend("force", map_opts, { desc = "Decrease Neovide scale" }))

    vim.keymap.set(modes, "<C-0>", function()
      vim.g.neovide_scale_factor = 1.0
    end, vim.tbl_extend("force", map_opts, { desc = "Reset Neovide scale" }))

    vim.keymap.set("n", "<F11>", function()
      vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
    end, vim.tbl_extend("force", map_opts, { desc = "Toggle Neovide fullscreen" }))

    vim.keymap.set({ "n", "i" }, "<C-s>", "<Cmd>write<CR>",
      vim.tbl_extend("force", map_opts, { desc = "Save file" }))

    vim.keymap.set("v", "<C-S-c>", '"+y',
      vim.tbl_extend("force", map_opts, { desc = "Copy to system clipboard" }))

    vim.keymap.set({ "n", "v", "i", "c", "t" }, "<C-S-v>", function()
      vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
    end, vim.tbl_extend("force", map_opts, { desc = "Paste from system clipboard" }))
  '';
}

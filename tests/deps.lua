-- `make deps`, second half: after `Lazy! restore` has installed the plugins, start the config
-- once and wait for its treesitter parser installs to finish, so test runs see highlighted
-- buffers and don't compile parsers in the background.
local h = dofile((vim.env.KICKSTART_REPO or vim.fn.getcwd()) .. '/tests/helpers.lua')
h.disable_mason_installs()
h.track_parser_installs()

local function missing(langs)
  local installed = require('nvim-treesitter').get_installed()
  return vim.tbl_filter(function(lang)
    return not vim.tbl_contains(installed, lang)
  end, type(langs) == 'table' and langs or { langs })
end

h.run_on_vim_enter(function()
  local requested = {}
  for _, install in ipairs(h.parser_installs) do
    install.task:pwait(600000)
    vim.list_extend(requested, type(install.langs) == 'table' and install.langs or { install.langs })
  end

  -- A parallel download occasionally fails without the task reporting it; retry those once.
  local retry = missing(requested)
  if #retry > 0 then
    io.stdout:write('\nRETRY parsers: ' .. table.concat(retry, ', ') .. '\n')
    require('nvim-treesitter').install(retry):pwait(600000)
    for _, lang in ipairs(missing(retry)) do
      h.fail('treesitter parser failed to install: ' .. lang)
    end
  end
  return ('%d treesitter parser(s) installed'):format(#requested - #missing(requested))
end, 660)

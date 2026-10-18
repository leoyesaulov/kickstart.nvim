-- Keymap <-> docs check: every keymap this config defines must have a row in bindings.md, and
-- the Active/Disabled status column must match which plugin specs init.lua actually loads.
--
-- Run via `make keymaps` (nvim --cmd, -V1 so Lua mappings record the script that defined them).
-- One-directional on purpose: bindings.md also documents plugin defaults (mini.ai, blink.cmp,
-- nvim's gr*) and LSP/gitsigns/jdtls on_attach maps that a headless run never produces.
local h = dofile((vim.env.KICKSTART_REPO or vim.fn.getcwd()) .. '/tests/helpers.lua')
h.disable_mason_installs()

local repo = vim.uv.fs_realpath(h.repo)

local function read(path)
  local f = assert(io.open(path, 'r'))
  local s = f:read '*a'
  f:close()
  return s
end

-- Canonical form of a key sequence, so `<C-space>`, `<c-Space>` and the internal encoding
-- nvim_get_keymap returns all compare equal. Leader is <Space> in this config; spell it
-- `<leader>` to match bindings.md.
local function canon(internal)
  return (vim.fn.keytrans(internal):gsub('^<Space>', '<leader>'))
end

-- For keys as written in bindings.md.
-- keycode() turns <C-j> into a bare "\n", which keytrans() spells <NL>, while the mapping
-- table keeps it as <C-J>.
local function norm(keys)
  local c = canon(vim.keycode(keys))
  return (c:gsub('<NL>', '<C-J>'))
end

-- bindings.md mode column -> set of nvim mode letters it covers. "All"/"—" match anything.
local mode_words = { Normal = 'n', Visual = 'x', Select = 's', Insert = 'i', Terminal = 't', Operator = 'o', Command = 'c' }

local function parse_bindings()
  local rows = {}
  for line in read(h.repo .. '/bindings.md'):gmatch '[^\n]+' do
    local keys, mode, source, status = line:match '^| (`.-`) | (.-) | .- | (.-) | (%a+) |$'
    if keys then
      local modes = {}
      local base = mode:gsub('%(.-%)', '')
      if base:find 'All' or base:find '—' then
        modes = nil
      else
        for word in base:gmatch '%a+' do
          if mode_words[word] then
            modes[mode_words[word]] = true
          end
        end
      end
      -- "`<C-n>` / `<C-p>`, `<Down>` / `<Up>`" documents several keys in one row.
      for key in keys:gmatch '`(.-)`' do
        table.insert(rows, { key = norm(key), modes = modes, source = source, status = status, line = line })
      end
    end
  end
  return rows
end

-- nvim_get_keymap reports `mode` as the :map-command prefix: ' ' = :map (n+x+s+o), 'v' = x+s,
-- '!' = i+c, ...
local map_modes = {
  [' '] = { n = true, x = true, s = true, o = true },
  v = { x = true, s = true },
  ['!'] = { i = true, c = true },
  l = { i = true, c = true },
}

local function documented(rows, lhs, mode)
  local want = map_modes[mode] or { [mode] = true }
  for _, row in ipairs(rows) do
    if row.key == lhs then
      if row.modes == nil then
        return true
      end
      for m in pairs(want) do
        if row.modes[m] then
          return true
        end
      end
    end
  end
  return false
end

-- Script path for a mapping's sid, or nil for the Lua/builtin pseudo-scripts.
local script_names = {}
local function script_of(sid)
  if sid <= 0 then
    return nil
  end
  if script_names[sid] == nil then
    local info = vim.fn.getscriptinfo({ sid = sid })[1]
    script_names[sid] = info and vim.uv.fs_realpath(info.name) or false
  end
  return script_names[sid] or nil
end

-- A mapping is "defined by this config" if it was set from init.lua or lua/ in this repo, or by
-- lazy.nvim's keys handler (which registers every `keys = { ... }` entry of our plugin specs).
local function from_config(path)
  if not path then
    return false
  end
  if path == repo .. '/init.lua' or vim.startswith(path, repo .. '/lua/') then
    return true
  end
  return path:find '/lazy%.nvim/lua/lazy/core/handler/keys%.lua$' ~= nil
end

local function check_maps(rows, maps, where)
  local seen = {}
  local count = 0
  for _, map in ipairs(maps) do
    local path = script_of(map.sid)
    local lhs = canon(map.lhsraw or map.lhs)
    local id = map.mode .. '\0' .. lhs
    if from_config(path) and not seen[id] and not lhs:find '^<Plug>' then
      seen[id] = true
      count = count + 1
      if not documented(rows, lhs, map.mode) then
        local src = vim.fn.fnamemodify(path, ':~:.') .. ':' .. (map.lnum or '?')
        h.fail(('%s keymap %s (mode %q, %s) is not in bindings.md%s'):format(where, lhs, map.mode, src, map.desc and (' — desc: ' .. map.desc) or ''))
      end
    end
  end
  return count
end

local modes = { 'n', 'v', 'x', 's', 'o', 'i', 't', 'c' }

local function global_maps()
  local all = {}
  for _, m in ipairs(modes) do
    vim.list_extend(all, vim.api.nvim_get_keymap(m))
  end
  return all
end

local function buf_maps(buf)
  local all = {}
  for _, m in ipairs(modes) do
    vim.list_extend(all, vim.api.nvim_buf_get_keymap(buf, m))
  end
  return all
end

-- Rows sourced from a lua/kickstart/plugins/<name>.lua file must say Active exactly when
-- init.lua's lazy.setup has an uncommented `require 'kickstart.plugins.<name>'`; rows from
-- lua/custom/plugins/ follow the `{ import = 'custom.plugins' }` line the same way.
local function check_status(rows)
  local init = read(h.repo .. '/init.lua')
  local function enabled(pattern)
    for line in init:gmatch '[^\n]+' do
      if line:find(pattern) then
        return not line:find '^%s*%-%-'
      end
    end
    return false
  end

  for _, row in ipairs(rows) do
    local want
    local custom = row.source:match '^custom/plugins/'
    local kick = row.source:match '^([%w_-]+)%.lua'
    if custom then
      want = enabled "{%s*import%s*=%s*'custom%.plugins'%s*}"
    elseif kick and vim.uv.fs_stat(h.repo .. '/lua/kickstart/plugins/' .. kick .. '.lua') then
      want = enabled("require%s*%(?%s*'kickstart%.plugins%." .. vim.pesc(kick) .. "'")
    end
    if want ~= nil then
      local expected = want and 'Active' or 'Disabled'
      if row.status ~= expected then
        h.fail(('bindings.md says %s for %s but init.lua makes it %s:\n%s'):format(row.status, row.key, expected, row.line))
      end
    end
  end
end

h.run_on_vim_enter(function()
  local rows = parse_bindings()
  if #rows == 0 then
    error 'parsed no rows out of bindings.md; did the table format change?'
  end
  check_status(rows)

  h.trigger_very_lazy()
  vim.wait(200)
  local bufs = h.open_fixtures()

  local count = check_maps(rows, global_maps(), 'global')
  for file, buf in pairs(bufs) do
    count = count + check_maps(rows, buf_maps(buf), file)
  end
  if count == 0 then
    error 'found no config-defined keymaps; is nvim running with -V1?'
  end
  return ('%d config keymaps all documented in bindings.md (%d rows)'):format(count, #rows)
end)

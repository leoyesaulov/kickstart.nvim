-- Per-project completion usage for blink.cmp: every accepted item in a tracked filetype bumps a
-- counter for its project, and items you've accepted before get a score_offset bonus on the next
-- completion request. Wired up in init.lua (blink's lsp/snippets transform_items + setup()).
--
-- blink's built-in frecency isn't used: it only works with the Rust matcher (this config uses
-- the Lua one) and keeps a single global database rather than one per project.
--
-- Stats: stdpath('state')/completion-usage/<project>-<hash>.json. Delete a file to reset it.
local M = {}

M.filetypes = { java = true, python = true }
M.state_dir = vim.fn.stdpath 'state' .. '/completion-usage'

-- Priority groups, like java.lua's find_root: a git repo wins over a nested build file, so a
-- multi-module project shares one set of stats.
local root_markers = {
  { '.git' },
  {
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
    'settings.gradle',
    'settings.gradle.kts',
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
  },
}

local MAX_BONUS = 12
local WRITE_DELAY_MS = 2000

--- @type table<string, { counts: table<string, integer>, dirty: boolean }>
local projects = {}
local write_timer

--- Score bonus for an item accepted `count` times: 0, 1→3, 3→6, 7→9, 15+→12.
function M.bonus(count)
  if not count or count <= 0 then
    return 0
  end
  return math.min(math.floor(3 * math.log(count + 1) / math.log(2) + 1e-9), MAX_BONUS)
end

local function project_root(buf)
  local cached = vim.b[buf].completion_usage_root
  if cached then
    return cached
  end
  local root = vim.fs.root(buf, root_markers) or vim.fn.getcwd()
  vim.b[buf].completion_usage_root = root
  return root
end

local function db_path(root)
  return ('%s/%s-%s.json'):format(M.state_dir, vim.fn.fnamemodify(root, ':t'), vim.fn.sha256(root):sub(1, 8))
end

local function load(root)
  local project = projects[root]
  if project then
    return project
  end
  local counts = {}
  local f = io.open(db_path(root), 'r')
  if f then
    local ok, decoded = pcall(vim.json.decode, f:read '*a')
    f:close()
    if ok and type(decoded) == 'table' then
      counts = decoded
    end
  end
  project = { counts = counts, dirty = false }
  projects[root] = project
  return project
end

--- Write every project with unsaved counts (tmp file + rename, so a crash can't truncate it).
function M.flush()
  for root, project in pairs(projects) do
    if project.dirty then
      vim.fn.mkdir(M.state_dir, 'p')
      local path = db_path(root)
      local f = io.open(path .. '.tmp', 'w')
      if f then
        f:write(vim.json.encode(project.counts))
        f:close()
        os.rename(path .. '.tmp', path)
        project.dirty = false
      end
    end
  end
end

local function schedule_flush()
  write_timer = write_timer or vim.uv.new_timer()
  write_timer:stop()
  write_timer:start(WRITE_DELAY_MS, 0, vim.schedule_wrap(M.flush))
end

-- filterText rather than label: jdtls labels carry the signature ("println(String x) : void"),
-- so keying on filterText ("println") lets all overloads share one count.
local function key(ft, item)
  return ft .. '\t' .. tostring(item.kind or 0) .. '\t' .. (item.filterText or item.label or '')
end

--- Count one accepted item for the project and filetype of `buf`.
function M.record(buf, item)
  local ft = vim.bo[buf].filetype
  if not M.filetypes[ft] or not item then
    return
  end
  local project = load(project_root(buf))
  local k = key(ft, item)
  project.counts[k] = (project.counts[k] or 0) + 1
  project.dirty = true
  schedule_flush()
end

--- blink transform_items helper: add each item's usage bonus to its score_offset.
function M.boost(ctx, items)
  local buf = ctx and ctx.bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  if not M.filetypes[ft] then
    return items
  end
  local counts = load(project_root(buf)).counts
  for _, item in ipairs(items) do
    local bonus = M.bonus(counts[key(ft, item)])
    if bonus > 0 then
      item.score_offset = (item.score_offset or 0) + bonus
    end
  end
  return items
end

function M.setup()
  local group = vim.api.nvim_create_augroup('custom-completion-usage', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'BlinkCmpAccept',
    callback = function(ev)
      local data = ev.data or {}
      local buf = data.context and data.context.bufnr or vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(buf) then
        M.record(buf, data.item)
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = M.flush })
end

return M

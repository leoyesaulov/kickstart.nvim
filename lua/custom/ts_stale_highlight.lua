-- Workaround for a Neovim 0.12 treesitter highlighter bug: "Decoration provider "range"
-- (ns=nvim.treesitter.highlighter): treesitter.lua:216: Index out of bounds", e.g. after undoing a
-- multi-line snippet in a big file.
--
-- The highlighter re-parses asynchronously. When a parse takes longer than 3ms, `parsing` stays
-- true, and on_win then reuses the saved highlight states instead of rebuilding them. Each saved
-- state holds the TSTree from before the edit: LanguageTree:_edit stores a new `tree:edit()`
-- copy, so the saved one is never updated. Once lines are deleted, that old tree's nodes point
-- past the end of the buffer, and a query predicate's get_node_text throws.
--
-- The fix: while a parse is running, swap each saved state's old tree for the current one (edited,
-- not yet re-parsed, but in the buffer's current coordinates). A state whose tree can't be found is
-- skipped for that redraw, and the parse callback repaints it a few ms later.
--
-- This wraps two internal highlighter methods. If they're missing (Neovim changed), it does nothing.
-- Drop this file once upstream fixes the bug. Wired up in init.lua.
local M = {}

function M.setup()
  local ok, H = pcall(require, 'vim.treesitter.highlighter')
  if not ok or H._kickstart_stale_patch then
    return
  end
  local prepare, for_each = H.prepare_highlight_states, H.for_each_highlight_state
  if type(prepare) ~= 'function' or type(for_each) ~= 'function' then
    return
  end
  H._kickstart_stale_patch = true

  -- Record which LanguageTree (and which of its trees) each new state came from.
  H.prepare_highlight_states = function(self, ...)
    local ret = prepare(self, ...)
    local origin = {} ---@type table<TSTree, { [1]: vim.treesitter.LanguageTree, [2]: integer }>
    self.tree:for_each_tree(function(_, ltree)
      for idx, tree in pairs(ltree:trees()) do
        origin[tree] = { ltree, idx }
      end
    end)
    for _, state in ipairs(self._highlight_states or {}) do
      local o = origin[state.tstree]
      if o then
        state._ltree, state._idx = o[1], o[2]
      end
    end
    return ret
  end

  H.for_each_highlight_state = function(self, fn)
    if not self.parsing then
      return for_each(self, fn) -- states were just rebuilt from the current trees
    end
    return for_each(self, function(state)
      local cur = state._ltree and state._ltree:trees()[state._idx]
      if not cur then
        return -- unknown or gone: skip this redraw rather than read a stale tree
      end
      if cur ~= state.tstree then
        state.tstree, state.iter, state.next_row, state.next_col = cur, nil, 0, 0
      end
      return fn(state)
    end)
  end
end

return M

-- Java via nvim-jdtls.
--
-- jdtls is deliberately NOT in init.lua's generic `servers` table: it needs a per-project
-- workspace dir, lombok, and bundled java-debug/java-test jars that the static
-- `servers[name] = opts` + mason-lspconfig generic handler pattern can't express. Instead it's
-- started here, from a FileType autocmd, which re-resolves root_dir/workspace per project (so
-- switching between two different Java projects in the same session attaches correctly to both).
--
-- Needs a real Maven/Gradle (or Eclipse .project) root to fully attach — a loose .java file with
-- no build descriptor gets degraded single-file support, same as IntelliJ without a project.
return {
  'mfussenegger/nvim-jdtls',
  ft = 'java',
  config = function()
    local function attach_jdtls()
      local jdtls_ok, jdtls = pcall(require, 'jdtls')
      if not jdtls_ok then
        return
      end

      local mason_registry = require 'mason-registry'
      local jdtls_ok2, jdtls_pkg = pcall(mason_registry.get_package, 'jdtls')
      if not jdtls_ok2 or not jdtls_pkg:is_installed() then
        vim.notify('jdtls: Mason package not installed yet (:Mason to install)', vim.log.levels.WARN)
        return
      end
      local jdtls_root = jdtls_pkg:get_install_path()

      local function bundle_jars(pkg_name, glob)
        local ok, pkg = pcall(mason_registry.get_package, pkg_name)
        if not ok or not pkg:is_installed() then
          return {}
        end
        return vim.fn.glob(pkg:get_install_path() .. '/' .. glob, true, true)
      end

      local bundles = {}
      vim.list_extend(bundles, bundle_jars('java-debug-adapter', 'extension/server/com.microsoft.java.debug.plugin-*.jar'))
      vim.list_extend(bundles, bundle_jars('java-test', 'extension/server/*.jar'))

      local root_dir = require('jdtls.setup').find_root { 'pom.xml', 'build.gradle', 'build.gradle.kts', 'settings.gradle', '.git' }
      if not root_dir or root_dir == '' then
        return
      end

      local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
      local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. project_name

      local os_config = vim.fn.has 'mac' == 1 and 'config_mac' or vim.fn.has 'win32' == 1 and 'config_win' or 'config_linux'

      local config = {
        cmd = {
          'java',
          '-Declipse.application=org.eclipse.jdt.ls.core.id1',
          '-Dosgi.bundles.defaultStartLevel=4',
          '-Declipse.product=org.eclipse.jdt.ls.core.product',
          '-Dlog.protocol=true',
          '-Dlog.level=ALL',
          '-javaagent:' .. jdtls_root .. '/lombok.jar',
          '-Xmx1g',
          '--add-modules=ALL-SYSTEM',
          '--add-opens',
          'java.base/java.util=ALL-UNNAMED',
          '--add-opens',
          'java.base/java.lang=ALL-UNNAMED',
          '-jar',
          vim.fn.glob(jdtls_root .. '/plugins/org.eclipse.equinox.launcher_*.jar'),
          '-configuration',
          jdtls_root .. '/' .. os_config,
          '-data',
          workspace_dir,
        },
        root_dir = root_dir,
        init_options = {
          bundles = bundles,
        },
        settings = {
          java = {
            signatureHelp = { enabled = true },
            completion = { favoriteStaticMembers = {} },
          },
        },
        capabilities = require('blink.cmp').get_lsp_capabilities(),
        on_attach = function(_, bufnr)
          jdtls.setup_dap { hotcodereplace = 'auto' }
          require('jdtls.dap').setup_dap_main_class_configs()

          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = bufnr, desc = 'Java: ' .. desc })
          end
          map('<leader>jo', jdtls.organize_imports, '[O]rganize imports')
          map('<leader>jt', require('jdtls.dap').test_class, '[T]est class')
          map('<leader>jm', require('jdtls.dap').test_nearest_method, 'Test nearest [M]ethod')
        end,
      }

      jdtls.start_or_attach(config)
    end

    vim.api.nvim_create_autocmd('FileType', { pattern = 'java', callback = attach_jdtls })
    attach_jdtls()
  end,
}

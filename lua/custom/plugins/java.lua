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
    -- macOS ships a stub /usr/bin/java that only prints "Unable to locate a Java Runtime", and
    -- brew's openjdk is keg-only (not on PATH) — so look for a real JDK before falling back to PATH.
    local function find_java()
      local candidates = {}
      if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= '' then
        table.insert(candidates, vim.env.JAVA_HOME .. '/bin/java')
      end
      if vim.fn.has 'mac' == 1 then
        table.insert(candidates, '/opt/homebrew/opt/openjdk/bin/java')
        table.insert(candidates, '/usr/local/opt/openjdk/bin/java')
        local java_home = vim.fn.system({ '/usr/libexec/java_home' }):gsub('%s+$', '')
        if vim.v.shell_error == 0 and java_home ~= '' then
          table.insert(candidates, java_home .. '/bin/java')
        end
      end
      for _, java in ipairs(candidates) do
        if vim.fn.executable(java) == 1 then
          return java
        end
      end
      -- On macOS a bare `java` is the stub unless java_home found a JDK above, so don't use it.
      if vim.fn.has 'mac' == 0 and vim.fn.executable 'java' == 1 then
        return 'java'
      end
      return nil
    end

    -- Ordered by priority, not proximity: vim.fs.root tries each group in turn, so a multi-module
    -- build resolves to the top-level project (gradlew/mvnw/settings.gradle) rather than the
    -- submodule whose build.gradle/pom.xml happens to be nearest.
    local root_markers = {
      { 'gradlew', 'mvnw', 'settings.gradle', 'settings.gradle.kts' },
      '.git',
      { 'pom.xml', 'build.gradle', 'build.gradle.kts' },
    }
    local function find_root()
      return vim.fs.root(0, root_markers)
    end

    -- jdtls checks every project's gradle/wrapper/gradle-wrapper.jar against Gradle's published
    -- checksums and refuses unknown ones ("Security Warning! The gradle wrapper ... could be
    -- malicious"). :JdtTrustGradleWrapper records the current project's jar sha256 here, and the
    -- list is passed as `java.imports.gradle.wrapper.checksums` on every jdtls start.
    local trust_file = vim.fn.stdpath 'data' .. '/jdtls-trusted-gradle-wrappers.json'

    local function read_trusted()
      local f = io.open(trust_file, 'r')
      if not f then
        return {}
      end
      local ok, list = pcall(vim.json.decode, f:read '*a')
      f:close()
      return ok and type(list) == 'table' and list or {}
    end

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
      -- java-test ships jars that aren't OSGi bundles (runner, jacoco) plus asm jars jdtls already
      -- has; loading those makes jdtls fail the whole bundle list, so filter them out.
      local excluded = { 'com.microsoft.java.test.runner-jar-with-dependencies.jar', 'jacocoagent.jar' }
      vim.list_extend(
        bundles,
        vim.tbl_filter(function(jar)
          local name = vim.fn.fnamemodify(jar, ':t')
          return not vim.tbl_contains(excluded, name) and not name:match '^org%.objectweb%.asm'
        end, bundle_jars('java-test', 'extension/server/*.jar'))
      )

      local java = find_java()
      if not java then
        vim.notify('jdtls: no JDK found (macOS: brew install openjdk, or set JAVA_HOME)', vim.log.levels.WARN)
        return
      end

      local root_dir = find_root()
      if not root_dir or root_dir == '' then
        return
      end

      local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
      -- Hash suffix keeps two projects with the same folder name from sharing one jdtls index.
      local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. project_name .. '-' .. vim.fn.sha256(root_dir):sub(1, 8)

      local trusted = read_trusted()
      local settings = {
        java = {
          signatureHelp = { enabled = true },
          completion = { favoriteStaticMembers = {} },
          -- Left nil when empty: vim.json encodes {} as an object, but jdtls expects a list.
          imports = {
            gradle = {
              wrapper = {
                checksums = #trusted > 0 and vim.tbl_map(function(sha)
                  return { sha256 = sha, allowed = true }
                end, trusted) or nil,
              },
            },
          },
        },
      }

      local os_config = vim.fn.has 'mac' == 1 and 'config_mac' or vim.fn.has 'win32' == 1 and 'config_win' or 'config_linux'

      local config = {
        cmd = {
          java,
          '-Declipse.application=org.eclipse.jdt.ls.core.id1',
          '-Dosgi.bundles.defaultStartLevel=4',
          '-Declipse.product=org.eclipse.jdt.ls.core.product',
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
        -- Settings go in init_options too: jdtls runs the initial project import (including the
        -- gradle wrapper check) using only initializationOptions.settings, before the
        -- workspace/didChangeConfiguration that `settings` produces arrives.
        init_options = {
          bundles = bundles,
          -- Unlocks the interactive "Generate Constructors… / Getters and Setters… / toString() /
          -- hashCode() and equals()" source actions (field pickers via vim.ui.select).
          extendedClientCapabilities = jdtls.extendedClientCapabilities,
          settings = settings,
        },
        settings = settings,
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
          map('<leader>jg', function()
            vim.lsp.buf.code_action { context = { only = { 'source' } } }
          end, '[G]enerate (ctor/getters/setters/toString/equals)')
        end,
      }

      jdtls.start_or_attach(config)
    end

    vim.api.nvim_create_user_command('JdtTrustGradleWrapper', function()
      local root = find_root()
      local jar = root and root .. '/gradle/wrapper/gradle-wrapper.jar'
      if not jar or vim.fn.filereadable(jar) == 0 then
        vim.notify('jdtls: no gradle/wrapper/gradle-wrapper.jar in this project', vim.log.levels.WARN)
        return
      end
      -- sha256sum on Arch (coreutils), shasum on macOS.
      local cmd = vim.fn.executable 'sha256sum' == 1 and { 'sha256sum', jar } or { 'shasum', '-a', '256', jar }
      local sha = vim.fn.system(cmd):match '^(%x+)'
      if vim.v.shell_error ~= 0 or not sha then
        vim.notify('jdtls: failed to hash ' .. jar, vim.log.levels.ERROR)
        return
      end

      local trusted = read_trusted()
      if not vim.tbl_contains(trusted, sha) then
        table.insert(trusted, sha)
        vim.fn.mkdir(vim.fn.fnamemodify(trust_file, ':h'), 'p')
        vim.fn.writefile({ vim.json.encode(trusted) }, trust_file)
      end
      vim.notify('jdtls: trusted gradle wrapper ' .. sha:sub(1, 12) .. '…, restarting', vim.log.levels.INFO)

      -- Restart so the new checksum list goes out with the initial settings and Gradle re-imports.
      for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
        client:stop()
      end
      vim.wait(5000, function()
        return #vim.lsp.get_clients { name = 'jdtls' } == 0
      end)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'java' then
          vim.api.nvim_buf_call(buf, attach_jdtls)
        end
      end
    end, { desc = "Trust this project's Gradle wrapper jar for jdtls and restart it" })

    vim.api.nvim_create_autocmd('FileType', { pattern = 'java', callback = attach_jdtls })
    attach_jdtls()
  end,
}

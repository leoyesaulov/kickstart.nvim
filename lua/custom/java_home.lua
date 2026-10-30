-- JDK lookup shared by lua/custom/plugins/java.lua (to launch jdtls) and run.lua (to run loose
-- .java files). Lives outside lua/custom/plugins/ so lazy doesn't import it as a plugin spec.
local M = {}

-- macOS ships a stub /usr/bin/java that only prints "Unable to locate a Java Runtime", and
-- brew's openjdk is keg-only (not on PATH) — so look for a real JDK before falling back to PATH.
function M.find_java()
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

return M

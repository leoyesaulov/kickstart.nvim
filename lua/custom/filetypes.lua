-- Extra filetype detection for the DevOps stack. Required from init.lua before lazy.setup so it's
-- in place before any buffer opens.
--
-- Compound filetypes (`yaml.docker-compose`, `yaml.github`) keep yaml highlighting and
-- formatting, because treesitter and conform both split on `.`. They also let specific tools
-- attach: docker_compose_language_service only runs on `yaml.docker-compose`, and actionlint
-- (lua/kickstart/plugins/lint.lua) only on `yaml.github`.
--
-- Patterns without a `/` match the file's basename; patterns with one match the full path.
vim.filetype.add {
  pattern = {
    -- Neovim 0.12 detects these as plain `yaml`, so the compose LSP never attaches without this.
    ['docker%-compose%.ya?ml'] = 'yaml.docker-compose',
    ['docker%-compose%..*%.ya?ml'] = 'yaml.docker-compose', -- docker-compose.override.yml, .prod.yml, ...
    ['compose%.ya?ml'] = 'yaml.docker-compose',
    ['compose%..*%.ya?ml'] = 'yaml.docker-compose',

    ['.*/%.github/workflows/.*%.ya?ml'] = 'yaml.github',

    -- Neovim already covers /etc/nginx/, nginx.conf and */nginx/*.conf. Bare `sites-available/*`
    -- is left out on purpose: Debian's apache uses the same directory name.
    ['.*%.nginx'] = 'nginx',
    ['.*/nginx/sites%-[^/]*/.*'] = 'nginx',
    ['.*/nginx/.*%.conf%.template'] = 'nginx', -- the official nginx image's /etc/nginx/templates
  },
}

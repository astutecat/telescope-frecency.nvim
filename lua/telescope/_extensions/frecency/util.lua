local uv = vim.loop
local const = require"frecency.const"
local Path = require"plenary.path"

local util = {}

-- stolen from penlight

---escape any Lua 'magic' characters in a string
util.escape = function(str)
  return (str:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1"))
end

util.string_isempty = function(str)
  return str == nil or str == ""
end

util.filemask = function(mask)
  mask = util.escape(mask)
  return "^" .. mask:gsub("%%%*", ".*"):gsub("%%%?", ".") .. "$"
end

util.file_is_ignored = function(filepath, ignore_patters)
  local is_ignored = false
  --- TODO: it should be merged or flatten
  for _, pattern in pairs(ignore_patterns and ignore_patters or const.ignore_patterns) do
    if filepath:find(util.filemask(pattern)) ~= nil then
      is_ignored = true
      goto continue
    end
  end

  ::continue::
  return is_ignored
end

---Format filename. Mainly os_home to {~/} or current to {./}
---@param filename string
---@return string
util.file_format = function(filename, opts)
  local original_filename = filename

  if opts.active_filter then
    filename = Path:new(filename):make_relative(opts.active_filter)
  else
    filename = Path:new(filename):make_relative(opts.cwd)
    -- check relative to home/current
    if vim.startswith(filename, os_home) then
      filename = "~/" .. Path:new(filename):make_relative(os_home)
    elseif filename ~= original_filename then
      filename = "./" .. filename
    end
  end

  if opts.tail_path then
    filename = util.path_tail(filename)
  elseif opts.shorten_path then
    filename = util.path_shorten(filename)
  end

  return filename
end

util.fs_stat = function(path)
  local stat = path and uv.fs_stat(path) or nil
  local res = {}
  res.exists = stat and true or false -- TODO: this is silly
  res.isdirectory = (stat and stat.type == "directory") and true or false

  return res
end

util.path_invalid = function(path)
  local stat = util.fs_stat(path)
  if stat == {} or stat.isdirectory then
    return true
  end
  return false
end

util.confirm_deletion = function (num_of_entries)
  local question = "Telescope-Frecency: remove %d entries from SQLite3 database?"
  return vim.fn.confirm(question:format(num_of_entries), "&Yes\n&No", 2) == 1
end

util.abort_remove_unlinked_files = function()
  ---TODO: refactor all messages to a lua file. alarts.lua?
  print "TelescopeFrecency: validation aborted."
end

util.tbl_match = function(field, val, tbl)
  return vim.tbl_filter(function(t)
    return t[field] == val
  end, tbl)
end

---Wrappe around Path:new():make_relative
---@return string
---@FIXME: errors out, path is nil
util.path_make_relative = function (path, cwd)
  return Path:new(cwd..path):make_relative()
end

---Given a filename, check if there's a buffer with the given name.
---@return boolean
util.buf_is_loaded = function (filename)
  return vim.api.nvim_buf_is_loaded(vim.fn.bufnr(filename))
end

---Set buffer mappings and options
---@param opts: {bufnr, mappings = {}, options = {}}
util.buf_set = function(opts)
  local bufnr = opts[1]
  for k, v in pairs(opts.options) do
    vim.api.nvim_buf_set_option(bufnr, k, v)
  end
  for k, lhs in pairs(opts.mappings) do
    if k ~= "expr" then
      local rhs = vim.split(k, "|")
      vim.api.nvim_buf_set_keymap(bufnr, rhs[1], rhs[2], lhs, { expr = opts.expr, noremap = true })
    end
  end
end

util.include_unindexed = function (files, ws_path)
  local scan_opts = { respect_gitignore = true, depth = 100, hidden = true, }

  local unindexed_files = require("plenary.scandir").scan_dir(ws_path, scan_opts)
  for _, file in pairs(unindexed_files) do
    if not util.file_is_ignored(file) then -- this causes some slowdown on large dirs
      table.insert(files, { id = 0, path = file, count = 0, directory_id = 0 })
    end
  end
end

return util

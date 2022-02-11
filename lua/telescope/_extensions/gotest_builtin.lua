#! /usr/bin/env lua

local actions = require'telescope.actions'
local state = require'telescope.actions.state'
local actions_set = require'telescope.actions.set'
local conf = require'telescope.config'.values
local finders = require'telescope.finders'
local channel = require("plenary.async.control").channel
local make_entry = require "telescope.make_entry"
local pickers = require'telescope.pickers'

local M = {}

local function filter_symbols(results, opts)
  if opts.symbols == nil then
    return results
  end
  local valid_symbols = vim.tbl_map(string.lower, vim.lsp.protocol.SymbolKind)

  local filtered_symbols = {}
  for _, result in ipairs(results) do
    if string.match(result.filename, "_test.go") ~= nil and string.lower(result.kind) == string.lower(opts.symbols) then
      table.insert(filtered_symbols, result)
    end
  end

  local current_buf = vim.api.nvim_get_current_buf()
  if not vim.tbl_isempty(filtered_symbols) then
    -- filter adequately for workspace symbols
    local filename_to_bufnr = {}
    for _, symbol in ipairs(filtered_symbols) do
      if filename_to_bufnr[symbol.filename] == nil then
        filename_to_bufnr[symbol.filename] = vim.uri_to_bufnr(vim.uri_from_fname(symbol.filename))
      end
      symbol["bufnr"] = filename_to_bufnr[symbol.filename]
    end
    table.sort(filtered_symbols, function(a, b)
      if a.bufnr == b.bufnr then
        return a.lnum < b.lnum
      end
      if a.bufnr == current_buf then
        return true
      end
      if b.bufnr == current_buf then
        return false
      end
      return a.bufnr < b.bufnr
    end)
    return filtered_symbols
  end
  -- only account for string|table as function otherwise already printed message and returned nil
  local symbols = type(opts.symbols) == "string" and opts.symbols or table.concat(opts.symbols, ", ")
  print(string.format("%s symbol(s) were not part of the query results", symbols))
end

local function get_workspace_symbols_requester(bufnr, opts)
  local cancel = function() end

  return function(prompt)
    local tx, rx = channel.oneshot()
    cancel()
    _, cancel = vim.lsp.buf_request(bufnr, "workspace/symbol", { query = prompt }, tx)

    -- Handle 0.5 / 0.5.1 handler situation
    local err, res = rx()
    assert(not err, err)

    local locations = vim.lsp.util.symbols_to_items(res or {}, bufnr) or {}
    if not vim.tbl_isempty(locations) then
      locations = filter_symbols(locations, opts) or {}
    end
    return locations
  end
end

M.gotest = function(opts)
  opts = opts or {}
  opts.symbols = 'function'
  local curr_bufnr = vim.api.nvim_get_current_buf()

  pickers.new(opts, {
    prompt_title = "LSP Dynamic Workspace Symbols",
    finder = finders.new_dynamic {
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
      fn = get_workspace_symbols_requester(curr_bufnr, opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
			actions_set.select:replace(function(_, type)
				local entry = state.get_selected_entry()
				actions.close(prompt_bufnr)
				if not entry then
					return
				end
                local pkg = string.reverse(entry.filename)
                local file_name = string.match(pkg, "og.[_%w]*/")
                if file_name == nil then
                  return
                end

                local file_name_length = string.len(file_name)

                local matched_path = string.match(entry.filename, "pkg/[_/%.%w]*")
                if matched_path == nil then
                  return
                end

                local matched_path_length = string.len(matched_path)
                local ret = string.sub(matched_path, 0, matched_path_length - file_name_length)
                -- vim.fn.termopen(string.format('echo "Symbol=%s\nfile_name=%s\nmatched_path=%s\nret=%s"', entry.symbol_name, file_name, matched_path, ret))
                vim.fn.termopen(string.format('./dev test %s -f %s -v --show-logs', ret, entry.symbol_name))
			end)
			return true
		end,
  }):find()
end

return M


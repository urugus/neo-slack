---@brief [[
--- neo-slack.nvim UI モジュール
--- ユーザーインターフェースを構築します
---@brief ]]

local api = require('neo-slack.api')
local utils = require('neo-slack.utils')
local state = require('neo-slack.state')
local events = require('neo-slack.core.events')
local config = require('neo-slack.core.config')

---@class NeoSlackUI
---@field layout table レイアウト情報
local M = {}

-- レイアウト情報
M.layout = {
  channels_win = nil,
  messages_win = nil,
  thread_win = nil,
  channels_buf = nil,
  messages_buf = nil,
  thread_buf = nil,
}

-- 通知ヘルパー関数
---@param message string 通知メッセージ
---@param level number 通知レベル
local function notify(message, level)
  utils.notify(message, level)
end

-- ウィンドウが有効かどうかをチェック
---@param win_id number|nil ウィンドウID
---@return boolean 有効かどうか
local function is_valid_window(win_id)
  return win_id ~= nil and vim.api.nvim_win_is_valid(win_id)
end

-- バッファオプションを設定
---@param bufnr number バッファ番号
---@param filetype string ファイルタイプ
local function setup_buffer_options(bufnr, filetype)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', filetype)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
end

-- 分割レイアウトを設定
---@return nil
function M.setup_split_layout()
  -- 既存のスレッドウィンドウを閉じる
  if is_valid_window(M.layout.thread_win) then
    vim.api.nvim_win_close(M.layout.thread_win, true)
    M.layout.thread_win = nil
    M.layout.thread_buf = nil
  end
  
  -- チャンネル一覧用のウィンドウが存在しない場合は作成
  if not is_valid_window(M.layout.channels_win) then
    -- 現在のウィンドウを全画面に
    vim.cmd('only')
    
    -- 現在のウィンドウをメッセージ用に設定
    M.layout.messages_win = vim.api.nvim_get_current_win()
    
    -- 左側に新しいウィンドウを作成（チャンネル一覧用）
    vim.cmd('leftabove vsplit')
    M.layout.channels_win = vim.api.nvim_get_current_win()
    
    -- チャンネル一覧の幅を設定
    local channels_width = config.get('layout.channels.width', 30)
    vim.api.nvim_win_set_width(M.layout.channels_win, channels_width)
    
    -- メッセージウィンドウに戻る
    vim.cmd('wincmd l')
  end
end

-- スレッド表示用のレイアウトを設定
---@return nil
function M.setup_thread_layout()
  -- 分割レイアウトを設定
  M.setup_split_layout()
  
  -- スレッド用のウィンドウが存在しない場合は作成
  if not is_valid_window(M.layout.thread_win) then
    -- メッセージウィンドウにフォーカス
    if is_valid_window(M.layout.messages_win) then
      vim.api.nvim_set_current_win(M.layout.messages_win)
    end
    
    -- 右側に新しいウィンドウを作成（スレッド用）
    vim.cmd('rightbelow vsplit')
    M.layout.thread_win = vim.api.nvim_get_current_win()
    
    -- スレッドウィンドウとメッセージウィンドウの幅を調整
    local total_width = vim.o.columns
    local channels_width = config.get('layout.channels.width', 30)
    local remaining_width = total_width - channels_width
    local thread_width = math.floor(remaining_width / 2)
    
    vim.api.nvim_win_set_width(M.layout.thread_win, thread_width)
    
    -- メッセージウィンドウに戻って幅を調整
    vim.cmd('wincmd h')
    if is_valid_window(M.layout.messages_win) then
      vim.api.nvim_win_set_width(M.layout.messages_win, thread_width)
    end
    
    -- スレッドウィンドウに戻る
    vim.cmd('wincmd l')
  end
end

-- バッファを作成または取得
---@param name string バッファ名
---@return number バッファ番号
function M.get_or_create_buffer(name)
  local bufname = 'neo-slack://' .. name
  
  -- 既存のバッファを探す
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == bufname then
      return buf
    end
  end
  
  -- 新しいバッファを作成
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, bufname)
  
  return bufnr
end

-- セクションの折りたたみ/展開を切り替える
---@param section_name string セクション名またはID
---@return nil
function M.toggle_section_collapse(section_name)
  local is_collapsed = state.is_section_collapsed(section_name)
  state.set_section_collapsed(section_name, not is_collapsed)
  
  -- 折りたたみ状態を保存
  state.save_section_collapsed()
  
  -- チャンネル一覧を更新
  events.emit('refresh_channels')
  
  -- セクション名を取得（IDの場合はセクション名に変換）
  local display_name = section_name
  if state.custom_sections[section_name] then
    display_name = state.custom_sections[section_name].name
  end
  
  -- 通知
  if not is_collapsed then
    notify(display_name .. ' セクションを折りたたみました', vim.log.levels.INFO)
  else
    notify(display_name .. ' セクションを展開しました', vim.log.levels.INFO)
  end
end

-- チャンネル一覧のキーマッピングを設定
---@param bufnr number バッファ番号
---@return nil
function M.setup_channels_keymaps(bufnr)
  local opts = { noremap = true, silent = true }
  
  -- Enter: チャンネルを選択またはセクションの折りたたみ/展開
  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '<cmd>lua require("neo-slack.ui").select_channel_or_toggle_section()<CR>', opts)
  
  -- q: ウィンドウを閉じる
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<cmd>q<CR>', opts)
  
  -- r: チャンネル一覧を更新
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'r', '<cmd>lua require("neo-slack.core.events").emit("refresh_channels")<CR>', opts)
  
  -- s: チャンネルをスター付き/解除
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 's', '<cmd>lua require("neo-slack.ui").toggle_star_channel()<CR>', opts)
  
  -- a: チャンネルをセクションに割り当て
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'a', '<cmd>lua require("neo-slack.ui").assign_channel_to_section_current()<CR>', opts)
  
  -- c: 新しいセクションを作成
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'c', '<cmd>lua require("neo-slack.ui").create_section_dialog()<CR>', opts)
  
  -- e: セクションを編集
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'e', '<cmd>lua require("neo-slack.ui").edit_section_current()<CR>', opts)
  
  -- d: セクションを削除
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'd', '<cmd>lua require("neo-slack.ui").delete_section_current()<CR>', opts)
end

-- チャンネルを選択またはセクションの折りたたみ/展開
function M.select_channel_or_toggle_section()
  local line = vim.api.nvim_get_current_line()
  local line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- セクションヘッダーかどうかを判断（折りたたみマーク付き）
  if line:match('^## [▶▼]') then
    -- カスタムセクションのIDを取得
    local ok, section_id = pcall(vim.api.nvim_buf_get_var, bufnr, 'section_' .. line_nr)
    
    if ok and section_id then
      -- カスタムセクションの折りたたみ/展開
      M.toggle_section_collapse(section_id)
      return
    elseif line:match('★ スター付き') then
      -- スター付きセクションの折りたたみ/展開
      M.toggle_section_collapse('starred')
      return
    elseif line:match('チャンネル$') then
      -- チャンネルセクションの折りたたみ/展開
      M.toggle_section_collapse('channels')
      return
    end
  end
  
  -- セクションヘッダーでない場合はチャンネルを選択
  M.select_channel()
end

-- チャンネルを選択
function M.select_channel()
  local line = vim.api.nvim_get_current_line()
  local line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- チャンネルIDを直接取得（行番号から）
  local ok, channel_id = pcall(vim.api.nvim_buf_get_var, bufnr, 'channel_' .. line_nr)
  
  if ok and channel_id then
    -- チャンネル名を抽出（表示用）
    local channel_name = line:match('[#🔒]%s+([%w-_]+)')
    if not channel_name then
      channel_name = "選択したチャンネル"
    end
    
    notify(channel_name .. ' を選択しました', vim.log.levels.INFO)
    
    -- 状態に現在のチャンネルを設定
    state.set_current_channel(channel_id, channel_name)
    
    -- チャンネル選択イベントを発行
    events.emit('channel_selected', channel_id, channel_name)
    
    -- メッセージ一覧のウィンドウにフォーカス
    if is_valid_window(M.layout.messages_win) then
      vim.api.nvim_set_current_win(M.layout.messages_win)
    else
      -- メッセージウィンドウが無効な場合は、レイアウトを再設定
      M.setup_split_layout()
      if is_valid_window(M.layout.messages_win) then
        vim.api.nvim_set_current_win(M.layout.messages_win)
      end
    end
  else
    -- 従来の方法でチャンネル名を抽出（"unread_" または "read_" プレフィックスを考慮）
    local channel_name = line:match('[✓%s][#🔒]%s+([%w-_]+)')
    
    if not channel_name then
      notify('チャンネルを選択できませんでした', vim.log.levels.ERROR)
      return
    end
    
    -- チャンネル選択イベントを発行
    events.emit('channel_selected', channel_name, channel_name)
    
    -- メッセージ一覧のウィンドウにフォーカス
    if is_valid_window(M.layout.messages_win) then
      vim.api.nvim_set_current_win(M.layout.messages_win)
    else
      -- メッセージウィンドウが無効な場合は、レイアウトを再設定
      M.setup_split_layout()
      if is_valid_window(M.layout.messages_win) then
        vim.api.nvim_set_current_win(M.layout.messages_win)
      end
    end
  end
end

-- チャンネル一覧を表示
--- @param channels table[] チャンネルオブジェクトの配列
--- @return nil
function M.show_channels(channels)
  -- 分割レイアウトを設定
  M.setup_split_layout()
  
  -- バッファを作成または取得
  local bufnr = M.get_or_create_buffer('channels')
  M.layout.channels_buf = bufnr
  
  -- バッファを設定
  setup_buffer_options(bufnr, 'neo-slack-channels')
  
  -- セクションの折りたたみ状態を初期化（初回のみ）
  if not state.section_collapsed or not next(state.section_collapsed) then
    state.init_section_collapsed()
  end
  
  -- チャンネル一覧を整形
  local lines = {
    '# Slackチャンネル一覧',
    '',
  }
  
  -- チャンネルをセクションごとに分類
  local starred_channels = {}
  local normal_channels = {}
  local sectioned_channels = {}
  
  for _, channel in ipairs(channels) do
    local section_id = state.get_channel_section(channel.id)
    
    if state.is_channel_starred(channel.id) then
      table.insert(starred_channels, channel)
    elseif section_id then
      if not sectioned_channels[section_id] then
        sectioned_channels[section_id] = {}
      end
      table.insert(sectioned_channels[section_id], channel)
    else
      table.insert(normal_channels, channel)
    end
  end
  
  -- チャンネルをソート（それぞれのカテゴリ内でアルファベット順）
  local sort_func = function(a, b)
    return a.name < b.name
  end
  
  table.sort(starred_channels, sort_func)
  table.sort(normal_channels, sort_func)
  for _, channels_list in pairs(sectioned_channels) do
    table.sort(channels_list, sort_func)
  end
  
  -- スター付きチャンネルセクション
  if #starred_channels > 0 then
    -- 折りたたみ状態を表示
    local collapsed_mark = state.is_section_collapsed('starred') and '▶' or '▼'
    table.insert(lines, string.format('## %s ★ スター付き', collapsed_mark))
    
    -- 折りたたまれていない場合のみチャンネルを表示
    if not state.is_section_collapsed('starred') then
      for _, channel in ipairs(starred_channels) do
        local prefix = channel.is_private and '🔒' or '#'
        local member_status = channel.is_member and '✓' or ' '
        local has_unread = channel.unread_count and channel.unread_count > 0
        local unread = has_unread and string.format(' (%d)', channel.unread_count) or ''
        
        -- プレフィックスなしでチャンネル情報を表示
        table.insert(lines, string.format('%s %s %s%s', member_status, prefix, channel.name, unread))
        
        -- チャンネルIDを保存（後で使用）
        vim.api.nvim_buf_set_var(bufnr, 'channel_' .. #lines, channel.id)
      end
      
      -- セクション間の区切り
      table.insert(lines, '')
    end
  end
  
  -- カスタムセクション
  local sorted_sections = {}
  for id, section in pairs(state.custom_sections) do
    table.insert(sorted_sections, section)
  end
  table.sort(sorted_sections, function(a, b) return a.order < b.order end)
  
  for _, section in ipairs(sorted_sections) do
    local section_channels = sectioned_channels[section.id] or {}
    if #section_channels > 0 then
      -- 折りたたみ状態を表示
      local collapsed_mark = state.is_section_collapsed(section.id) and '▶' or '▼'
      table.insert(lines, string.format('## %s %s', collapsed_mark, section.name))
      
      -- セクションIDを保存（後で使用）
      vim.api.nvim_buf_set_var(bufnr, 'section_' .. #lines, section.id)
      
      -- 折りたたまれていない場合のみチャンネルを表示
      if not state.is_section_collapsed(section.id) then
        for _, channel in ipairs(section_channels) do
          local prefix = channel.is_private and '🔒' or '#'
          local member_status = channel.is_member and '✓' or ' '
          local has_unread = channel.unread_count and channel.unread_count > 0
          local unread = has_unread and string.format(' (%d)', channel.unread_count) or ''
          
          -- プレフィックスなしでチャンネル情報を表示
          table.insert(lines, string.format('%s %s %s%s', member_status, prefix, channel.name, unread))
          
          -- チャンネルIDを保存（後で使用）
          vim.api.nvim_buf_set_var(bufnr, 'channel_' .. #lines, channel.id)
        end
        
        -- セクション間の区切り
        table.insert(lines, '')
      end
    end
  end
  
  -- 通常のチャンネルセクション
  -- 折りたたみ状態を表示
  local collapsed_mark = state.is_section_collapsed('channels') and '▶' or '▼'
  table.insert(lines, string.format('## %s チャンネル', collapsed_mark))
  
  -- 折りたたまれていない場合のみチャンネルを表示
  if not state.is_section_collapsed('channels') then
    for _, channel in ipairs(normal_channels) do
      local prefix = channel.is_private and '🔒' or '#'
      local member_status = channel.is_member and '✓' or ' '
      local has_unread = channel.unread_count and channel.unread_count > 0
      local unread = has_unread and string.format(' (%d)', channel.unread_count) or ''
      
      -- プレフィックスなしでチャンネル情報を表示
      table.insert(lines, string.format('%s %s %s%s', member_status, prefix, channel.name, unread))
      
      -- チャンネルIDを保存（後で使用）
      vim.api.nvim_buf_set_var(bufnr, 'channel_' .. #lines, channel.id)
    end
  end
  
  -- バッファにラインを設定
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  
  -- キーマッピングを設定
  M.setup_channels_keymaps(bufnr)
  
  -- 左側のウィンドウにバッファを表示
  vim.api.nvim_win_set_buf(M.layout.channels_win, bufnr)
  
  -- チャンネル一覧のウィンドウにフォーカス
  vim.api.nvim_set_current_win(M.layout.channels_win)
end

-- イベントハンドラの登録
events.on('refresh_channels', function()
  -- チャンネル一覧を更新
  api.get_channels(function(success, channels)
    if success then
      -- 状態にチャンネル一覧を保存
      state.set_channels(channels)
      -- UIにチャンネル一覧を表示
      M.show_channels(channels)
    else
      notify('チャンネル一覧の取得に失敗しました', vim.log.levels.ERROR)
    end
  end)
end)

return M

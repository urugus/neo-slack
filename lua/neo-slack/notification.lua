-- neo-slack 通知モジュール
-- 新しいメッセージやメンションの通知を処理します

local api = require('neo-slack.api')

local M = {}

-- 通知設定
M.config = {
  enabled = true,
  refresh_interval = 30, -- 秒
  last_check = {},       -- チャンネルごとの最終チェック時間
  timer = nil,           -- タイマーオブジェクト
}

-- 通知システムの初期化
function M.setup(refresh_interval)
  M.config.refresh_interval = refresh_interval or 30
  
  -- 既存のタイマーを停止
  if M.config.timer then
    M.config.timer:stop()
    M.config.timer = nil
  end
  
  -- 通知が有効な場合、タイマーを開始
  if M.config.enabled then
    M.start_notification_timer()
  end
end

-- 通知タイマーを開始
function M.start_notification_timer()
  -- タイマーを作成
  M.config.timer = vim.loop.new_timer()
  
  -- 最初は5秒後に実行し、その後は指定された間隔で実行
  M.config.timer:start(5000, M.config.refresh_interval * 1000, vim.schedule_wrap(function()
    M.check_for_notifications()
  end))
  
  vim.notify('Neo-Slack: 通知システムを開始しました（更新間隔: ' .. M.config.refresh_interval .. '秒）', vim.log.levels.INFO)
end

-- 通知タイマーを停止
function M.stop_notification_timer()
  if M.config.timer then
    M.config.timer:stop()
    M.config.timer = nil
    vim.notify('Neo-Slack: 通知システムを停止しました', vim.log.levels.INFO)
  end
end

-- 通知をチェック
function M.check_for_notifications()
  -- ユーザー情報が取得できていない場合はスキップ
  if not api.config.user_info then
    return
  end
  
  -- チャンネル一覧を取得
  api.get_channels(function(success, channels)
    if not success then
      return
    end
    
    -- 参加しているチャンネルのみをチェック
    for _, channel in ipairs(channels) do
      if channel.is_member then
        M.check_channel_for_notifications(channel)
      end
    end
  end)
end

-- チャンネルの通知をチェック
function M.check_channel_for_notifications(channel)
  -- 最終チェック時間を取得
  local last_ts = M.config.last_check[channel.id] or 0
  
  -- チャンネルのメッセージを取得
  local params = {
    channel = channel.id,
    limit = 10,
    oldest = last_ts,
  }
  
  api.request('GET', 'conversations.history', params, function(success, data)
    if not success or not data.messages or #data.messages == 0 then
      return
    end
    
    -- 最新のタイムスタンプを更新
    local newest_ts = last_ts
    for _, message in ipairs(data.messages) do
      if tonumber(message.ts) > newest_ts then
        newest_ts = tonumber(message.ts)
      end
    end
    M.config.last_check[channel.id] = newest_ts
    
    -- 自分宛てのメッセージやメンションをチェック
    local user_id = api.config.user_info.user.id
    local notifications = {}
    
    for _, message in ipairs(data.messages) do
      -- 自分のメッセージはスキップ
      if message.user == user_id then
        goto continue
      end
      
      -- メンションをチェック
      local is_mentioned = false
      
      -- テキスト内のメンションをチェック
      if message.text and message.text:match('<@' .. user_id .. '>') then
        is_mentioned = true
      end
      
      -- メンション情報をチェック
      if message.blocks then
        for _, block in ipairs(message.blocks) do
          if block.elements then
            for _, element in ipairs(block.elements) do
              if element.elements then
                for _, sub_element in ipairs(element.elements) do
                  if sub_element.type == 'user' and sub_element.user_id == user_id then
                    is_mentioned = true
                  end
                end
              end
            end
          end
        end
      end
      
      -- DMをチェック
      if channel.is_im then
        is_mentioned = true
      end
      
      -- 通知を追加
      if is_mentioned then
        table.insert(notifications, {
          channel = channel,
          message = message,
        })
      end
      
      ::continue::
    end
    
    -- 通知を表示
    M.show_notifications(notifications)
  end)
end

-- 通知を表示
function M.show_notifications(notifications)
  if #notifications == 0 then
    return
  end
  
  for _, notification in ipairs(notifications) do
    local channel = notification.channel
    local message = notification.message
    
    -- ユーザー名を取得（簡略化）
    local username = message.user or 'unknown'
    -- 実際の実装では、APIからユーザー名を取得する必要があります
    
    -- チャンネル名
    local channel_name = channel.name or 'DM'
    if channel.is_im then
      channel_name = 'DM'
    end
    
    -- メッセージテキスト（短縮）
    local text = message.text or ''
    if #text > 50 then
      text = text:sub(1, 47) .. '...'
    end
    
    -- 通知メッセージ
    local notify_message = string.format(
      '[%s] %s: %s',
      channel_name,
      username,
      text
    )
    
    -- 通知を表示
    vim.notify(notify_message, vim.log.levels.INFO, {
      title = 'Neo-Slack',
      icon = '💬',
    })
  end
end

-- 通知を有効化
function M.enable()
  M.config.enabled = true
  M.setup(M.config.refresh_interval)
  vim.notify('Neo-Slack: 通知を有効化しました', vim.log.levels.INFO)
end

-- 通知を無効化
function M.disable()
  M.config.enabled = false
  M.stop_notification_timer()
  vim.notify('Neo-Slack: 通知を無効化しました', vim.log.levels.INFO)
end

-- 通知の状態を切り替え
function M.toggle()
  if M.config.enabled then
    M.disable()
  else
    M.enable()
  end
end

return M
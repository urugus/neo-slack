" Vim syntax file
" Language: Neo-Slack Channels
" Maintainer: Neo-Slack Developer
" Latest Revision: 2025-04-06

if exists("b:current_syntax")
  finish
endif

" チャンネル一覧のヘッダー
syntax match neoSlackChannelsHeader /^# .*$/

" チャンネル情報
syntax match neoSlackChannelPublic /^. # .*$/
syntax match neoSlackChannelPrivate /^. 🔒 .*$/
syntax match neoSlackChannelJoined /^✓ [#🔒] .*$/
syntax match neoSlackChannelUnread /([0-9]\+)$/

" ハイライトの定義
highlight default link neoSlackChannelsHeader Title
highlight default link neoSlackChannelPublic Identifier
highlight default link neoSlackChannelPrivate Special
highlight default link neoSlackChannelJoined Statement
highlight default link neoSlackChannelUnread Number

let b:current_syntax = "neo-slack-channels"
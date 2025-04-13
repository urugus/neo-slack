" Vim syntax file
" Language: Neo-Slack.nvim Channels
" Maintainer: Neo-Slack.nvim Developer
" Latest Revision: 2025-04-13

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

" 未読/既読状態 - チャンネル全体で区別
syntax match neoSlackChannelUnreadState /^. [#🔒] .*([0-9]\+)$/
syntax match neoSlackChannelReadState /^. [#🔒] .*[^)]$/

" ハイライトの定義
highlight default link neoSlackChannelsHeader Title
highlight default link neoSlackChannelPublic Identifier
highlight default link neoSlackChannelPrivate Special
highlight default link neoSlackChannelJoined Statement
highlight default link neoSlackChannelUnread Number

" 未読/既読状態のハイライト
highlight default neoSlackChannelUnreadState term=bold cterm=bold gui=bold
highlight default neoSlackChannelReadState ctermfg=242 guifg=#6c6c6c

let b:current_syntax = "neo-slack-nvim-channels"
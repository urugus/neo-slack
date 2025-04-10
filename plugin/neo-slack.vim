" neo-slack.vim - Neovim用Slackプラグイン
" Maintainer: Neo-Slack開発者
" Version: 0.1.0

if exists('g:loaded_neo_slack') || &cp || v:version < 700
  finish
endif
let g:loaded_neo_slack = 1

" コマンド定義
command! -nargs=0 SlackStatus lua require('neo-slack').status()
command! -nargs=0 SlackChannels lua require('neo-slack').list_channels()
command! -nargs=? SlackMessages lua require('neo-slack').list_messages(<f-args>)
command! -nargs=+ SlackSend lua require('neo-slack').send_message(<f-args>)
command! -nargs=+ SlackReply lua require('neo-slack').reply_message(<f-args>)
command! -nargs=+ SlackReact lua require('neo-slack').add_reaction(<f-args>)
command! -nargs=+ SlackUpload lua require('neo-slack').upload_file(<f-args>)
command! -nargs=0 SlackDeleteToken lua require('neo-slack').delete_token()
command! -nargs=? SlackSetToken lua require('neo-slack').prompt_for_token()
command! -nargs=0 SlackResetToken lua require('neo-slack').reset_token()

" デフォルト設定
let g:neo_slack_token = get(g:, 'neo_slack_token', '')
let g:neo_slack_default_channel = get(g:, 'neo_slack_default_channel', 'general')
let g:neo_slack_refresh_interval = get(g:, 'neo_slack_refresh_interval', 30)
let g:neo_slack_notification = get(g:, 'neo_slack_notification', 1)

" キーマッピング（ユーザーが設定していない場合のデフォルト）
if !exists('g:neo_slack_disable_default_mappings') || !g:neo_slack_disable_default_mappings
  nnoremap <silent> <leader>ss :SlackStatus<CR>
  nnoremap <silent> <leader>sc :SlackChannels<CR>
  nnoremap <silent> <leader>sm :SlackMessages<CR>
endif
" プラグインの初期化
" 自動初期化はデフォルトで無効化（循環参照エラーを避けるため）
" ユーザーは明示的に :SlackSetup コマンドを実行する必要があります

" 手動初期化用コマンド
command! -nargs=0 SlackSetup lua require('neo-slack').setup()
" 自動初期化は VimEnter イベントで行うため、ここでは実行しない
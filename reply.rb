# coding:utf-8

require './bot.rb'
require 'pp'

bot = Bot.new

# bot.client.update("おはよ")
# pp bot.client.mentions
bot.timeline.userstream do |status|

  twitter_id = status.user.screen_name
  name = status.user.name
  contents = status.text
  status_id = status.id

  # リツイート以外を取得
  if !contents.index("RT")
    str_time = Time.now.strftime("[%Y-%m-%d %H:%M]")

    # botを呼び出す(他人へのリプを無視)
    if !(/^@\w*/.match(contents))
      if contents =~ /おーい/
        text = "はい\n#{str_time}"
        bot.post(text, twitter_id, status_id)
      end
    end

    # 自分へのリプであれば
    if contents =~ /^@qitter_bot\s*/
      # if contents =~ /やっほー/
        text = "こんにちわ#{str_time}"
        bot.post(text, twitter_id, status_id)
      # end
    end
  end
  # sleep 2
end

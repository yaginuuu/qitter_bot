# coding: utf-8
#
# Twitterのbotを簡単（当社比）に作れるかもしれない君
# 使うにはGemのTwitterライブラリが必要です
# 割とデバッグしてないです
#

require 'yaml'
require 'twitter'

module RTwBot
  #
  # 設定ファイルからインスタンス作成
  #
  def self.load(filename, &block)
    # 設定ファイルの読み込み
    config = nil
    File.open(filename, 'r') {|f| config = YAML.load(f.read)}
    # インスタンスの作成
    bot = Bot.new(config)
    # ブロックがない場合はインスタンスを返す
    return bot unless block
    # インスタンスの実行
    bot.instance_eval(&block)
    bot.post_stack
    bot.save_data.save
    nil
  end
  ##
  ## Botクラス
  ##
  class Bot
    #
    # 生成
    #
    def initialize(config)
      @now = Time.now
      @client = Twitter::Client.new(
        :consumer_key => config['consumer_key'],
        :consumer_secret => config['consumer_key_secret'],
        :oauth_token => config['access_token'],
        :oauth_token_secret => config['access_token_secret'],
      )
      @max_page     = config['max_page'].to_s.empty? ? 1 : config['max_page'].to_i
      @testmode     = config['testmode'].to_i > 0
      @tweet_footer = config['footer'].to_s
      @tweet_select = []
      @tweet_stack  = []
      # セーブデータ読み込み
      @save_data = SaveData.load(config['savefile'])
      unless @save_data.my_id
        if t = @client.user_timeline('count' => 1)
          @save_data.my_id = t.first.user.id
        end
      end
    end
    attr_reader   :tweet_stack
    attr_accessor :save_data
    #
    # 自分からのTweet
    #
    def own(&block)
      clear_select
      Bot.change_method(&block).bind(self).call
      if determine_select
        @save_data.last_own_time = Time.now
      end
    end
    #
    # Timelineへの反応
    #
    def tl(&block)
      tweets = []
      page = 1
      while true
        # TLから取得
        t = @client.home_timeline(
          'since_id' => @save_data.last_check_tl,
          'page' => page,
          'include_rts' => false,
        )
        break if t.empty?
        # 自分のツイートは破棄
        t.reject!{|x| x.user.id == @save_data.my_id}
        # reply(@付き)は破棄
        t.reject!{|x| x.text.index("@")}
        # 配列に追加
        tweets += t
        break if page >= @max_page
        page += 1
      end
      if tweets.size > 0
        @save_data.last_check_tl = tweets.first.id
        if tl_reply(tweets.reverse, &block)
          @save_data.last_tl_time = Time.now
        end
      end
    end
    #
    # Replyへの反応
    #
    def reply(&block)
      tweets = []
      page = 1
      while true
        # mentionsから取得
        t = @client.mentions(
          'since_id' => @save_data.last_check_reply,
          'page' => page,
          'include_rts' => false,
        )
        break if t.empty?
        # 自分のツイートは破棄
        t.reject!{|x| x.user.id == @save_data.my_id}
        # 配列に追加
        tweets += t
        break if page >= @max_page
        page += 1
      end
      if tweets.size > 0
        @save_data.last_check_reply = tweets.first.id
        if tl_reply(tweets.reverse, &block)
          @save_data.last_reply_time = Time.now
        end
      end
    end
    #
    # TL/Replyへの反応
    #
    def tl_reply(tweets, &block)
      result = false
      method = Bot.change_method(&block)
      tweets.each do |tweet|
        clear_select
        method.bind(self).call(tweet)
        t = determine_select
        if t
          result = true
          t[1][:in_reply_to_status_id] = tweet.id
          t[1][:reply_to] = tweet.user.screen_name unless t[1][:reply_to]
        end
      end
      result
    end
    #
    # ツイート候補の追加
    #
    def add_select(str, options ={})
      @tweet_select.push([str, options])
    end
    alias add add_select
    #
    # ツイート候補の決定
    #
    def determine_select
      tweet = @tweet_select.shuffle.first
      @tweet_stack.push tweet if tweet
      tweet
    end
    #
    # ツイート候補の削除
    #
    def clear_select
      @tweet_select.clear
    end
    #
    # ツイート
    #
    def post_stack
      return if @tweet_stack.empty?
      @tweet_stack.each do |tweet|
        text   = tweet[0].to_s
        option = tweet[1]
        next if text.empty?
        str = "#{option[:reply_to].to_s.size > 0 ? "@#{option[:reply_to]} " : ''}#{text}#{@tweet_footer}"
        puts "[tweet]#{str}"
        next if @testmode
        begin
          @client.update(
            str,
            'in_reply_to_status_id' => option[:in_reply_to_status_id].to_s
          )
        rescue => e
          puts "#{$!} - #{$@}"
        end
      end
      save_data.last_post_time = Time.now
    end
    #
    # ツイートスタックの削除
    #
    def clear_stack
      @tweet_stack.clear
    end
    #
    # フォローする
    #
    def follow(screen_name)
      @client.follow(screen_name)
    end
    #
    # 年が範囲内か？
    #
    def year?(date_str)
      date_str = date_str.to_s
      if date_str =~ /^(\d+)(?:〜|から|to|-)(\d+)$/
        return ($1.to_i <= @now.year and @now.year <= $2.to_i)
      elsif date_str =~ /^(\d+)$/
        return @now.year == $1.to_i
      end
      false
    end
    #
    # 日付が範囲内か？
    #
    def day?(date_str)
      if date_str =~ /^(\d+)\/(\d+)(?:〜|から|to|-)(\d+)\/(\d+)$/
        s_month = $1.to_i
        s_day   = $2.to_i
        e_month = $3.to_i
        e_day   = $4.to_i
        s_time = Time.local(@now.year, s_month, s_day, @now.hour, @now.min, @now.sec)
        e_time = Time.local(@now.year, e_month, e_day, @now.hour, @now.min, @now.sec)
        if s_time <= e_time
          return (s_time <= @now and @now <= e_time)
        else
          return (@now < e_time + 1 or s_time <= @now)
        end
      elsif date_str =~ /^(\d+)\/(\d+)$/
        month = $1.to_i
        day   = $2.to_i
        return (@now.month == month and @now.day == day)
      end
      false
    end
    #
    # 現在時間が範囲内か？
    #
    def time?(date_str)
      if date_str =~ /^(\d+):(\d+)(?:〜|から|to|-)(\d+):(\d+)$/
        s_hour = $1.to_i
        s_min  = $2.to_i
        e_hour = $3.to_i
        e_min  = $4.to_i
        s_time = Time.local(@now.year, @now.month, @now.day, s_hour, s_min, @now.sec)
        e_time = Time.local(@now.year, @now.month, @now.day, e_hour, e_min, @now.sec)
        if s_time <= e_time
          return (s_time <= @now and @now <= e_time)
        else
          return (@now < e_time + 1 or s_time <= @now)
        end
      elsif date_str =~ /^(\d+):(\d+)$/
        hour = $1.to_i
        min  = $2.to_i
        return (@now.hour == hour and @now.min == min)
      end
      false
    end
    #
    # ブロックをメソッドに変換
    #
    def self.change_method(&block)
      name = "tmp_#{Time.now}_#{rand}"
      define_method(name, &block)
      method = instance_method(name)
      remove_method(name)
      method
    end
  end
  ##
  ## botの記憶領域
  ##
  class SaveData
    #
    # ファイルから読み込み
    # ファイルが無いときは生成
    #
    def self.load(filename)
      if File.exist?(filename)
        loaddata = nil
        File.open(filename, 'r') {|f| loaddata = YAML.load(f.read)}
        return loaddata if loaddata.class == RTwBot::SaveData
      end
      SaveData.new(filename)
    end
    #
    # 生成
    #
    def initialize(filename)
      @filename = filename
      @data = {}
      @last_post_time  = Time.at(0)
      @last_own_time   = Time.at(0)
      @last_tl_time    = Time.at(0)
      @last_reply_time = Time.at(0)
      @last_check_tl    = 1
      @last_check_reply = 1
      @my_id            = nil
    end
    attr_accessor :last_post_time
    attr_accessor :last_own_time
    attr_accessor :last_tl_time
    attr_accessor :last_reply_time
    attr_accessor :last_check_tl
    attr_accessor :last_check_reply
    attr_accessor :my_id
    #
    # 保存
    #
    def save
      File.open(@filename, 'w') do |file|
        file.write self.to_yaml
      end
    end
    #
    # データの読み込み
    #
    def [](key)
      @data[key]
    end
    #
    # データの書き込み
    #
    def []=(key, value)
      @data[key] = value
    end
  end
end
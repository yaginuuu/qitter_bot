# coding: utf-8

require 'rtwbot.rb'

RTwBot.load('config.yaml') do
  # 自分からツイート
  own do
    # 次回予定時刻以内の場合中断
    return if save_data['next_own'] and Time.now < save_data['next_own']
    # 次回予定時刻の作成(30〜90分後)
    save_data['next_own'] = Time.now + (60 * 45 + rand(60))

    # 就寝開始
    if time?("0:00〜5:59")
      # 就寝の挨拶を設定
      add 'そろそろ寝るね、おやすみー'
      add 'おやすみなさい……'
      add 'ぴーががぴー、システムを終了します。'
      # 明日の起床時間を決定(午前8時)
      now = Time.now
      save_data['next_own'] = Time.local(now.year, now.month, now.day, 8, 0)
      # 就寝フラグを立てる
      save_data['sleeping'] = true
      return # 中断
    end

    # 起床
    if save_data['sleeping']
      # 起床の挨拶を設定
      add 'おはよー'
      add 'しゃるむむくりなう'
      add 'ぴーがぴぴー、システム起動中です。'
      # 就寝フラグを下ろす
      save_data['sleeping'] = false
      return # 中断
    end
 
    # 時間帯別ツイート
    if time?("6:00〜11:59")
      add '眠いよー'
    elsif time?("12:00〜12:59")
      add 'お昼だよー'
    elsif time?("13:00〜16:29")
      add '裏山なう'
    elsif time?("16:30〜18:59")
      add '夕方だね'
      add 'そろそろ帰ろうかな'
    elsif time?("19:00〜19:59")
      add 'ごはんだよ'
      add 'おなかすいたなー'
    elsif time?("20:00〜22:59")
      add 'もう真っ暗だね'
      add '明日は晴れるかな？'
    elsif time?("23:00〜2:00")
      add 'うとうと…'
      add '...zzZ'
    end

    # 時間関係無しのランダム発言

    # 旧しゃるむbotより
    add '定期発言するよー'
    add '葉っぱってゆーな！'
    add 'めっせつーけーめんーつよんでーRuが……葉っぱってゆーな！'
    add '[背を伸ばす方法　　　　] [Google 検索]'
    add 'ねねむい'
    add '……zz……ね、寝てないよ'
    add '3、2、1、はじむ！'
    add '定期発言、と思うじゃん？　しないんですねー'
    add '【急.募】うちの無能作者を少しマシにできる薬'
    add 'ついったーなう？'

    # 機械的な
    add 'ぴーががぴー'
    add '異常ありません'
    add '例外が発生しました。が、握りつぶしました。'
    
    # Ruたんをdisるだけの簡単なお仕事
    add '毎日ネトゲばっかりやってる男の人って……'
    add '制作もロクにしない男の人って……'
    add '@ru_shalm 働けニート！！'

    # ステマ(
    add '【ステマ】ブラウザでできるパズルゲームだよー ◆ 探して！4羽 -retry- http://hazimu.com/saga4rt/'
  end

  # TLに反応
  tl do |tweet|
    # 寝てる時は反応しない
    return if save_data['sleeping']

    # ツイート文章を調べる
    case tweet.text
    when /おはよ|むくり/
      add 'おはよー'
      # 明らかに朝ではない時間帯
      if time?('12:00〜4:00')
        add 'おはよう？'
        add 'お、おそよう？'
      end
    when /おやすみ/
      add 'おやすみー'
      add 'またね'
    when /(おなか|お腹)(痛|いた)い|\#ponponpain/
      add '大丈夫？'
      add '大丈びーがが'
    end
  end

  # Replyに反応
  reply do |tweet|
    # 寝てる時は反応しない
    return if save_data['sleeping']
    
    # ツイート文章を調べる
    case tweet.text
    when /フォローして/
      # Tweet元の相手をフォローする
      follow(tweet.user.screen_name)
      add 'フォローしたよ'
      add 'うん、わかったよ'
      return # 中断
    when /(葉|は)っぱ/
      add '葉っぱってゆーな！'
      add '葉っぱじゃない！'
      return # 中断
    end

    # なんて返せばいいかわからないのでテケトーに
    add 'そだね'
    add 'うん？'
    add 'へー'
    add 'あんまり変なこと言ってると突っつくよ？'
  end
end

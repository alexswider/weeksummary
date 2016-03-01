require 'httparty'
require 'sinatra'
require 'pry'
set :haml, :escape_html => true

tokens = File.read("tokens.txt").lines
binding.pry
get "/" do
	haml :index
end

post "/summary" do
	template = ";;;;;;;\nDate;Platform;Post Copy;Comments;Likes;Shares;Retweets;Engagement\n"
	more = true
	first = true
	lrts = 0
	mrts = 0
	lfavs = 0
	mfavs = 0
	mtext = ""
	ltext = ""
	mdate = ""
	ldate = ""
	max_id = ""
	kek = params[:boundary][:hi].scan(/\d+/)
	hi = Time.new(kek.last, kek[1], kek[0])
	kek = params[:boundary][:low].scan(/\d+/)
	low = Time.new(kek.last, kek[1], kek[0])
	while more
		tweets = HTTParty.get("https://api.twitter.com/1.1/statuses/user_timeline.json?include_rts=false&count=200&screen_name=#{params[:twitter]}#{max_id}", :headers => {"Authorization" => "Bearer " + tokens[0].chop})
		tweets.each do |tweet|
			ary = tweet["created_at"].split
			date = Time.new(ary.last, ary[1], ary[2])
			next if date > hi
			if date < low
				more = false
				break
			end
			favorites = tweet["favorite_count"].nil?? 0 : tweet["favorite_count"]
			retweets = tweet["retweet_count"].nil?? 0 : tweet["retweet_count"]
			text = tweet["text"].gsub("\n", " ").slice(0,40).gsub("\"", "\"\"").delete(";").rstrip
			max_id = "&max_id=#{tweet["id"]}"
			if first
				lrts = retweets
				mrts = lrts
				mfavs = favorites
				lfavs = mfavs
				mtext = String.new(text)
				ltext = String.new(text)
				first = false
			else
				if favorites + retweets > mrts + mfavs
					mrts = retweets
					mfavs = favorites
					mtext = String.new(text)
					mdate = date.strftime("%d %b")
				end
				if favorites + retweets < lrts + lfavs
				lrts = retweets
				lfavs = favorites
				ltext = String.new(text)
				ldate = date.strftime("%d %b")
				end
			end
			template << date.strftime("%d %b %y;") << "Twitter;" << text << ";;#{favorites};;#{retweets};#{favorites + retweets}\n"
		end
	end
	posts = eval(HTTParty.get("https://graph.facebook.com/abstrachujetv/posts?fields=message,created_time,shares,comments.limit(1).summary(true),likes.limit(1).summary(true)&access_token=" + tokens[1].chop))
	posts[:data].each do |post|
		ary = post[:created_time].scan(/\d+/)
		date = Time.new(ary[0], ary[1], ary[2])
		next if date > hi
		break if date < low
		text = post[:message].gsub("\n", " ").slice(0,40).gsub("\"", "\"\"").delete(";").rstrip
		likes = post[:likes][:summary][:total_count]
		comments = post[:comments][:summary][:total_count]
		shares = post[:shares][:count]
		template << date.strftime("%d %b %y;") << "Facebook;" << text << ";#{comments};#{likes};#{shares};;#{likes + comments + shares}\n"
	end
	filename = "dw/#{params[:twitter] << low.day.to_s << "-" << hi.day.to_s << hi.strftime("%b")}.csv"
	File.write(filename, template.prepend("Twitter summary;;The #{mdate} post " + mtext + " was the top performing post (#{mrts + mfavs} total engagements) with #{mrts} retweets and #{mfavs} likes. The #{ldate} post "  + ltext + " was the lowest performing post (#{lrts + lfavs} total engagements) with #{lrts} retweets and #{lfavs} likes.;;;;;\n"))
	send_file(filename, :filename => (low.strftime("%d") << "-" << hi.strftime("%d") << hi.strftime("%b") << "_summary"))
end

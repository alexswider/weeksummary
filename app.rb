require 'httparty'
require 'sinatra'
require 'json'
set :haml, :escape_html => true

tokens = File.read("tokens.txt").lines
get "/" do
	haml :index
end

post "/summary" do
	if params[:boundary][:hi].empty? or params[:boundary][:low].empty?
		return "You must provide a time span"
	end
	summary = [";;;;;;;\r\nDate;Platform;Post Copy;Link attached;Comments;Likes;Shares;Retweets;Engagement\r\n"]
	all_posts = []
	more = true
	first = true
	lrts = 0
	mrts = 0
	lfavs = 0
	mfavs = 0
	mtext = ""
	ltext = ""
	mcomm = 0
	lcomm = 0
	mdate = ""
	ldate = ""
	max_id = ""
	next_page = ""
	kek = params[:boundary][:hi].scan(/\d+/)
	hi = Time.new(kek.last, kek[0], kek[1])
	kek = params[:boundary][:low].scan(/\d+/)
	low = Time.new(kek.last, kek[0], kek[1])
	if low > hi
		kek = hi
		hi = low
		low = kek
	end
	unless params[:fb].size == 0
		while more
			query =	first ? "https://graph.facebook.com/#{params[:fb]}/posts?fields=message,link,created_time,shares,comments.limit(1).summary(true),likes.limit(1).summary(true)&access_token=" + tokens[1].chop : next_page
			posts = HTTParty.get(query, :headers => {'Accept' => 'application/json'})
			next_page = posts["paging"]["next"]
			posts["data"].each do |post|
				ary = post["created_time"].scan(/\d+/)
				date = Time.new(ary[0], ary[1], ary[2])
				next if date > hi
				if date < low
					more = false
					break
				end
				if post["message"]
					text = post["message"].gsub("\n", " ").gsub("\"", "\"\"").delete(";").rstrip
				else
					text = ""
				end
				likes = post["likes"]["summary"]["total_count"]
				comments = post["comments"]["summary"]["total_count"]
				shares = post["shares"]? post["shares"]["count"] : 0
				link = post["link"]? post["link"] : ""
				if first
					mrts = shares
					lrts = shares
					mfavs = likes
					lfavs = likes
					lcomm = comments
					mcomm = comments
					mdate = date.strftime("%d %b")
					ldate = date.strftime("%d %b")
					mtext = String.new(text)
					ltext = String.new(text)
					first = false
				else
					if likes + comments + shares > mfavs + mcomm + mrts
						mfavs = likes
						mcomm = comments
						mrts = shares
						mdate = date.strftime("%d %b")
						mtext = String.new(text)
					else
						if likes + comments + shares < lfavs + lcomm + lrts
							lfavs = likes
							lcomm = comments
							lrts = shares
							ldate = date.strftime("%d %b")
							ltext = String.new(text)
						end
					end
				end
				all_posts << (date.strftime("%d %b %y;") << "Facebook;" << text << ";#{link};#{comments};#{likes};#{shares};;#{likes + comments + shares}\r\n")
			end
		end
		summary.insert(0, ("Facebook summary;;The #{mdate} post " + mtext + " was the top performing post (#{mrts + mfavs + mcomm} total engagements) with #{mfavs} likes, #{mcomm} comments and #{mrts} shares. The #{ldate} post "  + ltext + " was the lowest performing post (#{lrts + lfavs + lcomm} total engagements) with #{lfavs} likes, #{lcomm} comments and #{lrts} shares.;;;;;\r\n"))
	end
	unless params[:twitter].size == 0
		more = true
		first = true
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
				text = tweet["text"].gsub("\n", " ").gsub("\"", "\"\"").delete(";").rstrip
				link = tweet["entities"]["urls"].empty?? "" : tweet["entities"]["urls"].first["expanded_url"]
				max_id = "&max_id=#{tweet["id"]}"
				if first
					lrts = retweets
					mrts = lrts
					mfavs = favorites
					lfavs = mfavs
					mtext = String.new(text)
					ltext = String.new(text)
					mdate = date.strftime("%d %b")
					ldate = date.strftime("%d %b")
					first = false
				else
					if favorites + retweets > mrts + mfavs
						mrts = retweets
						mfavs = favorites
						mtext = String.new(text)
						mdate = date.strftime("%d %b")
					else
						if favorites + retweets < lrts + lfavs
							lrts = retweets
							lfavs = favorites
							ltext = String.new(text)
							ldate = date.strftime("%d %b")
						end
					end
				end
				all_posts << (date.strftime("%d %b %y;") << "Twitter;" << text << ";" << link << ";;#{favorites};;#{retweets};#{favorites + retweets}\r\n")
			end
		end
	summary.insert(0, ("Twitter summary;;The #{mdate} post " + mtext + " was the top performing post (#{mrts + mfavs} total engagements) with #{mrts} retweets and #{mfavs} likes. The #{ldate} post "  + ltext + " was the lowest performing post (#{lrts + lfavs} total engagements) with #{lrts} retweets and #{lfavs} likes.;;;;;\r\n"))
	end
	unless params[:insta].empty?
		first = true
		media = JSON.parse(%x`instagram-screen-scrape -u #{params[:insta]}`)
		media.each do |post|
			date = Time.at(post["time"])
			date = Time.new(date.year, date.month, date.day)
			next if date > hi
			break if date < low
			comments = post["comment"]
			likes = post["like"]
			text = post["text"]? post["text"].gsub("\n", " ").gsub("\"", "\"\"").delete(";").rstrip : ""
			if first
				mfavs = likes
				lfavs = likes
				mcomm = comments
				lcomm = comments
				mtext = String.new(text)
				ltext = String.new(text)
				mdate = date.strftime("%d %b")
				ldate = date.strftime("%d %b")
				first = false
			else
				if likes + comments > mcomm + mfavs
					mfavs = likes
					mtext = String.new(text)
					mdate = date.strftime("%d %b")
				else
					if likes + comments < lcomm + lfavs
						lfavs = likes
						lcomm = comments
						ltext = String.new(text)
						ldate = date.strftime("%d %b")
					end
				end
			end
			all_posts << (date.strftime("%d %b %y;") << "Instagram;" << text << ";;#{comments};#{likes};;;#{likes + comments}\r\n")
		end
		summary.insert(0, ("Instagram summary;;The #{mdate} post " + mtext + " was the top performing post (#{mfavs + mcomm} total engagements) with #{mfavs} likes and #{mcomm} comments. The #{ldate} post "  + ltext + " was the lowest performing post (#{lfavs + lcomm} total engagements) with #{lfavs} likes and #{lcomm} comments.;;;;;\r\n"))
	end
	filename = "dw/#{params[:twitter] << low.day.to_s << "-" << hi.day.to_s << hi.strftime("%b")}.csv"
	all_posts.sort! do |a, b|
		one = a[0..8].split
		two = b[0..8].split
		Time.new("20#{two[2]}", two[1], two[0]) <=> Time.new("20#{one[2]}", one[1], one[0])
	end
	File.write(filename, summary.join << all_posts.join)
	send_file(filename, :filename => (low.strftime("%d") << "-" << hi.strftime("%d") << hi.strftime("%b") << "_summary.csv"))
end

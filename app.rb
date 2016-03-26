require 'nokogiri'
require 'open-uri'
require 'httparty'
require 'sinatra'
require 'json'
require 'tilt/haml'
set :haml, :escape_html => true
set :environment, :production

tokens = File.read("tokens.txt").lines
get "/" do
	haml :index
end

post "/summary" do
	def week_of date
		kek = date
		date += 86400 until date.sunday?
		kek -= 86400 until kek.monday?
		return "%02d" % (kek.day) + date.strftime("-%b-%d")
	end
	if params[:boundary][:hi].empty? or params[:boundary][:low].empty?
		return "You must provide a time span"
	end
	min = Hash.new("")
	max = Hash.new("")
	summary = [";;;;;;;;;\r\nWeek of;Date;Platform;Post Copy;Link to post;Link/video attached;Video views;Comments;Likes;Shares;Retweets;Engagement\r\n"]
	all_posts = []
	more = true
	first = true
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
	unless params[:fb].empty?
		while more
			query =	first ? "https://graph.facebook.com/#{params[:fb]}/posts?fields=message,link,created_time,shares,comments.limit(1).summary(true),likes.limit(1).summary(true)&access_token=" + tokens[1].chop : next_page
			posts = HTTParty.get(query, :headers => {'Accept' => 'application/json'})
			next_page = posts["paging"]? posts["paging"]["next"] : ""
			if posts["paging"]
				if posts["paging"]["next"].nil?
					more = false
					next_page = ""
				else
					next_page = posts["paging"]["next"]
				end
			end
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
				text = "\"#{text}\"" if text.include? (",")
				likes = post["likes"]["summary"]["total_count"]
				comments = post["comments"]["summary"]["total_count"]
				shares = post["shares"]? post["shares"]["count"] : 0
				link = post["link"]? post["link"] : ""
				views = ""
				if link.include? "videos"
					views = Nokogiri::HTML(open(link)).css('div.fbPhotosMediaInfo > span.fcg')[2].text[/[^a-zA-Z]+/].strip
				end
				if first
					max[:rts] = shares
					min[:rts] = shares
					max[:favs] = likes
					min[:favs] = likes
					min[:comments] = comments
					max[:comments] = comments
					max[:date] = date.strftime("%d %b")
					min[:date] = date.strftime("%d %b")
					max[:text] = String.new(text)
					min[:text] = String.new(text)
					first = false
				else
					if likes + comments + shares > max[:favs] + max[:comments] + max[:rts]
						max[:favs] = likes
						max[:comments] = comments
						max[:rts] = shares
						max[:date] = date.strftime("%d %b")
						max[:text] = String.new(text)
					else
						if likes + comments + shares < min[:favs] + min[:comments] + min[:rts]
							min[:favs] = likes
							min[:comments] = comments
							min[:rts] = shares
							min[:date] = date.strftime("%d %b")
							min[:text] = String.new(text)
						end
					end
				end
				all_posts << (week_of(date) << date.strftime(";%d %b %y;") << "Facebook;" << text << ";http://facebook.com/#{params[:fb]}/posts/#{post["id"].scan(/\d+/).last};#{link};#{views};#{comments};#{likes};#{shares};;#{likes + comments + shares}\r\n")
			end
		end
		summary.insert(0, ("Facebook summary;;;The #{max[:date]} post " + max[:text] + " was the top performing post (#{max[:rts] + max[:favs] + max[:comments]} total engagements) with #{max[:favs]} likes, #{max[:comments]} comments and #{max[:rts]} shares. The #{min[:date]} post "  + min[:text] + " was the lowest performing post (#{min[:rts] + min[:favs] + min[:comments]} total engagements) with #{min[:favs]} likes, #{min[:comments]} comments and #{min[:rts]} shares.;;;;;;\r\n")) unless first
	end
	unless params[:twitter].empty?
		more = true
		first = true
		while more
			tweets = HTTParty.get("https://api.twitter.com/1.1/statuses/user_timeline.json?include_rts=true&count=200&screen_name=#{params[:twitter]}#{max_id}", :headers => {"Authorization" => "Bearer " + tokens[0].chop})
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
				text = "\"#{text}\"" if text.include? (",")
				if first
					min[:rts] = retweets
					max[:rts] = retweets
					max[:favs] = favorites
					min[:favs] = favorites
					max[:text] = String.new(text)
					min[:text] = String.new(text)
					max[:date] = date.strftime("%d %b")
					min[:date] = date.strftime("%d %b")
					first = false
				else
					if favorites + retweets > max[:rts] + max[:favs]
						max[:rts] = retweets
						max[:favs] = favorites
						max[:text] = String.new(text)
						max[:date] = date.strftime("%d %b")
					else
						if favorites + retweets < min[:rts] + min[:favs]
							min[:rts] = retweets
							min[:favs] = favorites
							min[:text] = String.new(text)
							min[:date] = date.strftime("%d %b")
						end
					end
				end
				all_posts << (week_of(date) << date.strftime(";%d %b %y;") << "Twitter;" << text << ";http://twitter.com/#{params[:twitter]}/status/#{tweet["id"]};" << link << ";;;#{favorites};;#{retweets};#{favorites + retweets}\r\n")
			end
		end
	summary.insert(0, ("Twitter summary;;;The #{max[:date]} post " + max[:text] + " was the top performing post (#{max[:rts] + max[:favs]} total engagements) with #{max[:rts]} retweets and #{max[:favs]} likes. The #{min[:date]} post "  + min[:text] + " was the lowest performing post (#{min[:rts] + min[:favs]} total engagements) with #{min[:rts]} retweets and #{min[:favs]} likes.;;;;;;\r\n")) unless first
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
			text = "\"#{text}\"" if text.include? (",")
			if first
				max[:favs] = likes
				min[:favs] = likes
				max[:comments] = comments
				min[:comments] = comments
				max[:text] = String.new(text)
				min[:text] = String.new(text)
				max[:date] = date.strftime("%d %b")
				min[:date] = date.strftime("%d %b")
				first = false
			else
				if likes + comments > max[:comments] + max[:favs]
					max[:favs] = likes
					max[:text] = String.new(text)
					max[:date] = date.strftime("%d %b")
				else
					if likes + comments < min[:comments] + min[:favs]
						min[:favs] = likes
						min[:comments] = comments
						min[:text] = String.new(text)
						min[:date] = date.strftime("%d %b")
					end
				end
			end
			all_posts << (week_of(date) << date.strftime(";%d %b %y;") << "Instagram;" << text << "http://instagram.com/p/#{post["id"]};;;#{comments};#{likes};;;#{likes + comments}\r\n")
		end
		summary.insert(0, ("Instagram summary;;;The #{max[:date]} post " + max[:text] + " was the top performing post (#{max[:favs] + max[:comments]} total engagements) with #{max[:favs]} likes and #{max[:comments]} comments. The #{min[:date]} post "  + min[:text] + " was the lowest performing post (#{min[:favs] + min[:comments]} total engagements) with #{min[:favs]} likes and #{min[:comments]} comments.;;;;;;\r\n")) unless first
	end
	filename = "dw/#{params[:twitter] << low.day.to_s << "-" << hi.day.to_s << hi.strftime("%b")}.csv"
	all_posts.sort! do |a, b|
		one = a[10..18].split
		two = b[10..18].split
		Time.new("20#{two[2]}", two[1], two[0]) <=> Time.new("20#{one[2]}", one[1], one[0])
	end
	File.write(filename, summary.join << all_posts.join)
	send_file(filename, :filename => (low.strftime("%d") << "-" << hi.strftime("%d") << hi.strftime("%b") << "_summary.csv"))
end

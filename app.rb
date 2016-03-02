require 'httparty'
require 'sinatra'
require 'pry'
set :haml, :escape_html => true

tokens = File.read("tokens.txt").lines
get "/" do
	haml :index
end

post "/summary" do
	template = ";;;;;;;\nDate;Platform;Post Copy;Link attached;Comments;Likes;Shares;Retweets;Engagement\n"
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
	hi = Time.new(kek.last, kek[1], kek[0])
	kek = params[:boundary][:low].scan(/\d+/)
	low = Time.new(kek.last, kek[1], kek[0])
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
					text = post["message"].gsub("\n", " ").slice(0,40).gsub("\"", "\"\"").delete(";").rstrip
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
				template << date.strftime("%d %b %y;") << "Facebook;" << text << ";#{link};#{comments};#{likes};#{shares};;#{likes + comments + shares}\n"
			end
		end
		template = template.prepend("Facebook summary;;The #{mdate} post " + mtext + " was the top performing post (#{mrts + mfavs + mcomm} total engagements) with #{mfavs} likes, #{mcomm} comments and #{mrts} shares. The #{ldate} post "  + ltext + " was the lowest performing post (#{lrts + lfavs + lcomm} total engagements) with #{lfavs} likes, #{lcomm} comments and #{lrts} shares.;;;;;\n")
	end
	unless params[:twitter].size == 0
		more = true
		first = true
		while more
			tweets = HTTParty.get("https://api.twitter.com/1.1/statuses/user_timeline.json?include_rts=false&count=200&screen_name=#{params[:twitter]}#{max_id}", :headers => {"Authorization" => "Bearer " + tokens[0].chop})
			binding.pry
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
				template << date.strftime("%d %b %y;") << "Twitter;" << text << ";;;#{favorites};;#{retweets};#{favorites + retweets}\n"
			end
		end
	template = template.prepend("Twitter summary;;The #{mdate} post " + mtext + " was the top performing post (#{mrts + mfavs} total engagements) with #{mrts} retweets and #{mfavs} likes. The #{ldate} post "  + ltext + " was the lowest performing post (#{lrts + lfavs} total engagements) with #{lrts} retweets and #{lfavs} likes.;;;;;\n")
	end
	filename = "dw/#{params[:twitter] << low.day.to_s << "-" << hi.day.to_s << hi.strftime("%b")}.csv"
	File.write(filename, template)
	send_file(filename, :filename => (low.strftime("%d") << "-" << hi.strftime("%d") << hi.strftime("%b") << "_summary"))
end

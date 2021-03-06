# encoding: utf-8

class Lastfm
    include Cinch::Plugin
    include UtilityFunctions
    require 'cgi'

    def minutes_in_words(timestamp)
    	minutes = (((Time.now - timestamp).abs)/60).round.to_i

		return nil if minutes < 0

		case minutes
		when 0..1      then "just now"
		when 2..59     then "#{minutes.to_s} minutes ago"
		when 60..1439        
			words = (minutes/60).to_i
			if words > 1
				"#{words.to_s} hours ago"
			else
				"#{words.to_s} hour ago"
			end
		when 1440..11519     
			words = (minutes/1440).to_i
			if words > 1
				"#{words.to_s} days ago"
			else
				"#{words.to_s} day ago"
			end
		when 11520..43199    
			words = (minutes/11520).to_i
			if words > 1
				"#{words.to_s} weeks ago"
			else
				"#{words.to_s} week ago"
			end
		when 43200..525599   
			words = (minutes/43200).to_i
			if words > 1
				"#{words.to_s} months ago"
			else
				"#{words.to_s} month ago"
			end
		else                      
			words = (minutes/525600).to_i
			if words > 1
				"#{words.to_s} years ago"
			else
				"#{words.to_s} year ago"
			end
		end
	end

	# Check the DB for stored usernames

	def get_lastfm(m, param) 
		if param == '' || param.nil?
			username = LastfmDB.first(:nick => m.user.nick.downcase)
			if username.nil?
				m.reply "last.fm username not provided nor on file."
				return nil
			else
				return username.username
			end
		else
			username = LastfmDB.first(:nick => param.downcase)
			if username.nil?
				return param.strip
			else
				return username.username
			end
		end
	end 



	# Last.fm user info

	match /lastfm(?: (.+))?/i, method: :user_info

	def user_info(m, query = nil)
		return unless ignore_nick(m.user.nick).nil?

		username = get_lastfm(m, query)
		return if username.nil?

		retrys = 2

		begin
			result = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=user.getinfo&user=#{username}&api_key="+$CONFIG.apis.lastfm, :read_timeout=>3).read)

			user          = result.xpath("//user/name").text
			realname      = result.xpath("//user/realname").text
			age           = result.xpath("//user/age").text
			sex           = result.xpath("//user/gender").text
			location      = result.xpath("//user/country").text
			playcount     = result.xpath("//user/playcount").text

			playcount = playcount.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse

			age = "–" if age.length < 1
			sex = "–" if sex.length < 1
			location = "–" if location.length < 1

			realname = ""+realname+" " if realname.length > 1

			reply = "#{realname}#{user} (#{age}/#{sex}/#{location}) | #{playcount} Scrobbles | Top Artists: "

			result = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=user.gettopartists&user=#{username}&period=overall&limit=5&api_key="+$CONFIG.apis.lastfm, :read_timeout=>3).read)

			top_artists = result.xpath("//topartists/artist")[0..4]

			top_artists.each do |artist|
				name = artist.xpath("name").text
				count = artist.xpath("playcount").text
				reply = reply + "#{name} (#{count}), "
			end
			reply = reply[0..reply.length-3]
		rescue Timeout::Error
			if retrys > 0
				retrys = retrys - 1
				retry
			else
				reply = "Timeout error"
			end
		rescue
			reply = "The user '#{username}' doesn't have a Last.fm account"
		end
		m.reply "Last.fm | #{reply}"
	end



	# Last.fm 7 day charts

	match /charts(?: (.+))?/i, method: :charts

	def charts(m, query = nil)
		return unless ignore_nick(m.user.nick).nil?

		username = get_lastfm(m, query)
		return if username.nil?

		retrys = 2

		begin
			result = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=user.gettopartists&user=#{username}&period=7day&limit=5&api_key="+$CONFIG.apis.lastfm, :read_timeout=>3).read)
			top_artists = result.xpath("//topartists/artist")[0..4]
			reply = "Top 5 Weekly artists for #{username} | "
			top_artists.each do |artist|
				name = artist.xpath("name").text
				count = artist.xpath("playcount").text
				reply = reply + "#{name} (#{count}), "
			end
			reply = reply[0..reply.length-3]
		rescue Timeout::Error
			if retrys > 0
				retrys = retrys - 1
				retry
			else
				reply = "Timeout error"
			end
		rescue
			reply = "The user '#{username}' doesn't have a Last.fm account"
		end
		m.reply "Last.fm | #{reply}"
	end



	# Compare two users

	match /compare (\S+)$/i, method: :compare
	match /compare (\S+) (\S+)/i, method: :compare

	def compare(m, one, two = nil)
		return unless ignore_nick(m.user.nick).nil?

		userone = get_lastfm(m, one)
		return if userone.nil?

		usertwo = get_lastfm(m, two)
		return if usertwo.nil?

		retrys = 2

		begin
			result = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=tasteometer.compare&type1=user&type2=user&value1=#{userone}&value2=#{usertwo}&api_key="+$CONFIG.apis.lastfm, :read_timeout=>3).read)
			score = result.xpath("//score").text

			common = result.xpath("//artists/artist")[0..4]
			commonlist = ""
			common.each do |getcommon|
				artist = getcommon.xpath("name").text
				commonlist = commonlist + "#{artist}, "
			end
			commonlist = commonlist[0..commonlist.length-3]
			commonlist = "Common artists include: #{commonlist}" if commonlist != ""

			#score = score[2..4]
			#scr = "#{score.to_i/10}.#{score.to_i % 10}"
            scr = (score.to_f * 100).round(1)

			reply = "#{userone} vs #{usertwo} #{scr}% | #{commonlist}"
		rescue Timeout::Error
			if retrys > 0
				retrys = retrys - 1
				retry
			else
				reply = "Timeout error"
			end
		rescue
			reply = "Error"
		end
		m.reply "Last.fm | #{reply}"
	end



	# Last played/Currently playing Track

	match /np(?: (.+))?/i, method: :now_playing

	def now_playing(m, query = nil)
		return unless ignore_nick(m.user.nick).nil?

		username = get_lastfm(m, query)
		return if username.nil?

		retrys = 2

		begin
			result = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=#{username}&limit=1&api_key="+$CONFIG.apis.lastfm, :read_timeout=>3).read)

			artist  = result.xpath("//recenttracks/track[1]/artist").text
			track   = result.xpath("//recenttracks/track[1]/name").text
			now     = result.xpath("//recenttracks/track[1]/@nowplaying").text
			album   = result.xpath("//recenttracks/track[1]/album").text
            

			album   = " from #{album}" if album != ""

			tagurl = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=artist.gettoptags&artist=#{URI.escape(artist)}&api_key="+$CONFIG.apis.lastfm, :read_timeout=>3).read)
			tags = tagurl.xpath("//toptags/tag")[0..3]
			taglist = ""
			tags.each do |gettags|
				tag = gettags.xpath("name").text
				taglist = taglist + "#{tag}, "
			end
			taglist = taglist[0..taglist.length-3]
			taglist = "| #{taglist}" if taglist != ""
            
            video = getVideo(track + " by " + artist)

			if now == "true"
				reply = "#{username} is playing: \"#{track}\" by #{artist}#{album} #{taglist} | Youtube: #{video}"
			else
                time    = result.xpath("//recenttracks/track[1]/date").text
                timestamp = Time.parse(time)
                timeago = minutes_in_words(timestamp)
				reply = "#{username} played #{timeago}: \"#{track}\" by #{artist}#{album} #{taglist} | Youtube: #{video}"
			end
		rescue Timeout::Error
			if retrys > 0
				retrys = retrys - 1
				retry
			else
				reply = "Timeout error"
			end
		rescue Exception => x
            error x.message
            error x.backtrace.inspect
			reply = "Error"
		end
		m.reply "Last.fm | #{reply}"
	end

    def getVideo(query)
        begin
			
			query = CGI.escape(query)

			url = open("http://gdata.youtube.com/feeds/api/videos?q=#{query}&max-results=3&v=2&prettyprint=true&alt=rss")
			url = Nokogiri::XML(url)
		

            video = "Not Found" #TODO: fix
			return # if url.xpath("//item[1]/title").text.length < 1

			id = url.xpath("//item[1]/media:group/yt:videoid").text

			video = "http://youtu.be/#{id}"

		rescue Exception => e
			error "Last.FM | Error: Could not find video for now playing with query: #{query}"
            error e.message
            error e.backtrace.inspect
            video = "Not Found"
		end
        return video
    end


	# Artist Info

	match /artist (.+)/i, method: :artist_info

	def artist_info(m, query)
		return unless ignore_nick(m.user.nick).nil?

		begin
			artistinfo = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=#{URI.escape(query)}&api_key="+$CONFIG.apis.lastfm))
			toptracks  = Nokogiri::XML(open("http://ws.audioscrobbler.com/2.0/?method=artist.gettoptracks&artist=#{URI.escape(query)}&limit=3&autocorrect=1&api_key="+$CONFIG.apis.lastfm))    

			artist     = artistinfo.xpath("//lfm/artist/name").text
			plays      = artistinfo.xpath("//lfm/artist/stats/playcount").text
			listeners  = artistinfo.xpath("//lfm/artist/stats/listeners").text
			url        = artistinfo.xpath("//lfm/artist/url").text

			tags = artistinfo.xpath("//tags/tag")[0..2]
			taglist = ""
			tags.each do |gettags|
				tag = gettags.xpath("name").text
				taglist = taglist + "#{tag}, "
			end
			taglist = taglist[0..taglist.length-3]
			taglist = "| Tags: #{taglist}. " if taglist != ""

			tracks = toptracks.xpath("//toptracks/track")
			tracklist = ""
			tracks.each do |gettracks|
				track = gettracks.xpath("name").text
				tracklist = tracklist + "#{track}, "
			end
			tracklist = tracklist[0..tracklist.length-3]
			tracklist = "Tracks: #{tracklist}. " if tracklist != ""

			plays     = plays.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
			listeners = listeners.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse

			reply = "%s | %s plays, %s listeners | %s%s| %s" % [artist, plays, listeners, tracklist, taglist, url]
		rescue
			reply = "Error"
		end
		m.reply "Last.fm | #{reply}"
	end

end
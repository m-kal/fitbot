# encoding: utf-8

class Youtube
    include Cinch::Plugin
    include UtilityFunctions
    require 'cgi'

	match /y(?:outube)? (.+)/i
	match /yt (.+)/i

	def length_in_minutes(seconds)
		return nil if seconds < 0

		if seconds > 3599
			length = [seconds/3600, seconds/60 % 60, seconds % 60].map{|t| t.to_s.rjust(2,'0')}.join(':')
		elsif seconds > 59
			length = [seconds/60 % 60, seconds % 60].join('m')+"s"
		else
			length = length+"s"
		end
	end

	def execute(m, query)
		return unless ignore_nick(m.user.nick).nil?

		begin
			bitly = Bitly.new($CONFIG.apis.bitly.user, $CONFIG.apis.bitly.api)

			query = CGI.escape(query)

			@url = open("http://gdata.youtube.com/feeds/api/videos?q=#{query}&max-results=3&v=2&prettyprint=true&alt=rss")
			@url = Nokogiri::XML(@url)

			@page_url = bitly.shorten("https://www.youtube.com/results?search_query=#{query}")

			def search(number)
				return if @url.xpath("//item[#{number}]/title").text.length < 1

				name       = @url.xpath("//item[#{number}]/title").text
				id         = @url.xpath("//item[#{number}]/media:group/yt:videoid").text
				views      = @url.xpath("//item[#{number}]/yt:statistics/@viewCount").text
				likes      = @url.xpath("//item[#{number}]/yt:rating/@numLikes").text
				dislikes   = @url.xpath("//item[#{number}]/yt:rating/@numDislikes").text
				rating     = @url.xpath("//item[#{number}]/gd:rating/@average").text
				length     = @url.xpath("//item[#{number}]/media:group/yt:duration/@seconds").text

				views      = views.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
				likes      = likes.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
				dislikes   = dislikes.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse

				length = length_in_minutes(length.to_i)

				"YouTube | \"%s\" | %s | %s views | %s/5 (%s|%s) | http://youtu.be/%s | More results: %s" % [name, length, views, rating[0..2], likes, dislikes, id, @page_url.shorten]
			end

			m.reply search(1)
		rescue
			m.reply "YouTube | Error: Could not find video"
		end
	end
end
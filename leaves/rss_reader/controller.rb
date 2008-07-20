require 'cgi'
class Controller < Autumn::Leaf

  before_filter :authenticate, :only => [:reload, :quit, :addFeed, :removeFeed, :silence]
	
	attr_reader :truncate, :update_interval, :get_rss	
	
	# load config for rss reader
	def will_start_up
		config = {}		
		if File.exists?('leaves/rss_reader/config.yml')
			config = YAML.load(File.open('leaves/rss_reader/config.yml'))
		end 
		@truncate = config['truncate'] || false
		@update_interval = config['update_interval'] || 120 
	end
	
	# send self a message to initialize the background task for retrieving
	# new feed entries
  def did_start_up
    stems.each{|sf| sf.message "!initrss", sf.nickname; break}
  end
    
  def about_command(stem, sender, reply_to, msg)
    "RSS Reader for WebProg-Trac-Timeline!"
  end

  def addFeed_command(stem, sender, reply_to, msg)
  	response = "foobar"		
		if(msg =~ /https:\/\//i)
			response = "Sry, unsupported protocol! probably later ;)"
    else
  		f = Feed.first(:server => server_identifier(stem), :channel => reply_to, :url => msg)
      f = Feed.create(:server => server_identifier(stem), :channel => reply_to, :url => msg) unless f
		  response = "added feed"
		end
    response
  end
#		  f = Feed.first(:server => server_identifier(stem), :channel => reply_to, :url => msg)
#      logger.info("f: #{f.class} -- #{f.inspect}")
#		  f = Feed.create(:server => server_identifier(stem), :channel => reply_to, :url => msg)
#			response = "Feed added!"		
#		end
#    response
  
  
  def removeFeed_command(stem, sender, reply_to, msg)
    response = ""
    f = Feed.first(msg.to_i)
		if f 
  		f.feed_datum.each{|fd| fd.destroy}
      if f.destroy! 
  			stem.message "Feed removed!", reply_to	
  		end
		else 
		  response = "feed not found"
		end
		response
  end

	def listFeeds_command(stem, sender, reply_to, msg)
		stem.message "Listing feeds for #{reply_to}", reply_to
		feeds = Feed.all :channel => reply_to, :server => server_identifier(stem)
		feeds.each{|f| stem.message "#{f.id}\t: #{f.url}", reply_to}
		""
	end

	def silence_command(stem, sender, reply_to, msg)
		feeds = Feed.all :channel => reply_to, :server => server_identifier(stem)
		sil = !feeds.first.silence
		feeds.each{|f| f.update_attributes(:silence => sil)}
		if sil
			response = "Stopped updating feeds for this channel."
		else
			response = "Restarted updating feeds for this channel."
		end
		response
	end

  def initrss_command(stem, sender, reply_to, msg)
		return unless (sender[:nick] == "universal" ||	sender[:nick] == stem.nickname)
    if "stop" == msg
      @get_rss = false
    else
      unless @get_rss
        @get_rss = true
        rssGetter
      end
    end
    ""
  end
  
  private
  def authenticate_filter(stem, channel, sender, command, msg, opts)
    (channel_auth(stem, channel, sender) || user_auth(sender))
  end

	## auth helper methods
	def channel_auth(stem, channel, sender)
		# Returns true if the sender has any of the privileges listed below		
		not ([:operator, :admin, :founder, :channel_owner] & [stem.privilege(channel, sender)].flatten).empty?
	end
	
	def user_auth(sender)
  	sender[:nick] == "universal"
	end

	# server_ident helper
  def server_identifier(stem)
    "#{stem.server}:#{stem.port}"
  end

  ## background task
	def rssGetter
    while @get_rss
      updateRss
      logger.debug "falling asleep at #{Time.now}"
      sleep @update_interval
      logger.debug "woke up at #{Time.now}"
    end
  end

  def updateRss
    stems.each do |stem|
      feeds = Feed.all :server => server_identifier(stem), :silence => false
      feeds.each{|f| f.update_feed_data @truncate}
      feeds.each do |feed|
    	  if feed.new_from_last_update.size > 0
       	    (feed.new_from_last_update.size - 1).downto 0 do |i|
    	      msg = feed.new_from_last_update[i]
            if msg
    	        stem.message "#{CGI.unescapeHTML(msg.title)} at #{msg.pubDate.strftime('%d.%m - %H:%M')} >> #{msg.link}", feed.channel
							# wait three seconds before next message ;) should prevent kicks because of flooding (at least for a reasonable number of messages)
							sleep 3.0
            end
          end
        end
      end
    end
  end  
end

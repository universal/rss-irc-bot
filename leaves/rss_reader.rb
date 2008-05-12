require 'data_mapper'
# Provides RSS parsing capabilities
require 'rss'
class RssReader < Autumn::Leaf

  before_filter :authenticate, :only => [:reload, :quit, :addFeed, :removeFeed, :silence]
	
	attr_reader :truncate, :update_interval, :get_rss	
	
	# load config for rss reader
	def will_start_up
		config = {}		
		if File.exists?('leaves/rss_reader_config.yml')
			config = YAML.load(File.open('leaves/rss_reader_config.yml'))
		end 
		@truncate = config['truncate'] || false
		@update_interval = config['update_interval'] || 120 
	end
	# send self a message to initialize the background task for retrieving
	# new feed entries
  def did_start_up
    sf = stems.first
    if sf 
      sf.message "!initrss", sf.nickname
    end
  end
    
  def about_command(stem, sender, reply_to, msg)
    stem.message "RSS Reader for WebProg-Trac-Timeline!", reply_to
  end

  def addFeed_command(stem, sender, reply_to, msg)
    f = Feed.find_or_create(:server => server_identifier(stem), :channel => reply_to, :url => msg)
    stem.message "Feed added!", f.channel
  end
  
  def removeFeed_command(stem, sender, reply_to, msg)
    f = Feed.find(msg.to_i)
		f.feed_datas.each{|fd| fd.destroy!}
    if f.destroy! 
			stem.message "Feed removed!", reply_to	
		end
  end

	def listFeeds_command(stem, sender, reply_to, msg)
		stem.message "Listing feeds for #{reply_to}", reply_to
		feeds = Feed.all :channel => reply_to, :server => server_identifier(stem)
		feeds.each{|f| stem.message "#{f.id}\t: #{f.url}", reply_to}
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
		stem.message response, reply_to
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
      sleep @update_interval
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
    	        stem.message "#{msg.title} at #{msg.pubDate} >> #{msg.link}", feed.channel 
            end
          end
        end
      end
    end
  end  
end

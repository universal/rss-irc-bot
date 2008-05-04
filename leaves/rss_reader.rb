require 'data_mapper'
# Provides RSS parsing capabilities
require 'rss'
class RssReader < Autumn::Leaf

  before_filter :authenticate, :only => [ :reload, :quit ]
  
  def did_start_up
    #t = Thread.fork{rssGetter}
    #t.join
  end
    
  def about_command(stem, sender, reply_to, msg)
    "RSS Reeder for WebProg-Trac-Timeline!"
  end

  def addFeed_command(stem, sender, reply_to, msg)
    f = Feed.find_or_create(:server => server_identifier(stem), :channel => reply_to, :url => msg)
    "Feed added!"
  end
  
  def rss_command(stem, sender, reply_to, msg)
    feeds = Feed.all :channel => reply_to, :server => server_identifier(stem)
    feeds.each{|f| f.update_feed_data }
    n = 0
    feeds.each{|f| n += f.new_from_last_update.size}
    "Test: Updated #{n} feed entries"
  end
  
  def update_command(stem, sender, reply_to, msg)
    if "start" == msg
      unless @get_rss
        @get_rss = true
        rssGetter
      end
    elsif "stop" == msg
      @get_rss = false
    end
  end
  
    
  def initrss_command(stem, sender, reply_to, msg)
    stem.message "Rss updating started", reply_to
    @get_rss = true
    rssGetter
  end
  
  def stoprss_command(stem, sender, reply_to, msg)
    stem.message "Rss updating stopped", reply_to
    @get_rss = false
  end
    
  def debug_command(stem, sender, reply_to, msg)
#    logger.info stem.nick? reply_to
    
    "debug command"
  end
    
  private
  
  def authenticate_filter(stem, channel, sender, command, msg, opts)
    # Returns true if the sender has any of the privileges listed below
    (not ([ :operator, :admin, :founder, :channel_owner ] & [ stem.privilege(channel, sender) ].flatten).empty?) || sender[:nick] == "universal"
  end
    
  def server_identifier(stem)
    "#{stem.server}:#{stem.port}"
  end
  
  def rssGetter
#    DataMapper::Database.setup({
#     :adapter  => 'sqlite3',
#     :database => 'data/irc.sqlite3'
#    })
#    require 'support/rss_reader/feed'
#    require 'support/rss_reader/feed_data'
    while @get_rss
      stems.each do |stem|
        logger.info "rss update running"
        channels = stem.channel_members.keys.clone.select{|c| c.length > 0}
        channels.each do |channel|
          feeds = Feed.all :channel => channel, :server => server_identifier(stem)
          feeds.each{|f| f.update_feed_data}
          feeds.each do |feed|
            if feed.new_from_last_update.size > 0
              4.downto 0 do |i|
                msg = feed.new_from_last_update[i]
                if msg
                  stem.message "New Msg: #{msg.title} at #{msg.pubDate}", channel 
                end
              end
            end
          end
        end
      end
      sleep 25.0
    end
  end
  
end

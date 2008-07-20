# Provides RSS parsing capabilities
require 'rubygems'
require 'simple-rss'
require 'open-uri'
class Feed 
  include DataMapper::Resource

  property :id, Integer,  :serial => true
  property :channel, Text, :length => 255, :nullable => false
  property :server, Text, :length => 255, :nullable => false
  property :url, Text, :length => 255, :nullable => false
  property :created_at, DateTime
  property :updated_at, DateTime
	property :silence, Boolean, :default => false
  
  has n, :feed_datum
#  validates_present :channel
#  validates_present :server
#  validates_present :url
  
  attr_accessor :new_from_last_update
  
	# get new feed entries for this feed and collect new ones in 
  # <code>:new_from_last_update</code>
  def update_feed_data(truncate = false)
    @new_from_last_update = []
    # Parse the feed, dumping its contents to rss
		return if (self.url.nil? || self.server.nil? || self.channel.nil?)
    return unless rss = SimpleRSS.parse(open(self.url))
	  rss.items.each do |item|

      if feed_datum.first(:pubDate => item.pubDate)
        # since the objects come sorted in a newest to oldest order, 
        # we don't care about all following, since we got all new ones already
        break;
      else 
        fd = FeedData.new :title => item.title, :pubDate => item.pubDate, :link => item.link, :feed => self
        if fd.save
          @new_from_last_update << fd
        end
      end
    end
		if truncate && last = @new_from_last_update.last
			fds = feed_datum.all(:pubDate.lt => last.pubDate).each{|fd| fd.destroy}
		end    
  end
end

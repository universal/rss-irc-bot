# Provides RSS parsing capabilities
require 'rubygems'
require 'simple-rss'
require 'open-uri'
class Feed < DataMapper::Base
  property :channel, :string, :nullable => false
  property :server, :string, :nullable => false
  property :url, :string, :nullable => false
  property :created_at, :datetime
  property :updated_at, :datetime
	property :silence, :boolean, :default => false
  
  has_many :feed_datas
  
  attr_accessor :new_from_last_update
  
	# get new feed entries for this feed and collect new ones in 
  # <code>:new_from_last_update</code>
  def update_feed_data(truncate = false)
    self.new_from_last_update = []
    # Parse the feed, dumping its contents to rss
		logger.info "help me plx, i'm nil" if self.nil?
    return if (self.url.nil? || self.server.nil? || self.channel.nil?)
    return unless rss = SimpleRSS.parse(open(self.url))
	  rss.items.each do |item|
      if FeedData.first(:pubDate => item.pubDate, :feed_id => self.id)
        # since the objects come sorted in a newest to oldest order, 
        # we don't care about all following, since we got all new ones already
        break;
      else 
        fd = self.feed_datas.build :title => item.title, :pubDate => item.pubDate, :link => item.link
        if fd.save
          self.new_from_last_update << fd
        end
      end
    end
		if truncate && last = self.new_from_last_update.last
			fds = FeedData.all :pubDate.lt => last.pubDate, :feed_id => self.id
			fds.each{|fd| fd.destroy!}			
		end    
  end
end

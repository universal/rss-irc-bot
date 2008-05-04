# Provides RSS parsing capabilities
require 'rss'
class Feed < DataMapper::Base
  property :channel, :string, :nullable => false
  property :server, :string, :nullable => false
  property :url, :string, :nullable => false
  property :created_at, :datetime
  property :updated_at, :datetime
  
  has_many :feed_datas
  
  attr_accessor :new_from_last_update
  
  def update_feed_data
    self.new_from_last_update = []
    # Parse the feed, dumping its contents to rss
    return if (self.url.nil? || self.server.nil? || self.url.nil? )
    rss = RSS::Parser.parse(self.url, false)
    rss.items.each do |item|
      if FeedData.first(:pubDate => item.pubDate, :feed_id => self.id)
        # since the objects come sorted in a newest to oldest order, 
        # we don't care about all following, since we got all new ones already
        break;
      else 
        fd = self.feed_datas.build :title => item.title, :pubDate => item.pubDate
        if fd.save
          self.new_from_last_update << fd
        end
      end
    end
    42
  end
end

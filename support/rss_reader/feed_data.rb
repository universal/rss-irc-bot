class FeedData < DataMapper::Base
  property :title, :string, :nullable => false
  property :pubDate, :datetime
  property :link, :string
  
  belongs_to :feed
end

class FeedData < DataMapper::Base
  property :title, :string, :nullable => false
  property :pubDate, :datetime
  
  belongs_to :feed
end

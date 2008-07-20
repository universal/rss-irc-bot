class FeedData 
  include DataMapper::Resource
  property :id, Integer,  :serial => true
  property :title, Text, :nullable => false
  property :pubDate, Time
  property :link, Text

  belongs_to :feed

#  validates_present :title
end

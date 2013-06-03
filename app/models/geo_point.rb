class GeoPoint
  include Mongoid::Document
  field :type, type: String, default: "Point"
  field :coordinates, type: Array, default: []
  embedded_in :locatable
  
  def latitude
    self.coordinates[1]
  end
  alias lat latitude
  
  def latitude=(value)
    self.coordinates[1] = value
  end
  alias lat= latitude=
  
  def longitude
    self.coordinates[0]
  end
  alias lng longitude
  
  def longitude=(value)
    self.coordinates[0] = value
  end
  alias lng= longitude=
  
  def as_mappable
    self.coordinates.reverse
  end
end

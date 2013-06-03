class Boundary
  include Mongoid::Document
  embeds_one :northeast, class_name: "GeoPoint"
  embeds_one :southwest, class_name: "GeoPoint"
  embedded_in :location
  
  def as_queryable
    [self.northeast.coordinates, self.southwest.coordinates]
  end
end

class Boundary
  include Mongoid::Document
  embeds_one :northeast, class_name: "GeoPoint"
  embeds_one :southwest, class_name: "GeoPoint"
  embedded_in :location
  
  def as_queryable
    [self.northeast.coordinates, self.southwest.coordinates]
  end
  
  def as_geo_polygon
    [self.northeast.coordinates, [self.northeast.lng, self.southwest.lat], self.southwest.coordinates, [self.southwest.lng, self.northeast.lat]]
  end
end

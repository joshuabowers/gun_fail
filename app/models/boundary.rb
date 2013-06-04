class Boundary
  include Mongoid::Document
  embeds_one :northeast, class_name: "GeoPoint"
  embeds_one :southwest, class_name: "GeoPoint"
  embedded_in :location
  
  def crosses_anti_meridian?
    self.southwest.lng > self.northeast.lng
  end
  
  def as_queryable
    if crosses_anti_meridian?
      [
        [self.southwest.coordinates, [180, self.northeast.lat]],
        [[-180, self.southwest.lat], self.northeast.coordinates]
      ]
    else
      [self.southwest.coordinates, self.northeast.coordinates]
    end
  end
  
  def as_geo_polygon
    [self.northeast.coordinates, [self.northeast.lng, self.southwest.lat], self.southwest.coordinates, [self.southwest.lng, self.northeast.lat]]
  end
end

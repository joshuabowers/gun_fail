class Incident
  include Mongoid::Document
  field :source_url, type: String
  field :daily_kos_url, type: String
  field :gun_fail_series, type: String
  field :street, type: String
  field :city, type: String
  field :state, type: String
  field :coordinates, type: Array
  field :occurred_at, type: ActiveSupport::TimeWithZone
  field :description, type: String
  
  index({coordinates: "2d"})
  
  EARTH_RADIUS = 6371.0
  
  # Distances measured in Km
  def self.within_distance(loc, distance)
    geo_near(loc).distance_multiplier(EARTH_RADIUS).spherical.max_distance(distance / EARTH_RADIUS)
  end
  
  scope :within_bounds, lambda {|bounds| bounds.blank? ? criteria : within_box(coordinates: bounds.split(',').map(&:to_f).each_slice(2).map(&:reverse))}
end

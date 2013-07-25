class Incident
  include Mongoid::Document
  field :source_url, type: String
  field :daily_kos_url, type: String
  field :gun_fail_series, type: String
  field :formatted_address, type: String
  field :occurred_at, type: ActiveSupport::TimeWithZone
  field :description, type: String
  field :status, type: Symbol
  
  embeds_one :geo_point
  
  index({"geo_point.coordinates" => "2d"})
  
  scope :failed, lambda { where(status: :failed) }
  scope :ok, lambda { where(status: :ok) }
  
  EARTH_RADIUS = 6371.0
  
  # Distances measured in Km
  def self.within_distance(loc, distance)
    geo_near(loc).distance_multiplier(EARTH_RADIUS).spherical.max_distance(distance / EARTH_RADIUS)
  end
  
  scope :within_bounds, lambda {|bounds| bounds.blank? ? criteria : within_box("geo_point.coordinates" => bounds.split(',').map(&:to_f).each_slice(2).map(&:reverse))}
  
  # Potential optimization, which will affect the javascript rendering for clusters: rather than return all results
  # within the boundaries, return a smaller subset, paginated, then clustered. The javascript can then start sending
  # multiple requests for the paginated data, potentially allowing for faster map refreshes between data additions.
  def self.clustered(bounds, zoom_level)
    self.ok.within_bounds(bounds).order_by(:occurred_at.asc).group_by {|i| i.geo_point.coordinates}
  end
  
  def self.bounded_by(bounds)
    Location.within_box(coordinates: bounds.split(',').map(&:to_f).each_slice(2).map(&:reverse))
  end
end

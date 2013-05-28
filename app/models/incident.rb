class Incident
  include Mongoid::Document
  field :source_url, type: String
  field :street, type: String
  field :city, type: String
  field :state, type: String
  field :coordinates, type: Array
  field :occurred_at, type: ActiveSupport::TimeWithZone
  field :description, type: String
  
  index({coordinates: "2d"})
end

class Incident
  include Mongoid::Document
  field :street, type: String
  field :city, type: String
  field :state, type: String
  field :coordinates, type: Array
  field :occurred_at, type: Time
  field :description, type: String
end

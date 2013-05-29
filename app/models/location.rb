class Location
  include Mongoid::Document
  field :city, type: String
  field :state, type: String
  field :coordinates, type: Array
  field :timezone, type: String
  
  def self.geolocate(placename)
    sanitized = sanitize_placename(placename)
    locale = sanitized.split(/, ?/)
    location = where(city: locale[0], state: locale[1]).first
    unless location
      postal_codes = Geonames::WebService.find_nearby_postal_codes( Geonames::PostalCodeSearchCriteria.new.tap do |criteria|
        criteria.place_name = sanitized
        criteria.country_code = "US"
      end)
      create(
        city: locale[0],
        state: locale[1],
        coordinates: [postal_codes.first.longitude, postal_codes.first.latitude],
        timezone: Geonames::WebService.timezone(postal_codes.first.latitude, postal_codes.first.longitude).timezone_id
      )
    else
      location
    end
  end
  
  def self.sanitize_placename(placename)
    placename.gsub(/\bCO\./i, "COUNTY")
  end
end

class Location
  include Mongoid::Document
  field :city, type: String
  field :state, type: String
  field :coordinates, type: Array
  field :timezone, type: String
  
  index({coordinates: "2d"})
  
  def incidents
    Incident.where(city: self.city, state: self.state)
  end
  
  class_attribute :accessed_webservice
  self.accessed_webservice = false
  
  def self.geolocate(placename)
    sanitized = sanitize_placename(placename)
    locale = sanitized.split(/, ?/)
    location = where(city: locale[0], state: locale[1]).first
    unless location
      postal_codes = Geonames::WebService.find_nearby_postal_codes( Geonames::PostalCodeSearchCriteria.new.tap do |criteria|
        criteria.place_name = sanitized
        criteria.country_code = "US"
      end)
      self.accessed_webservice = true
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
  
  # Geonames has problems with some of the abbreviations used in the GunFail series. This makes sure it can
  # properly handle the place names.
  def self.sanitize_placename(placename)
    {
      /\bCO\./i => "COUNTY",
      /\bBORO\b/i => "BOROUGH",
      /^MOUNTAIN HOME, AK$/i => "MOUNTAIN VILLAGE, AK"
    }.inject(placename) {|memo, pair| memo.gsub(pair[0], pair[1])}
  end
end

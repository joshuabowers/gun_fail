require 'open-uri'

class Location
  include Mongoid::Document
  field :long_name, type: String
  field :short_name, type: String
  field :formatted_address, type: String
  field :type, type: String
  field :timezone, type: String
  
  embeds_one :geo_point
  embeds_one :boundary
  
  index({"geo_point.coordinates" => "2d"})
  
  scope :city, lambda { where(type: "locality") }
  scope :township, lambda { where(type: "administrative_area_level_3") }
  scope :county, lambda { where(type: "administrative_area_level_2") }
  scope :state, lambda { where(type: "administrative_area_level_1") }
  
  class_attribute :valid_types
  self.valid_types = %w[sublocality locality administrative_area_level_3 administrative_area_level_2 administrative_area_level_1 country]
  
  def incidents
    Incidents.within_box("geo_point.coordinates" => self.boundary.as_queryable)
  end
  
  def self.geolocate(placename)
    sanitized = sanitize_placename(placename)
    where(formatted_address: /^#{Regexp.escape(sanitized)}$/i).first || geocode(placename)
  end
  
  def self.geocode(placename, administrative_area = nil)
    response = lookup_placename(placename, administrative_area)
    if response['status'] == "OK"
      response_type = (response['results'][0]['types'] & self.valid_types).first
      address_components = response['results'][0]['address_components']
      names = address_components.select {|c| c['types'].member?(response_type)}.first
      new(
        long_name: names['long_name'],
        short_name: names['short_name'],
        formatted_address: response['results'][0]['formatted_address'],
        type: response_type
      ).tap do |location|
        geometry = response['results'][0]['geometry']
        location.build_geo_point(geometry['location'])
        location.build_boundary(geometry['bounds'])
        # Need to restructure this; some locations will not have all administrative levels. (E.g. CA does not 
        # seem to have administrative_area_level_3's.) Need to loop over valid_types until an appropriate starting
        # point is found.
        next_type = self.valid_types[self.valid_types.index(response_type)+1]
        unless next_type.blank?
          next_index = address_components.index {|c| c['types'].member?(next_type)}
          puts next_type, next_index, address_components.length
          placename = address_components[next_index, address_components.length].map {|c| c['long_name'] + (c['types'].member?('administrative_area_level_2') ? " County" : "")}.join(', ')
          geolocate(placename)
        end
      end.save!
    else
      raise "Geocoding on \"#{placename}\" failed: #{response['status']}"
    end
  end
  
  def self.lookup_placename(placename, administrative_area = nil)
    parameters = { address: placename, sensor: false }.
      tap {|o| o[:administrative_area] = administrative_area unless administrative_area.blank? }.
      map {|key, value| "#{key}=#{value}"}.join("&")
    uri = URI.encode("https://maps.googleapis.com/maps/api/geocode/json?#{parameters}")
    JSON.parse(open(uri).read)
  end
  
  def self.sanitize_placename(placename)
    {
      /\bCO\./i => "COUNTY",
      /\bBORO\b/i => "BOROUGH",
      /^MOUNTAIN HOME, AK$/i => "MOUNTAIN VILLAGE, AK"
    }.inject(placename) {|memo, pair| memo.gsub(pair[0], pair[1])} + ", USA"
  end
  
  
  # index({coordinates: "2d"})
  
  # field :city, type: String
  # field :state, type: String
  # field :coordinates, type: Array
  # field :timezone, type: String
  # 
  # index({coordinates: "2d"})
  # 
  # def incidents
  #   Incident.where(city: self.city, state: self.state)
  # end
  # 
  # class_attribute :accessed_webservice
  # self.accessed_webservice = false
  # 
  # def self.geolocate(placename)
  #   sanitized = sanitize_placename(placename)
  #   locale = sanitized.split(/, ?/)
  #   location = where(city: locale[0], state: locale[1]).first
  #   unless location
  #     postal_codes = Geonames::WebService.find_nearby_postal_codes( Geonames::PostalCodeSearchCriteria.new.tap do |criteria|
  #       criteria.place_name = sanitized
  #       criteria.country_code = "US"
  #     end)
  #     self.accessed_webservice = true
  #     create(
  #       city: locale[0],
  #       state: locale[1],
  #       coordinates: [postal_codes.first.longitude, postal_codes.first.latitude],
  #       timezone: Geonames::WebService.timezone(postal_codes.first.latitude, postal_codes.first.longitude).timezone_id
  #     )
  #   else
  #     location
  #   end
  # end
  # 
  # # Geonames has problems with some of the abbreviations used in the GunFail series. This makes sure it can
  # # properly handle the place names.
  # def self.sanitize_placename(placename)
  #   {
  #     /\bCO\./i => "COUNTY",
  #     /\bBORO\b/i => "BOROUGH",
  #     /^MOUNTAIN HOME, AK$/i => "MOUNTAIN VILLAGE, AK"
  #   }.inject(placename) {|memo, pair| memo.gsub(pair[0], pair[1])}
  # end
end

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
  
  # index({"geo_point.coordinates" => "2d"})
  index("geo_point" => "2dsphere")
  
  scope :city, lambda { where(type: "locality") }
  scope :township, lambda { where(type: "administrative_area_level_3") }
  scope :county, lambda { where(type: "administrative_area_level_2") }
  scope :state, lambda { where(type: "administrative_area_level_1") }
  scope :short_or_long_name, lambda {|name| criteria.or({short_name: /^#{name}$/i}, {long_name: /^#{name}$/i})}
  
  class_attribute :valid_types
  self.valid_types = %w[locality administrative_area_level_3 administrative_area_level_2 administrative_area_level_1]
  
  class_attribute :geocode_hints
  self.geocode_hints = {"administrative_area_level_2" => " county", "administrative_area_level_1" => " state"}
  
  class_attribute :accessed_webservice
  self.accessed_webservice = 0
  
  def incidents
    Incidents.within_box("geo_point.coordinates" => self.boundary.as_queryable)
  end
  
  def self.geolocate(placename)
    sanitized = sanitize_placename(placename)
    reverse_location_search(sanitized) || geocode(sanitized)
  end
  
  def self.reverse_location_search(placename)
    names = placename.gsub(/county|state\b/i, '').split(/, ?/).map(&:strip).reverse
    location = self.short_or_long_name(names.shift).first
    until names.blank? || location.blank?
      location = self.short_or_long_name(names.shift).within_box("geo_point.coordinates" => location.boundary.as_queryable).first
    end
    location
  end
  
  def self.geocode(placename, administrative_area = nil)
    response = lookup_placename(placename, administrative_area)
    if response['status'] == "OK"
      self.accessed_webservice += 1
      result = response['results'].select {|r| (r['types'] & self.valid_types).present?}.first
      response_type = (result['types'] & self.valid_types).first
      address_components = result['address_components'].select {|c| (self.valid_types & c['types']).present?}
      names = address_components.select {|c| c['types'].member?(response_type)}.first
      new(
        long_name: names['long_name'],
        short_name: names['short_name'],
        formatted_address: result['formatted_address'],
        type: response_type
      ).tap do |location|
        geometry = result['geometry']
        location.build_geo_point(geometry['location'])
        location.build_boundary(geometry['bounds'])
        applicable_types = self.valid_types & address_components.map {|c| c['types']}.flatten - [response_type, 'administrative_area_level_3']
        unless applicable_types.blank?
          placename = address_components.select {|c| (c['types'] & applicable_types).present?}.map {|c| c['long_name'] + self.geocode_hints[(c['types'] & self.valid_types).first].to_s}.join(', ')
          sleep 1.second
          geolocate(placename)
        end
        location.save!
      end
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
    }.inject(placename) {|memo, pair| memo.gsub(pair[0], pair[1])}
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

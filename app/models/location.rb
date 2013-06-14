require 'open-uri'

class Location
  include Mongoid::Document
  field :long_name, type: String
  field :short_name, type: String
  field :formatted_address, type: String
  field :type, type: String
  field :timezone, type: String
  field :parent_location_id, type: Moped::BSON::ObjectId
  
  embeds_one :geo_point
  embeds_one :boundary
  
  index({"geo_point.coordinates" => "2d"})
  # index("geo_point" => "2dsphere")
  
  class_attribute :valid_types
  self.valid_types = %w[locality administrative_area_level_3 administrative_area_level_2 administrative_area_level_1 country]
  
  class_attribute :geocode_hints
  self.geocode_hints = {"administrative_area_level_2" => "county", "administrative_area_level_1" => "state"}
  
  class_attribute :accessed_webservice
  self.accessed_webservice = 0
  
  scope :city, lambda { where(type: "locality") }
  scope :township, lambda { where(type: "administrative_area_level_3") }
  scope :county, lambda { where(type: "administrative_area_level_2") }
  scope :state, lambda { where(type: "administrative_area_level_1") }
  scope :short_or_long_name, lambda {|name| 
    c = criteria
    m = name.match(/(.+?)(?: (#{self.geocode_hints.values.map {|v| Regexp.escape(v)}.join('|')}))?$/i)
    if m[2]
      c = c.where(type: self.geocode_hints.invert[m[2]])
    else
      c = c.where(:type.in => self.valid_types - self.geocode_hints.keys)
    end
    c.or({short_name: /^#{m[1]}$/i}, {long_name: /^#{m[1]}$/i})
  }
    
  def incidents(incident_criteria = nil)
    criteria_within_boundary(criteria: incident_criteria, class: Incident)
  end
  
  def sublocations(location_criteria = nil)
    criteria_within_boundary(criteria: location_criteria)
  end
  
  def criteria_within_boundary(options = {})
    c = options[:criteria] || options[:class].criteria || self.class.criteria
    Enumerator.new do |y|
      boundaries = self.boundary.crosses_anti_meridian? ? self.boundary.as_queryable : [self.boundary.as_queryable]
      boundaries.each do |sub_boundary|
        c.clone.within_box('geo_point.coordinates' => sub_boundary).each {|l| y << l}
      end
    end
  end
  
  # Note: Two location types (administrative_area_level_2 and administrative_area_level_1) are not directly
  # accessible via this method; geolocate biases results towards localities, rather than toward counties and
  # states. While for many locations this is not a problem, certain places (such as New York (City|State) or 
  # Sacramento (City|County)) complicate what would otherwise be a simple algorithm. As such, counties and states
  # do not pop up without some prodding: specifically, appending "county" or "state" to a placename component
  # representative as such will add in a type search for that leveled entity. #geocode does this automatically,
  # so any other code which calls #geolocate (probably only rake tasks) should append these words, as appropriate.
  def self.geolocate(placename, type = nil)
    sanitized = sanitize_placename(placename)
    reverse_location_search(sanitized) || geocode(sanitized, type)
  end
  
  def self.reverse_location_search(placename)
    names = placename.split(/, ?/).map(&:strip).reverse
    location = self.short_or_long_name(names.shift).first
    until names.blank? || location.blank?
      location = location.sublocations(self.short_or_long_name(names.shift)).first
    end
    location
  end
  
  def self.geocode(placename, type = nil)
    response = lookup_placename(placename)
    if response['status'] == "OK"
      self.accessed_webservice += 1
      result = response['results'].select {|r| (r['types'] & self.valid_types).present?}.
        reject {|r| type && !r['types'].member?(type)}.first
      raise "Could not locate \"#{placename}\" of type \"#{type}\"" unless result
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
        location.timezone = location.retrieve_timezone unless location.type == "country"
        applicable_types = self.valid_types & address_components.map {|c| c['types']}.flatten - [response_type, 'administrative_area_level_3']
        unless applicable_types.blank?
          placename = address_components.select {|c| (c['types'] & applicable_types).present?}.map do |c| 
            (c['long_name'] + " " + self.geocode_hints[(c['types'] & self.valid_types).first].to_s).strip
          end.join(', ')
          type = address_components.map {|c| c['types'] & applicable_types}.select {|c| c.present?}.first.first
          sleep 1.second
          parent = geolocate(placename, type)
          location.parent_location_id = parent.id
        end
        location.save!
      end
    else
      raise "Geocoding on \"#{placename}\" failed: #{response['status']}"
    end
  end
    
  def self.lookup_placename(placename)
    parameters = { address: placename, sensor: false }.map {|key, value| "#{key}=#{value}"}.join("&")
    uri = URI.encode("https://maps.googleapis.com/maps/api/geocode/json?#{parameters}")
    JSON.parse(open(uri).read)
  end
  
  def retrieve_timezone()
    parameters = { location: self.geo_point.as_mappable.join(','), sensor: false, timestamp: Time.now.to_i }.map {|k,v| "#{k}=#{v}"}.join("&")
    uri = URI.encode("https://maps.googleapis.com/maps/api/timezone/json?#{parameters}")
    response = JSON.parse(open(uri).read)
    if response['status'] == "OK"
      response['timeZoneId']
    else
      raise "Failed ot acquire timezome for location \"#{self.long_name}\": status: \"#{response['status']}\""
    end
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

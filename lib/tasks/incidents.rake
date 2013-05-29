require 'open-uri'

namespace :incidents do
  desc "Returns a list of article titles and links to GunFail sources"
  task :search => :environment do
    doc = Nokogiri::HTML(open('http://www.dailykos.com/search?story_type=&search_type=search_stories&text_type=query&text_expand=contains&text=%28text%29&usernames=David+Waldman&tags=gunfail&time_type=time_published&time_begin=11%2F01%2F2012&time_end=now&submit=Search'))
    doc.css('#panel-search-stories .hasTooltip').each do |i|
      puts "#{i.content} => #{i['href']}"
    end
  end

  desc "Grabs the latest GunFail entries from Daily Kos"
  task :fetch_latest => :environment do
    doc = Nokogiri::HTML(open('http://www.dailykos.com/story/2013/05/24/1210114/-GunFAIL-XIX'))
    doc.css('#body li').each do |i|
      geolocation = Location.geolocate(i.css('a').first.content)
      info = i.at_xpath('text()').content.match(/(?:, )?(\d{1,2}\/\d{1,2}\/\d{2,4}): (.*)/)
      time_of_day = info[2].match(/(\d{1,2})(?::?(\d{2}))? ([ap]\.?m\.?)/)
      occurred_at = Time.strptime(info[1], info[1] =~ /\/\d{2}$/ ? "%m/%d/%y" : "%m/%d/%Y").
        in_time_zone(geolocation.timezone).at_midnight +
        (time_of_day.blank? ? 0.hours : (
          (time_of_day[3] == "p.m." ? 12.hours : 0.hours) +
          (time_of_day[1].present? ? time_of_day[1].to_i.hours : 0.hours) +
          (time_of_day[2].present? ? time_of_day[2].to_i.minutes : 0.minutes)
        ))
      incident = Incident.create(
        source_url: i.css('a').first['href'],
        city: geolocation.city,
        state: geolocation.state,
        coordinates: geolocation.coordinates,
        occurred_at: occurred_at,
        description: info[2]
      )
    end
  end
end

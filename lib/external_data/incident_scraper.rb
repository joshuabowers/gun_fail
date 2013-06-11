require 'observer'
require 'open-uri'

module ExternalData
  class IncidentScraper
    include Observable
    
    def log(message)
      changed
      notify_observers(event: :log, message: message)
    end
    
    def started_article(article, incidents)
      changed
      notify_observers(event: :started_article, article: article, incidents: incidents)
    end
    
    def progress_updated
      changed
      notify_observers(event: :progress_updated)
    end
    
    def finished_article
      changed
      notify_observers(event: :finished_article)
    end
    
    def find_daily_kos_articles
      doc = Nokogiri::HTML(open('http://www.dailykos.com/search?story_type=&search_type=search_stories&text_type=query&text_expand=contains&text=%28text%29&usernames=David+Waldman&tags=gunfail&time_type=time_published&time_begin=11%2F01%2F2012&time_end=now&submit=Search'))
      doc.css('#panel-search-stories .hasTooltip').map do |i|
        {title: i.content, uri: "http://www.dailykos.com" + i['href']}
      end
    end

    def fetch_from_articles
      articles = find_daily_kos_articles
      Rails.logger.info "Found #{articles.count} articles"
      articles.each do |article|
        fetch_from_standard_article(article[:uri])
        # Note: This is to avoid incurring the wrath of Geonames, as there are usage limitations.
        sleep( Location.accessed_webservice ? 10.minutes : 30.seconds )
      end
    end

    def fetch_from_standard_article(uri)
      doc = Nokogiri::HTML(open(uri))
      gun_fail_series = doc.css('#titleHref//text()').to_s
      incidents = doc.css('#body li')
      started_article(gun_fail_series, incidents.count)
      incidents.each do |i|
        begin
          info = i.content.match(/([^,]+, [^,]+)(?:, )?(?:\D+)?(\d{1,2}\/\d{1,2}\/\d{2,4}): (.*)/)
          geolocation = Location.geolocate(info[1] + " state")
          time_of_day = info[3].match(/(\d{1,2})(?::?(\d{2}))? ([apAP]\.?[mM]\.?)/)
          occurred_at = Time.strptime(info[2], info[2] =~ /\/\d{2}$/ ? "%m/%d/%y" : "%m/%d/%Y").
            in_time_zone(geolocation.timezone).at_midnight +
            (time_of_day.blank? ? 0.hours : (
              (time_of_day[3] =~ /p\.?m\.?/i ? 12.hours : 0.hours) +
              (time_of_day[1].present? ? time_of_day[1].to_i.hours : 0.hours) +
              (time_of_day[2].present? ? time_of_day[2].to_i.minutes : 0.minutes)
            ))
          incident = Incident.create(
            source_url: i.css('a').first['href'],
            daily_kos_url: uri,
            gun_fail_series: gun_fail_series,
            formatted_address: geolocation.formatted_address,
            geo_point: geolocation.geo_point.clone,
            occurred_at: occurred_at,
            description: info[3],
            status: :ok
          )
        rescue Exception => e
          Rails.logger.warn "\n!!!\n!!! Failed to process incident: \"#{i.content.truncate(30)}\": #{e}\n!!!\n"
          Incident.create(
            daily_kos_url: uri,
            gun_fail_series: gun_fail_series,
            description: i.to_s,
            status: :failed
          )
        ensure
          progress_updated
          sleep 0.01
        end
      end
      finished_article
    end
  end
end

require 'open-uri'
require 'external_data/incident_scraper'
require 'reports/scrape_progress'

namespace :incidents do
  desc "Returns a list of article titles and links to GunFail sources"
  task :search => :environment do
    scraper = ExternalData::IncidentScraper.new
    scraper.find_daily_kos_articles.each do |a|
      puts a.inspect
    end
  end
  
  desc "Retrieves all GunFail entries from Daily Kos"
  task :fetch_all => :environment do
    # Incident.fetch_from_articles
    scraper = ExternalData::IncidentScraper.new
    scraper.add_observer(Reports::ScrapeProgress.new)
    scraper.fetch_from_articles
  end

  desc "Grabs the latest GunFail entries from Daily Kos"
  task :fetch_latest => :environment do
    scraper = ExternalData::IncidentScraper.new
    scraper.add_observer(Reports::ScrapeProgress.new)
    article = scraper.find_daily_kos_articles.first
    scraper.fetch_from_standard_article(article[:uri])
  end
  
  desc "Removes all incidents from the database"
  task :destroy_all => :environment do
    Incident.destroy_all
  end
end

module Reports
  class ScrapeProgress
    def update(event_args)
      send(event_args[:event], event_args)
    end
    
    def log(event_args)
      
    end
    
    def started_article(event_args)
      @progress_bar = ProgressBar.create(title: event_args[:article], total: event_args[:incidents], format: "%t: %a |%B| %p%% %e")
    end
    
    def progress_updated(event_args)
      @progress_bar.increment
    end
    
    def finished_article(event_args)
      @progress_bar.finish unless @progress_bar.finished?
    end
  end
end
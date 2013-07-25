class ActiveSupport::TimeWithZone
  def as_json(options = {})
    strftime('%A, %B %d, %Y @ %l:%M%p %Z')
  end
end
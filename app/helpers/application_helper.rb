module ApplicationHelper
  def metadata(data)
    content_for :page_metadata do
      data.map do |key, value|
        tag :meta, name: key, content: value
      end.join('\n').html_safe
    end
  end
  
  def meta_tag(name, content)
    metadata(name => content)
  end
end

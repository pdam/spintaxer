module Youtube

  class Video
    attr_accessor :author
    attr_accessor :id
    attr_accessor :title
    attr_accessor :length_seconds
    attr_accessor :rating_avg
    attr_accessor :rating_count
    attr_accessor :description
    attr_accessor :view_count
    attr_accessor :upload_time
    attr_accessor :comment_count
    attr_accessor :tags
    attr_accessor :upload_time
    attr_accessor :url
    attr_accessor :thumbnail_url

    # Return self information as XML format.
    def to_xml
      xml = "<video>\n"
      instance_variables.each do |attr|
        value = instance_variable_get(attr).to_s
        value.gsub!(/<br \/>/, "\n")
        value.gsub!(/<.*?>/m, '')
        value.gsub!(/&/m, '&amp;')
        value.gsub!(/'/m, '&apos;')
        value.gsub!(/"/m, '&quot;')
        value.gsub!(/</m, '&lt;')
        value.gsub!(/>/m, '&gt;')
        attr.sub!(/@/, '')
        xml += "<#{attr}>#{value}</#{attr}>\n"
      end
      xml += "</video>\n"
    end
  end

end


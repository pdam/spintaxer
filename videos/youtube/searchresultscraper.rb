
require 'open-uri'
require 'cgi'
require 'rubygems'
require 'hpricot'
require 'youtube/video'

module Youtube

  # = Introduction
  # Youtube::SearchResultScraper scrapes video information from search result page
  # on http://www.youtube.com.
  #
  # You can get result as array or xml.
  #
  # XML format is same as YouTube Developer API
  # (http://www.youtube.com/dev_api_ref?m=youtube.videos.list_by_tag).
  #
  # = Example
  #   require "rubygems"
  #   require "youtube/searchresultscraper"
  #
  #   scraper = Youtube::SearchResultScraper.new(keyword, page)
  #   scraper.open
  #   scraper.scrape
  #   puts scraper.get_xml
  #

  class SearchResultScraper

    attr_accessor :keyword
    attr_accessor :page
    attr_accessor :sort
    attr_reader   :video_count
    attr_reader   :video_from
    attr_reader   :video_to

    Relevance   = 'relevance'
    DateAdded   = 'video_date_uploaded'
    ViewCount   = 'video_view_count'
    Rating      = 'video_avg_rating'

    @@youtube_search_base_url = "http://www.youtube.com/results?search_query="

    # Create Youtube::SearchResultScraper object specifying keyword and number of page.
    #
    # You cannot specify number of videos per page.
    # Always, the number of videos is 20 per page.
    #
    # * keyword - specify keyword that you want to search on YouTube.
    #   You must specify keyword encoded by UTF-8.
    # * page    - specify number of page
    # * sort    - specify sort rule

    def initialize keyword, page=nil, sort=nil
      @keyword = keyword
      @page    = page if not page == nil
      @sort    = sort if not sort == nil
    end

    # Get search result from youtube by specified keyword.
    def open
      @url = @@youtube_search_base_url + CGI.escape(@keyword)
      @url += "&page=#{@page}" if not @page == nil
      @url += "&search_sort=#{@sort}" if not @sort == nil
      @html = Kernel.open(@url).read
      replace_document_write_javascript
      @search_result = Hpricot.parse(@html)
    end

    # Scrape video information from search result html.
    def scrape
      @videos = []

      @search_result.search("//div[@class='vEntry']").each do |video_html|
        video = Youtube::Video.new
        video.id             = scrape_id(video_html)
        video.author         = scrape_author(video_html)
        video.title          = scrape_title(video_html)
        video.length_seconds = scrape_length_seconds(video_html)
        video.rating_avg     = scrape_rating_avg(video_html)
        video.rating_count   = scrape_rating_count(video_html)
        video.description    = scrape_description(video_html)
        video.view_count     = scrape_view_count(video_html)
        video.thumbnail_url  = scrape_thumbnail_url(video_html)
        video.tags           = scrape_tags(video_html)
        video.upload_time    = scrape_upload_time(video_html)
        video.url            = scrape_url(video_html)

        check_video video

        @videos << video
      end

      @video_count = scrape_video_count
      @video_from  = scrape_video_from
      @video_to    = scrape_video_to

      raise "scraping error" if (is_no_result != @videos.empty?)

      @videos
    end

    # Iterator for scraped videos.
    def each
      @videos.each do |video|
        yield video
      end
    end

    # Return videos information as XML Format.
    def get_xml
      xml = "<ut_response status=\"ok\">" +
              "<video_count>" + @video_count.to_s +  "</video_count>" +
              "<video_list>\n"
      each do |video|
        xml += video.to_xml
      end
      xml += "</video_list></ut_response>"
    end

    private

    def replace_document_write_javascript
      @html.gsub!(%r{<script language="javascript" type="text/javascript">.*?document.write\('(.*?)'\).*?</script>}m, '\1')
    end

    def scrape_id video_html
      scrape_thumbnail_url(video_html).sub(%r{.*/([^/]+)/[^/]+.jpg}, '\1')
    end

    def scrape_author video_html
      video_html.search("div[@class='vfacets']").inner_html.sub(/.*From:<\/span> <a.*?>(.*?)<\/a>.*/m, '\1')
    end

    def scrape_title video_html
      video_html.search("div[@class='vtitle']/a").inner_html
    end

    def scrape_length_seconds video_html
      length_seconds = video_html.search("span[@class='runtime']").inner_html
      length_seconds =~ /(\d\d):(\d\d)/
      $1.to_i * 60 + $2.to_i
    end

    def scrape_rating_avg video_html
      video_html.search("img[@src='/img/star_sm.gif']").size +
        video_html.search("img[@src='/img/star_sm_half.gif']").size * 0.5
    end

    def scrape_rating_count video_html
      video_html.search("div[@class='rating']").inner_html.sub(/(\d+) rating/, '\1').to_i
    end

    def scrape_description video_html
      description = video_html.search("div[@class='vdesc']/span").inner_html.sub(/^\s*(.*?)\s*$/m, '\1')
    end

    def scrape_view_count video_html
      video_html.search("div[@class='vfacets']").inner_html.sub(/.*Views:<\/span> (\d+).*/m, '\1').to_i
    end

    def scrape_tags video_html
      tags = []
      video_html.search("div[@class='vtagValue']/a").each do |tag|
        tags << tag.inner_html
      end
      tags.join(" ")
    end

    def scrape_upload_time video_html
      if   video_html.search("div[@class='vfacets']").inner_html =~ /.*Added:<\/span>\s*(\d+)\s*(hour|day|week|month|year).*/m
        if $2 == "hour"
          Time.now - $1.to_i * 60 * 60
        elsif $2 == "day"
          Time.now - $1.to_i * 60 * 60 * 24
        elsif $2 == "week"
          Time.now - $1.to_i * 60 * 60 * 24 * 7
        elsif $2 == "month"
          Time.now - $1.to_i * 60 * 60 * 24 * 30
        elsif $2 == "year"
          Time.now - $1.to_i * 60 * 60 * 24 * 30 * 12
        end
      end
    end

    def scrape_thumbnail_url video_html
      video_html.search("img[@class='vimg120']").to_html.sub(/.*src="(.*?)".*/, '\1')
    end

    def scrape_url video_html
      "http://www.youtube.com" +
        video_html.search("div[@class='vtitle']/a").to_html.sub(/.*href="(.*?)".*/m, '\1')
    end

    def scrape_result_header
      @search_result.search("div[@id='sectionHeader']").inner_html
    end

    def scrape_video_count
      video_count = scrape_result_header
      unless video_count.sub!(/.+Results \d+-\d+ of\s*(|about )([0-9,]+)/m , '\2')
        raise "no video count: " + @url unless is_no_result
      end
      video_count.gsub!(/,/, '')
      video_count.to_i
    end

    def scrape_video_from
      video_from = scrape_result_header
      unless video_from.sub!(/.+Results (\d+)/m, '\1')
        raise "no video from: " + @url unless is_no_result
      end
      video_from.to_i
    end

    def scrape_video_to
      video_to = scrape_result_header
      unless video_to.sub!(/.+Results \d+-(\d+)/m, '\1')
        raise "no video to: "  + @url unless is_no_result
      end
      video_to.to_i
    end

    def is_no_result
      if @is_no_result == nil
        @is_no_result = @html.include?('No Videos found')
      end
      @is_no_result
    end

    def check_video video
      errors = []

      errors << "author"         if video.author.empty?
      errors << "id"             if video.id.empty?
      errors << "title"          if video.title.empty?
      errors << "length_seconds" if video.length_seconds.to_s.empty?
      errors << "rating_avg"     if video.rating_avg.to_s.empty?
      errors << "rating_count"   if video.rating_count.to_s.empty?
      errors << "view_count"     if video.view_count.to_s.empty?
      errors << "tags"           if video.tags.empty?
      errors << "url"            if video.url.empty?
      errors << "thumbnail_url"  if video.thumbnail_url.empty?

      unless errors.empty? then
        error_msg = "scraping error occurred.\n"
        errors.each do |error|
          error_msg << error + " is not setted.\n"
        end
        raise error_msg
      end
    end

  end

end

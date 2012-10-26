

require 'open-uri'
require 'cgi'
require 'rubygems'
require 'hpricot'
require 'video'

module Youtube #:nodoc:
  # = Introduction
  # Youtube::BrowseScraper scrapes video information from search result page
  # on http://www.youtube.com.
  #
  # You can get result as array or xml.
  #
  # XML format is same as YouTube Developer API
  # (http://www.youtube.com/dev_api_ref?m=youtube.videos.list_by_tag).
  #
  # = Example
  #   require "rubygems"
  #   require "youtube/BrowseScraper"
  #
  #   scraper = Youtube::BrowseScraper.new(browse, time, category, language, page)
  #   scraper.open
  #   data = scraper.scrape
  #   p data

  class BrowseScraper
    # constants for browse parameter(default MoseRecent)
    MostRecent        = 'mr'
    MostViewed        = 'mp'
    TopRated          = 'tr'
    MostDiscussed     = 'md'
    TopFavorites      = 'mf'
    MostLinked        = 'mrd'
    RecentryFeatured  = 'rf'
    MostResponded     = 'ms'
    WatchOnMobile     = 'mv'
    BrowseArray = [MostRecent,
                   MostViewed,
                   TopRated,
                   MostDiscussed,
                   TopFavorites,
                   MostLinked,
                   RecentryFeatured,
                   MostResponded,
                   WatchOnMobile]

    # constants for time parameter(default Today)
    Today       = 't'
    ThisWeek    = 'w'
    ThisMonth   = 'm'
    All         = 'a'
    TimeArray = [Today,
                 ThisWeek,
                 ThisMonth,
                 All]

    # constants for category parameter(default 0)
    AllCategory     =  0
    AutosVehicles   =  2
    Comedy          = 23
    Entertainment   = 24
    FilmAnimation   =  1
    GadgetsGames    = 20
    HowtoDIY        = 26
    Music           = 10
    NewsPolitics    = 25
    PeopleBlogs     = 22
    PetsAnimals     = 15
    Sports          = 17
    TravelPlaces    = 19

    # constants for language parameter(default '')
    AllLanguage   = ''
    English       = 'EN'
    Spanish       = 'ES'
    Japanese      = 'JP'
    German        = 'DE'
    Chinese       = 'CN'
    French        = 'FR'
    LanguageArray = [AllLanguage,
                     English,
                     Spanish,
                     Japanese,
                     German,
                     Chinese,
                     French]

    attr_accessor :browse
    attr_accessor :time
    attr_accessor :category
    attr_accessor :language
    attr_accessor :page
    attr_reader   :video_count
    attr_reader   :video_from
    attr_reader   :video_to

    @@youtube_search_base_url = 'http://www.youtube.com/browse'

    # Create Youtube::BrowseScraper object
    # (default parameter )
    #
    # You cannot specify number of videos per page.
    # Always, the number of videos is 20 per page.
    def initialize browse = MostRecent, time = Today, category = AllCategory, language = AllLanguage, page = 1
      @browse   = browse
      @time     = time
      @category = category
      @language = language
      @page     = page

      errors = []
      errors << "browse"    if BrowseArray.index(@browse)     == nil
      errors << "time"      if TimeArray.index(@time)         == nil
      errors << "language"  if LanguageArray.index(@language) == nil
      unless errors.empty? then
        error_msg = "parameter error occurred.\n"
        errors.each do |error|
          error_msg << error + " is invalid.\n"
        end
        raise error_msg
      end
    end

    # Get search result from youtube by specified keyword.
    def open
      @url  = @@youtube_search_base_url
      @url += "?s=#{@browse}"
      @url += "&t=#{@time}"
      @url += "&c=#{@category}"
      @url += "&l=#{@language}"
      @url += "&p=#{@page}"
      @html = Kernel.open(@url).read
      @search_result = Hpricot.parse(@html)
    end

    # Scrape video information from search result html.
    def scrape
      @videos = []
      @video_count = 0
      @search_result.search('//div[@class="v120vEntry"]').each do |video_html|
        video                = Youtube::Video.new

        video.id             = scrape_id(video_html)
        video.author         = scrape_author(video_html)
        video.title          = scrape_title(video_html)
        video.length_seconds = scrape_length_seconds(video_html)
        video.rating_avg     = scrape_rating_avg(video_html)
        video.view_count     = scrape_view_count(video_html)
        video.thumbnail_url  = scrape_thumbnail_url(video_html)

        check_video video

        @videos << video
        @video_count += 1
      end
      @videos
    end

    # Return videos information as XML Format.
    def get_xml
    end

    def replace_document_write_javascript
      @html.gsub!(%r{<script language="javascript" type="text/javascript">.*?document.write\('(.*?)'\).*?</script>}m, '\1')
    end

    def scrape_id video_html
      scrape_thumbnail_url(video_html).sub(%r{.*/([^/]+)/[^/]+.jpg}, '\1')
    end

    def scrape_thumbnail_url video_html
      video_html.search("img[@class='vimg120']").to_html.sub(/.*src="(.*?)".*/, '\1')
    end

    def scrape_title video_html
      video_html.search('div[@class="vtitle"]/a').inner_html
    end

    def scrape_length_seconds video_html
      length_seconds = video_html.search("span[@class='runtime']").inner_html
      length_seconds =~ /(\d\d):(\d\d)/
      $1.to_i * 60 + $2.to_i
    end

    def scrape_rating_avg video_html
      video_html.search("img[@src='/img/icn_star_full_11x11.gif']").size +
      video_html.search("img[@src='/img/icn_star_half_11x11.gif']").size * 0.5
    end

    def scrape_thumbnail_url video_html
      video_html.search("img[@class=' vimg ']").to_html.sub(/.*src="(.*?)".*/, '\1')
    end

    def scrape_author video_html
      video_html.search("div[@class='vfacets']").inner_html.sub(/.*From:<\/span> <a.*?>(.*?)<\/a>.*/m, '\1')
    end

    def scrape_view_count video_html
      @num = video_html.search("div[@class='vfacets']").inner_html.sub(/.*Views:<\/span> ([\d,]+).*/m, '\1')
      @num.gsub(/,/, '').to_i
    end

    def check_video video
      errors = []

      errors << "id"             if video.id.empty?
      errors << "author"         if video.author.empty?
      errors << "title"          if video.title.empty?
      errors << "length_seconds" if video.length_seconds.to_s.empty?
      errors << "thumbnail_url"  if video.thumbnail_url.empty?

      unless errors.empty? then
        error_msg = "scraping error occurred.\n"
        errors.each do |error|
          error_msg << error + " is not setted.\n"
        end
        raise error_msg
      end
    end

    def each
      @videos.each do |video|
        yield video
      end
    end

  end
end

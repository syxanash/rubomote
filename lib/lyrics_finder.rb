require 'rest-client'
require 'nokogiri'
require 'genius'
require 'similar_text'

class LyricsNotFound < StandardError; end

class LyricsFinder
  # change this constant if you want to increase or decrease the percentage
  # of similarity between the artist entered by the user and the artist
  # found on genius.com
  PERCENTAGE_OF_SIMILARITY = 80

  def initialize(api_key)
    Genius.access_token = api_key
  end

  def lyrics(track_name, track_artist)
    lyrics_text = ''

    # beautify the song name removing the featuring in order to be easily
    # searchable on genius.com

    track_name.gsub!(/\((.*?)\)/, '')
    track_artist.gsub!(/\((.*?)\)/, '')

    track_name.gsub!(/.((ft\.|feat).*?)$/mi, '')
    track_artist.gsub!(/.((ft\.|feat).*?)$/mi, '')

    songs = Genius::Song.search("#{track_artist} #{track_name}")
    song_found = songs.first

    # if first method returns nil or song artist found is not similar by 80%
    # to the artist entered by the user then lyrics is not found

    if song_found.nil? ||
       (song_found.resource['primary_artist']['name'].similar(track_artist) < PERCENTAGE_OF_SIMILARITY)
      raise LyricsNotFound, "Lyrics not found for #{track_name}"
    end

    # download html content from the genius.com website and parse the div
    # lyrics downloading only the text removing extra tags

    html_content = RestClient.get(song_found.url)
    doc = Nokogiri::HTML::Document.parse(html_content)

    doc.css('.lyrics').each do |n|
      lyrics_text += n.text.strip
    end

    lyrics_text
  end
end

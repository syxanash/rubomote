module RubomoteHelpers
  def authenticate!
    redirect '/login' unless authenticated?
  end

  def authenticated?
    session[:pin] == settings.session_secret
  end

  def track_lyrics
    if @player.stopped?
      lyrics_text = 'Press ▶️ to get the lyrics'
    else
      begin
        lyrics_text = @lyrics_finder.lyrics(@player.current_track.name, @player.current_track.artist)
      rescue LyricsNotFound
        lyrics_text = 'Nothing found'
      rescue Genius::AuthenticationError
        lyrics_text = 'Invalid Genius API token'
      rescue Exception
      end
    end

    lyrics_text
  end

  def track_info
    "#{@player.current_track.name} - #{@player.current_track.artist}"
  end
end

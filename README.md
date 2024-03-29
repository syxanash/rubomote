# rubomote :musical_note:

remotely control iTunes over Wi-Fi using Ruby.

## Demo

[![rubomote](https://thumbs.gfycat.com/FakeDistantBorderterrier-size_restricted.gif)](https://gfycat.com/FakeDistantBorderterrier)

alternatively you can also :boom: **shake** :boom: your smartphone to change song *(just don't do it with your laptop)*

[![rubomote](https://thumbs.gfycat.com/LinearFeistyIndigowingedparrot-size_restricted.gif)](https://gfycat.com/LinearFeistyIndigowingedparrot)

## Getting Started
### Dependencies

Check `Gemfile` to see all dependencies required or just run:

```
bundle install
```

this app also requires **cowsay** and **lolcat**:

```
$ gem install lolcat
$ brew install cowsay
```

and you are ready to go.

### Run the app

Download this repo or clone it. Run the app with the following command:

```
$ ruby app.rb
```

now open the web browser on your device and type the ip address of the server **followed by port** `4567`; you can check your ip address with `ifconfig` command and look for `inet` address on interface `en1`. After that you should see the web app asking for the secret pin generated randomly on the terminal like so:

![secret cow](https://i.imgur.com/zxAXOhP.png)

Copy it into the login page and once you've clicked on **Verify** you should be able to control iTunes with your smartphone.

![web app](https://i.imgur.com/GGJHAGG.png)

[Here](https://asciinema.org/a/120635)'s an example of how to set up rubomote server.

## Lyrics

If you want to get lyrics when you're listening to a song, simply add your **client access token** from [genius.com](https://genius.com/api-clients) to `rubomote_config.json`. Once the token is stored inside rubomote configuration file you'll be able to get the lyrics of the current song played by clicking the green button under the volume bar, see the picture displayed before.

I've also written a command line tool to download lyrics from genius.com, check [this](https://gist.github.com/syxanash/f9a21f21d2bbad43d7eae0f969efe0b6) out!

## Tested OS

* OS X Mavericks
* OS X Yosemite
* OS X El Capitan
* macOS Sierra

Unfortunately this app currently works only on Macs due to **itunes-client** library which uses AppleScript scripts to control iTunes.

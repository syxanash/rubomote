# rubomote :musical_note:

remotely control iTunes over Wi-Fi using Ruby.

## Demo

[![rubomote](https://thumbs.gfycat.com/FakeDistantBorderterrier-size_restricted.gif)](https://gfycat.com/FakeDistantBorderterrier)

alternatively you can also :boom: **shake** :boom: your smartphone to change song *(just don't do it with your laptop)*

[![rubomote](https://thumbs.gfycat.com/LinearFeistyIndigowingedparrot-size_restricted.gif)](https://gfycat.com/LinearFeistyIndigowingedparrot)

## Getting Started
### Dependencies

install [sinatra](http://www.sinatrarb.com/) and [itunes-client](https://github.com/katsuma/itunes-client) gems:

```
$ gem install sinatra
$ gem install itunes-client
```

this app also requires **cowsay** and **lolcat**:

```
$ gem install lolcat
$ brew install cowsay
```

and you are ready to go.

### Run the app

Download this repo or clone it. In order to correctly use the app, you need to allow access from external clients on the same network, to do this set sinatra [bind option](http://www.sinatrarb.com/configuration.html#__server_hostname_or_ip_address) to `0.0.0.0` or simply run the app with the following command:

```
$ ruby app.rb -o 0.0.0.0
```

now open the web browser on your device and type the ip address of the server **followed by port** `4567`; you can check your ip address with `ifconfig` command and look for `inet` address on interface `en1`. After that you should see the web app asking for the secret pin generated randomly on the terminal like so:

![secret cow](http://i.imgur.com/BS7vY9p.png)

Copy it into the login page and once you've clicked on **Verify** you should be able to control iTunes with your smartphone.

![web app](http://i.imgur.com/TJ81IXL.jpg)

[Here](https://asciinema.org/a/113400)'s an example of how to set up rubomote server.

## Tested OS

* OS X Mavericks
* OS X Yosemite
* OS X El Capitan
* macOS Sierra

Unfortunately this app currently works only on Macs due to **itunes-client** library which uses AppleScript scripts to control iTunes.

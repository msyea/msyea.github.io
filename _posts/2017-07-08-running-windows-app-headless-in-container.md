---
title: Running a Windows app headless in a debian/node container
category: technology
tags: [nodejs]
---
**Skip to "Now the meat of the post" if financial data doesn't interest you.**

I had a problem. I have been building a data visualisation app in Node/React for
a client and have been sourcing my data from the undocumented/deprecated Yahoo Finance API.
It turns out that (surprisingly) the *undocumented/deprecated* Yahoo Finance API doesn't
provide complete or consistent data for UK stocks (we're interested in the fundamental and
technical data points). So we had to find an alternative datasource, and boy was this hard.

We evaluated the following sources:

* Reuters
* Bloomberg
* LSE
* Interactive Brokers
* Morning Star
* Xignite
* DTN (iqfeed)
* Intrinio
* Barchart
* Quandl

About half didn't provide real-time or delayed prices (they only had historical) and/or
didn't provide enough fundamental/technical signals. Also some we far too expensive ($15k+ pa).
And one didn't respond (Reuters, disappointingly I'm looking at you).

**The stand out winner was DTN** (although subsequently we found out their fundamental/technical data
  was incomplete and we've had to pivot to modelling US stocks, rather the UK but they may introduce
  enhanced UK data in the future).

Data source problem solved... but not quite. They don't provide an internet API, they only provide
a proxy agent that runs on the host machine, which you can communicate with via a TCP/IP socket...

So I had a new host of problems... i). write a streaming socket client in js and ii). workout how to run
this IQFeed agent in "production".

Writing the client was relatively easy. i). write a pretty wrapper around `net.Socket`, ii). connect to a
few ports, iii). do an auth handshake and configure their client (using their propriety API) and iv). choose
the stocks that I want to watch, and hey presto, I now have a streaming source of data. I even wrapped the calls
in promises, so you can do: (the example below batches and tracks 6 `socket.write` and `Event: 'data'`)

```js
iqFeedClient.getLatest(['AAPL', 'GOOGL')
  .then(data => {
    console.log(data['AAPL'])
  })
// outputs: {"fundamental": {"key": "values"}, "summary": {"key": "values"}}
```
I would love to open source my iqfeed client, but their developer agreement prevents me from sharing
info about their propriety API. Also this is why there are no screenshots :-(

# Now the meat of the post

Anyway, now to move onto the bigger problem. How to get the IQFeed agent in production. I noticed that
their macOS version was their Windows version but packaged using WineBottler, so Wine was my starting point.

I then spun up an Ubuntu VM, installed Wine and again, hey presto, it worked out of the box. Perfect.
Now how to I squeeze it into my node Docker container that the app actually runs in...

So here we go:

```bash
# in macOS terminal
$ docker run -it node:6.11.0 bash
# in container
> apt-get update
> apt-get install wine -y
> wget http://www.iqfeed.net/iqfeed_client.exe
> wine iqfeed_client.exe
# output:
# it looks like multiarch needs to be enabled.  as root, please
# execute "dpkg --add-architecture i386 && apt-get update &&
# apt-get install wine32"
# wine: created the configuration directory '/root/.wine64'
# Application tried to create a window, but no driver could be loaded.
# Make sure that your X server is running and that $DISPLAY is set correctly.
```
I'm like oh, win32, old school... let's try again:

```bash
> dpkg --add-architecture i386 && apt-get update &&
  apt-get install wine32 -y
> wine iqfeed_client.exe
# output:
# wine: created the configuration directory '/root/.wine'
# Application tried to create a window, but no driver could be loaded.
# Make sure that your X server is running and that $DISPLAY is set correctly.
```
I didn't really know what X server but I was aware that running a windows GUI installer on
a linux non-GUI OS was going to be difficult.

After a bit of Googling I found this excellent post by [Fredrik Averpil](https://fredrikaverpil.github.io/2016/07/31/docker-for-mac-and-gui-applications/)
(credit for getting XQuarts and Docker working all his) It basically tells me I can
run X server locally on macOS and if I enable networking, I can add a display to
my container. I was like WTF? This is magic. Let's do it.

On my mac:

```bash
$ brew cask install xquartz
$ open -a XQuartz
```
In "XQuartz Preferences" enable networking "Preferences > Security > [x] Allow connections from network clients" and then add local IP to ACL:

```bash
$ ip=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')
$ xhost + $ip
# x.x.x.x being added to access control list
```
Then the moment of truth do (repeat the above install):

```bash
$ docker run -e DISPLAY=x.x.x.x:0 -v /tmp/.X11-unix:/tmp/.X11-unix -it node:6.11.0 bash
# repeat install above
> wine iqfeed_client.exe
```
I was like OMG. A Windows Installer running in a debian/node container has just appeared on my Mac desktop. Mind blown.

Then halfway through the install it hanged... just hanged... "Microsoft Visual C++ 2014 Update 4 Redistributable not found!". Microsoft LOL.

After trawling iqfeed forums and elsewhere on the web I found that the solution was to use the official
WineHQ Debian packages https://wiki.winehq.org/Debian instead.

So here we go again:

```bash
> apt-get purge wine* && apt-get autoremove && rm -rf .wine
> dpkg --add-architecture i386
> wget -nc https://dl.winehq.org/wine-builds/Release.key
> apt-key add Release.key
> apt-add-repository https://dl.winehq.org/wine-builds/debian/
# apt-add-repository: command not found -bah!
> apt-get install -y software-properties-common
> apt-add-repository https://dl.winehq.org/wine-builds/debian/
> apt-get update
# E: The method driver /usr/lib/apt/methods/https could not be found.
# N: Is the package apt-transport-https installed? -bah!
> apt-get install -y apt-transport-https
> apt-get update
> apt-get install -y --install-recommends winehq-stable
> wine iqfeed_client.exe
```

This time it downloaded the dependences and worked!! Now for the critical test, does
the installed program work?

```bash
> wine .wine/drive_c/Program\ Files\ \(x86\)/DTN/IQFeed/iqconnect.exe
```
And yes! It worked... I cannot describe how elated I was at this point. Now is it
portable and repeatable?

```bash
> tar -xzf iqfeed.tgz .wine/
> cp  iqfeed.tgz /tmp/.X11-unix/
> exit # kill container
$ docker run -e DISPLAY=x.x.x.x:0 -v /tmp/.X11-unix:/tmp/.X11-unix -it node:6.11.0 bash
# repeat install above
> tar -xzf /tmp/.X11-unix/iqfeed.tgz
> wine .wine/drive_c/Program\ Files\ \(x86\)/DTN/IQFeed/iqconnect.exe
```

Yes it was. Now is it possible to run it headless?

After much Googling I found a program [Xvfb](https://en.wikipedia.org/wiki/Xvfb)
(X Virtual Frame Buffer)... could this work?

```bash
$ docker run -it node:6.11.0 bash
# note. no X server vars
# repeat wine install
> apt-get install -y xvfb
> Xvfb :99 & # start and detach
> DISPLAY=:99 wine .wine/drive_c/Program\ Files\ \(x86\)/DTN/IQFeed/iqconnect.exe
```

It looked like it worked... will work with javascript?

```js
// start up iqconnect.exe
exec('Xvfb :99 & DISPLAY=:99 wine "/.wine/drive_c/Program Files (x86)/DTN/IQFeed/iqconnect.exe"')
// wait a bit to be safe
setTimeout(() => {
  const socket = new Socket()
  socket.connect(port, () => console.log('connected to server!'))
}, 10000)
```

And then I got those magic words: "connected to server!".

Well that was 5 hours of fun!

Finally can I wrap can I turn all of this into a Docker image?

```
FROM node:6.11.0

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
  && apt-get install -y software-properties-common apt-transport-https \
  && dpkg --add-architecture i386 \
  && wget -nc https://dl.winehq.org/wine-builds/Release.key \
  && apt-key add Release.key \
  && apt-add-repository https://dl.winehq.org/wine-builds/debian/ \
  && apt-get update \
  && apt-get install -y --install-recommends winehq-stable xvfb \
  && apt-get remove -y software-properties-common apt-transport-https \
  && apt-get clean
  && apt-get autoremove

COPY iqfeed.tgz .
RUN tar -xzf iqfeed.tgz && rm iqfeed.tgz
ENV WINEPREFIX /.wine

ENV DISPLAY :99
CMD Xvfb $DISPLAY -nolisten tcp & wine "/.wine/drive_c/Program Files (x86)/DTN/IQFeed/iqconnect.exe"
```

This is now running successfully in production. I hope it opens up opportunities
to people who face similar problems.

Also I'm just a javascript developer, so if anyone has advice on security or
other optimisations (particularly docker image size) please get in touch.

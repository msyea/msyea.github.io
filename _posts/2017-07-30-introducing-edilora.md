---
title: Introducing Edilora
category: technology
tags: [edilora]
---
<p class="lead">
I'm proud to introduce my new side-project: <a href="https://edilora.com">Edilora</a>, the <abbr title="Command and Control">C2</abbr> and Planning app for organisations deploying teams in an outdoor environment.
</p>

<p class="text-center"><a class="btn btn-primary btn-lg" href="https://edilora.com">Go to Edilora</a></p>

Essentially, if you send people to go get lost in the mountains and have some sort of corporate responsibility over them (implied or otherwise) it will allow you to manage and document your risk assessment process, route planning and then monitor them in realtime using a variety of satellite trackers, low-data apps or predefined SMS <abbr title="Location Status Reports">locstats</abbr> messages. Using their near realtime locstats and predefined checkpoints you can see if they're on track to achieve objectives long before the objective is expected.

All that I've rolled out today is a [SPOT Tracker](https://www.findmespot.eu/en/) and [Strava](https://www.strava.com/) integration. You can <abbr title="">rebro</abbr> your incoming satellite tracking feed, package it as GPX and automatically upload it into Strava. You can also export existing activities from Strava as a track and visualise in Edilora. There is a roadmap to achieve the promised features above.

Why did I build Edilora? The idea spawned because I was going to walk the Cape Wrath Trail from Fort William to Cape Wrath. The route takes you through some very remote Scottish Highlands and I wanted to share the progress on Strava (don't judge me). I already owned a SPOT Tracker and had briefly looked at the [Strava API](https://strava.github.io/api/). I quickly knocked up a headless prototype and got it working. I used it on a couple of trips to Dartmoor and North Wales and it worked well. I know it's really niche but possibly, maybe others would want to use it. Clearly it was extremely niche and would never make an money. But it got me thinking...

I had used SPOT's own "shared page" tool, which allows you to share a live feed/stream on a very simple Google Map but was fairly unimpressed. I wanted a more extensive tool.

Edilora is broken down into two main strands "Planning" and "Operations". Planning will encapsulate all planning tasks it will have a master "expedition workflow" that walks you through all the risk management, resource management, objective/checkpoint and route planning. It's all about risk management and GIS data. Operations will be a bit like Uber "God Mode". See you team positions and stats and their joint progress towards the stated objectives. In the event of an incident there will be a incident management tool. For those who like or need to share (for corporate promotion) there will be various sharing and embedding features.

It's just baby steps at the moment but I hope the plan is sound and there is a market for it.

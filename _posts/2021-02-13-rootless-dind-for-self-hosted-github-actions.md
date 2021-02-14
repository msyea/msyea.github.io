---
title: Rootless DIND for self-hosted GitHub Actions runners
category: technology
tags: [rootless,docker,github,github-actions]
---
> TL;DR checkout [github-actions-runner](https://github.com/msyea/github-actions-runner) running with rootless DIND on ubunu


This post follows my earlier post [Self-hosted GitHub Actions on ECS](/technology/2021/01/07/self-hosted-github-actions-on-ecs.html).

On refection my earlier implementation of "docker ~~in~~ outside docker" had many flaws. It shared state between runners and would have resulted in container name, network and other collisions. I continued to search for another solution and discovered that was what I thought was “docker in docker” was in fact “docker outside docker”, and that there was another way.

Jérôme Petazzoni has written a great article, worryingly titled: [Do not use docker in docker for CI](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/) that discusses the two approaches in depth. I’ve carefully considered his advice and concluded that DIND (docker in docker) is still the most suitable approach to take. This is further validated; as I understand that it’s the approach that GitLab takes with it’s runners. The principle issue that affects us that needs further consideration is caching, which I will address in a future article. There is a nirvana which uses [sysbox](https://github.com/nestybox/sysbox), that provides adequate sandboxing but unfortunately, it doesn’t work on our target runtime ECS [yet](https://github.com/aws/containers-roadmap/issues/1072).

# That was emotional!

Trying to get GitHub Actions self-hosted runners on DIND has been a rollercoaster. There have been many so many ups and downs along the way. This article will probably not give it justice.

After reading Jérôme’s article, I started to look at [docker:20.10-dind](https://github.com/docker-library/docker/tree/master/20.10/dind) in depth. DIND uses [alpine:3.13](https://hub.docker.com/_/alpine/) as its base, a small, simple and secure Linux distro, which sometimes can be challenging to get complex applications to play nicely with. GitHub Actions runners are based on Azure Pipelines Agents, so installing the .NET Core dependencies could be challenging. Luckily it was a breeze, Alpine is a supported run time, and Microsoft produces both [scripted and manual installations](https://docs.microsoft.com/en-us/dotnet/core/install/linux-alpine). The next challenge was installing and running GitHub Actions runners. Unfortunately this proved impossible. Alpine is not a supported runtime, and I couldn’t hack the dependencies together contrary to the considerable effort I put in. There seemed to be an issue with libicu, a hurdle I couldn’t get over. I tried a variety of other package sources to no avail.

I began looking at other options after discussing the issues at length with colleagues. We decided that Alpine was probably a non-starter because it didn’t run simply and isn’t a supported runtime, which is not something we’d want to support in production.

Looking at the other supported platforms for GitHub Actions runner, ubuntu looked like the most suitable candidate. The question is - can you run DIND on ubuntu? Thankfully [cruizba/ubuntu-dind](https://github.com/cruizba/ubuntu-dind) had achieved such a feat! The game was back on.

I started fighting and managed to get get a clean image using a similar approach. Now to install GitHub Actions runner and cross my fingers - it worked. Whoop. Now, will it execute? Eh-eh. Negative. It won’t run as `root` user (without a flag - which I wasn’t going to use). Okay, quickly switch user, will it work? Whoop yes. It managed to register and wait for jobs. Will docker work? Again, crossing my fingers. Eh-eh. The action executed correctly but my user wasn’t in the docker group, so couldn’t use it. Facepalm moment. Try again. Now, I cannot remember the details - but I’m pretty sure this didn’t work because the runner refused to play nice with docker when it was run as `root` user - a good safety check. Note. I wasn’t looking for a completely secure setup as I was working on a proof of concept to see if this approach was feasible.

What now? Just toggle the flag and run all as `root`? I didn’t think this was acceptable - so I switched to the rootless approach.

[docker:20.10-dind-rootless](https://github.com/docker-library/docker/tree/master/20.10/dind-rootless) here we go! I copied the pattern but couldn’t get it to work… what’s the problem? Facepalm moment again. It needs access the linux kernel on the host and I was running a mac os. Something about [rslave](https://www.google.com/search?q=docker+The+host+root+filesystem+is+mounted+as+%22master:122%22.+Setting+child+propagation+to+%22rslave%22+is+not+supported) not working on the host filesystem.

I quickly jumped into AWS, spun up a Amazon Linux 2, installed docker and git and checkout out my code. OMG. It worked! I then spend a while rewriting my [Dockerfile](https://github.com/msyea/github-actions-runner/blob/main/Dockerfile) and it toggled from working to not working. What was going on? I discovered there was an issue with the `rootless` [user UID](https://www.google.com/search?q=error:+failed+to+setup+UID/GID+map:+newuidmap+39+%5B0+1000+1+1+100000+65536+65537+100000+65536%5D+failed:+newuidmap:+write+to+uid_map+failed:+Invalid+argument). I’m still not sure what the issue is. [Please, help](https://github.com/msyea/github-actions-runner/issues/10). But with a weird hack of adding a user at `1000` and a stroke of luck by letting `rootless` user get assigned `1001` it works.

I then spent the rest of the time using [myoung36s](https://github.com/myoung34/docker-github-actions-runner) pattern for dockerising GitHub Actions runner, and after installing a few more dependencies it appeared to work. I used it as a drop-in for my ECS approach in my [earlier article](/technology/2021/01/07/self-hosted-github-actions-on-ecs.html) and it is now working reliably.

A now here we are we have [github-actions-runner](https://github.com/msyea/github-actions-runner) running on ubuntu using rootless dind. I've learnt a hell of of a lot and am pretty happy with the outcome. Please share and if you can help us harden and fix the pending issues, please contribute and open a PR.

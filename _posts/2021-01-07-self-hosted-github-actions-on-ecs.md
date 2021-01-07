---
title: Self-hosted GitHub Actions on ECS
category: technology
tags: [github,ecs,github-actions]
---
GitHub Actions are awesome right? It's not perfect - but what tool is? IMHO you cannot beat the native integration with GitHub. 3rd party tools are no longer an option, the only option would be to move your whole life over to GitLab but I don't think that is worth it. If you're working on a large project or security focused you'll want to run a [self-hosted runner](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/about-self-hosted-runners).

I'm an AWS guy, so let's work out how to do this.

Looking at the docs the only real defficult requirement is docker. This is a bit of a bummer as my default choice would be to run the runner on kubernetes but they've recently [deprecated the docker runtime](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.20.md#deprecation)... You can run "docker in docker" by running a privileged container and mounting `/var/run/docker.sock`. In an AWS world this basically leaves us with ECS EC2 as the only option. Fargate would be ideal but you cannot run privileged containers there. ECS EC2 is is then.

The first step is to "dockerise" the GitHub, luckily @myoung34 has done this for us [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner).

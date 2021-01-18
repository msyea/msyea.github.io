---
title: Self-hosted GitHub Actions on ECS
category: technology
tags: [github,ecs,github-actions]
---
[GitHub Actions](https://github.com/features/actions) are awesome right? They're not perfect - but what tool is? Some 3rd party CICD tools are *probably better* but they would have to be **significantly better** to get over the native/3rd party barrier. After thoroughly reviewing features and competitors I don't think any 3rd party is signifantly better and the native integration is first class. For better functionality you would have to migrate completely (inc. VCS) to a different platform (eg. [GitLab](https://about.gitlab.com/)).

In order to use GitHub Actions at any scale you need to deploy [self-hosted runner](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/about-self-hosted-runners).

I'm an AWS guy, so let's work out how to do this.

Looking at the docs the only real difficult requirement is [docker](https://www.docker.com/). This is a bit of a bummer as my default choice would be to run the runner on kubernetes but they've recently [deprecated the docker runtime](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.20.md#deprecation)... In order to run the runner in docker you need to run "docker in docker" which is achieved by running a privileged container and mounting `/var/run/docker.sock`. In a managed AWS world this basically leaves us with ECS EC2 as the only option. I would have preferred Fargate but unfortunately you cannot run privileged containers there. ECS EC2 is is then.

Before we proceed we need to know some basics about the runners.

### How do Self-hosted GitHub Runners work?

GitHub Runners are a service that long polls GitHub for work. They reset the connection every 50 seconds. Before starting they need to be registered via the API and configured. They don't take incoming connections and just need to make outbound connections to GitHub (and any other dependencies). This is great as the runners don't need to be internet facing.

### Dockerisation

The first step is to "dockerise" the GitHub, luckily @myoung34 has done this for already [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner). His implementation takes some environment variables below, registers and starts the runner when the container is started.

### Environment Variables

A subset of @myoung34's environment variables:

| Environment Variable | Description |
| -------------------- | --- |
| `RUNNER_NAME_PREFIX` | A prefix for a randomly generated name (followed by a random 13 digit string). You must not also provide `RUNNER_NAME`. Defaults to `github-runner` |
| `ACCESS_TOKEN`       | A [github PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to use to generate `RUNNER_TOKEN` dynamically at container start. Not using this requires a valid `RUNNER_TOKEN` |
| `ORG_RUNNER`         | Only valid if using `ACCESS_TOKEN`. This will set the runner to an org runner. Default is 'false'. Valid values are 'true' or 'false'. If this is set to true you must also set `ORG_NAME` and makes `REPO_URL` unneccesary |
| `ORG_NAME`           | The organization name for the runner to register under. Requires `ORG_RUNNER` to be 'true'. No default value. |
| `LABELS`             | A comma separated string to indicate the labels. Default is 'default' |
| `RUNNER_GROUP`       | Name of the runner group to add this runner to (defaults to the default runner group) |

### Deploying to ECS

Deploying ECS had a couple gotchas/requirements:
* You have to put your docker hub credentials in AWS Secrets Manager to get around the rate limit funsies.
* You have to put your GitHub PAT in SSM to make it securely available to the task
* You need to spin up/deploy to a ECS cluster that can access GitHub and the outside world
* You need to consider/setup your ECS Instance Role, Execution Role and Task Roles in IAM


### Task Definition

This makes for a very straightforward ECS Task Definition:

<script src="https://gist.github.com/msyea/e1eeecafc80a431070ac7d7953886346.js"></script>

### GitHub Actions Settings

After you deploy the task definition as a x5 service to ECS you get:

<img src="/img/gha-settings.png" alt="github action settings" class="img-responsive img-thumbnail"/>

### Testing with a workflow

<script src="https://gist.github.com/msyea/be3b866e41325368569227c0b8540f39.js"></script>
### It works! 🎉

It successfully triggers the workflow and picks up the task role: `arn:aws:iam:::role/gha-taskrole`.

<img src="/img/gha-workflow1.png" alt="github workflow1" class="img-responsive img-thumbnail" />

But I have a gut feeling the "docker in docker" container might not go to plan:

<img src="/img/gha-workflow2.png" alt="github workflow2" class="img-responsive img-thumbnail" />

Boohoo 😭 It's picked up the `ecsInstanceRole`, not the Task Role. This makes total sense as the instance is created by docker, not ECS but it's annoying. How can we get around this?

I logged into the box and had a poke around with `docker inspect [container name/id]` and this showed me some useful environment variables provided by ECS:

| Environment Variable                     | Documentation |
| ---------------------------------------- | ------------- |
| `ECS_CONTAINER_METADATA_URI`             | https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint-v4.html |
| `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` | https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html |

As we can see from the self-titled environment variables, `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` looks like our saviour 🎉:

```bash
curl 169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
```
```json
{
    "AccessKeyId":     "ACCESS_KEY_ID",
    "Expiration":      "EXPIRATION_DATE",
    "RoleArn":         "TASK_ROLE_ARN",
    "SecretAccessKey": "SECRET_ACCESS_KEY",
    "Token":           "SECURITY_TOKEN_STRING"
}
```
We can easily parse the response and pass it into the "docker in docker" containers to give them the correct IAM Role. There is/will be a GitHub Action for this...

### Considerations and wrap up

Overall I'm pretty happy, it's a shame the roles don't magically work but that's somewhat expected. There're still a few unknowns: how to recycle runners (they persist between jobs - death would be better but this might affect performance), scaling strategies for the cluster instances/service count, how the GitHub Actions runner labels/groups work in reality and do any maintenance scripts need to get written?
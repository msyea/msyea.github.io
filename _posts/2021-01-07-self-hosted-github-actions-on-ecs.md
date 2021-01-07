---
title: Self-hosted GitHub Actions on ECS
category: technology
tags: [github,ecs,github-actions]
---
GitHub Actions are awesome right? They're not perfect - but what tool is? IMHO you cannot beat the native integration with GitHub. 3rd party tools are no longer an option, the only option would be to move your whole life over to GitLab but I don't think that is worth it. If you're working on a large project or security focused you'll want to run a [self-hosted runner](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/about-self-hosted-runners).

I'm an AWS guy, so let's work out how to do this.

Looking at the docs the only real defficult requirement is docker. This is a bit of a bummer as my default choice would be to run the runner on kubernetes but they've recently [deprecated the docker runtime](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.20.md#deprecation)... You can run "docker in docker" by running a privileged container and mounting `/var/run/docker.sock`. In an AWS world this basically leaves us with ECS EC2 as the only option. Fargate would be ideal but you cannot run privileged containers there. ECS EC2 is is then.

### How do Self-hosted GitHub Runners work?

GitHub Runners are a service that long polls GitHub for work. They reset the connection every 50 seconds. Before starting they need to be registered and configured.

The first step is to "dockerise" the GitHub, luckily @myoung34 has done this for already [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner). His implementation takes some environment variables below and registers and starts the runner when the container is started.

### Environment Variables

| Environment Variable | Description |
| --- | --- |
| `RUNNER_NAME` | The name of the runner to use. Supercedes (overrides) `RUNNER_NAME_PREFIX` |
| `RUNNER_NAME_PREFIX` | A prefix for a randomly generated name (followed by a random 13 digit string). You must not also provide `RUNNER_NAME`. Defaults to `github-runner` |
| `ACCESS_TOKEN` | A [github PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to use to generate `RUNNER_TOKEN` dynamically at container start. Not using this requires a valid `RUNNER_TOKEN` |
| `ORG_RUNNER` | Only valid if using `ACCESS_TOKEN`. This will set the runner to an org runner. Default is 'false'. Valid values are 'true' or 'false'. If this is set to true you must also set `ORG_NAME` and makes `REPO_URL` unneccesary |
| `ORG_NAME` | The organization name for the runner to register under. Requires `ORG_RUNNER` to be 'true'. No default value. |
| `LABELS` | A comma separated string to indicate the labels. Default is 'default' |
| `REPO_URL` | If using a non-organization runner this is the full repository url to register under such as 'https://github.com/myoung34/repo' |
| `RUNNER_TOKEN` | If not using a PAT for `ACCESS_TOKEN` this will be the runner token provided by the Add Runner UI (a manual process). Note: This token is short lived and will change frequently. `ACCESS_TOKEN` is likely preferred. |
| `RUNNER_WORKDIR` | The working directory for the runner. Runners on the same host should not share this directory. Default is '/_work'. This must match the source path for the bind-mounted volume at RUNNER_WORKDIR, in order for container actions to access files. |
| `RUNNER_GROUP` | Name of the runner group to add this runner to (defaults to the default runner group) |

This makes for a very straightforward ECS Task Definition:
```
{
  "ipcMode": null,
  "executionRoleArn": "arn:aws:iam:::role/gha-taskexecutionrole",
  "containerDefinitions": [
    {
      "dnsSearchDomains": null,
      "environmentFiles": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/gha",
          "awslogs-region": "eu-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "entryPoint": null,
      "portMappings": [],
      "command": null,
      "linuxParameters": null,
      "cpu": 0,
      "environment": [
        {
          "name": "ORG_NAME",
          "value": "msyea"
        },
        {
          "name": "ORG_RUNNER",
          "value": "true"
        },
        {
          "name": "RUNNER_NAME_PREFIX",
          "value": "ecs-msyea"
        }
      ],
      "resourceRequirements": null,
      "ulimits": null,
      "repositoryCredentials": {
        "credentialsParameter": "msyea/docker-hub"
      },
      "dnsServers": null,
      "mountPoints": [
        {
          "readOnly": null,
          "containerPath": "/var/run/docker.sock",
          "sourceVolume": "docker"
        }
      ],
      "workingDirectory": null,
      "secrets": [
        {
          "valueFrom": "/msyea/gha-pat",
          "name": "ACCESS_TOKEN"
        }
      ],
      "dockerSecurityOptions": null,
      "memory": null,
      "memoryReservation": 500,
      "volumesFrom": [],
      "stopTimeout": null,
      "image": "myoung34/github-runner:latest",
      "startTimeout": null,
      "firelensConfiguration": null,
      "dependsOn": null,
      "disableNetworking": null,
      "interactive": null,
      "healthCheck": null,
      "essential": true,
      "links": null,
      "hostname": null,
      "extraHosts": null,
      "pseudoTerminal": null,
      "user": null,
      "readonlyRootFilesystem": false,
      "dockerLabels": null,
      "systemControls": null,
      "privileged": true,
      "name": "runner-1"
    }
  ],
  "placementConstraints": [],
  "memory": null,
  "taskRoleArn": "arn:aws:iam:::role/gha-taskrole",
  "compatibilities": [
    "EC2"
  ],
  "taskDefinitionArn": "arn:aws:ecs:eu-west-2::task-definition/gha:1",
  "family": "gha",
  "requiresAttributes": [
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.logging-driver.awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.execution-role-awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.19"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.privileged-container"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.private-registry-authentication.secretsmanager"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.21"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.task-iam-role"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.secrets.ssm.environment-variables"
    }
  ],
  "pidMode": null,
  "requiresCompatibilities": [
    "EC2"
  ],
  "networkMode": null,
  "cpu": null,
  "revision": 1,
  "status": "ACTIVE",
  "inferenceAccelerators": null,
  "proxyConfiguration": null,
  "volumes": [
    {
      "fsxWindowsFileServerVolumeConfiguration": null,
      "efsVolumeConfiguration": null,
      "name": "docker",
      "host": {
        "sourcePath": "/var/run/docker.sock"
      },
      "dockerVolumeConfiguration": null
    }
  ]
}
```
---
title: Migrating to Sauce
category: technology
tags: [testing, integration-tests, sauce-labs, selenium]
---
Sauce Labs is an automated web and mobile testing cloud. They take on the difficulty of
managing browsers, VMs, devices and emulators and allow you to concentrate on code.

The principle reason we moved to Sauce Labs was that we could not easily run Internet Explorer in our test environment (licensing issues/linux host). Our test suite was based around running selenium/standalone-chrome (and Firefox) in a container via docker-compose. This worked well and was very performant. The debug versions of selenium/standalone allowed you to VNC into the container were especially helpful.

There are two options to using saucelabs: i). You provide public endpoints for saucelabs to hit (you can lock it down to their IP addresses) or ii). Use sauce connect proxy to set up a tunnel to your network. We opted for the latter option.

The application that we were testing was internal only and had no public endpoints. The significant engineering involved to consider this approach meant that it wasn’t really considered.

Switching to Sauce Labs using Sauce Connect Proxy is very easy; you switch the standalone container for docker-sauce-connect and change some configuration – it comes up on a different port and requires credentials and that’s (potentially) it!

That’s it (if you’re lucky). You’re now integrated with Sauce Labs. Unfortunately we weren’t so lucky – our tests would sometimes time out and were taking an age to run.

We were using webdriver and lots of custom assertions. Triggering something in the UI and then waiting for something observable to happen in the app state or a stub service state. These waiting assertions had a couple of issues with their implementation once the latency between our test environment (eu-west-1) and sauce labs (us-east-1) was introduced. I would recommend that you either use a higher level library (I hear webdriverio is very good) or use the built-in wait and until functions in webdriver to build robust assertions.

Once we had fixed all our assertions we had a reliable but very slow suite. How could we improve the speed? We had two problems; our suite was written using mocha and thus was being executed sequentially and network latency.

I’ve written a separate post on running mocha tests in parallel, so will stick with Sauce Labs latency here. Sauce Labs runs multiple data centres and docker-sauce-connect connects to a US data centre. Sauce Connect Proxy exposes the command line option `- x` or ` – rest-url <arg>`, which allows you to change the endpoint. Unfortunately henrrich’s dockerised version doesn’t expose this option, so it was essential to fork the repo and add it in.

Once we had changed to the European data centre the latency reduced to acceptable limits and we could use the webdriver API to add additional metadata to Sauce Labs – test names and statuses. This meant that we could now easily reconcile the failing tests in the test suite to the Sauce Labs UI and quickly fix the cross-browser issues.

The end result of this was we had a full suite of tests being executed in all the latest versions of browsers on a variety of devices. We now had the ability to debug the niche browser edge cases and had increased confidence in the reliability of our application. This increased insight identified a number of bugs that we had no idea about. These bugs would have been customer affecting and may have resulted in lost sales. Net result - happier (bug free) customer interactions and increased sales.

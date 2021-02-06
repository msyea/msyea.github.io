---
title: Running mocha tests in parallel
category: technology
tags: [testing, mocha]
---
Mocha by design runs tests in series. Often this is not efficient and you might want to
run some or all of the tests in parallel.

Mocha uses a wrapper executable under the hood, which runs the “real” _mocha executable. The _mocha executable is run via `require(‘child_process’).spawn`. See [bin/mocha](https://github.com/mochajs/mocha/blob/master/bin/mocha). This makes it easy to run tests in parallel, in their own child processes with their own environment. We had success in two scenarios: i). inspecting the content of the files for the presence of a function and choosing whether to run them in parallel or series and ii). running a selenium suite multiple times with different environment variables specifying different browser configurations.

Feel free to use the script below to make your own runner. It is heavily inspired by [bin/mocha](https://github.com/mochajs/mocha/blob/master/bin/mocha).

<script src="https://gist.github.com/msyea/c402de0c01e2de837153b2fa5e751f9f.js"></script>
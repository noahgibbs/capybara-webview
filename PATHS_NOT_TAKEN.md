# Paths Not Taken

Here are some approaches we attempted and abandoned...

## Forking a Child Process Worker

Weird bug on MacOS, but when trying to fork a worker and then run Webview, we get a fun error with this:

```
objc[53150]: +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called. We cannot safely call it or ignore it in the fork() child process. Crashing instead. Set a breakpoint on objc_initializeAfterForkError to debug.
```

It would appear it's a disagreement between how Ruby (and Python, and others) handle fork() and recent versions of MacOS. D'oh!

This can be fixed by running a different child process and connecting via socket instead of making the socket and forking. We had this problem with the Scarpe WebviewRelay display service, too...

## Fork and Minitest Override

Along the lines of minitest-parallel_fork, I tried forking in run_one_method, then using Capybara and Minitest there normally. Unfortunately, Webview wants to control the event loop via webview.run, which makes it hard for Capybara code to work in the obvious way.

It's possible to make this work, for instance by making the Capybara code using a Fiber and have Webview constantly call back from Javascript to advance the Fiber. But this is likely to cause way too much ugliness with other libraries. There's just too much magic under the covers to make this look like "normal" Minitest and Capybara code.

## Capybara::Webview::OuterMinitest

You could imagine a method call inside a Minitest::Test method (inside test_foo, call "webview_capybara_test") that would fork the process, run the Capybara Minitest code while attached to Webview, and pass the results back to the outer process. That's workable with Minitest's infrastructure... but not so great with Webview's.

To make this work you'd need to initialize Webview inside the subprocess, not the parent process. And in this case, setup would happen in the parent process. Oopsie. You *can* make this work, but it strongly encourages you to do it wrong and then have it crash later because you've tried to initialize Webview multiple times in a single (parent) process.

Not good.

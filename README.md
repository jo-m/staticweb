# Staticweb

Compile a directory of static web files (e.g. from a static web site generator like Hugo) into a single static binary, complete with web server.
Comes with two build systems, Bazel and Make.

**This is just an experiment, totally unsuitable and unsafe to use in production.**

Known limitations:

* Only tested on Ubuntu 18.04
* Does not work with empty files
* Does not work on with non-ASCII paths
* Spaces in file names?
* Encoded URLs don't work

## Build & run with `bazel`

```bash
# put your files here
mkdir webroot/

# compile and run
bazel run //:main
```

Open the website at [http://localhost:8888/](http://localhost:8888/).

## Build & run with `make`

Libmicrohttpd and its dependencies are linked dynamically.

```bash
# put your files here
mkdir webroot/

sudo apt-get install libmicrohttpd-dev
make
./build/main
```

Open the website at [http://localhost:8888/](http://localhost:8888/).

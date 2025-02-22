![Yarr](https://raw.github.com/brownplt/pyret-lang/master/img/pyret-banner.png)

Installing
-----------

This guide explains how to install and interface with the Anchor Pyret compiler.

### Setting up the environment

Using Linux or MacOS is highly recommended.

First, install npm, Node.js, git, and Python.

It is important to have a recent version of npm and Node.js. You can install a recent version 
of these by following the instructions at https://github.com/nodesource/distributions/blob/master/README.md

Install git and Python through your package manager.

Next, clone the pyret-lang repository from GitHub, and switch to the anchor branch.

```shell
~ $ git clone 'https://github.com/brownplt/pyret-lang.git'
~ $ cd pyret-lang
~/pyret-lang $ git checkout anchor
```

### Installing dependencies and launching the server

Install the required dependencies with npm.

```shell
~/pyret-lang $ npm install
```

Now, build the compiler, and its webworker library

```shell
~/pyret-lang $ make
```

```shell
~/pyret-lang $ npm run web
```

Next, start the server.

```shell
~/pyret-lang $ cd ide
~/pyret-lang/ide $ npm install
~/pyret-lang/ide $ npm start
```

This should open a new server in your browser.

### Compiling a program locally
Outputs a 'compiled' directory into the current working directory
``` shell
node /path/to/pyret-lang/build/phaseA --builtin-js-dir /path/to/pyret-lang/runtime --build-runnable /path/to/pyret/local-program
```

### Compiling a builtin Pyret module locally
Outputs a 'compiled' directory into the current working directory
``` shell
node /path/to/pyret-lang/build/phaseA --builtin-js-dir /path/to/pyret-lang/runtime --build-runnable /path/to/pyret/local-program --runtime-builtin-relative-path "../path/to/builtin/directory/at/runtime" --type-check [true|false]
```

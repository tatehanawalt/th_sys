<div align="center">

# TH_SYS #

Executable projects written in various languages

Find [Brew](https://brew.sh/) install instructions at  [tatehanawalt/homebrew-devtools](https://github.com/tatehanawalt/homebrew-devtools)

</div>

## Overview ##

Each project is a single project which can be built/compiled to a single binary (or java byte code) and installed/run with brew

### Project Criteria: ###

**Projects must have root level directories:**

  - `bin`

    - `build` - Executable file (described below) which builds the project to a tar file <name>.tar.gz

  - `doc`

    - `man`

      - `<project_name>.1` - Man 1 Page file for the project

#### Specific Project Files: ####

**`bin/build`** - Builds project binary or java byte code

**Params:**

  1. Project Path: `<path/to/this/repo>/<project>`

  2. Destination path: A directory where the build script must build the project to

  3. Build Version: Semver

**Exit Codes:**

  - **0**: Successfully packaged project to the destination path

  - **1**: Input error (invalid param count, format, or any input/context related issues)

  - **2**: Failed to build project for any other reason

<br>

**Build a project**

  1. `cd` to the root directory of one of the projects - `<path/to/repo>/<project`

  2. Create a directory where the project will build. try `<path/to/repo>/out` with `mkdir out`

  3. Run Build Command `./bin/build $(pwd) $(pwd)/out 0.0.0`

## Projects ##

[democ](https://github.com/tatehanawalt/th_sys/tree/main/democ)

[democpp](https://github.com/tatehanawalt/th_sys/tree/main/democpp)

[demogolang](https://github.com/tatehanawalt/th_sys/tree/main/demogolang)

[demonodejs](https://github.com/tatehanawalt/th_sys/tree/main/demonodejs)

[demopython](https://github.com/tatehanawalt/th_sys/tree/main/demopython)

[demozsh](https://github.com/tatehanawalt/th_sys/tree/main/demozsh)

[devenv](https://github.com/tatehanawalt/th_sys/tree/main/devenv)

[gaffer](https://github.com/tatehanawalt/th_sys/tree/main/gaffer)

## Development ##

**Generate Project README**

The readme is generated by running the script below with no arguments.

```shell
./.github/scripts/gen_readme.sh
```


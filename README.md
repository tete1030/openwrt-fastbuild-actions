Building OpenWrt with GitHub Actions and Docker
============================================================================

[中文说明](README_CN.md)

> I have largely optimized the main building process. It is now easier to use.
>
> This project is most useful for people who modify the compiling settings frequently, and may need to compile new packages from time to time. It by default does not update OpenWrt's and packages' source code every time it builds (unless you specified), because doing so harms incremental building‘s utility and stability.
> 
> If you don't like this, do not care about long compiling duration, or feel that the following instructions are complex, check out [P3TERX's Actions-Openwrt](https://github.com/P3TERX/Actions-OpenWrt) or [KFERMercer's OpenWrt-CI](https://github.com/KFERMercer/OpenWrt-CI). They are very easy to use except for the compiling duration.


This project is inspired by [P3TERX's Actions-Openwrt](https://github.com/P3TERX/Actions-OpenWrt).

With Github Actions and Actions-Openwrt, it is easy to build an OpenWrt firmware without running locally. However, Github Actions do not store cache and building files. This means it has to completely rebuild from source each time, even if it is a small change.

This project uses Docker Hub or any Docker registriy for storing previous building process, allowing incremental building.

- [Building OpenWrt with GitHub Actions and Docker](#building-openwrt-with-github-actions-and-docker)
  - [Features](#features)
  - [Usage](#usage)
    - [Basic usage](#basic-usage)
      - [First-time building](#first-time-building)
        - [Secrets page](#secrets-page)
      - [Following building](#following-building)
    - [Advanced usage](#advanced-usage)
      - [Re-create your building environment](#re-create-your-building-environment)
      - [Rebase your building environment](#rebase-your-building-environment)
      - [Manually trigger building and its options](#manually-trigger-building-and-its-options)
        - [Global options](#global-options)
        - [Options only for build-inc](#options-only-for-build-inc)
        - [Options only for build-package](#options-only-for-build-package)
        - [Examples](#examples)
          - [Use github-repo-dispatcher to rebase building environment](#use-github-repo-dispatcher-to-rebase-building-environment)
          - [Use commit message to re-create building environment](#use-commit-message-to-re-create-building-environment)
  - [Details](#details)
    - [Mechanism](#mechanism)
    - [Success building job examples](#success-building-job-examples)
    - [Building process explained](#building-process-explained)
      - [build-inc](#build-inc)
      - [build-package](#build-package)
  - [Debug and manually configure](#debug-and-manually-configure)
  - [FAQs](#faqs)
    - [Why I cannot see any tag on Docker Hub website?](#why-i-cannot-see-any-tag-on-docker-hub-website)
    - [How to add my own packages and do other customizations? (Chinese)](#how-to-add-my-own-packages-and-do-other-customizations-chinese)
  - [Todo](#todo)
  - [Acknowledgments](#acknowledgments)
  - [License](#license)

## Features

- Load and save building state to Docker Hub or other registries
- Support building options
- Various trigger methods
  - Push with commands in commit messages
  - Deployment events (you can use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher))
  - Repository dispatch events (you can use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher))
  - Your repo been starred by yourself
  - Scheduled cron jobs
- Two building modes (before colons are job names of Github Actions)
  - `build-inc`: Incrementally building firmware and packages (every push, about 40 minutes for standard config, about 3 hours for first-time building)
  - `build-package`: Incrementally building only packages (every push, about 25 minutes for standard config, useful when only enabling a package module)
- Handy debugging and manual configuration through SSH (e.g. `make menuconfig`)

## Usage

**The default configuration uses [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) as the OpenWrt Repo** (popular in China). If you want official OpenWrt 19.07, check out ["openwrt_official" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/openwrt_official). (It's just changes of `REPO_URL` and `REPO_BRANCH` envs in `.github/workflows/build-openwrt.yml`.)

Check out my own configuration in ["sample" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/sample).

### Basic usage

#### First-time building

The building process generally takes **1.5~3 hours** depending on your config.

1. Sign up for [GitHub Actions](https://github.com/features/actions/signup)
2. Fork this repo
3. **Register a Docker Hub account**. This is necessary.
4. Get your Docker Hub **personal access token**. Fill your username and the generated token into the forked repo's **Settings->Secrets** page. Use `docker_username` for your username, and `docker_password` for your token. See [Secrets page](#secrets-page) for correct settings.
5. *(Optional, for debug)* Set `SLACK_WEBHOOK_URL` or `TMATE_ENCRYPT_PASSWORD` in the Secrets page. Refer to [Debug and manually configure](#debug-and-manually-configure).
6. *(Optional)* Customize `.github/workflows/build-openwrt.yml` to **change builder's name and other options**.
7. **Generate your `.config`** and rename it to `config.diff`. Put the file in the `user` dir of your forked repo.
8. *(Optional)* Customize `scripts/update_feeds.sh` for **additional packages** you want to download.
9. *(Optional)* Put any **patch** you want to `user/patches` dir. The patches are applied after `update_feeds.sh` and before `download.sh`.
10. **Commit and push** your changes. This will automatically trigger an incremental building.
11. Wait for `build-inc` job to finish.
12. Collect your files in the `build-inc` job's `Artifacts` menu

##### Secrets page

![Secrets page](imgs/secrets.png)

#### Following building

After the first-time building, you will only need the following steps to build your firmwares and packages when you change your config. The building process generally only takes **20 minutes ~ 1 hour** depending on how much your config has changed.

1. *(Optional)* Modify your `user/config.diff` if you want.
2. *(Optional)* Customize `scripts/update_feeds.sh` for **additional packages** you want to download.
3. *(Optional)* Put any **patch** you want to `user/patches` dir.
4. Commit and push your changes. If you want to do `build-inc`, you don't need any special step. If you need `build-package`, you can include this string in your last commit message before push: `#build-package#`.
5. Wait for `build-inc` or `build-package` to finish
6. Collect your files in the `build-inc` or `build-package` job's "Artifacts" menu

### Advanced usage

The following contents require your understanding of the mechanism. See [Mechanism](#mechanism).

#### Re-create your building environment

If you have largely modified your configurations, incremental building may fail as there could be old configurations remained. It's better to completely re-create your builder. You can specify the `rebuild` building option to achieve this. For usage of building options, refer to [Manually trigger building and its options](#manually-trigger-building-and-its-options).


Technically, this is to "re-create your base builder". For definition of "base builder", refer to [Mechanism](#mechanism).

#### Rebase your building environment

Sometimes, you don't need to re-create the base builder. You just need to link previous base builder to current "incremental builder".

Because the incremental builders used in `build-inc` and `build-package` jobs are reusing previous building state, the builder image may grow larger and larger. The builder itself could also fall into some error state. If so, you can re-link them from the base builder.

For rebase `build-inc`, you can use the `use_base` option to base it on the base builder.

For rebase `build-package`, you can use the `use_base` option to base it on the base builder, or you can use the `use_inc` option to base it on previous incremental builder used in `build-inc`.

#### Manually trigger building and its options

There are two methods for manually triggering and specifying building options:
- Use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher).
  - Repository dispatch event ("Repo Dispatch" button, only support "master" branch)
    - Specify your job name in the "Type" prompt
    - Fill your options in the "Payload" prompt (in JSON), or leave "Payload" empty when no option is needed
  - Deployment event ("Deploy" button, support any commit/branch/tag)
    - Specify your job name in the "Task" prompt
    - Specify your branch in the "Ref" prompt
    - Fill your options in the "Payload" prompt (in JSON), or leave "Payload" empty when no option is needed
- Including your command and options in your commit message (it must be the commit right before the push)
  - You can specify your job name by including a string "#JOB_NAME#" in your latest commit message, e.g. `#build-package#`
  - You can enable boolean options by including a string "#BOOL_OPTION_NAME#" in your latest commit message, e.g. `#debug#`
  - You can combine job name and options. e.g. `#build-package##debug#` or `#build-package#debug#` are both acceptable (because `indexOf(commit_message, '#JOB_OR_OPT#')` is used for searching them).

All boolean options are by default `false`. The following are options available.

##### Global options

- `debug`(bool): entering tmate during and after building, allowing you to SSH into the docker container and Actions. See [Debug and manually configure](#debug-and-manually-configure) for detailed usage.
- `push_when_fail`(bool): always save the builder to Docker Hub even if the building process fails. Not recommended to use

##### Options only for `build-inc`

- `rebuild`(bool): re-create the building environment completely
- `update_repo`(bool): do `git pull` on main repo. It could fail if any tracked file of the repo has changed.
- `update_feeds`(bool): do `git pull` on feeds and your manually added packages. It could fail if any tracked file changed.
- `use_base`(bool): instead of using the job's own previous builder, use latest base builder

##### Options only for `build-package`

- `update_feeds`(bool): same to previous section
- `use_base`(bool): same to previous section
- `use_inc`(bool): instead of using the job's own previous builder, use latest incremental builder generated by `build-inc`

##### Examples

###### Use github-repo-dispatcher to rebase building environment

To trigger rebasing the incremental builder with SSH debugger enabled:
1. Open your forked repo
2. Click "Repo Dispatch" or "Deploy" at the top right corner (install at [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher))
3. Fill `build-inc` in "Type/Task" prompt
4. If using "Deploy" trigger, fill your branch/tag/commit in "Ref" prompt (e.g. `master`)
5. Fill `{"use_base": true, "debug": true}` in "Payload" prompt
6. Open the job's log page, wait for the SSH command showing up (when debugging, you are allowed to SSH into the job's runner, with the help of tmate.io)

###### Use commit message to re-create building environment

1. Save all the files you changed
2. At the last commit before push, commit with message "some message #build-inc#rebuild# some message"
3. Push
4. Wait for jobs to finish

## Details

### Mechanism

[TODO] Probably a figure is better

For convenience, assume docker image for storing builder
- `IMAGE_NAME=tete1030/openwrt_x86_64` (abbreviated to `t/o`)
- `IMAGE_TAG=latest`

There are three builders:

- When doing first-time building or rebuilding, the `build-inc` mode setups "base builder" and builds OpenWrt freshly. It produces a firmware and a "base builder". The builder is named as `t/o:latest` and stored in Docker Hub. It is further linked to `t/o:latest-inc`, which is an incremental build used for future use.
- For every push, the `build-inc` mode setups "incremental builder `t/o:latest-inc`" based on its own previous "incremental builder `t/o:latest-inc`" (same name). This mode builds a new firmware and packages. Finally it saves back the new builder to Docker Hub, overwriting the old one.
- For every push, the `build-package` mode setups "incremental builder `t/o:latest-package`" based on its own previous "incremental builder `t/o:latest-package`" (same name). If the previous one does not exist, it uses the base builder. This mode only builds packages (*.ipkg), no firmware is built. Finally it saves back the new builder to Docker Hub, overwriting the old one.

### Success building job examples

[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede):
- [`build-base` (deprecated)](https://github.com/tete1030/openwrt-fastbuild-actions/runs/359974704)
- [`build-inc`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360084146)
- [`build-package`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360084313)

[openwrt/openwrt;openwrt-19.07](https://github.com/openwrt/openwrt/tree/openwrt-19.07):
- [`build-base` (deprecated)](https://github.com/tete1030/openwrt-fastbuild-actions/commit/7757f6741a804b84f2f6fa6c03272e322ce6a8e9/checks?check_suite_id=370526615)
- [`build-inc`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360106903)
- [`build-package`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360107046)

### Building process explained

I'll now explain here the detailed building process of each mode.

#### `build-inc`

1. Pull `${BUILDER_NAME}:${BUILDER_TAG}-inc` from Docker Hub. If the tag does not exist or `use_base` building option is set, link `${BUILDER_NAME}:${BUILDER_TAG}` to `${BUILDER_NAME}:${BUILDER_TAG}-inc`. If `${BUILDER_NAME}:${BUILDER_TAG}` also does not exist, set building option `rebuild` to `true`.
2. `initenv.sh`, set up building environment only when `rebuild`.
3. `update_repo.sh`. It will do `git clone` or `git pull` for main repo only when `update_repo` or `rebuild` option is set
4. `update_feeds.sh`. It will download you manually added packages, and do `git pull` for existing packages only when `update_feeds` option is set.
5. `customize.sh`. Apply patches only when a patch has not been already applied. Load `user/config.diff` to `.config`, execute `make defconfig`
6. `download.sh`, download/update package source code that are not already downloaded
7. `compile.sh`, Multi/single-thread compile
8. Save this new builder to Docker Hub's `${BUILDER_NAME}:${BUILDER_TAG}-inc`. If `rebuild`, link it back to `${BUILDER_NAME}:${BUILDER_TAG}`
9. Copy out from docker and upload files to Artifacts
    - `OpenWrt_bin`: all binaries files, including packages and firmwares
    - `OpenWrt_firmware`: firmware only

#### `build-package`

1. Pull `${BUILDER_NAME}:${BUILDER_TAG}-package` from Docker Hub. If the tag does not exist or when `use_base` option is set, link current `${BUILDER_NAME}:${BUILDER_TAG}` to `${BUILDER_NAME}:${BUILDER_TAG}-package` (Or link `${BUILDER_NAME}:${BUILDER_TAG}-inc` to `${BUILDER_NAME}:${BUILDER_TAG}-package` when the `use_inc` option is set)
2. Unlike other building processes, `update_repo.sh` is not executed
3. `update_feeds.sh`. It will always download you manually added packages, and do `git pull` for existing packages only when `update_feeds` option is set.
4. `customize.sh`, apply patches only when a patch has not been already applied
5. `download.sh`, download/update package source code that are not already downloaded
6. `compile.sh`, Multi/single-thread compile
7. Save this new builder to Docker Hub's `${BUILDER_NAME}:${BUILDER_TAG}-package`
8. Upload files to Artifacts
    - `OpenWrt_packages`: all packages
    - `OpenWrt_new_packages`: only newly produced packages of this building

## Debug and manually configure

Thanks to [tmate](https://tmate.io/), you can enter into both the docker containers and GitHub Actions runners through SSH to debug and manually change your configuration, e.g. `make menuconfig`. To enter the mode, you have to enable the building option: `debug`. See [Manually trigger building and its options](#manually-trigger-building-and-its-options) for methods of using options.

For safety of your sensitive information, you **must** either set `SLACK_WEBHOOK_URL` or `TMATE_ENCRYPT_PASSWORD` in the **Secrets** page to protect the tmate connection info. Refer to [tete1030/safe-debugger-action/README.md](https://github.com/tete1030/safe-debugger-action/blob/master/README.md) for details.

Note that the configuration changes you made should only be for **temporary use**. Though your changes in the docker container will be saved to Docker Hub, there are situations where you manual configuration may lost:
1. The `rebuild` option is set to completely rebuild your base builder and rebase the incremental builder
2. The `use_base` or `use_inc` option is set to rebase the incremental builder
3. Some files will be overwriten during every building. For example, if you have executed `make menuconfig` in the container, the changes of the `.config` file will be saved. But during next building, the `user/config.diff` file in this repo will be copied to `.config`. This will overwrite your previous changes.

To make permanent changes, it is still recommended to use the `user/config.diff` file and other customization methods provided in this repo.

## FAQs

### Why I cannot see any tag on Docker Hub website?

All tags actually exist but could be invisible. Caused by known problem of buildx:
- https://github.com/docker/hub-feedback/issues/1906
- https://github.com/docker/buildx/issues/173

### How to add my own packages and do other customizations? (Chinese)

[Wiki-如何添加自定义安装包？](https://github.com/tete1030/openwrt-fastbuild-actions/wiki/%E5%A6%82%E4%BD%95%E6%B7%BB%E5%8A%A0%E8%87%AA%E5%AE%9A%E4%B9%89%E5%AE%89%E8%A3%85%E5%8C%85%EF%BC%9F)

## Todo

- [x] Merge building modes to simplify the process
- [ ] SSH into docker container instead of just the runner (for `make menuconfig`)
- [x] Allow customizing trigger event
- [x] Allow specify building job in commit message
- [x] Automatically linking from base builder to builders for `build-inc` and `build-package` when not existing
- [ ] Optimize README
  - [x] Simplfy documentation
  - [ ] Add Chinese version of "Usage"
  - [ ] Add a figure to "Mechanism"
  - [x] Describe mechanism
  - [x] Describe building process
  - [x] Describe using [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to trigger building with extra options
- [x] Optimize comments in `build-openwrt.yml` and `docker.sh`
- [x] Optimize `build-openwrt.yml`, making options cleaner
- [ ] Allow deterministic building (by fixing commit of main repo and feeds)

## Acknowledgments

- [P3TERX's Actions-Openwrt](https://github.com/P3TERX/Actions-OpenWrt)
- [crazy-max/ghaction-docker-buildx](https://github.com/crazy-max/ghaction-docker-buildx)
- [Docker Hub](https://hub.docker.com/)
- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [tmate](https://github.com/tmate-io/tmate)
- [mxschmitt/action-tmate](https://github.com/mxschmitt/action-tmate)
- [csexton/debugger-action](https://github.com/csexton/debugger-action)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean's OpenWrt](https://github.com/coolsnowwolf/lede)

## License

Most files under

[MIT](https://github.com/tete1030/openwrt-fastbuild-actions/blob/master/LICENSE) © Texot

Original idea and some files under

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE) © P3TERX

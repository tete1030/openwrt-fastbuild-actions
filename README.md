Building OpenWrt with GitHub Actions and Docker
============================================================================

> I largely optimized the main building process. It is now easier to use.

This project is inspired by [P3TERX's Actions-Openwrt](https://github.com/P3TERX/Actions-OpenWrt).

With Github Actions and Actions-Openwrt, it is easy to build an OpenWrt firmware without running locally. However, Github Actions do not store cache and building files. This means it has to completely rebuild from source each time, even if it is a small change.

This project uses Docker Hub or any Docker registriy for storing previous building process, allowing incremental building.

Github Actions和Actions-Openwrt让我们可以很方便地自动化编译OpenWrt固件，而不必在本地编译。然而Github Actions不存储缓存，已编译过的文件也不会在下次编译重新被使用。这就意味着，即便只是很小的改动，每次编译我们要等上很久来重新编译整个固件。

本项目使用Docker Hub或任何Docker Registry存储编译状态，使得后续的编译可以增量进行。

- [Building OpenWrt with GitHub Actions and Docker](#building-openwrt-with-github-actions-and-docker)
  - [Features 特点](#features-%e7%89%b9%e7%82%b9)
  - [Usage 用法](#usage-%e7%94%a8%e6%b3%95)
    - [Basic usage 基础用法](#basic-usage-%e5%9f%ba%e7%a1%80%e7%94%a8%e6%b3%95)
      - [First-time building 第一次编译](#first-time-building-%e7%ac%ac%e4%b8%80%e6%ac%a1%e7%bc%96%e8%af%91)
        - [Secrets page](#secrets-page)
      - [Following building 后续编译](#following-building-%e5%90%8e%e7%bb%ad%e7%bc%96%e8%af%91)
    - [Advanced usage 高级用法](#advanced-usage-%e9%ab%98%e7%ba%a7%e7%94%a8%e6%b3%95)
      - [Re-create your building environment 重建编译环境](#re-create-your-building-environment-%e9%87%8d%e5%bb%ba%e7%bc%96%e8%af%91%e7%8e%af%e5%a2%83)
      - [Rebase your building environment 重设编译环境](#rebase-your-building-environment-%e9%87%8d%e8%ae%be%e7%bc%96%e8%af%91%e7%8e%af%e5%a2%83)
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
  - [FAQs](#faqs)
    - [Why I cannot see any tag on Docker Hub website?](#why-i-cannot-see-any-tag-on-docker-hub-website)
  - [Todo](#todo)
  - [Acknowledgments](#acknowledgments)
  - [License](#license)

## Features 特点

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

----

- 在Docker Hub或其他Registry加载和存储OpenWrt编译状态
- 支持编译选项
- 多种触发模式
  - Push触发，支持在commit message中包含指令
  - Deployment事件触发（可使用[tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher)）
  - Repository dispatch事件触发（可使用[tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher)）
  - 自己给自己Star触发（可指定Star的触发者）
  - 定时触发
- 两个编译模式（冒号前是Github Actions中的job名称）
  - `build-inc`：增量编译固件和软件包（每次push自动进行，标准配置下大约每次40分钟，第一次编译时耗时大约3小时）
  - `build-package`：增量编译软件包（每次push自动进行，标准配置下大约每次25分钟，当仅需要编译软件安装包时比较有用）

## Usage 用法

**The default configuration uses [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) as the OpenWrt Repo** (popular in China). If you want official OpenWrt 19.07, check out ["openwrt_official" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/openwrt_official). (It's just changes of `REPO_URL` and `REPO_BRANCH` envs in `.github/workflows/build-openwrt.yml`.)

Check out my own configuration in ["sample" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/sample).

### Basic usage 基础用法

#### First-time building 第一次编译

The building process generally takes **1.5~3 hours** depending on your config.

1. Sign up for [GitHub Actions](https://github.com/features/actions/signup)
2. Fork this repo
3. **Register a Docker Hub account**. This is necessary.
4. Get your Docker Hub **personal access token**. Fill your username and the generated token into the forked repo's **Settings->Secrets** page. Use `docker_username` for your username, and `docker_password` for your token. See [Secrets page](#secrets-page) for correct settings.
5. *(Optional, not very useful)* If you want the debug SSH command to be sent to Slack, you can generate a Slack Webhook URL and set the url as `SLACK_WEBHOOK_URL` in the Secrets page. Search in Google if you don't know how to do it.
6. *(Optional)* Customize `.github/workflows/build-openwrt.yml` to **change builder's name and other options**.
7. **Generate your `.config`** and rename it to `config.diff`. Put the file in the root dir of your forked repo.
8. *(Optional)* Customize `scripts/update_feeds.sh` for **additional packages** you want to download.
9. *(Optional)* Put any **patch** you want to `patches` dir. The patches are applied after `update_feeds.sh` and before `download.sh`.
10. **Commit and push** your changes. This will automatically trigger an incremental building.
11. Wait for `build-inc` job to finish.
12. Collect your files in the `build-inc` job's `Artifacts` menu

----

1. 注册[GitHub Actions](https://github.com/features/actions/signup)
2. Fork
3. **注册Docker Hub**. 这步很重要
4. 取得Docker Hub的**personal access token**。在你自己Fork的Repo中的**Settings->Secrets**页面填写你的Docker Hub用户名和token。使用“docker_username”填写用户名，使用“docker_password”填写token。详见[Secrets page](#secrets-page)。
5. *(可选，没什么用)* 如果你想自动把SSH命令发送到Slack，你可以在Secrets页面设置`SLACK_WEBHOOK_URL`。详细方法请自行Google。
6. *(可选)* 定制`.github/workflows/build-openwrt.yml`以修改你想在Docker Hub保存的**builder名和其他选项**。
7. **生成你的`.config`文件**，并把它重命名为`config.diff`。把它放在根目录。
8. *(可选)* 如果你想**放置额外安装包**，定制`scripts/update_feeds.sh`。
9. *(可选)* 在patches目录放置**补丁文件**。补丁会自动在`update_feeds.sh`之后，`download.sh`之前执行。
10. **Commit并Push**。这一步骤会自动触发编译。
11. 等待`build-inc`任务完成。
12. 在`build-inc`任务的`Artifacts`目录下载编译好的文件。

##### Secrets page

![Secrets page](imgs/secrets.png)

#### Following building 后续编译

After the first-time building, you will only need the following steps to build your firmwares and packages when you change your config. The building process generally only takes **20 minutes ~ 1 hour** depending on how much your config has changed.

1. *(Optional)* Modify your `config.diff` if you want.
2. *(Optional)* Customize `scripts/update_feeds.sh` for **additional packages** you want to download.
3. *(Optional)* Put any **patch** you want to `patches` dir.
4. Commit and push your changes. If you want to do `build-inc`, you don't need any special step. If you need `build-package`, you can include this string in your last commit message before push: `#build-package#`.
5. Wait for `build-inc` or `build-package` to finish
6. Collect your files in the `build-inc` or `build-package` job's "Artifacts" menu

----

1. *(可选)* 根据需要修改你的`config.diff`
2. *(可选)* 根据需要修改你的`scripts/update_feeds.sh`
3. *(可选)* 根据需要添加新的补丁至patches目录
4. Commit并Push。如果你想执行`build-inc`任务，你不需要进行任何特殊操作。如果你需要执行`build-package`，你可以在Push前的最后一个commit message中包含这一字符串：`#build-package#`
5. 等待`build-inc`或`build-package`完成
6. 在“Artifacts”目录收集文件

### Advanced usage 高级用法

The following contents require your understanding of the mechanism. See [Mechanism](#mechanism).

#### Re-create your building environment 重建编译环境

If you have largely modified your configurations, incremental building may fail as there could be old configurations remained. It's better to completely re-create your builder. You can specify the `rebuild` building option to achieve this. For usage of building options, refer to [Manually trigger building and its options](#manually-trigger-building-and-its-options).


Technically, this is to "re-create your base builder". For definition of "base builder", refer to [Mechanism](#mechanism).

#### Rebase your building environment 重设编译环境

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

- `debug`(bool): entering tmate during and after building, allowing you to SSH into the Actions
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

To trigger rebase the incremental builder with SSH debugger enabled:
1. Open your forked repo
2. Click "Repo Dispatch" or "Deploy" at the top right corner (install at [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher))
3. Fill `build-inc` in "Type/Task" prompt
4. If using "Deploy" trigger, fill your branch/tag/commit in "Ref" prompt (e.g. `master`)
5. Fill `{"use_base": true, "debug": true}` in "Payload" prompt
6. Open the job's log page, wait for the SSH command showing up (when debugging, you are allowed to SSH into the job's runner, with the help of tmate.io)

##### Use commit message to re-create building environment

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
- For every push, the `build-inc` mode setups "incremental builder `t/o:latest-inc`" based on its own previous "incremental builder `t/o:latest-inc`" (same name). It also builds a new firmware. Finally it saves back the new builder to Docker Hub, overwriting the old one.
- For every push, the `build-package` mode setups "incremental builder `t/o:latest-package`" based on its own previous "incremental builder `t/o:latest-package`" (same name). If the previous one does not exist, it uses the base builder. This mode also builds packages (*.ipkg). Finally it saves back the new builder to Docker Hub, overwriting the old one.

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
5. `customize.sh`. Apply patches only when a patch has not been already applied. Load `config.diff` to `.config`, execute `make defconfig`
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

## FAQs

### Why I cannot see any tag on Docker Hub website?

All tags actually exist but could be invisible. Caused by known problem of buildx:
- https://github.com/docker/hub-feedback/issues/1906
- https://github.com/docker/buildx/issues/173

## Todo

- [x] Merge three building modes into one to simplify the process
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

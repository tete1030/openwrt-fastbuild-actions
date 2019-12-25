Building OpenWrt with GitHub Actions and Docker
============================================================================

> Due to the complexity of using, I'm creating an auto mode to cover most use cases. 
> 由于本项目用起来稍显复杂，正在创建一个全自动模式以迎合大多数情况的需求。
> More information: [#4](https://github.com/tete1030/openwrt-fastbuild-actions/issues/4)

This project is inspired by [P3TERX's Actions-Openwrt](https://github.com/P3TERX/Actions-OpenWrt).

With Github Actions and Actions-Openwrt, it is easy to build an OpenWrt firmware without running locally. However, Github Actions do not store cache and building files. This means it has to completely rebuild from source each time, even if it is a small change.

This project uses Docker Hub or any Docker registriy for storing previous building process, allowing incremental building.

Github Actions和Actions-Openwrt让我们可以很方便地自动化编译OpenWrt固件，而不必在本地编译。然而Github Actions不存储缓存，已编译过的文件也不会在下次编译重新被使用。这就意味着，即便只是很小的改动，每次编译我们要等上很久来重新编译整个固件。

本项目使用Docker Hub或任何Docker Registry存储编译状态，使得后续的编译可以增量进行。

- [Building OpenWrt with GitHub Actions and Docker](#building-openwrt-with-github-actions-and-docker)
  - [Features 特点](#features-%e7%89%b9%e7%82%b9)
  - [Mechanism 原理](#mechanism-%e5%8e%9f%e7%90%86)
  - [Usage 用法](#usage-%e7%94%a8%e6%b3%95)
    - [First-time building 第一次编译](#first-time-building-%e7%ac%ac%e4%b8%80%e6%ac%a1%e7%bc%96%e8%af%91)
      - [Secrets page](#secrets-page)
    - [Following building 后续编译](#following-building-%e5%90%8e%e7%bb%ad%e7%bc%96%e8%af%91)
    - [Re-create your base builder 重建基础构建器](#re-create-your-base-builder-%e9%87%8d%e5%bb%ba%e5%9f%ba%e7%a1%80%e6%9e%84%e5%bb%ba%e5%99%a8)
    - [Re-create your incremental builders 重建增量构建器](#re-create-your-incremental-builders-%e9%87%8d%e5%bb%ba%e5%a2%9e%e9%87%8f%e6%9e%84%e5%bb%ba%e5%99%a8)
    - [Manually trigger building and its options](#manually-trigger-building-and-its-options)
      - [Global options](#global-options)
      - [Options only for build-inc](#options-only-for-build-inc)
      - [Options only for build-package](#options-only-for-build-package)
      - [Examples](#examples)
  - [Details](#details)
    - [Success building job examples](#success-building-job-examples)
    - [Building process explained](#building-process-explained)
      - [build-base](#build-base)
      - [build-inc](#build-inc)
      - [build-package](#build-package)
  - [FAQs](#faqs)
    - [Why I cannot see any tag on Docker Hub website?](#why-i-cannot-see-any-tag-on-docker-hub-website)
    - [[Fixed] Spend so much time on &quot;Copy out bin directory&quot; in build-base (Original docker-build)](#fixed-spend-so-much-time-on-quotcopy-out-bin-directoryquot-in-build-base-original-docker-build)
  - [Todo](#todo)
  - [Acknowledgments](#acknowledgments)
  - [License](#license)

## Features 特点

- Load and save building state to Docker Hub or other registries
- Load and save base builder cache to Docker Hub or other registries
- Three building modes in parallel (before colons are job names of Github Actions)
  - `build-base`: Completely rebuilding firmware and packages (every release, long period if code has changed)
  - `build-inc`: Incrementally building firmware and packages (every push, short period)
  - `build-package`: Incrementally building only packages (every push, short period, useful when only enabling a package module)

----

- 在Docker Hub或其他Registry加载和存储OpenWrt编译状态
- 在Docker Hub或其他Registry加载和存储用于构建“基础构建器”的缓存
- 三个编译模式平行进行（冒号前是Github Actions中的job名称）
  - `build-base`：完全重编译固件和软件包（每次release自动进行，如果代码更新会很耗时）
  - `build-inc`：增量编译固件和软件包（每次push自动进行，耗时相对较短）
  - `build-package`：增量编译软件包（每次push自动进行，耗时相对较短，当仅需要编译软件安装包时比较有用）

## Mechanism 原理

[TODO] Probably a figure is better

For convenience, assume docker image for storing builder
- `IMAGE_NAME=tete1030/openwrt_x86_64` (abbreviated to `t/o`)
- `IMAGE_TAG=latest`

The **three building modes**:

- For every release, the `build-base` mode setups "base builder" and builds OpenWrt freshly. It produces a firmware and a "base builder". The builder is named as `t/o:latest` and stored in Docker Hub.<sup>1</sup><sup>2</sup>
- For every push, the `build-inc` mode setups "incremental builder `t/o:latest-inc`" based on its own previous "incremental builder `t/o:latest-inc`" (same name). It also builds a new firmware. Finally it saves back the new builder to Docker Hub, overwriting the old one.<sup>2</sup>
- For every push, the `build-package` mode setups "incremental builder `t/o:latest-package`" based on its own previous "incremental builder `t/o:latest-package`" (same name). It also builds packages (*.ipkg). Finally it saves back the new builder to Docker Hub, overwriting the old one.<sup>2</sup>

<sup>[1] *For `build-base` mode, there are also an intermediate builder `t/o:latest-build` and cache `t/o:latest-buildcache`、`t/o:latest-cache`. You don't need to care them.*</sup>
<sup>[2] *For all modes, there are also test builders `t/o:test-latest*`. You don't need to care them.*</sup>

You may notice that until now the three builders are not connected. The latter two builders actually relies on pulling from the first builder:

- For first time building of `build-inc` mode, `t/o:latest` builder is used as the basis builder, rather than the default basis `t/o:latest-inc` (Because by the time it doesn't exist). The job will automatically do this if `t/o:latest-inc` does not exist. To manually trigger this, see [Re-create your incremental builders](#re-create-your-incremental-builders-重建增量构建器).

- The same logic also applies to the first time usage of `build-package` mode.

---

为了简便，假设用于存储编译状态的Docker image为
- `IMAGE_NAME=tete1030/openwrt_x86_64`（用`t/o`简略)
- `IMAGE_TAG=latest`

**三种编译模式**按照以下方式工作：
- 每次release，`build-base`自动建立“基础构建器”并从头编译OpenWrt。该模式产生固件和一个“基础构建器”，该构建器命名为`t/o:latest`并被存储在Docker Hub上<sup>1</sup><sup>2</sup>
- 每次push，`build-inc`自动基于“增量构建器`t/o:latest-inc`”建立新的“增量构建器`t/o:latest-inc`”（同名）。该模式也产生固件。最终该新构建器被保存回Docker Hub，覆盖之前的旧构建器。<sup>2</sup>
- 每次push，`build-package`自动基于“增量构建器`t/o:latest-package`”建立新的“增量构建器`t/o:latest-package`”（同名）。该模式仅产生软件包（*.ipkg)。最终该新构建器被保存回Docker Hub，覆盖之前的旧构建器。<sup>2</sup>

<sup>[1] *对于`build-base`模式，一些“中间构建器`t/o:latest-build`”和“缓存`t/o:latest-buildcache`、`t/o:latest-cache`”也会产生。不用管它们。*</sup>
<sup>[2] *对于所有模式，一些测试构建器`t/o:test-latest*`会产生在Docker Hub上。同样不需要理睬。*</sup>

你可能会注意到，三种构建器之间没有建立任何联系。事实上，后两个构建器需要从第一个构建器拉取：
- 第一次使用`build-inc`模式时，该模式会使用`t/o:latest`作为基础，而不是默认的`t/o:latest-inc`构建器（因为此时它还不存在）。这一过程会在`t/o:latest-inc`不存在时自动发生。如你想手动触发这一拉取过程，参考[重建增量构建器](#re-create-your-incremental-builders-重建增量构建器)。
- 第一次使用`build-package`模式适用相同的逻辑。

## Usage 用法

**The default configuration uses [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) as the OpenWrt Repo** (popular in China). If you want OpenWrt 19.07, check out ["openwrt_official" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/openwrt_official). (It's just changes of `REPO_URL` and `REPO_BRANCH` envs in `.github/workflows/build-openwrt.yml`.)

Check out my own configuration in ["sample" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/sample).

### First-time building 第一次编译

These steps are for making a base builder. When you are building for the first time, or you need a fresh rebuilding of everything, you can follow these steps.

The base builder can be triggered by github release event (by publishing a release), or you can use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to mannually trigger a rebuilding with parameters "Type/Task": `build-base` and empty "Client Payload". (see [Manually trigger building and its options](#manually-trigger-building-and-its-options))

The building process generally takes **1.5~3 hours** depending on your config.

1. Sign up for [GitHub Actions](https://github.com/features/actions/signup)
2. Fork this repo
3. **Register a Docker Hub account**. This is necessary
4. Get your Docker Hub **personal access token**. Fill your username and the generated token into the forked repo's **Settings->Secrets** page. Use `docker_username` for your username, and `docker_password` for your token. See [Secrets page](#secrets-page) for correct settings.
5. *(Optional, not very useful)* If you want the debug SSH command to be sent to Slack, you can generate a Slack Webhook URL and set the url as `SLACK_WEBHOOK_URL` in the Secrets page. Search in Google if you don't know how to do it.
6. *(Optional)* Customize `.github/workflows/build-openwrt.yml` to **change builder's name and other options**.
7. **Generate your `.config`** and rename it to `config.diff`. Put the file in the root dir of your forked repo.
8. *(Optional)* Customize `scripts/update_feeds.sh` for **additional packages** you want to download.
9. *(Optional)* Put any **patch** you want to `patches` dir. The patches are applied after `update_feeds.sh` and before `download.sh`.
10. **Commit and push** your changes. This will automatically trigger an incremental building. However, it will fail as you haven't built base builder. **Just let it fail** or cancel it in the Actions page.
11. **Publish** a release. This is for creating the base builder. Or you can use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to manually trigger it. ("Type/Task": `build-base`, "Payload": leave it empty)
12. Wait for `build-base` job to finish.
13. Collect your files in the `build-base` job's `Artifacts` menu

#### Secrets page

![Secrets page](imgs/secrets.png)

### Following building 后续编译

After the base builder has been made, you will only need the following steps to build your firmwares and packages when you change your config. The building process generally only takes **20 minutes ~ 1 hour** depending on how much your config has changed.

1. *(Optional)* Modify your `config.diff` if you want.
8. *(Optional)* Customize `scripts/update_feeds.sh` for **additional packages** you want to download.
9. *(Optional)* Put any **patch** you want to `patches` dir.
10. Commit and push your changes
11. Wait for `build-inc` or `build-package` to finish
12. Collect your files in the `build-inc` or `build-package` job's `Artifacts` menu

### Re-create your base builder 重建基础构建器

If you have largely modified your configurations, incremental building may fail as there could be old configurations remained. It's better to re-create your base builder, and then [Re-create your incremental builders](#re-create-your-incremental-builders-重建增量构建器).

For re-creating base builder, just do the last several steps of [First-time building](#first-time-building-第一次编译).

### Re-create your incremental builders 重建增量构建器

Because the `build-inc` and `build-package` builders are reusing previous building state, the builder image may grow larger and larger. The builder itself could also fall into some error state. If so, you can re-create them from the base builder.

1. Use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to link the latest base builder to the incremental builders.
   - For builder used in `build-inc`, use parameters:
     - Type/Task: `build-inc` 
     - Client Payload: `{"use_base": true}`
   - For builder used in `build-package`, use parameters:
     - Type/Task: `build-package`
     - Payload:
       - `{"use_base": true}` if you want to use the base builder from `build-base`
       - `{"use_inc": true}` if you want to use the incremental builder from `build-inc`
2. Wait for jobs to finish.

### Manually trigger building and its options

If you don't want to build by publishing releases or pushing, you can manually trigger every building mode by using [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher).

The project supports both "Repo Dispatch" and "Deploy" trigger. When using "Repo Dispatch", specify your job name in the "Type" prompt. When using "Deploy", specify your job name in the "Task" prompt.

If you want to trigger a job in other branches instead of "master", you can only use the "Deploy" trigger in order to specify your branch.

You can also specify some building options to control the process (not possible when publishing or pushing). Fill your options in the "Payload" prompt, or leave "Payload" empty when no option is needed. All boolean options are by default `false`. The following are options available.

#### Global options

- `debug`(bool): entering tmate during and after building, allowing you to SSH into the Actions
- `push_when_fail`(bool): always save the builder to Docker Hub even if the building process fails. Not recommended to use

#### Options only for `build-inc`

- `update_repo`(bool): do `git pull` on main repo. It could fail if any tracked file of the repo has changed.
- `update_feeds`(bool): do `git pull` on feeds and your manually added packages. It could fail if any tracked file changed.
- `use_base`(bool): instead of using the job's own previous builder, use latest base builder

#### Options only for `build-package`

- `update_feeds`(bool): same to previous section
- `use_base`(bool): same to previous section
- `use_inc`(bool): instead of using the job's own previous builder, use latest incremental builder generated by `build-inc`

#### Examples

To trigger re-creating the base builder with SSH debugger enabled:
1. Open your forked repo
2. Click "Repo Dispatch" or "Deploy" at the top right corner
3. Fill `build-base` in "Type/Task" prompt
4. If using "Deploy" trigger, fill your branch/tag/commit in "Ref" prompt (e.g. default: `master`)
5. Fill `{"debug": true}` in "Payload" prompt
6. Open the job's log page, wait for the SSH command showing up (when debugging, you are allowed to SSH into the job's runner, with the help of tmate.io)

## Details

### Success building job examples

[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede):
- [`build-base`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/359974704)
- [`build-inc`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360084146)
- [`build-package`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360084313)

[openwrt/openwrt;openwrt-19.07](https://github.com/openwrt/openwrt/tree/openwrt-19.07):
- [`build-base`](https://github.com/tete1030/openwrt-fastbuild-actions/commit/7757f6741a804b84f2f6fa6c03272e322ce6a8e9/checks?check_suite_id=370526615)
- [`build-inc`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360106903)
- [`build-package`](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360107046)

### Building process explained

I'll now explain here the detailed building process of each mode.

#### `build-base`

1. `cleanup.sh`: Clean for extra disk space
2. `initenv.sh`: Set up building environment
3. `update_repo.sh`: Clone main repo
4. `update_feeds.sh`: Init feeds and custom packages
5. `customize.sh`: Apply patches, load `config.diff` to `.config`, `make defconfig`
6. `download.sh`: Download all packages
7. `compile.sh`: Multi/single-thread compile
8. Save the builder to Docker Hub, named as `${BUILDER_NAME}:${BUILDER_TAG}`. ~~Save the constructing cache to `${BUILDER_NAME}:${BUILDER_TAG}-cache`~~(cache currently disabled to speed up copy files out)
9. Copy out from docker and upload files to Artifacts
    - `OpenWrt_bin`: all binaries files, packages and firmwares
    - `OpenWrt_firmware`: firmware only

#### `build-inc`

1. Pull `${BUILDER_NAME}:${BUILDER_TAG}-inc` from Docker Hub. If the tag does not exist or `use_base` building option is set, link current `${BUILDER_NAME}:${BUILDER_TAG}` to `${BUILDER_NAME}:${BUILDER_TAG}-inc` ()
2. `update_repo.sh`. It will do `git pull` for main repo only when `update_repo` option is set
3. `update_feeds.sh`. It will download you manually added packages, and do `git pull` for existing packages only when `update_feeds` option is set.
4. `customize.sh`, apply patches only when a patch has not been already applied
5. `download.sh`, download/update package source code that are not already downloaded
6. `compile.sh`, Multi/single-thread compile
7. Save this new builder to Docker Hub's `${BUILDER_NAME}:${BUILDER_TAG}-inc`
8. Copy out from docker and upload files to Artifacts
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

### [Fixed] Spend so much time on "Copy out bin directory" in `build-base` (Original docker-build)

The problem should no longer exist. I disabled building cache by default, as it is rarely used. 

~~Due to the use of `docker-container` driver of `docker buildx` command for only `build-base` job, we can not directly use `docker cp`. Instead, I have to use a multi-stage hack to export out files, in order to in the same time keep the ability of exporting cache and builder image to Docker Hub. When the image is large, this method can spend much time in unpacking the image.~~

~~`build-inc` and `build-package` are not affected.~~

~~I have tried many methods to workaround this. Currently this setting is the best trade-off I can achieve. If you are interested or have better idea, feel free to open an issue for discussion.~~

## Todo

- [ ] Merge three building modes into one to simplify the process
- [ ] SSH into docker container instead of just the runner (for `make menuconfig`)
- [ ] Allow customizing trigger event
- [ ] Allow specify building job in commit message (comming soon)
- [x] Automatically linking from base builder to builders for `build-inc` and `build-package` when not existing
- [ ] Optimize README
  - [ ] Simplfy documentation
  - [ ] Add Chinese version of "Usage"
  - [ ] Add a figure to "Mechanism"
  - [x] Describe mechanism
  - [x] Describe building process
  - [x] Describe using [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to trigger building with extra options
- [x] Optimize comments in `build-openwrt.yml` and `docker.sh`
- [x] Optimize `build-openwrt.yml`, making options cleaner
- [ ] Allow deterministic building (by fixing commit of main repo and feeds)
- [ ] Utilize `jobs.<job_id>.container` instead of docker commands if possible
  - [ ] ~~For `build-base`~~
    - Problem: may not able to use cache and push
  - [ ] For `build-base`'s upload stage
    - Probably very useful. Currently it consumes a lot of time due to repeatly compressing and uncompressing image
  - [ ] ~~For `build-inc` and `build-package`~~
    - Problem: may not able to push

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

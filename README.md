Building OpenWrt with GitHub Actions and Docker
============================================================================

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
    - [Re-link your builders 重建编译环境](#re-link-your-builders-%e9%87%8d%e5%bb%ba%e7%bc%96%e8%af%91%e7%8e%af%e5%a2%83)
    - [Manually trigger building and its options](#manually-trigger-building-and-its-options)
      - [Global](#global)
      - [For docker-build-inc](#for-docker-build-inc)
      - [For docker-build-package](#for-docker-build-package)
      - [Examples](#examples)
  - [Details](#details)
    - [Building log examples](#building-log-examples)
    - [Building process explained](#building-process-explained)
      - [docker-build building process](#docker-build-building-process)
      - [docker-build-inc building process](#docker-build-inc-building-process)
      - [docker-build-package building process](#docker-build-package-building-process)
  - [FAQs](#faqs)
    - [Docker Hub: Tags not retrieved](#docker-hub-tags-not-retrieved)
    - [Spend so much time on &quot;Copy out bin directory&quot; in docker-build](#spend-so-much-time-on-quotcopy-out-bin-directoryquot-in-docker-build)
    - [What are test-docker-build* jobs?](#what-are-test-docker-build-jobs)
  - [Todo](#todo)
  - [Acknowledgments](#acknowledgments)
  - [License](#license)

## Features 特点

- Load and save building state to Docker Hub or other registries
- Load and save base builder cache to Docker Hub or other registries
- Three building modes in parallel (before colons are job names of Github Actions)
  - `docker-build`: Completely rebuilding firmware and packages (every release, long period if code has changed)
  - `docker-build-inc`: Incrementally building firmware and packages (every push, short period)
  - `docker-build-package`: Incrementally building only packages (every push, short period, useful when only enabling a package module)

----

- 在Docker Hub或其他Registry加载和存储OpenWrt编译状态
- 在Docker Hub或其他Registry加载和存储用于构建“基础编译环境”的缓存
- 三个编译模式平行进行（冒号前是Github Actions中的job名称）
  - `docker-build`：完全重编译固件和软件包（每次release自动进行，如果代码更新会很耗时）
  - `docker-build-inc`：增量编译固件和软件包（每次push自动进行，耗时相对较短）
  - `docker-build-package`：增量编译软件包（每次push自动进行，耗时相对较短，当仅需要编译软件安装包时比较有用）

## Mechanism 原理

[TODO] Probably a figure is better

For convenience, assume docker image for storing builder
- `IMAGE_NAME=tete1030/openwrt_x86_64` (abbreviated to `t/o`)
- `IMAGE_TAG=latest`

The **three building modes** function as following description:

- For every release, the `docker-build` mode setups "base builder" and builds OpenWrt freshly. It produces a firmware and "base builder". The builder is named as `t/o:latest` and stored in Docker Hub.<sup>1</sup><sup>2</sup>
- For every push, the `docker-build-inc` mode setups "new builder `t/o:latest-inc`" based on itself's "previous builder `t/o:latest-inc`" (same name), and it builds new firmware. Then it saves back the new builder to Docker Hub.<sup>2</sup>
- For every push, the `docker-build-package` mode setups "new builder `t/o:latest-package`" based on itself's "previous builder `t/o:latest-package`" (same name), and it builds new packages (*.ipkg). Then it saves back the new builder to Docker Hub.<sup>2</sup>

<sup>[1] *For `docker-build` mode, there are also an intermediate builder `t/o:latest-build` and cache `t/o:latest-buildcache`、`t/o:latest-cache`. You don't need to care them.*</sup>
<sup>[2] *For all modes, there are also test builders `t/o:test-latest*`. You don't need to care them.*</sup>

You may notice there are gaps between the three builders. YES. The latter two builders relies on pulling from the first builder (_They are already addressed automatically, you don't need to follow these steps unless you want to manually trigger them_):

- For first time usage of `docker-build-inc` mode, we need to make it use the `t/o:latest` builder as basis builder instead of the default basis `t/o:latest-inc` (Because by the time it doesn't exist). The method is described in [Re-link your builders](#re-link-your-builders-重建编译环境).

- For first time usage of `docker-build-package` mode, we need to make it use the `t/o:latest` builder or the `t/o:latest-inc` builder as basis builder instead of the default basis `t/o:latest-package` (Because by the time it doesn't exist). The method is described in [Re-link your builders](#re-link-your-builders-重建编译环境).

---

为了简便，假设用于存储编译状态的Docker image为
- `IMAGE_NAME=tete1030/openwrt_x86_64`（用`t/o`简略)
- `IMAGE_TAG=latest`

**三种编译模式**按照以下方式工作：
- 每次release，`docker-build`自动建立“基础编译环境”。该模式产生固件和“基础编译环境”，并将该编译环境命名为`t/o:latest`存储在Docker Hub上<sup>1</sup><sup>2</sup>
- 每次push，`docker-build-inc`自动基于“旧编译环境`t/o:latest-inc`”建立“新编译环境`t/o:latest-inc`”（同名）。该模式也产生固件，“新编译环境”最终被保存回Docker Hub<sup>2</sup>
- 每次push，`docker-build-package`自动基于“旧编译环境`t/o:latest-package`”建立“新编译环境`t/o:latest-package`（同名）。该模式仅产生可安装软件包（*.ipkg)。“新编译环境”最终被保存至Docker Hub<sup>2</sup>

<sup>[1] *对于`docker-build`模式，一些“中间编译环境`t/o:latest-build`”和“缓存`t/o:latest-buildcache`、`t/o:latest-cache`”也会产生。不用管。*</sup>
<sup>[2] *对于所有模式，一些测试环境`t/o:test-latest*`会产生在Docker Hub上。同样不需要理睬。*</sup>

你可能会注意到，三种编译环境之间没有建立任何联系。确实，后两个编译环境需要从第一个编译环境拉取（_这两个步骤已经被自动化完成，除非你想手动触发这个过程，你不需要执行以下步骤_）：
- 第一次使用`docker-build-inc`模式时，我们需要让该模式使用`t/o:latest`作为基础，而不是默认的`t/o:latest-inc`环境（因为此时它还不存在）。使用方法在下面[重建编译环境](#re-link-your-builders-重建编译环境)章节描述。
- 第一次使用`docker-build-package`模式时，我们需要让该模式使用`t/o:latest`或`t/o:latest-inc`作为基础，而不是默认的`t/o:latest-package`环境（因为此时它还不存在）。使用方法在下面[重建编译环境](#re-link-your-builders-重建编译环境)章节描述。

## Usage 用法

Check out my own configuration in ["sample" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/sample).

Configuration for official OpenWrt 19.07 is in ["openwrt_official" branch](https://github.com/tete1030/openwrt-fastbuild-actions/tree/openwrt_official). It is just a change of `REPO_URL`.

### First-time building 第一次编译

These step is for making a base builder. When you need a fresh rebuilding of everything, you can execute this by publishing a new release or use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to mannually trigger a rebuilding with parameters "Type/Task": `docker-build` and empty "Client Payload".

The building process generally takes **1.5~3 hours** depending on your config.

1. Sign up for [GitHub Actions](https://github.com/features/actions/signup)
2. Register a **Docker Hub** account
3. **Fork** this repo
4. Get your Docker Hub **personal access token**. Paste your username and the generated token to the forked repo's **Settings->Secrets** page. Use `docker_username` for your username and `docker_password` for your token. Check [Secrets page](#secrets-page) for correct settings.
5. *(Optional, not very useful)* If you want a debug message to be sent to **Slack**, you can generate a Slack Webhook URL and set the url as `SLACK_WEBHOOK_URL` in the Secrets page. Search in Google if you don't know how to do it.
6. *(Optional)* Customize `.github/workflows/build-openwrt.yml` to **change builder's name and other options**.
7. **Generate your `.config`** and rename it to `config.diff`. Put the file in the root dir of your forked repo.
8. *(Optional)* Customize `scripts/update_feeds.sh` for **additional packages** you want to download.
9. *(Optional)* Put any **patch** you want to `patches` dir. The patches are applied after `update_feeds.sh` and before `download.sh`.
10. **Commit and push** your changes. This will automatically trigger an incremental building. However, it will fail as you haven't built base builder. **Just let it fail** or cancel it in the Actions page.
11. **Publish** a release. This is for full building of base builder. Or you can use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to manually trigger the building. ("Type/Task": `docker-build`, "Payload": leave it empty)
12. Wait for `docker-build` job to finish.
13. Collect your files in the `docker-build` job's `Artifacts` menu

#### Secrets page

![Secrets page](imgs/secrets.png)

### Following building 后续编译

After the base builder has been made, you only need the following step to build your firmware and packages when you want to change your config. The building process generally only takes **20 minutes ~ 1 hour** depending on the extent your config has changed.

1. Commit and push your changes
2. Wait for `docker-build-inc` or `docker-build-package` to finish
3. Collect your files in the `docker-build-inc` or `docker-build-package` job's `Artifacts` menu

### Re-link your builders 重建编译环境

Because the `docker-build-inc` builder and `docker-build-package` builder are reusing previous building state, the builder image may grow larger and larger. The builder itself may also fall into some wrong state. If so, you can remake them from the base builder.

1. Use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to link the latest base builder to the builder used for incremental building.
   - For `docker-build-inc`, use parameters:
     - Type/Task: `docker-build-inc` 
     - Client Payload: `{"use_latest": true}`
   - For `docker-build-package`, use parameters:
     - Type/Task: `docker-build-package`
     - Payload:
       - `{"use_latest": true}` if you want to use the base builder from `docker-build`
       - `{"use_latest_inc": true}` if you want to use the incremental builder from `docker-build-inc`
2. Wait for jobs to finish
3. Collect your files in the job's `Artifacts` menu

### Manually trigger building and its options

The following options are only usable when triggering building from [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher)

The project support both "Repo Dispatch" and "Deploy" trigger. When using "Repo Dispatch", using "Type" to specify your job name. When using "Deploy", using "Task" to specify your job name.

Using "Payload" to specify you options.

If you want to trigger a job in other branches than "master", you can only use the "Deploy" trigger to specify your branch.

#### Global

- `debug`(bool): entering tmate during and after building, allowing you to SSH into the Actions
- `push_when_fail`(bool): always push even if the building process fails. Not recommended to use

#### For `docker-build-inc`

- `update_repo`(bool): do `git pull` on repo. It could fail if there is any tracked file in the repo that has changed.
- `update_feeds`(bool): do `git pull` on feeds and your own packages. It could fail if any tracked file changed.
- `use_latest`(bool): instead of using itself's previous builder, use latest base builder

#### For `docker-build-package`

- `update_feeds`(bool): same to previous
- `use_latest`(bool): same to previous
- `use_latest_inc`(bool): instead of using itself's previous builder, use latest incremental builder generated by `docker-build-inc`

#### Examples

To trigger rebuilding base builder,
1. Open your forked repo
2. Click "Repo Dispatch" or "Deploy" at the top right corner (left of the "Watch" button)
3. If using "Deploy" trigger, fill your branch/tag/commit for "Ref" prompt (e.g. `master`)
4. Fill `docker-build` for "Type/Task" prompt
5. Fill `{"debug": true}` for "Payload" prompt
6. Open the job's log page, wait for the SSH command shown up (when debugging, you are allowed to SSH into the jobs with tmate.io)

## Details

### Building log examples

coolsnowwolf/lede:
- [`docker-build` build log](https://github.com/tete1030/openwrt-fastbuild-actions/runs/359974704)
- [`docker-build-inc` build log](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360084146)
- [`docker-build-package` build log](https://github.com/tete1030/openwrt-fastbuild-actions/runs/360084313)

openwrt/openwrt;openwrt-19.07:
- [`docker-build` build log](https://github.com/tete1030/openwrt-fastbuild-actions/commit/7757f6741a804b84f2f6fa6c03272e322ce6a8e9/checks?check_suite_id=370526615)

### Building process explained

#### `docker-build` building process

1. `cleanup.sh`: Clean for extra disk space
2. `initenv.sh`: Install building environment
3. `update_repo.sh`: Clone/update main repo
4. `update_feeds.sh`: Init/update feeds and custom packages
5. `customize.sh`: Apply patches, load `config.diff` to `.config`, `make defconfig`
6. `download.sh`: Download all packages
7. `compile.sh`: Multi/single-thread compile
8. Save builder to Docker Hub's `${BUILDER_NAME}:${BUILDER_TAG}`, the constructing cache to `${BUILDER_NAME}:${BUILDER_TAG}-cache`
9. Upload files to Artifacts
    - `OpenWrt_bin`: all binaries files, packages and firmwares
    - `OpenWrt_firmware`: firmware only

#### `docker-build-inc` building process

1. Pull from Docker Hub `${BUILDER_NAME}:${BUILDER_TAG}-inc`. If not existing, link `${BUILDER_NAME}:${BUILDER_TAG}` to `${BUILDER_NAME}:${BUILDER_TAG}-inc` (or when `use_latest` option is set)
2. `update_repo.sh`, only when `update_repo` option is set
3. `update_feeds.sh`, do `git pull` for existing packages only when `update_feeds` option is set
4. `customize.sh`, apply patches only when a patch has not been applied
5. `download.sh`, download/update packages if any thing changed when `update_repo.sh` or `update_feeds.sh`
6. `compile.sh`, Multi/single-thread compile
7. Save builder to Docker Hub's `${BUILDER_NAME}:${BUILDER_TAG}-inc` (no matter if `use_latest` is set)
8. Upload files to Artifacts
    - `OpenWrt_bin`: all binaries files, packages and firmwares
    - `OpenWrt_firmware`: firmware only

#### `docker-build-package` building process

1. Pull from Docker Hub `${BUILDER_NAME}:${BUILDER_TAG}-package`. If not existing, set `${BUILDER_NAME}:${BUILDER_TAG}` to `${BUILDER_NAME}:${BUILDER_TAG}-package` (or when `use_latest` option is set, or link `${BUILDER_NAME}:${BUILDER_TAG}-inc` to `${BUILDER_NAME}:${BUILDER_TAG}-package` when `use_latest_inc` option is set)
2. Unlike other building processes, `update_repo.sh` is not run
3. `update_feeds.sh`, do `git pull` for existing packages only when `update_feeds` option is set
4. `customize.sh`, apply patches only when a patch has not been applied
5. `download.sh`, download/update packages if any thing changed when `update_repo.sh` or `update_feeds.sh`
6. `compile.sh`, Multi/single-thread compile
7. Save builder to Docker Hub's `${BUILDER_NAME}:${BUILDER_TAG}-package` (no matter if `use_latest` or `use_latest_inc` is set)
8. Upload files to Artifacts
    - `OpenWrt_packages`: all packages
    - `OpenWrt_new_packages`: only new produced packages from building of this time (by comparing modified time)

## FAQs

### Docker Hub: Tags not retrieved

Caused by known of buildx:
- https://github.com/docker/hub-feedback/issues/1906
- https://github.com/docker/buildx/issues/173

### Spend so much time on "Copy out bin directory" in `docker-build`

Indeed. Due to the use of `docker-container` driver of `docker buildx` command for only `docker-build` job, we can not directly use `docker cp`. Instead, I have to use a multi-stage hack to export out files, in order to in the same time keep the ability of exporting cache and builder image to Docker Hub. When the image is large, this method can spend much time in unpacking the image.

`docker-build-inc` and `docker-build-package` are not affected.

I have tried many methods to workaround this. Currently this setting is the best trade-off I can achieve. If you are interested or have better idea, feel free to open an issue for discussion.

### What are `test-docker-build*` jobs?

They are for fast checking of Github Actions and Docker settings. Typically they only spend less than 5 minutes. When they fail, its sibling job will be stopped. Fix the problem it reported.

## Todo

- [ ] Automatically trigger building base image
- [x] Automatically linking from base builder to `docker-build-inc` and `docker-build-package` when not existing
- [ ] Optimize README
  - [x] Describe mechanism
  - [x] Describe building process
  - [ ] Describe files
  - [x] Describe using [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to trigger building with extra options
- [x] Optimize comments in `build-openwrt.yml` and `docker.sh`
- [x] Optimize `build-openwrt.yml`, making options cleaner
- [ ] Allow deterministic building (by fixing commit of main repo and feeds)
- [ ] Utilize `jobs.<job_id>.container` instead of docker commands if possible
  - [ ] ~~For `docker-build`~~
    - Problem: may not able to use cache and push
  - [ ] For `docker-build`'s upload stage
    - Probably very useful. Currently it consumes a lot of time due to repeatly compressing and uncompressing image
  - [ ] ~~For `docker-build-inc` and `docker-build-package`~~
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

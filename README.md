Building OpenWrt with GitHub Actions and Docker
============================================================================

This project is rooted from [P3TERX's Actions-Openwrt](https://github.com/P3TERX/Actions-OpenWrt).

With Github Actions, we can now easily build an OpenWrt firmware without running locally. However, Github Actions do not store cache and building files. This means each time it has to completely rebuild from source, even if it is a small change.

This project uses Docker Hub for storing previous building process, allowing incremental building.

有了Github Actions，现在可以很方便地自动化编译OpenWrt固件，而不必在本地编译。然而Github Actions不存储缓存，已编译过的文件也不会在下次编译重新被使用。这就意味着，即便只是很小的改动，每次编译我们要等上很久来重新编译整个固件。

本项目使用Docker Hub存储编译状态，使得后续的编译可以增量进行。

## Features 特点

- Load and save building state to Docker Hub
- Load and save docker image cache to Docker Hub (currently cache is only rarely used)
- Three building modes in parallel (before colons are job names of Github Actions)
  - `docker-build`: Completely rebuilding firmware (every release, long period)
  - `docker-build-inc`: Incrementally building firmware (every push, short period)
  - `docker-build-package`: Incrementally building only packages (every push, short period, useful when only enabling a package module)

- 在Docker Hub加载和存储OpenWrt编译状态
- 在Docker Hub加载和存储Docker Image的构建缓存（当前只有极少情况被使用）
- 三个编译模式平行进行
  - `docker-build`：完全重编译固件（每次release自动进行，耗时）
  - `docker-build-inc`：增量编译固件（每次push自动进行，耗时较短）
  - `docker-build-package`：增量编译软件包（每次push自动进行，耗时较短，当仅需要编译一个软件安装包时比较有用）

## Mechanism 原理

For convenience, assume docker image for storing builder
- `IMAGE_NAME=tete1030/openwrt_x86_64`
- `IMAGE_TAG=latest`
  
The three building modes function as following description:

- For every release, the `docker-build` mode setups "base builder" and builds OpenWrt freshly. It produces a firmware and a builder. The builder is named as `tete1030/openwrt_x86_64:latest` and stored in Docker Hub.<sup>1</sup>
- For every push, the `docker-build-inc` mode setups "new builder `tete1030/openwrt_x86_64:latest-inc`" based on itself's "previous builder `tete1030/openwrt_x86_64:latest-inc`" (same name), and it builds new firmware. Then it saves back the new builder to Docker Hub.
- For every push, the `docker-build-package` mode setups "new builder `tete1030/openwrt_x86_64:latest-package`" based on itself's "previous builder `tete1030/openwrt_x86_64:latest-package`" (same name), and it builds new packages (*.ipkg). Then it saves back the new builder to Docker Hub.

<sup>[1] *For `docker-build` mode, there are also an intermediate builder `tete1030/openwrt_x86_64:latest-build` and cache `tete1030/openwrt_x86_64:latest-buildcache`、`tete1030/openwrt_x86_64:latest-cache`. You don't need to care them.*</sup>

You may notice there are gaps between the three builders. YES. The latter two builders relies on pulling from the first builder:

- For first time usage of `docker-build-inc` mode, we need to make it use the `*:latest` builder instead of the `*:latest-inc` (Because currently it doesn't exist). The method is described in [Usage](#usage-使用).

- For first time usage of `docker-build-package` mode, we need to make it use the `*:latest` builder or the `*:latest-inc` builder instead of the `*:latest-package` (Because currently it doesn't exist). The method is described in [Usage](#usage-用法).

为了简便，假设用于存储编译状态的Docker image为
- `IMAGE_NAME=tete1030/openwrt_x86_64`
- `IMAGE_TAG=latest`
  
这三种编译模式按照以下方式工作：
- 每次release，`docker-build`自动建立“基础编译环境”。该模式产生固件和编译状态，并将改编译状态命名为`tete1030/openwrt_x86_64:latest`存储在Docker Hub上
- 每次push，`docker-build-inc`自动建立“新编译环境`tete1030/openwrt_x86_64:latest-inc`”，基于“旧编译环境`tete1030/openwrt_x86_64:latest-inc`”（同名）。该模式也产生固件，“新编译环境”最终被保存至Docker Hub
- 每次push，`docker-build-package`自动建立“新编译环境`tete1030/openwrt_x86_64:latest-package`，基于“旧编译环境`tete1030/openwrt_x86_64:latest-package`”（同名）。该模式仅产生可安装软件包（*.ipkg)。“新编译环境”最终被保存至Docker Hub

<sup>[1] *对于`docker-build`模式，一些“中间编译环境`tete1030/openwrt_x86_64:latest-build`”和“缓存`tete1030/openwrt_x86_64:latest-buildcache`、`tete1030/openwrt_x86_64:latest-cache`”也会产生。不用管。*</sup>

你可能会注意到，三种编译环境之间没有建立任何联系。确实，后两个编译环境需要从第一个编译环境拉取：
- 第一次使用`docker-build-inc`模式时，我们需要让该模式使用`*:latest`作为基础，而不是默认的`*:latest-inc`环境（因为此时它还不存在）。使用方法在下面[用法](#usage-用法)章节描述。
- 第一次使用`docker-build-package`模式时，我们需要让该模式使用`*:latest`或`*:latest-inc`作为基础，而不是默认的`*:latest-package`环境（因为此时它还不存在）。使用方法在下面[用法](#usage-用法)章节描述。

## Usage 用法

### First time building 第一次编译

1. Sign up for [GitHub Actions](https://github.com/features/actions/signup)
2. Register a Docker Hub account
3. Fork this repo
4. Get your Docker Hub personal access token. Paste your username and the generated token to the forked repo's Settings->Secrets page. Use `docker_username` for your username and `docker_password` for your token.
5. (Optional, not very useful) If you want a debug message to be sent to Slack, you can generate a Slack Webhook URL and set the url as `SLACK_WEBHOOK_URL` in the Secrets page. Search in Google if you don't know how to do it.
6. Generate your `.config` and rename it to `config.diff`. Put the file in the root dir of your forked repo.
7. Customize optional packages you want to download in `scripts/update_feeds.sh`
8. Put any patch you want to `patches` dir. The patches are applied after `update_feeds.sh` and before `download.sh`.
9. Commit and push your changes. 
10. Publish a release the first time you use. Or you can use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to start the building. (`Type`: `docker-build`, `Payload`: leave it empty)
11. Wait for `docker-build` job to finish. This is for full building of base builder.
12. After `docker-build` finished, use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to mark this builder as the builder used for incremental building. (`Type`: `docker-build-inc`, `Payload`: `{"use_latest": true}`) and (`Type`: `docker-build-package`, `Payload`: `{"use_latest": true}`)
13. Collect your files in the `docker-build` job's `Artifacts` menu

### Following building 后续编译

1. Commit and push your changes
2. Wait for `docker-build-inc` or `docker-build-package` to finish
3. Collect your files in the `docker-build-inc` or `docker-build-package` job's `Artifacts` menu

### Remake your `docker-build-inc` builder or `docker-build-package` builder 重建编译环境

If the builder `docker-build-inc` or `docker-build-package` falls into some wrong state, you can remake them by

1. Use [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to mark the latest base builder as the builder used for incremental building. (`Type`: `docker-build-inc` or `docker-build-package`, `Payload`: `{"use_latest": true}`)
2. Wait for `docker-build-inc` or `docker-build-package` to finish
3. Collect your files in the `docker-build-inc` or `docker-build-package` job's `Artifacts` menu

## Details

### Files

To be finished

### `docker-build` building process

1. `cleanup.sh`: Clean for extra disk space
2. `initenv.sh`: Install building environment
3. `update_repo.sh`: Clone/update main repo
4. `update_feeds.sh`: Init/update feeds and custom packages
5. `customize.sh`: Apply patches, load `config.diff` to `.config`, `make defconfig`
6. `download.sh`: Download all packages
7. `compile.sh`: Multi/single-thread compile
8. Save builder to Docker Hub's `${IMAGE_NAME}:${IMAGE_TAG}`
9. Upload files to Artifacts
    - `OpenWrt_bin`: all binaries files, packages and firmwares
    - `OpenWrt_firmware`: firmware only

### `docker-build-inc` building process

1. Pull from Docker Hub `${IMAGE_NAME}:${IMAGE_TAG}-inc` (or `${IMAGE_NAME}:${IMAGE_TAG}` when `github.event.client_payload.use_latest` is set)
2. `update_repo.sh`, only when `github.event.client_payload.update_repo` is set
3. `update_feeds.sh`, do `git pull` for existing packages only when `github.event.client_payload.update_feeds` is set
4. `customize.sh`, apply patches only when patch is detected as not applied
5. `download.sh`, download/update packages if any thing changed when `update_repo.sh` or `update_feeds.sh`
6. `compile.sh`, Multi/single-thread compile
7. Save builder to Docker Hub's `${IMAGE_NAME}:${IMAGE_TAG}-inc` (no matter if `use_latest` is set)
8. Upload files to Artifacts
    - `OpenWrt_bin`: all binaries files, packages and firmwares
    - `OpenWrt_firmware`: firmware only

### `docker-build-inc` building process

1. Pull from Docker Hub `${IMAGE_NAME}:${IMAGE_TAG}-package` (or `${IMAGE_NAME}:${IMAGE_TAG}` when `github.event.client_payload.use_latest` is set, `${IMAGE_NAME}:${IMAGE_TAG}-inc` when `github.event.client_payload.use_latest_inc` is set)
2. No `update_repo.sh`
3. `update_feeds.sh`, do `git pull` for existing packages only when `github.event.client_payload.update_feeds` is set
4. `customize.sh`, apply patches only when patch is detected as not applied
5. `download.sh`, download/update packages if any thing changed when `update_repo.sh` or `update_feeds.sh`
6. `compile.sh`, Multi/single-thread compile
7. Save builder to Docker Hub's `${IMAGE_NAME}:${IMAGE_TAG}-package` (no matter if `use_latest` or `use_latest_inc` is set)
8. Upload files to Artifacts
    - `OpenWrt_packages`: all packages
    - `OpenWrt_new_packages`: only new produced packages from building of this time (by comparing modified time)

## Todo

- [ ] Automate the trigger of building base image
- [ ] Optimize README
  - [ ] Describe mechanism
  - [ ] Describe building process
  - [ ] Describe files
  - [ ] Describe using [tete1030/github-repo-dispatcher](https://github.com/tete1030/github-repo-dispatcher) to trigger building with extra options
- [ ] Optimize comments in `build-openwrt.yml` and `docker.sh`
- [ ] Optimize `build-openwrt.yml`, making options cleaner
- [ ] Allow deterministic building (by fixing commit of main repo and feeds)
- [ ] Utilize `jobs.<job_id>.container` instead of docker commands if possible
  - [ ] For `docker-build`
    - Problem: not able to use cache, wouldn't able to push
  - [ ] For `docker-build`'s upload stage
    - Probably very useful. Currently it consumes a lot of time due to repeat uncompressing image
  - [ ] For `docker-build-inc` and `docker-build-package`
    - Problem: wouldn't able to push

## Acknowledgments

- [P3TERX's Actions-Openwrt](https://github.com/P3TERX/Actions-OpenWrt)
- [Microsoft](https://www.microsoft.com)
- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub](https://github.com)
- [GitHub Actions](https://github.com/features/actions)
- [tmate](https://github.com/tmate-io/tmate)
- [mxschmitt/action-tmate](https://github.com/mxschmitt/action-tmate)
- [csexton/debugger-action](https://github.com/csexton/debugger-action)
- [Cisco](https://www.cisco.com/)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean's OpenWrt](https://github.com/coolsnowwolf/lede)

## License

Most files under

[MIT](https://github.com/tete1030/openwrt-fastbuild-actions/blob/master/LICENSE) © Texot

Original idea and some files under

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE) © P3TERX

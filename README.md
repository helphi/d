# Golang 包依赖管理脚本

通过 Bash 脚本管理 Golang 的包依赖，目前只支持 git。[官方wiki](https://github.com/golang/go/wiki/PackageManagementTools) 中也推荐了很多工具，相比这些工具本脚本不会过多联网，速度快。而其最大的好处就是纯脚本，可以自行根据需要修改。

## 使用方式

1. 将 `d.sh` 和 `d.conf` 下载到项目根目录
1. 修改 `d.conf` 配置文件
1. 然后执行以下指令：

```sh
bash d.sh
```

或

```sh
chmod +x d.sh
./d.sh
```

## 配置文件说明

配置文件需命名为 `d.conf`，其语法说明如下，示例见 [d.conf](d.conf)

### 语法格式
```
*PKG@VERSION URL>DIR
```

### 语法示例
```
*golang.org/x/net/websocket@release-branch.go1.10 https://github.com/golang/net.git>golang.org/x/net
```

### 语法解释
- `*` 用于表示依赖包是否用 `go install` 进行安装，不写表示不安装；这里也可以用 `-` 代替 `*` 表示不使用 `go get -d` 进行依赖包的解析，如果只想下载这个依赖包而不想解析并下载依赖包的依赖则应该使用 `-`
- `PKG` 所依赖的包名，必填
- `VERSION` 所依赖包的版本号，可以是 `TAG`、`BRANCH` 或者任何 `git checkout` 可以接受的值，不写则不会执行 `git checkout` 操作
- `URL` 依赖包的源码库地址，不写则使用 `https://DIR.git` 作为源码库 url
- `DIR` 源码库下载到本地的相对目录，不写则直接提取包名中的 `域名/所有者/库名` 作为相对目录，如果是本地包则直接使用包名

## 功能说明

本脚本默认下载依赖到 `vendor` 目录，也可以通过添加参数 `nv` 直接下载到 `$GOPATH\src`，即 `bash d.sh nv`。

使用 `nv` 参数的话建议在 `$GOPATH\src` 级别来隔离 app，比如有一个 app1 位于 `$GOPATH\src\app1`，当我们建立 app2 时应该先 `mv $GOPATH\src $GOPATH\src.app1` 然后再 `mkdir $GOPATH\src\app2`，这样可以避免包管理的冲突。

本脚本主要包含以下几个处理过程：

### 解析配置文件

主要对配置文件 `d.conf` 进行解析，比如当 `DIR` 没有设置的时候根据 `PKG` 提取相对目录等。解析完成后会将解析结果打印出来。

### 用 git 下载代码

对于配置了 `URL` 的包会调用 `git clone --mirror` 用镜像的方式先将其缓存到 `$GOPATH\mirror` 中，如果缓存已经存在则会跳过。镜像完成后再用 `git clone` 从本地缓存克隆到 `$GOPATH\src` 中，克隆操作之前都会先删除之前的目录以保持最新。

使用本地镜像缓存是为了让这些缓存可以重用，避免重复下载。如果长时间不更新缓存可能会出现找不到较新版本代码的情况，这时可以调用脚本时添加参数 `u` 更新镜像缓存，即 `bash d.sh u`，镜像的更新使用 `git remote update` 实现。

如果多个 app 之间对于用一个包配置的 URL 不一样，那么镜像缓存中的代码有可能不是我们想要的代码，因为它们的代码源地址都不一样，如果出现这种情况可以将改镜像删除然后重新执行脚本，因此我们应该尽量保持各个 app 的镜像源一致。

### 用 go get 下载代码

对所有的包都执行一遍 `go get` 指令，这样做是为了使用 `go get` 原生的包解析功能下载这个依赖包所依赖的包，这个过程没有用脚本实现是因为难度太大。，这个步骤在使用了 `nv` 参数情况下才执行，因为 `go get` 使用的是 `$GOPATH/src` 下面的源码，而不是当前项目的 `vendor` 目录。

### 设置版本

对于指定了版本的包使用 `git checkout` 为其检出相应的版本

### 安装

对于设置了安装标识的包调用 `go install` 进行安装，这个步骤也是在使用了 `nv` 参数情况下才执行，因为 `go install` 使用的是 `$GOPATH/src` 下面的源码，而不是当前项目的 `vendor` 目录。

-------------

**如果您发现任何 bug 或者想要扩展该脚本欢迎提交 PR**


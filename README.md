# Golang 包依赖管理脚本

通过 Bash 脚本管理 Golang 的包依赖，目前只支持 git。

## 使用方式

```sh
bash d.sh
```

或

```
chmod +x d.sh
./d.sh
```

## 配置文件说明

配置文件需命名为 `d.conf`，其语法说明如下，示例见 [d.conf](d.conf)

**语法格式：**
```
*PKG@VERSION URL>DIR
```

**语法示例：**
```
*golang.org/x/net/websocket@release-branch.go1.10 https://github.com/golang/net.git>golang.org/x/net
```

**语法解释：**
- `*` 用于表示源码下载完成后是否执行 `go install` 进行安装，不写表示不安装
- `PKG` 所依赖的包名，必填
- `VERSION` 所依赖包的版本号，可以是 `TAG`、`BRANCH` 或者任何 `git checkout` 可以接受的值，不写则不会执行 `git checkout` 操作
- `URL` 依赖包的源码库地址，不写则直接调用 `go get` 解析源码库 url
- `DIR` 源码库下载到本地的相对目录，不写则直接提取包名中的 `域名/所有者/库名` 作为相对目录，如果是本地包则直接使用包名

## 功能说明

本脚本适合在 `$GOPATH\src` 中直接管理包依赖，如果你更喜欢用 go 提供的 `vendor` 机制来管理，可以参考 [官方wiki](https://github.com/golang/go/wiki/PackageManagementTools) 中推荐的工具。


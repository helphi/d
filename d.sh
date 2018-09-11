#!/bin/bash

set -e

#打印用法
usage() {
    echo "用法："
    echo "  bash d.sh [-h] [-n] [-u] [-f 依赖配置文件]"
    echo "描述："
    echo "  -h, 使用帮助"
    echo "  -n, 不使用 vendor 目录存储依赖包源码，而是存储在 $GOPATH/src 中"
    echo "  -u, 从远端库更新，默认情况使用本地缓存"
    echo "  -f, 指定依赖配置文件，默认为 d.conf"
    exit -1
}

#GOPATH必须存在
: ${GOPATH?"请先设置 GOPATH 环境变量"}

#是否使用vendor目录
noVendor=false
#是否从远端库更新
update=false
#依赖的配置文件路径，默认为当前目录下的d.conf
confPath="d.conf"

while getopts 'hnuf:' arg; do
    case $arg in
        n) noVendor=true;;
        u) update=true;;
        f) confPath="$arg";;
        h) usage;;
        ?) usage;;
    esac
done

echo noVendor=$noVendor
echo update=$update
echo confPath=$confPath

#代码库镜像地址，用于将下载的代码库缓存下来，避免后面重复下载
mirrorPath="$GOPATH/mirror"

#存储包名
pkgArr=()
#存储包对应版本号
verArr=()
#存储下载包对应的url地址
urlArr=()
#存储包下载到本地的路径
dirArr=()
#存储包是否需要安装
installArr=()

#将预设分隔符(Internal Field Seperator)修改为换行符（默认是空格），以便读取配置文件中的每一行记录
OLD_IFS="$IFS"
IFS=$'\n'

#循环分析每一行配置，并将分析结果存储到上面定义的数组中
for line in `grep -v -e '^[[:space:]]*$' "$confPath"`; do
  #按空格分离每行配置，空格前面为包相关配置，后面为包对应url相关配置
  IFS="$OLD_IFS"
  lineArr=($line)
  IFS="$OLD_IFS"

  #取包相关配置
  pkgVer="${lineArr[0]}"
  #取包对应url相关配置
  urlDir="${lineArr[1]}"

  #按@符号分离包相关配置，@前面为包名相关配置，@后面为对应的版本号
  IFS="@"
  pkgVerArr=($pkgVer)
  IFS="$OLD_IFS"

  #取版本号
  verArr+=("${pkgVerArr[1]}")
  #取包名相关配置
  pkg="${pkgVerArr[0]}"

  #由于包名相关配置前面可能有安装相关标识符，如果有，需要提取出来
  install=""
  if [ "*" == "${pkg:0:1}" ];then
    pkg=("${pkg:1}")
    install=("*")
  fi
  if [ "-" == "${pkg:0:1}" ];then
    pkg=("${pkg:1}")
    install=("-")
  fi
  #取包名
  pkgArr+=("$pkg")
  #取标识符
  installArr+=("$install")

  #处理下载包的url地址和下载到本地的存储路径
  url=""
  dir=""
  #先将url和存储路径分离出来
  if [ -n "$urlDir" ];then
    IFS=">"
    urlDirArr=($urlDir)
    IFS="$OLD_IFS"

    url=("${urlDirArr[0]}")
    dir="${urlDirArr[1]}"
  fi
  #如果本地存储路径未指定，则从包名中提取
  if [ -z "$dir" ];then
    IFS="/"
    dirTmpArr=($pkg)
    IFS="$OLD_IFS"
    len=${#dirTmpArr[@]}
    IFS=$OLD_IFS
    #如果包名中没有完全包含<域名/所有者/库名>三部分，则直接使用包名作为路径，否则就只提取这三部分出来作为路径
    [ $len -le 3 ] && dir=("$pkg") || dir=("${dirTmpArr[0]}/${dirTmpArr[1]}/${dirTmpArr[2]}")
  fi
  #如果url不存在则使用本地存储路径dir来组装
  if [ -z "$url" ];then
    url="https://$dir.git"
  fi
  #取下载的url
  urlArr+=("$url")
  #取本地存储路径
  dirArr+=("$dir")
done
IFS="$OLD_IFS"

#将分析结果打印出来
echo -e "\n#################### CONFIG ANALYSIS ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  echo "${installArr[i]}${pkgArr[i]}@${verArr[i]} ${urlArr[i]}>${dirArr[i]}"
done

#代码库下载
echo -e "\n#################### GIT CLONE ####################"
#如果没有不使用vendor，就先删除vendor中的源码
if ! $noVendor;then
  rm -rf vendor
  mkdir vendor
fi

for ((i=0;i<${#pkgArr[@]};i++));do
  pkg="${pkgArr[i]}"
  ver="${verArr[i]}"
  url="${urlArr[i]}"
  dir="${dirArr[i]}"

  mirrorPathTmp="$mirrorPath/$dir.git"

  #如果镜像目录已经存在，则直接跳过clone避免重复下载，如果加了强制更新参数-u，还需要对库进行update操作获取更新
  if [ ! -d "$mirrorPathTmp" ];then
    echo ">>> clone mirror <$url> to <$mirrorPathTmp>"
    git clone --mirror "$url" "$mirrorPathTmp"
  elif $update;then
    echo ">>> update mirror <$url> in <$mirrorPathTmp>"
    OLD_PWD=`pwd`
    cd $mirrorPathTmp
    git remote update
    cd $OLD_PWD
  fi
  
  #复制源码的目的地址，默认复制到vendor/src
  toPathTmp="vendor/$dir"
  #如果不使用vendor，就往$GOPATH/src中复制
  if $noVendor ;then
    toPathTmp="$GOPATH/src/$dir"
    #复制代码库的时候先将目的地址中的内容全部删除
    rm -rf toPathTmp
  fi

  echo ">>> clone $mirrorPathTmp to $toPathTmp"
  #使用clone的方式复制代码库，以保持git相关数据
  git clone -l "$mirrorPathTmp" "$toPathTmp"
  OLD_PWD=`pwd`
  cd "$toPathTmp"
  #由于本地clone后远程仓库地址为本地文件路径，所以需要将远程仓库地址还原为url，避免go get等指令链接远程仓库时出错
  git remote set-url origin "$url"
  cd $OLD_PWD
  echo "----------"
done

#如果配置中的依赖包有自己的依赖，还需要使用go get进行下载，如果要使用vendor，则不执行该操作
if $noVendor ;then
  echo -e "\n#################### GO GET ####################"
  for ((i=0;i<${#pkgArr[@]};i++));do
    #如果标识符为-，则跳过该步骤
    [ "-" == "${installArr[i]}" ] && continue
    echo ">>> go get -v -d ${pkgArr[i]}"
    #使用go get指令时加上-d参数只下载不安装，是否安装在后续的步骤中仍然通过标识符来判断
    go get -v -d "${pkgArr[i]}"
    echo "----------"
  done
fi

#检出指定的版本
echo -e "\n#################### GIT CHECKOUT ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  OLD_PWD=`pwd`

  #依赖包源码的目的地址，如果不使用vendor，就在$GOPATH/src下，否则就默认在vendor下
  $noVendor && toPathTmp="$GOPATH/src/${dirArr[i]}" || toPathTmp="vendor/${dirArr[i]}"

  cd "$toPathTmp"

  #指定版本号才检出
  if [ -n "${verArr[i]}" ];then
    echo ">>> git checkout -q ${verArr[i]} in $toPathTmp"
    git checkout -q "${verArr[i]}"
  fi

  #如果使用vendor目录，则将git相关数据删除
  if ! $noVendor ;then
    rm -rf .git
  fi

  echo "----------"
  cd $OLD_PWD
done

#对于标识符为*的包进行安装
echo -e "\n#################### GO INSTALL ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  [ "*" != "${installArr[i]}" ] && continue

  #依赖包源码的目的地址，默认在vendor下，如果不使用vendor，就在$GOPATH/src下
  $noVendor && pkgTmp="${pkgArr[i]}" || pkgTmp="./vendor/${pkgArr[i]}"
  echo "go install $pkgTmp"
  go install "$pkgTmp"
  echo "----------"
done

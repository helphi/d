#!/bin/bash

set -e

: ${GOPATH?"please set GOPATH environment variable first"}

confPath="d.conf"

pkgArr=()
verArr=()
urlArr=()
dirArr=()
installArr=()

OLD_IFS="$IFS"
IFS=$'\n'
for line in `grep -v -e '^[[:space:]]*$' "$confPath"`; do
  IFS="$OLD_IFS"
  lineArr=($line)
  IFS="$OLD_IFS"

  pkgVer="${lineArr[0]}"
  urlDir="${lineArr[1]}"

  IFS="@"
  pkgVerArr=($pkgVer)
  IFS="$OLD_IFS"

  verArr+=("${pkgVerArr[1]}")
  pkg="${pkgVerArr[0]}"
  install=""
  if [ "*" == "${pkg:0:1}" ];then
    pkg=("${pkg:1}")
    install=("*")
  fi
  if [ "-" == "${pkg:0:1}" ];then
    pkg=("${pkg:1}")
    install=("-")
  fi
  pkgArr+=("$pkg")
  installArr+=("$install")

  url=""
  dir=""
  if [ -n "$urlDir" ];then
    IFS=">"
    urlDirArr=($urlDir)
    IFS="$OLD_IFS"

    url=("${urlDirArr[0]}")
    dir="${urlDirArr[1]}"
  fi
  if [ -z "$dir" ];then
    IFS="/"
    dirTmpArr=($pkg)
    IFS="$OLD_IFS"
    len=${#dirTmpArr[@]}
    IFS=$OLD_IFS
    [ $len -le 3 ] && dir=("$pkg") || dir=("${dirTmpArr[0]}/${dirTmpArr[1]}/${dirTmpArr[2]}")
  fi
  if [ -z "$url" ];then
    url="https://$dir.git"
  fi
  urlArr+=("$url")
  dirArr+=("$dir")
done
IFS="$OLD_IFS"

echo -e "\n#################### CONFIG ANALYSIS ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  echo "${installArr[i]}${pkgArr[i]}@${verArr[i]} ${urlArr[i]}>${dirArr[i]}"
done

echo -e "\n#################### GIT CLONE ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  pkg="${pkgArr[i]}"
  ver="${verArr[i]}"
  url="${urlArr[i]}"
  dir="${dirArr[i]}"

  mirrorPath="$GOPATH/mirror/$dir.git"

  if [ ! -d "$mirrorPath" ];then
    echo ">>> clone mirror <$url> to <$mirrorPath>"
    git clone --mirror "$url" "$mirrorPath"
  elif [ "$1" == "u" ];then
    echo ">>> update mirror <$url> in <$mirrorPath>"
    OLD_PWD=`pwd`
    cd $mirrorPath
    git remote update
    cd $OLD_PWD
  fi
  
  rm -rf "$GOPATH/src/$dir"
  echo ">>> clone $mirrorPath to $GOPATH/src/$dir"
  git clone -l "$mirrorPath" "$GOPATH/src/$dir"
  echo "----------"
done

echo -e "\n#################### GO GET ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  [ "-" == "${installArr[i]}" ] && continue
  echo ">>> go get -v -d ${pkgArr[i]}"
  go get -v -d "${pkgArr[i]}"
  echo "----------"
done

echo -e "\n#################### GIT CHECKOUT ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  [ -z "${verArr[i]}" ] && continue
  OLD_PWD=`pwd`
  cd "$GOPATH/src/${dirArr[i]}"
  echo ">>> git checkout -q ${verArr[i]} in $GOPATH/src/${dirArr[i]}"
  git checkout -q "${verArr[i]}"
  echo "----------"
  cd $OLD_PWD
done

echo -e "\n#################### GO INSTALL ####################"
for ((i=0;i<${#pkgArr[@]};i++));do
  [ "*" != "${installArr[i]}" ] && continue
  echo "go install ${pkgArr[i]}"
  go install "${pkgArr[i]}"
  echo "----------"
done

#!/bin/bash
###################################################################################
# Title         : enable-detective-all-regions.sh
# Description   : 全リージョンのAmazon Detectiveを有効化。
#                 大阪(ap-northeast-3)、ジャカルタ(ap-southeast-3)、UAE(me-central-1)の3リージョンは、
#                 2022年9月時点でDetectiveが利用できないため、有効化対象外とする。
# Author        : IIJ takeda-m
# Date          : 2022.09.21
###################################################################################
# 実行条件：Detectiveを有効化したいAWSアカウントのCloudShellで実行すること。
# 引数：なし
# リターンコード：0 (成功)、1 (失敗)
###################################################################################

# ログファイル
LOGFILE=$(pwd)/enable-detective-all-regions.log

######################
# 関数：INFOログ出力
######################
function info() {
  local fname=${BASH_SOURCE[1]##*/}
  echo -e "$(date '+%Y-%m-%dT%H:%M:%S') [INFO] (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $@" | tee -a ${LOGFILE}
}

######################
# 関数：ERRORログ出力
######################
function err() {
  local fname=${BASH_SOURCE[1]##*/}
  echo -e "$(date '+%Y-%m-%dT%H:%M:%S') [ERROR] (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $@" | tee -a ${LOGFILE}
}

#######################################################
# メイン関数
# 引数：なし
# リターンコード：0 (成功)、1 (失敗)
#######################################################
function main(){
  # 環境変数DEBUG_MODEがonの場合、ステップ実行機能を有効にする。
  if [[ "${DEBUG_MODE}" = "on" ]]; then trap 'read -p "$0($LINENO) $BASH_COMMAND"' DEBUG ;fi

  ### 変数宣言 ###
  local regions # リージョン一覧
  local result # コマンド実行結果

  # cloudshell-userユーザで実行されていることの確認（CloudShellで実行されていることの確認）
  if [[ "$(whoami)" != "cloudshell-user" ]] ; then
    err '実行ユーザがcloudshell-userではありません。CloudShellで実行していることを確認して下さい。'
    return 1
  fi
  
  # リージョン一覧を取得
  info 'リージョン一覧を取得'
  info 'aws ec2 describe-regions --query Regions[].RegionName --output text'
  result=$(aws ec2 describe-regions --query Regions[].RegionName --output text 2>&1)
  if [[ $? -ne 0 ]]; then
    err "${result}"
    err 'リージョン一覧の取得に失敗しました。'
    return 1
  else
    info "${result}"
    regions=${result}
  fi

  # 大阪(ap-northeast-3)、ジャカルタ(ap-southeast-3)、UAE(me-central-1)の3リージョンを対象から除外
  info '大阪(ap-northeast-3)、ジャカルタ(ap-southeast-3)、UAE(me-central-1)の3リージョンを対象から除外'
  regions=$(echo ${regions} | sed -e 's/ap-northeast-3//g' -e 's/ap-southeast-3//g' -e 's/me-central-1//g')
  info "${regions}"

  # Detectiveを有効化
  for region in ${regions}; do
    info "${region}リージョンのDetectiveを有効化"
    info "aws detective create-graph --region ${region} --output text"
    result=$(aws detective create-graph --region ${region} --output text 2>&1)
    if [[ $? -ne 0 ]]; then
      err "${result}"
      err "${region}リージョンのDetectiveの有効化に失敗しました。"
      return 1
    else
      info "${result}"
    fi
  done

  # Detective有効化の確認
  for region in ${regions}; do
    info "${region}リージョンのDetective有効化を確認"
    info "aws detective list-graphs --query GraphList[].Arn --region ${region} --output text"
    result=$(aws detective list-graphs --query GraphList[].Arn --region ${region} --output text 2>&1)
    if [[ $? -ne 0 ]]; then
      err "${result}"
      err "${region}リージョンのDetective有効化の確認に失敗しました。"
      return 1
    elif [[ -z "$result" ]]; then
      err "${result}"
      err "${region}リージョンのDetectiveが有効になっていません。"
      return 1
    else
      info "${result}"
    fi
  done

  return 0
}

###########################################################
# メイン関数へのエントリー
###########################################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  # 環境変数DEBUG_MODEがonの場合、ステップ実行機能を有効にする。
  if [[ "${DEBUG_MODE}" = "on" ]]; then trap 'read -p "$0($LINENO) $BASH_COMMAND"' DEBUG ;fi

  info '全リージョンのAmazon Detectiveを有効化 開始'
  main $1 $2
  if [[ $? = 0 ]]; then
    info '全リージョンのAmazon Detectiveを有効化 正常終了'
    exit 0
  else
    err '全リージョンのAmazon Detectiveを有効化 異常終了'
    exit 1
  fi

fi

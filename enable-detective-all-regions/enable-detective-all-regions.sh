#!/bin/bash
###################################################################################
# Title         : enable-detective-all-regions.sh
# Description   : 全リージョンのAmazon Detectiveを有効化。
#                 大阪(ap-northeast-3)、ジャカルタ(ap-southeast-3)、UAE(me-central-1)の3リージョンは、
#                 2022年9月時点でDetectiveが利用できないため、有効化対象外とする。
# Author        : IIJ takeda-m
# Date          : 2022.03.03
###################################################################################
# 実行条件：Detectiveを有効化したいAWSアカウントのCloudShellで実行すること。
# 引数：なし
# リターンコード：0 (成功)、1 (失敗)
###################################################################################

# ログファイル
LOGFILE=$(pwd)/enable-detective-all-regions.log

# タグ
NAME_TAGKEY="Name" # Nameタグのキー値
NAME_TAGVAL="iijsecbase-detective" # Nameタグのキー値
CREATEDBY_TAGKEY="CreatedBy" # CreatedByタグのキー
CREATEDBY_TAGVAL="iijsecbase" # CreatedByタグの値
IIJCOSTTAG_TAGKEY="iij-cost-tag" # iij-cost-tagタグのキー
IIJCOSTTAG_TAGVAL="iijsecbase" # iij-cost-tagタグの値

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
  local detective_arn # DetectiveリソースのARN

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
    # Detective有効化
    info "${region}リージョンのDetectiveを有効化"
    info "aws detective create-graph --region ${region} --output text"
    result=$(aws detective create-graph --region ${region} --output text 2>&1)
    if [[ $? -ne 0 ]]; then
      err "${result}"
      err "${region}リージョンのDetectiveの有効化に失敗しました。"
      return 1
    else
      info "${result}"
      detective_arn=${result}
    fi
    # タグ付け
    info "${region}リージョンのDetectiveへのタグ付け"
    info "aws detective tag-resource --resource-arn ${detective_arn} --tags ${NAME_TAGKEY}=${NAME_TAGVAL},${CREATEDBY_TAGKEY}=${CREATEDBY_TAGVAL},${IIJCOSTTAG_TAGKEY}=${IIJCOSTTAG_TAGVAL} --region ${region} --output text"
    result=$(aws detective tag-resource --resource-arn ${detective_arn} --tags ${NAME_TAGKEY}=${NAME_TAGVAL},${CREATEDBY_TAGKEY}=${CREATEDBY_TAGVAL},${IIJCOSTTAG_TAGKEY}=${IIJCOSTTAG_TAGVAL} --region ${region} --output text 2>&1)
    if [[ $? -ne 0 ]]; then
      err "${result}"
      err "${region}リージョンのDetectiveへのタグ付けに失敗しました。"
      return 1
    fi
  done

  # Detective有効化の確認
  for region in ${regions}; do
    # Detective有効化確認
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
      detective_arn=${result}
    fi
    # タグ付け確認
    info "${region}リージョンのDetectiveタグ付けの確認"
    info "aws detective list-tags-for-resource --resource-arn ${detective_arn} --query \"Tags\" --region ${region}"
    result=$(aws detective list-tags-for-resource --resource-arn ${detective_arn} --query "Tags" --region ${region} 2>&1)
    if [[ $? -ne 0 ]]; then
      err "${result}"
      err "${region}リージョンのDetectiveタグ付けの確認に失敗しました。"
      return 1
    else
      info ${result}
      name_tag_value=$(echo ${result} | jq -r .${NAME_TAGKEY})
      createdby_tag_value=$(echo ${result} | jq -r .${CREATEDBY_TAGKEY})
      iijcosttag_tag_value=$(echo ${result} | jq -r .\"${IIJCOSTTAG_TAGKEY}\")
      if [[ "${name_tag_value}" != "${NAME_TAGVAL}" ]] || [[ "${createdby_tag_value}" != "${CREATEDBY_TAGVAL}" ]] || [[ "${iijcosttag_tag_value}" != "${IIJCOSTTAG_TAGVAL}" ]]; then
        err "${region}リージョンのDetectiveに正しく付与されていないタグが存在しました。"
        return 1
      fi
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

#!/bin/bash
# Parole の読み上げ音声を作る（Mac 用）
#
# 使い方：ターミナルでこのフォルダに移動して
#     caffeinate -i bash make_audio.sh
# （caffeinate は作業中に Mac がスリープしないようにするコマンド）
#
# ・4人の声（Federica / Emma / Paola / Luca）を同時に作ります。
# ・途中で止めても（control + C）、もう一度実行すれば続きから作ります。
# ・ある声だけ作り直したいときは、audio フォルダの中のその声のフォルダを消してから実行します。
#   （例：Mac をアップデートして Emma のプレミアムが入ったら audio/emma を消す）

set -u
cd "$(dirname "$0")"

RATE=165          # 読む速さ（1分あたりの語数）。ゆっくりにしたいときは数を小さく
OUT=audio
VOICES="federica:Federica emma:Emma paola:Paola luca:Luca"

if [ ! -f texts.tsv ]; then echo "texts.tsv が見つかりません。make_audio.sh と同じフォルダに置いてください。"; exit 1; fi
TOTAL=$(wc -l < texts.tsv | tr -d ' ')

# この Mac にあるイタリア語の声の名前の一覧
LIST=$(say -v '?' | grep -E '[[:space:]]it_IT[[:space:]]' | sed -E 's/[[:space:]]+it_IT[[:space:]].*$//')

# 名前から、いちばん高音質な声を選ぶ（プレミアム → 拡張 → 標準）
pick(){
  local base="$1" v
  v=$(printf '%s\n' "$LIST" | grep -iE "^$base[[:space:]]*[(（].*(premium|プレミアム)" | head -n1)
  [ -z "$v" ] && v=$(printf '%s\n' "$LIST" | grep -iE "^$base[[:space:]]*[(（].*(enhanced|拡張)" | head -n1)
  [ -z "$v" ] && v=$(printf '%s\n' "$LIST" | grep -E "^$base[[:space:]]*$" | head -n1)
  printf '%s' "$v"
}

make(){
  local key="$1" voice="$2" dir="$OUT/$1" n=0 tmp="/tmp/parole_$1_$$.aiff"
  mkdir -p "$dir"
  while IFS=$'\t' read -r id text; do
    n=$((n + 1))
    [ -z "$id" ] && continue
    if [ ! -s "$dir/$id.m4a" ]; then
      if say -v "$voice" -r "$RATE" -o "$tmp" "$text" < /dev/null \
         && afconvert -f m4af -d aac -b 32000 "$tmp" "$dir/$id.m4a" < /dev/null 2>/dev/null; then :
      else
        rm -f "$dir/$id.m4a"
        echo "[$key] 作れませんでした: $text" >> errors.log
      fi
    fi
    [ $((n % 250)) -eq 0 ] && echo "[$key] $n / $TOTAL"
  done < texts.tsv
  rm -f "$tmp"
  echo "[$key] 完了"
}

echo "使う声："
STARTED=0
for spec in $VOICES; do
  key=${spec%%:*}; base=${spec#*:}
  v=$(pick "$base")
  if [ -z "$v" ]; then
    echo "  $base … 見つかりません。システム設定 → アクセシビリティ → 読み上げコンテンツ → システムの声 からダウンロードしてください"
    continue
  fi
  echo "  $base … $v"
done
echo
echo "$TOTAL 本 × 声の数 を作ります。しばらくかかります（目安：1〜3時間）。"
echo

for spec in $VOICES; do
  key=${spec%%:*}; base=${spec#*:}
  v=$(pick "$base")
  [ -z "$v" ] && continue
  make "$key" "$v" &
  STARTED=$((STARTED + 1))
done
wait

echo
if [ -f errors.log ]; then echo "一部の音声が作れませんでした（errors.log を見てください）。もう一度実行すると作り直します。"; fi
echo "完了しました。audio フォルダを、GitHub の index.html と同じ場所に入れてください。"

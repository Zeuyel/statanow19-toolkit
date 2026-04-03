#!/usr/bin/env bash
set -euo pipefail

readonly ALPH="0123456789abcdefghijklmnopqrstuvwxyz$"
readonly MOD=37
readonly PROFILE_NAME="statanow19"
readonly DISPLAY_NAME="StataNow 19"
readonly DEFAULT_PRESET="mp64"
readonly DEFAULT_OUTPUT="~/.config/statanow19-runtime/stata.lic"
readonly FIELD6_REQUIRED=1
readonly YEAR_MAX="2050"

serial=""
field1=""
field2=""
field3=""
field4=""
field5=""
field6=""
field7=""
line1=""
line2=""
preset="$DEFAULT_PRESET"
split_prefix=4
output=""
format="text"
interactive="auto"
allow_warnings=0
has_custom_args=0
write_output=0

payload=""
encoded=""
authorization=""
code=""
checksum_value=""
license_text=""
written_to=""
errors=()
warnings=()

declare -A overrides=()
declare -A override_set=()

die() {
  echo "error: $*" >&2
  exit 2
}

warn_msg() {
  echo "warning: $*" >&2
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

expand_path() {
  local path="$1"
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    ~/*) printf '%s/%s\n' "$HOME" "${path#~/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

set_defaults() {
  serial="12345678"
  field1="999"
  field2="24"
  field3="5"
  field4="9999"
  field5="h"
  field6="01012050"
  field7="64"
  line1="LocalLab"
  line2="LocalLab"
}

apply_preset() {
  case "$1" in
    be)
      set_defaults
      field7=""
      ;;
    mp32)
      set_defaults
      field7="32"
      ;;
    mp64)
      set_defaults
      field7="64"
      ;;
    *)
      die "unknown preset: $1"
      ;;
  esac
}

usage() {
  cat <<EOF2
$DISPLAY_NAME license builder

Usage:
  $(basename "$0")                # interactive mode
  $(basename "$0") --preset mp64 --output ~/.config/statanow19-runtime/stata.lic
  $(basename "$0") --non-interactive --preset be --field6 01012050 --format license-only

Options:
  --interactive         force interactive mode
  --non-interactive     disable prompts
  --preset PRESET       one of: be, mp32, mp64
  --split-prefix N      split point between authorization and code (default: 4)
  --output PATH         write stata.lic to PATH
  --format FMT          text, license-only, json
  --allow-warnings      continue with warning-only parameter sets
  --serial VALUE
  --field1 VALUE
  --field2 VALUE
  --field3 VALUE
  --field4 VALUE
  --field5 VALUE
  --field6 VALUE
  --field7 VALUE
  --line1 VALUE
  --line2 VALUE
EOF2
}

char_ord() {
  printf '%d' "'$1"
}

char_to_digit() {
  local ch="$1"
  case "$ch" in
    [0-9]) printf '%d\n' "$ch" ;;
    [a-z]) printf '%d\n' $(( $(char_ord "$ch") - 87 )) ;;
    [A-Z]) printf '%d\n' $(( $(char_ord "$ch") - 55 )) ;;
    '$') printf '36\n' ;;
    *) return 1 ;;
  esac
}

digit_to_char() {
  local value="$1"
  printf '%s' "${ALPH:value:1}"
}

to_digits() {
  local text="$1"
  local -n out_ref="$2"
  local ch value
  out_ref=()
  for ((i = 0; i < ${#text}; i++)); do
    ch=${text:i:1}
    value=$(char_to_digit "$ch") || die "unsupported character in payload: $ch"
    out_ref+=("$value")
  done
}

join_by_dollar() {
  local -n arr_ref="$1"
  local old_ifs="$IFS"
  IFS='$'
  printf '%s' "${arr_ref[*]}"
  IFS="$old_ifs"
}

checksum_bytes() {
  LC_ALL=C printf '%s' "$1$2" | od -An -tu1 -v | awk '{for (i = 1; i <= NF; ++i) sum += $i} END {print sum + 0}'
}

build_payload() {
  local parts=("$serial" "$field1" "$field2" "$field3" "$field4" "$field5" "$field6")
  if [[ -n "$field7" ]]; then
    parts+=("$field7")
  fi
  payload=$(join_by_dollar parts)
}

encode_payload() {
  local -a prefix_values y partials encoded_values
  local sum_all=0 sum_odd=0 sum_even=0 acc=0 len

  to_digits "$payload" prefix_values
  for i in "${!prefix_values[@]}"; do
    sum_all=$(( (sum_all + prefix_values[i]) % MOD ))
    if (( i & 1 )); then
      sum_odd=$(( (sum_odd + prefix_values[i]) % MOD ))
    else
      sum_even=$(( (sum_even + prefix_values[i]) % MOD ))
    fi
  done

  y=("${prefix_values[@]}" "$sum_all" "$sum_odd" "$sum_even")
  partials=()
  for value in "${y[@]}"; do
    acc=$(( (acc + value) % MOD ))
    partials+=("$acc")
  done

  len=${#y[@]}
  encoded_values=()
  encoded_values[$((len - 1))]=${partials[$((len - 1))]}
  for ((i = len - 2; i >= 0; i--)); do
    encoded_values[i]=$(( (partials[i] + encoded_values[i + 1]) % MOD ))
  done

  encoded=""
  for value in "${encoded_values[@]}"; do
    encoded+=$(digit_to_char "$value")
  done
}

split_encoded() {
  [[ "$split_prefix" =~ ^[0-9]+$ ]] || die "split-prefix must be decimal digits"
  if ! (( split_prefix > 0 && split_prefix < ${#encoded} )); then
    die "invalid split-prefix=$split_prefix for encoded length ${#encoded}"
  fi
  authorization=${encoded:0:split_prefix}
  code=${encoded:split_prefix}
}

build_license() {
  build_payload
  encode_payload
  split_encoded
  checksum_value=$(checksum_bytes "$line1" "$line2")
  license_text="${serial}!${code}!${authorization}!${line1}!${line2}!${checksum_value}!"
}

validate_fields() {
  errors=()
  warnings=()

  for key in serial field1 field2 field3 field4; do
    if [[ ! ${!key} =~ ^[0-9]+$ ]]; then
      errors+=("$key must be decimal digits")
    fi
  done

  if [[ -z "$field5" || ! ${field5:0:1} =~ [a-h] ]]; then
    errors+=("field5 must start with a-h")
  fi

  if [[ "$line1" == *'!'* || "$line2" == *'!'* ]]; then
    errors+=("Licensed-to lines cannot contain '!'")
  fi

  if (( FIELD6_REQUIRED )) && [[ -z "$field6" ]]; then
    errors+=("field6 is required for this profile")
  fi

  if [[ -n "$field6" ]]; then
    if [[ ! "$field6" =~ ^[0-9]{8}$ ]]; then
      errors+=("field6 must be 8 digits in MMDDYYYY format")
    elif [[ -n "$YEAR_MAX" && ${field6:4:4} -gt $YEAR_MAX ]]; then
      errors+=("field6 year must be <= $YEAR_MAX")
    fi
  fi

  if [[ -n "$field7" ]]; then
    if [[ ! "$field7" =~ ^[0-9]+$ ]]; then
      errors+=("field7 must be decimal digits when present")
    elif (( field7 < 2 )); then
      errors+=("field7 must be >= 2 when present")
    elif (( field7 > 64 )); then
      warnings+=("field7 > 64 is accepted but runtime clamps it to 64")
    fi
  fi

  if [[ "$field2" != "24" ]]; then
    warnings+=("validated family uses field2=24")
  fi

  if [[ "$field3" != "2" && "$field3" != "5" ]]; then
    warnings+=("validated family uses field3 in {2,5}")
  fi
}

print_errors() {
  local line
  for line in "${errors[@]}"; do
    echo "error: $line" >&2
  done
}

print_warnings() {
  local line
  for line in "${warnings[@]}"; do
    echo "warning: $line" >&2
  done
}

prompt_default() {
  local label="$1"
  local default_value="$2"
  local reply
  read -r -p "$label [$default_value]: " reply || exit 1
  printf '%s' "${reply:-$default_value}"
}

prompt_yes_no() {
  local label="$1"
  local default_answer="$2"
  local suffix answer
  if [[ "$default_answer" == "y" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi
  read -r -p "$label $suffix: " answer || exit 1
  answer=${answer:-$default_answer}
  [[ "$answer" =~ ^[Yy]$ ]]
}


show_interactive_field_guide() {
  echo "参数说明:"
  echo "- be: 基础版模板, 不带 MP 核心数"
  echo "- mp32: MP 32 核模板"
  echo "- mp64: MP 64 核模板"
  echo "- field1/field2/field3: 内部兼容字段, 通常保持默认值 999 / 24 / 5"
  echo "- field4: 席位数/用户数, 9999 表示 Unlimited"
  echo "- field5: 授权类型, h 表示 student lab"
  echo "- field6: 到期日, StataNow 必填, 格式 MMDDYYYY, 例如 01012050"
  echo "- field7: MP 核心数, 基础版 BE 留空, MP 常见为 32 或 64"
  echo "- Licensed-to line1/line2: 授权名称显示文本"
  echo "- split-prefix: Authorization 和 Code 的内部切分位, 正常保持 4"
  echo
}

run_interactive() {
  local new_preset

  while :; do
    echo "交互式 license 生成器: $DISPLAY_NAME"
    echo

    show_interactive_field_guide
    new_preset=$(prompt_default "授权模板 preset: be=基础版, mp32=32核MP, mp64=64核MP" "$preset")
    if [[ "$new_preset" != "$preset" ]]; then
      preset="$new_preset"
      apply_preset "$preset"
    fi

    serial=$(prompt_default "序列号 Serial number" "$serial")
    field1=$(prompt_default "field1 产品族标记, 通常保持 999" "$field1")
    field2=$(prompt_default "field2 版本族标记, 通常保持 24" "$field2")
    field3=$(prompt_default "field3 edition 标记, 常用 5" "$field3")
    field4=$(prompt_default "field4 席位数/用户数, 9999=Unlimited" "$field4")
    field5=$(prompt_default "field5 授权类型, h=student lab" "$field5")
    field6=$(prompt_default "field6 到期日 MMDDYYYY, StataNow 必填" "$field6")
    field7=$(prompt_default "field7 MP 核心数, BE 留空" "$field7")
    line1=$(prompt_default "授权显示名称第1行" "$line1")
    line2=$(prompt_default "授权显示名称第2行" "$line2")
    split_prefix=$(prompt_default "split-prefix 内部分割位, 通常保持 4" "$split_prefix")

    validate_fields
    if ((${#errors[@]})); then
      print_errors
      echo
      echo "请重新输入这些值。"
      echo
      continue
    fi

    if ((${#warnings[@]})); then
      print_warnings
      if ! prompt_yes_no "存在警告, 是否继续" "n"; then
        echo
        continue
      fi
    fi

    if prompt_yes_no "是否写出 stata.lic 文件" "y"; then
      output=$(prompt_default "输出路径 Output path" "${output:-$DEFAULT_OUTPUT}")
      write_output=1
    else
      output=""
      write_output=0
    fi
    break
  done
}

write_license_file() {
  local expanded_output out_dir
  expanded_output=$(expand_path "$output")
  out_dir=$(dirname "$expanded_output")
  mkdir -p "$out_dir"
  printf '%s' "$license_text" > "$expanded_output"
  written_to="$expanded_output"
}

print_json() {
  local first=1 line
  printf '{\n'
  printf '  "profile": "%s",\n' "$(json_escape "$PROFILE_NAME")"
  printf '  "display_name": "%s",\n' "$(json_escape "$DISPLAY_NAME")"
  printf '  "serial": "%s",\n' "$(json_escape "$serial")"
  printf '  "payload": "%s",\n' "$(json_escape "$payload")"
  printf '  "encoded": "%s",\n' "$(json_escape "$encoded")"
  printf '  "authorization": "%s",\n' "$(json_escape "$authorization")"
  printf '  "code": "%s",\n' "$(json_escape "$code")"
  printf '  "checksum": "%s",\n' "$(json_escape "$checksum_value")"
  printf '  "license_text": "%s",\n' "$(json_escape "$license_text")"
  printf '  "default_output": "%s"' "$(json_escape "$DEFAULT_OUTPUT")"
  if [[ -n "$written_to" ]]; then
    printf ',\n  "written_to": "%s"' "$(json_escape "$written_to")"
  fi
  if ((${#warnings[@]})); then
    printf ',\n  "warnings": ['
    for line in "${warnings[@]}"; do
      if (( first )); then
        first=0
      else
        printf ', '
      fi
      printf '"%s"' "$(json_escape "$line")"
    done
    printf ']'
  fi
  printf '\n}\n'
}

print_text() {
  echo "Profile: $DISPLAY_NAME"
  echo "Payload: $payload"
  echo "Serial number: $serial"
  echo "Authorization: $authorization"
  echo "Code: $code"
  echo "Checksum: $checksum_value"
  if ((${#warnings[@]})); then
    echo "Warnings:"
    local line
    for line in "${warnings[@]}"; do
      echo "- $line"
    done
  fi
  if [[ -n "$written_to" ]]; then
    echo "License written to: $written_to"
  else
    echo "Suggested output path: $DEFAULT_OUTPUT"
  fi
  echo "stata.lic:"
  echo "$license_text"
}

parse_args() {
  local arg key
  while (($#)); do
    arg="$1"
    case "$arg" in
      --interactive)
        interactive=1
        shift
        ;;
      --non-interactive)
        interactive=0
        shift
        ;;
      --preset|--split-prefix|--output|--format)
        (($# >= 2)) || die "$arg requires a value"
        has_custom_args=1
        case "$arg" in
          --preset) preset="$2" ;;
          --split-prefix) split_prefix="$2" ;;
          --output) output="$2"; write_output=1 ;;
          --format) format="$2" ;;
        esac
        shift 2
        ;;
      --allow-warnings)
        allow_warnings=1
        has_custom_args=1
        shift
        ;;
      --serial|--field1|--field2|--field3|--field4|--field5|--field6|--field7|--line1|--line2)
        (($# >= 2)) || die "$arg requires a value"
        key=${arg#--}
        overrides["$key"]="$2"
        override_set["$key"]=1
        has_custom_args=1
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $arg"
        ;;
    esac
  done
}

apply_overrides() {
  local key
  for key in serial field1 field2 field3 field4 field5 field6 field7 line1 line2; do
    if [[ ${override_set[$key]:-0} -eq 1 ]]; then
      printf -v "$key" '%s' "${overrides[$key]}"
    fi
  done
}

main() {
  parse_args "$@"
  apply_preset "$preset"
  apply_overrides

  case "$format" in
    text|license-only|json) ;;
    *) die "unsupported format: $format" ;;
  esac

  if [[ "$interactive" == "auto" ]]; then
    if (( has_custom_args == 0 )) && [[ -t 0 && -t 1 ]]; then
      interactive=1
    else
      interactive=0
    fi
  fi

  if (( interactive )); then
    run_interactive
  else
    validate_fields
    if ((${#errors[@]})); then
      print_errors
      exit 2
    fi
    if ((${#warnings[@]})) && (( ! allow_warnings )); then
      print_warnings
      warn_msg "re-run with --allow-warnings to accept this parameter set"
      exit 3
    fi
  fi

  build_license

  if (( write_output )) && [[ -n "$output" ]]; then
    write_license_file
  fi

  case "$format" in
    text) print_text ;;
    license-only) echo "$license_text" ;;
    json) print_json ;;
  esac
}

main "$@"

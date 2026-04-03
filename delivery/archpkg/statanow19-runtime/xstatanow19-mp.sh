#!/bin/sh
set -eu

APP_ID='statanow19-runtime'
APP_ROOT="/opt/$APP_ID"
CFGDIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP_ID"
STATEDIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APP_ID"
RUNTIME_TEMPLATE="$APP_ROOT/runtime.template"
WORKDIR="$STATEDIR/runtime"
CONFIG_SAMPLE="$APP_ROOT/share/config.env.sample"
THEME_SAMPLE="$APP_ROOT/share/themes/mojave.gtkrc"
BUILDER="$APP_ROOT/tools/statanow19-license-builder.py"
STAMP_VALUE='19.5.0-1'
PRESET='mp64'
PROFILE_NAME='statanow19'
BINARY='xstata-mp'
MODE='gui'
LIBDIRS='/opt/statanow19-runtime/lib/gtk2:/opt/statanow19-runtime/lib/ncurses6'

ensure_config() {
  install -d "$CFGDIR"
  if [ ! -f "$CFGDIR/config.env" ]; then
    cp "$CONFIG_SAMPLE" "$CFGDIR/config.env"
  fi
  if [ -f "$THEME_SAMPLE" ] && [ ! -f "$CFGDIR/mojave.gtkrc" ]; then
    cp "$THEME_SAMPLE" "$CFGDIR/mojave.gtkrc"
  fi
}

ensure_workspace() {
  install -d "$STATEDIR"
  if [ ! -f "$WORKDIR/.app-stamp" ] || [ "$(cat "$WORKDIR/.app-stamp" 2>/dev/null || true)" != "$STAMP_VALUE" ]; then
    rm -rf "$WORKDIR"
    install -d "$WORKDIR"
    cp -a -s "$RUNTIME_TEMPLATE/." "$WORKDIR/"
    printf '%s\n' "$STAMP_VALUE" > "$WORKDIR/.app-stamp"
  fi
}

load_config() {
  # shellcheck disable=SC1090
  . "$CFGDIR/config.env"
  : "${STATA_SERIAL:=12345678}"
  : "${STATA_FIELD1:=999}"
  : "${STATA_FIELD2:=24}"
  : "${STATA_FIELD3:=5}"
  : "${STATA_FIELD4:=9999}"
  : "${STATA_FIELD5:=h}"
  : "${STATA_FIELD6:=}"
  : "${STATA_FIELD7:=}"
  : "${STATA_LINE1:=LocalLab}"
  : "${STATA_LINE2:=LocalLab}"
  : "${STATA_PRESET:=$PRESET}"
  : "${STATA_GTK_RC:=}"
}

write_license() {
  python3 "$BUILDER" \
    --preset "$STATA_PRESET" \
    --serial "$STATA_SERIAL" \
    --field1 "$STATA_FIELD1" \
    --field2 "$STATA_FIELD2" \
    --field3 "$STATA_FIELD3" \
    --field4 "$STATA_FIELD4" \
    --field5 "$STATA_FIELD5" \
    --field6 "$STATA_FIELD6" \
    --field7 "$STATA_FIELD7" \
    --line1 "$STATA_LINE1" \
    --line2 "$STATA_LINE2" \
    --output "$WORKDIR/stata.lic" \
    --allow-warnings \
    >/dev/null
}

main() {
  ensure_config
  ensure_workspace
  load_config
  write_license

  cd "$WORKDIR"
  if [ "$MODE" = gui ]; then
    THEME_FILE="$STATA_GTK_RC"
    if [ -z "$THEME_FILE" ]; then
      THEME_FILE="$CFGDIR/mojave.gtkrc"
    fi
    unset GTK_MODULES
    export GTK2_RC_FILES="$THEME_FILE"
  fi

  export LD_LIBRARY_PATH="$LIBDIRS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  exec "./$BINARY" "$@"
}

main "$@"

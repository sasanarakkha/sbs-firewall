#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

PACKAGE_NAME="sbs-firewall"
PACKAGE_VERSION="0.1.1"
PACKAGE_DESCRIPTION="TODO"
PACKAGE_URL="https//github.com/sasanarakkha/sbs-firewall"
PACKAGE_DEPENDS="firewall4 libc luci-base rpcd-mod-ucode ucode ucode-mod-debug ucode-mod-fs ucode-mod-log ucode-mod-socket ucode-mod-struct"

#
# Download/build apk-tools
#

test -d apk-tools ||
  git clone https://gitlab.alpinelinux.org/alpine/apk-tools.git apk-tools

(
  cd apk-tools
  git pull
  meson setup build
  ninja -C build
)

#
# Install/build HTML
#

pnpm install
pnpm run build-html

#
# Build ipk
#

rm -rf dist/ipk
mkdir -p dist/ipk/control

cat >dist/ipk/control/conffiles <<'EOF'
/etc/sbs/local_allowlist_ether.conf
/etc/sbs/local_blocklist_ether.conf
/etc/sbs/remote_allowlist_domain.conf
EOF

cat >dist/ipk/control/control <<EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Description: $PACKAGE_DESCRIPTION
URL: $PACKAGE_URL
Depends: $(echo "$PACKAGE_DEPENDS" | sed 's/ /, /g')
Architecture: all
License: AGPL-3.0-or-later
SourceDateEpoch: $(git log -1 --no-show-signature --format=format:%ct)
Installed-Size: $(du -bs tree | cut -f 1)
EOF

cat >dist/ipk/control/postinst <<'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_postinst $0 $@
EOF
chmod 755 dist/ipk/control/postinst

cat >dist/ipk/control/postinst-pkg <<'EOF'
[ -n "${IPKG_INSTROOT}" ] || {
  rm -f /tmp/luci-indexcache.*
  rm -rf /tmp/luci-modulecache/
  /etc/init.d/rpcd reload 2>/dev/null
  /etc/init.d/firewall restart 2>/dev/null
  /etc/init.d/sbs reload
  exit 0
}
EOF
chmod 755 dist/ipk/control/postinst-pkg

cat >dist/ipk/control/prerm <<'EOF'
#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_prerm $0 $@
EOF
chmod 755 dist/ipk/control/prerm

echo 2.0 >dist/ipk/debian-binary

cp -r tree dist/ipk/data

fakeroot tar -C dist/ipk/control -cz . >dist/ipk/control.tar.gz
fakeroot tar -C dist/ipk/data -cz . >dist/ipk/data.tar.gz
fakeroot tar -C dist/ipk -cz control.tar.gz data.tar.gz debian-binary \
  >"dist/$PACKAGE_NAME-$PACKAGE_VERSION.ipk"

rm -rf dist/ipk

#
# Build apk
#

rm -rf dist/apk
mkdir -p dist/apk
cp -r tree dist/apk/files
mkdir -p dist/apk/files/lib/apk/packages
find dist/apk/files -type f,l -printf '/%P\n' |
  sort >"dist/apk/files/lib/apk/packages/$PACKAGE_NAME.list"

fakeroot apk-tools/build/src/apk mkpkg \
  --info "name:$PACKAGE_NAME" \
  --info "version:$PACKAGE_VERSION" \
  --info "description:$PACKAGE_DESCRIPTION" \
  --info "url:$PACKAGE_URL" \
  --info "depends:$PACKAGE_DEPENDS" \
  --info "arch:all" \
  --files "dist/apk/files" \
  --output "dist/${PACKAGE_NAME}-${PACKAGE_VERSION}.apk"

rm -rf dist/apk

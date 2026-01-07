#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

PACKAGE_NAME="sbs-firewall"
PACKAGE_VERSION="0.1.2"
PACKAGE_DESCRIPTION="Internet access controls for a monastery."
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

postinst() {
  cat <<'EOF'
[ -n "${IPKG_INSTROOT}" ] || {
  rm -f /tmp/luci-indexcache.*
  rm -rf /tmp/luci-modulecache/
  /etc/init.d/rpcd reload 2>/dev/null
  /etc/init.d/firewall restart 2>/dev/null
  /etc/init.d/sbs reload
  exit 0
}
EOF
}

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

postinst >dist/ipk/control/postinst-pkg
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

cat >dist/apk/post-install <<EOF
#!/bin/sh
[ "\${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s \${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. \${IPKG_INSTROOT}/lib/functions.sh
export root="\${IPKG_INSTROOT}"
export pkgname="$PACKAGE_NAME"
add_group_and_user
default_postinst
$(postinst)
EOF
chmod 755 dist/apk/post-install

cat >dist/apk/post-upgrade <<EOF
#!/bin/sh
export PKG_UPGRADE=1
$(cat dist/apk/post-install)
EOF
chmod 755 dist/apk/post-upgrade

fakeroot apk-tools/build/src/apk mkpkg \
  --info "name:$PACKAGE_NAME" \
  --info "version:$PACKAGE_VERSION" \
  --info "description:$PACKAGE_DESCRIPTION" \
  --info "url:$PACKAGE_URL" \
  --info "depends:$PACKAGE_DEPENDS" \
  --info "arch:all" \
  --script "post-install:dist/apk/post-install" \
  --script "post-upgrade:dist/apk/post-upgrade" \
  --files "dist/apk/files" \
  --output "dist/${PACKAGE_NAME}-${PACKAGE_VERSION}.apk"

rm -rf dist/apk

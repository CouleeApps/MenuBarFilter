#!/bin/bash

set -o errexit
set -x

HERE=$PWD

if test -z "$1" ; then
  BUILT_PRODUCTS_DIR=/Applications
else
  BUILT_PRODUCTS_DIR="$1"
fi

PRODUCT_NAME=MenuBarFilter

VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Info" CFBundleVersion)
DOWNLOAD_BASE_URL="https://github.com/downloads/wez/MenuBarFilter"
 
ARCHIVE_FILENAME="${PRODUCT_NAME}_$VERSION.zip"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
 
WD=$PWD
rm -f "$PRODUCT_NAME"*.zip

cd "$BUILT_PRODUCTS_DIR"
ditto -ck --keepParent "$PRODUCT_NAME.app" "$HERE/$ARCHIVE_FILENAME"
cd "$HERE"
 
SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
 
SIGNATURE=$(openssl dgst -sha1 -binary < "$ARCHIVE_FILENAME" \
| openssl dgst -dss1 -sign dsa_priv.pem  \
| openssl enc -base64)
 
cat > appcast.xml <<EOF
<item>
    <title>Version $VERSION</title>
    <description>
    </description>
    <pubDate>$PUBDATE</pubDate>
    <enclosure
        url="$DOWNLOAD_URL"
        sparkle:version="$VERSION"
        type="application/octet-stream"
        length="$SIZE"
        sparkle:dsaSignature="$SIGNATURE"
    />
</item>
EOF

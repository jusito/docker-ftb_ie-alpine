#!/bin/sh

if [ "${DEBUGGING:?}" = "true" ]; then
	set -o xtrace
fi
set -o errexit
#set -o pipefail
set -o nounset

MCVER="1.12.2"
MCJAR="minecraft_server.${MCVER}.jar"
FORGEINSTALLER="forge-${MCVER}-${FORGE_VERSION}-installer.jar"
FORGEJAR="forge-${MCVER}-${FORGE_VERSION}-universal.jar"
JAVACMD="java"

if [ -f "reinstall" ]; then
	rm -f "reinstall"
	REINSTALL=true
else
	REINSTALL=false
fi

if [ -f "${MY_VOLUME}/RLCraft Server Pack*" ]; then
	echo "[ServerStart]Needing to move server files"
	mv -f "${MY_VOLUME}/RLCraft Server Pack*/*" "${MY_VOLUME}"
	rm -rf "${MY_VOLUME}/RLC*"
fi

if [ ! -f "${MY_VOLUME}/${MCJAR}" ] || [ "$REINSTALL" = "true " ]; then
	echo "[ServerStart]Downloading Minecraft Server"
	rm -rf minecraft_server.* || true
	wget -O "${MY_VOLUME}/${MCJAR}" "https://s3.amazonaws.com/Minecraft.Download/versions/${MCVER}/${MCJAR}"
fi
if [ ! -f "${MY_VOLUME}/${FORGEJAR}" ] || [ "$REINSTALL" = "true " ]; then
	echo "[ServerStart]Downloading Forge Server"
	rm -rf forge-* || true
	wget -O "${MY_VOLUME}/$FORGEINSTALLER" "http://files.minecraftforge.net/maven/net/minecraftforge/forge/${MCVER}-${FORGE_VERSION}/${FORGEINSTALLER}"
	java -jar "${MY_VOLUME}/$FORGEINSTALLER" --installServer
	rm -f "${MY_VOLUME}/$FORGEINSTALLER"
fi

"$JAVACMD" -server JAVA_PARAMETERS -jar "${MY_VOLUME}/${FORGEJAR}" nogui
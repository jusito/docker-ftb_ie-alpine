#!/bin/bash

if [ ! -f "test/shared/shared.sh" ]; then exit 1; fi
# shellcheck disable=SC1091
. test/shared/shared.sh
echo "[testHealth][INFO] starting..."

IMAGE="${REPO}:$1"
HEALTH=" " #default should be fine

function isHealthy() {
	container=$1
	healthy=$2
	info=$(docker ps | grep -F -e "$container")
	
	if [ "$healthy" = "true" ]; then
		state="(healthy)"
	else
		state="(unhealthy)"
	fi
	
	if [ -z "$info" ]; then
		echo "[testHealth][FATAL] $container isn't running"
		docker ps
		return 2
	else
		step=1
		while docker ps | grep -F -e "$container" | grep -Fq -e '(health: starting)'; do
			if [ "$step" = "1" ]; then
				echo -en "\r[testHealth][INFO] health is starting[-]..."
			elif [ "$step" = "2" ]; then
				echo -en "\r[testHealth][INFO] health is starting[\\]..."
			else
				echo -en "\r[testHealth][INFO] health is starting[/]..."
				step=0
			fi
			step=$((step+1))
			sleep 1s
		done
		echo -en "\r[testHealth][INFO] health is starting... done!\n"
		info=$(docker ps | grep -F -e "$container")
	fi
	
	if echo "$info" | grep -Fq -e "$state"; then
		echo "[testHealth][INFO] $container health state $state"
		return 0
	else
		echo "[testHealth[ERROR] $container health state $state"
		echo "$info" || true
		set +o errexit
		ps -o comm,pid,etime,vsz,stat,args
		docker exec "$container" "/home/checkHealth.sh" "debug"
		docker exec "$container" ls "/home/docker/"
		docker exec "$container" ls "/home/docker/logs/"
		# shellcheck disable=SC2002
		if docker exec "$container" grep -Eq -e ':\s*Done\s*\([0-9.]+\w?\)!' "/home/docker/logs/latest.log"; then
			echo "[testHealth][INFO] server log contains done"
		else
			echo "[testHealth][ERROR] server log DOESN'T contains done"
		fi
		set -o errexit
		return 3
	fi
}

function printDebug() {
	container=$1
	docker ps --filter "name=${TEST_CONTAINER}"
	if [ -z "$container" ]; then
		docker exec "$container" /home/checkHealth.sh debugMode || true
	fi
}

NAME_HEALTHY="${TEST_CONTAINER}_VanillaHealthy"
NAME_UNHEALTHY="${TEST_CONTAINER}_VanillaUnhealthy"
NAME_UNHEALTHY2="${TEST_CONTAINER}_VanillaFromHealthyToUnhealthy"

docker stop "$NAME_HEALTHY" "$NAME_UNHEALTHY" "$NAME_UNHEALTHY2" 2>/dev/null 1>/dev/null || true 

echo "[testHealth][INFO] starting container Healthy"
# shellcheck disable=SC2086
docker run -d --rm --name "$NAME_HEALTHY" -e DEBUGGING=${DEBUGGING} -e JAVA_PARAMETERS="-Xms2G -Xmx2G" $HEALTH "$IMAGE" 1>/dev/null
await "$NAME_HEALTHY" "/home/docker/logs/latest.log" "]: Done ("
ret=$?
if [ $ret = 0 ]; then
	echo "[testHealth][INFO] $NAME_HEALTHY starting done"
	isHealthy "$NAME_HEALTHY" true
	ret=$?
	if [ "$ret" = "0" ]; then
		echo "[testHealth][INFO] $NAME_HEALTHY looks healthy"	
	else
		echo "[testHealth][ERROR] $NAME_HEALTHY looks unhealthy"
		printDebug "$NAME_HEALTHY"
		exit 2
	fi
else
	echo "[testHealth][ERROR] $NAME_HEALTHY starting failed"
	printDebug "$NAME_HEALTHY"
	exit 1
fi
docker stop "$NAME_HEALTHY" 1>/dev/null || true






echo "[testHealth][INFO] starting Unhealthy"
# shellcheck disable=SC2086
docker run -d --rm --name "$NAME_UNHEALTHY" -e DEBUGGING=${DEBUGGING} -e JAVA_PARAMETERS="-Xms2G -Xmx2G" -e HEALTH_PORT="20" $HEALTH "$IMAGE" 1>/dev/null
await "$NAME_UNHEALTHY" "/home/docker/logs/latest.log" "]: Done ("
ret=$?
if [ "$ret" = "0" ]; then
	isHealthy "$NAME_UNHEALTHY" false
	ret=$?
	if [ "$ret" = "0" ]; then
		echo "[testHealth][INFO] $NAME_UNHEALTHY looks unhealthy"	
	else
		echo "[testHealth][ERROR] $NAME_UNHEALTHY looks healthy"
		printDebug "$NAME_UNHEALTHY"
		exit 4
	fi
else
	echo "[testHealth][ERROR] $NAME_UNHEALTHY starting failed"
	printDebug "$NAME_UNHEALTHY"
	exit 3
fi
docker stop "$NAME_UNHEALTHY" 1>/dev/null || true





echo "[testHealth][INFO] starting Healthy->Unhealthy"
# shellcheck disable=SC2086
docker run -d --rm --name "$NAME_UNHEALTHY2" -e DEBUGGING=${DEBUGGING} -e JAVA_PARAMETERS="-Xms2G -Xmx2G" $HEALTH "$IMAGE" 1>/dev/null

# make unhealth
echo "[testHealth][INFO] lets make it unhealthy"
docker cp "$NAME_UNHEALTHY2:/home/checkHealth.sh" MyFile
if [ ! -e MyFile ]; then
	echo "[testHealth][FATAL] failed to copy checkHealth.sh"
	exit 1
fi
echo "newLine" >> MyFile
chmod a=rwx MyFile
docker cp MyFile "$NAME_UNHEALTHY2:/home/checkHealth.sh"
echo "[testHealth][INFO] should be unhealthy"
await "$NAME_UNHEALTHY2" "/home/docker/logs/latest.log" "]: Done ("
ret=$?
if [ "$ret" = "0" ]; then
	isHealthy "$NAME_UNHEALTHY2" false
	ret=$?
	if [ "$ret" = "0" ]; then
		echo "[testHealth][INFO] $NAME_UNHEALTHY2 looks unhealthy"	
	else
		echo "[testHealth][ERROR] $NAME_UNHEALTHY2 looks healthy"
		printDebug "$NAME_UNHEALTHY2"
		exit 6
	fi
else
	echo "[testHealth][ERROR] $NAME_UNHEALTHY2 starting failed"
	printDebug "$NAME_UNHEALTHY2"
	exit 5
fi
docker stop "$NAME_UNHEALTHY2" 1>/dev/null || true

echo "[testHealth][INFO] successful!"
exit 0
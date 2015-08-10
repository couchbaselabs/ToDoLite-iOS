#  Copyright (c) 2014 Couchbase, Inc. All rights reserved.
# 
#  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
#  except in compliance with the License. You may obtain a copy of the License at
# 
#  http:// www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software distributed under the
#  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
#  either express or implied. See the License for the specific language governing permissions
#  and limitations under the License.
# 

#!/bin/bash

function usage 
{
	echo -e "\nUse: ${0} start|stop|clean\n"
}

PROJECT_DIR="$(pwd)"
SG_DIR="${PROJECT_DIR}/tmp"
SG_VER="1.1.0"
SG_BLD="24"
SG_URL="http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/release/${SG_VER}/${SG_VER}-$SG_BLD/couchbase-sync-gateway-community_${SG_VER}-${SG_BLD}_x86_64.tar.gz"
SG_PKG="${SG_DIR}/couchbase-sync-gateway-community_${SG_VER}-${SG_BLD}_x86_64.tar.gz"
SG_TAR="${SG_DIR}/couchbase-sync-gateway"
SG_BIN="${SG_TAR}/bin/sync_gateway"
SG_PID="${SG_DIR}/pid"
SG_CFG="${PROJECT_DIR}/sync-gateway-config.json"

function startSyncGateway
{
	if  [[ ! -e ${SG_BIN} ]] 
		then
		cleanSyncGateway
		mkdir "${SG_DIR}"
		echo "Downloading SyncGateway ..."
		curl -s -o "${SG_PKG}" ${SG_URL}
		tar xf "${SG_PKG}" -C "${SG_DIR}"
		rm -f "${SG_PKG}"
	fi

	stopSyncGateway

	open "http://localhost:4985/_admin/"
	
	"${SG_BIN}" "${SG_CFG}"
	PID=$!
	echo ${PID} > "${SG_PID}"
}

function stopSyncGateway
{
	if  [[ -e "${SG_PID}" ]]
		then
		kill $(cat "${SG_PID}") 2>/dev/null
		rm -f "${SG_PID}"
	fi
}

function cleanSyncGateway
{
	stopSyncGateway
	rm -rf "${SG_DIR}"
}

MODE=${1}
if [[ ${MODE} = "start" ]]
	then 
	echo "Start SyncGateway ..."
	startSyncGateway
elif [[ ${MODE} = "stop" ]]
	then 
	echo "Stop SyncGateway ..."
	stopSyncGateway
elif [[ ${MODE} = "clean" ]]
	then 
	echo "Clean SyncGateway ..."
	cleanSyncGateway
else
	usage
fi

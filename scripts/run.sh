#!/usr/bin/env bash
#
# Copyright 2019 Confluent Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Override this section from the script to include the com.sun.management.jmxremote.rmi.port property.
if [ -z "$KAFKA_JMX_OPTS" ]; then
  export KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.authenticate=false  -Dcom.sun.management.jmxremote.ssl=false "
fi

#!/usr/bin/env bash
#
# Copyright 2019 Confluent Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

. /etc/confluent/docker/bash-config

# Set environment values if they exist as arguments
if [ $# -ne 0 ]; then
  echo "===> Overriding env params with args ..."
  for var in "$@"
  do
    export "$var"
  done
fi

echo "===> User"
id

echo "Controller CLUSTER_ID intialization checks."

# Function to perform variable replacement
replace_variables() {
    local line="$1"
    # Identify variables in the line using regex
    local var_regex='\$\{?([a-zA-Z_][a-zA-Z0-9_]*)\}?'
    # Loop through all matches of variables
    while [[ $line =~ $var_regex ]]; do
        # Extract variable name
        local var_name="${BASH_REMATCH[1]}"
        # Get value of the variable
        local var_value="${!var_name}"
        # Replace variable placeholder with its value
        line="${line//$BASH_REMATCH/$var_value}"
    done
    echo "$line"
}

if [ -e "/etc/kafka/kafka.properties.done" ]; then
    echo "Controller CLUSTER_ID is already initialized. Skipping initialization."
else
    if [ -n "${CLUSTER_ID}" ]; then
      echo "Controller CLUSTER_ID is not initialized. Initializing."
      # Process the template file
      while IFS= read -r line; do
          # Call function to replace variables in the line
          line=$(replace_variables "$line")
          # Append the modified line to the output file
          echo "$line" >> "/etc/kafka/kafka.properties"
      done < "/etc/kafka/kafka.properties.template"
      kafka-storage format --config /etc/"${COMPONENT}"/"${COMPONENT}".properties --cluster-id $CLUSTER_ID
      touch /etc/kafka/kafka.properties.done
      echo "Controller CLUSTER_ID ${CLUSTER_ID} initialized."
    fi
fi

echo "===> Configuring ..."
/etc/confluent/docker/configure

echo "===> Running preflight checks ... "
/etc/confluent/docker/ensure

echo "===> Launching ... "
exec /etc/confluent/docker/launch



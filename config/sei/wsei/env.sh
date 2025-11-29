
## Load hub config
source config/sei/wsei/hub/main.sh
source config/sei/wsei/hub/hub-config.sh


export CURRENT_REMOTE=eth
export CURRENT_BRIDGE=lz

REMOTE_UPPER=$(echo "$CURRENT_REMOTE" | tr '[:lower:]' '[:upper:]')

source config/sei/wsei/remotes/$CURRENT_REMOTE/main.sh
source config/sei/wsei/remotes/$CURRENT_REMOTE/$CURRENT_BRIDGE.sh



eval "export CURRENT_SUB_VAULT_ADDRESS=\$${REMOTE_UPPER}_SUB_VAULT_ADDRESS"
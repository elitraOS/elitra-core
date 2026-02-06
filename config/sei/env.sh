export ZAP_EXECUTOR_ADDRESS=0xD98d795c7D95da8e62Cd97472143f6f34419B518
export CROSSCHAIN_DEPOSIT_QUEUE_ADDRESS=0x36918B348a668CF4A9f59A9Fb142a9Fc133b90C6

## choose to source either from usdc / wsei
## get the asset from the param
## Usage: source config/sei/env.sh wsei 
## or:    source config/sei/env.sh usdc

param=$1

if [ -z "$param" ]; then
    echo "Error: Please specify asset type (usdc or wsei)"
    echo "Usage: source config/sei/env.sh [usdc|wsei]"
    return 1 2>/dev/null || exit 1
fi

export ELITRA_VAULT_FACTORY_ADDRESS=0x4340d6116dd378B32B3D87810Fd2E25C92F21f6D
export FEE_REGISTRY_ADDRESS=0x7c0B0AFcaF28544bd5AaD9d30c8098f2e1A18A5C

source config/sei/$param/env.sh

echo "Sourcing the lz config from hub chain"

####### SEI LZ CONFIG #########
export LZ_EID=30280
export LZ_ENDPOINT_V2=0x1a44076050125825900e736c501f859c50fE728c
export LZ_SOURCE_EID=30101

# ReceiveUln302 - Message library for receiving messages
# This is the standard LayerZero V2 ReceiveUln302 address
# Verify at: https://layerzeroscan.com/ or query the endpoint
export LZ_RECEIVE_ULN_302=0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043

## Crosschain hub configurttion 
export EID=30280
export OFT_ADDRESS=0xbdF43ecAdC5ceF51B7D1772F722E40596BC1788B




######### ENTRY POINT ADDRESS FOR THE ADAPTER #########
export LZ_CROSSCHAIN_DEPOSIT_ADAPTER_ADDRESS=0xE1Bd84dA6edf0D0CE68cE88C5DfDDBB222ca3175
sui client call \
  --package 0x99adf37b1f96eaa0a5ad65d265f11d84b9d139053bc95e53f5273f64ff9c865a \
  --module pool_rewards \
  --function create_pool \
  --args \
    0x74a21ae4b05105d003d35b51faea9905abed2668074b75862156fbf6349fcb74 \
   0xcd698cd0dba0f42fbbddf94cb3c578a7512aaf96d3d151264ab2879f120dd2ff \
    "Pool Name" \
    "Pool Description" \
    '[10, 20, 30]' \
    1749131100501 \
    "https://app.merg3.xyz/images/sui.svg" \
    1749134700501 \
    0x6 \
  --gas-budget 10000000

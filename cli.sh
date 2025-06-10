sui client call \
  --package 0xbdf701160b02d873841fc5ed20484dc2592de627422b3f50f0a244455edda20a \
  --module pool_rewards \
  --function create_pool \
  --args \
    0x74a21ae4b05105d003d35b51faea9905abed2668074b75862156fbf6349fcb74 \
   0xcd698cd0dba0f42fbbddf94cb3c578a7512aaf96d3d151264ab2879f120dd2ff \
    "Pool Name 4" \
    "Pool Description 4" \
    '[491271,21,13]' \
    1749379144000 \
    "https://app.merg3.xyz/images/sui.svg" \
    1750074557000 \
    0x6 \
  --gas-budget 10000000

sui client call \
  --package 0xbdf701160b02d873841fc5ed20484dc2592de627422b3f50f0a244455edda20a \
  --module pool_rewards \
  --function start_pool \
  --args \
    0x74a21ae4b05105d003d35b51faea9905abed2668074b75862156fbf6349fcb74 \
   0xcd698cd0dba0f42fbbddf94cb3c578a7512aaf96d3d151264ab2879f120dd2ff \
    0x39ae497da9c3969b9d3d77602a554e27be0ef48f1fcaf2290dfacb84bf057c8f \
    0x6 \
  --gas-budget 10000000

sui client call \
  --package 0xbdf701160b02d873841fc5ed20484dc2592de627422b3f50f0a244455edda20a \
  --module pool_rewards \
  --function end_pool \
  --args \
    0x74a21ae4b05105d003d35b51faea9905abed2668074b75862156fbf6349fcb74 \
   0xcd698cd0dba0f42fbbddf94cb3c578a7512aaf96d3d151264ab2879f120dd2ff \
    0x89d1a3d196ce1c0deaa07acf49fb3aa9744c186d934d46eea64efac82ffeb90a \
    0x6 \
  --gas-budget 10000000

sui client call \
  --package 0xbdf701160b02d873841fc5ed20484dc2592de627422b3f50f0a244455edda20a \
  --module pool_rewards \
  --function add_sui_rewards \
  --args \
    0x74a21ae4b05105d003d35b51faea9905abed2668074b75862156fbf6349fcb74 \
   0xcd698cd0dba0f42fbbddf94cb3c578a7512aaf96d3d151264ab2879f120dd2ff \
    0x8c7c6e34b85668412754694f852b83d709b8dcd9e7d37eb9e296e2968db8fb0b \
    0x6 \
  --gas-budget 10000000

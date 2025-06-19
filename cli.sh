sui client call \
  --package 0x1f246b075220ec5f49435224ca862fa60c254b9c544c8961764b1bfe77bf8728 \
  --module pool_rewards \
  --function create_pool \
  --args \
    0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848 \
   0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01 \
    "Required Element Pool" \
    "Required elements lava, volcano, tornado" \
    '[6,12,11]' \
    1749379144000 \
    "https://app.merg3.xyz/images/sui.svg" \
    1750677941000 \
    0x6 \
  --gas-budget 10000000

sui client call \
  --package 0x1f246b075220ec5f49435224ca862fa60c254b9c544c8961764b1bfe77bf8728 \
  --module pool_rewards \
  --function start_pool \
  --args \
    0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848 \
   0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01 \
    0x4c98d6d44d414a98506c009c242bf378d3bc63da87a74dbd0641868789b0b570 \
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


sui client pay-sui \
--input-coins 0x9c399f425abad605a7d42862dfa72181c4f697a7dcde7d42780aa44e6ca74c9f \
--amounts 10000000 \
--recipients 0xce1b022dd5633fae11efabc9a48c871637b66c2f3e608929cf8fd4ba7683e205 \
  --gas-budget 10000000

sui client call \
  --package 0x417ec8eec0c63303256299861a14804ff0a5bedf5ac1cbaf3c73eae0d0118f1b \
  --module pool_rewards \
  --function add_sui_rewards_from_balance \
  --args \
    0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848 \
    0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01 \
    0x541b9eda8b91cc19f79b2863f86900e6978f83e91a1b2c97316515d955b2a7d0 \
    0x636dbed3e001ba42b46a6ec61d4086e6c911d5362a2ccfd3842bc3cc2583c54b \
  --gas-budget 10000000


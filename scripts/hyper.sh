(
  set -a
  source .env
  set +a

  npx @layerzerolabs/hyperliquid-composer \
    set-block \
    --size big \
    --network mainnet \
    --private-key "$PK_5"
)
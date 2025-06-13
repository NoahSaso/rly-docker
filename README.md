# rly-docker

This Docker setup provides an automated way to configure and run the [Cosmos
Relayer](https://github.com/cosmos/relayer) for IBC packet relaying between
Cosmos chains.

## Usage

1. **Run**:

   ```bash
   docker compose up
   ```

2. **Check Logs**:

   ```bash
   docker compose logs -f relayer
   ```

## Configuration

The relayer is configured through files and environment variables.

### Config

Mount your `config.yaml` at `/home/relayer/.relayer/config/config.yaml` with
chains and paths already configured.

### Keys

Set the `KEY_DIR` environment variable to a directory containing chain key
mnemonic files. This defaults to `/home/relayer/.keys`.

The file names should match the chain names in the config.yaml (no extension),
and the contents should just be the mnemonic.

### Environment Variables

You can configure environment variables to change behavior, but the defaults
should work for most cases.

| Variable          | Default                 | Description                                       |
| ----------------- | ----------------------- | ------------------------------------------------- |
| `KEY_DIR`         | `"/home/relayer/.keys"` | Directory with chain key mnemonic files           |
| `KEY_NAME`        | `"relayer_key"`         | Key name to use for all chains                    |
| `START_ALL_PATHS` | `"true"`                | Whether to start all paths or specific path       |
| `SPECIFIC_PATH`   | `""`                    | Specific path to start (if START_ALL_PATHS=false) |

## Funding Accounts

**Important**: Before starting the relayer, ensure all configured accounts have
sufficient tokens to pay for transaction fees.

### Check Balances

```bash
# View logs to see account addresses and balances logged during startup
docker compose logs relayer | grep -A5 "Balance for"

# Check balances
docker compose exec relayer rly q balance <CHAIN>
```

## Troubleshooting

### Debug Commands

```bash
# Enter the container
docker compose exec relayer /bin/sh

# Check configuration
rly config show

# List chains
rly chains list

# List keys
rly keys list cosmoshub

# Check balances
rly q balance cosmoshub

# List paths
rly paths list

# Manual path creation (if needed)
rly tx link hubosmo
```

### Logs

```bash
# View all logs
docker compose logs relayer

# Follow logs
docker compose logs -f relayer

# View specific timeframe
docker compose logs --since="1h" relayer
```

## License

This project is licensed under Apache 2.0 (the same as the Cosmos Relayer).

## References

- [Cosmos Relayer](https://github.com/cosmos/relayer)
- [Chain Registry](https://github.com/cosmos/chain-registry)

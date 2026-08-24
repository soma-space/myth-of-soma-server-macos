# Myth of Soma Server for macOS

A standalone Apple Silicon host for the classic Myth of Soma server stack. It
runs the original 32-bit Windows services in an isolated CrossOver bottle and
SQL Server 2022 in an `amd64` Linux container through Colima's VZ/Rosetta
support. This is a platform distribution, not part of Soma Crucible.

## Verified state

- SQL Server restores the 91-table `soma` database.
- UserManager, Session, GameDirectory, shared memory, and OnePerOne all start
  from scripts and expose the expected loopback endpoints.
- The Wine ODBC 2 shim keeps OnePerOne alive beyond the old repeatable
  85-second Driver 17 crash.
- A checksum-verified eSoma 223 client logs in and reaches character selection.
- The client launches through Sikarugir's DxWnd setup, fixing the colour-depth
  problem and capping its otherwise unbounded render loop.

The Windows package remains Rauban-enabled. On CrossOver, Rauban's extension
loads and completes database startup but does not complete the client's
OnePerOne handoff. This host therefore selects the package's guarded
`OnePerOne.wine.exe` variant. The extension build is preserved beside it as
`OnePerOne.extension.exe` for future compatibility work.

## Requirements

- Apple Silicon Mac with Rosetta 2
- [CrossOver](https://www.codeweavers.com/crossover) at
  `/Applications/CrossOver.app`
- Homebrew packages: `colima`, `docker`, `docker-compose`, and `mingw-w64`
- At least 6 GB of memory and 40 GB of disk assigned to Colima

The optional local client additionally needs `sevenzip`, `unshield`, and a
Sikarugir Myth of Soma wrapper containing DxWnd. By default the wrapper is
expected at `~/Applications/Sikarugir/myth of soma.app`; set
`SOMA_SIKARUGIR_APP` if yours is elsewhere.

## First-time server setup

```bash
brew install colima docker docker-compose mingw-w64

make doctor
make fetch
cp .env.example .env
# Change MSSQL_SA_PASSWORD in .env.

make vm-start
make db-up
make db-restore
make crossover
make prepare
make start
make status
```

`make start` creates/configures the three legacy Windows services directly and
waits for ports 4100, 4110, 4120, and 12000. `make smoke` performs a destructive
lifecycle check and stops the game server when it finishes.

Create a login with values that satisfy the legacy 20-character limits:

```bash
SOMA_ACCOUNT_USER=player \
SOMA_ACCOUNT_PASSWORD='change-me' \
SOMA_ACCOUNT_EMAIL=player@localhost \
make account
```

## Local eSoma 223 client

The client installer and patches are the community links collected in the
[eSoma client thread](https://www.reddit.com/r/soma_space/comments/y0kpmp/esoma_client_links/).
They are downloaded into ignored cache/runtime directories and verified before
use; no client binaries are committed to this repository.

```bash
brew install sevenzip unshield
make client-fetch
make client-setup
make client
```

`make client-fetch` assembles eSoma 220 plus patches 221, 222, and 223.
`make client-setup` creates a separate Sikarugir Wine prefix, installs the
official Visual C++ 6 SP6 MFC runtime, copies DxWnd, and targets `127.0.0.1`.

### CPU and frame-rate control

DxWnd's profile uses a per-frame delay because its Hz mode is disabled. The
macOS default is 50 ms, approximately 20 FPS. On the tested machine this kept
`Soma.exe` around 49-57% CPU instead of roughly 124% uncapped, while login and
character selection remained responsive.

To change the tradeoff, rerun setup with a different delay:

```bash
# Smoother, approximately 30 FPS
SOMA_CLIENT_FRAME_DELAY_MS=33 make client-setup

# Cooler, approximately 15 FPS
SOMA_CLIENT_FRAME_DELAY_MS=66 make client-setup
```

Accepted values are 16-200 ms. Then launch normally with `make client`.

## Server payload

`make fetch` downloads and verifies a release from
[myth-of-soma-server-windows](https://github.com/soma-space/myth-of-soma-server-windows).
Both platform repositories therefore use the same checksum-audited game files;
the macOS repository contains only its platform configuration and compatibility
layer.

The default is the immutable `v0.2.0-rc1` release. To test another published
build without editing the script, provide both its tag and archive checksum:

```bash
SOMA_WINDOWS_VERSION=v0.2.1 \
SOMA_WINDOWS_ZIP_SHA256=<sha256> \
make fetch
```

See [NOTICE.md](NOTICE.md) for project scope and provenance.

## Network and platform warning

The server and SQL ports default to loopback. Do not forward gameplay ports
until a local client login succeeds, and never expose SQL port 1433 publicly.

Microsoft does not support SQL Server's Linux container under emulation. This
is a community preservation and compatibility host, not a production SQL
Server deployment.

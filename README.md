# Myth of Soma Server for macOS

A standalone macOS host for the classic Myth of Soma server, including the repaired Rauban extension build. This is a platform distribution—not a game configuration or a derivative of Soma Crucible.

The original server applications remain 32-bit Windows executables. On Apple Silicon this project runs them in an isolated CrossOver bottle, while SQL Server 2022 runs in an `amd64` Linux container through Colima's VZ/Rosetta support.

## Verified state

- SQL Server starts and restores the 91-table `soma` database.
- Microsoft ODBC Driver 17 x86 connects from the isolated CrossOver bottle.
- `sharedmem.exe` and the repaired `OnePerOne.exe` remain alive.
- OnePerOne loads `gsodbc.dll` and `ServerExtention.dll` before its original entry point.
- The extension reads `DSN=soma;UID=soma;PWD=soma` and completes `SQLDriverConnect`.

Arcanine's File Manager, User Manager, Session, Starter, and Game services still use the original service-creator UI. They are the next compatibility boundary for a fully playable local client.

## Requirements

- Apple Silicon Mac with Rosetta 2
- [CrossOver](https://www.codeweavers.com/crossover) installed at `/Applications/CrossOver.app`
- Homebrew packages: `colima`, `docker`, `docker-compose`, and `mingw-w64`
- At least 6 GB of memory and 40 GB of disk assigned to Colima

Microsoft does not support SQL Server's Linux container under emulation. This is a community compatibility host, not a production SQL Server deployment.

## First-time setup

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
make smoke
```

To create the remaining Windows services, run `make services`, press **Create Services** in Arcanine's window, and confirm each service says Started. Then use:

```bash
make start
make status
make stop
```

The server and SQL ports default to loopback. Do not forward gameplay ports until a local client login succeeds, and never expose SQL port 1433 publicly.

## Server payload

`make fetch` downloads and verifies a release from [myth-of-soma-server-windows](https://github.com/soma-space/myth-of-soma-server-windows). Both platform repositories therefore use the same repaired, checksum-audited game files. Platform-specific configuration is kept here.

The default is the immutable `v0.1.0-rc1` release. To test another published
build without editing the scripts, provide both its tag and archive checksum:

```bash
SOMA_WINDOWS_VERSION=v0.1.1 \
SOMA_WINDOWS_ZIP_SHA256=<sha256> \
make fetch
```

See [NOTICE.md](NOTICE.md) for project scope and provenance.

## Current limitation

CrossOver is the verified runtime because WineHQ's macOS ODBC bridge returned an invalid handle-allocation status before reaching SQL Server, and Microsoft's x86 ODBC MSI would not install in the tested WineHQ prefix. Contributions that produce a verified Wine-only route are welcome.

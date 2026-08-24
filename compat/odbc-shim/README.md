# ODBC 17 Wine capability shim

The unmodified 32-bit Myth of Soma server uses MFC 4.2's ODBC 2 API. Microsoft
ODBC Driver 17 connects successfully under Wine on macOS, but the old MFC
recordset layer then encounters incomplete ODBC 2 compatibility paths in
Wine's manager and the native ODBC 3 driver.

The application-facing `odbc32` proxy forwards every ODBC operation to Wine's
unmodified manager under the name `odbc32_real.dll`. Legacy capability probes
used by MFC are answered locally with the compatible SQL Server values, while
all ordinary connection, query, and fetch operations still reach the real
manager and Microsoft driver.

The proxy also maps the ODBC 2 `SQLSetStmtOption` call to the equivalent ODBC 3
`SQLSetStmtAttr` call. Wine's manager currently returns an error for the former
when a native Windows ODBC 3 driver is in use. Cursor requests are downgraded to
forward-only/read-only at the driver boundary: Driver 17 accepts the richer
attributes under Wine but then rejects otherwise valid prepared statements.
MFC's `SQL_FETCH_FIRST` rewind is implemented by closing and re-executing the
prepared lookup-table statement before its next fetch.

The shim also supplies ODBC 2 diagnostics through `SQLGetDiagRec` and protects
an old extension-library edge case: `SQLParamData` on a statement with zero
parameters returns `SQL_NO_DATA`. Forwarding that invalid sequence into Driver
17 otherwise faults inside `SQLGetData` after OnePerOne has been running for
about 85 seconds.

Build the 32-bit DLL with MinGW-w64:

```sh
i686-w64-mingw32-gcc -Os -shared -static-libgcc \
  -Wl,--kill-at -o odbc32.dll odbc32-shim.c odbc32-shim.def
```

The setup script puts the proxy beside the Soma executables and selects it with
Wine's per-process DLL override. The Microsoft driver remains unmodified.

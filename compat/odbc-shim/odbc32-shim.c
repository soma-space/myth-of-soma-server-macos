#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <sql.h>
#include <sqlext.h>
#include <string.h>

typedef SQLRETURN (SQL_API *sql_get_info_fn)(
    SQLHDBC, SQLUSMALLINT, SQLPOINTER, SQLSMALLINT, SQLSMALLINT *);
typedef SQLRETURN (SQL_API *sql_set_stmt_attr_fn)(
    SQLHSTMT, SQLINTEGER, SQLPOINTER, SQLINTEGER);
typedef SQLRETURN (SQL_API *sql_prepare_fn)(
    SQLHSTMT, SQLCHAR *, SQLINTEGER);
typedef SQLRETURN (SQL_API *sql_get_diag_rec_fn)(
    SQLSMALLINT, SQLHANDLE, SQLSMALLINT, SQLCHAR *, SQLINTEGER *, SQLCHAR *,
    SQLSMALLINT, SQLSMALLINT *);
typedef SQLRETURN (SQL_API *sql_extended_fetch_fn)(
    SQLHSTMT, SQLUSMALLINT, SQLLEN, SQLULEN *, SQLUSMALLINT *);
typedef SQLRETURN (SQL_API *sql_execute_fn)(SQLHSTMT);
typedef SQLRETURN (SQL_API *sql_free_stmt_fn)(SQLHSTMT, SQLUSMALLINT);
typedef SQLRETURN (SQL_API *sql_num_params_fn)(SQLHSTMT, SQLSMALLINT *);
typedef SQLRETURN (SQL_API *sql_param_data_fn)(SQLHSTMT, SQLPOINTER *);

static sql_get_info_fn real_sql_get_info(void)
{
    static sql_get_info_fn function;
    static int attempted;

    if (!attempted) {
        HMODULE manager;
        FARPROC address;
        attempted = 1;
        manager = LoadLibraryA("odbc32_real.dll");
        address = manager == NULL ? NULL : GetProcAddress(manager, "SQLGetInfo");
        if (address != NULL) {
            memcpy(&function, &address, sizeof(function));
        }
    }
    return function;
}

static sql_set_stmt_attr_fn real_sql_set_stmt_attr(void)
{
    static sql_set_stmt_attr_fn function;
    static int attempted;

    if (!attempted) {
        HMODULE manager;
        FARPROC address;
        attempted = 1;
        manager = LoadLibraryA("odbc32_real.dll");
        address = manager == NULL ? NULL :
                  GetProcAddress(manager, "SQLSetStmtAttr");
        if (address != NULL) {
            memcpy(&function, &address, sizeof(function));
        }
    }
    return function;
}

static sql_prepare_fn real_sql_prepare(void)
{
    static sql_prepare_fn function;
    static int attempted;

    if (!attempted) {
        HMODULE manager;
        FARPROC address;
        attempted = 1;
        manager = LoadLibraryA("odbc32_real.dll");
        address = manager == NULL ? NULL : GetProcAddress(manager, "SQLPrepare");
        if (address != NULL) {
            memcpy(&function, &address, sizeof(function));
        }
    }
    return function;
}

static sql_get_diag_rec_fn real_sql_get_diag_rec(void)
{
    static sql_get_diag_rec_fn function;
    static int attempted;

    if (!attempted) {
        HMODULE manager;
        FARPROC address;
        attempted = 1;
        manager = LoadLibraryA("odbc32_real.dll");
        address = manager == NULL ? NULL : GetProcAddress(manager, "SQLGetDiagRec");
        if (address != NULL) {
            memcpy(&function, &address, sizeof(function));
        }
    }
    return function;
}

static FARPROC real_odbc_function(const char *name)
{
    HMODULE manager = LoadLibraryA("odbc32_real.dll");
    return manager == NULL ? NULL : GetProcAddress(manager, name);
}

static void log_probe(SQLUSMALLINT info_type, const char *action)
{
    char message[96];
    DWORD written;
    HANDLE file;
    int length = wsprintfA(message, "SQLGetInfo type=%u action=%s\r\n",
                           (unsigned int)info_type, action);

    file = CreateFileA("odbc-shim.log", FILE_APPEND_DATA,
                       FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        return;
    }
    WriteFile(file, message, (DWORD)length, &written, NULL);
    CloseHandle(file);
}

static void log_statement(SQLCHAR *statement, SQLINTEGER statement_length)
{
    static const char prefix[] = "SQLPrepare statement=";
    static const char suffix[] = "\r\n";
    DWORD written;
    DWORD length;
    HANDLE file;

    if (statement == NULL) {
        return;
    }
    length = statement_length == SQL_NTS ? (DWORD)lstrlenA((char *)statement) :
             (DWORD)statement_length;
    file = CreateFileA("odbc-shim.log", FILE_APPEND_DATA,
                       FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        return;
    }
    WriteFile(file, prefix, sizeof(prefix) - 1, &written, NULL);
    WriteFile(file, statement, length, &written, NULL);
    WriteFile(file, suffix, sizeof(suffix) - 1, &written, NULL);
    CloseHandle(file);
}

static void log_diagnostic(SQLCHAR *state, SQLINTEGER native_error,
                           SQLCHAR *message, SQLSMALLINT message_length)
{
    static const char prefix[] = "SQLError state=";
    static const char middle[] = " native=";
    static const char suffix[] = " message=";
    static const char newline[] = "\r\n";
    char number[24];
    DWORD written;
    HANDLE file;
    int number_length;

    file = CreateFileA("odbc-shim.log", FILE_APPEND_DATA,
                       FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        return;
    }
    number_length = wsprintfA(number, "%ld", (long)native_error);
    WriteFile(file, prefix, sizeof(prefix) - 1, &written, NULL);
    WriteFile(file, state, 5, &written, NULL);
    WriteFile(file, middle, sizeof(middle) - 1, &written, NULL);
    WriteFile(file, number, (DWORD)number_length, &written, NULL);
    WriteFile(file, suffix, sizeof(suffix) - 1, &written, NULL);
    WriteFile(file, message, (DWORD)message_length, &written, NULL);
    WriteFile(file, newline, sizeof(newline) - 1, &written, NULL);
    CloseHandle(file);
}

static SQLRETURN write_u16(SQLPOINTER output, SQLSMALLINT *length,
                           SQLUSMALLINT value)
{
    if (output != NULL) {
        *((SQLUSMALLINT *)output) = value;
    }
    if (length != NULL) {
        *length = (SQLSMALLINT)sizeof(value);
    }
    return SQL_SUCCESS;
}

static SQLRETURN write_u32(SQLPOINTER output, SQLSMALLINT *length,
                           SQLUINTEGER value)
{
    if (output != NULL) {
        *((SQLUINTEGER *)output) = value;
    }
    if (length != NULL) {
        *length = (SQLSMALLINT)sizeof(value);
    }
    return SQL_SUCCESS;
}

static SQLRETURN write_string(SQLPOINTER output, SQLSMALLINT output_size,
                              SQLSMALLINT *length, const char *value)
{
    SQLSMALLINT value_length = (SQLSMALLINT)lstrlenA(value);

    if (length != NULL) {
        *length = value_length;
    }
    if (output != NULL && output_size > 0) {
        SQLSMALLINT copy_length = value_length;
        if (copy_length >= output_size) {
            copy_length = output_size - 1;
        }
        CopyMemory(output, value, (SIZE_T)copy_length);
        ((char *)output)[copy_length] = '\0';
        if (copy_length != value_length) {
            return SQL_SUCCESS_WITH_INFO;
        }
    }
    return SQL_SUCCESS;
}

/* Intercept MFC 4.2's three Wine-incompatible ODBC 2 capability probes. */
__declspec(dllexport) SQLRETURN SQL_API SQLGetInfo(
    SQLHDBC connection, SQLUSMALLINT info_type, SQLPOINTER output,
    SQLSMALLINT output_size, SQLSMALLINT *length)
{
    switch (info_type) {
    case SQL_ODBC_API_CONFORMANCE:
        log_probe(info_type, "compat-u16");
        return write_u16(output, length, SQL_OAC_LEVEL2);
    case SQL_ODBC_SQL_CONFORMANCE:
        log_probe(info_type, "compat-u16");
        return write_u16(output, length, SQL_OSC_EXTENDED);
    case SQL_TXN_CAPABLE:
        log_probe(info_type, "compat-u16");
        return write_u16(output, length, SQL_TC_ALL);
    case SQL_CURSOR_COMMIT_BEHAVIOR:
    case SQL_CURSOR_ROLLBACK_BEHAVIOR:
        log_probe(info_type, "compat-u16");
        return write_u16(output, length, SQL_CB_PRESERVE);
    case SQL_DATA_SOURCE_READ_ONLY:
        log_probe(info_type, "compat-string");
        return write_string(output, output_size, length, "N");
    case SQL_IDENTIFIER_QUOTE_CHAR:
        log_probe(info_type, "compat-string");
        return write_string(output, output_size, length, "\"");
    case SQL_SCROLL_CONCURRENCY:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_SCCO_READ_ONLY | SQL_SCCO_LOCK |
                         SQL_SCCO_OPT_VALUES);
    case SQL_SCROLL_OPTIONS:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_SO_FORWARD_ONLY | SQL_SO_KEYSET_DRIVEN |
                         SQL_SO_DYNAMIC | SQL_SO_MIXED | SQL_SO_STATIC);
    case SQL_LOCK_TYPES:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_LCK_NO_CHANGE | SQL_LCK_EXCLUSIVE |
                         SQL_LCK_UNLOCK);
    case SQL_POS_OPERATIONS:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_POS_POSITION | SQL_POS_REFRESH | SQL_POS_UPDATE |
                         SQL_POS_DELETE | SQL_POS_ADD);
    case SQL_POSITIONED_STATEMENTS:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_PS_POSITIONED_DELETE | SQL_PS_POSITIONED_UPDATE |
                         SQL_PS_SELECT_FOR_UPDATE);
    case SQL_GETDATA_EXTENSIONS:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_GD_ANY_COLUMN | SQL_GD_ANY_ORDER |
                         SQL_GD_BLOCK | SQL_GD_BOUND);
    case SQL_BOOKMARK_PERSISTENCE:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_BP_CLOSE | SQL_BP_DELETE | SQL_BP_DROP |
                         SQL_BP_TRANSACTION | SQL_BP_UPDATE |
                         SQL_BP_OTHER_HSTMT | SQL_BP_SCROLL);
    case SQL_STATIC_SENSITIVITY:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_SS_ADDITIONS | SQL_SS_DELETIONS | SQL_SS_UPDATES);
    case SQL_DEFAULT_TXN_ISOLATION:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length, SQL_TXN_READ_COMMITTED);
    case SQL_TXN_ISOLATION_OPTION:
        log_probe(info_type, "compat-u32");
        return write_u32(output, length,
                         SQL_TXN_READ_UNCOMMITTED | SQL_TXN_READ_COMMITTED |
                         SQL_TXN_REPEATABLE_READ | SQL_TXN_SERIALIZABLE);
    default: {
        sql_get_info_fn function = real_sql_get_info();
        log_probe(info_type, "forward");
        if (function == NULL) {
            return SQL_ERROR;
        }
        return function(connection, info_type, output, output_size, length);
    }
    }
}

/* Wine's ODBC manager does not translate this ODBC 2 entry point for a native
 * ODBC 3 driver. The option and attribute identifiers are intentionally
 * identical, as required by the ODBC compatibility mapping. */
__declspec(dllexport) SQLRETURN SQL_API SQLSetStmtOption(
    SQLHSTMT statement, SQLUSMALLINT option, SQLULEN value)
{
    sql_set_stmt_attr_fn function = real_sql_set_stmt_attr();
    if (function == NULL) {
        return SQL_ERROR;
    }
    /* The Windows driver accepts scrollable/updatable cursor attributes under
     * Wine but fails every prepared statement when they are active. Soma's
     * startup recordsets are consumed sequentially, so use the compatible
     * forward-only/read-only driver mode while preserving MFC's API contract. */
    if (option == SQL_CURSOR_TYPE) {
        return SQL_SUCCESS;
    } else if (option == SQL_CONCURRENCY) {
        return SQL_SUCCESS;
    }
    return function(statement, (SQLINTEGER)option,
                    (SQLPOINTER)(UINT_PTR)value, 0);
}

__declspec(dllexport) SQLRETURN SQL_API SQLPrepare(
    SQLHSTMT statement_handle, SQLCHAR *statement, SQLINTEGER statement_length)
{
    sql_prepare_fn function = real_sql_prepare();
    log_statement(statement, statement_length);
    if (function == NULL) {
        return SQL_ERROR;
    }
    return function(statement_handle, statement, statement_length);
}

/* ODBC 2's SQLError is another unimplemented path for native ODBC 3 drivers
 * in Wine. Retrieve the first diagnostic record from the most specific
 * supplied handle, matching MFC's use after a failed operation. */
__declspec(dllexport) SQLRETURN SQL_API SQLError(
    SQLHENV environment, SQLHDBC connection, SQLHSTMT statement,
    SQLCHAR *state, SQLINTEGER *native_error, SQLCHAR *message,
    SQLSMALLINT message_size, SQLSMALLINT *message_length)
{
    static int returned_record;
    sql_get_diag_rec_fn function = real_sql_get_diag_rec();
    SQLSMALLINT handle_type;
    SQLHANDLE handle;
    SQLRETURN result;

    if (function == NULL) {
        return SQL_ERROR;
    }
    if (returned_record) {
        returned_record = 0;
        return SQL_NO_DATA;
    }
    if (statement != SQL_NULL_HSTMT) {
        handle_type = SQL_HANDLE_STMT;
        handle = statement;
    } else if (connection != SQL_NULL_HDBC) {
        handle_type = SQL_HANDLE_DBC;
        handle = connection;
    } else {
        handle_type = SQL_HANDLE_ENV;
        handle = environment;
    }
    result = function(handle_type, handle, 1, state, native_error, message,
                      message_size, message_length);
    if (SQL_SUCCEEDED(result) && state != NULL && native_error != NULL &&
        message != NULL && message_length != NULL) {
        returned_record = 1;
        log_diagnostic(state, *native_error, message, *message_length);
    }
    return result;
}

/* MFC rewinds lookup-table recordsets after its initial fetch. A native
 * Driver 17 statement cannot expose a scrollable cursor under Wine, so rewind
 * the prepared statement by closing and re-executing it before fetching its
 * first row again. Bindings survive SQL_CLOSE as required by ODBC. */
__declspec(dllexport) SQLRETURN SQL_API SQLExtendedFetch(
    SQLHSTMT statement, SQLUSMALLINT orientation, SQLLEN offset,
    SQLULEN *row_count, SQLUSMALLINT *row_status)
{
    static sql_extended_fetch_fn extended_fetch;
    static sql_execute_fn execute;
    static sql_free_stmt_fn free_stmt;
    FARPROC address;
    SQLRETURN result;

    if (extended_fetch == NULL) {
        address = real_odbc_function("SQLExtendedFetch");
        memcpy(&extended_fetch, &address, sizeof(extended_fetch));
        address = real_odbc_function("SQLExecute");
        memcpy(&execute, &address, sizeof(execute));
        address = real_odbc_function("SQLFreeStmt");
        memcpy(&free_stmt, &address, sizeof(free_stmt));
    }
    if (extended_fetch == NULL || execute == NULL || free_stmt == NULL) {
        return SQL_ERROR;
    }
    if (orientation == SQL_FETCH_FIRST) {
        result = free_stmt(statement, SQL_CLOSE);
        if (!SQL_SUCCEEDED(result)) {
            return result;
        }
        result = execute(statement);
        if (!SQL_SUCCEEDED(result)) {
            return result;
        }
        orientation = SQL_FETCH_NEXT;
        offset = 1;
    }
    return extended_fetch(statement, orientation, offset, row_count, row_status);
}

/* SQL Server Native Client 11 crashes under Wine when SQLParamData is called
 * after executing a statement that has no parameters. Soma's database helper
 * performs that call after every successful SQLExecDirect, including plain
 * UPDATE statements. Windows' driver manager returns SQL_NO_DATA for that
 * harmless probe; reproduce it here while preserving the real data-at-exec
 * path for statements which actually have parameters. */
__declspec(dllexport) SQLRETURN SQL_API SQLParamData(
    SQLHSTMT statement, SQLPOINTER *value)
{
    static sql_num_params_fn num_params;
    static sql_param_data_fn param_data;
    SQLSMALLINT parameter_count = 0;
    FARPROC address;
    SQLRETURN result;

    if (num_params == NULL || param_data == NULL) {
        address = real_odbc_function("SQLNumParams");
        memcpy(&num_params, &address, sizeof(num_params));
        address = real_odbc_function("SQLParamData");
        memcpy(&param_data, &address, sizeof(param_data));
    }
    if (num_params == NULL || param_data == NULL) {
        return SQL_ERROR;
    }

    result = num_params(statement, &parameter_count);
    if (SQL_SUCCEEDED(result) && parameter_count == 0) {
        if (value != NULL) {
            *value = NULL;
        }
        return SQL_NO_DATA;
    }
    return param_data(statement, value);
}

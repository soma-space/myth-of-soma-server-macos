#include <stdio.h>
#include <windows.h>
#include <sql.h>
#include <sqlext.h>

static void diagnostics(SQLHENV environment, SQLHDBC connection)
{
    SQLCHAR state[6] = {0};
    SQLCHAR message[1024] = {0};
    SQLINTEGER native_error = 0;
    SQLSMALLINT length = 0;
    SQLRETURN result;

    result = SQLError(environment, connection, SQL_NULL_HSTMT, state,
                      &native_error, message, sizeof(message), &length);
    printf("SQLError=%d state=%s native=%ld message=%s\n", result, state,
           (long)native_error, message);
}

int main(void)
{
    SQLHENV environment = SQL_NULL_HENV;
    SQLHDBC connection = SQL_NULL_HDBC;
    SQLCHAR output[512] = {0};
    SQLSMALLINT output_length = 0;
    SQLRETURN result;

    result = SQLAllocEnv(&environment);
    printf("SQLAllocEnv=%d\n", result);
    if (!SQL_SUCCEEDED(result)) return 1;

    result = SQLAllocConnect(environment, &connection);
    printf("SQLAllocConnect=%d\n", result);
    if (!SQL_SUCCEEDED(result)) return 1;

    printf("SQLSetConnectOption(LOGIN_TIMEOUT)=%d\n",
           SQLSetConnectOption(connection, SQL_LOGIN_TIMEOUT, 10));
    printf("SQLSetConnectOption(ODBC_CURSORS)=%d\n",
           SQLSetConnectOption(connection, SQL_ODBC_CURSORS, SQL_CUR_USE_ODBC));

    result = SQLDriverConnect(connection, NULL,
                              (SQLCHAR *)"DSN=soma;UID=soma;PWD=soma", SQL_NTS,
                              output, sizeof(output), &output_length,
                              SQL_DRIVER_NOPROMPT);
    printf("SQLDriverConnect=%d output_length=%d output=%s\n", result,
           output_length, output);
    if (!SQL_SUCCEEDED(result)) diagnostics(environment, connection);

    if (SQL_SUCCEEDED(result)) SQLDisconnect(connection);
    SQLFreeConnect(connection);
    SQLFreeEnv(environment);
    return SQL_SUCCEEDED(result) ? 0 : 1;
}

#include "include/shim.h"
#include "include/sqlite-vec.h"
#include <sqlite3.h>
#include <stddef.h>

int cs_sqlite_vec_connection_init(void *db) {
    return sqlite3_vec_init((sqlite3 *)db, NULL, NULL);
}

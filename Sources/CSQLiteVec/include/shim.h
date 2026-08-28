#ifndef CSQLITEVEC_SHIM_H
#define CSQLITEVEC_SHIM_H

/// Registers sqlite-vec on one connection. Apple's system SQLite does not
/// support process-global auto extensions, so this must be called per
/// connection (GRDB: Configuration.prepareDatabase).
/// `db` is a sqlite3* handle. Returns SQLITE_OK (0) on success.
int cs_sqlite_vec_connection_init(void *db);

#endif

Handle g_hDatabase = INVALID_HANDLE;
bool g_bMySQL = false;

#include "store/sql.sp"

void Store_DB_ConfigsExecuted_ConnectDatabase()
{
	if(g_hDatabase == INVALID_HANDLE)
		SQL_TConnect(SQLCallback_Connect, g_eCvars[g_cvarDatabaseEntry].sCache);
	// If database has been connected. Skip connection and do some housekeeping here
	else Store_DB_HouseKeeping(g_hDatabase);
	
	if(g_eCvars[g_cvarDatabaseRetries].aCache > 0)
		CreateTimer(view_as<float>(g_eCvars[g_cvarDatabaseTimeout].aCache), Timer_DatabaseTimeout);
}

public Action Timer_DatabaseTimeout(Handle timer, any userid)
{
	// Database is connected successfully
	if(g_hDatabase != INVALID_HANDLE)
		return Plugin_Stop;

	if(g_iDatabaseRetries < g_eCvars[g_cvarDatabaseRetries].aCache)
	{
		SQL_TConnect(SQLCallback_Connect, g_eCvars[g_cvarDatabaseEntry].sCache);
		CreateTimer(view_as<float>(g_eCvars[g_cvarDatabaseTimeout].aCache), Timer_DatabaseTimeout);
		++g_iDatabaseRetries;
	}
	else
	{
		SetFailState("Database connection failed to initialize after %d retrie(s)", g_eCvars[g_cvarDatabaseRetries].aCache);
	}

	return Plugin_Stop;
}

void Store_DB_HouseKeeping(Handle db)
{
	// Do some housekeeping
	char m_szQuery[600], m_szLogCleaningQuery[256];
	
	char m_szDriver[12];
	SQL_ReadDriver(db, STRING(m_szDriver));
	
	// Remove expired and equipped items
	if (StrEqual(m_szDriver, "mysql"))
	{
		// This query removes expired items that are equipped, and also remove the rows from store_equipment - it doesn't remove unequipped items!
		Format(STRING(m_szQuery), "DELETE store_items, store_equipment "
								... "FROM store_items, store_equipment "
								... "WHERE store_items.unique_id = store_equipment.unique_id "
									... "AND store_items.player_id = store_equipment.player_id "
									... "AND store_items.date_of_expiration != 0 "
									... "AND store_items.date_of_expiration < %d", GetTime());
		// Ugly syntax, but MySQL DOES allow DELETE clauses between multiple tables in a single query
	}
	else
	{
		// This query removes rows from store_equipment that are linked to items that are expired, BUT DOESN'T ACTUALLY REMOVE EXPIRED ITEMS FROM PLAYERS INVENTORIES! - This is done by the query after this one.
		// ^ NOTE THAT THE BEHAVIOR OF THIS QUERY DIFFERS FROM THE MySQL ONE!
		// For easier copy-pasting: DELETE FROM store_equipment WHERE ROWID IN (SELECT store_equipment.ROWID FROM store_items, store_equipment WHERE store_items.unique_id = store_equipment.unique_id AND store_items.player_id = store_equipment.player_id AND store_items.date_of_expiration != 0 AND store_items.date_of_expiration < %d);
		Format(STRING(m_szQuery), "DELETE FROM store_equipment "
								... "WHERE ROWID IN "
									... "("
									...	"SELECT store_equipment.ROWID "
										... "FROM store_items, store_equipment "
										... "WHERE store_items.unique_id = store_equipment.unique_id "
											... "AND store_items.player_id = store_equipment.player_id "
											... "AND store_items.date_of_expiration != 0 "
											... "AND store_items.date_of_expiration < %d"
									... ") ", GetTime());
		// SQLite doesn't allow DELETE clauses between multiple tables in a single query. GRRRR!!!
		
		// Btw, ROWID is the default hidden SQLite primary key, because the store_equipment table doesn't have one
	}
	SQL_TVoid(db, m_szQuery);
	
	// Remove expired and unequipped items
	Format(STRING(m_szQuery), "DELETE FROM store_items WHERE date_of_expiration != 0 AND date_of_expiration < %d", GetTime());
	SQL_TVoid(db, m_szQuery);
	
	
	if (g_eCvars[g_cvarLogLast].aCache>0)
	{
		if (StrEqual(m_szDriver, "mysql"))
		{
			Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_plugin_logs WHERE `date` < CURDATE()-%i", g_eCvars[g_cvarLogLast].aCache);
			SQL_TVoid(db, m_szLogCleaningQuery);
			Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_logs WHERE `date` < CURDATE()-%i", g_eCvars[g_cvarLogLast].aCache);
			SQL_TVoid(db, m_szLogCleaningQuery);
		}
		else
		{
			Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_plugin_logs WHERE `date` < (SELECT DATETIME('now', '-%i day'))", g_eCvars[g_cvarLogLast].aCache);
			SQL_TVoid(db, m_szLogCleaningQuery);
		}
	}
}
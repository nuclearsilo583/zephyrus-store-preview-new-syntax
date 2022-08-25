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

public void Store_DB_HouseKeeping(Handle db)
{
	// Do some housekeeping
	char m_szQuery[256], m_szLogCleaningQuery[256];
	Format(STRING(m_szQuery), "delete `store_items`, `store_equipment`"
							... "from  `store_items`, `store_equipment` "
							... "where (store_items.unique_id = store_equipment.unique_id) "
							... "and store_items.date_of_expiration<>0 and store_items.date_of_expiration<%d", GetTime());
	SQL_TVoid(db, m_szQuery);
	
	char m_szDriver[2];
	SQL_ReadDriver(g_hDatabase, STRING(m_szDriver));
	
	if (g_eCvars[g_cvarLogLast].aCache>0)
	{
		if(m_szDriver[0] == 'm')
		{
			Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_plugin_logs WHERE `date` < CURDATE()-%i", g_eCvars[g_cvarLogLast].aCache);
			SQL_TVoid(g_hDatabase, m_szLogCleaningQuery);
			Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_logs WHERE `date` < CURDATE()-%i", g_eCvars[g_cvarLogLast].aCache);
			SQL_TVoid(g_hDatabase, m_szLogCleaningQuery);
		}
		else
		{
			Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_plugin_logs WHERE `date` < (SELECT DATETIME('now', '-%i day'))", g_eCvars[g_cvarLogLast].aCache);
			SQL_TVoid(g_hDatabase, m_szLogCleaningQuery);
		}
	}
}
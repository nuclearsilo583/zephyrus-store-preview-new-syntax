Handle g_hLogFile = INVALID_HANDLE;

void Store_Logs_ConfigsExecuted_Logging()
{
	if(g_eCvars[g_cvarLogging].aCache == 1 || g_eCvars[g_cvarPluginsLogging].aCache == 1)
	{
		if(g_hLogFile == INVALID_HANDLE)
		{
			char m_szPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, STRING(m_szPath), "logs/store.log.txt");
			g_hLogFile = OpenFile(m_szPath, "w+");
		}
	}
}
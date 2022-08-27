void Store_Configs_ReloadConfig()
{
	Store_ReloadConfig();
}

void Store_Configs_OnAllPluginLoaded()
{
	CreateTimer(1.0, LoadConfig);
}

public Action LoadConfig(Handle timer, any data)
{
	// Load the config file
	Store_ReloadConfig();
	
	return Plugin_Continue;
}

public void Store_ReloadConfig()
{
	g_iItems = 0;
	
	for(int i=0;i<g_iTypeHandlers;++i)
	{
		if(g_eTypeHandlers[i].fnReset != INVALID_FUNCTION)
		{
			Call_StartFunction(g_eTypeHandlers[i].hPlugin, g_eTypeHandlers[i].fnReset);
			Call_Finish();
		}
	}

	if(strcmp(g_eCvars[g_cvarItemSource].sCache, "database")==0)
	{
		char m_szQuery[64];
		Format(STRING(m_szQuery), "SELECT * FROM %s WHERE supported_games LIKE \"%%%s%%\" OR supported_games = \"\"", g_eCvars[g_cvarItemsTable].sCache, g_szGameDir);
		SQL_TQuery(g_hDatabase, SQLCallback_ReloadConfig, m_szQuery);
	}
	else
	{	
		char m_szFile[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, STRING(m_szFile), "configs/store/items.txt");
		Handle m_hKV = CreateKeyValues("Store");
		FileToKeyValues(m_hKV, m_szFile);
		if (!KvGotoFirstSubKey(m_hKV))
		{
			
			SetFailState("Failed to read configs/store/items.txt");
		}
		Store_WalkConfig(m_hKV);
		CloseHandle(m_hKV);
	}
}

void Store_WalkConfig(Handle &kv,int parent=-1)
{
	char m_szType[32];
	char m_szGame[64];
	char m_szFlags[64];
	int m_iHandler;
	bool m_bSuccess;
	do
	{
		if(g_iItems == STORE_MAX_ITEMS)
				continue;
		if (KvGetNum(kv, "enabled", 1) && KvGetNum(kv, "type", -1)==-1 && KvGotoFirstSubKey(kv))
		{
			KvGoBack(kv);
			KvGetSectionName(kv, g_eItems[g_iItems].szName, 64);
			KvGetSectionName(kv, g_eItems[g_iItems].szUniqueId, 64);
			ReplaceString(g_eItems[g_iItems].szName, 64, "\\n", "\n");
			KvGetString(kv, "shortcut", g_eItems[g_iItems].szShortcut, 64);
			KvGetString(kv, "flag", STRING(m_szFlags));
			KvGetString(kv, "steam", g_eItems[g_iItems].szSteam, 256, "\0");
			KvGetString(kv, "description", g_eItems[g_iItems].szDescription, 256, "\0");
			KvGetString(kv, "games", STRING(m_szGame));
			if(m_szGame[0] != 0 && StrContains(m_szGame, g_szGameDir)==-1)
				continue;
			g_eItems[g_iItems].iFlagBits = ReadFlagString(m_szFlags);
			g_eItems[g_iItems].iPrice = KvGetNum(kv, "price", -1);
			g_eItems[g_iItems].bBuyable = (KvGetNum(kv, "buyable", 1)?true:false);
			g_eItems[g_iItems].bIgnoreVIP = (KvGetNum(kv, "ignore_vip", 0)?true:false);
			g_eItems[g_iItems].iHandler = g_iPackageHandler;
			KvGotoFirstSubKey(kv);
			
			g_eItems[g_iItems].iParent = parent;
			
			Store_WalkConfig(kv, g_iItems++);
			KvGoBack(kv);
		}
		else
		{
			if(!KvGetNum(kv, "enabled", 1))
				continue;

			KvGetString(kv, "games", STRING(m_szGame));
			if(m_szGame[0] != 0 && StrContains(m_szGame, g_szGameDir)==-1)
				continue;
				
			g_eItems[g_iItems].iParent = parent;
			KvGetSectionName(kv, g_eItems[g_iItems].szName, ITEM_NAME_LENGTH);
			g_eItems[g_iItems].iPrice = KvGetNum(kv, "price");
			g_eItems[g_iItems].bBuyable = KvGetNum(kv, "buyable", 1)?true:false;
			g_eItems[g_iItems].bIgnoreVIP = (KvGetNum(kv, "ignore_vip", 0)?true:false);
			g_eItems[g_iItems].bPreview = KvGetNum(kv, "preview", 0) ? true : false;
			g_eItems[g_iItems].bIgnoreFree = KvGetNum(kv, "ignore_free", 0) ? true : false;
			KvGetString(kv, "description", g_eItems[g_iItems].szDescription, 256, "\0");
			KvGetString(kv, "steam", g_eItems[g_iItems].szSteam, 256, "\0");

			
			KvGetString(kv, "type", STRING(m_szType));
			m_iHandler = Store_GetTypeHandler(m_szType);
			if(m_iHandler == -1)
				continue;

			KvGetString(kv, "flag", STRING(m_szFlags));
			g_eItems[g_iItems].iFlagBits = ReadFlagString(m_szFlags);
			g_eItems[g_iItems].iHandler = m_iHandler;
			
			if(KvGetNum(kv, "unique_id", -1)==-1)
				KvGetString(kv, g_eTypeHandlers[m_iHandler].szUniqueKey, g_eItems[g_iItems].szUniqueId, PLATFORM_MAX_PATH);
			else
				KvGetString(kv, "unique_id", g_eItems[g_iItems].szUniqueId, PLATFORM_MAX_PATH);

			if(KvJumpToKey(kv, "Plans"))
			{
				KvGotoFirstSubKey(kv);
				int index=0;
				do
				{
					KvGetSectionName(kv, g_ePlans[g_iItems][index].szName_Plan, ITEM_NAME_LENGTH);
					g_ePlans[g_iItems][index].iPrice_Plan = KvGetNum(kv, "price");
					g_ePlans[g_iItems][index].iTime_Plan = KvGetNum(kv, "time");
					index++;
				} while (KvGotoNextKey(kv));

				g_eItems[g_iItems].iPlans=index;

				KvGoBack(kv);
				KvGoBack(kv);
			}

			if(g_eItems[g_iItems].hAttributes)
				CloseHandle(g_eItems[g_iItems].hAttributes);
			g_eItems[g_iItems].hAttributes = INVALID_HANDLE;
			if(KvJumpToKey(kv, "Attributes"))
			{
				g_eItems[g_iItems].hAttributes = CreateTrie();

				KvGotoFirstSubKey(kv, false);

				char m_szAttribute[64];
				char m_szValue[64];
				do
				{
					KvGetSectionName(kv, STRING(m_szAttribute));
					KvGetString(kv, NULL_STRING, STRING(m_szValue));
					SetTrieString(g_eItems[g_iItems].hAttributes, m_szAttribute, m_szValue);
				} while (KvGotoNextKey(kv, false));

				KvGoBack(kv);
				KvGoBack(kv);
			}
			
			m_bSuccess = true;
			if(g_eTypeHandlers[m_iHandler].fnConfig!=INVALID_FUNCTION)
			{
				Call_StartFunction(g_eTypeHandlers[m_iHandler].hPlugin, g_eTypeHandlers[m_iHandler].fnConfig);
				Call_PushCellRef(kv);
				Call_PushCell(g_iItems);
				Call_Finish(m_bSuccess); 
			}
			
			if(m_bSuccess)
				++g_iItems;
		}
	} while (KvGotoNextKey(kv));
}
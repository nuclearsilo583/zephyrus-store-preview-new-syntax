int g_cvarDatabaseEntry = -1;
int g_cvarDatabaseRetries = -1;
int g_cvarDatabaseTimeout = -1;
int g_cvarItemSource = -1;
int g_cvarItemsTable = -1;
int g_cvarStartCredits = -1;
int g_cvarCreditTimer = -1;
int g_cvarCreditAmountActive = -1;
int g_cvarCreditAmountInactive = -1;
int g_cvarCreditAmountKill = -1;
int g_cvarRequiredFlag = -1;
int g_cvarVIPFlag = -1;
int g_cvarSellEnabled = -1;
int g_cvarGiftEnabled = -1;
int g_cvarCreditGiftEnabled = -1;
int g_cvarSellRatio = -1;
int g_cvarConfirmation = -1;
int g_cvarPreview = -1;
int g_cvarAdminFlag = -1;
int g_cvarSaveOnDeath = -1;
int g_cvarCreditMessages = -1;
int g_cvarShowVIP = -1;
int g_cvarShowSTEAM = -1;
int g_cvarLogging = -1;
int g_cvarLogLast = -1;
int g_cvarPluginsLogging = -1;							  
int g_cvarSilent = -1;
//int g_cvarCredits = -1;
int gc_iDescription = -1;
int gc_iReloadType = -1;
int gc_iReloadDelay = -1;
int gc_iReloadNotify = -1;
ConVar g_cvarGiveItemBehavior;
ConVar g_cvarChatTag;

#pragma unused g_cvarCenterTag
ConVar g_cvarCenterTag;

void Store_Cvars_OnPluginStart()
{
	AutoExecConfig_SetFile("plugin.store", "sourcemod");
	AutoExecConfig_SetCreateFile(true);

	// Register ConVars
	g_cvarDatabaseEntry = RegisterConVar("sm_store_database", "storage-local", "Name of the default store database entry", TYPE_STRING);
	g_cvarDatabaseRetries = RegisterConVar("sm_store_database_retries", "4", "Number of retries if the connection fails to estabilish with timeout", TYPE_INT);
	g_cvarDatabaseTimeout = RegisterConVar("sm_store_database_timeout", "10", "Timeout in seconds to wait for database connection before retry", TYPE_FLOAT);
	g_cvarItemSource = RegisterConVar("sm_store_item_source", "flatfile", "Source of the item list, can be set to flatfile and database, sm_store_items_table must be set if database is chosen (THIS IS HIGHLY EXPERIMENTAL AND MAY NOT WORK YET)", TYPE_STRING);
	g_cvarItemsTable = RegisterConVar("sm_store_items_table", "store_menu", "Name of the items table", TYPE_STRING);
	g_cvarStartCredits = RegisterConVar("sm_store_startcredits", "0", "Number of credits a client starts with", TYPE_INT);
	g_cvarCreditTimer = RegisterConVar("sm_store_credit_interval", "60", "Interval in seconds to give out credits", TYPE_FLOAT, ConVar_CreditTimer);
	g_cvarCreditAmountActive = RegisterConVar("sm_store_credit_amount_active", "1", "Number of credits to give out for active players", TYPE_INT, ConVar_CreditTimer);
	g_cvarCreditAmountInactive = RegisterConVar("sm_store_credit_amount_inactive", "1", "Number of credits to give out for inactive players (spectators)", TYPE_INT, ConVar_CreditTimer);
	g_cvarCreditAmountKill = RegisterConVar("sm_store_credit_amount_kill", "1", "Number of credits to give out for killing a player", TYPE_INT, ConVar_CreditTimer);
	g_cvarRequiredFlag = RegisterConVar("sm_store_required_flag", "", "Flag to access the !store menu", TYPE_FLAG);
	g_cvarVIPFlag = RegisterConVar("sm_store_vip_flag", "", "Flag for VIP access (all items unlocked). Leave blank to disable.", TYPE_FLAG);
	g_cvarAdminFlag = RegisterConVar("sm_store_admin_flag", "z", "Flag for admin access. Leave blank to disable.", TYPE_FLAG);
	g_cvarSellEnabled = RegisterConVar("sm_store_enable_selling", "1", "Enable/disable selling of already bought items.", TYPE_INT);
	g_cvarGiftEnabled = RegisterConVar("sm_store_enable_gifting", "1", "Enable/disable gifting of already bought items. [1=everyone, 2=admins only]", TYPE_INT);
	g_cvarCreditGiftEnabled = RegisterConVar("sm_store_enable_credit_gifting", "1", "Enable/disable gifting of credits.", TYPE_INT);
	g_cvarSellRatio = RegisterConVar("sm_store_sell_ratio", "0.60", "Ratio of the original price to get for selling an item.", TYPE_FLOAT);
	g_cvarConfirmation = RegisterConVar("sm_store_confirmation_windows", "1", "Enable/disable confirmation windows.", TYPE_INT);
	g_cvarPreview = RegisterConVar("sm_store_preview_enable", "1", "Enable/disable preview button.", TYPE_INT);
	g_cvarSaveOnDeath = RegisterConVar("sm_store_save_on_death", "0", "Enable/disable client data saving on client death.", TYPE_INT);
	g_cvarCreditMessages = RegisterConVar("sm_store_credit_messages", "1", "Enable/disable messages when a player earns credits.", TYPE_INT);
	
	//g_cvarChatTag = RegisterConVar("sm_store_chat_tag", "[Store] ", "The chat tag to use for displaying messages.", TYPE_STRING);
	g_cvarChatTag = AutoExecConfig_CreateConVar("sm_store_chat_tag_plugins", "[Store] ", "The chat tag to use for displaying messages.");
	g_cvarCenterTag = AutoExecConfig_CreateConVar("sm_store_center_tag", "[Store] ", "The chat tag to use for displaying messages in hint text box.");

	g_cvarShowSTEAM = RegisterConVar("sm_store_show_steam_items", "0", "If you enable this STEAM items will be shown in grey.", TYPE_INT);
	g_cvarShowVIP = RegisterConVar("sm_store_show_vip_items", "0", "If you enable this VIP items will be shown in grey.", TYPE_INT);
	g_cvarLogging = RegisterConVar("sm_store_logging", "0", "Set this to 1 for file logging and 2 to SQL logging (only MySQL). Leaving on 0 means disabled.", TYPE_INT);
	g_cvarLogLast = RegisterConVar("sm_store_log_last", "7", "How many day to delete data log since the log created in database. Leaving on 0 means no delete.", TYPE_INT);
	
	g_cvarPluginsLogging = RegisterConVar("sm_store_plugins_logging", "2", "Enable Logging for module . 0 = disable, 1 = file log, 2 = SQL log (MySQL only)", TYPE_INT);																																								 
	g_cvarSilent = RegisterConVar("sm_store_silent_givecredits", "0", "Controls the give credits message visibility. 0 = public 1 = private 2 = no message", TYPE_INT);
	//g_cvarCredits = RegisterConVar("sm_store_cmd_credits_cooldown", "12", "Control of the spam cooldown time for !credits", TYPE_FLOAT);
	g_cvarGiveItemBehavior = RegisterConVar("sm_store_give_exist_item_behavior", "0", "Controls behavior when Store_GiveItem function gives an item already exists in client's inventory. 0 = create new one (default) , 1 = extend item date.");

	gc_iDescription = RegisterConVar("sm_store_description", "2", "Show item description 1 - only in menu page under item name / 2 - both menu and item page / 3 - only in item page in title", TYPE_INT);
	gc_iReloadType = RegisterConVar("sm_store_reload_config_type", "0", "Type of reload config: 1 - Change map manually / 0 - Instantly reload current map", TYPE_INT);
	gc_iReloadDelay = RegisterConVar("sm_store_reload_config_delay", "10", "Time in second to reload current map on store reload config. Dependence: \"sm_store_reload_config_type\" 0", TYPE_INT);
	gc_iReloadNotify = RegisterConVar("sm_store_reload_config_notify", "1", "Store reloadconfig notify player", TYPE_INT);

	
	g_cvarChatTag.AddChangeHook(OnSettingChanged);
	
	// After every module was loaded we are ready to generate the cfg
	//AutoExecConfig();
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvarChatTag)
	{
		strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), newValue);
	}
}

//////////////////////////////
//			CONVARS	 		//
//////////////////////////////

public void ConVar_CreditTimer(any index)
{
	any m_bTimer = (FloatCompare(g_eCvars[g_cvarCreditTimer].aCache, 0.0)==0 || g_eCvars[g_cvarCreditAmountActive].aCache==0);
	for(int i=1;i<=MaxClients;++i)
	{
		ClearTimer(g_eClients[i].hCreditTimer);
		if(m_bTimer && IsClientInGame(i))
			g_eClients[i].hCreditTimer = Store_CreditTimer(i);
	}
}
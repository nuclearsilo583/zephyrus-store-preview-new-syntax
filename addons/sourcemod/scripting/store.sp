#pragma semicolon 1
#pragma newdecls required

//////////////////////////////
//		DEFINITIONS			//
//////////////////////////////

#define PLUGIN_NAME "Store - The Resurrection with preview rewritten compilable with SM 1.10 new syntax"
#define PLUGIN_AUTHOR "Zephyrus, nuclear silo, AiDN™"
#define PLUGIN_DESCRIPTION "A completely new Store system with preview rewritten by nuclear silo"
#define PLUGIN_VERSION "6.5"
#define PLUGIN_URL ""

#define SERVER_LOCK_IP ""

//////////////////////////////
//			INCLUDES		//
//////////////////////////////

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <store>
#include <zephstocks>
#include <donate>
#include <adminmenu>
#if !defined STANDALONE_BUILD
#include <sdkhooks>
#include <cstrike>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <gifts>
//#include <scp>
#include <thirdperson>
#include <saxtonhale>
#endif

//////////////////////////////
//			ENUMS			//
//////////////////////////////

enum struct Client_Data
{
	int iId_Client;
	int iUserId;
	char szAuthId[32];
	char szName_Client[64];
	char szNameEscaped[128];
	int iCredits;
	int iOriginalCredits;
	int iDateOfJoin;
	int iDateOfLastJoin;
	int iItems;
	int aEquipment[STORE_MAX_HANDLERS*STORE_MAX_SLOTS];
	int aEquipmentSynced[STORE_MAX_HANDLERS*STORE_MAX_SLOTS];
	Handle hCreditTimer;
	bool bLoaded;
}

enum struct Menu_Handler
{
	char szIdentifier[64];
	Handle hPlugin_Handler;
	Function fnMenu;
	Function fnHandler;
}

//////////////////////////////////
//		GLOBAL VARIABLES		//
//////////////////////////////////

bool GAME_CSS = false;
bool GAME_CSGO = false;
bool GAME_DOD = false;
bool GAME_TF2 = false;
bool GAME_L4D = false;
bool GAME_L4D2 = false;

char g_szGameDir[64];
char g_sChatPrefix[128];

Handle g_hDatabase = INVALID_HANDLE;
Handle g_hAdminMenu = INVALID_HANDLE;
Handle g_hLogFile = INVALID_HANDLE;
Handle g_hCustomCredits = INVALID_HANDLE;

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
int g_cvarLogging = -1;
int g_cvarLogLast = -1;
int g_cvarPluginsLogging = -1;							  
int g_cvarSilent = -1;
//int g_cvarCredits = -1;
int gc_iDescription = -1;
int gc_iReloadType = -1;
int gc_iReloadDelay = -1;
int gc_iReloadNotify = -1;

Store_Item g_eItems[STORE_MAX_ITEMS];
Client_Data g_eClients[MAXPLAYERS+1];
Client_Item g_eClientItems[MAXPLAYERS+1][STORE_MAX_ITEMS];
Type_Handler g_eTypeHandlers[STORE_MAX_HANDLERS];
Menu_Handler g_eMenuHandlers[STORE_MAX_HANDLERS];
Item_Plan g_ePlans[STORE_MAX_ITEMS][STORE_MAX_PLANS];

Handle gf_hPreviewItem;
Handle gf_hOnConfigExecuted;
//Handle gf_hOnBuyItem;

int g_iItems = 0;
int g_iTypeHandlers = 0;
int g_iMenuHandlers = 0;
int g_iMenuBack[MAXPLAYERS+1];
int g_iLastSelection[MAXPLAYERS+1];
int g_iSelectedItem[MAXPLAYERS+1];
int g_iSelectedPlan[MAXPLAYERS+1];
int g_iMenuClient[MAXPLAYERS+1];
int g_iMenuNum[MAXPLAYERS+1];
int g_iSpam[MAXPLAYERS+1];
int g_iPackageHandler = -1;
int g_iDatabaseRetries = 0;

bool g_bInvMode[MAXPLAYERS+1];
bool g_bIsInRecurringMenu[MAXPLAYERS + 1] = {false, ...};
bool g_bMySQL = false;

char g_szClientData[MAXPLAYERS+1][256];

//new TopMenuObject:g_eStoreAdmin;
any g_eStoreAdmin;

char g_iPublicChatTrigger;
//int SilentChatTrigger = 0;
int hTime;

Handle ReloadTimer = INVALID_HANDLE;

ConVar g_cvarChatTag2;

//////////////////////////////
//			MODULES			//
//////////////////////////////

#if !defined STANDALONE_BUILD
//#include "store/hats.sp"
//#include "store/tracers.sp"
//#include "store/playerskins.sp"
//#include "store/trails.sp"
//#include "store/grenskins.sp"
//#include "store/grentrails.sp"
//#include "store/weaponcolors.sp"
//#include "store/tfsupport.sp"
//#include "store/paintball.sp"
//#include "store/betting.sp"
//#include "store/watergun.sp"
#include "store/gifts.sp"
//#include "store/scpsupport.sp"
//#include "store/weapons.sp"
//#include "store/help.sp"
//#include "store/jetpack.sp"
//#include "store/bunnyhop.sp"
//#include "store/lasersight.sp"
//#include "store/health.sp"
//#include "store/speed.sp"
//#include "store/gravity.sp"
//#include "store/invisibility.sp"
//#include "store/commands.sp"
//#include "store/doors.sp"
//#include "store/zrclass.sp"
//#include "store/jihad.sp"
//#include "store/godmode.sp"
//#include "store/sounds.sp"
#include "store/attributes.sp"
//#include "store/respawn.sp"
//#include "store/pets.sp"
//#include "store/sprays.sp"
//#include "store/admin.sp"
//#include "store_misc_voucher.sp"
//#include "store/store_misc_toplists.sp"
#endif

//uncomment the next line if you using valve weapon skin and knives (warning, this may cause your server get banned. Please use at your own risk)
//#define WEAPONS_KNIVES
#if defined WEAPONS_KNIVES
#include "store/knife.sp"
#include "store/weaponskins.sp"
#endif

//////////////////////////////////
//		PLUGIN DEFINITION		//
//////////////////////////////////

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

//////////////////////////////
//		PLUGIN FORWARDS		//
//////////////////////////////

public void OnPluginStart()
{
	RegPluginLibrary("store_zephyrus");

	if(strcmp(SERVER_LOCK_IP, "") != 0)
	{
		char m_szIP[64];
		any m_unIP = GetConVarInt(FindConVar("hostip"));
		Format(STRING(m_szIP), "%d.%d.%d.%d:%d", (m_unIP >> 24) & 0x000000FF, (m_unIP >> 16) & 0x000000FF, (m_unIP >> 8) & 0x000000FF, m_unIP & 0x000000FF, GetConVarInt(FindConVar("hostport")));

		if(strcmp(SERVER_LOCK_IP, m_szIP)!=0)
			SetFailState("GTFO");
	}

	// Identify the game
	GetGameFolderName(STRING(g_szGameDir));
	
	if(strcmp(g_szGameDir, "cstrike")==0)
		GAME_CSS = true;
	else if(strcmp(g_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	else if(strcmp(g_szGameDir, "dod")==0)
		GAME_DOD = true;
	else if(strcmp(g_szGameDir, "tf")==0)
		GAME_TF2 = true;
	else if(strcmp(g_szGameDir, "l4d")==0)
		GAME_L4D = true;
	else if(strcmp(g_szGameDir, "left4dead2")==0)
		GAME_L4D2 = true;
	else
	{
		SetFailState("This game is not be supported. Please contact the author for support.");
	}

	// Supress warnings about unused variables.....
	if(GAME_DOD || GAME_L4D || GAME_L4D2 || g_bL4D || g_bL4D2 || g_bND || GAME_TF2 || GAME_CSGO || GAME_CSS) {}

	// Setting default values
	for(int i=1;i<=MaxClients;++i)
	{
		g_eClients[i].iCredits = -1;
		g_eClients[i].iOriginalCredits = 0;
		g_eClients[i].iItems = -1;
		g_eClients[i].hCreditTimer = INVALID_HANDLE;
	}

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
	g_cvarPreview = RegisterConVar("sm_store_preview_enable", "1", "Enable/disable confirmation windows.", TYPE_INT);
	g_cvarSaveOnDeath = RegisterConVar("sm_store_save_on_death", "0", "Enable/disable client data saving on client death.", TYPE_INT);
	g_cvarCreditMessages = RegisterConVar("sm_store_credit_messages", "1", "Enable/disable messages when a player earns credits.", TYPE_INT);
	
	g_cvarChatTag = RegisterConVar("sm_store_chat_tag", "[Store] ", "The chat tag to use for displaying messages.", TYPE_STRING);
	g_cvarChatTag2 = CreateConVar("sm_store_chat_tag_plugins", "[Store] ", "The chat tag to use for displaying messages.");

	g_cvarShowVIP = RegisterConVar("sm_store_show_vip_items", "0", "If you enable this VIP items will be shown in grey.", TYPE_INT);
	g_cvarLogging = RegisterConVar("sm_store_logging", "0", "Set this to 1 for file logging and 2 to SQL logging (only MySQL). Leaving on 0 means disabled.", TYPE_INT);
	g_cvarLogLast = RegisterConVar("sm_store_log_last", "7", "How many day to delete data log since the log created in database. Leaving on 0 means no delete.", TYPE_INT);
	
	g_cvarPluginsLogging = RegisterConVar("sm_store_plugins_logging", "2", "Enable Logging for module . 0 = disable, 1 = file log, 2 = SQL log (MySQL only)", TYPE_INT);																																								 
	g_cvarSilent = RegisterConVar("sm_store_silent_givecredits", "0", "Controls the give credits message visibility. 0 = public 1 = private 2 = no message", TYPE_INT);
	//g_cvarCredits = RegisterConVar("sm_store_cmd_credits_cooldown", "12", "Control of the spam cooldown time for !credits", TYPE_FLOAT);
	
	gc_iDescription = RegisterConVar("sm_store_description", "2", "Show item description 1 - only in menu page under item name / 2 - both menu and item page / 3 - only in item page in title", TYPE_INT);
	gc_iReloadType = RegisterConVar("sm_store_reload_config_type", "0", "Type of reload config: 1 - Change map manually / 0 - Instantly reload current map", TYPE_INT);
	gc_iReloadDelay = RegisterConVar("sm_store_reload_config_delay", "10", "Time in second to reload current map on store reload config. Dependence: \"sm_store_reload_config_type\" 0", TYPE_INT);
	gc_iReloadNotify = RegisterConVar("sm_store_reload_config_notify", "1", "Store reloadconfig notify player", TYPE_INT);

	
	g_cvarChatTag2.AddChangeHook(OnSettingChanged);

	// Register Commands
	RegConsoleCmd("sm_store", Command_Store);
	RegConsoleCmd("sm_shop", Command_Store);
	RegConsoleCmd("sm_inv", Command_Inventory);
	RegConsoleCmd("sm_inventory", Command_Inventory);
	RegConsoleCmd("sm_gift", Command_Gift);
	RegConsoleCmd("sm_givecredits", Command_GiveCredits);
	RegConsoleCmd("sm_resetplayer", Command_ResetPlayer);
	RegConsoleCmd("sm_credits", Command_Credits);
	RegServerCmd("sm_store_custom_credits", Command_CustomCredits);
	
	RegAdminCmd("sm_store_reloadconfig", Command_ReloadConfig, ADMFLAG_ROOT);																	  
	
	// Hook events
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	// Load the translations file
	LoadTranslations("store.phrases");

	// Initiaze the fake package handler
	g_iPackageHandler = Store_RegisterHandler("package", "", _, _, _, _, _);

	// Initialize the modules	
#if !defined STANDALONE_BUILD
	//Hats_OnPluginStart();
	//Tracers_OnPluginStart();
	//Trails_OnPluginStart();
	//PlayerSkins_OnPluginStart();
	//GrenadeSkins_OnPluginStart();
	//GrenadeTrails_OnPluginStart();
	//WeaponColors_OnPluginStart();
	//TFSupport_OnPluginStart();
	//Paintball_OnPluginStart();
	//Watergun_OnPluginStart();
	//Betting_OnPluginStart();
	Gifts_OnPluginStart();
	//SCPSupport_OnPluginStart();
	//Weapons_OnPluginStart();
	//Help_OnPluginStart();
	//Jetpack_OnPluginStart();
	//Bunnyhop_OnPluginStart();
	//LaserSight_OnPluginStart();
	//Health_OnPluginStart();
	//Gravity_OnPluginStart();
	//Speed_OnPluginStart();
	//Invisibility_OnPluginStart();
	//Commands_OnPluginStart();
	//Doors_OnPluginStart();
	//ZRClass_OnPluginStart();
	//Jihad_OnPluginStart();

	//Godmode_OnPluginStart();
	//Sounds_OnPluginStart();
	Attributes_OnPluginStart();
	//Respawn_OnPluginStart();
	//Pets_OnPluginStart();
	//Sprays_OnPluginStart();
	//AdminGroup_OnPluginStart();
	//Vounchers_OnPluginStart();
#endif

	#if defined WEAPONS_KNIVES
		Knives_OnPluginStart();
		WeaponSkins_OnPluginStart();
	#endif

	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
		OnAdminMenuReady(topmenu);

	// Initialize handles
	g_hCustomCredits = CreateArray(3);

	// Load the config file
	Store_ReloadConfig();
	
	// After every module was loaded we are ready to generate the cfg
	AutoExecConfig();

	// Read core.cfg for chat triggers
	ReadCoreCFG();

	// Add a say command listener for shortcuts
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	LoopIngamePlayers(client)
	{
		OnClientConnected(client);
		OnClientPostAdminCheck(client);
		OnClientPutInServer(client);
	}

}

public void OnAllPluginsLoaded()
{
	CreateTimer(1.0, LoadConfig);

	if(GetFeatureStatus(FeatureType_Native, "Donate_RegisterHandler")==FeatureStatus_Available)
		Donate_RegisterHandler("Store", Store_OnPaymentReceived);
		
	//if (g_eCvars[gc_bItemVoucherEnabled].aCache)
	//{
	//Store_RegisterMenuHandler("Voucher", Voucher_OnMenu, Voucher_OnHandler);
	//}
}

public Action LoadConfig(Handle timer, any data)
{
	// Load the config file
	Store_ReloadConfig();
}

public void OnPluginEnd()
{
	LoopIngamePlayers(i)
		if(g_eClients[i].bLoaded)
			OnClientDisconnect(i);

	if(GetFeatureStatus(FeatureType_Native, "Donate_RemoveHandler")==FeatureStatus_Available)
		Donate_RemoveHandler("Store");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error,int err_max)
{
	CreateNative("Store_RegisterHandler", Native_RegisterHandler);
	CreateNative("Store_RegisterMenuHandler", Native_RegisterMenuHandler);
	CreateNative("Store_SetDataIndex", Native_SetDataIndex);
	CreateNative("Store_GetDataIndex", Native_GetDataIndex);
	CreateNative("Store_GetEquippedItem", Native_GetEquippedItem);
	CreateNative("Store_IsClientLoaded", Native_IsClientLoaded);
	CreateNative("Store_DisplayPreviousMenu", Native_DisplayPreviousMenu);
	CreateNative("Store_SetClientMenu", Native_SetClientMenu);
	CreateNative("Store_GetClientCredits", Native_GetClientCredits);
	CreateNative("Store_SetClientCredits", Native_SetClientCredits);
	CreateNative("Store_IsClientVIP", Native_IsClientVIP);
	CreateNative("Store_IsItemInBoughtPackage", Native_IsItemInBoughtPackage);
	CreateNative("Store_DisplayConfirmMenu", Native_DisplayConfirmMenu);
	CreateNative("Store_ShouldConfirm", Native_ShouldConfirm);
	CreateNative("Store_GetItem", Native_GetItem);
	CreateNative("Store_GetHandler", Native_GetHandler);
	CreateNative("Store_GiveItem", Native_GiveItem);
	CreateNative("Store_GetItemIdbyUniqueId", Native_GetItemIdbyUniqueId);
	CreateNative("Store_RemoveItem", Native_RemoveItem);
	CreateNative("Store_GetClientItem", Native_GetClientItem);
	CreateNative("Store_GetClientTarget", Native_GetClientTarget);
	CreateNative("Store_GiveClientItem", Native_GiveClientItem);
	CreateNative("Store_HasClientItem", Native_HasClientItem);
	CreateNative("Store_IterateEquippedItems", Native_IterateEquippedItems);
	CreateNative("Store_IsInRecurringMenu", Native_IsInRecurringMenu);
	CreateNative("Store_SetClientRecurringMenu", Native_SetClientRecurringMenu);
	
	CreateNative("Store_SQLEscape", Native_SQLEscape);
	CreateNative("Store_SQLQuery", Native_SQLQuery);
	CreateNative("Store_SQLLogMessage", Native_LogMessage);	
	CreateNative("Store_SQLTransaction", Native_SQLTransaction);	
	
	gf_hPreviewItem = CreateGlobalForward("Store_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	gf_hOnConfigExecuted = CreateGlobalForward("Store_OnConfigExecuted", ET_Ignore, Param_String);
	//gf_hOnBuyItem = CreateGlobalForward("Store_OnBuyItem", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);

	
#if !defined STANDALONE_BUILD
	MarkNativeAsOptional("ZR_IsClientZombie");
	MarkNativeAsOptional("ZR_IsClientHuman");
	MarkNativeAsOptional("ZR_GetClassByName");
	MarkNativeAsOptional("ZR_SelectClientClass");
	MarkNativeAsOptional("HideTrails_ShouldHide");
#endif

	//RegPluginLibrary("store");

	return APLRes_Success;
} 

#if !defined STANDALONE_BUILD
public void OnLibraryAdded(const char[] name)
{
	//PlayerSkins_OnLibraryAdded(name);
	//ZRClass_OnLibraryAdded(name);
}
#endif

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvarChatTag2)
	{
		strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), newValue);
	}
}

//////////////////////////////
//		 ADMIN MENUS		//
//////////////////////////////

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == g_hAdminMenu)
		return;
	g_hAdminMenu = topmenu;

	g_eStoreAdmin = AddToTopMenu(g_hAdminMenu, "Store Admin", TopMenuObject_Category, CategoryHandler_StoreAdmin, INVALID_TOPMENUOBJECT);
	AddToTopMenu(g_hAdminMenu, "sm_store_resetdb", TopMenuObject_Item, AdminMenu_ResetDb, g_eStoreAdmin, "sm_store_resetdb", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_resetplayer", TopMenuObject_Item, AdminMenu_ResetPlayer, g_eStoreAdmin, "sm_store_resetplayer", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_givecredits", TopMenuObject_Item, AdminMenu_GiveCredits, g_eStoreAdmin, "sm_store_givecredits", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_viewinventory", TopMenuObject_Item, AdminMenu_ViewInventory, g_eStoreAdmin, "sm_store_viewinventory", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_reload_config", TopMenuObject_Item, AdminMenu_RealoadConfig, g_eStoreAdmin, "sm_store_reload_config", g_eCvars[g_cvarAdminFlag].aCache);
}

public void CategoryHandler_StoreAdmin(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int param, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Store Admin");
}

//////////////////////////////
//		Reload config		//
//////////////////////////////

public void AdminMenu_RealoadConfig(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Reload store config");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 0;

		char sBuffer[128];
		if(!g_eCvars[gc_iReloadType].aCache)
			Format(sBuffer, sizeof(sBuffer), "%t", "confirm_reload_type_0", view_as<int>(g_eCvars[gc_iReloadDelay].aCache));
		else Format(sBuffer, sizeof(sBuffer), "%t", "confirm_reload_type_1");
		Store_DisplayConfirmMenu(client, sBuffer, FakeMenuHandler_StoreReloadConfig, 0);

	}
}

//////////////////////////////
//		Reset database		//
//////////////////////////////

public void AdminMenu_ResetDb(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Reset database");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 0;
		Store_DisplayConfirmMenu(client, "Do you want to reset database?\nServer will be restarted!", FakeMenuHandler_ResetDatabase, 0);
	}
}

public void FakeMenuHandler_ResetDatabase(Handle menu, MenuAction action, int client,int param2)
{
	SQL_TVoid(g_hDatabase, "DROP TABLE store_players");
	SQL_TVoid(g_hDatabase, "DROP TABLE store_items");
	SQL_TVoid(g_hDatabase, "DROP TABLE store_equipment");
	ServerCommand("_restart");
}

//////////////////////////////
//		Reset player		//
//////////////////////////////

public void AdminMenu_ResetPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Reset player");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		Handle m_hMenu = CreateMenu(MenuHandler_ResetPlayer);
		SetMenuTitle(m_hMenu, "Choose a player to reset");
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			char m_szName[64];
			char m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public int MenuHandler_ResetPlayer(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
			FakeClientCommandEx(client, "sm_resetplayer \"%s\"", g_szClientData[client]);
		else
		{
			any style;
			char m_szName[64];
			GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]), style, STRING(m_szName));

			char m_szTitle[256];
			Format(STRING(m_szTitle), "Do you want to reset %s?", m_szName);
			Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_ResetPlayer, 0);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

//////////////////////////////
//		Give credits		//
//////////////////////////////

public void AdminMenu_GiveCredits(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Give credits");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 5;
		Handle m_hMenu = CreateMenu(MenuHandler_GiveCredits);
		SetMenuTitle(m_hMenu, "Choose a player to give credits to");
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			char m_szName[64];
			char m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public int MenuHandler_GiveCredits(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(param2 != -1)
			GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]));
		Handle m_hMenu = CreateMenu(MenuHandler_GiveCredits2);

		int target = GetClientBySteamID(g_szClientData[client]);
		if(target == 0)
		{
			AdminMenu_GiveCredits(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
			return;
		}

		SetMenuTitle(m_hMenu, "Choose the amount of credits\n%N - %d credits", target, g_eClients[target].iCredits);
		SetMenuExitBackButton(m_hMenu, true);
		AddMenuItem(m_hMenu, "-1000", "-1000");
		AddMenuItem(m_hMenu, "-100", "-100");
		AddMenuItem(m_hMenu, "-10", "-10");
		AddMenuItem(m_hMenu, "10", "10");
		AddMenuItem(m_hMenu, "100", "100");
		AddMenuItem(m_hMenu, "1000", "1000");
		DisplayMenu(m_hMenu, client, 0);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

public int MenuHandler_GiveCredits2(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		char m_szData[11];
		GetMenuItem(menu, param2, STRING(m_szData));
		FakeClientCommand(client, "sm_givecredits \"%s\" %s", g_szClientData[client], m_szData);
		MenuHandler_GiveCredits(INVALID_HANDLE, MenuAction_Select, client, -1);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		AdminMenu_GiveCredits(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
}

//////////////////////////////
//		View inventory		//
//////////////////////////////

public void AdminMenu_ViewInventory(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "View inventory");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		Handle m_hMenu = CreateMenu(MenuHandler_ViewInventory);
		SetMenuTitle(m_hMenu, "Choose a player");
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			char m_szName[64];
			char m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public int MenuHandler_ViewInventory(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]));
		int target = GetClientBySteamID(g_szClientData[client]);
		if(target == 0)
		{
			AdminMenu_ViewInventory(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
			return;
		}

		g_bInvMode[client]=true;
		g_iMenuClient[client]=target;
		DisplayStoreMenu(client);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

//////////////////////////////////////
//		REST OF PLUGIN FORWARDS		//
//////////////////////////////////////

public void OnMapStart()
{
	for(int i=0;i<g_iTypeHandlers;++i)
	{
		if(g_eTypeHandlers[i].fnMapStart != INVALID_FUNCTION)
		{
			Call_StartFunction(g_eTypeHandlers[i].hPlugin, g_eTypeHandlers[i].fnMapStart);
			Call_Finish();
		}
	}
}

public void OnMapEnd()
{
	ReloadTimer = INVALID_HANDLE;
}

public void OnConfigsExecuted()
{
	//Jetpack_OnConfigsExecuted();
	//Jihad_OnConfigsExecuted();
	
	// Call foward Store_OnConfigsExecuted
	Forward_OnConfigsExecuted();

	// Connect to the database
	if(g_hDatabase == INVALID_HANDLE)
		SQL_TConnect(SQLCallback_Connect, g_eCvars[g_cvarDatabaseEntry].sCache);
	if(g_eCvars[g_cvarDatabaseRetries].aCache > 0)
		CreateTimer(view_as<float>(g_eCvars[g_cvarDatabaseTimeout].aCache), Timer_DatabaseTimeout);

	if(g_eCvars[g_cvarLogging].aCache == 1 || g_eCvars[g_cvarPluginsLogging].aCache == 1)
		if(g_hLogFile == INVALID_HANDLE)
		{
			char m_szPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, STRING(m_szPath), "logs/store.log.txt");
			g_hLogFile = OpenFile(m_szPath, "w+");
		}
}

#if !defined STANDALONE_BUILD
public void OnGameFrame()
{
	//Trails_OnGameFrame();
	//TFWeapon_OnGameFrame();
	//TFHead_OnGameFrame();
}
#endif

#if !defined STANDALONE_BUILD
public void OnEntityCreated(int entity, const char[] classname)
{
	//GrenadeSkins_OnEntityCreated(entity, classname);
	//GrenadeTrails_OnEntityCreated(entity, classname);
}
#endif

//////////////////////////////
//			NATIVES			//
//////////////////////////////

public int Native_RegisterHandler(Handle plugin,int numParams)
{
	if(g_iTypeHandlers == STORE_MAX_HANDLERS)
		return -1;
		
	char m_szType[32];
	GetNativeString(1, STRING(m_szType));
	int m_iHandler = Store_GetTypeHandler(m_szType);	
	int m_iId = g_iTypeHandlers;
	
	if(m_iHandler != -1)
		m_iId = m_iHandler;
	else
		++g_iTypeHandlers;
	
	g_eTypeHandlers[m_iId].hPlugin = plugin;
	g_eTypeHandlers[m_iId].fnMapStart = GetNativeCell(3);
	g_eTypeHandlers[m_iId].fnReset = GetNativeCell(4);
	g_eTypeHandlers[m_iId].fnConfig = GetNativeCell(5);
	g_eTypeHandlers[m_iId].fnUse = GetNativeCell(6);
	g_eTypeHandlers[m_iId].fnRemove = GetNativeCell(7);
	g_eTypeHandlers[m_iId].bEquipable = GetNativeCell(8);
	g_eTypeHandlers[m_iId].bRaw = GetNativeCell(9);
	//strcopy(g_eTypeHandlers[m_iId][szType], 32, m_szType);
	strcopy(g_eTypeHandlers[m_iId].szType, sizeof(Type_Handler::szType), m_szType);
	//GetNativeString(2, g_eTypeHandlers[m_iId].szUniqueKey, 32);
	GetNativeString(2, g_eTypeHandlers[m_iId].szUniqueKey, sizeof(Type_Handler::szUniqueKey));

	return m_iId;
}

public int Native_RegisterMenuHandler(Handle plugin,int numParams)
{
	if(g_iMenuHandlers == STORE_MAX_HANDLERS)
		return -1;
		
	char m_szIdentifier[64];
	GetNativeString(1, STRING(m_szIdentifier));
	int m_iHandler = Store_GetMenuHandler(m_szIdentifier);	
	int m_iId = g_iMenuHandlers;
	
	if(m_iHandler != -1)
		m_iId = m_iHandler;
	else
		++g_iMenuHandlers;
	
	g_eMenuHandlers[m_iId].hPlugin_Handler = plugin;
	g_eMenuHandlers[m_iId].fnMenu = GetNativeCell(2);
	g_eMenuHandlers[m_iId].fnHandler = GetNativeCell(3);
	strcopy(g_eMenuHandlers[m_iId].szIdentifier, sizeof(Menu_Handler::szIdentifier), m_szIdentifier);

	return m_iId;
}

public int Native_IsInRecurringMenu(Handle plugin, int numParams)
{
	return g_bIsInRecurringMenu[GetNativeCell(1)];
}

public int Native_SetClientRecurringMenu(Handle plugin, int numParams)
{
	g_bIsInRecurringMenu[GetNativeCell(1)] = view_as<bool>(GetNativeCell(2));
}

public any Native_SetDataIndex(Handle plugin,int numParams)
{
	g_eItems[GetNativeCell(1)].iData = GetNativeCell(2);
}

public any Native_GetDataIndex(Handle plugin,int numParams)
{
	return g_eItems[GetNativeCell(1)].iData;
}

public any Native_GetEquippedItem(Handle plugin,int numParams)
{
	char m_szType[16];
	GetNativeString(2, STRING(m_szType));
	
	int m_iHandler = Store_GetTypeHandler(m_szType);
	if(m_iHandler == -1)
		return -1;
	
	return Store_GetEquippedItemFromHandler(GetNativeCell(1), m_iHandler, GetNativeCell(3));
}

public any Native_IsClientLoaded(Handle plugin,int numParams)
{
	return g_eClients[GetNativeCell(1)].bLoaded;
}

public any Native_DisplayPreviousMenu(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	if(g_iMenuNum[client] == 1)
		DisplayStoreMenu(client, g_iMenuBack[client], g_iLastSelection[client]);
	else if(g_iMenuNum[client] == 2)
		DisplayItemMenu(client, g_iSelectedItem[client]);
	else if(g_iMenuNum[client] == 3)
		DisplayPlayerMenu(client);
	else if(g_iMenuNum[client] == 4)
		AdminMenu_ResetPlayer(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
	else if(g_iMenuNum[client] == 5)
		DisplayPlanMenu(client, g_iSelectedItem[client]);
	else if(g_iMenuNum[client] == 0)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

public any Native_SetClientMenu(Handle plugin,int numParams)
{
	g_iMenuNum[GetNativeCell(1)] = GetNativeCell(2);
}

public any Native_GetClientCredits(Handle plugin,int numParams)
{
	return g_eClients[GetNativeCell(1)].iCredits;
}

public int Native_SetClientCredits(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int m_iCredits = GetNativeCell(2);
	Store_LogMessage(client, m_iCredits-g_eClients[client].iCredits, "Set by external plugin");
	g_eClients[client].iCredits = m_iCredits;
	Store_SaveClientData(client);
	return 1;
}

public any Native_IsClientVIP(Handle plugin,int numParams)
{
	return (g_eCvars[g_cvarVIPFlag].aCache != 0 && GetClientPrivilege(GetNativeCell(1), g_eCvars[g_cvarVIPFlag].aCache));
}

public int Native_IsItemInBoughtPackage(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	any uid = GetNativeCell(3);

	any m_iParent;
	if(itemid<0)
		m_iParent = g_eItems[itemid].iParent;
	else
		m_iParent = g_eItems[itemid].iParent;
		
	while(m_iParent != -1)
	{
		for(int i=0;i<g_eClients[client].iItems;++i)
			if(((uid == -1 && g_eClientItems[client][i].iUniqueId == m_iParent) || (uid != -1 && g_eClientItems[client][i].iUniqueId == uid)) && !g_eClientItems[client][i].bDeleted)
				return true;
		m_iParent = g_eItems[m_iParent].iParent;
	}
	return false;
}

public int Native_DisplayConfirmMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char sBuffer[255];
	GetNativeString(2, sBuffer, sizeof(sBuffer));

	//Zephyrus magic with pinch of kxnlr
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteCell(GetNativeCell(3));
	pack.Reset();

	char sCallback[32];
	char sData[11];
	IntToString(view_as<int>(pack), sCallback, sizeof(sCallback));
	IntToString(GetNativeCell(4), sData, sizeof(sData));

	//delete pack;
	Menu menu = new Menu(MenuHandler_Confirm);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Confirm_Yes");
	menu.AddItem(sCallback, sBuffer, ITEMDRAW_DEFAULT);

	Format(sBuffer, sizeof(sBuffer), "%t", "Confirm_No");
	menu.AddItem(sData, sBuffer, ITEMDRAW_DEFAULT);
	//Zephyrus magic

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Native_ShouldConfirm(Handle plugin,int numParams)
{
	return g_eCvars[g_cvarConfirmation].aCache;
}

public int Native_GetItem(Handle plugin,int numParams)
{
	SetNativeArray(2, view_as<int>(g_eItems[GetNativeCell(1)]), sizeof(g_eItems[])); 
}

public int Native_GetItemIdbyUniqueId(Handle plugin, int numParams)
{
	char sUId[1024];
	GetNativeString(1, sUId, sizeof(sUId));

	for (int i = 0; i < g_iItems; i++)
	{
		if (StrEqual(sUId, g_eItems[i].szUniqueId))
			return i;
	}

	return -1;
}

public int Native_GetHandler(Handle plugin,int numParams)
{
	SetNativeArray(2, view_as<int>(g_eTypeHandlers[GetNativeCell(1)]), sizeof(g_eTypeHandlers[])); 
}

public int Native_GetClientItem(Handle plugin,int numParams)
{
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);

	new uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;

	SetNativeArray(3, view_as<int>(g_eClientItems[client][uid]), sizeof(g_eClientItems[][])); 

	return 1;
}

public int Native_GiveItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int purchase = GetNativeCell(3);
	int expiration = GetNativeCell(4);
	int price = GetNativeCell(5);

	int m_iDateOfPurchase = (purchase==0?GetTime():purchase);
	int m_iDateOfExpiration = expiration;

	int m_iId = g_eClients[client].iItems++;
	g_eClientItems[client][m_iId].iId_Client_Item = -1;
	g_eClientItems[client][m_iId].iUniqueId = itemid;
	g_eClientItems[client][m_iId].iDateOfPurchase = m_iDateOfPurchase;
	g_eClientItems[client][m_iId].iDateOfExpiration = m_iDateOfExpiration;
	g_eClientItems[client][m_iId].iPriceOfPurchase = price;
	g_eClientItems[client][m_iId].bSynced = false;
	g_eClientItems[client][m_iId].bDeleted = false;
	
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
}

public int Native_RemoveItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	if(itemid>0 && g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove != INVALID_FUNCTION)
	{
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid].iHandler].hPlugin, g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}
	
	Store_UnequipItem(client, itemid, false);
	
	int m_iId = Store_GetClientItemId(client, itemid);
	if(m_iId != -1)
		g_eClientItems[client][m_iId].bDeleted = true;
	
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
}

public int Native_GetClientTarget(Handle plugin,int numParams)
{
	return g_iMenuClient[GetNativeCell(1)];
}

public int Native_GiveClientItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int receiver = GetNativeCell(2);
	int itemid = GetNativeCell(3);

	int item = Store_GetClientItemId(client, itemid);
	if(item == -1)
		return 1;

	int m_iId = g_eClientItems[client][item].iUniqueId;
	int target = g_iMenuClient[client];
	g_eClientItems[client][item].bDeleted = true;
	Store_UnequipItem(client, m_iId);

	g_eClientItems[receiver][g_eClients[receiver].iItems].iId_Client_Item = -1;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iUniqueId = m_iId;
	g_eClientItems[receiver][g_eClients[receiver].iItems].bSynced = false;
	g_eClientItems[receiver][g_eClients[receiver].iItems].bDeleted = false;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iDateOfPurchase = g_eClientItems[target][item].iDateOfPurchase;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iDateOfExpiration = g_eClientItems[target][item].iDateOfExpiration;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iPriceOfPurchase = g_eClientItems[target][item].iPriceOfPurchase;
	
	++g_eClients[receiver].iItems;
	
	LoopIngamePlayers(i)
	{
		Store_SaveClientData(i);
		Store_SaveClientInventory(i);
		Store_SaveClientEquipment(i);
	}

	return 1;
}

public int Native_HasClientItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);

	// Can he even have it?	
	if(!GetClientPrivilege(client, g_eItems[itemid].iFlagBits) || !CheckSteamAuth(client, g_eItems[itemid].szSteam))
	{
		if (g_eItems[itemid].iPrice <= 0 && g_eItems[itemid].iPlans==0)
			return false;
			//if(g_eClientItems[client][i][iDateOfExpiration]==0 || (g_eClientItems[client][i][iDateOfExpiration] && GetTime()<g_eClientItems[client][i][iDateOfExpiration]))
		
		for(int i=0;i<g_eClients[client].iItems;++i)
		{	
			if(g_eClientItems[client][i].iUniqueId == itemid && !g_eClientItems[client][i].bDeleted)
				if(g_eClientItems[client][i].iDateOfExpiration==0 || (g_eClientItems[client][i].iDateOfExpiration && GetTime()<g_eClientItems[client][i].iDateOfExpiration))
					return true;
				else
					return false;
		}
	}

	// Is the item free (available for everyone)?
	if (g_eItems[itemid].iPrice <= 0 && g_eItems[itemid].iPlans==0)
		return true;
		
	// Is the client a VIP therefore has access to all the items already?
	if(Store_IsClientVIP(client) && !g_eItems[itemid].bIgnoreVIP && !g_eItems[itemid].bIgnoreFree)
		return true;
		
	// Can he even have it?	
	//if(!GetClientPrivilege(client, g_eItems[itemid][iFlagBits]))
	//	return false;
		
	// Check if the client actually has the item
	for(int i=0;i<g_eClients[client].iItems;++i)
	{
		if(g_eClientItems[client][i].iUniqueId == itemid && !g_eClientItems[client][i].bDeleted)
			if(g_eClientItems[client][i].iDateOfExpiration==0 || (g_eClientItems[client][i].iDateOfExpiration && GetTime()<g_eClientItems[client][i].iDateOfExpiration))
				return true;
			else
				return false;
	}
	
	// Check if the item is part of a group the client already has
	if(Store_IsItemInBoughtPackage(client, itemid))
		return true;
		
	return false;
}

public int Native_IterateEquippedItems(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int start = GetNativeCellRef(2);
	bool attributes = GetNativeCell(3);

	for(int i=start+1;i<STORE_MAX_HANDLERS*STORE_MAX_SLOTS;++i)
	{
		if(g_eClients[client].aEquipment[i] >= 0 && (attributes==false || (attributes && g_eItems[g_eClients[client].aEquipment[i]].hAttributes!=INVALID_HANDLE)))
		{
			SetNativeCellRef(2, i);
			return g_eClients[client].aEquipment[i];
		}
	}
		
	return -1;
}

public int Native_SQLEscape(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	char sBuffer[512], sBuffer2[512];
	GetNativeString(1, sBuffer, sizeof(sBuffer));

	SQL_EscapeString(g_hDatabase, sBuffer, sBuffer2, sizeof(sBuffer2));

	SetNativeString(1, sBuffer2, sizeof(sBuffer2));

	return 1;
}

public int Native_SQLQuery(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	char sQuery[512];
	GetNativeString(1, sQuery, sizeof(sQuery));
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(GetNativeFunction(2));
	pack.WriteCell(GetNativeCell(3));

	SQL_TQuery(g_hDatabase, Natives_SQLCallback, sQuery, pack);
	return 1;
}

public void Natives_SQLCallback(Handle owner, Handle results, const char[] error, DataPack pack)
{
	pack.Reset();
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	any data = pack.ReadCell();
	delete pack;

	Call_StartFunction(plugin, callback);
	Call_PushCell(owner);
	Call_PushCell(results);
	Call_PushString(error);
	Call_PushCell(data);
	Call_Finish();
}

public int Native_SQLTransaction(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	Transaction tnx = GetNativeCell(1);
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(GetNativeFunction(2));
	pack.WriteCell(GetNativeCell(3));

	//g_hDatabase.Execute(tnx, Natives_SQLTXNCallback_Success, Natives_SQLTXNCallback_Error, pack);
	SQL_ExecuteTransaction(g_hDatabase, tnx, Natives_SQLTXNCallback_Success, Natives_SQLTXNCallback_Error, pack);

	return 1;
}

public void Natives_SQLTXNCallback_Success(Database db, DataPack pack, int numQueries, Handle[] results, any[] queryData)
{
	PrintToServer("Store - Native Transaction Complete - Querys: %i", numQueries);

	pack.Reset();
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	any data = pack.ReadCell();
	delete pack;

	Call_StartFunction(plugin, callback);
	Call_PushCell(db);
	Call_PushCell(data);
	Call_PushCell(numQueries);
	Call_PushArray(results, numQueries);
	Call_PushArray(queryData, numQueries);
	Call_Finish();
}

public void Natives_SQLTXNCallback_Error(Database db, DataPack pack, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	pack.Reset();
	Handle plugin = pack.ReadCell();
	delete pack;

	char sBuffer[64];
	GetPluginFilename(plugin, sBuffer, sizeof(sBuffer));

	StoreLogMessage(0, LOG_ERROR, "Natives_SQLTXNCallback_Error: %s - Plugin: %s Querys: %i - FailedIndex: %i", error, sBuffer, numQueries, failIndex);
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char sBuffer[256];
	char sPlugin[256];
	int client = GetNativeCell(1);
	int level = GetNativeCell(2);
	GetNativeString(3, sBuffer, sizeof(sBuffer));
	FormatNativeString(0, 3, 4, sizeof(sBuffer), _, sBuffer);

	GetPluginFilename(plugin, sPlugin, sizeof(sPlugin));
	Format(sBuffer, sizeof(sBuffer), "Plugin: %s - %s", sPlugin, sBuffer);

	StoreLogMessage(client, level, sBuffer);
}

void StoreLogMessage(int client = 0, int level, char[] message, any ...)
{
	if (g_eCvars[g_cvarPluginsLogging].aCache < 1)
		return;

	char sLevel[8];
	char sReason[256];
	VFormat(sReason, sizeof(sReason), message, 4);
	
	char steamid[64], name[64];
	if(client)
	{
		// steam id, name
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		GetClientName(client, name, sizeof(name));
	}
	
	switch(level)
	{
		case LOG_ADMIN: strcopy(sLevel, sizeof(sLevel), "[Admin]");
		case LOG_EVENT: strcopy(sLevel, sizeof(sLevel), "[Event]");
		case LOG_CREDITS: strcopy(sLevel, sizeof(sLevel), "[Credits]");
		case LOG_ERROR:
		{
			strcopy(sLevel, sizeof(sLevel), "[ERROR]");
			LogError("%s - %L - %s", sLevel, client, sReason);
		}
	}

	if(g_eCvars[g_cvarPluginsLogging].aCache == 2)
	{
		char sQuery[1024];
		SQL_EscapeString(g_hDatabase, sQuery, sQuery, sizeof(sQuery));
		if (client)
		{
			if(g_bMySQL)
				Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", %i, \"%s\", CURRENT_TIMESTAMP, \"%s\", \"%s\")", sLevel, g_eClients[client].iId_Client, sReason, name, steamid);
			else
				Format(sQuery, sizeof(sQuery), "INSERT INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", %i, \"%s\", CURRENT_TIMESTAMP, \"%s\", \"%s\")", sLevel, g_eClients[client].iId_Client, sReason, name, steamid);
		}
		else
		{
			if(g_bMySQL)
				Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", \"0\", \"%s\", CURRENT_TIMESTAMP, \"Console\", \"0\")", sLevel, sReason);
			else
				Format(sQuery, sizeof(sQuery), "INSERT INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", \"0\", \"%s\", CURRENT_TIMESTAMP, \"Console\", \"0\")", sLevel, sReason);
		}
		SQL_TQuery(g_hDatabase, SQLCallback_Void_Error, sQuery);
	}
	else if(g_eCvars[g_cvarPluginsLogging].aCache == 1)
	{
		LogToOpenFileEx(g_hLogFile, "%s - %L - %s", sLevel, client, sReason); //WriteFileLine(g_hLogFile, "%s - %L - %s", sLevel, client, sReason); //todo dont work
	}
}
//////////////////////////////
//		CLIENT FORWARDS		//
//////////////////////////////

public void OnClientConnected(int client)
{
	g_iSpam[client] = 0;
	g_eClients[client].iUserId = GetClientUserId(client);
	g_eClients[client].iCredits = -1;
	g_eClients[client].iOriginalCredits = 0;
	g_eClients[client].iItems = -1;
	g_eClients[client].bLoaded = false;
	for(int i=0;i<STORE_MAX_HANDLERS;++i)
	{
		for(int a=0;a<STORE_MAX_SLOTS;++a)
		{
			g_eClients[client].aEquipment[i*STORE_MAX_SLOTS+a] = -2;
			g_eClients[client].aEquipmentSynced[i*STORE_MAX_SLOTS+a] = -2;
		}
	}

#if !defined STANDALONE_BUILD
	//PlayerSkins_OnClientConnected(client);
	//Jetpack_OnClientConnected(client);
	//ZRClass_OnClientConnected(client);
	//Pets_OnClientConnected(client);
	//Sprays_OnClientConnected(client);
#endif
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;
	Store_LoadClientInventory(client);
}

#if !defined STANDALONE_BUILD
public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;
	//WeaponColors_OnClientPutInServer(client);
	#if defined WEAPONS_KNIVES
		Knives_OnClientPutInServer(client);
		WeaponSkins_OnClientPutInServer(client);
	#endif

}
#endif

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;
	
#if !defined STANDALONE_BUILD
	//Betting_OnClientDisconnect(client);
	//Pets_OnClientDisconnect(client);
#endif

	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
	Store_DisconnectClient(client);
	g_bIsInRecurringMenu[client] = false;
}

public void OnClientSettingsChanged(int client)
{
	GetClientName(client, g_eClients[client].szName_Client, 64);
	if(g_hDatabase)
		SQL_EscapeString(g_hDatabase, g_eClients[client].szName_Client, g_eClients[client].szNameEscaped, 128);
}

#if !defined STANDALONE_BUILD
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsClientInGame(client))
		return Plugin_Continue;

	//new Action m_iRet = Plugin_Continue;

	//Jetpack_OnPlayerRunCmd(client, buttons);
	//LaserSight_OnPlayerRunCmd(client);
	//Pets_OnPlayerRunCmd(client, tickcount);
	//Sprays_OnPlayerRunCmd(client, buttons);
	//m_iRet = Bunnyhop_OnPlayerRunCmd(client, buttons);

	return Plugin_Continue;
}
#endif

//////////////////////////////
//			EVENTS			//
//////////////////////////////

public Action Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if(g_eCvars[g_cvarSaveOnDeath].aCache)
	{
		Store_SaveClientData(victim);
		Store_SaveClientInventory(victim);
		Store_SaveClientEquipment(victim);
	}

	if(!attacker || victim == attacker || !IsClientInGame(attacker) || IsFakeClient(attacker))
		return Plugin_Continue;
	if ((GAME_L4D2 || GAME_L4D) && g_eCvars[g_cvarCreditAmountKill].aCache)
	{
		if( victim ) // still give credits on killing Specials Infected
		{
			char buffer[32];
			GetEventString(event, "victimname", buffer, sizeof(buffer));
			if( strlen(buffer) != 0 && !StrEqual(buffer, "infected") )
			{
				//PrintToChatAll("\x03Special infected '\x01%s\x03' death", buffer);  // debug
				//do some function - SPECIAL INFECTED DEATH
				g_eClients[attacker].iCredits += GetMultipliedCredits(attacker, g_eCvars[g_cvarCreditAmountKill].aCache);
				Chat(attacker, "%t", "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
			}
		}
		else // prevent farming credits by killing Commin Infected
		{
			int victimentityid = GetEventInt(event, "entityid");
			if( IsCommonInfected(victimentityid) )
			{
				//PrintToChatAll("\x01Common infected death"); // debug
				return Plugin_Continue;
				//do some function - COMMNON INFECTED DEATH
			}
		}
	}
	else if(g_eCvars[g_cvarCreditAmountKill].aCache)
	{
		//g_eClients[attacker][iCredits] += g_eCvars[g_cvarCreditAmountKill].aCache;
		g_eClients[attacker].iCredits += GetMultipliedCredits(attacker, g_eCvars[g_cvarCreditAmountKill].aCache);
		if(g_eCvars[g_cvarCreditMessages].aCache)
			Chat(attacker, "%t", "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
		Store_LogMessage(attacker, g_eCvars[g_cvarCreditAmountKill].aCache, "Earned for killing");
	}
		
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsClientInGame(client))
		return Plugin_Continue;

#if !defined STANDALONE_BUILD
	//Health_OnPlayerSpawn(client);
#endif
		
	return Plugin_Continue;
}


//////////////////////////////////
//			COMMANDS	 		//
//////////////////////////////////

public Action Command_Say(int client, const char[] command,int argc)
{
	if(argc > 0)
	{
		char m_szArg[65];
		GetCmdArg(1, STRING(m_szArg));
		if(m_szArg[0] == g_iPublicChatTrigger)
		{
			for(int i=0;i<g_iItems;++i)
				if(strcmp(g_eItems[i].szShortcut, m_szArg[1])==0 && g_eItems[i].szShortcut[0] != 0)
				{
					g_bInvMode[client]=false;
					g_iMenuClient[client]=client;
					DisplayStoreMenu(client, i);
					break;
				}
		}
	}

	return Plugin_Continue;
}

public Action Command_Store(int client,int params)
{
	if(g_eCvars[g_cvarRequiredFlag].aCache && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag].aCache))
	{
		Chat(client, "%t", "You dont have permission");
		return Plugin_Handled;
	}
	
	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		Chat(client, "%t", "Inventory hasnt been fetched");
		return Plugin_Handled;
	}
	
	char itemname[64];
	GetCmdArg(1, itemname, sizeof(itemname));
	
	//if(itemname[0] == '$')
	//{
		//strcopy(itemname, sizeof(itemname), itemname);
	//Store_ItemName(client, itemname);
	//}
	
	if(params > 0)
	{
		Store_ItemName(client, itemname);
	}
	
	if(params == 0)
	{
		g_bInvMode[client]=false;
		g_iMenuClient[client]=client;
		DisplayStoreMenu(client);
	}
	
	return Plugin_Handled;
}

void Store_ItemName(int client, char[] sItemName)
{
	int iItemCount = 0;
	//	iItemIndex = -1;
		
	for(int i = 0; i<g_iItems; i++)
	{
		//if((StrContains(g_eItems[i][szName], sItemName, false) != -1 || StrContains(g_eItems[i][szUniqueId], sItemName, false) != -1))
		if(StrContains(g_eItems[i].szName, sItemName, false) != -1 || StrContains(g_eItems[i].szUniqueId, sItemName, false) != -1)
		{
			iItemCount++;
			//iItemIndex = i;
			//g_iSelectedItem[client] = iItemIndex;
		}
	}
	if(iItemCount <= 0)
	{
		//Not Found
		//CPrintToChat(client, "%s%t", g_sChatPrefix, "Item not found", sItemName);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item not found");
	} /*else if(iItemCount == 1)
	{
		///Only 1 weapon
		g_bInvMode[client]=false;
		g_iMenuClient[client]=client;
		//DisplayStoreMenu(client, iItemIndex);
		//if (g_eItems[iItemIndex][bPreview])
		//	DisplayPreviewMenu(client, iItemIndex);
		//else DisplayItemMenu(client, iItemIndex);
		g_iSelectedItem[client] = iItemIndex;
		
		if (g_eItems[g_iSelectedItem[client]][bPreview])
			DisplayPreviewMenu(client, g_iSelectedItem[client]);
		else DisplayItemMenu(client, g_iSelectedItem[client]);
		//break;
		//Display(client, iItemIndex, iReceiver, true);
	} */
	else
	{
		//More 1 weapon
		int m_iFlags = GetUserFlagBits(client);
		
		Menu hEdictMenu = CreateMenu(Store_ItemNameMenu_Handler);
		char sMenuTemp[1024], sIndexTemp[128];
		FormatEx(sMenuTemp, sizeof(sMenuTemp), "%t", "Search Info Title", sItemName);
		hEdictMenu.SetTitle(sMenuTemp);

		for(int i = 0; i<g_iItems; i++)
		{
			if((StrContains(g_eItems[i].szName, sItemName, false) != -1 || StrContains(g_eItems[i].szUniqueId, sItemName, false) != -1))
			{
				FormatEx(sIndexTemp, sizeof(sIndexTemp), "%i", i);
				int iStyle = ITEMDRAW_DEFAULT;
				//FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s)", g_eItems[i][szName], g_eItems[i][szType], client);
				/*
				if(!CheckSteamAuth(target, g_eItems[itemid][szSteam]))
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i][szName_Plan], g_ePlans[itemid][i][iPrice_Plan]);
					menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
				}
				else if (GetClientPrivilege(target, g_eItems[itemid][iFlagBits], m_iFlags) || g_eItems[itemid][szSteam][0])
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i][szName_Plan], g_ePlans[itemid][i][iPrice_Plan]);
					menu.AddItem("", sBuffer, (g_eClients[target][iCredits]>=g_ePlans[itemid][i][iPrice_Plan])? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
				}
				*/
				
				if (g_eItems[i].iPlans != 0 /*&& g_eItems[i][bPreview]*/)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, client);
				}
				
				else if(!CheckSteamAuth(client, g_eItems[i].szSteam) && !g_eItems[i].bPreview)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) (%t)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																			"Cant be bought", client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else if (!GetClientPrivilege(client, g_eItems[i].iFlagBits, m_iFlags) && !g_eItems[i].bPreview)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) (%t)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																			"Cant be bought", client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else if(Store_HasClientItem(client, i))
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) %t", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, "Owned", client);
				}
				else if(!g_eItems[i].bBuyable)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) (%t)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																			"Cant be bought", client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else if (g_eClients[client].iCredits<g_eItems[i].iPrice)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) - %t", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																					"Price", g_eItems[i].iPrice, client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else 
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) - %t", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																					"Price", g_eItems[i].iPrice, client);
				}
				
				hEdictMenu.AddItem(sIndexTemp, sMenuTemp, iStyle);
			}
		}
		hEdictMenu.ExitButton = true;
		hEdictMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Store_ItemNameMenu_Handler(Menu hEdictMenu, MenuAction hAction, int client, int iParam2)
{
	switch (hAction)
	{
		case MenuAction_End:delete hEdictMenu;
		case MenuAction_Select:
		{
			char sSelected[32];
			GetMenuItem(hEdictMenu, iParam2, sSelected, sizeof(sSelected));
			g_iSelectedItem[client] = StringToInt(sSelected);
			//ExplodeString(sSelected, "/", Explode_sParam, 2, 32);
			//int iItemIndex = StringToInt(Explode_sParam[0]);
			//int iReceiver = GetClientOfUserId(StringToInt(Explode_sParam[1]));
			
			g_iMenuBack[client]=g_eItems[StringToInt(sSelected)].iParent;
			
			if(g_eItems[StringToInt(sSelected)].iHandler == g_iPackageHandler)
				DisplayStoreMenu(client, g_iSelectedItem[client]);
			else 
			{
				//if (!g_eItems[StringToInt(sSelected)][bBuyable])
				//	CPrintToChat(client, " %s%t", g_sChatPrefix, "Cant be bought");
				if (g_eItems[StringToInt(sSelected)].bPreview && g_eItems[StringToInt(sSelected)].iPlans == 0 && !Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayPreviewMenu(client, g_iSelectedItem[client]);
				else if (g_eItems[StringToInt(sSelected)].bPreview && g_eItems[StringToInt(sSelected)].iPlans != 0 && !Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayPlanMenu(client, StringToInt(sSelected));
				else if (!g_eItems[StringToInt(sSelected)].bPreview && g_eItems[StringToInt(sSelected)].iPlans != 0 && !Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayPlanMenu(client, StringToInt(sSelected));
				else if (Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayItemMenu(client, StringToInt(sSelected));
				//else if (Store_IsClientVIP(client))
				//	DisplayItemMenu(client, StringToInt(sSelected));
				else 
				{
					//DisplayItemMenu(client, StringToInt(sSelected));
					char sTitle[128];
					Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType);
					Store_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
				}
			}
		}
	}
}


public Action Command_Inventory(int client,int params)
{
	if(g_eCvars[g_cvarRequiredFlag].aCache && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag].aCache))
	{
		Chat(client, "%t", "You dont have permission");
		return Plugin_Handled;
	}
	
	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		Chat(client, "%t", "Inventory hasnt been fetched");
		return Plugin_Handled;
	}
	
	g_bInvMode[client]=true;
	g_iMenuClient[client]=client;
	DisplayStoreMenu(client);

	return Plugin_Handled;
}

public Action Command_Gift(int client,int params)
{
	if(!g_eCvars[g_cvarCreditGiftEnabled].aCache)
	{
		Chat(client, "%t", "Credit Gift Disabled");
		return Plugin_Handled;
	}
	
	char m_szTmp[64];
	GetCmdArg(2, STRING(m_szTmp));
	
	int m_iCredits = StringToInt(m_szTmp);
	if(g_eClients[client].iCredits<m_iCredits || m_iCredits<=0)
	{
		Chat(client, "%t", "Credit Invalid Amount");
		return Plugin_Handled;
	}

	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));
	
	int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
	if(m_clients>2)
	{
		Chat(client, "%t", "Credit Too Many Matches");
		return Plugin_Handled;
	}
	
	if(m_clients != 1)
	{
		Chat(client, "%t", "Credit No Match");
		return Plugin_Handled;
	}
	
	int m_iReceiver = m_iTargets[0];
	
	g_eClients[client].iCredits -= m_iCredits;
	g_eClients[m_iReceiver].iCredits += m_iCredits;
	
	Chat(client, "%t", "Credit Gift Sent", m_iCredits, g_eClients[m_iReceiver].szName_Client);
	Chat(m_iReceiver, "%t", "Credit Gift Received", m_iCredits, g_eClients[client].szName_Client);

	Store_LogMessage(m_iReceiver, m_iCredits, "Gifted by %N", client);
	Store_LogMessage(client, -m_iCredits, "Gifted to %N", m_iReceiver);
	
	return Plugin_Handled;
}

public Action Command_GiveCredits(int client,int params)
{
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarAdminFlag].aCache))
	{
		Chat(client, "%t", "You dont have permission");
		return Plugin_Handled;
	}
	
	char m_szTmp[64];
	GetCmdArg(2, STRING(m_szTmp));
	
	int m_iCredits = StringToInt(m_szTmp);

	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));

	int m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			char m_szQuery[512];
			if(g_bMySQL)
				Format(STRING(m_szQuery), "INSERT IGNORE INTO store_players (authid, credits) VALUES (\"%s\", %d) ON DUPLICATE KEY UPDATE credits=credits+%d", m_szTmp[8], m_iCredits, m_iCredits);
			else
			{
				Format(STRING(m_szQuery), "INSERT OR IGNORE INTO store_players (authid) VALUES (\"%s\")", m_szTmp[8]);
				SQL_TVoid(g_hDatabase, m_szQuery);
				Format(STRING(m_szQuery), "UPDATE store_players SET credits=credits+%d WHERE authid=\"%s\"", m_iCredits, m_szTmp[8]);
			}
			SQL_TVoid(g_hDatabase, m_szQuery);
			ChatAll("%t", "Credits Given", m_szTmp[8], m_iCredits);
			m_iReceiver = -1;
		}
	} else if(strcmp(m_szTmp, "@all")==0)
	{
		LoopIngamePlayers(i)
			FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
	} else if(strcmp(m_szTmp, "@t")==0 || strcmp(m_szTmp, "@red")==0)
	{
		LoopIngamePlayers(i)
			if(GetClientTeam(i)==2)
				FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
	} else if(strcmp(m_szTmp, "@ct")==0 || strcmp(m_szTmp, "@blu")==0)
	{
		LoopIngamePlayers(i)
			if(GetClientTeam(i)==3)
				FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
	}
	else
	{
		int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_clients>2)
		{
			if(client)
				Chat(client, "%t", "Credit Too Many Matches");
			else
				ReplyToCommand(client, "%t", "Credit Too Many Matches");
			return Plugin_Handled;
		} else if(m_clients != 1)
		{
			if(client)
				Chat(client, "%t", "Credit No Match");
			else
				ReplyToCommand(client, "%t", "Credit No Match");
			return Plugin_Handled;
		}

		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		g_eClients[m_iReceiver].iCredits += m_iCredits;
		if(g_eCvars[g_cvarSilent].aCache == 1)
		{
			if(client)
				Chat(client, "%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			else
				ReplyToCommand(client, "%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			Chat(m_iReceiver, "%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
		}
		else if(g_eCvars[g_cvarSilent].aCache == 0)
			ChatAll("%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
		Store_LogMessage(m_iReceiver, m_iCredits, "Given by Admin");
		
		Store_SaveClientData(m_iReceiver);
		Store_SaveClientInventory(m_iReceiver);
		Store_SaveClientEquipment(m_iReceiver);
	}
	
	
	return Plugin_Handled;
}

public Action Command_ResetPlayer(int client,int params)
{
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarAdminFlag].aCache))
	{
		Chat(client, "%t", "You dont have permission");
		return Plugin_Handled;
	}

	char m_szTmp[64];
	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));

	int m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			char m_szQuery[512];
			Format(STRING(m_szQuery), "SELECT id, authid FROM store_players WHERE authid=\"%s\"", m_szTmp[9]);
			SQL_TQuery(g_hDatabase, SQLCallback_ResetPlayer, m_szQuery, g_eClients[client].iUserId);
		}
	}
	else
	{	
		int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_clients>2)
		{
			Chat(client, "%t", "Credit Too Many Matches");
			return Plugin_Handled;
		}
		
		if(m_clients != 1)
		{
			Chat(client, "%t", "Credit No Match");
			return Plugin_Handled;
		}

		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		Store_LogMessage(client, -g_eClients[m_iReceiver].iCredits, "Player resetted");
		g_eClients[m_iReceiver].iCredits = 0;
		for(int i=0;i<g_eClients[m_iReceiver].iItems;++i)
			Store_RemoveItem(m_iReceiver, g_eClientItems[m_iReceiver][i].iUniqueId);
		ChatAll("%t", "Player Resetted", g_eClients[m_iReceiver].szName_Client);
	}
	
	return Plugin_Handled;
}

public Action Command_Credits(int client,int params)
{	
	if(g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1)
	{
		Chat(client, "%t", "Inventory hasnt been fetched");
		return Plugin_Handled;
	}

	if(g_iSpam[client]<GetTime())
	{
		//CPrintToChatAll("%t", "Player Credits", g_eClients[client][szName_Client], g_eClients[client][iCredits]);
		ChatAll("%t", "Player Credits", g_eClients[client].szName_Client, g_eClients[client].iCredits);
		g_iSpam[client] = GetTime()+12;
		//g_iSpam[client] = GetTime()+ g_cvarCredits.FloatValue;
	}
	
	return Plugin_Handled;
}

public Action Command_CustomCredits(int params)
{
	if(params < 2)
	{
		PrintToServer("sm_store_custom_credits [flag] [multiplier]");
		return Plugin_Handled;
	}

	char tmp[16];
	GetCmdArg(1, STRING(tmp));
	char flag = ReadFlagString(tmp);
	GetCmdArg(2, STRING(tmp));
	float mult = StringToFloat(tmp);

	any size = GetArraySize(g_hCustomCredits);
	int index = -1;
	for(int i=0;i<size;++i)
	{
		int sflag = GetArrayCell(g_hCustomCredits, i, 0);
		if(sflag == flag)
		{
			index = i;
			break;
		}
	}

	if(index == -1)
	{
		index = PushArrayCell(g_hCustomCredits, flag);
	}

	SetArrayCell(g_hCustomCredits, index, mult, 1);

	return Plugin_Handled;
}


//////////////////////////////
//			MENUS	 		//
//////////////////////////////

void DisplayStoreMenu(int client,int parent=-1,int last=-1)
{
	if(!client || !IsClientInGame(client))
		return;

	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];

	Handle m_hMenu = CreateMenu(MenuHandler_Store);
	if(parent!=-1)
	{
		SetMenuExitBackButton(m_hMenu, true);
		if(client == target)
		{
			if (g_eCvars[gc_iDescription].aCache > 1)
			{
				SetMenuTitle(m_hMenu, "%s\n%s\n%t", g_eItems[parent].szName, g_eItems[parent].szDescription, "Title Credits", g_eClients[target].iCredits);
			}
			else SetMenuTitle(m_hMenu, "%s\n%t", g_eItems[parent].szName, "Title Credits", g_eClients[target].iCredits);
		}
		else
			SetMenuTitle(m_hMenu, "%N\n%s\n%t", target, g_eItems[parent].szName, "Title Credits", g_eClients[target].iCredits);
		g_iMenuBack[client] = g_eItems[parent].iParent;
	}
	else if(client == target)
		SetMenuTitle(m_hMenu, "%t\n%t", "Title Store", "Title Credits", g_eClients[target].iCredits);
	else
		SetMenuTitle(m_hMenu, "%N\n%t\n%t", target, "Title Store", "Title Credits", g_eClients[target].iCredits);
	
	char m_szId[11];
	int m_iFlags = GetUserFlagBits(target);
	int m_iPosition = 0;
	
	g_iSelectedItem[client] = parent;
	if(parent != -1)
	{
		if(g_eItems[parent].iPrice>0)
		{
			if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, parent))
			{
				if(g_eCvars[g_cvarSellEnabled].aCache)
				{
					AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "sell_package", "%t", "Package Sell", RoundToFloor(g_eItems[parent].iPrice*view_as<float>(g_eCvars[g_cvarSellRatio].aCache)));
					++m_iPosition;
				}
				if(g_eCvars[g_cvarGiftEnabled].aCache == 1 || (g_eCvars[g_cvarGiftEnabled].aCache == 2 && GetUserFlagBits(client) & g_eCvars[g_cvarAdminFlag].aCache))
				{
					AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "gift_package", "%t", "Package Gift");
					++m_iPosition;
				}

				for(int i=0;i<g_iMenuHandlers;++i)
				{
					if(g_eMenuHandlers[i].hPlugin_Handler == INVALID_HANDLE)
						continue;
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnMenu);
					Call_PushCellRef(m_hMenu);
					Call_PushCell(client);
					Call_PushCell(parent);
					Call_Finish();
				}
			}
		}
	}
	
	for(int i=0;i<g_iItems;++i)
	{
		if(g_eItems[i].iParent==parent && (g_eCvars[g_cvarShowVIP].aCache == 0 && GetClientPrivilege(target, g_eItems[i].iFlagBits, m_iFlags) || g_eCvars[g_cvarShowVIP].aCache))
		{
			int m_iPrice = Store_GetLowestPrice(i);
			//bool reduced = false;

			// This is a package
			if(g_eItems[i].iHandler == g_iPackageHandler)
			{
				if(!Store_PackageHasClientItem(target, i, g_bInvMode[client]))
					continue;

				int m_iStyle = ITEMDRAW_DEFAULT;
				//if(g_eCvars[g_cvarShowVIP].aCache && !GetClientPrivilege(target, g_eItems[i][iFlagBits], m_iFlags) || !CheckSteamAuth(target, g_eItems[i][szSteam]))
				//	m_iStyle = ITEMDRAW_DISABLED;
				//if(!g_eItems[i][bBuyable])
				//	m_iStyle = ITEMDRAW_DISABLED;
				char sBuffer[256];
				IntToString(i, STRING(m_szId));
				if(g_eItems[i].iPrice == -1 || Store_HasClientItem(target, i))
				{
					if (g_eCvars[gc_iDescription].aCache < 3)
					{
						Format(sBuffer, sizeof(sBuffer), "%s\n%s", g_eItems[i].szName, g_eItems[i].szDescription);
					}
					else Format(sBuffer, sizeof(sBuffer), "%s", g_eItems[i].szName);
					
					AddMenuItem(m_hMenu, m_szId, sBuffer, m_iStyle);
					
					//AddMenuItem(m_hMenu, m_szId, g_eItems[i][szName], m_iStyle);
				}
				else if(!g_bInvMode[client] && g_eItems[i].iPlans==0 /*&& g_eItems[i][bBuyable]*/)
					InsertMenuItemEx(m_hMenu, m_iPosition, (m_iPrice<=g_eClients[target].iCredits?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED), m_szId, "%t", "Item Available", g_eItems[i].szName, g_eItems[i].iPrice);
				else if(!g_bInvMode[client])
					InsertMenuItemEx(m_hMenu, m_iPosition, (m_iPrice<=g_eClients[target].iCredits?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED), m_szId, "%t", "Item Plan Available", g_eItems[i].szName);
				++m_iPosition;
			}
			// This is a normal item
			else
			{
				IntToString(i, STRING(m_szId));
				if(Store_HasClientItem(target, i))
				{
					if(Store_IsEquipped(target, i))
						InsertMenuItemEx(m_hMenu, m_iPosition, ITEMDRAW_DEFAULT, m_szId, "%t", "Item Equipped", g_eItems[i].szName);
					else
						InsertMenuItemEx(m_hMenu, m_iPosition, ITEMDRAW_DEFAULT, m_szId, "%t", "Item Bought", g_eItems[i].szName);
				}
				else if(!g_bInvMode[client] /*&& g_eItems[i][bBuyable]*/)
				{				
					int m_iStyle = ITEMDRAW_DEFAULT;
					//if((g_eItems[i][iPlans]==0 && g_eClients[target][iCredits]<m_iPrice && !g_eItems[i][bPreview]) || (g_eCvars[g_cvarShowVIP].aCache && !GetClientPrivilege(target, g_eItems[i][iFlagBits], m_iFlags) || !CheckSteamAuth(target, g_eItems[i][szSteam])))
					//	m_iStyle = ITEMDRAW_DISABLED;
					
					if((!g_eItems[i].bPreview) && (g_eCvars[g_cvarShowVIP].aCache && !GetClientPrivilege(target, g_eItems[i].iFlagBits, m_iFlags) || !CheckSteamAuth(target, g_eItems[i].szSteam)))
						m_iStyle = ITEMDRAW_DISABLED;
					
					if(!g_eItems[i].bBuyable && !g_eItems[i].bPreview)
						m_iStyle = ITEMDRAW_DISABLED;
						
					if(!g_eItems[i].bPreview && g_eClients[target].iCredits<m_iPrice && g_eItems[i].iPlans==0)
						m_iStyle = ITEMDRAW_DISABLED;

					if(g_eItems[i].iPlans==0)
					{
						if (g_eCvars[gc_iDescription].aCache < 3)
						{
							AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t\n%s", "Item Available", g_eItems[i].szName, g_eItems[i].iPrice, g_eItems[i].szDescription);
						}
						else AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t", "Item Available", g_eItems[i].szName, g_eItems[i].iPrice);
					}
					else
					{
						if (g_eCvars[gc_iDescription].aCache < 3)
						{
							AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t\n%s", "Item Plan Available", g_eItems[i].szName, g_eItems[i].szDescription);
						}
						else AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t", "Item Plan Available", g_eItems[i].szName);
					}
				}
			}
		}
	}
	
	if(last == -1)
		DisplayMenu(m_hMenu, client, 0);
	else
		DisplayMenuAtItem(m_hMenu, client, (last/GetMenuPagination(m_hMenu))*GetMenuPagination(m_hMenu), 0);
}

public int MenuHandler_Store(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		int target = g_iMenuClient[client];
		// Confirmation was given
		if(menu == INVALID_HANDLE)
		{
			if(param2 == 0)
			{
				g_iMenuBack[client]=1;
				int m_iPrice = 0;
				if(g_iSelectedPlan[client]==-1)
					m_iPrice = g_eItems[g_iSelectedItem[client]].iPrice;
				else
					m_iPrice = g_ePlans[g_iSelectedItem[client]][g_iSelectedPlan[client]].iPrice_Plan;

				if(g_eClients[target].iCredits>=m_iPrice && !Store_HasClientItem(target, g_iSelectedItem[client]))
					Store_BuyItem(target, g_iSelectedItem[client], g_iSelectedPlan[client]);

				if(g_eItems[g_iSelectedItem[client]].iHandler == g_iPackageHandler)
					DisplayStoreMenu(client, g_iSelectedItem[client]);
				else
					DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			else if(param2 == 1)
			{
				Store_SellItem(target, g_iSelectedItem[client]);
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			char m_szId[64];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			g_iLastSelection[client]=param2;
			
			// We are selling a package
			if(strcmp(m_szId, "sell_package")==0)
			{
				if(g_eCvars[g_cvarConfirmation].aCache)
				{
					char m_szTitle[128];
					Format(STRING(m_szTitle), "%t", "Confirm_Sell", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType, RoundToFloor(g_eItems[g_iSelectedItem[client]].iPrice*view_as<float>(g_eCvars[g_cvarSellRatio].aCache)));
					Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Store, 1);
					return;
				}
				else
				{
					Store_SellItem(target, g_iSelectedItem[client]);
					Store_DisplayPreviousMenu(client);
				}
			}
			// We are gifting a package
			else if(strcmp(m_szId, "gift_package")==0)
			{
				DisplayPlayerMenu(client);
			}
			// This is menu handler stuff
			else if(!(48 <= m_szId[0] <= 57))
			{
				any ret;
				for(int i=0;i<g_iMenuHandlers;++i)
				{
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnHandler);
					Call_PushCell(target);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
			// We are being boring
			else
			{
				int m_iId = StringToInt(m_szId);
				g_iMenuBack[client]=g_eItems[m_iId].iParent;
				g_iSelectedItem[client] = m_iId;
				g_iSelectedPlan[client] = -1;
				
				if (g_eItems[m_iId].bPreview && !Store_HasClientItem(target, m_iId) && g_eItems[m_iId].iPrice != -1 && g_eItems[m_iId].iPlans == 0)
				{
					DisplayPreviewMenu(client, m_iId);
					return;
				}
				else 
				//if((g_eClients[target][iCredits]>=g_eItems[m_iId][iPrice] || g_eItems[m_iId][iPlans]>0 && g_eClients[target][iCredits]>=Store_GetLowestPrice(m_iId)) && !Store_HasClientItem(target, m_iId) && g_eItems[m_iId][iPrice] != -1)				
				//if((g_eClients[target][iCredits]>=g_eItems[m_iId][iPrice] || g_eItems[m_iId][iPlans]>0) && !Store_HasClientItem(target, m_iId) && g_eItems[m_iId][iPrice] != -1)				
				if((g_eClients[target].iCredits>=g_eItems[m_iId].iPrice || g_eItems[m_iId].iPlans>0 && g_eClients[target].iCredits>=Store_GetLowestPrice(m_iId)) && !Store_HasClientItem(target, m_iId) && g_eItems[m_iId].iPrice != -1)				
				{
					if(g_eItems[m_iId].iPlans > 0)
					{
						DisplayPlanMenu(client, m_iId);
						return;
					}
					else
						if(g_eCvars[g_cvarConfirmation].aCache)
						{
							char m_szTitle[128];
							Format(STRING(m_szTitle), "%t", "Confirm_Buy", g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
							Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Store, 0);
							return;
						}
						else
							Store_BuyItem(target, m_iId);
				}
				
				if(g_eItems[m_iId].iHandler != g_iPackageHandler)
				{				
					if(Store_HasClientItem(target, m_iId))
					{
						if(g_eTypeHandlers[g_eItems[m_iId].iHandler].bRaw)
						{
							Call_StartFunction(g_eTypeHandlers[g_eItems[m_iId].iHandler].hPlugin, g_eTypeHandlers[g_eItems[m_iId].iHandler].fnUse);
							Call_PushCell(target);
							Call_PushCell(m_iId);
							Call_Finish();
						}
						else
							DisplayItemMenu(client, m_iId);
					}
					else
						DisplayStoreMenu(client, g_iMenuBack[client]);					
				}
				else
				{			
					if(Store_HasClientItem(target, m_iId) || g_eItems[m_iId].iPrice == -1)
						DisplayStoreMenu(client, m_iId);
					else
						DisplayStoreMenu(client, g_eItems[m_iId].iParent);
				}
			}
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Store_DisplayPreviousMenu(client);
}

public void DisplayItemMenu(int client,int itemid)
{
	g_iMenuNum[client] = 1;
	g_iMenuBack[client] = g_eItems[itemid].iParent;
	int target = g_iMenuClient[client];

	Handle m_hMenu = CreateMenu(MenuHandler_Item);
	SetMenuExitBackButton(m_hMenu, true);
	
	bool m_bEquipped = Store_IsEquipped(target, itemid);
	char m_szTitle[256];
	int idx = 0;
	if(m_bEquipped)
	{
		if (g_eCvars[gc_iDescription].aCache > 1)
		{
			idx = Format(STRING(m_szTitle), "%t\n%s\n%t", "Item Equipped", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
		}
		else idx = Format(STRING(m_szTitle), "%t\n%t", "Item Equipped", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);
	}
	else
	{
		if (g_eCvars[gc_iDescription].aCache > 1)
		{
			idx = Format(STRING(m_szTitle), "%s\n%s\n%t", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
		}
		else idx = Format(STRING(m_szTitle), "%s\n%t", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);
	}
	
	int m_iExpiration = Store_GetExpiration(target, itemid);
	if(m_iExpiration != 0)
	{
		m_iExpiration = m_iExpiration-GetTime();
		int m_iDays = m_iExpiration/(24*60*60);
		int m_iHours = (m_iExpiration-m_iDays*24*60*60)/(60*60);
		Format(m_szTitle[idx-1], sizeof(m_szTitle)-idx-1, "\n%t", "Title Expiration", m_iDays, m_iHours);
	}
	
	SetMenuTitle(m_hMenu, m_szTitle);
	
	if(g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
	{
		if(!m_bEquipped)
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "0", "%t", "Item Equip");
		else
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "3", "%t", "Item Unequip");
	}
	else
	{
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "0", "%t", "Item Use");
	}
	//
	if (g_eItems[itemid].bPreview)
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "4", "%t", "Preview Item");
		
	if(/*!Store_IsClientVIP(target) && */!Store_IsItemInBoughtPackage(target, itemid))
	{
		int m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, itemid)*view_as<float>(g_eCvars[g_cvarSellRatio].aCache));
		if(m_iCredits!=0)
		{
			int uid = Store_GetClientItemId(client, itemid);
			if(g_eClientItems[client][uid].iDateOfExpiration != 0)
			{
				int m_iLength = g_eClientItems[client][uid].iDateOfExpiration-g_eClientItems[client][uid].iDateOfPurchase;
				int m_iLeft = g_eClientItems[client][uid].iDateOfExpiration-GetTime();
				if(m_iLeft < 0)
					m_iLeft = 0;
				m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
			}

			if(g_eCvars[g_cvarSellEnabled].aCache)
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "1", "%t", "Item Sell", m_iCredits);
			if(g_eCvars[g_cvarGiftEnabled].aCache == 1 || (g_eCvars[g_cvarGiftEnabled].aCache == 2 && GetUserFlagBits(client) & g_eCvars[g_cvarAdminFlag].aCache))
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "2", "%t", "Item Gift");
		}
	}

	for(int i=0;i<g_iMenuHandlers;++i)
	{
		if(g_eMenuHandlers[i].hPlugin_Handler == INVALID_HANDLE)
			continue;
		Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnMenu);
		Call_PushCellRef(m_hMenu);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}
	
	DisplayMenu(m_hMenu, client, 0);
}

public void DisplayPreviewMenu(int client, int itemid)
{
	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];
	int m_iFlags = GetUserFlagBits(target);
	Handle m_hMenu = CreateMenu(MenuHandler_Item);
	Menu menu = new Menu(MenuHandler_Preview);
	menu.ExitBackButton = true;
	
	bool m_bEquipped = Store_IsEquipped(target, itemid);

	if(g_eCvars[gc_iDescription].aCache > 1)
	{
		menu.SetTitle("%s\n%s\n%t", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
	}
	else
	{
		menu.SetTitle("%s\n%t", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);
	}

	char sBuffer[128];

	if (Store_HasClientItem(client, itemid))
	{
		if(g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
		if(!m_bEquipped)
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "0", "%t", "Item Equip");
		else
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "3", "%t", "Item Unequip");
		else
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "0", "%t", "Item Use");
	}
	// Player don't own the item
	else if (!g_bInvMode[client] && !Store_HasClientItem(target, itemid))
	{
		//new String:m_szId[64];
		//new m_iId = StringToInt(m_szId);
					
		int iStyle = ITEMDRAW_DEFAULT;
		//if ((g_eClients[target][iCredits]<g_eItems[itemid][iPrice]) && !GetClientPrivilege(target, g_eItems[itemid][iFlagBits], m_iFlags) || !CheckSteamAuth(target, g_eItems[itemid][szSteam]))
		if (g_eClients[target].iCredits<g_eItems[itemid].iPrice)
		{
			iStyle = ITEMDRAW_DISABLED;
		}
		
		if(!GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags))
		{
			iStyle = ITEMDRAW_DISABLED;
		}
		
		if(!CheckSteamAuth(target, g_eItems[itemid].szSteam))
		{
			iStyle = ITEMDRAW_DISABLED;
		}

		// Player can buy the item as normal trade in
		/*
		if (g_eItems[itemid][iPlans]==0)
		{
			if (!GetClientPrivilege(target, g_eItems[itemid][iFlagBits], m_iFlags) || !CheckSteamAuth(target, g_eItems[itemid][szSteam]))
			{
				Format(sBuffer, sizeof(sBuffer), "%t %t", "Buy Item", price, reduced ? "discount" : "nodiscount");
				menu.AddItem("buy_item", sBuffer, ITEMDRAW_DISABLED);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%t %t", "Buy Item", price, reduced ? "discount" : "nodiscount");
				menu.AddItem("buy_item", sBuffer, ITEMDRAW_DISABLED);
			}
		}
		*/
		
		if (g_eItems[itemid].iPlans==0)
		{
			if (!GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) || !CheckSteamAuth(target, g_eItems[itemid].szSteam) || !g_eItems[itemid].bBuyable)
			{
				iStyle = ITEMDRAW_DISABLED;
			}
			Format(sBuffer, sizeof(sBuffer), "%t", "Buy Item", g_eItems[itemid].iPrice);
			menu.AddItem("buy_item", sBuffer, iStyle);
		}
		// Player can buy the item in a plan
		else
		{
			//Format(sBuffer, sizeof(sBuffer), "%t", "Choose Plan", g_eItems[itemid][szName]);
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Plan Available", g_eItems[itemid].szName);
			menu.AddItem("item_plan", sBuffer, iStyle);
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%t", "Preview Item");
	menu.AddItem("preview_item", sBuffer, ITEMDRAW_DEFAULT);
	
	for(int i=0;i<g_iMenuHandlers;++i)
	{
		if(g_eMenuHandlers[i].hPlugin_Handler == INVALID_HANDLE)
			continue;
		Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnMenu);
		Call_PushCellRef(m_hMenu);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Preview(Menu menu, MenuAction action, int client, int param2)
{
	char m_szId[64];
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char sId[24];
		menu.GetItem(param2, sId, sizeof(sId));
		int itemid = g_iSelectedItem[client];

		if (strcmp(sId, "buy_item") == 0)
		{
			if (g_eCvars[g_cvarConfirmation].aCache)
			{
				char sTitle[128];
				//g_eItems[g_iSelectedItem[client]][szName], g_eTypeHandlers[g_eItems[g_iSelectedItem[client]][iHandler]][szType]
				Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType);
				Store_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
				return;
			}
			else
			{
				Store_BuyItem(client, g_iSelectedItem[client], itemid);
				//BuyItem(client, itemid);
				DisplayPreviewMenu(client, itemid);
			}
		}
		else if (strcmp(sId, "item_plan") == 0)
		{
			DisplayPlanMenu(client, itemid);
		}
		else if (strcmp(sId, "item_use") == 0)
		{
			any bRet = Store_UseItem(client, g_iSelectedItem[client]);
			if (GetClientMenu(client) == MenuSource_None && bRet)
			{
				//g_eTypeHandlers[g_eItems[itemid][iHandler]][bEquipable]
				if (g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
				{
					if (g_eItems[g_iSelectedItem[client]].bPreview)
					{
						DisplayPreviewMenu(client, g_iSelectedItem[client]);
					}
					else
					{
						DisplayItemMenu(client, g_iSelectedItem[client]);
					}
				}
			}
		}
		else if (strcmp(sId, "item_unequipped") == 0)
		{
			Store_UnequipItem(client, itemid);
			if (g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
			{
				DisplayPreviewMenu(client, g_iSelectedItem[client]);
			}
			else
			{
				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
		}
		else if (strcmp(sId, "preview_item") == 0)
		{
			//if (g_iSpam[client] > GetTime())
			//{
			//	CPrintToChat(client, "%s%t", " {yellow}♛ J1BroS Store ♛ {default}", "Spam Cooldown", g_iSpam[client] - GetTime());
			//	DisplayPreviewMenu(client, itemid);
			//	return;
			//}

			if (!IsPlayerAlive(client))
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
				DisplayPreviewMenu(client, itemid);
				return;
			}
			if (g_eCvars[g_cvarPreview].aCache)
			{
				Call_StartForward(gf_hPreviewItem);
				Call_PushCell(client);
				Call_PushString(g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
				Call_PushCell(g_eItems[itemid].iData);
				Call_Finish();
				DisplayPreviewMenu(client, itemid);
			//g_iSpam[client] = GetTime() + 10;
			}
			else
			{
				CPrintToChat(client, "%s%s", g_sChatPrefix, " Preview disabled");
				DisplayPreviewMenu(client, itemid);
			}
		}
		else /*if (!(48 <= sId[0] <= 57))
		{
			bool ret;
			for (int i = 0; i < g_iItemHandlers; i++)
			{
				Call_StartFunction(g_hItemPlugin[i], g_fnItemHandler[i]);
				Call_PushCell(client);
				Call_PushString(sId);
				Call_PushCell(g_iSelectedItem[client]);
				Call_Finish(ret);

				if (ret)
					break;
			}
		}*/
		if(!(48 <= m_szId[0] <= 57))
			{
				any ret;
				for(int i=0;i<g_iMenuHandlers;++i)
				{
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnHandler);
					Call_PushCell(client);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
}

public void DisplayPlanMenu(int client, int itemid)
{
	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];
	int m_iFlags = GetUserFlagBits(target);
	
	Menu menu = new Menu(MenuHandler_Plan);
	menu.ExitBackButton = true;

	if (g_eCvars[gc_iDescription].aCache > 1)
	{
		menu.SetTitle("%s\n%s\n%t", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
	}
	else menu.SetTitle("%s\n%t", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);

	char sBuffer[64];
	if (g_eItems[itemid].bPreview)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Preview Item");
		menu.AddItem("preview", sBuffer, ITEMDRAW_DEFAULT);
	}

	for (int i = 0; i < g_eItems[itemid].iPlans; ++i)
	{
		if(!CheckSteamAuth(target, g_eItems[itemid].szSteam))
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
		}
		else if (GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) || g_eItems[itemid].szSteam[0])
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, (g_eClients[target].iCredits>=g_ePlans[itemid][i].iPrice_Plan)? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		else if (!g_eItems[itemid].bBuyable)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Plan(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		int target = g_iMenuClient[client];
		g_iMenuNum[client] = 5;

		char sId[24];
		menu.GetItem(param2, sId, sizeof(sId));
		int itemid = g_iSelectedItem[client];

		if (strcmp(sId, "preview") == 0)
		{
			//if (g_iSpam[client] < GetTime())
			//{
			if (g_eCvars[g_cvarPreview].aCache)
			{
				Call_StartForward(gf_hPreviewItem);
				Call_PushCell(client);
				Call_PushString(g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
				Call_PushCell(g_eItems[itemid].iData);
				Call_Finish();
				DisplayPlanMenu(client, itemid);
			}
				//g_iSpam[client] = GetTime() + 10;
			//}
			//else
			//{
			//	CPrintToChat(client, "%s%t", " {yellow}♛ J1BroS Store ♛ {default}", "Spam Cooldown", g_iSpam[client] - GetTime());
			//}
			else 
			{
				CPrintToChat(client, "%s%s", g_sChatPrefix, " Preview disabled");
				DisplayPlanMenu(client, itemid);
			}
			return;
		}

		g_iSelectedPlan[client] = param2;

		if (g_eItems[g_iSelectedItem[client]].bPreview)
		{
			g_iSelectedPlan[client]--;
		}

		if (g_eCvars[g_cvarConfirmation].aCache)
		{
			char sTitle[128];
			Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType);
			Store_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
		}
		else
		{
			Store_BuyItem(target, g_iSelectedItem[client], g_iSelectedPlan[client]);
			DisplayItemMenu(client, g_iSelectedItem[client]);
		}
		
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
}

public int MenuHandler_Item(Handle menu, MenuAction action,int client,int param2)
{
		
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		int itemid = g_iSelectedItem[client];
		int target = g_iMenuClient[client];
		// Confirmation was sent
		if(menu == INVALID_HANDLE)
		{
			if(param2 == 0)
			{
				g_iMenuNum[client] = 1;
				Store_SellItem(target, g_iSelectedItem[client]);
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			char m_szId[64];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			int m_iId = StringToInt(m_szId);
			
			// Menu handlers
			if(!(48 <= m_szId[0] <= 57))
			{
				any ret;
				for(int i=0;i<g_iMenuHandlers;++i)
				{
					if(g_eMenuHandlers[i].hPlugin_Handler == INVALID_HANDLE)
						continue;
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnHandler);
					Call_PushCell(client);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
			// Player wants to equip this item
			else if(m_iId == 0)
			{
				int m_iRet = Store_UseItem(target, g_iSelectedItem[client]);
				if(GetClientMenu(client)==MenuSource_None && m_iRet == 0)
					DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			// Player wants to sell this item
			else if(m_iId == 1)
			{
				if(g_eCvars[g_cvarConfirmation].aCache)
				{
					int m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, g_iSelectedItem[client])*view_as<float>(g_eCvars[g_cvarSellRatio].aCache));
					int uid = Store_GetClientItemId(client, g_iSelectedItem[client]);
					if(g_eClientItems[client][uid].iDateOfExpiration != 0)
					{
						int m_iLength = g_eClientItems[client][uid].iDateOfExpiration-g_eClientItems[client][uid].iDateOfPurchase;
						int m_iLeft = g_eClientItems[client][uid].iDateOfExpiration-GetTime();
						if(m_iLeft < 0)
							m_iLeft = 0;
						m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
					}

					char m_szTitle[128];
					Format(STRING(m_szTitle), "%t", "Confirm_Sell", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType, m_iCredits);
					g_iMenuNum[client] = 2;
					Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Item, 0);
				}
				else
				{
					Store_SellItem(target, g_iSelectedItem[client]);
					Store_DisplayPreviousMenu(client);
				}
			}
			// Player wants to gift this item
			else if(m_iId == 2)
			{
				g_iMenuNum[client] = 2;
				DisplayPlayerMenu(client);
			}
			// Player wants to unequip this item
			else if(m_iId == 3)
			{
				Store_UnequipItem(target, g_iSelectedItem[client]);
				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			else if(m_iId == 4)
			{
				//if (g_iSpam[client] < GetTime())
				//{
				if (g_eCvars[g_cvarPreview].aCache)
				{
					Call_StartForward(gf_hPreviewItem);
					Call_PushCell(client);
					Call_PushString(g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
					Call_PushCell(g_eItems[itemid].iData);
					Call_Finish();
					DisplayItemMenu(client, g_iSelectedItem[client]);
				}
				//	g_iSpam[client] = GetTime() + 10;
				//}
				//else
				//{
				//	CPrintToChat(client, "%s%t", " {yellow}♛ J1BroS Store ♛ {default}", "Spam Cooldown", g_iSpam[client] - GetTime());
				//}
				else
				{
					CPrintToChat(client, "%s%s", g_sChatPrefix, " Preview disabled");
					DisplayItemMenu(client, g_iSelectedItem[client]);
				}
			}
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Store_DisplayPreviousMenu(client);
}

public void DisplayPlayerMenu(int client)
{
	g_iMenuNum[client] = 3;
	int target = g_iMenuClient[client];

	int m_iCount = 0;
	Handle m_hMenu = CreateMenu(MenuHandler_Gift);
	SetMenuExitBackButton(m_hMenu, true);
	SetMenuTitle(m_hMenu, "%t\n%t", "Title Gift", "Title Credits", g_eClients[client].iCredits);
	
	char m_szID[11];
	int m_iFlags;
	LoopIngamePlayers(i)
	{
		m_iFlags = GetUserFlagBits(i);
		if(!GetClientPrivilege(i, g_eItems[g_iSelectedItem[client]].iFlagBits, m_iFlags))
			continue;
		if(i != target && IsClientInGame(i) && !Store_HasClientItem(i, g_iSelectedItem[client]))
		{
			IntToString(g_eClients[i].iUserId, STRING(m_szID));
			AddMenuItem(m_hMenu, m_szID, g_eClients[i].szName_Client);
			++m_iCount;
		}
	}
	
	if(m_iCount == 0)
	{
		CloseHandle(m_hMenu);
		g_iMenuNum[client] = 1;
		DisplayItemMenu(client, g_iSelectedItem[client]);
		Chat(client, "%t", "Gift No Players");
	}
	else
		DisplayMenu(m_hMenu, client, 0);
}

public int MenuHandler_Gift(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		int m_iItem, m_iReceiver;
		int target = g_iMenuClient[client];
	
		// Confirmation was given
		if(menu == INVALID_HANDLE)
		{
			m_iItem = Store_GetClientItemId(target, g_iSelectedItem[client]);
			m_iReceiver = GetClientOfUserId(param2);
			if(!m_iReceiver)
			{
				Chat(client, "%t", "Gift Player Left");
				return;
			}
			Store_GiftItem(target, m_iReceiver, m_iItem);
			g_iMenuNum[client] = 1;
			Store_DisplayPreviousMenu(client);
		}
		else
		{
			char m_szId[11];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			int m_iId = StringToInt(m_szId);
			m_iReceiver = GetClientOfUserId(m_iId);
			if(!m_iReceiver)
			{
				Chat(client, "%t", "Gift Player Left");
				return;
			}
				
			m_iItem = Store_GetClientItemId(target, g_iSelectedItem[client]);
			
			if(g_eCvars[g_cvarConfirmation].aCache)
			{
				char m_szTitle[128];
				Format(STRING(m_szTitle), "%t", "Confirm_Gift", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType, g_eClients[m_iReceiver].szName_Client);
				Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Gift, m_iId);
				return;
			}
			else
				Store_GiftItem(target, m_iReceiver, m_iItem);
			Store_DisplayPreviousMenu(client);
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			DisplayItemMenu(client, g_iSelectedItem[client]);
}

public int MenuHandler_Confirm(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		if (param2 == 0)
		{
			char sCallback[32];
			char sData[11];
			GetMenuItem(menu, 0, sCallback, sizeof(sCallback));
			GetMenuItem(menu, 1, sData, sizeof(sData));

			DataPack pack = view_as<DataPack>(StringToInt(sCallback));
			Handle m_hPlugin = view_as<Handle>(pack.ReadCell());
			Function fnMenuCallback = pack.ReadCell();
			delete pack;

			if (fnMenuCallback != INVALID_FUNCTION)
			{
				Call_StartFunction(m_hPlugin, fnMenuCallback);
				Call_PushCell(INVALID_HANDLE);
				Call_PushCell(MenuAction_Select);
				Call_PushCell(client);
				Call_PushCell(StringToInt(sData));
				Call_Finish();
			}
			else
			{
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			Store_DisplayPreviousMenu(client);
		}
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

//////////////////////////////
//			TIMERS	 		//
//////////////////////////////
public int GetMultipliedCredits(int client,int amount)
{
	int flags = GetUserFlagBits(client);
	int size = GetArraySize(g_hCustomCredits);
	float multiplier = 1.0;
	for(int i=0;i<size;++i)
	{
		if(GetClientPrivilege(client, GetArrayCell(g_hCustomCredits, i, 0), flags))
		{
			float mul = GetArrayCell(g_hCustomCredits, i, 1);

			if(multiplier < mul)
				multiplier = mul;
		}
	}

	return RoundFloat(amount * multiplier);
}

public Action Timer_CreditTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	int m_iCredits;

	//if(2<=GetClientTeam(client)<=3)
	int team = GetClientTeam(client);
	if(2<=team<=3)
		m_iCredits = g_eCvars[g_cvarCreditAmountActive].aCache;
	else
		m_iCredits = g_eCvars[g_cvarCreditAmountInactive].aCache;
		
	m_iCredits = GetMultipliedCredits(client, m_iCredits);

	if(m_iCredits)
	{
		g_eClients[client].iCredits += m_iCredits;
		if(g_eCvars[g_cvarCreditMessages].aCache)
			Chat(client, "%t", "Credits Earned For Playing", m_iCredits);
		Store_LogMessage(client, m_iCredits, "Earned for playing");
	}

	return Plugin_Continue;
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

//////////////////////////////
//		SQL CALLBACKS		//
//////////////////////////////

public void SQLCallback_Connect(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl==INVALID_HANDLE)
	{
		SetFailState("Failed to connect to SQL database. Error: %s", error);
	}
	else
	{
		// If it's already connected we are good to go
		if(g_hDatabase != INVALID_HANDLE)
			return;
			
		g_hDatabase = hndl;
		char m_szDriver[2];
		SQL_ReadDriver(g_hDatabase, STRING(m_szDriver));
		if(m_szDriver[0] == 'm')
		{
			g_bMySQL = true;
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_players` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `authid` varchar(32) NOT NULL,\
										  `name` varchar(64) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `date_of_join` int(11) NOT NULL,\
										  `date_of_last_join` int(11) NOT NULL,\
										  PRIMARY KEY (`id`),\
										  UNIQUE KEY `id` (`id`),\
										  UNIQUE KEY `authid` (`authid`)\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_items` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `date_of_purchase` int(11) NOT NULL,\
										  `date_of_expiration` int(11) NOT NULL,\
										  PRIMARY KEY (`id`)\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_equipment` (\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `slot` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_logs` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `reason` varchar(256) NOT NULL,\
										  `date` timestamp NOT NULL,\
										  PRIMARY KEY (`id`)\
										)");

			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_plugin_logs` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `level` varchar(8) NOT NULL,\
										   name varchar(64) NOT NULL default '',\
										   steam varchar(64) NOT NULL default '',\
										  `player_id` int(11) NOT NULL,\
										  `reason` varchar(256) NOT NULL,\
										  `date` timestamp NOT NULL,\
										  PRIMARY KEY (`id`),\
										  UNIQUE KEY `id` (`id`)\
										)");

			/*SQL_TVoid(g_hDatabase, "CREATE TABLE if NOT EXISTS store_voucher (\
										  voucher varchar(64) NOT NULL PRIMARY KEY default '',\
										  name_of_create varchar(64) NOT NULL default '',\
										  steam_of_create varchar(64) NOT NULL default '',\
										  credits INT NOT NULL default 0,\
										  item varchar(64) NOT NULL default '',\
										  date_of_create INT NOT NULL default 0,\
										  date_of_redeem INT NOT NULL default 0,\
										  name_of_redeem varchar(64) NOT NULL default '',\
										  steam_of_redeem TEXT NOT NULL,\
										  unlimited TINYINT NOT NULL default 0,\
										  date_of_expiration INT NOT NULL default 0,\
										  item_expiration INT default NULL);"
										  );*/

			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_items ADD COLUMN price_of_purchase int(11)");
			// Edit exist date column
			SQL_TQuery(g_hDatabase, SQLCallback_CheckError, "ALTER TABLE store_logs MODIFY COLUMN date TIMESTAMP NOT NULL");
			char m_szQuery[512];
			Format(STRING(m_szQuery), "CREATE TABLE IF NOT EXISTS `%s` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `parent_id` int(11) NOT NULL DEFAULT '-1',\
										  `item_price` int(32) NOT NULL,\
										  `item_type` varchar(64) NOT NULL,\
										  `item_flag` varchar(64) NOT NULL,\
										  `item_name` varchar(64) NOT NULL,\
										  `additional_info` text NOT NULL,\
										  `item_status` tinyint(1) NOT NULL,\
										  `supported_game` varchar(64) NOT NULL,\
										  PRIMARY KEY (`id`)\
										)", g_eCvars[g_cvarItemsTable].sCache);
			SQL_TVoid(g_hDatabase, m_szQuery);
		}
		else
		{
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_players` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `authid` varchar(32) NOT NULL,\
										  `name` varchar(64) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `date_of_join` int(11) NOT NULL,\
										  `date_of_last_join` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_items` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `date_of_purchase` int(11) NOT NULL,\
										  `date_of_expiration` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_equipment` (\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `slot` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_plugin_logs` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `level` varchar(8) NOT NULL,\
										   name varchar(64) NOT NULL default '',\
										   steam varchar(64) NOT NULL default '',\
										  `player_id` int(11) NOT NULL,\
										  `reason` varchar(256) NOT NULL,\
										  `date` timestamp NOT NULL\
										)");	
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_items ADD COLUMN price_of_purchase int(11)");
			if(strcmp(g_eCvars[g_cvarItemSource].sCache, "database")==0)
			{
	
				SetFailState("Database item source can only be used with MySQL databases");
			}
		}
		
		// Do some housekeeping
		char m_szQuery[256], m_szLogCleaningQuery[256];
		Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `date_of_expiration` <> 0 AND `date_of_expiration` < %d", GetTime());
		SQL_TVoid(g_hDatabase, m_szQuery);
		
		/*Format(STRING(m_szVoucherQuery), "UPDATE store_voucher SET"
									... " name_of_redeem = \"voucher's item expired\","
									... " date_of_redeem = %d,"
									... " steam_of_redeem = \"voucher's item expired\","
									... " item_expiration = 0 "
									... "WHERE item_expiration <> 0 AND item_expiration < %d", GetTime(), GetTime());
		SQL_TVoid(g_hDatabase, m_szVoucherQuery);*/
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
				Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_logs WHERE `date` < (SELECT DATETIME('now', '-%i day'))", g_eCvars[g_cvarLogLast].aCache);
				SQL_TVoid(g_hDatabase, m_szLogCleaningQuery);
			}
		}
	}
}

public void SQLCallback_CheckError(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(!StrEqual("", error))
		LogError("Error happened. Error: %s", error);
}

public void SQLCallback_LoadClientInventory_Credits(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
		
		char m_szQuery[256];
		char m_szSteamID[32];
		int m_iTime = GetTime();
		g_eClients[client].iUserId = userid;
		g_eClients[client].iItems = -1;
		GetLegacyAuthString(client, STRING(m_szSteamID), false);
		//strcopy(g_eClients[client].szAuthId, 32, m_szSteamID[8]);
		strcopy(g_eClients[client].szAuthId, sizeof(Client_Data::szAuthId), m_szSteamID[8]);
		GetClientName(client, g_eClients[client].szName_Client, 64);
		SQL_EscapeString(g_hDatabase, g_eClients[client].szName_Client, g_eClients[client].szNameEscaped, 128);
		
		if(SQL_FetchRow(hndl))
		{
			g_eClients[client].iId_Client = SQL_FetchInt(hndl, 0);
			g_eClients[client].iCredits = SQL_FetchInt(hndl, 3);
			g_eClients[client].iOriginalCredits = SQL_FetchInt(hndl, 3);
			g_eClients[client].iDateOfJoin = SQL_FetchInt(hndl, 4);
			g_eClients[client].iDateOfLastJoin = m_iTime;
			
			Format(STRING(m_szQuery), "SELECT * FROM store_items WHERE `player_id`=%d", g_eClients[client].iId_Client);
			SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Items, m_szQuery, userid);

			Store_LogMessage(client, g_eClients[client].iCredits, "Amount of credits when the player joined");
			
			Store_SaveClientData(client);
		}
		else
		{
			Format(STRING(m_szQuery), "INSERT INTO store_players (`authid`, `name`, `credits`, `date_of_join`, `date_of_last_join`) VALUES(\"%s\", '%s', %d, %d, %d)",
						g_eClients[client].szAuthId, g_eClients[client].szNameEscaped, g_eCvars[g_cvarStartCredits].aCache, m_iTime, m_iTime);
			SQL_TQuery(g_hDatabase, SQLCallback_InsertClient, m_szQuery, userid);
			g_eClients[client].iCredits = g_eCvars[g_cvarStartCredits].aCache;
			g_eClients[client].iOriginalCredits = g_eCvars[g_cvarStartCredits].aCache;
			g_eClients[client].iDateOfJoin = m_iTime;
			g_eClients[client].iDateOfLastJoin = m_iTime;
			g_eClients[client].bLoaded= true;
			g_eClients[client].iItems = 0;

			if(g_eCvars[g_cvarStartCredits].aCache > 0)
				Store_LogMessage(client, g_eCvars[g_cvarStartCredits].aCache, "Start credits");
		}
		
		g_eClients[client].hCreditTimer = Store_CreditTimer(client);
	}
}

public void SQLCallback_LoadClientInventory_Items(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{	
		int client = GetClientOfUserId(userid);
		if(!client)
			return;

		char m_szQuery[256];
		Format(STRING(m_szQuery), "SELECT * FROM store_equipment WHERE `player_id`=%d", g_eClients[client].iId_Client);
		SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Equipment, m_szQuery, userid);

		if(!SQL_GetRowCount(hndl))
		{
			g_eClients[client].bLoaded = true;
			g_eClients[client].iItems = 0;
			return;
		}
		
		char m_szUniqueId[PLATFORM_MAX_PATH];
		char m_szType[16];
		int m_iExpiration;
		int m_iUniqueId;
		int m_iTime = GetTime();
		
		int i = 0;
		while(SQL_FetchRow(hndl))
		{
			m_iUniqueId = -1;
			m_iExpiration = SQL_FetchInt(hndl, 5);
			if(m_iExpiration && m_iExpiration<=m_iTime)
				continue;
			
			SQL_FetchString(hndl, 2, STRING(m_szType));
			SQL_FetchString(hndl, 3, STRING(m_szUniqueId));
			while((m_iUniqueId = Store_GetItemId(m_szType, m_szUniqueId, m_iUniqueId))!=-1)
			{
				g_eClientItems[client][i].iId_Client_Item = SQL_FetchInt(hndl, 0);
				g_eClientItems[client][i].iUniqueId = m_iUniqueId;
				g_eClientItems[client][i].bSynced = true;
				g_eClientItems[client][i].bDeleted = false;
				g_eClientItems[client][i].iDateOfPurchase = SQL_FetchInt(hndl, 4);
				g_eClientItems[client][i].iDateOfExpiration = m_iExpiration;
				g_eClientItems[client][i].iPriceOfPurchase = SQL_FetchInt(hndl, 6);
			
				++i;
			}
		}
		g_eClients[client].iItems = i;
	}
}

public void SQLCallback_LoadClientInventory_Equipment(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
		
		char m_szUniqueId[PLATFORM_MAX_PATH];
		char m_szType[16];
		int m_iUniqueId;
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 1, STRING(m_szType));
			SQL_FetchString(hndl, 2, STRING(m_szUniqueId));
			m_iUniqueId = Store_GetItemId(m_szType, m_szUniqueId);
			if(m_iUniqueId == -1)
				continue;
				
			if(!Store_HasClientItem(client, m_iUniqueId))
				Store_UnequipItem(client, m_iUniqueId);
			else
				Store_UseItem(client, m_iUniqueId, true, SQL_FetchInt(hndl, 3));
		}
		g_eClients[client].bLoaded = true;
	}
}

public void SQLCallback_RefreshCredits(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
			
		if(SQL_FetchRow(hndl))
		{
			g_eClients[client].iCredits = SQL_FetchInt(hndl, 3);
			g_eClients[client].iOriginalCredits = SQL_FetchInt(hndl, 3);
		}
	}
}

public void SQLCallback_InsertClient(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
			
		g_eClients[client].iId_Client = SQL_GetInsertId(hndl);
	}
}

public void SQLCallback_ReloadConfig(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
	{
		SetFailState("Error happened reading the config table. The plugin cannot continue.", error);
	}
	else
	{
		char m_szType[64];
		char m_szFlag[64];
		char m_szInfo[2048];
		char m_szKey[64];
		char m_szValue[256];
		
		Handle m_hKV;
		
		bool m_bSuccess;
		
		int m_iLength;
		int m_iHandler;
		int m_iIndex = 0;
	
		while(SQL_FetchRow(hndl))
		{
			if(g_iItems == STORE_MAX_ITEMS)
				return;
				
			if(!SQL_FetchInt(hndl, 7))
				continue;
			
			g_eItems[g_iItems].iId = SQL_FetchInt(hndl, 0);
			g_eItems[g_iItems].iParent = SQL_FetchInt(hndl, 1);
			g_eItems[g_iItems].iPrice = SQL_FetchInt(hndl, 2);
			
			IntToString(g_eItems[g_iItems].iId, g_eItems[g_iItems].szUniqueId, PLATFORM_MAX_PATH);
			
			SQL_FetchString(hndl, 3, STRING(m_szType));
			m_iHandler = Store_GetTypeHandler(m_szType);
			if(m_iHandler == -1)
				continue;
			
			g_eItems[g_iItems].iHandler = m_iHandler;
			
			SQL_FetchString(hndl, 4, STRING(m_szFlag));
			g_eItems[g_iItems].iFlagBits = ReadFlagString(m_szFlag);
			
			SQL_FetchString(hndl, 5, g_eItems[g_iItems].szName, ITEM_NAME_LENGTH);
			SQL_FetchString(hndl, 6, STRING(m_szInfo));
			
			m_hKV = CreateKeyValues("Additional Info");
			
			m_iLength = strlen(m_szInfo);
			while(m_iIndex != m_iLength)
			{
				m_iIndex += strcopy(m_szKey, StrContains(m_szInfo[m_iIndex], "="), m_szInfo[m_iIndex])+2;
				m_iIndex += strcopy(m_szValue, StrContains(m_szInfo[m_iIndex], "\";"), m_szInfo[m_iIndex])+2; // \"
				
				KvJumpToKey(m_hKV, m_szKey, true);
				KvSetString(m_hKV, m_szKey, m_szValue);
				
				m_bSuccess = true;
				if(g_eTypeHandlers[m_iHandler].fnConfig!=INVALID_FUNCTION)
				{
					Call_StartFunction(g_eTypeHandlers[m_iHandler].hPlugin, g_eTypeHandlers[m_iHandler].fnConfig);
					Call_PushCellRef(m_hKV);
					Call_PushCell(g_iItems);
					Call_Finish(m_bSuccess); 
				}
				
				if(m_bSuccess)
					++g_iItems;
			}
			CloseHandle(m_hKV);
		}
	}
}

public void SQLCallback_ResetPlayer(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);

		if(SQL_GetRowCount(hndl))
		{
			SQL_FetchRow(hndl);
			int id = SQL_FetchInt(hndl, 0);
			char m_szAuthId[32];
			SQL_FetchString(hndl, 1, STRING(m_szAuthId));

			char m_szQuery[512];
			Format(STRING(m_szQuery), "DELETE FROM store_players WHERE id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);
			Format(STRING(m_szQuery), "DELETE FROM store_items WHERE player_id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);
			Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE player_id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);

			ChatAll("%t", "Player Resetted", m_szAuthId);

		}
		else
			if(client)
				Chat(client, "%t", "Credit No Match");
	}
}

//////////////////////////////
//			STOCKS			//
//////////////////////////////

public void Store_LoadClientInventory(int client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	char m_szQuery[256];
	char m_szAuthId[32];

	GetLegacyAuthString(client, STRING(m_szAuthId));
	if(m_szAuthId[0] == 0)
		return;

	Format(STRING(m_szQuery), "SELECT * FROM store_players WHERE `authid`=\"%s\"", m_szAuthId[8]);

	SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Credits, m_szQuery, g_eClients[client].iUserId);
}

public void Store_SaveClientInventory(int client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	// Player disconnected before his inventory was even fetched
	if(g_eClients[client].iCredits==-1 && g_eClients[client].iItems==-1)
		return;
	
	char m_szQuery[256];
	char m_szType[16];
	char m_szUniqueId[PLATFORM_MAX_PATH];
	
	for(int i=0;i<g_eClients[client].iItems;++i)
	{
		strcopy(STRING(m_szType), g_eTypeHandlers[g_eItems[g_eClientItems[client][i].iUniqueId].iHandler].szType);
		strcopy(STRING(m_szUniqueId), g_eItems[g_eClientItems[client][i].iUniqueId].szUniqueId);
	
		if(!g_eClientItems[client][i].bSynced && !g_eClientItems[client][i].bDeleted)
		{
			g_eClientItems[client][i].bSynced = true;
			Format(STRING(m_szQuery), "INSERT INTO store_items (`player_id`, `type`, `unique_id`, `date_of_purchase`, `date_of_expiration`, `price_of_purchase`) VALUES(%d, \"%s\", \"%s\", %d, %d, %d)", g_eClients[client].iId_Client, m_szType, m_szUniqueId, g_eClientItems[client][i].iDateOfPurchase, g_eClientItems[client][i].iDateOfExpiration, g_eClientItems[client][i].iPriceOfPurchase);
			SQL_TVoid(g_hDatabase, m_szQuery);
		} else if(g_eClientItems[client][i].bSynced && g_eClientItems[client][i].bDeleted)
		{
			// Might have been synced already but ID wasn't acquired
			if(g_eClientItems[client][i].iId_Client_Item==-1)
				Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `player_id`=%d AND `type`=\"%s\" AND `unique_id`=\"%s\"", g_eClients[client].iId_Client, m_szType, m_szUniqueId);
			else
				Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `id`=%d", g_eClientItems[client][i].iId_Client_Item);
			SQL_TVoid(g_hDatabase, m_szQuery);
		}
	}
}

public void Store_SaveClientEquipment(int client)
{
	char m_szQuery[256];
	int m_iId;
	for(int i=0;i<STORE_MAX_HANDLERS;++i)
	{
		for(int a=0;a<STORE_MAX_SLOTS;++a)
		{
			m_iId = i*STORE_MAX_SLOTS+a;
			if(g_eClients[client].aEquipmentSynced[m_iId] == g_eClients[client].aEquipment[m_iId])
				continue;
			else if(g_eClients[client].aEquipmentSynced[m_iId] != -2)
				if(g_eClients[client].aEquipment[m_iId]==-1)
					Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE `player_id`=%d AND `type`=\"%s\" AND `slot`=%d", g_eClients[client].iId_Client, g_eTypeHandlers[i].szType, a);
				else
					Format(STRING(m_szQuery), "UPDATE store_equipment SET `unique_id`=\"%s\" WHERE `player_id`=%d AND `type`=\"%s\" AND `slot`=%d", g_eItems[g_eClients[client].aEquipment[m_iId]].szUniqueId, g_eClients[client].iId_Client, g_eTypeHandlers[i].szType, a);
				
			else
				Format(STRING(m_szQuery), "INSERT INTO store_equipment (`player_id`, `type`, `unique_id`, `slot`) VALUES(%d, \"%s\", \"%s\", %d)", g_eClients[client].iId_Client, g_eTypeHandlers[i].szType, g_eItems[g_eClients[client].aEquipment[m_iId]].szUniqueId, a);

			SQL_TVoid(g_hDatabase, m_szQuery);
			g_eClients[client].aEquipmentSynced[m_iId] = g_eClients[client].aEquipment[m_iId];
		}
	}
}

public void Store_SaveClientData(int client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	if((g_eClients[client].iCredits==-1 && g_eClients[client].iItems==-1) || !g_eClients[client].bLoaded)
		return;
	
	char m_szQuery[256];
	if(g_bMySQL)
		Format(STRING(m_szQuery), "UPDATE store_players SET `credits`=GREATEST(`credits`+%d,0), `date_of_last_join`=%d, `name`='%s' WHERE `id`=%d", g_eClients[client].iCredits-g_eClients[client].iOriginalCredits, g_eClients[client].iDateOfLastJoin, g_eClients[client].szNameEscaped, g_eClients[client].iId_Client);
	else
		Format(STRING(m_szQuery), "UPDATE store_players SET `credits`=MAX(`credits`+%d,0), `date_of_last_join`=%d, `name`='%s' WHERE `id`=%d", g_eClients[client].iCredits-g_eClients[client].iOriginalCredits, g_eClients[client].iDateOfLastJoin, g_eClients[client].szNameEscaped, g_eClients[client].iId_Client);

	g_eClients[client].iOriginalCredits = g_eClients[client].iCredits;

	SQL_TVoid(g_hDatabase, m_szQuery);
}

public void Store_DisconnectClient(int client)
{
	Store_LogMessage(client, g_eClients[client].iCredits, "Amount of credits when the player left");
	g_eClients[client].iCredits = -1;
	g_eClients[client].iOriginalCredits = -1;
	g_eClients[client].iItems = -1;
	g_eClients[client].bLoaded = false;
	if (g_eClients[client].hCreditTimer != null)
	{
		ClearTimer(g_eClients[client].hCreditTimer);
	}
}

int Store_GetItemId(char[] type, char[] uid,int start=-1)
{
	for(int i=start+1;i<g_iItems;++i)
		if(strcmp(g_eTypeHandlers[g_eItems[i].iHandler].szType, type)==0 && strcmp(g_eItems[i].szUniqueId, uid)==0 && g_eItems[i].iPrice >= 0)
			return i;
	return -1;
}

void Store_BuyItem(int client,int itemid,int plan=-1)
{
	if(Store_HasClientItem(client, itemid))
		return;
	
	int m_iPrice = 0;
	if(plan==-1)
	{
		m_iPrice = g_eItems[itemid].iPrice;
	}
	else
	{
		m_iPrice = g_ePlans[itemid][plan].iPrice_Plan;
	}
	
	if(g_eClients[client].iCredits<m_iPrice)
		return;
		
	int m_iId = g_eClients[client].iItems++;
	g_eClientItems[client][m_iId].iId_Client_Item = -1;
	g_eClientItems[client][m_iId].iUniqueId = itemid;
	g_eClientItems[client][m_iId].iDateOfPurchase = GetTime();
	g_eClientItems[client][m_iId].iDateOfExpiration = (plan==-1?0:(g_ePlans[itemid][plan].iTime_Plan?GetTime()+g_ePlans[itemid][plan].iTime_Plan:0));
	g_eClientItems[client][m_iId].iPriceOfPurchase = m_iPrice;
	g_eClientItems[client][m_iId].bSynced = false;
	g_eClientItems[client][m_iId].bDeleted = false;
	
	g_eClients[client].iCredits -= m_iPrice;

	Store_LogMessage(client, -g_eItems[itemid].iPrice, "Bought a %s %s", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	Store_SQLLogMessage(client, LOG_EVENT, "Bought a %s %s.", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	
	Chat(client, "%t", "Chat Bought Item", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
}

public void Store_SellItem(int client,int itemid)
{	
	int m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, itemid)*view_as<float>(g_eCvars[g_cvarSellRatio].aCache));
	int uid = Store_GetClientItemId(client, itemid);
	if(g_eClientItems[client][uid].iDateOfExpiration != 0)
	{
		int m_iLength = g_eClientItems[client][uid].iDateOfExpiration-g_eClientItems[client][uid].iDateOfPurchase;
		int m_iLeft = g_eClientItems[client][uid].iDateOfExpiration-GetTime();
		if(m_iLeft<0)
			m_iLeft = 0;
		m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
	}

	g_eClients[client].iCredits += m_iCredits;
	Chat(client, "%t", "Chat Sold Item", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	
	Store_UnequipItem(client, itemid);
	
	Store_LogMessage(client, m_iCredits, "Sold a %s %s", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	Store_SQLLogMessage(client, LOG_EVENT, "Sold a %s %s", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	
	Store_RemoveItem(client, itemid);
}

public void Store_GiftItem(int client,int receiver,int item)
{
	int m_iId = g_eClientItems[client][item].iUniqueId;
	int target = g_iMenuClient[client];
	g_eClientItems[client][item].bDeleted = true;
	Store_UnequipItem(client, m_iId);

	g_eClientItems[receiver][g_eClients[receiver].iItems].iId_Client_Item = -1;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iUniqueId = m_iId;
	g_eClientItems[receiver][g_eClients[receiver].iItems].bSynced = false;
	g_eClientItems[receiver][g_eClients[receiver].iItems].bDeleted = false;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iDateOfPurchase = g_eClientItems[target][item].iDateOfPurchase;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iDateOfExpiration = g_eClientItems[target][item].iDateOfExpiration;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iPriceOfPurchase = g_eClientItems[target][item].iPriceOfPurchase;
	
	++g_eClients[receiver].iItems;

	Chat(client, "%t", "Chat Gift Item Sent", g_eClients[receiver].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
	Chat(receiver, "%t", "Chat Gift Item Received", g_eClients[target].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
	Store_SQLLogMessage(0, LOG_EVENT, "%s gift %s (%s) to %s", g_eClients[target].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType, g_eClients[receiver].szName_Client);

	Store_LogMessage(client, 0, "Gifted a %s to %N", g_eItems[m_iId].szName, receiver);
}

public int Store_GetClientItemId(int client,int itemid)
{
	for(int i=0;i<g_eClients[client].iItems;++i)
	{
		if(g_eClientItems[client][i].iUniqueId == itemid && !g_eClientItems[client][i].bDeleted)
			return i;
	}
		
	return -1;
}

public Handle Store_CreditTimer(int client)
{
	return CreateTimer(g_eCvars[g_cvarCreditTimer].aCache, Timer_CreditTimer, g_eClients[client].iUserId, TIMER_REPEAT);
}

public void ReadCoreCFG()
{
	char m_szFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, STRING(m_szFile), "configs/core.cfg");

	Handle hParser = SMC_CreateParser();
	char error[128];
	int line = 0;
	int col = 0;

	SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(hParser, Config_End);

	any result = SMC_ParseFile(hParser, m_szFile, line, col);
	CloseHandle(hParser);

	if (result != SMCError_Okay) 
	{
		SMC_GetErrorString(view_as<SMCError>(result), error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, m_szFile);
	}

}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes) 
{
	if (StrEqual(section, "Core"))
	{
		return SMCParse_Continue;
	}

	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if(StrEqual(key, "PublicChatTrigger", false))
		g_iPublicChatTrigger = value[0];
	//else if(StrEqual(key, "SilentChatTrigger", false))
	//	SilentChatTrigger = value[0];
	
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser) 
{
    return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed) 
{
}

public Action Command_ReloadConfig(int client, int args)
{
	
	if(g_eCvars[g_cvarConfirmation].aCache)
	{
		char buffer[128];
		if(!g_eCvars[gc_iReloadType].aCache)
			Format(buffer, sizeof(buffer), "%t", "confirm_reload_type_0", view_as<int>(g_eCvars[gc_iReloadDelay].aCache));
		else Format(buffer, sizeof(buffer), "%t", "confirm_reload_type_1");
		Store_DisplayConfirmMenu(client, buffer, FakeMenuHandler_StoreReloadConfig, 0);
	}
	else
	{
		Store_ReloadConfig();
		ReplyToCommand(client, "%s %s", g_sChatPrefix, "Config reloaded. Please restart or change map");
	}
	
	return Plugin_Handled;
}

public void FakeMenuHandler_StoreReloadConfig(Handle menu, MenuAction action, int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			//FakeClientCommandEx(client, "sm_resetplayer \"%s\"", g_szClientData[client]);
			//Store_ReloadConfig();
			if(!g_eCvars[gc_iReloadType].aCache)
			{
				if(ReloadTimer != INVALID_HANDLE)
				{
					Chat(client, "%t", "Admin chat reload timer exist");
				}
				else
				{
					hTime = view_as<int>(g_eCvars[gc_iReloadDelay].aCache);
					ReloadTimer = CreateTimer(1.0, Timer_ReloadConfig);
				}
			}
			else
			{
				Store_ReloadConfig();
				Chat(client, "%s", "Config reloaded. Please restart or change map");
			}
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

public Action Timer_ReloadConfig(Handle timer, DataPack pack)
{
	char map[128];
	GetCurrentMap(map, 128);
	
	if(hTime > 0)
	{
		if(g_eCvars[gc_iReloadNotify].aCache)
		{
			//CPrintToChatAll("%t" , "Timer_Server_ReloadConfig", time);
			ChatAll("%t" , "Timer_Server_ReloadConfig", hTime);
		}
		--hTime;
		ReloadTimer = CreateTimer(1.0, Timer_ReloadConfig);
	}
	else 
	{
		Store_ReloadConfig();
		ServerCommand("sm_map %s", map);
	}
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

public int Store_GetTypeHandler(char[] type)
{
	for(int i=0;i<g_iTypeHandlers;++i)
	{
		if(strcmp(g_eTypeHandlers[i].szType, type)==0)
			return i;
	}
	return -1;
}

public int Store_GetMenuHandler(char[] id)
{
	for(int i=0;i<g_iMenuHandlers;++i)
	{
		if(strcmp(g_eMenuHandlers[i].szIdentifier, id)==0)
			return i;
	}
	return -1;
}

public bool Store_IsEquipped(int client,int itemid)
{
	for(int i=0;i<STORE_MAX_SLOTS;++i)
		if(g_eClients[client].aEquipment[g_eItems[itemid].iHandler*STORE_MAX_SLOTS+i] == itemid)
			return true;
	return false;
}

public int Store_GetExpiration(int client,int itemid)
{
	int uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;
	return g_eClientItems[client][uid].iDateOfExpiration;
}

any Store_UseItem(int client,int itemid, bool synced=false,int slot=0)
{
	int m_iSlot = slot;
	if(g_eTypeHandlers[g_eItems[itemid].iHandler].fnUse != INVALID_FUNCTION)
	{
		int m_iReturn = -1;
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid].iHandler].hPlugin, g_eTypeHandlers[g_eItems[itemid].iHandler].fnUse);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(m_iReturn);
		
		if(m_iReturn != -1)
			m_iSlot = m_iReturn;
	}

	if(g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
	{
		g_eClients[client].aEquipment[g_eItems[itemid].iHandler*STORE_MAX_SLOTS+m_iSlot]=itemid;
		if(synced)
			g_eClients[client].aEquipmentSynced[g_eItems[itemid].iHandler*STORE_MAX_SLOTS+m_iSlot]=itemid;
	}
	else if(m_iSlot == 0)
	{
		Store_RemoveItem(client, itemid);
		return 1;
	}
	return 0;
}

any Store_UnequipItem(int client,int itemid, bool fn=true)
{
	int m_iSlot = 0;
	if(fn && itemid > 0 && g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove != INVALID_FUNCTION)
	{
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid].iHandler].hPlugin, g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(m_iSlot);
	}

	int m_iId;
	if(g_eItems[itemid].iHandler != g_iPackageHandler)
	{
		m_iId = g_eItems[itemid].iHandler*STORE_MAX_SLOTS+m_iSlot;
		if(g_eClients[client].aEquipmentSynced[m_iId]==-2)
			g_eClients[client].aEquipment[m_iId]=-2;
		else
			g_eClients[client].aEquipment[m_iId]=-1;
	}
	else
	{
		for(int i=0;i<STORE_MAX_HANDLERS;++i)
		{
			for(int a=0;i<STORE_MAX_SLOTS;++i)
			{
				if(g_eClients[client].aEquipment[i+a] < 0)
					continue;
				m_iId = i*STORE_MAX_SLOTS+a;
				if(Store_IsItemInBoughtPackage(client, g_eClients[client].aEquipment[m_iId], itemid))
					if(g_eClients[client].aEquipmentSynced[m_iId]==-2)
						g_eClients[client].aEquipment[m_iId]=-2;
					else
						g_eClients[client].aEquipment[m_iId]=-1;
			}
		}
	}
}

int Store_GetEquippedItemFromHandler(int client,any handler,int slot=0)
{
	return g_eClients[client].aEquipment[handler*STORE_MAX_SLOTS+slot];
}

bool Store_PackageHasClientItem(int client,int packageid, bool invmode=false)
{
	int m_iFlags = GetUserFlagBits(client);
	if(!g_eCvars[g_cvarShowVIP].aCache && !GetClientPrivilege(client, g_eItems[packageid].iFlagBits, m_iFlags))
		return false;
	for(int i=0;i<g_iItems;++i)
		if(g_eItems[i].iParent == packageid && (g_eCvars[g_cvarShowVIP].aCache || GetClientPrivilege(client, g_eItems[i].iFlagBits, m_iFlags)) && (invmode && Store_HasClientItem(client, i) || !invmode))
			if((g_eItems[i].iHandler == g_iPackageHandler && Store_PackageHasClientItem(client, i, invmode)) || g_eItems[i].iHandler != g_iPackageHandler)
				return true;
	return false;
}

void Store_LogMessage(int client,int credits, const char[] message,any ...)
{
	if(!g_eCvars[g_cvarLogging].aCache)
		return;

	char m_szReason[256];
	VFormat(STRING(m_szReason), message, 4);

	if(g_eCvars[g_cvarLogging].aCache == 1)
	{
		LogToOpenFileEx(g_hLogFile, "%N's credits have changed by %d. Reason: %s", client, credits, m_szReason);
	} else if(g_eCvars[g_cvarLogging].aCache == 2)
	{
		char m_szQuery[256];
		Format(STRING(m_szQuery), "INSERT INTO store_logs (player_id, credits, reason, date) VALUES(%d, %d, \"%s\", CURRENT_TIMESTAMP)", g_eClients[client].iId_Client, credits, m_szReason);
		SQL_TVoid(g_hDatabase, m_szQuery);
	}
}

int Store_GetLowestPrice(int itemid)
{
	if(g_eItems[itemid].iPlans==0)
		return g_eItems[itemid].iPrice;

	int m_iLowest=g_ePlans[itemid][0].iPrice_Plan;
	for(int i=1;i<g_eItems[itemid].iPlans;++i)
	{
		if(m_iLowest>g_ePlans[itemid][i].iPrice_Plan)
			m_iLowest = g_ePlans[itemid][i].iPrice_Plan;
	}
	return m_iLowest;
}

int Store_GetClientItemPrice(int client,int itemid)
{
	int uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;
		
	if(g_eClientItems[client][uid].iPriceOfPurchase==0)
		return g_eItems[itemid].iPrice;

	return g_eClientItems[client][uid].iPriceOfPurchase;
}

public void Store_OnPaymentReceived(any FriendID,any quanity, Handle data)
{
	LoopIngamePlayers(i)
	{
		if(GetFriendID(i)==FriendID)
		{
			Store_SaveClientData(i);

			any m_unMod = FriendID % 2;
			any m_unAccountID = (FriendID-m_unMod)/2;

			char m_szQuery[256];
			Format(STRING(m_szQuery), "SELECT * FROM store_players WHERE `authid`=\"%d:%d\"", m_unMod, m_unAccountID);
			SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Credits, m_szQuery, GetClientUserId(i));
			break;
		}
	}
}

bool CheckSteamAuth(int client, char[] steam)
{
	if (!steam[0])
		return true;

	char sSteam[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteam, 32))
		return false;

	if (StrContains(steam, sSteam) == -1)
		return false;

	return true;
}

void Forward_OnConfigsExecuted()
{
	Call_StartForward(gf_hOnConfigExecuted);
	Call_PushString(g_sChatPrefix);
	Call_Finish();
}

stock bool IsCommonInfected(int iEntity)
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        char strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "infected");
    }
    return false;
} 
public void SQLCallback_Void_Error(Handle owner, Handle hndl, const char[] error, any data)
{
	if (owner == null)
	{
		StoreLogMessage(0, LOG_ERROR, "SQLCallback_Void_Error: %s", error);
	}
}	
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

Store_Item g_eItems[STORE_MAX_ITEMS];
Client_Data g_eClients[MAXPLAYERS+1];
Client_Item g_eClientItems[MAXPLAYERS+1][STORE_MAX_ITEMS];
Type_Handler g_eTypeHandlers[STORE_MAX_HANDLERS];
Menu_Handler g_eMenuHandlers[STORE_MAX_HANDLERS];
Item_Plan g_ePlans[STORE_MAX_ITEMS][STORE_MAX_PLANS];
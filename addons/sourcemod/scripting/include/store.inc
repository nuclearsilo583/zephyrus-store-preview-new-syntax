#if defined _store_included
	#endinput
#endif
#define _store_included

int g_cvarChatTag = -1;
#define CHAT_TAG g_eCvars[g_cvarChatTag].sCache

#define LOG_ERROR 0
#define LOG_CREDITS 1
#define LOG_ADMIN 2
#define LOG_EVENT 3

#define ITEM_NAME_LENGTH 64
#define STORE_MAX_ITEMS 2048
#define STORE_MAX_HANDLERS 64
#define STORE_MAX_PLANS 8
#define STORE_MAX_SLOTS 12

enum struct Item_Plan
{
	char szName_Plan[ITEM_NAME_LENGTH];
	int iPrice_Plan;
	int iTime_Plan;
}

enum struct Store_Item
{
	char szName[ITEM_NAME_LENGTH];
	char szUniqueId[PLATFORM_MAX_PATH];
	char szShortcut[64];
	char szSteam[256];
	char szDescription[256];
	int iId;
	int iPrice;
	int iParent;
	int iHandler;
	int iFlagBits;
	int iData;
	int iPlans;
	bool bBuyable;
	bool bIgnoreFree;
	bool bIgnoreVIP;
	bool bPreview;
	Handle hAttributes;
}

enum struct Type_Handler
{
	char szType[64];
	char szUniqueKey[32];
	bool bEquipable;
	bool bRaw;
	Handle hPlugin;
	Function fnMapStart;
	Function fnReset;
	Function fnConfig;
	Function fnUse;
	Function fnRemove;
}

enum struct Client_Item
{
	int iId_Client_Item;
	int iUniqueId;
	bool bSynced;
	bool bDeleted;
	int iDateOfPurchase;
	int iDateOfExpiration;
	int iPriceOfPurchase;
}

/**
 * Register a item type (plugin) to the core.
 *
 * @param type			Type of item.
 * @param uniquekey		Unique key of item.
 * @param mapstart		Optional function to call on store mapstart.
 * @param reset			Optional function to call for reset items.
 * @param config		Optional function to call for add item configs.
 * @param use			Function to call for use/equip item.
 * @param remove		Optional function to call for remove/unequip item.
 * @param equipable		Optional if set to true, the item is equipable.
 * @param raw			Optional if set to true, type will be "only a menu entry".
 *						Shows no menu item like use or equip.
 * 
 * @return				-1 if failed to add (reached STORE_MAX_HANDLERS)
 *						else the index of this typehandler.
 */
native int Store_RegisterHandler(char[] type, char[] uniquekey, Function mapstart = INVALID_FUNCTION, Function reset = INVALID_FUNCTION, Function config = INVALID_FUNCTION, Function use = INVALID_FUNCTION, Function remove = INVALID_FUNCTION, bool equipable = true, bool raw = false);

/**
 * Register a item menu handler (plugin) to the core.
 *
 * @param identifier	Identifier for this handler.
 * @param menu			Function to call on display item menu.
 * @param handler		Function to call on select item handler.
 * 
 * @return				-1 if failed to add (reached STORE_MAX_HANDLERS)
 *						else the index of this itemhandler.
 */
native int Store_RegisterMenuHandler(char[] identifier, Function menu, Function handler);

/**
 * Set the DataIndex of a item.
 *
 * @param itemid		ID of the item.
 * @param index			DataIndex of the item.
 * 
 * @noreturn
 */
native void Store_SetDataIndex(int itemid, int index);

/**
 * Get the DataIndex of a item.
 *
 * @param itemid		ID of the selected item.
 * 
 * @return				DataIndex of the item.
 */
native int Store_GetDataIndex(int itemid);

/**
 * Get clients equipt item.
 *
 * @param client		Index of client.
 * @param type			Type of the item.
 * @param slot			Optional slot of the item.
 * 
 * @return				ID of the item.
 */
native int Store_GetEquippedItem(int client, char[] type, int slot=0);

/**
 * Check if client data is loaded from database
 *
 * @param client		Index of client.
 * 
 * @return				True for success, otherwise false.
 */
native bool Store_IsClientLoaded(int client);

/**
 * Display the previous menu window to a client.
 * 
 * @param client		Index of client.
 * 
 * @noreturn
 */
native void Store_DisplayPreviousMenu(int client);

native void Store_SetClientMenu(int client, int num);

/**
 * Get clients credits.
 *
 * @param client		Index of client.
 * 
 * @return				Amount of credits.
 */
native int Store_GetClientCredits(int client);

/**
 * Set clients credits.
 *
 * @param client		Index of client.
 * @param credits		Amount of credits.
 * @param reason		Optional reason for changed credits.
 * 
 * @noreturn
 */
native void Store_SetClientCredits(int client, int credits);

/**
 * Check client for vip flag "sm_store_vip_flag"
 *
 * @param client		Index of client.
 * 
 * @return				True for success, otherwise false.
 */
native bool Store_IsClientVIP(int client);

/**
 * Check if client has a item
 *
 * @param client		Index of client.
 * @param itemid		ID of the item.
 * @param uid			Optional ID of the package.
 * 
 * @return				True for success, otherwise false.
 */
native bool Store_IsItemInBoughtPackage(int client, int itemid, int uid=-1);

/**
 * Check if a comfirm is required "store_confirm"
 * 
 * @return				True for comfirm, otherwise false.
 */
native bool Store_ShouldConfirm();

/**
 * Display the comfirm window to a client.
 * 
 * @param client		Index of client.
 * @param title			Title of the comfirm window.
 * @param callback		Function to call on postive comfirm.
 * @param data			Data to pass through menus.
 * 
 * @noreturn
 */
native void Store_DisplayConfirmMenu(int client, char[] title, Function callback, int data);

/**
 * Get item data.
 *
 * @param itemid		ID of the item.
 * @param output		Buffer to store item data.
 * 
 * @return				True for success, otherwise false.
 */
native int Store_GetItem(int itemid, any output[sizeof(Store_Item)]);

/**
 * Get type data.
 *
 * @param index			Index of the type.
 * @param output		Buffer to store type data.
 * 
 * @return				True for success, otherwise false.
 */
native void Store_GetHandler(int index, any output[sizeof(Type_Handler)]);

/**
 * Give a client a item.
 *
 * @param client		Index of client.
 * @param itemid		ID of the item.
 * @param purchase		Optional date of purchase.
 * @param expiration	Optional date of expiration.
 * @param price			Optional price of purchase.
 * 
 * @noreturn
 */
native void Store_GiveItem(int client, int itemid, int purchase=0, int expiration=0, int price=0);

/**
 * Unequip & removes a client a item.
 *
 * @param client		Index of client.
 * @param itemid		ID of the item.
 *
 * @noreturn
 */
native void Store_RemoveItem(int client, int itemid);

/**
 * Get a clients item data.
 *
 * @param client		Index of client.
 * @param itemid		ID of the item.
 * @param output		Buffer to store client item data.
 * 
 * @return				True for success, otherwise false.
 */
native bool Store_GetClientItem(int client, int itemid, any output[sizeof(Client_Item)]);

/**
 * Get a clients target.
 *
 * @param client		Index of client.
 * 
 * @return				Index of target client.
 */
native int Store_GetClientTarget(int client);

/**
 * Give a client a item.
 *
 * @param client		Index of client.
 * @param recipient		Index of receiver.
 * @param itemid		ID of the item.
 * 
 * @noreturn
 */
native void Store_GiveClientItem(int client, int recipient, int itemid);

/**
 * Check if client has a item
 *
 * @param client		Index of client.
 * @param itemid		ID of the item.
 * 
 * @return				True for success, otherwise false.
 */
native bool Store_HasClientItem(int client, int itemid);

/**
 * Iterate throuh all equipped items of a client.
 *
 * @param client		Index of client.
 * @param start			Start Index of client equipt items (value increases through iterate).
 * @param attributes	Only return items with attribues.
 *
 * @return				Itemid if the item
 */
native int Store_IterateEquippedItems(int client,int &start, bool attributes=false);

/**
 * Get item data.
 *
 * @param unique_id		Unique indentfy sting.
 * 
 * @return				The item ID, -1 on false.
 */
native int Store_GetItemIdbyUniqueId(char[] unique_id);

/**
 * Get item plan price.
 *
 * @param itemid		ID of the item.
 * @param highest		Get the highest plan price.
 * 
 * @return				Price of the planned item.
 */
native int Store_GetPlansPrice(int itemid, int highest = 0);

/**
 * Get total number of items loaded in store.
 * 
 * @return				Number of items loaded.
 */
native int Store_GetStoreItemsCount();

/**
 * Send an string to core plugin to escape for SQL querys/transactions
 *
 * @param tnx			string to escape
 * @return				-1 if db is not connected else 1
 */
native int Store_SQLEscape(char[] escapeString);

/**
 * Send and SQL query through the core plugin to database server
 *
 * @param query			Query to send to db
 * @param callback		Callback to recieve answer from db
 * @param data			data to pass to callback
 *
 * @return				-1 if db is not connected else 1
 */
native int Store_SQLQuery(char[] query, SQLQueryCallback callback, any data);

/**
 * Send and SQL transaction through the core plugin to database server
 *
 * @param tnx			Transaction to query
 * @param callback		Callback to recieve answer from db
 * @param data			data to pass to callback
 *
 * @return				-1 if db is not connected else 1
 */
native int Store_SQLTransaction(Transaction tnx, SQLTxnSuccess callback, any data);

/**
 * Set an store Log Message
 *
 * @param client		Client triggered logging event
 * @param callback		Message to log
 * @param data			Log Level
 * 						LOG_ERROR
 * 						LOG_CREDITS
 * 						LOG_ADMIN
 * 						LOG_EVENT
 *
 * @noreturn
 */
native void Store_SQLLogMessage(int client = 0, int level, char[] message, any ...);

forward void Store_OnClientModelChanged(int client, char[] model);

/**
 * Called when a client preview a item.
 *
 * @param client		Index of client.
 * @param type			Type of item.
 * @param index			DataIndex of item.
 * 
 * @noreturn
 */
forward void Store_OnPreviewItem(int client, char[] type, int index);

/**
 * Called when a client preview a item.
 * @param prefix		Chat prefix of store "sm_store_chat_tag_plugins".
 * 
 * @noreturn
 */
forward void Store_OnConfigExecuted(char[] prefix);

/**
 * Check if player is in a recurring menu. (most likely gambling)
 *
 * @param client		Index of client.
 * 
 * @return				True for success, otherwise false.
 */
native bool Store_IsInRecurringMenu(int client);

/**
 * Set if player is in a recurring menu.
 *
 * @param client		Index of client.
 * @param active		True is in menu, otherwise false.
 * 
 * @noreturn
 */
native void Store_SetClientRecurringMenu(int client, bool active);

/*
public Extension:__ext_store_sm =
{
	name = "Store - The Resurrection",
	file = "store_sm.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
	required = 0,
};*/
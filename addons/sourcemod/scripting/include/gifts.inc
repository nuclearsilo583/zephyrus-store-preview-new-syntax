#if defined _gifts_included
  #endinput
#endif
#define _gifts_included

public SharedPlugin __pl_gifts = 
{
	name = "[ANY] Gifts",
	file = "gifts.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_gifts_SetNTVOptional()
{
	MarkNativeAsOptional("Gifts_RegisterPlugin");
	MarkNativeAsOptional("Gifts_RemovePlugin");
	MarkNativeAsOptional("Gifts_SetClientCondition");
	MarkNativeAsOptional("Gifts_GetClientCondition");
	MarkNativeAsOptional("Gifts_SpawnGift");
}
#endif

enum GiftConditions
{
	Condition_None = 0,
	Condition_InCondition,
	Condition_InConditionCanPickUp
}

/**
 * Registers a listener with the gifts plugin.
 *
 * @param callback  The callback function
 * @return        True if plugin was successfully registered.
 */
native any Gifts_RegisterPlugin(Function callback);
native any Gifts_RemovePlugin();
native any Gifts_SetClientCondition(int client, GiftConditions clientState);
native any Gifts_GetClientCondition(int client);
native any Gifts_SpawnGift(Function callback, const char[] model, float lifetime, float[3] position,any data,int owner=0);

forward void Gifts_OnGiftSpawned(any entity);
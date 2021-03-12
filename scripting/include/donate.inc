#if defined _donate_Included_
	#endinput
#endif
#define _donate_Included_

public SharedPlugin __pl_donate =
{
		name = "donate",
		file = "donate.smx",
#if defined REQUIRE_PLUGIN
		required = 1,
#else
		required = 0,
#endif
};

native any Donate_RegisterHandler(char[] name, Function callback);
native any Donate_RemoveHandler(char[] name);

public void __pl_donate_SetNTVOptional()
{
	MarkNativeAsOptional("Donate_RegisterHandler");
	MarkNativeAsOptional("Donate_RemoveHandler");
}
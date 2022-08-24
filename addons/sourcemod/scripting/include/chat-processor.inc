#if defined _chat_processor_included
  #endinput
#endif
#define _chat_processor_included

//Globals
#define MAXLENGTH_FLAG		32
#define MAXLENGTH_NAME		128
#define MAXLENGTH_MESSAGE	128
#define MAXLENGTH_BUFFER	255

////////////////////////////
//Natives

/**
* Retrieves the current format string assigned from a flag string.
* Example: "Cstrike_Chat_All" = "{1} :  {2}"
* You can find the config formats in either the translations or the configs.
*
* param sFlag		Flag string to retrieve the format string from.
* param sBuffer		Format string from the flag string.
* param iSize		Size of the format string buffer.
*
* noreturn
**/
native void ChatProcessor_GetFlagFormatString(const char[] sFlag, char[] sBuffer, int iSize);

/**
* Adds a specific tag to a clients name.
*
* param client		Client index.
* param tag			Tag buffer.
*
* return			True if added, false otherwise.
**/
native bool ChatProcessor_AddClientTag(int client, const char[] tag);

/**
* Removes a specific tag from a clients name.
*
* param client		Client index.
* param tag			Tag buffer.
*
* return			True if found and removed, false otherwise.
**/
native bool ChatProcessor_RemoveClientTag(int client, const char[] tag);

/**
* Swap client tags in place.
*
* param client		Client index.
* param tag1		Tag1 buffer.
* param tag2		Tag2 buffer.
*
* return			True if both found and swapped, false otherwise.
**/
native bool ChatProcessor_SwapClientTags(int client, const char[] tag1, const char[] tag2);

/**
* Strips all tags from a client.
*
* param client		Client index.
*
* return			True if tags were found and stripped, false if none were found and stripped.
**/
native bool ChatProcessor_StripClientTags(int client);

/**
* Sets the specific color for a tag.
*
* param client		Client index.
* param tag			Tag buffer.
* param color		Color to use.
*
* return			True if found and set, false otherwise.
**/
native bool ChatProcessor_SetTagColor(int client, const char[] tag, const char[] color);

/**
* Sets the specific color for the clients name.
*
* param client		Client index.
* param color		Color to use.
*
* return			True if set, false otherwise.
**/
native bool ChatProcessor_SetNameColor(int client, const char[] color);

/**
* Sets the specific color for the clients messages.
*
* param client		Client index.
* param color		Color to use.
*
* return			True if set, false otherwise.
**/
native bool ChatProcessor_SetChatColor(int client, const char[] color);

////////////////////////////
//Forwards

/**
* Called before a chat message is sent, here the message is already processed.
*
* param sender			Author that sent the message.
* param reciver			Reciver of the message.
* param flag			Message's flag.
* param buffer			Message's buffer.
* param maxlength		Max length of the buffer.
*
* return types
*  - Plugin_Continue	Continues the message.
*  - Plugin_Changed		Continues the message.
*  - Plugin_Handled		Stops the message.
*  - Plugin_Stop		Stops the message.
**/
forward Action CP_OnChatMessageSendPre(int sender, int reciever, char[] flag, char[] buffer, int maxlength);

/**
* Called while sending a chat message before It's sent.
* Limits on the name and message strings can be found above.
*
* param author			Author that created the message.
* param recipients		Array of clients who will receive the message.
* param flagstring		Flag string to determine the type of message.
* param name			Name string of the author to be pushed.
* param message		Message string from the author to be pushed.
* param processcolors	Toggle to process colors in the buffer strings.
* param removecolors	Toggle to remove colors in the buffer strings. (Requires bProcessColors = true)
*
* return types
*  - Plugin_Continue	Continues the message.
*  - Plugin_Changed		Fires the post-forward below and prints out a message.
*  - Plugin_Handled		Fires the post-forward below but doesn't print a message.
*  - Plugin_Stop		Stops the message.
**/
forward Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool & processcolors, bool & removecolors);

/**
* Called after the chat message is sent to the designated clients by the author.
*
* param author			Author that sent the message.
* param recipients		Array of clients who received the message.
* param flagstring		Flag string to determine the type of message.
* param formatstring	Format string used in the message based on the flag string.
* param name			Name string of the author.
* param message		Message string from the author.
* param processcolors	Check if colors were processed in the buffer strings.
* param removecolors	Check if colors were removed from the buffer strings.
*
* noreturn
**/
forward void CP_OnChatMessagePost(int author, ArrayList recipients, const char[] flagstring, const char[] formatstring, const char[] name, const char[] message, bool processcolors, bool removecolors);

/**
* Called after the client has had a new tag added.
*
* param client			Client index.
* param index			Index for the tag.
* param tag				The tag itself.
*
* noreturn
**/
forward void CP_OnAddClientTagPost(int client, int index, const char[] tag);

/**
* Called after the client has had a new tag removed.
*
* param client			Client index.
* param index			Index the tag used to have.
* param tag				The tag removed.
*
* noreturn
**/
forward void CP_OnRemoveClientTagPost(int client, int index, const char[] tag);

/**
* Called after the client has had two tags swapped in place.
*
* param client			Client index.
* param index1			Index for the first tag.
* param tag1			The first tag itself.
* param index2			Index for the second tag.
* param tag2			The second tag itself.
*
* noreturn
**/
forward void CP_OnSwapClientTagsPost(int client, int index1, const char[] tag1, int index2, const char[] tag2);

/**
* Called after the client had all of their tags stripped.
*
* param client			Client index.
*
* noreturn
**/
forward void CP_OnStripClientTagsPost(int client);

/**
* Called after a particular client tags color is set.
*
* param client			Client index.
* param index			Index for the tag.
* param tag				The tag itself.
* param color			The color code used.
*
* noreturn
**/
forward void CP_OnSetTagColorPost(int client, int index, const char[] tag, const char[] color);

/**
* Called after a client's name color is set.
*
* param client			Client index.
* param color			The color code used.
*
* noreturn
**/
forward void CP_OnSetNameColorPost(int client, const char[] color);

/**
* Called after a client's chat color is set.
*
* param client			Client index.
* param color			The color code used.
*
* noreturn
**/
forward void CP_OnSetChatColorPost(int client, const char[] color);

/**
* Called once the plugin is fully loaded and chat data is ready to be parsed.
*
* noreturn
**/
forward void CP_OnReloadChatData();

#if !defined REQUIRE_PLUGIN
public void __pl_chat_processor_SetNTVOptional()
{
	MarkNativeAsOptional("ChatProcessor_GetFlagFormatString");
	MarkNativeAsOptional("ChatProcessor_AddClientTag");
	MarkNativeAsOptional("ChatProcessor_RemoveClientTag");
	MarkNativeAsOptional("ChatProcessor_SwapClientTags");
	MarkNativeAsOptional("ChatProcessor_StripClientTags");
	MarkNativeAsOptional("ChatProcessor_SetTagColor");
	MarkNativeAsOptional("ChatProcessor_SetNameColor");
	MarkNativeAsOptional("ChatProcessor_SetChatColor");
}
#endif

public SharedPlugin __pl_chat_processor =
{
	name = "chat-processor",
	file = "chat-processor.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <discordWebhookAPI>
#include "utilshelper.inc"

#undef REQUIRE_PLUGIN
#tryinclude <ExtendedDiscord>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME "Map Notification"

bool g_bPreMapEnd = false;
bool g_Plugin_ExtDiscord = false;

ConVar g_cvAvatar, g_cvUsername, g_cvColorStart, g_cvColorEnd,
	g_cvWebhook, g_cvWebhookRetry, g_cvChannelType, g_cvThreadName, g_cvThreadID,
	g_cvEndOfMapInfo, g_cvNetPublicAddr, g_cvRedirectURL, g_cvMapThumbailURL,
	g_cvPort, g_cCountBots;

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = "maxime1907, .Rushaway",
	description = "Sends a server info message to discord on map start",
	version = "2.1.3",
	url = "https://github.com/srcdslab/sm-plugin-MapNotification"
};

public void OnPluginStart()
{
	g_cvAvatar = CreateConVar("sm_mapnotification_avatar", "https://avatars.githubusercontent.com/u/110772618?s=200&v=4", "URL to Avatar image.");
	g_cvUsername = CreateConVar("sm_mapnotification_username", "Map Notification", "Discord username.");
	g_cvColorStart = CreateConVar("sm_mapnotification_colors_start", "4244579", "Decimal color code for map START\nHex to Decimal - https://www.binaryhexconverter.com/hex-to-decimal-converter");
	g_cvColorEnd = CreateConVar("sm_mapnotification_colors_end", "11678774", "Decimal color code for map END\nHex to Decimal - https://www.binaryhexconverter.com/hex-to-decimal-converter");
	g_cvEndOfMapInfo = CreateConVar("sm_mapnotification_endmap_info", "1", "Print a notification for the map end.", _, true, 0.0, true, 1.0);
	g_cCountBots = CreateConVar("sm_mapnotification_count_bots", "1", "Should we count bots as players ?[0 = No, 1 = Yes]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvRedirectURL = CreateConVar("sm_mapnotification_redirect", "https://nide.gg/connect/", "URL to your redirect.php file.");
	g_cvMapThumbailURL = CreateConVar("sm_mapnotification_mapthumbailurl", "https://bans.nide.gg/images/maps/", "URL where you store map thumbail files. (.JPG ONLY)");

	g_cvWebhook = CreateConVar("sm_mapnotification_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
	g_cvWebhookRetry = CreateConVar("sm_mapnotification_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
	g_cvChannelType = CreateConVar("sm_mapnotification_channel_type", "0", "Type of your channel: (1 = Thread, 0 = Classic Text channel");

	/* Thread config */
	g_cvThreadName = CreateConVar("sm_mapnotification_threadname", "Map Notifications - Analytics", "The Thread Name of your Discord forums. (If not empty, will create a new thread)", FCVAR_PROTECTED);
	g_cvThreadID = CreateConVar("sm_mapnotification_threadid", "0", "If thread_id is provided, the message will send in that thread.", FCVAR_PROTECTED);
	AutoExecConfig(true);

	RegAdminCmd("sm_mapnotification", Command_ForceMessage, ADMFLAG_ROOT, "Test the discord map notification");

	HookEvent("cs_win_panel_match", Event_WinPanel);
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = false;
}

public void OnMapStart()
{
	g_bPreMapEnd = false;
	CreateTimer(5.0, Timer_SendMessage, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_WinPanel(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEndOfMapInfo)
		return;

	int timeLeft;
	if (!GetMapTimeLeft(timeLeft))
		return;

	if (timeLeft >= 0)
		return;

	g_bPreMapEnd = true;

	CreateTimer(0.1, Timer_SendMessage, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_ForceMessage(int client, int argc)
{
	Timer_SendMessage(INVALID_HANDLE);
	ReplyToCommand(client, "[%s] Executing SendMessage function.", PLUGIN_NAME);
	return Plugin_Handled;
}

public Action Timer_SendMessage(Handle timer)
{
	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
	if (!sWebhookURL[0])
	{
		LogError("[%s] No webhook found or specified.", PLUGIN_NAME);
		return Plugin_Stop;
	}

	/* Webhook UserName */
	char sName[128];
	g_cvUsername.GetString(sName, sizeof(sName));

	/* Webhook Avatar */
	char sAvatar[256];
	g_cvAvatar.GetString(sAvatar, sizeof(sAvatar));

	/* Server Name */
	char sHostname[512];
	ConVar cvar = FindConVar("hostname");
	cvar.GetString(sHostname, sizeof(sHostname));
	delete cvar;

	/* Map Name */
	char sMapName[PLATFORM_MAX_PATH], sMapNameLower[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapName, sizeof(sMapName));
	GetCurrentMap(sMapNameLower, sizeof(sMapNameLower));

	/* Players Count */
	char sCount[64];
	int iMaxPlayers = MaxClients;
	int iConnected = GetClientCount(false);
	if (g_cCountBots.BoolValue)
	{
		ConVar bot = FindConVar("bot_quota");
		int iBots = GetConVarInt(bot);
		iConnected = iConnected - iBots;
		delete bot;
	}
	Format(sCount, sizeof(sCount), "%d/%d", iConnected, iMaxPlayers);

	/* Discord Color Embed */
	int Color = GetColor();

	/* Quick Connect */
	g_cvPort = FindConVar("hostport");
	g_cvNetPublicAddr = FindConVar("net_public_adr");

	char sConnect[256], sURL[256], sNetIP[32], sNetPort[32];
	GetConVarString(g_cvRedirectURL, sURL, sizeof(sURL));

	if (g_cvPort != null)
		GetConVarString(g_cvPort, sNetPort, sizeof (sNetPort));

	if (g_cvNetPublicAddr == null)
		g_cvNetPublicAddr = FindConVar("hostip");

	GetConVarString(g_cvNetPublicAddr, sNetIP, sizeof(sNetIP));

	Format(sConnect, sizeof(sConnect), "[%s:%s](%s?ip=%s&port=%s)", sNetIP, sNetPort, sURL, sNetIP, sNetPort);

	delete g_cvPort;
	delete g_cvNetPublicAddr;

	/* Generate map images */
	char sThumb[256], sThumbailURL[256];
	StringToLowerCase(sMapNameLower);
	GetConVarString(g_cvMapThumbailURL, sThumbailURL, sizeof(sThumbailURL));
	Format(sThumb, sizeof(sThumb), "%s/%s.jpg", sThumbailURL, sMapNameLower);

	/* Let's build the Embed */
	Webhook webhook = new Webhook("");

	char sThreadID[32], sThreadName[WEBHOOK_THREAD_NAME_MAX_SIZE];
	g_cvThreadID.GetString(sThreadID, sizeof sThreadID);
	g_cvThreadName.GetString(sThreadName, sizeof sThreadName);

	bool IsThread = g_cvChannelType.BoolValue;

	if (IsThread) {
		if (!sThreadName[0] && !sThreadID[0]) {
			LogError("[%s] Thread Name or ThreadID not found or specified.", PLUGIN_NAME);
			delete webhook;
			return Plugin_Stop;
		} else {
			if (strlen(sThreadName) > 0) {
				webhook.SetThreadName(sThreadName);
				sThreadID[0] = '\0';
			}
		}
	}

	if (strlen(sName) > 0)
		webhook.SetUsername(sName);
	if (strlen(sAvatar) > 0)
		webhook.SetAvatarURL(sAvatar);
	
	/* Header */
	Embed Embed_1 = new Embed(sHostname);
	Embed_1.SetTimeStampNow();
	Embed_1.SetColor(Color);

	/* Map Image */
	EmbedThumbnail thumbnail1 = new EmbedThumbnail();
	thumbnail1.SetURL(sThumb);
	Embed_1.SetThumbnail(thumbnail1);
	delete thumbnail1;
	
	/* Fields */
	EmbedField Field_Map = new EmbedField();
	Field_Map.SetName("Now Playing:");
	Field_Map.SetValue(sMapName);
	Embed_1.AddField(Field_Map);

	EmbedField Field_Players = new EmbedField();
	Field_Players.SetName("Players:");
	Field_Players.SetValue(sCount);
	Embed_1.AddField(Field_Players);

	if (g_bPreMapEnd)
	{
		char nextMap[64];
		if (!GetNextMap(nextMap, sizeof(nextMap)))
			Format(nextMap, sizeof(nextMap), "Error: can't get nextmap data");

		EmbedField Field_NextMap = new EmbedField();
		Field_NextMap.SetName("Nextmap:");
		Field_NextMap.SetValue(nextMap);
		Field_NextMap.SetInline(false);
		Embed_1.AddField(Field_NextMap);
	}

	EmbedField Field_Connect = new EmbedField();
	Field_Connect.SetName("Quick Connect:");
	Field_Connect.SetValue(sConnect);
	Field_Connect.SetInline(false);
	Embed_1.AddField(Field_Connect);
	
	EmbedFooter Footer = new EmbedFooter("");
	//Footer.SetIconURL("https://github.githubassets.com/images/icons/emoji/unicode/1f55c.png?v8");
	Embed_1.SetFooter(Footer);
	delete Footer;

	/* Generate the Embed */
	webhook.AddEmbed(Embed_1);

	DataPack pack = new DataPack();
	if (IsThread && strlen(sThreadName) <= 0 && strlen(sThreadID) > 0)
		pack.WriteCell(1);
	else
		pack.WriteCell(0);
	pack.WriteString(sWebhookURL);

	/* Push the message */
	webhook.Execute(sWebhookURL, OnWebHookExecuted, pack, sThreadID);
	delete webhook;

	return Plugin_Stop;
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	static int retries = 0;
	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];

	pack.Reset();
	bool IsThreadReply = pack.ReadCell();
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));
	delete pack;
	
	if ((!IsThreadReply && response.Status != HTTPStatus_OK) || (IsThreadReply && response.Status != HTTPStatus_NoContent))
	{
		if (retries < g_cvWebhookRetry.IntValue) {
			PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
			CreateTimer(0.1, Timer_SendMessage, _, TIMER_FLAG_NO_MAPCHANGE);
			retries++;
			return;
		} else {
			if (!g_Plugin_ExtDiscord)
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#if defined _extendeddiscord_included
			else
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#endif
		}
	}

	retries = 0;
}

stock int GetColor()
{
	if (g_bPreMapEnd)
		return g_cvColorEnd.IntValue;
	else
		return g_cvColorStart.IntValue;
}

#include <sourcemod>
#include <discordWebhookAPI>
#include "utilshelper.inc"

#pragma newdecls required

#define WEBHOOK_URL_MAX_SIZE	1000

bool g_bPreMapEnd = false

ConVar 
	g_cvWebhook, 
	g_cvWebhookRetry,
	g_cvEndOfMapInfo, 
	g_cvNetPublicAddr, 
	g_cvRedirectURL,
	g_cvMapThumbailURL,
	g_cvPort,
	g_cCountBots;

public Plugin myinfo = 
{
	name = "MapNotification",
	author = "maxime1907, .Rushaway",
	description = "Sends a server info message to discord on map start",
	version = "2.0.1",
	url = ""
};

public void OnPluginStart()
{
	g_cvWebhook = CreateConVar("sm_mapnotification_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
	g_cvWebhookRetry = CreateConVar("sm_mapnotification_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
	g_cvEndOfMapInfo = CreateConVar("sm_mapnotification_endmap_info", "1", "Print a notification for the map end.", _, true, 0.0, true, 1.0);
	g_cCountBots = CreateConVar("sm_mapnotification_count_bots", "1", "Should we count bots as players ?[0 = No, 1 = Yes]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvRedirectURL = CreateConVar("sm_mapnotification_redirect", "https://nide.gg/connect/", "URL to your redirect.php file.");
	g_cvMapThumbailURL = CreateConVar("sm_mapnotification_mapthumbailurl", "https://bans.nide.gg/images/maps/", "URL where you store map thumbail files.");

	AutoExecConfig(true);

	RegAdminCmd("sm_mapnotification", Command_ForceMessage, ADMFLAG_ROOT, "Test the discord map notification");

	HookEvent("cs_win_panel_match", Event_WinPanel);
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
	if (argc < 1)
		CreateTimer(0.1, Timer_SendMessage, _, TIMER_FLAG_NO_MAPCHANGE);
	ReplyToCommand(client, "[MapNotificaiton] Executing SendMessage function.");
	return Plugin_Handled;
}

public Action Timer_SendMessage(Handle timer)
{
	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
	if (!sWebhookURL[0])
	{
		LogError("[MapNotifications] No webhook found or specified.");
		return Plugin_Handled;
	}

	/* Server Name */
	char sHostname[512];
	ConVar cvar = FindConVar("hostname");
	cvar.GetString(sHostname, sizeof(sHostname));

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

	if (g_cvNetPublicAddr != null)
		GetConVarString(g_cvNetPublicAddr, sNetIP, sizeof(sNetIP));

	Format(sConnect, sizeof(sConnect), "[%s:%s](%s?ip=%s&port=%s)", sNetIP, sNetPort, sURL, sNetIP, sNetPort);

	/* Generate map images */
	char sThumb[256], sThumbailURL[256];
	StringToLowerCase(sMapNameLower);
	GetConVarString(g_cvMapThumbailURL, sThumbailURL, sizeof(sThumbailURL));
	Format(sThumb, sizeof(sThumb), "%s/%s.jpg", sThumbailURL, sMapNameLower);

	/* Let's build the Embed */
	Webhook webhook = new Webhook("");
	webhook.SetUsername("Map Notification");
	webhook.SetAvatarURL("https://avatars.githubusercontent.com/u/110772618?s=200&v=4");
	
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

	/* Push the message */
	webhook.Execute(sWebhookURL, OnWebHookExecuted);
	delete webhook;

	return Plugin_Handled;
}

public void OnWebHookExecuted(HTTPResponse response, any data)
{
	static int retries = 0;

	if (response.Status != HTTPStatus_OK)
	{
		if (retries < g_cvWebhookRetry.IntValue)
		{
			PrintToServer("[MapNotifcations] Failed to send the webhook. Resending it .. (%d/%d)", retries, g_cvWebhookRetry.IntValue);
			CreateTimer(0.1, Timer_SendMessage, _, TIMER_FLAG_NO_MAPCHANGE);
			retries++;
			return;
		}
		else
		{
			LogError("[MapNotifcations] Failed to send the webhook after %d retries, aborting.", retries);
		}
	}

	retries = 0;
}

int GetColor()
{
	if (g_bPreMapEnd)
		return 11678774;
	else
		return 4244579;
}

#include <sourcemod>
#include <colorlib_sample>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Show Online Admins",
    author = "Ilusion9",
    description = "Show online admins by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

#define MAX_GROUPS		65
enum struct GroupInfo
{
	char groupName[64];
	char colorHex;
	int uniqueFlag;
	bool useTranslation;
}

bool g_IsHiddenAdmin[MAXPLAYERS + 1];
GroupInfo g_Groups[MAX_GROUPS];
int g_GroupsArrayLength;

public void OnPluginStart()
{
	LoadTranslations("groups_online.phrases");
	LoadTranslations("groups_name.phrases");
	
	RegAdminCmd("sm_admins", Command_Admins, ADMFLAG_GENERIC, "Usage: sm_admins [visible|hidden] - Show online admins by groups");
}

public void OnConfigsExecuted()
{
	g_GroupsArrayLength = 0;
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/groups_online.cfg");
	KeyValues kv = new KeyValues("Groups"); 
	
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("The configuration file could not be read.");
		return;
	}
	
	if (!kv.JumpToKey("Admin Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"Admin Groups\" section could not be found).");
		return;
	}
	
	GroupInfo group;
	AdminFlag flag;
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char buffer[65];
			kv.GetSectionName(group.groupName, sizeof(GroupInfo::groupName));
			
			kv.GetString("flag", buffer, sizeof(buffer));
			if (!FindFlagByChar(buffer[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.groupName);
				continue;
			}
			
			group.uniqueFlag = FlagToBit(flag);
			kv.GetString("color", buffer, sizeof(buffer));
			if (!CTranslateColor(buffer, group.colorHex))
			{
				group.colorHex = view_as<char>(0x01);
			}
			
			kv.GetString("translation", buffer, sizeof(buffer));
			group.useTranslation = StrEqual(buffer, "yes", false) ? true : false;
			
			g_Groups[g_GroupsArrayLength] = group;
			g_GroupsArrayLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
}

public void OnClientConnected(int client)
{
	g_IsHiddenAdmin[client] = false;
}

public Action Command_Admins(int client, int args)
{
	if (!g_GroupsArrayLength)
	{
		return Plugin_Handled;
	}
	
	if (args)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		
		if (StrEqual(arg, "visible", false))
		{
			if (IsClientMemberOfAnyGroup(client))
			{
				g_IsHiddenAdmin[client] = false;
				CReplyToCommand(client, "[SM] %t", "Visible Admin Command");
			}
			else
			{
				CReplyToCommand(client, "[SM] %t", "No Feature Access");
			}
			
			return Plugin_Handled;
		}
		
		if (StrEqual(arg, "hidden", false))
		{
			if (IsClientMemberOfAnyGroup(client))
			{
				g_IsHiddenAdmin[client] = true;
				CReplyToCommand(client, "[SM] %t", "Hidden Admin Command");
			}
			else
			{
				CReplyToCommand(client, "[SM] %t", "No Feature Access");
			}
			
			return Plugin_Handled;
		}
	}
	
	bool membersOnline = false;
	int groupCount[MAX_GROUPS];
	int groupMembers[MAX_GROUPS][MAXPLAYERS + 1];
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (!IsClientInGame(player) || IsFakeClient(player))
		{
			continue;
		}
		
		for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
		{
			if (!CheckCommandAccess(player, "", g_Groups[groupIndex].uniqueFlag, true))
			{
				continue;
			}
			
			membersOnline = true;
			groupMembers[groupIndex][groupCount[groupIndex]] = player;
			groupCount[groupIndex]++;
			break;
		}
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Admins Online");
		return Plugin_Handled;
	}
	
	membersOnline = false;
	ReplySource replySource = GetCmdReplySource();

	for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (!groupCount[groupIndex])
		{
			continue;
		}
		
		int groupLength;
		char clientName[32], groupName[32], buffer[256], oldBuffer[256];
		
		bool playersShown;
		bool clientHasAccess = CheckCommandAccess(client, "", g_Groups[groupIndex].uniqueFlag, true);
		
		if (replySource == SM_REPLY_TO_CHAT)
		{
			groupLength = CPreFormat(groupName);
			groupName[groupLength] = g_Groups[groupIndex].colorHex;
			groupLength++;
		}
		groupLength = Format(groupName[groupLength], sizeof(groupName) - groupLength, g_Groups[groupIndex].useTranslation ? "%T:\x01" : "%s:\x01", g_Groups[groupIndex].groupName, client);		
		
		for (int index = 0; index < groupCount[groupIndex]; index++)
		{
			int player = groupMembers[groupIndex][index];
			if (g_IsHiddenAdmin[player] && !clientHasAccess)
			{
				continue;
			}
			
			membersOnline = true;
			playersShown = true;
			GetClientName(player, clientName, sizeof(clientName));
			
			if (buffer[0] == '\0')
			{
				strcopy(buffer, sizeof(buffer), clientName);
				continue;
			}
			
			int length = Format(buffer, sizeof(buffer), "%s, %s", buffer, clientName);
			if (groupLength + length > 190)
			{
				ReplyToCommand(client, "%s %s", groupName, oldBuffer);
				strcopy(buffer, sizeof(buffer), clientName);
			}
			
			strcopy(oldBuffer, sizeof(oldBuffer), buffer);
		}
		
		if (playersShown)
		{
			ReplyToCommand(client, "%s %s", groupName, buffer);
		}
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Admins Online");
	}
	
	return Plugin_Handled;
}

bool IsClientMemberOfAnyGroup(int client)
{
	for (int i = 0; i < g_GroupsArrayLength; i++)
	{
		if (CheckCommandAccess(client, "", g_Groups[i].uniqueFlag, true))
		{
			return true;
		}
	}
	
	return false;
}

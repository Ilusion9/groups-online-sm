#include <sourcemod>
#include <sourcecolors>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Show Online Admins",
    author = "Ilusion9",
    description = "Show online admins by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

#define MAX_CHATMESSAGE_LENGTH 190
enum struct GroupInfo
{
	char groupPhrase[128];
	AdminFlag uniqueFlag;
}

bool g_IsHiddenAdmin[MAXPLAYERS + 1];
GroupInfo g_Groups[32];
int g_GroupsArrayLength;
int g_GroupIndex[MAXPLAYERS + 1];

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
	
	char buffer[128];
	GroupInfo group;	
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.groupPhrase, sizeof(GroupInfo::groupPhrase));
			kv.GetString("flag", buffer, sizeof(buffer));
			
			if (!FindFlagByChar(buffer[0], group.uniqueFlag))
			{
				LogError("Invalid flag specified for group: %s", group.groupPhrase);
				continue;
			}
			
			g_Groups[g_GroupsArrayLength] = group;
			g_GroupsArrayLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	OnConfigsExecuted();
}

public void OnClientConnected(int client)
{
	g_IsHiddenAdmin[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	g_GroupIndex[client] = -1;
	
	if (IsFakeClient(client))
	{
		return;
	}
	
	AdminId admin_id = GetUserAdmin(client);
	if (admin_id == INVALID_ADMIN_ID)
	{
		return;
	}
	
	for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (GetAdminFlag(admin_id, g_Groups[groupIndex].uniqueFlag, Access_Effective))
		{
			g_GroupIndex[client] = groupIndex;
			break;
		}
	}
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
	int groupIndex, memberIndex;
	int groupCount[sizeof(g_Groups)];
	int groupMembers[sizeof(g_Groups)][MAXPLAYERS + 1];
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (!IsClientInGame(player) || IsFakeClient(player))
		{
			continue;
		}
		
		groupIndex = g_GroupIndex[player];
		if (groupIndex < 0)
		{
			continue;
		}
		
		groupMembers[groupIndex][groupCount[groupIndex]] = player;
		groupCount[groupIndex]++;
		membersOnline = true;
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Admins Online");
		return Plugin_Handled;
	}
	
	membersOnline = false;
	int groupLength, bufferLength, nameLength;
	char clientName[32], groupName[32], buffer[256];

	for (groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (!groupCount[groupIndex])
		{
			continue;
		}
		
		nameLength = groupLength = bufferLength = 0;
		strcopy(buffer, sizeof(buffer), "");
		
		bool playersShown = false;
		bool clientHasAccess = IsClientMemberOfGroup(client, groupIndex);
		
		groupLength = Format(groupName, sizeof(groupName), "%T", g_Groups[groupIndex].groupPhrase, client);
		for (memberIndex = 0; memberIndex < groupCount[groupIndex]; memberIndex++)
		{
			int player = groupMembers[groupIndex][memberIndex];
			if (g_IsHiddenAdmin[player] && !clientHasAccess)
			{
				continue;
			}
			
			membersOnline = true;
			playersShown = true;
			
			nameLength = Format(clientName, sizeof(clientName), "%N", player);
			if (groupLength + bufferLength + nameLength > 190)
			{
				CReplyToCommand(client, "%s %s", groupName, buffer);
				strcopy(buffer, sizeof(buffer), clientName);
				bufferLength = nameLength;
				continue;
			}
			
			if (buffer[0] == '\0')
			{
				strcopy(buffer, sizeof(buffer), clientName);
				bufferLength = nameLength;
			}
			else
			{
				bufferLength = Format(buffer, sizeof(buffer), "%s, %s", buffer, clientName);
			}
		}
		
		if (playersShown)
		{
			CReplyToCommand(client, "%s %s", groupName, buffer);
		}
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Admins Online");
	}
	
	return Plugin_Handled;
}

bool IsClientMemberOfGroup(int client, int groupIndex)
{
	AdminId admin_id = GetUserAdmin(client);
	if (admin_id == INVALID_ADMIN_ID)
	{
		return false;
	}
	
	return GetAdminFlag(admin_id, g_Groups[groupIndex].uniqueFlag, Access_Effective);
}

bool IsClientMemberOfAnyGroup(int client)
{
	AdminId admin_id = GetUserAdmin(client);
	if (admin_id == INVALID_ADMIN_ID)
	{
		return false;
	}
	
	for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (GetAdminFlag(admin_id, g_Groups[groupIndex].uniqueFlag, Access_Effective))
		{
			return true;
		}
	}
	
	return false;
}

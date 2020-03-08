#include <sourcemod>
#include <colorlib_sample>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Show Online Vips",
    author = "Ilusion9",
    description = "Show online vips by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

enum struct GroupInfo
{
	char groupName[32];
	char colorHex;
	int uniqueFlag;
	bool useTranslation;
}

GroupInfo g_Groups[32];
int g_GroupsArrayLength;

public void OnPluginStart()
{
	LoadTranslations("groups_online.phrases");
	LoadTranslations("groups_name.phrases");
	
	RegConsoleCmd("sm_vips", Command_Vips, "Show online vips by groups");
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
	
	if (!kv.JumpToKey("VIP Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"VIP Groups\" section could not be found).");
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

public Action Command_Vips(int client, int args)
{
	if (!g_GroupsArrayLength)
	{
		return Plugin_Handled;
	}
	
	bool membersOnline = false;
	int groupCount[sizeof(g_Groups)];
	int groupMembers[sizeof(g_Groups)][MAXPLAYERS + 1];
	
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
		CReplyToCommand(client, "%t", "No Vips Online");
		return Plugin_Handled;
	}
	
	int groupLength, bufferLength, nameLength;
	char clientName[32], groupName[32], buffer[256];
	ReplySource replySource = GetCmdReplySource();

	for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (!groupCount[groupIndex])
		{
			continue;
		}
		
		nameLength = groupLength = bufferLength = 0;
		strcopy(buffer, sizeof(buffer), "");

		if (replySource == SM_REPLY_TO_CHAT)
		{
			groupLength = CPreFormat(groupName);
			groupName[groupLength] = g_Groups[groupIndex].colorHex;
			groupLength++;
		}
		
		groupLength += Format(groupName[groupLength], sizeof(groupName) - groupLength, g_Groups[groupIndex].useTranslation ? "%T:\x01" : "%s:\x01", g_Groups[groupIndex].groupName, client);				
		for (int memberIndex = 0; memberIndex < groupCount[groupIndex]; memberIndex++)
		{
			nameLength = Format(clientName, sizeof(clientName), "%N", groupMembers[groupIndex][memberIndex]);
			if (groupLength + bufferLength + nameLength > 190)
			{
				ReplyToCommand(client, "%s %s", groupName, buffer);
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
		
		ReplyToCommand(client, "%s %s", groupName, buffer);
	}
	
	return Plugin_Handled;
}

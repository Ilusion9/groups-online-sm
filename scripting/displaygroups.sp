#include <sourcemod>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Display groups",
    author = "Ilusion9",
    description = "Display admins and vips by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

enum struct GroupInfo
{
	char name[65];
	int flag;
}

ArrayList g_List_AdminGroups;
ArrayList g_List_VipGroups;

public void OnPluginStart()
{
	g_List_AdminGroups = new ArrayList(sizeof(GroupInfo));
	g_List_VipGroups = new ArrayList(sizeof(GroupInfo));

	RegConsoleCmd("sm_groups", Command_Groups);
}

public void OnConfigsExecuted()
{
	g_List_AdminGroups.Clear();
	g_List_VipGroups.Clear();
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/displaygroups.cfg");
	KeyValues kv = new KeyValues("Groups"); 
	
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("The configuration file could not be read.");
		return;
	}
	
	GroupInfo group;
	AdminFlag flag;
	
	if (!kv.JumpToKey("Admin Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"Admin Groups\" section could not be found).");
		return;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.name, sizeof(GroupInfo::name));
			char value[2];
			kv.GetString(NULL_STRING, value, sizeof(value));
			
			if (!FindFlagByChar(value[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.name);
				continue;
			}
			
			group.flag = FlagToBit(flag);
			g_List_AdminGroups.PushArray(group);
			
		} while (kv.GotoNextKey(false));
	}
	
	kv.Rewind();
	if (!kv.JumpToKey("VIP Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"VIP Groups\" section could not be found).");
		return;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.name, sizeof(GroupInfo::name));
			char value[2];
			kv.GetString(NULL_STRING, value, sizeof(value));
			
			if (!FindFlagByChar(value[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.name);
				continue;
			}
			
			group.flag = FlagToBit(flag);
			g_List_VipGroups.PushArray(group);
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
}

public Action Command_Groups(int client, int args)
{
	GroupInfo group;
	bool adminDisplayed[MAXPLAYERS + 1], vipDisplayed[MAXPLAYERS + 1];
	
	for (int i = 0; i < g_List_AdminGroups.Length; i++)
	{
		char buffer[256];
		bool memberFound = false;
		
		g_List_AdminGroups.GetArray(i, group);
		Format(buffer, sizeof(buffer), "%s:", group.name);
		
		for (int j = 1; j <= MaxClients; j++)
		{
			if (IsClientInGame(j))
			{
				if (!adminDisplayed[j])
				{
					if (CheckCommandAccess(j, "", group.flag, true))
					{
						memberFound = true;
						adminDisplayed[j] = true;
						Format(buffer, sizeof(buffer), "%s %N,", buffer, j);
					}
				}
			}
		}
		
		if (memberFound)
		{
			buffer[strlen(buffer) - 1] = 0;
			ReplyToCommand(client, "[SM] %s", buffer);
		}
	}
	
	for (int i = 0; i < g_List_VipGroups.Length; i++)
	{
		char buffer[256];
		bool memberFound = false;
		
		g_List_VipGroups.GetArray(i, group);
		Format(buffer, sizeof(buffer), "%s:", group.name);
		
		for (int j = 1; j <= MaxClients; j++)
		{
			if (IsClientInGame(j))
			{
				if (!vipDisplayed[j])
				{
					if (CheckCommandAccess(j, "", group.flag, true))
					{
						memberFound = true;
						vipDisplayed[j] = true;
						Format(buffer, sizeof(buffer), "%s %N,", buffer, j);
					}
				}
			}
		}
		
		if (memberFound)
		{
			buffer[strlen(buffer) - 1] = 0;
			ReplyToCommand(client, "[SM] %s", buffer);
		}
	}
	
	return Plugin_Handled;
}

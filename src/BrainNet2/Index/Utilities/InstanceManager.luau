--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local projectFolderCache = {}

export type InstanceManagerType = {
	initialize: () -> (),
	getOrCreateProjectFolder: (projectName: string) -> Folder,
	add: <T>(project: Instance, targetInstance: T) -> T,
	get: <T>(project: Instance, instanceName: string) -> T?,
	waitForInstance: <T>(project: Instance, instanceName: string, maxTimeout: number?) -> T?,
	expectInstance: <T>(project: Instance, instanceName: string, maxTimeout: number?) -> T
}

local InstanceManager: InstanceManagerType = {} :: InstanceManagerType

function InstanceManager.initialize()
	for _, folder in ipairs(ReplicatedStorage:GetChildren()) do
		if folder:IsA("Folder") then
			projectFolderCache[folder.Name] = folder
		end
	end
end

function InstanceManager.getOrCreateProjectFolder(projectName: string): Folder
	local folder = projectFolderCache[projectName]
	
	if not folder then
		folder = ReplicatedStorage:FindFirstChild(projectName)
		
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = projectName
			folder.Parent = ReplicatedStorage
			CollectionService:AddTag(folder, "WallyProjectFolder")
		end
		
		projectFolderCache[projectName] = folder
	end
	
	return folder
end

function InstanceManager.add<T>(project: Instance, targetInstance: T): T
	local projectName = project.Name
	local folder = InstanceManager.getOrCreateProjectFolder(projectName)
	
	if typeof(targetInstance) == "Instance" then
		local instance = targetInstance :: Instance
		
		if instance:IsA("ModuleScript") or instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
			CollectionService:AddTag(instance, "WallyManagedInstance")
			CollectionService:AddTag(instance, "Wally_" .. projectName)
		end
		
		instance.Parent = folder
	end
	
	return targetInstance
end

function InstanceManager.get<T>(project: Instance, instanceName: string): T?
	local projectName = project.Name
	local folder = projectFolderCache[projectName]
	
	if not folder then
		folder = ReplicatedStorage:FindFirstChild(projectName)
		if folder then
			projectFolderCache[projectName] = folder
		else
			return nil
		end
	end
	
	local directInstance = folder:FindFirstChild(instanceName)
	
	if directInstance then
		return directInstance
	end
	
	for _, instance in ipairs(CollectionService:GetTagged("WallyManagedInstance")) do
		if instance.Name == instanceName and CollectionService:HasTag(instance, "Wally_" .. projectName) then
			return instance
		end
	end
	
	local deepInstance = folder:FindFirstChild(instanceName, true)
	return deepInstance
end

function InstanceManager.waitForInstance<T>(project: Instance, instanceName: string, maxTimeout: number?): T?
	local startTime = os.clock()
	local projectName = project.Name
	local timeout = maxTimeout or 5
	local projectFolder
	
	projectFolder = projectFolderCache[projectName]
	if not projectFolder then
		projectFolder = ReplicatedStorage:FindFirstChild(projectName)
		if projectFolder then
			projectFolderCache[projectName] = projectFolder
		else
			projectFolder = ReplicatedStorage:WaitForChild(projectName, timeout)
			if projectFolder then
				projectFolderCache[projectName] = projectFolder
			else
				warn("InstanceManager: Timeout waiting for project " .. projectName)
				return nil
			end
		end
	end
	
	local instance = InstanceManager.get(project, instanceName)
	if instance then
		return instance
	end
	
	local elapsedTime = os.clock() - startTime
	local remainingTimeout = timeout - elapsedTime
	
	if remainingTimeout <= 0 then
		warn("InstanceManager: Timeout waiting for " .. instanceName .. " in " .. projectName)
		return nil
	end
	
	local waitedInstance = projectFolder:WaitForChild(instanceName, remainingTimeout)
	return waitedInstance
end

function InstanceManager.expectInstance<T>(project: Instance, instanceName: string, maxTimeout: number?): T
	local instance = InstanceManager.waitForInstance(project, instanceName, maxTimeout)
	assert(instance, "Instance not found: " .. instanceName)
	
	return instance
end

InstanceManager.initialize()
return InstanceManager
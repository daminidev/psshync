local M = {}
local menu = require("psshync.menu")

local projects = {}
local debug = false
local enabled = true

vim.api.nvim_create_user_command('PsshyncTest', function() M.debug() end, {})
vim.api.nvim_create_user_command('PsshyncEnable', function() M.enable() end, {})
vim.api.nvim_create_user_command('PsshyncDisable', function() M.disable() end, {})
vim.api.nvim_create_user_command('PsshyncIsEnabled', function() M.isEnabled() end, {})
vim.api.nvim_create_user_command('PsshyncToggle', function() M.toggle() end, {})
vim.api.nvim_create_user_command('PsshyncGetEnabled', function() return M.getEnabled() end, {})
vim.api.nvim_create_user_command('PsshyncDiff', function() M.checkIfDistantFileDiffers() end, {})
vim.api.nvim_create_user_command('PsshyncMenuTest', function() M.testMenu() end, {})

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*",
  callback = function()
    M.onSave()
  end
})

local s = string

-- add a terminal / if not present (the strategy for paths is to start with no / and have one at the end)
local ensureSlashTerminated = function(path)
  if s.sub(path, -1) ~= "/" then
    path = path .. "/"
  end
  return path
end

-- removes a / at the beginning if present
local ensureNotStartsWithSlash = function (path)
  if s.sub(path, 1, 1) == "/" then
    path = s.sub(path, 2)
  end
  return path
end

-- Returns true if the given filePath is within the given path
-- example : /abc/def.txt is in /abc
local isFileInPath = function (path, filePath)
  path = ensureSlashTerminated(path)
  local sub = s.sub(filePath, 1, s.len(path))
  return sub == path
end

-- Utilitary function : returns the last / position in a given string (a path)
local getLastSlashPos = function (filePath)
  return s.len(filePath) - s.find(s.reverse(filePath), '/', 1, true)
end

-- Returns the subpath that will be used on the distant server
-- example : we want to currentlyEditedFile /home/me/myproject/subdirectory/test.txt to the distant server 
-- given that the sourcePath is /home/me/myproject, we should return subdirectory/
local getDestSubPath = function(currentlyEditedFile, sourcePath)
  sourcePath = ensureSlashTerminated(sourcePath)
  local subPathAndFilename = s.sub(currentlyEditedFile, s.len(sourcePath))
  local lastSlashPos = getLastSlashPos(subPathAndFilename)
  local subPathOnly = s.sub(subPathAndFilename, 1, lastSlashPos)
  subPathOnly = ensureSlashTerminated(subPathOnly)
  return ensureNotStartsWithSlash(subPathOnly)
end

-- Returns the full distant path where we should send our copy
local getDistantPath = function(currentlyEditedFile, project)
  local subDestPath = getDestSubPath(currentlyEditedFile, project.sourcePath)
  local projectSubPath = ensureSlashTerminated(project.destPath)
  return projectSubPath .. subDestPath
end

-- Returns the distant file path that will be ovewrinten 
local getDistantFilePath = function(currentlyEditedFile, project)
  local distantPath = getDistantPath(currentlyEditedFile, project)
  local lastSlashPos = getLastSlashPos(currentlyEditedFile)
  local fileName = s.sub(currentlyEditedFile, lastSlashPos + 1)
  return distantPath .. fileName
end

-- Return the distant server ssh name 
local getSshDest = function(project)
  return project.sshUser .. "@" .. project.sshAddress
end

-- Returns the full distant destination user@sever:/some/distant/path/
local getSshDestination = function (currentlyEditedFile, project)
  local distantPath = getDistantPath(currentlyEditedFile, project)
  local dest = getSshDest(project) .. ":" .. distantPath
  return dest
end

-- Returns the md5sum result (from the beginning to the first space)
local extractMd5Sum = function(shellOutput)
  local firstSpace = s.find(shellOutput, ' ')
  return s.sub(shellOutput, 1, firstSpace)
end

local doCommand = function (currentlyEditedFile, project)
  local dest = getSshDestination(currentlyEditedFile, project)
  vim._system({'scp', currentlyEditedFile, dest})
end

M.debug = function()
  print('Psshync projects : ')
  print(debug)
  for _,project in pairs(projects) do
    print("[" .. project.name .. "] " .. project.sourcePath .. " [enable: " .. tostring(project.enabled) .. "]")
  end
end

M.enable = function()
  enabled = true
  vim.cmd.redrawstatus()
end

M.disable = function()
  enabled = false
  vim.cmd.redrawstatus()
end

M.toggle = function()
  enabled = not(enabled)
  vim.cmd.redrawstatus()
end

M.isEnabled = function()
  local currentState = "[OFF]"
  if enabled then
    currentState = "[ON]"
  end
  print("Psshync is " .. currentState)
end

M.getEnabled = function(path)

  local currentState = " Sync [OFF] "
  local isMatch = false
  local projectName = ""

  for _,project in pairs(projects) do
    isMatch = isFileInPath(project.sourcePath, path)
    if isMatch then
      projectName = project.name
      break
    end
  end
  if enabled and isMatch then
    currentState = " Sync ON for " .. projectName .. " "
  end
  return currentState
end

M.getCurrentFileAndMatchingProject = function()
  local currentlyEditedFile = vim.fn.expand("%:p")
  local projectFound = nil
  for _,project in pairs(projects) do

    local isMatch = isFileInPath(project.sourcePath, currentlyEditedFile)

    if (isMatch) then
      projectFound = project
      break
    end
  end
  return currentlyEditedFile, projectFound
end

M.onSave = function()

  if not(enabled) then
    return
  end

  local currentlyEditedFile, project = M.getCurrentFileAndMatchingProject()

  if nil == project then
    return
  end

  if debug then
    print(" ON : " .. project.name .. " [" .. project.sourcePath .. "]")
  end

  if project and project.enabled then
    doCommand(currentlyEditedFile, project)
  end

end

Dump = function (o)
   if type(o) == 'table' then
      local st = "{ \n"
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         st = st .. '['..k..'] = ' .. M.dump(v) .. ','
      end
      return st .. "\n}\n "
   else
      return tostring(o)
   end
end

M.checkIfDistantFileDiffers = function ()
  local currentlyEditedFile, project = M.getCurrentFileAndMatchingProject()
  local distantFilePath = getDistantFilePath(currentlyEditedFile, project)

  local dest = getSshDest(project)
  local command = "md5sum " .. distantFilePath

  local mdDistant = vim.fn.system {'ssh', dest, command}
  local mdLocal = vim.fn.system {'md5sum', currentlyEditedFile}

  if extractMd5Sum(mdLocal) == extractMd5Sum(mdDistant) then
    -- print("Files are identical")
    menu.show("Files are identical")
    else
    menu.show("Files differs")
    -- print("! Files are different !")
  end
end

M.setup = function(opt)
  debug = opt.debug;
  projects = opt.projects;
  if debug then
    M.debug()
  end
end
M.testMenu = function()
  menu.show("Overwrite local :")
end
return M

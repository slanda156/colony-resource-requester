function checkArgs()
    if args["-h"] or args["--help"] then
        printHelp()
        args["-h"] = nil
        args["--help"] = nil
    end
    if args["--skip-installer-update"] then
        skipInstallerUpdate = true
        args["--skip-installer-update"] = nil
    else
        skipInstallerUpdate = false
    end
    if #args > 0 then
        print("Invalid arguments")
        printHelp()
    end
end

function printHelp()
    print("Usage: ")
    print("install [arguments]")
    print("Arguments:")
    print("-h, --help: Show this help message")
    print("--skip-installer-update: Skip asking for updating the installer")
end

function delFile(file)
    if fs.exists(file) then
        print("Deleting: "..file)
        fs.delete(file)
    end
end

local args = {...}
checkArgs()

term.clear()
term.setCursorPos(1, 1)

if not skipInstallerUpdate then
    print("Do you want to update the installer? (y/n)")
    io.input(io.stdin)
    local updateInstallerInput = io.read()
    if updateInstallerInput == "y" then
        print("Which branch would you like to use?\n[1]: main (default)\n[2]: dev")
        io.input(io.stdin)
        local branchInput = io.read()
        delFile("install.lua")
        if #branchInput == 0 then
            branchInput = "1"
        end
        if branchInput == "1" then -- main
            shell.run("wget", "https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/install.lua", "install.lua")
        elseif branchInput == "2" then -- dev
            shell.run("wget", "https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/install.lua", "install.lua")
        else -- invalid
            print("Invalid branch")
            return
        end
        shell.run("install.lua")
        return
    end
end

print("Which branch would you like to install?\n[1]: main (default)\n[2]: dev")
io.input(io.stdin)
local branchInput = io.read()
local codes = {}
-- ToDo Change codes from def to main when making a pull request
if #branchInput == 0 then
    branchInput = "1"
end
if branchInput == "1" then -- main
    codes["startup.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/startup.lua", true}
    codes["src/widgets.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/widgets.lua", true}
    codes["src/logging.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/logging.lua", true}
    codes["logging.json"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/logging.json", false}
elseif branchInput == "2" then -- dev
    codes["startup.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/startup.lua", true}
    codes["src/widgets.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/widgets.lua", true}
    codes["src/logging.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/logging.lua", true}
    codes["src/function.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/function.lua", true}
    codes["logging.json"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/logging.json", false}
else -- invalid
    print("Invalid branch")
    return
end

local numDownloads = 0
for f, c in pairs(codes) do
    if c[2] then
        numDownloads = numDownloads + 1
    else
        if not fs.exists(f) then
            numDownloads = numDownloads + 1
        end
    end
end

print("Do you want to download "..numDownloads.." files? (y/n)")
io.input(io.stdin)
local downloadInput = io.read()
if downloadInput ~= "y" then
    print("Exiting")
    return
end

local replaceAll = false
print("Do you want to replace config files? (y/n)")
io.input(io.stdin)
local replaceInput = io.read()
if replaceInput == "y" then
    replaceAll = true
end

for f, c in pairs(codes) do
    if c[2] or replaceAll then
        delFile(f)
    end
    print("Downloading: "..f)
    if c[2] or replaceAll then
        shell.run("wget", c[1], f)
    else
        if fs.exists(f) then
            print("Skipping: "..f)
        else
            shell.run("wget", c[1], f)
        end
    end
end

print("Done")

local reboot = false
print("Do you want to reboot? (y/n)")
io.input(io.stdin)
local rebootInput = io.read()
if rebootInput == "y" then
    reboot = true
end
if reboot then
    shell.run("reboot")
end
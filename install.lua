function checkArgs(arguments)
    local args = {}
    for _, arg in ipairs(arguments) do
        if string.sub(arg, 1, 1) == "-" or string.sub(arg, 1, 2) == "--" then
            args[arg] = true
        else
            table.insert(args, arg)
        end
    end
    if args["-h"] or args["--help"] then
        printHelp()
        args["-h"] = nil
        args["--help"] = nil
        return true
    end
    if args["-y"] or args["--yes"] then
        skipQuestions = true
        args["-y"] = nil
        args["--yes"] = nil
    else
        skipQuestions = false
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
    return false
end

function printHelp()
    print("Usage: ")
    print("    install [arguments]")
    print("Arguments:")
    print("    -h, --help: Show this help message")
    print("    -y, --yes: Skip questions & use default")
    print("    --skip-installer-update: Skip installer update")
end

function delFile(file)
    if fs.exists(file) then
        print("Deleting: "..file)
        fs.delete(file)
    end
end

local args = {...}
if checkArgs(args) then
    return
end

term.clear()
term.setCursorPos(1, 1)

if not skipInstallerUpdate then
    if not skipQuestions then
        print("Do you want to update the installer? (y/n)")
        io.input(io.stdin)
        updateInstallerInput = io.read()
    else
        updateInstallerInput = "y"
    end
    if updateInstallerInput == "y" then
        if not skiptQuestions then
            print("Which branch would you like to use?\n[1]: main (default)\n[2]: dev")
            io.input(io.stdin)
            branchInput = io.read()
        else
            branchInput = "1"
        end
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
        shell.run("install.lua", "--skip-installer-update")
        return
    end
end

if not skipQuestions then
    print("Which branch would you like to install?\n[1]: main (default)\n[2]: dev")
    io.input(io.stdin)
    branchInput = io.read()
else
    branchInput = "1"
end
codes = {}
-- ToDo Change codes from def to main when making a pull request
if #branchInput == 0 then
    branchInput = "1"
end
if branchInput == "1" then -- main
    codes["startup.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/startup.lua"}
    codes["src/widgets.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/widgets.lua"}
    codes["src/logging.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/logging.lua"}
    codes["src/function.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/function.lua"}
    codes["logging.json"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/logging.json"}
elseif branchInput == "2" then -- dev
    codes["startup.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/startup.lua"}
    codes["src/widgets.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/widgets.lua"}
    codes["src/logging.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/logging.lua"}
    codes["src/function.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/function.lua"}
else -- invalid
    print("Invalid branch")
    return
end

numDownloads = 0
for f, c in pairs(codes) do
    numDownloads = numDownloads + 1
end

if not skipQuestions then
    print("Do you want to download "..numDownloads.." files? (y/n)")
    io.input(io.stdin)
    downloadInput = io.read()
    if downloadInput ~= "y" then
        print("Exiting")
        return
    end
end

for f, c in pairs(codes) do
    delFile(f)
    print("Downloading: "..f)
    shell.run("wget", c[1], f)
end

print("Done")

reboot = true
if not skipQuestions then
    print("Do you want to reboot? (y/n)")
    io.input(io.stdin)
    rebootInput = io.read()
    if rebootInput ~= "y" then
        reboot = false
    end
end
if reboot then
    shell.run("reboot")
end

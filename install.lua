function delFile(file)
    if fs.exists(file) then
        print("Deleting: "..file)
        fs.delete(file)
    end
end


print("Which branch would you like to install? ([0]: main, [1]: dev)")
io.input(io.stdin)
local branchInput = io.read()
local codes = {}
if branchInput == "0" then -- main
    codes["startup.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/startup.lua", true}
    codes["src/widgets.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/widgets.lua", true}
    codes["src/logging.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/logging.lua", true}
    codes["logging.json"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/logging.json", false}
elseif branchInput == "1" then -- dev
    codes["startup.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/startup.lua", true}
    codes["src/widgets.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/widgets.lua", true}
    codes["src/logging.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/dev/src/logging.lua", true}
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
print("Do you want to replace all files? (y/n)")
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
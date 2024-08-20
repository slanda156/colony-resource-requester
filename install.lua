function delFile(file)
    if fs.exists(file) then
        print("Deleting: "..file)
        fs.delete(file)
    end
end

local codes = {}
codes["startup.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/startup.lua", true}
codes["src/widgets.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/widgets.lua", true}
codes["src/logging.lua"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/src/logging.lua", true}
codes["logging.json"] = {"https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/logging.json", false}

for f, c in pairs(codes) do
    if c[2] then
        delFile(f)
    end
    print("Downloading: "..f)
    if c[2] then
        shell.run("wget", c[1], f)
    else
        if fs.exists(f) then
            print("Skipping: "..f)
        else
            shell.run("wget", c[1], f)
        end
    end
end

print("Done, Rebooting")

shell.run("reboot")

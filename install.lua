function delFile(file)
    if fs.exists(file) then
        print("Deleting: "..file)
        fs.delete(file)
    end
end

local codes = {}
codes["startup.lua"] = "https://raw.githubusercontent.com/slanda156/colony-resource-requester/main/startup.lua"

for f, c in pairs(codes) do
    delFile(f)
    print("Downloading: "..f)
    shell.run("wget", c, f)
end

print("Done, Rebooting")

shell.run("reboot")

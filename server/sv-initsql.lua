local Config <const> = require "config.config"

local SQL_FILE <const> = 'INSTALL/insert-me.sql'

local function parseStatements(content)
    local statements = {}

    for statement in content:gmatch("[^;]+") do
        local lines = {}

        for line in statement:gmatch("[^\r\n]+") do
            line = Trim(line)

            if line ~= "" and not line:match("^%-%-") and not line:match("^#") then
                lines[#lines + 1] = line
            end
        end

        if #lines > 0 then
            statements[#statements + 1] = table.concat(lines, " ")
        end
    end

    return statements
end

function InitSQL()
    if not Config.AutoRunSQL then return end

    local content = LoadResourceFile(GetCurrentResourceName(), SQL_FILE)
    if not content or content == "" then return end

    local statements = parseStatements(content)
    if #statements == 0 then return end

    local ok, err = pcall(MySQL.transaction.await, statements)

    if not ok then
        print(("^1[SQL ERROR] Running '%s' automatically failed (%s). Run it manually, or set AutoRunSQL = false if it's already installed.^0")
            :format(SQL_FILE, tostring(err)))
        return
    end

    Debug("success", "ran %d statement(s) from '%s'", #statements, SQL_FILE)
end

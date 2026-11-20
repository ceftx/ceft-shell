-- Decodificador JSON mínimo (objetos, listas, strings, números, true/false/null).
-- Lo usa ceft para leer overrides.json (lo escribe el Centro de control).
local M = {}

local escapes = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }

local function decode(s)
    local i = 1
    local function err(msg) error(("json: %s en la posición %d"):format(msg, i), 0) end
    local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
    local value

    local function str()
        i = i + 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == "" then err("string sin cerrar") end
            if c == '"' then i = i + 1; return table.concat(out) end
            if c == "\\" then
                local e = s:sub(i + 1, i + 1)
                if e == "u" then
                    local cp = tonumber(s:sub(i + 2, i + 5), 16) or err("\\u inválido")
                    out[#out + 1] = utf8.char(cp); i = i + 6
                else
                    out[#out + 1] = escapes[e] or err("escape inválido"); i = i + 2
                end
            else
                local j = s:find('["\\]', i) or #s + 1
                out[#out + 1] = s:sub(i, j - 1); i = j
            end
        end
    end

    function value()
        ws()
        local c = s:sub(i, i)
        if c == "{" then
            i = i + 1; local t = {}; ws()
            if s:sub(i, i) == "}" then i = i + 1; return t end
            while true do
                ws(); if s:sub(i, i) ~= '"' then err("se esperaba una clave") end
                local k = str(); ws()
                if s:sub(i, i) ~= ":" then err("se esperaba ':'") end
                i = i + 1; t[k] = value(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "}" then return t elseif d ~= "," then err("se esperaba ',' o '}'") end
            end
        elseif c == "[" then
            i = i + 1; local t = {}; ws()
            if s:sub(i, i) == "]" then i = i + 1; return t end
            while true do
                t[#t + 1] = value(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "]" then return t elseif d ~= "," then err("se esperaba ',' o ']'") end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == "true"  then i = i + 4; return true
        elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
        elseif s:sub(i, i + 3) == "null"  then i = i + 4; return nil
        else
            local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
            if not num or num == "" then err("valor inesperado '" .. c .. "'") end
            i = i + #num; return tonumber(num)
        end
    end

    local v = value(); ws()
    if i <= #s then err("texto sobrante") end
    return v
end

function M.decode(s) return decode(s) end

function M.read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("a"); f:close()
    if s:match("^%s*$") then return nil end
    return decode(s)
end

return M

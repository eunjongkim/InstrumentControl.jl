export set_user, get_user

# Some functions for user handling.
function validate_username(username)
    (username in listusers()) ||
        error("username not found in database.")
end

function listusers()
    io = IOBuffer()
    serialize(io, ICCommon.ListUsersRequest())
    ZMQ.send(dbsock[], ZMQ.Message(io))

    msg = ZMQ.recv(dbsock[])
    out = convert(IOStream, msg)
    seekstart(out)
    deserialize(out)
end

function set_user(username)
    validate_username(username)
    confd["username"] = username
end

get_user() = confd["username"]

# Load package configuration into a dictionary `confd`.
const confpath = joinpath(dirname(dirname(@__FILE__)), "deps", "config.json")
if isfile(confpath)
    const confd = JSON.parsefile(confpath)
    if !haskey(confd, "dbserver")
        error("set `dbserver` key in $(confpath) to have a valid ",
            "ZeroMQ connection string.")
    elseif !haskey(confd, "archivepath")
        error("set `archivepath` key in $(confpath) to the folder where ",
            "data should be archived. There should be an array of strings, ",
            "with each string representing a path component. The string ",
            "__homedir__ indicates the user's home directory.")
    end
    if !haskey(confd, "username")
        confd["username"] = "default"
    end
    if !haskey(confd, "notifications")
        confd["notifications"] = false
    end

    for (i,x) in enumerate(confd["archivepath"])
        if x == "__homedir__"
            confd["archivepath"][i] = homedir()
            break
        end
    end
    confd["archivepath"] = joinpath(confd["archivepath"]...)

    if !isdir(confd["archivepath"])
        error("`archivepath` key does not refer to an existing directory. ",
            "Please change the path or create a directory at ",
            "$(confd["archivepath"])")
    end
else
    error("configuration file not found at $(confpath).")
end

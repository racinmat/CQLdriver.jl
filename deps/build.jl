using Libdl
using Pkg.Artifacts

if !(Sys.islinux() || Sys.iswindows())
    error("This package does not support OSX or Windows")
end

version = "2.15.3"
const has_driver = !isempty(Libdl.find_library(["libcassandra"]))
const has_yum = try success(`yum --version`) catch e false end
const has_apt = try success(`apt-get -v`) && success(`apt-cache -v`) catch e false end

if has_driver
    println("Cassandra CPP driver already installed.")
elseif has_yum
    cass_target =  @artifact_str "centos_driver_$version"
    inst = try success(`sudo yum install -y $cass_target`) catch e false end
    !inst && error("Unable to install CPP driver.")
elseif has_apt
    ubuntu_version = chomp(read(pipeline(`cat /etc/os-release`, `grep -Eo "VERSION_ID=\"[0-9\.]+\""`, `grep -Eo "[^\"]+"`, `grep -E "[0-9.]+"`), String))
    cass_target =  @artifact_str "ubuntu_$(ubuntu_version)_driver_$version"
    libuv_target = @artifact_str "ubuntu_$(ubuntu_version)_libuv_1.23.0"
    libuv_inst = success(`sudo dpkg -i $libuv_target`)
    !libuv_inst && error("Unable to install libuv driver.")
    inst = try success(`sudo dpkg -i $cass_target`) catch e false end
    !inst && error("Unable to install CPP driver.")
elseif Sys.iswindows()
    Libdl.dllist()
    cass_target = @artifact_str "windows_driver_$version"
    push!(Libdl.DL_LOAD_PATH, cass_target)
else
    error("This package requires cassandra-cpp-driver to be installed, but the build system only understands apt and yum.")
end

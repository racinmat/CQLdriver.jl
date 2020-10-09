using Pkg.Artifacts
using SHA
using Pkg.BinaryPlatforms
using HTTP

# This is the path to the Artifacts.toml we will manipulate
artifacts_toml = joinpath(dirname(@__DIR__), "Artifacts.toml")

match_versions = r"href=\"v(?<version>\d\.\d{1,2}.\d{1,2})\/\""
driver_site = "http://downloads.datastax.com/cpp-driver"
const CENTOS_VERSIONS = let
    versions_page = String(HTTP.get("$driver_site/centos/7/cassandra/").body)
    [m[:version] for m in eachmatch(match_versions, versions_page)]
end

const UBUNTU_12_VERSIONS = let
    versions_page = String(HTTP.get("$driver_site/ubuntu/12.04/cassandra/").body)
    [m[:version] for m in eachmatch(match_versions, versions_page)]
end

const UBUNTU_14_VERSIONS = let
    versions_page = String(HTTP.get("$driver_site/ubuntu/14.04/cassandra/").body)
    [m[:version] for m in eachmatch(match_versions, versions_page)]
end

const UBUNTU_16_VERSIONS = let
    versions_page = String(HTTP.get("$driver_site/ubuntu/16.04/cassandra/").body)
    [m[:version] for m in eachmatch(match_versions, versions_page)]
end

const UBUNTU_18_VERSIONS = let
    versions_page = String(HTTP.get("$driver_site/ubuntu/18.04/cassandra/").body)
    [m[:version] for m in eachmatch(match_versions, versions_page)]
end

const WINDOWS_VERSIONS = let
    versions_page = String(HTTP.get("$driver_site/windows/cassandra/").body)
    [m[:version] for m in eachmatch(match_versions, versions_page)]
end

const VERSIONS = union(CENTOS_VERSIONS, UBUNTU_12_VERSIONS, UBUNTU_14_VERSIONS, UBUNTU_16_VERSIONS, UBUNTU_18_VERSIONS, WINDOWS_VERSIONS)

driver_url = "$driver_site/centos/7/cassandra/v$version/$prefix-$version-1.el7.centos.x86_64.rpm"
bind_driver!(version, version_name, driver_url::AbstractString) = bind_driver!(version, version_name, [driver_url])
function bind_driver!(version, version_name, driver_urls::Vector)
    # Query the `Artifacts.toml` file for the hash bound to the specific version
    # (returns `nothing` if no such binding exists)
    latest_hash = artifact_hash(version_name, artifacts_toml)

    # If the name was not bound, or the hash it was bound to does not exist, create it!
    if isnothing(latest_hash) || !artifact_exists(latest_hash)
        ok_urls = filter(d->HTTP.get(d, status_exception=false).status != 404, driver_urls)
        isempty(ok_urls) && return
        driver_url = first(ok_urls)
        ### centos ###
        # create_artifact() returns the content-hash of the artifact directory once we're finished creating it
        cass_target = "cassandra-cpp-driver" * splitext(driver_url)
        hash = create_artifact() do artifact_dir
            download(driver_url, joinpath(artifact_dir, cass_target))
        end
        download_dir = artifact_path(hash)
        content_sha = open(joinpath(download_dir, cass_target)) do f
           bytes2hex(sha256(f))
        end
        download_info = [(driver_url, content_sha)]
        # Now bind that hash within our `Artifacts.toml`.  `force = true` means that if it already exists,
        # just overwrite with the new content-hash.  Unless the source files change, we do not expect
        # the content hash to change, so this should not cause unnecessary version control churn.
        # since Artifacts does not distinguish between ubuntu and centos, which have different binaries,
        # I'm going to have different names for different platforms
        bind_artifact!(artifacts_toml, version_name, hash; download_info=download_info, lazy=true, force=true)
    end
end

centos_url(version, suffix) = "$driver_site/centos/7/cassandra/v$version/$prefix-$version-1.el7.centos.x86_64.rpm"
win_url(version, suffix) = "$driver_site/windows/cassandra/v$version/$prefix-$version-$suffix"

bind_libuv!(version, version_name, driver_url::AbstractString) = bind_libuv!(version, version_name, [driver_url])
function bind_libuv!(version, version_name, driver_urls::Vector)
    # Query the `Artifacts.toml` file for the hash bound to the specific version
    # (returns `nothing` if no such binding exists)
    latest_hash = artifact_hash(version_name, artifacts_toml)

    # If the name was not bound, or the hash it was bound to does not exist, create it!
    if isnothing(latest_hash) || !artifact_exists(latest_hash)
        ok_urls = filter(d->HTTP.get(d, status_exception=false).status != 404, driver_urls)
        isempty(ok_urls) && return
        driver_url = first(ok_urls)
        ### centos ###
        # create_artifact() returns the content-hash of the artifact directory once we're finished creating it
        cass_target = "libuv1.deb"
        hash = create_artifact() do artifact_dir
            download(driver_url, joinpath(artifact_dir, cass_target))
        end
        download_dir = artifact_path(hash)
        content_sha = open(joinpath(download_dir, cass_target)) do f
           bytes2hex(sha256(f))
        end
        download_info = [(driver_url, content_sha)]
        # Now bind that hash within our `Artifacts.toml`.  `force = true` means that if it already exists,
        # just overwrite with the new content-hash.  Unless the source files change, we do not expect
        # the content hash to change, so this should not cause unnecessary version control churn.
        # since Artifacts does not distinguish between ubuntu and centos, which have different binaries,
        # I'm going to have different names for different platforms
        bind_artifact!(artifacts_toml, version_name, hash; download_info=download_info, lazy=true, force=true)
    end
end

prefix = "cassandra-cpp-driver"

for version in VERSIONS
    version ∈ CENTOS_VERSIONS && bind_driver!(version, "centos_driver_$version", [centos_url(version, "1.el7.centos.x86_64.rpm"), centos_url(version, "1.el7.x86_64.rpm")])
    version ∈ WINDOWS_VERSIONS && bind_driver!(version, "windows_driver_$version", [win_url(version, "win64-msvc142.zip"), win_url(version, "win64-msvc141.zip"), win_url(version, "win64-msvc140.zip"), win_url(version, "win64-msvc120.zip")])
    version ∈ UBUNTU_12_VERSIONS && bind_driver!(version, "ubuntu_12_driver_$version", "$driver_site/ubuntu/12.04/cassandra/v$version/$(prefix)_$version-1_amd64.deb")
    version ∈ UBUNTU_14_VERSIONS && bind_driver!(version, "ubuntu_14_driver_$version", "$driver_site/ubuntu/14.04/cassandra/v$version/$(prefix)_$version-1_amd64.deb")
    version ∈ UBUNTU_16_VERSIONS && bind_driver!(version, "ubuntu_16_driver_$version", "$driver_site/ubuntu/16.04/cassandra/v$version/$(prefix)_$version-1_amd64.deb")
    version ∈ UBUNTU_18_VERSIONS && bind_driver!(version, "ubuntu_18_driver_$version", "$driver_site/ubuntu/18.04/cassandra/v$version/$(prefix)_$version-1_amd64.deb")
end

bind_libuv!("1.23.0", "ubuntu_12_libuv_1.23.0", "$driver_site/ubuntu/18.04/dependencies/libuv/v1.23.0/libuv1_1.23.0-1_amd64.deb")
bind_libuv!("1.23.0", "ubuntu_14_libuv_1.23.0", "$driver_site/ubuntu/18.04/dependencies/libuv/v1.23.0/libuv1_1.23.0-1_amd64.deb")
bind_libuv!("1.23.0", "ubuntu_16_libuv_1.23.0", "$driver_site/ubuntu/18.04/dependencies/libuv/v1.23.0/libuv1_1.23.0-1_amd64.deb")
bind_libuv!("1.23.0", "ubuntu_18_libuv_1.23.0", "$driver_site/ubuntu/18.04/dependencies/libuv/v1.23.0/libuv1_1.23.0-1_amd64.deb")

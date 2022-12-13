package group

docker_license_count := 25
docker_license_warn := 20
seats_taken := count(input["docker-desktop-admin"]) + count(input["docker-desktop-user"])

deny[msg] {
    seats_taken > docker_license_count
    msg = sprintf("The number of members (%v) exceeds the number of available licenses (%v).", [seats_taken, docker_license_count])
}

warn[msg] {
    seats_taken >= docker_license_warn ; seats_taken <= docker_license_count
    msg = sprintf("Please, be aware that %v of the available %v licenses have been used.", [seats_taken, docker_license_count])
}
#!/usr/bin/env bash
set -euo pipefail

TOOL_NAME="tuist"
TOOL_TEST="tuist --help"

GH_REPO="https://github.com/tuist/tuist"
ARTIFACTORY_REPO="https://repo.artifactory-dogen.group.echonet/artifactory/Tuist"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# If we find the "BNPP Root Interception Externe" certificate in Keychain,
# that mean we're in managed environment… so we use Artifactory,
# otherwise we use Github for our download.
if security find-certificate -c "BNPP Root Interception Externe" > /dev/null; then
	DOWNLOAD_BASE_URL=$ARTIFACTORY_REPO

	if [ -n "${HOMEBREW_DOCKER_REGISTRY_BASIC_AUTH_TOKEN:-}" ]; then
		curl_opts=("${curl_opts[@]}" -H "Authorization: Basic $HOMEBREW_DOCKER_REGISTRY_BASIC_AUTH_TOKEN")
	else
		echo "Please make sure that your mac is properly configured to access Artifactory:"
		echo "- https://bnpp-lbc.atlassian.net/wiki/spaces/RH/pages/4263739396"
		echo "- https://github.com/TMD-DX-Mobile/workstation-toolbox"
		exit 1
	fi
else
	DOWNLOAD_BASE_URL=$GH_REPO

	if [ -n "${GITHUB_API_TOKEN:-}" ]; then
		curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
	fi
fi

list_github_tags_sorted() {
	git -c 'versionsort.suffix=-beta' ls-remote --tags --refs --sort version:refname "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' | # NOTE: You might want to adapt this sed to remove non-version strings from tags
		grep -v "@"    # Filtering out tags with @ tied to non-CLI releases
}

list_all_versions_sorted() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if tuist has other means of determining installable versions.
	list_github_tags_sorted
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

	url="$DOWNLOAD_BASE_URL/releases/download/${version}/tuist.zip"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		# TODO: Assert tuist executable exists.
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

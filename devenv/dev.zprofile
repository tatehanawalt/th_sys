#!/usr/bin/env zsh

printf "ⓘ core-infra coredev zprofile:\n"
printf "ⓘ ${0:A:h}:\n"


# unlink broken symlinks
function unlink_broken_syms {
	while [ ${#@} -gt 0 ]; do
		if [ -L "$1" ]; then
			if [ ! -e "$1" ] ; then
				printf "prune $1\n"
				unlink "$1"
			fi
		fi
		shift
	done
	return 0
}

# INFO:
# -----------------------------------------------------------------------------
# path of this script: ${0:A}
# path of this dir:    ${0:A:h}

case "$OSTYPE" in
	darwin*) ;;
	*)
		printf "⚠\tinit\tSHELL not darwin\n" 1>&2
		return 1
		;;
esac
printf "ⓘ\tcheck\t✔ darwin\n"

# CHECK zsh
# -----------------------------------------------------------------------------
if [ "${SHELL#*zsh}" = "$SHELL" ]; then
	printf "⚠\tinit\tSHELL not zsh\n" 1>&2
	return 1
fi
printf "ⓘ\tcheck\t✔ zsh\n"

# CHECK git
# -----------------------------------------------------------------------------
command git &> /dev/null
if [ $? -ne 1 ]; then
	printf "⚠\tinit\tgit not detected\n" 1>&2
	printf "⚠\tinit\tYou must install git manually\n" 1>&2
	return 1
fi

# CHECK brew
# -----------------------------------------------------------------------------
# command brew writes usage (exit code 1) if brew is on the system
command brew &> /dev/null
if [ $? -ne 1 ]; then
	printf "ⓘ\tinit\tbrew not detected\n"
	printf "ⓘ\tinit\tbrew installing\n"
	printf "\n"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	printf "\n"
	command brew &> /dev/null
	if [ $? -ne 1 ]; then
		printf "⚠\tinit\tbrew install failed\n" 1>&2
		return 1
	fi
fi
printf "ⓘ\tcheck\t✔ brew\n"

# CHECK git (non apple)
# -----------------------------------------------------------------------------
GIT_VER_STR=$(command git --version)
if [ "${GIT_VER_STR#*Apple}" != "$GIT_VER_STR" ]; then
	printf "ⓘ\tinit\tgit detected apple git\n" 1>&2
	printf "ⓘ\tinit\tinstalling git (non-apple)\n" 1>&2
	printf "\n"
	command brew install git
	brew_install_exit_code=$?
	printf "\n"
	if [ $brew_install_exit_code -ne 0 ]; then
		printf "⚠\tinit\tgit non-apple install failed\n" 1>&2
		return 1
	fi
	printf "ⓘ\tinit\tinstalled non-apple git\n" 1>&2
	printf "ⓘ\tinit\trestart your shell\n" 1>&2
	return 1
fi
git config --global init.defaultBranch main   # default branch
git config --global pull.ff only              # fast forward
git config --global push.default current      # automatically set upstream
printf "ⓘ\tcheck\t✔ git\n"

# CHECK atom
# -----------------------------------------------------------------------------
command apm &> /dev/null
if [ $? -ne 0 ]; then
	printf "ⓘ\tinit\tatom not detected\n"
	printf "ⓘ\tinit\tatom installing\n"
	printf "\n"
	brew install atom
	printf "\n"
	command apm &> /dev/null
	if [ $? -ne 0 ]; then
		printf "⚠\tinit\tatom install failed\n" 1>&2
		return 1
	fi
fi
printf "ⓘ\tcheck\t✔ atom\n"

# CHECK atom styles.less file
# -----------------------------------------------------------------------------
atom_styles_path="$HOME/.atom/styles.less"
unlink_broken_syms $atom_styles_path &> /dev/null
if [ -f "${atom_styles_path:A}" ]; then
	if [ "${atom_styles_path:A}" != "${0:A:h}/styles.less" ]; then
		[ -L "$atom_styles_path" ] && unlink "$atom_styles_path"
		[ -f "$atom_styles_path" ] && rm -f "$atom_styles_path"
	fi
fi
if [ ! -f "$atom_styles_path" ]; then
	ln -s "${0:A:h}/styles.less" "$atom_styles_path"
	printf "ⓘ\tcheck\tsymlinked styles.less ~/.atom/styles.less\n"
fi
printf "ⓘ\tcheck\t✔ atom styles.less\n"

# CHECK atom minimal
# -----------------------------------------------------------------------------
if [ -z "$(apm ls | grep minimap | sed 's/.* //')" ]; then
	printf "ⓘ\tinit\tinstalling atom minimap\n"
	printf "ⓘ\tinit\t(may take a few minutes)\n"
	printf "\n"
	command apm install minimap
	printf "\n"
	if [ -z "$(apm ls | grep minimap | sed 's/.* //')" ]; then
		printf "⚠\tinit\tatom minimap install failed\n" 1>&2
		return 1
	fi
fi
printf "ⓘ\tcheck\t✔ atom minimap\n"

# CHECK atom teletype
# -----------------------------------------------------------------------------
if [ -z "$(apm ls | grep teletype | sed 's/.* //')" ]; then
	printf "ⓘ\tinit\tinstalling atom teletype package\n"
	printf "ⓘ\tinit\t(may take a few minutes)\n"
	printf "\n"
	command apm install teletype
	printf "\n"
	if [ -z "$(apm ls | grep teletype | sed 's/.* //')" ]; then
		printf "⚠\tinit\tatom teletype install failed\n" 1>&2
		return 1
	fi
fi
printf "ⓘ\tcheck\t✔ atom teletype\n"

# CHECK atom atom-beautify
# -----------------------------------------------------------------------------
if [ -z "$(apm ls | grep atom-beautify | sed 's/.* //')" ]; then
	printf "ⓘ\tinit\tinstalling atom atom-beautify\n"
	printf "ⓘ\tinit\t(may take a few minutes)\n"
	printf "\n"
	command apm install atom-beautify
	printf "\n"
	if [ -z "$(apm ls | grep atom-beautify | sed 's/.* //')" ]; then
		printf "⚠\tinit\tatom atom-beautify install failed\n" 1>&2
		return 1
	fi
fi
printf "ⓘ\tcheck\t✔ atom atom-beautify\n"

# CHECK gem env (required for rubocop)
# -----------------------------------------------------------------------------
if [ -z "$GEM_HOME" ]; then
	export GEM_HOME="$HOME/.gem"
	if [ ! -d "$GEM_HOME" ]; then
		printf "⚠\tinit\tGEM_HOME=%s\n" "$GEM_HOME" 1>&2
		printf "⚠\tinit\tpath is not a directory\n" 1>&2
		return 1
	fi
fi
# Add gem home to path
[ "${PATH#*$GEM_HOME}" = "$PATH" ] && PATH="$GEM_HOME/bin:$PATH"

# CHECK rubocop
# -----------------------------------------------------------------------------
command which rubocop &> /dev/null
if [ $? -ne 0 ]; then
	printf "ⓘ\tinit\tinstalling rubocop\n"
	printf "ⓘ\tinit\t(may take a few minutes)\n"
	printf "\n"
	command gem install rubocop
	printf "\n"
	command which rubocop &> /dev/null
	if [ $? -ne 0 ]; then
		printf "⚠\tinit\trubocop install failed\n" 1>&2
		return 1
	fi
fi
printf "ⓘ\tcheck\t✔ rubocop\n"

# Directory Permissions:
# -----------------------------------------------------------------------------
[ -d /usr/local/share/zsh ] && chmod -R 755 /usr/local/share/zsh
[ -d site-functions ] && chmod -R 755 site-functions

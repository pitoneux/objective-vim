#!/bin/bash

objvim_prefix=~/objvim
objvim_log=/tmp/objvim.log

vim_dir=${objvim_prefix}/share/vim/vim73
vim_bundle_dir=${vim_dir}/bundle

yaml_options=()
ruby_options=(
	--program-prefix=objvim_
	--enable-shared
	)
vim_options=(
	--with-features=huge
	--enable-rubyinterp=yes
	--with-ruby-command="${objvim_prefix}/bin/objvim_ruby"
	--enable-pythoninterp
	--with-python-config-dir=/usr/lib/python*/config
	--enable-tclinterp
	--with-tclsh=/usr/bin/tclsh
	--enable-perlinterp
	)

function set_up_environment() {
	export CFLAGS="-I${objvim_prefix}/include"
	export LDFLAGS="-L${objvim_prefix}/lib"
}

function unpack() {
	rm -rf "$1"*
	tar xzf src/"$1"*.tar.gz
}

function configure_and_make() {
	set_up_environment
	./configure --prefix=${objvim_prefix} "$@" >>$objvim_log 2>&1
	make >>$objvim_log 2>&1
	make install >>$objvim_log 2>&1
}

function build() {
	local package=$1
	printf 'Building %s... ' $package
	unpack $package
	pushd ${package}* >/dev/null 2>&1
	eval "local options=\$${package}_options"
	configure_and_make "${options[@]}"
	popd >/dev/null 2>&1
	printf 'OK\n'
}

function symlink_vi() {
	( cd ${objvim_prefix}/bin && ln -sf vim vi )
}

function install_pathogen() {
	printf 'Installing pathogen plugin... '
	cp src/pathogen.vim "${vim_dir}/autoload/pathogen.vim"
	printf 'OK\n'
}

function install_command_t() {
	printf 'Installing CommandT plugin... '
	mkdir -p "${vim_bundle_dir}"
	tar -xzf src/command-t.tar.gz -C "${vim_bundle_dir}"
	printf 'OK\n'
}

function error_exit() {
	printf '\n\n'
	printf '  An error occurred while building stuff.  Please check %s for more details\n' "$objvim_log"
	printf '  and definitely create a github issue if you cannot figure it out.\n'
	printf '\n'
	trap - EXIT
	exit 1
}

function run_tests() {
	printf 'Running tests:\n'
	local return_code=0
	for test in test/*.vim; do
		printf '  %s... ' "$test"
		${objvim_prefix}/bin/vim -u "$test" >/dev/null 2>&1
		if (( $? == 0 )); then
			printf 'OK\n'
		else
			printf 'FAILED\n'
			return_code=1
		fi
	done
	return $return_code
}

function build_all() {
	set -e
	trap 'error_exit' EXIT

	rm -rf ${objvim_prefix}
	mkdir ${objvim_prefix}

	if command -v rvm >/dev/null 2>&1
	then
		rvm use system
	fi

	build yaml
	build ruby
	build vim
	symlink_vi
	install_pathogen
	install_command_t

	run_tests

	trap - EXIT
}

if [[ -z "$objvim_develop" ]]
then
	build_all
fi

#!/bin/sh

export BASE_DIR="$(cd $(dirname $0); pwd)"
top_dir="$BASE_DIR/.."

n_processors=1
case `uname` in
    Linux)
	n_processors="$(grep '^processor' /proc/cpuinfo | wc -l)"
	;;
    Darwin)
	n_processors="$(/usr/sbin/sysctl -n hw.ncpu)"
	;;
    *)
	:
	;;
esac

if [ "$NO_MAKE" != "yes" ]; then
    MAKE_ARGS=
    if [ -n "$n_processors" ]; then
	MAKE_ARGS="-j${n_processors}"
    fi
    make $MAKE_ARGS -C $top_dir > /dev/null || exit 1
fi

. "${top_dir}/config.sh"

source_mysql_test_dir="${MYSQL_SOURCE_DIR}/mysql-test"
build_mysql_test_dir="${MYSQL_BUILD_DIR}/mysql-test"
source_test_suites_dir="${source_mysql_test_dir}/suite"
build_test_suites_dir="${build_mysql_test_dir}/suite"
build_test_include_dir="${build_mysql_test_dir}/include"
case "${MYSQL_VERSION}" in
    5.1.*)
	plugins_dir="${MYSQL_BUILD_DIR}/lib/mysql/plugin"
	if [ ! -d "${build_test_suites_dir}" ]; then
	    mkdir -p "${build_test_suites_dir}"
	fi
	;;
    *)
	if [ ! -d "${build_test_suites_dir}" ]; then
	    ln -s "${source_test_suites_dir}" "${build_test_suites_dir}"
	fi
	maria_storage_dir="${MYSQL_SOURCE_DIR}/storage/maria"
	if [ -d "${maria_storage_dir}" ]; then
	    mariadb="yes"
	else
	    mariadb="no"
	fi
	if [ "${mariadb}" = "yes" ]; then
	    if [ "${MRN_BUNDLED}" != "TRUE" ]; then
		ln -s "${top_dir}" "${MYSQL_BUILD_DIR}/plugin/mroonga"
	    fi
	    plugins_dir=
	else
	    plugins_dir="${MYSQL_SOURCE_DIR}/lib/plugin"
	fi
	;;
esac

same_link_p()
{
    src=$1
    dest=$2
    if [ -L "$dest" -a "$(readlink "$dest")" = "$src" ]; then
	return 0
    else
	return 1
    fi
}

local_mroonga_mysql_test_include_dir="${BASE_DIR}/sql/include"
for test_include_name in $(ls $local_mroonga_mysql_test_include_dir | grep '\.inc$'); do
    local_mroonga_mysql_test_include="${local_mroonga_mysql_test_include_dir}/${test_include_name}"
    mroonga_mysql_test_include="${build_test_include_dir}/${test_include_name}"
    if ! same_link_p "${local_mroonga_mysql_test_include}" \
			"${mroonga_mysql_test_include}"; then
	rm -f "${mroonga_mysql_test_include}"
        ln -s "${local_mroonga_mysql_test_include}" \
	    "${mroonga_mysql_test_include}"
    fi
done

for test_suite_name in mroonga; do
    local_mroonga_mysql_test_suite_dir="${BASE_DIR}/sql/suite/${test_suite_name}"
    mroonga_mysql_test_suite_dir="${build_test_suites_dir}/${test_suite_name}"
    if ! same_link_p "${local_mroonga_mysql_test_suite_dir}" \
			"${mroonga_mysql_test_suite_dir}"; then
	rm -f "${mroonga_mysql_test_suite_dir}"
	ln -s "${local_mroonga_mysql_test_suite_dir}" \
	    "${mroonga_mysql_test_suite_dir}"
    fi
done

innodb_test_suite_dir="${build_test_suites_dir}/innodb"
mroonga_wrapper_innodb_test_suite_name="mroonga_wrapper_innodb"
mroonga_wrapper_innodb_test_suite_dir="${build_test_suites_dir}/${mroonga_wrapper_innodb_test_suite_name}"
mroonga_wrapper_innodb_include_dir="${mroonga_wrapper_innodb_test_suite_dir}/include/"
if [ "$0" -nt "$(dirname "${mroonga_wrapper_innodb_test_suite_dir}")" ]; then
    rm -rf "${mroonga_wrapper_innodb_test_suite_dir}"
fi
if [ ! -d "${mroonga_wrapper_innodb_test_suite_dir}" ]; then
    cp -rp "${innodb_test_suite_dir}" "${mroonga_wrapper_innodb_test_suite_dir}"
    mkdir -p "${mroonga_wrapper_innodb_include_dir}"
    cp -rp "${build_test_include_dir}"/innodb[-_]*.inc \
	"${mroonga_wrapper_innodb_include_dir}"
    ruby -i'' \
	-pe "\$_.gsub!(/\\bengine\\s*=\\s*innodb\\b([^;\\n]*)/i,
                       \"ENGINE=mroonga\\\1 COMMENT='ENGINE \\\"InnoDB\\\"'\")
             \$_.gsub!(/\\b(storage_engine\\s*=\\s*)innodb\\b([^;\\n]*)/i,
                       \"\\\1mroonga\")
             \$_.gsub!(/^(--\\s*source\\s+)(include\\/innodb)/i,
                       \"\\\1suite/mroonga_wrapper_innodb/\\\2\")
            " \
	${mroonga_wrapper_innodb_test_suite_dir}/r/*.result \
	${mroonga_wrapper_innodb_test_suite_dir}/t/*.test \
	${mroonga_wrapper_innodb_test_suite_dir}/include/*.inc
    sed -i'' \
	-e '1 i --source include/have_mroonga.inc' \
	${mroonga_wrapper_innodb_test_suite_dir}/t/*.test
fi

all_test_suite_names=""
suite_dir="${BASE_DIR}/sql/suite"
cd "${suite_dir}"
for test_suite_name in $(find mroonga -type d '!' -name '[tr]'); do
    if [ -n "${all_test_suite_names}" ]; then
	all_test_suite_names="${all_test_suite_names},"
    fi
    all_test_suite_names="${all_test_suite_names}${test_suite_name}"
done
cd -

if [ -n "${plugins_dir}" ]; then
    if [ -d "${top_dir}/.libs" ]; then
	make -C ${top_dir} \
	    install-pluginLTLIBRARIES \
	    plugindir=${plugins_dir} > /dev/null || \
	    exit 1
    else
	cp "${top_dir}/ha_mroonga.so" "${plugins_dir}" || exit 1
    fi
fi

test_suite_names=""
while [ $# -gt 0 ]; do
    case "$1" in
	--*)
	    break
	    ;;
	*)
	    if [ -d "$1" ]; then
		test_suite_name=$(cd "$1" && pwd)
	    else
		test_suite_name="$1"
	    fi
	    shift
	    test_suite_name=$(echo "$test_suite_name" | sed -e "s,^${suite_dir},,")
	    if [ -n "${test_suite_names}" ]; then
		test_suite_names="${test_suite_names},"
	    fi
	    test_suite_names="${test_suite_names}${test_suite_name}"
	    ;;
    esac
done

if [ -z "$test_suite_names" ]; then
    test_suite_names="${all_test_suite_names}"
fi

(cd "$build_mysql_test_dir" && \
    ./mysql-test-run.pl \
    --no-check-testcases \
    --parallel="${n_processors}" \
    --retry=1 \
    --suite="${test_suite_names}" \
    --force \
    "$@")

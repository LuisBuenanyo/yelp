# Copyright (C) 2000-2004 Marco Pesenti Gritti
# Copyright (C) 2003, 2004, 2005 Christian Persch
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA

# GECKO_INIT([VARIABLE])
#
# Checks for gecko, and aborts if it's not found
#
# Checks for -fshort-wchar compiler variable, and adds it to
# AM_CXXFLAGS if found
#
# Checks whether RTTI is enabled, and adds -fno-rtti to 
# AM_CXXFLAGS otherwise
#
# Checks whether the gecko build is a debug build, and adds
# debug flags to AM_CXXFLAGS if it is.
#
# Expanded variables:
# VARIABLE: Which gecko was found (e.g. "xulrunnner", "seamonkey", ...)
# VARIABLE_FLAVOUR: The flavour of the gecko that was found
# VARIABLE_HOME:
# VARIABLE_PREFIX:
# VARIABLE_INCLUDE_ROOT:
# VARIABLE_VERSION: The version of the gecko that was found
# VARIABLE_VERSION_MAJOR:
# VARIABLE_VERSION_MINOR:

AC_DEFUN([GECKO_INIT],
[AC_REQUIRE([PKG_PROG_PKG_CONFIG])dnl

AC_MSG_CHECKING([which gecko to use])

AC_ARG_WITH([gecko],
	AS_HELP_STRING([--with-gecko@<:@=mozilla|firefox|seamonkey|xulrunner@:>@],
		       [Which gecko engine to use (default: autodetect)]))

# Backward compat
AC_ARG_WITH([mozilla],[],[with_gecko=$withval],[])

_GECKO=$with_gecko

# Autodetect gecko
_geckos="firefox mozilla-firefox seamonkey mozilla xulrunner"
if test -z "$_GECKO"; then
	for lizard in $_geckos; do
		if $PKG_CONFIG --exists $lizard-xpcom; then
			_GECKO=$lizard
			break;
		fi
	done
fi

if test "x$_GECKO" = "x"; then
	AC_MSG_ERROR([No gecko found])
elif ! ( echo "$_geckos" | egrep "(^| )$_GECKO(\$| )" > /dev/null); then
	AC_MSG_ERROR([Unknown gecko "$_GECKO" specified])
fi

AC_MSG_RESULT([$_GECKO])

case "$_GECKO" in
mozilla) _GECKO_FLAVOUR=mozilla ;;
seamonkey) _GECKO_FLAVOUR=mozilla ;;
*firefox) _GECKO_FLAVOUR=toolkit ;;
xulrunner) _GECKO_FLAVOUR=toolkit ;;
esac


_GECKO_INCLUDE_ROOT="`$PKG_CONFIG --variable=includedir $_GECKO-gtkmozembed`"
_GECKO_HOME="`$PKG_CONFIG --variable=libdir $_GECKO-gtkmozembed`"
_GECKO_PREFIX="`$PKG_CONFIG --variable=prefix $_GECKO-gtkmozembed`"

$1[]=$_GECKO
$1[]_FLAVOUR=$_GECKO_FLAVOUR
$1[]_INCLUDE_ROOT=$_GECKO_INCLUDE_ROOT
$1[]_HOME=$_GECKO_HOME
$1[]_PREFIX=$_GECKO_PREFIX

# **************************************************************
# This is really gcc-only
# Do this test using CXX only since some versions of gcc
# 2.95-2.97 have a signed wchar_t in c++ only and some versions
# only have short-wchar support for c++.
# **************************************************************

_GECKO_EXTRA_CPPFLAGS=
_GECKO_EXTRA_CFLAGS=
_GECKO_EXTRA_CXXFLAGS=
_GECKO_EXTRA_LDFLAGS=

AC_LANG_PUSH([C++])

_SAVE_CXXFLAGS=$CXXFLAGS
CXXFLAGS="$CXXFLAGS $_GECKO_EXTRA_CXXFLAGS -fshort-wchar"

AC_CACHE_CHECK([for compiler -fshort-wchar option],
	gecko_cv_have_usable_wchar_option,
	[AC_RUN_IFELSE([AC_LANG_SOURCE(
		[[#include <stddef.h>
		  int main () {
		    return (sizeof(wchar_t) != 2) || (wchar_t)-1 < (wchar_t) 0 ;
		  } ]])],
		[gecko_cv_have_usable_wchar_option="yes"],
		[gecko_cv_have_usable_wchar_option="no"],
		[gecko_cv_have_usable_wchar_option="maybe (cross-compiling)"])])

CXXFLAGS="$_SAVE_CXXFLAGS"

AC_LANG_POP([C++])

if test "$gecko_cv_have_usable_wchar_option" = "yes"; then
	_GECKO_EXTRA_CXXFLAGS="-fshort-wchar"
	AM_CXXFLAGS="$AM_CXXFLAGS -fshort-wchar"
fi

# **************
# Check for RTTI
# **************

AC_MSG_CHECKING([whether to enable C++ RTTI])
AC_ARG_ENABLE([cpp-rtti],
	AS_HELP_STRING([--enable-cpp-rtti],[Enable C++ RTTI]),
	[],[enable_cpp_rtti=no])
AC_MSG_RESULT([$enable_cpp_rtti])

if test "$enable_cpp_rtti" = "no"; then
	_GECKO_EXTRA_CXXFLAGS="-fno-rtti $_GECKO_EXTRA_CXXFLAGS"
	AM_CXXFLAGS="-fno-rtti $AM_CXXFLAGS"
fi

# *************
# Various tests
# *************

AC_LANG_PUSH([C++])

_SAVE_CPPFLAGS="$CPPFLAGS"
CPPFLAGS="$CPPFLAGS $_GECKO_EXTRA_CPPFLAGS -I$_GECKO_INCLUDE_ROOT"

AC_MSG_CHECKING([[whether we have a gtk 2 gecko build]])
AC_RUN_IFELSE(
	[AC_LANG_SOURCE(
		[[#include <mozilla-config.h>
		  #include <string.h>
                  int main(void) {
		    return strcmp (MOZ_DEFAULT_TOOLKIT, "gtk2") != 0;
		  } ]]
	)],
	[result=yes],
	[AC_MSG_ERROR([[This program needs a gtk 2 gecko build]])],
        [result=maybe])
AC_MSG_RESULT([$result])

AC_MSG_CHECKING([[whether we have a gecko debug build]])
AC_PREPROC_IFELSE(
	[AC_LANG_SOURCE(
		[[#include <mozilla-config.h>
		  #if !defined(MOZ_REFLOW_PERF) || !defined(MOZ_REFLOW_PERF_DSP)
		  #error No
		  #endif]]
	)],
	[gecko_cv_have_debug=yes],
	[gecko_cv_have_debug=no])
AC_MSG_RESULT([$gecko_cv_have_debug])

CPPFLAGS="$_SAVE_CPPFLAGS"

AC_LANG_POP([C++])

if test "$gecko_cv_have_debug" = "yes"; then
	_GECKO_EXTRA_CXXFLAGS="$_GECKO_EXTRA_CXXFLAGS -DDEBUG -D_DEBUG"
	AM_CXXFLAGS="-DDEBUG -D_DEBUG $AM_CXXFLAGS"
fi

# ***********************
# Check for gecko version
# ***********************

AC_MSG_CHECKING([[for gecko version]])

_GECKO_VERSION_SPLIT=`cat $_GECKO_INCLUDE_ROOT/mozilla-config.h | grep MOZILLA_VERSION_U | awk '{ print $[3]; }' | tr ".ab+" " "`
if test -z "$_GECKO_VERSION_SPLIT"; then
	_GECKO_VERSION_SPLIT="1 7"
fi

_GECKO_VERSION_MAJOR=`echo $_GECKO_VERSION_SPLIT | awk '{ print $[1]; }'`
_GECKO_VERSION_MINOR=`echo $_GECKO_VERSION_SPLIT | awk '{ print $[2]; }'`
_GECKO_VERSION="$_GECKO_VERSION_MAJOR.$_GECKO_VERSION_MINOR"

AC_MSG_RESULT([$_GECKO_VERSION])

$1[]_VERSION=$_GECKO_VERSION
$1[]_VERSION_MAJOR=$_GECKO_VERSION_MAJOR
$1[]_VERSION_MINOR=$_GECKO_VERSION_MINOR

if test "$_GECKO_VERSION_MAJOR" != "1" -o "$_GECKO_VERSION_MINOR" -lt "7" -o "$_GECKO_VERSION_MINOR" -gt "9"; then
	AC_MSG_ERROR([Gecko version $_GECKO_VERSION is not supported!])
fi

if test "$_GECKO_VERSION_MAJOR" = "1" -a "$_GECKO_VERSION_MINOR" -ge "7"; then
	AC_DEFINE([HAVE_GECKO_1_7],[1],[Define if we have gecko 1.7])
	gecko_cv_have_gecko_1_7=yes
fi
if test "$_GECKO_VERSION_MAJOR" = "1" -a "$_GECKO_VERSION_MINOR" -ge "8"; then
	AC_DEFINE([HAVE_GECKO_1_8],[1],[Define if we have gecko 1.8])
	gecko_cv_have_gecko_1_8=yes
fi
if test "$_GECKO_VERSION_MAJOR" = "1" -a "$_GECKO_VERSION_MINOR" -ge "9"; then
	AC_DEFINE([HAVE_GECKO_1_9],[1],[Define if we have gecko 1.9])
	gecko_cv_have_gecko_1_9=yes
fi

AM_CONDITIONAL([HAVE_GECKO_1_7],[test "$_GECKO_VERSION_MAJOR" = "1" -a "$_GECKO_VERSION_MINOR" -ge "7"])
AM_CONDITIONAL([HAVE_GECKO_1_8],[test "$_GECKO_VERSION_MAJOR" = "1" -a "$_GECKO_VERSION_MINOR" -ge "8"])
AM_CONDITIONAL([HAVE_GECKO_1_9],[test "$_GECKO_VERSION_MAJOR" = "1" -a "$_GECKO_VERSION_MINOR" -ge "9"])

])

# ***************************************************************************
# ***************************************************************************
# ***************************************************************************

# GECKO_DISPATCH([MACRO], [HEADERS], ...)

m4_define([GECKO_DISPATCH],
[

AC_LANG_PUSH([C++])

_SAVE_CPPFLAGS="$CPPFLAGS"
_SAVE_CXXFLAGS="$CXXFLAGS"
_SAVE_LDFLAGS="$LDFLAGS"
CPPFLAGS="$CPPFLAGS $_GECKO_EXTRA_CPPFLAGS -I$_GECKO_INCLUDE_ROOT $($PKG_CONFIG --cflags-only-I $_GECKO-xpcom)"
CXXFLAGS="$CXXFLAGS $_GECKO_EXTRA_CXXFLAGS $($PKG_CONFIG --cflags-only-other $_GECKO-xpcom)"
LDFLAGS="$LDFLAGS $_GECKO_EXTRA_LDFLAGS $($PKG_CONFIG --libs $_GECKO-xpcom) -Wl,--rpath=$_GECKO_HOME"

_GECKO_DISPATCH_HEADERS="$2"

# Sigh Gentoo has a rubbish header layout
# http://bugs.gentoo.org/show_bug.cgi?id=100804
# Mind you, it's useful to be able to test against uninstalled mozilla builds...
_GECKO_DISPATCH_HEADERS="$_GECKO_DISPATCH_HEADERS necko dom"

# Now add them to CPPFLAGS
for i in $_GECKO_DISPATCH_HEADERS; do
	CPPFLAGS="$CPPFLAGS -I$_GECKO_INCLUDE_ROOT/$i"
done

m4_indir([$1],m4_shiftn(2,$@))

CPPFLAGS="$_SAVE_CPPFLAGS"
CXXFLAGS="$_SAVE_CXXFLAGS"
LDFLAGS="$_SAVE_LDFLAGS"

AC_LANG_POP([C++])

])# _GECKO_DISPATCH

# ***************************************************************************
# ***************************************************************************
# ***************************************************************************

# GECKO_COMPILE_IFELSE(HEADERS, PROGRAM, [ACTION-IF-FOUND], [ACTION-IF-NOT-FOUND])

AC_DEFUN([GECKO_COMPILE_IFELSE],[GECKO_DISPATCH([AC_COMPILE_IFELSE],$@)])

# GECKO_RUN_IFELSE(HEADERS, PROGRAM, [ACTION-IF-FOUND], [ACTION-IF-NOT-FOUND])

AC_DEFUN([GECKO_RUN_IFELSE],[GECKO_DISPATCH([AC_RUN_IFELSE],$@)])

# ***************************************************************************
# ***************************************************************************
# ***************************************************************************

# GECKO_CHECK_CONTRACTID(IDENTIFIER, CONTRACTID, [ACTION-IF-FOUND], [ACTION-IF-NOT-FOUND])
#
# Checks wheter CONTRACTID is a registered contract ID

AC_DEFUN([GECKO_CHECK_CONTRACTID],
[AC_REQUIRE([GECKO_INIT])dnl

AC_CACHE_CHECK([for the $2 XPCOM component],
[gecko_cv_xpcom_contractid_[]$1],
[
gecko_cv_xpcom_contractid_[]$1[]=no

GECKO_RUN_IFELSE([],
[AC_LANG_PROGRAM([[
#include <mozilla-config.h>
#include <stdlib.h>
#include <stdio.h>
#include <nsXPCOM.h>
#include <nsCOMPtr.h>
#include <nsILocalFile.h>
#include <nsIServiceManager.h>
#include <nsIComponentRegistrar.h>
#include <nsString.h>
]],[[
// redirect unwanted mozilla debug output
freopen ("/dev/null", "w", stdout);
freopen ("/dev/null", "w", stderr);

nsresult rv;
nsCOMPtr<nsILocalFile> directory;
rv = NS_NewNativeLocalFile (NS_LITERAL_CSTRING("$_GECKO_HOME"), PR_FALSE, getter_AddRefs (directory));
if (NS_FAILED (rv) || !directory) {
	exit (EXIT_FAILURE);
}

nsCOMPtr<nsIServiceManager> sm;
rv = NS_InitXPCOM2 (getter_AddRefs (sm), directory, nsnull);
if (NS_FAILED (rv)) {
	exit (EXIT_FAILURE);
}

nsCOMPtr<nsIComponentRegistrar> registar (do_QueryInterface (sm, &rv));
sm = nsnull; // release service manager
if (NS_FAILED (rv)) {
	NS_ShutdownXPCOM (nsnull);
	exit (EXIT_FAILURE);
}

PRBool isRegistered = PR_FALSE;
rv = registar->IsContractIDRegistered ("$2", &isRegistered);
registar = nsnull; // release registar before shutdown
	
NS_ShutdownXPCOM (nsnull);
exit (isRegistered ? EXIT_SUCCESS : EXIT_FAILURE);
]])
],
[gecko_cv_xpcom_contractid_[]$1[]=present],
[gecko_cv_xpcom_contractid_[]$1[]="not present"],
[gecko_cv_xpcom_contractid_[]$1[]="not present (cross-compiling)"])

])

if test "$gecko_cv_xpcom_contractid_[]$1" = "present"; then
	ifelse([$3],,[:],[$3])
else
	ifelse([$4],,[AC_MSG_FAILURE([dnl
Contract ID "$2" is not registered, but $PACKAGE_NAME depends on it.])],
	[$4])
fi

])

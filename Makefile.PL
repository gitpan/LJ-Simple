use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub MY::postamble {
  return <<EOF;
##
## This will probably break for you; its designed for me to be
## able to update the website which distributes LJ::Simple
##
publish: dist
	set -e ; \\
	umask 022 ; \\
	htdocs="/home/triad/www/source-sites/live-www.bpfh.net" ; \\
	dest="\$\$htdocs/computing/software/LJ::Simple" ; \\
	tar="\$(DISTNAME)-\$(VERSION).tar.gz" ; \\
	if [ ! -d \$\$dest ] ; then \\
	  mkdir -p \$\$dest ; \\
	fi ; \\
	cp \$\$tar \$\$dest ; \\
	pod2html \$(VERSION_FROM) > \$\$dest/\$(VERSION_FROM).htm ; \\
	rm -rf pod2htm* ; \\
	cp Changes \$\$dest/Changes.txt ; \\
	cat index.html | \\
		sed 's/\@VERSION\@/\$(VERSION)/g' | \\
		sed "s/\@TAR\@/\$\$tar/g" | \\
		sed 's/\@MANPAGE\@/\$(VERSION_FROM).htm/g' | \\
		cat > \$\$dest/index.html ; \\
	chmod 644 \$\$dest/* ; \

rebuild-pkg:
	\@if [ -z "\$(BUILD_PKG_RECURSE)" ] ; then \\
	  echo "Rebuilding Makefile" ; \\
	  perl Makefile.PL ; \\
	  \$(MAKE) pkg BUILD_PKG_RECURSE=yes ; \\
	fi
##
## Unless you've got the pkg-tools package this will break for you
## as well
##
pkg: rebuild-pkg manifypods pure_all
	cat InstallPackage/pkginfo | \\
		sed 's/^VERSION=.*/VERSION=\$(VERSION)/' \\
		> tmp.pkginfo
	mv tmp.pkginfo InstallPackage/pkginfo
	build-pkg -n %PKG%-v%VERSION%.pkg -K
	mv InstallPackage/*.pkg .

EOF
}

WriteMakefile(
    'NAME'		=> 'LJ::Simple',
    'VERSION_FROM'	=> 'Simple.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Simple.pm', # retrieve abstract from module
       AUTHOR     => 'Simon Burr <simes@bpfh.net>') : ()),
);

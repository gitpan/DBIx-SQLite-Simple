#
# $Id: Makefile.PL,v 1.9 2006/06/11 09:32:58 gomor Exp $
#
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME          => 'DBIx::SQLite::Simple',
   AUTHOR        => 'GomoR <perl@gomor.org>',
   VERSION_FROM  => 'lib/DBIx/SQLite/Simple.pm',
   ABSTRACT_FROM => 'lib/DBIx/SQLite/Simple.pm',
   PREREQ_PM     => {
      DBD::SQLite  => 0,
      Class::Gomor => 0,
   },
);

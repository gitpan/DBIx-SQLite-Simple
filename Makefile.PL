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

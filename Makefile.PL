use ExtUtils::MakeMaker;

WriteMakefile(
   NAME          => 'DBIx::SQLite::Simple',
   AUTHOR        => 'GomoR <perl@gomor.org>',
   VERSION_FROM  => 'Simple.pm',
   ABSTRACT_FROM => 'Simple.pm',
   PREREQ_PM     => {
      DBD::SQLite        => 0,
      Class::Gomor::Hash => 0,
   },
);

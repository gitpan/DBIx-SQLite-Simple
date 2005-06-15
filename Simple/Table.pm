#
# $Id: Table.pm,v 1.16 2005/06/15 20:41:34 gomor Exp $
#

package DBIx::SQLite::Simple::Table;
use strict;
use warnings;
use Carp;

require Class::Gomor::Hash;
our @ISA = qw(Class::Gomor::Hash);

our @AS = qw(
   dbo
);
__PACKAGE__->buildAccessorsScalar(\@AS);

require DBIx::SQLite::Simple;

# XXX: do all SQL request with prepare/execute

=head1 NAME

DBIx::SQLite::Simple::Table - superclass only used to handle SQL tables

=head1 SYNOPSIS

   # Example of a table with a primary key

   package TPub;

   require DBIx::SQLite::Simple::Table;
   require Class::Gomor::Hash;
   our @ISA = qw(DBIx::SQLite::Simple::Table Class::Gomor::Hash);

   our @AS = qw(
      idPub
      pub
   );
   __PACKAGE__->buildAccessorsScalar(\@AS);

   # 'our $Id' and 'our @Fields' are named Id and Fields for a good
   # reason, so do not name these variables by another name.
   our $Id     = $AS[0];
   our @Fields = @AS[1..$#AS];

   1;

   # Example of a table with no key at all

   package TBeer;

   require DBIx::SQLite::Simple::Table;
   require Class::Gomor::Hash;
   our @ISA = qw(DBIx::SQLite::Simple::Table Class::Gomor::Hash);

   our @AS = qw(
      beer
      country
   );
   __PACKAGE__->buildAccessorsScalar(\@AS);

   our @Fields = @AS;

   1;

   # Now, we have two tables, we can play with the database

   package main;

   require DBIx::SQLite::Simple;
   my $db = DBIx::SQLite::Simple->new(db => 'sqlite.db');

   # Create to object to play with the two tables
   my $tPub = TPub->new;
   my $tBeer = TBeer->new;

   # Create tables
   $tPub->create unless $tPub->exists;
   $tBeer->create unless $tBeer->exists;

   # Create some entries
   my @pubEntries;
   push @pubEntries, TPub->new(pub => $_) for (qw(corner friends));

   my @beerEntries;
   push @beerEntries, TBeer->new(beer => $_, country => 'BE')
      for (qw(grim leffe bud));

   # Now insert those entries;
   $tPub->insert(\@pubEntries);
   $tBeer->insert(\@beerEntries);

   # Get friends pub
   my $friends = $tPub->select(pub => 'friends');

   # Lookup id
   my $id = $tPub->lookupId(pub => 'friends');

   # Lookup string
   my $str = $tPub->lookupString('pub', idPub => $id);

   # Add a beer from 'chez moi'
   my $dremwell = TBeer->new(beer => 'Dremwell', country => '?');
   $tBeer->insert([ $dremwell ]);

   $tPub->commit;
   $tBeer->commit;

   # Update Dremwell
   my $dremwellOld = $dremwell->clone;
   $dremwell->country('BZH');
   $tBeer->update([ $dremwell ], $dremwellOld);
   $tBeer->commit;

   # Delete all pubs
   $tPub->delete(\@pubEntries);

=head1 ATTRIBUTES

=over 4

=item B<dbo>

Stores a DBIx::SQLite::Simple object.

=back

=head1 METHODS

=over 4

=item B<new>

Object creator. Will return an object used to access corresponding SQL table. You can pass an optional parameter: dbo. By default, it uses the global variable $DBIx::SQLite::Simple::Dbo.

=cut

sub new {
   my $self = shift->SUPER::new(@_);

   $self->dbo($DBIx::SQLite::Simple::Dbo)
      unless $self->dbo;

   $self;
}

=item B<clone>

Create a copy of the object.

=cut

sub clone {
   my $self = shift;

   no strict 'refs';
   my $id     = ${ref($self). '::Id'};
   my @fields = @{ref($self). '::Fields'};

   my %values;
   $values{$_}  = $self->$_ for @fields;
   $values{$id} = $self->$id if $id;

   ref($self)->new(%values);
}

sub __toObj {
   my $self = shift;
   my ($fields, $aref) = @_;

   my $class = ref($self);

   my @obj = ();
   for my $h (@$aref) {
      my %values = map { $_ => $h->{$_} } @$fields;
      push @obj, $class->new(%values);
   }
   \@obj;
}

sub _create {
   my $self = shift;
   my ($fields, $noKey) = @_;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;

   my $query = 'CREATE TABLE '. $table. '(';
   if ($noKey) {
      $query .= $fields->[0]. ', ';
   }
   else {
      $query .= $fields->[0]. ' INTEGER PRIMARY KEY, ';
   }
   shift(@$fields);
   $query .= $_. ', ' for @$fields;
   $query =~ s/, $/)/;

   $self->dbo->_dbh->do($query);

   carp('_create: do: query['.$query.']: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   1;
}

=item B<commit>

Just a convenient method to commit pending changes to the whole database.

=cut

sub commit { shift->dbo->commit }

sub _exists {
   my $self = shift;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;

   $self->dbo->_dbh->do('SELECT * FROM '. $table);
   $self->dbo->_dbh->err ? undef : 1;
}

sub _delete {
   my $self = shift;
   my ($fields, $values) = @_;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;
   
   my $query = 'DELETE FROM '. $table. ' WHERE ';
   $query .= $_. '=? AND ' for @$fields;
   $query =~ s/ AND $//;
   my $sth = $self->dbo->_dbh->prepare($query);
   carp('_delete: prepare: query['.$query.']: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   for my $obj (@$values) {
      my @fields;
      push @fields, $obj->$_ for @$fields;
      $sth->execute(@fields);
      carp('_delete: execute: '. $self->dbo->_dbh->errstr)
         if $self->dbo->_dbh->err;
   }
   $sth->finish;

   1;
}

sub _update {
   my $self = shift;
   my ($fields, $id, $values, $where) = @_;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;

   my $query = 'UPDATE '. $table. ' SET ';
   $query .= $_. '=?, ' for @$fields;
   $query =~ s/, $/ WHERE /;
   if ($id) {
      $query .= $id. '=?';
   }
   else {
      $query .= $_. '=? AND ' for @$fields;
      $query =~ s/ AND $//;
   }
   my $sth = $self->dbo->_dbh->prepare($query);
   carp('_update: prepare: query['.$query.']: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   for my $obj (@$values) {
      my @fields;
      push @fields, $obj->$_ for @$fields;
      $id ? do { push @fields, $obj->$id               }
          : do { push @fields, $where->$_ for @$fields };
      $sth->execute(@fields);
      carp('_update: execute: '. $self->dbo->_dbh->errstr)
         if $self->dbo->_dbh->err;
   }
   $sth->finish;

   1;
}

sub _insert {
   my $self = shift;
   my ($fields, $values) = @_;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;
   
   my $query = 'INSERT INTO '. $table. '(';
   $query .= $_. ', ' for @$fields;
   $query =~ s/, $/) VALUES (/;
   $query .= ('?, ' x scalar @$fields);
   $query =~ s/, $/)/;
   my $sth = $self->dbo->_dbh->prepare($query);
   carp('_insert: prepare: query['.$query.']: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   for my $obj (@$values) {
      my @fields;
      push @fields, $obj->$_ for @$fields;
      $sth->execute(@fields);
      carp('_insert: execute: '. $self->dbo->_dbh->errstr)
         if $self->dbo->_dbh->err;
   }
   $sth->finish;

   1;
}

sub _select {
   my $self = shift;
   my (%fields) = @_;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;

   my $query = 'SELECT * FROM '. $table. ' WHERE ';
   if (%fields) {
      do { $query .= $_. '=? AND ' } for keys %fields;
      $query =~ s/ AND $//;
   }
   else {
      $query =~ s/ WHERE $//;
   }

   my $sth = $self->dbo->_dbh->prepare($query);
   carp('_select: prepare: query['.$query.']: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   %fields
      ? $sth->execute(values %fields)
      : $sth->execute;

   carp('_select: execute: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   my $res = $sth->fetchall_arrayref({});
   carp('_select: fetchall_arrayref: '. $self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   $self->can('_toObj')
      ? return $self->_toObj($res)
      : return $res->[0];
}

sub _lookupId {
   my $self = shift;
   my ($id, %fields) = @_;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;

   my $query = 'SELECT '. $id. ' FROM '. $table. ' WHERE ';
   do { $query .= $_. '=? AND ' } for keys %fields;
   $query =~ s/ AND $//;

   my $sth = $self->dbo->_dbh->prepare($query);
   carp('_lookupId: prepare: query['.$query.']: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   $sth->execute(values %fields);
   carp('_lookupId: execute: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   my @res = $sth->fetchrow_array;
   carp('_lookupId: fetchrow_array: '. $self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   $sth->finish;

   $res[0];
}

sub _lookupString {
   my $self = shift;
   my ($string, %fields) = @_;

   my ($table) = ref($self) =~ /^(?:.*::)?(.*)/;

   my $query = 'SELECT '. $string. ' FROM '. $table. ' WHERE ';
   do { $query .= $_. '=? AND ' } for keys %fields;
   $query =~ s/ AND $//;

   my $sth = $self->dbo->_dbh->prepare($query);
   carp('_lookupString: prepare: query['.$query.']: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   $sth->execute(values %fields);
   carp('_lookupString: execute: '.$self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   my @res = $sth->fetchrow_array;
   carp('_lookupString: fetchrow_array: '. $self->dbo->_dbh->errstr)
      if $self->dbo->_dbh->err;

   $sth->finish;

   $res[0];
}

# XXX: _lookupObject to return a list of objects

sub _toObj  {
   my $self = shift;

   no strict 'refs';
   my $id     = ${ref($self). '::Id'};
   my @fields = @{ref($self). '::Fields'};

   $id ? return $self->__toObj([ $id, @fields ], @_)
       : return $self->__toObj(\@fields, @_);
}

=item B<create>

Method to create the table.

=cut

sub create {
   my $self = shift;

   no strict 'refs';
   my $id     = ${ref($self). '::Id'};
   my @fields = @{ref($self). '::Fields'};

   $id ? return $self->_create([ $id, @fields ], @_)
       : return $self->_create(\@fields, 1, @_);
}

=item B<exists>

Method to verify existence of a table.

=cut

sub exists { shift->_exists(@_) }

=item B<select>

If called without parameters, returns the whole content as an arrayref. If called with a hash as argument containing some table fields with values, it plays as multiple where clauses (return result as an arrayref also). See SYNOPSIS.

=cut

sub select { shift->_select(@_) }

=item B<delete>($arrayref)

Deletes all entries specified in the arrayref (they are all objects of type DBIx::SQLite::Simple::Table).

=cut

sub delete {
   my $self = shift;

   no strict 'refs';
   my @fields = @{ref($self). '::Fields'};

   $self->_delete(\@fields, @_);
}

=item B<insert>($arrayref)

Insert all entries specified in the arrayref (they are all objects of type DBIx
::SQLite::Simple::Table).

=cut

sub insert {
   my $self = shift;

   no strict 'refs';
   my $id     = ${ref($self). '::Id'};
   my @fields = @{ref($self). '::Fields'};

   $id ? return $self->_insert([ $id, @fields ], @_)
       : return $self->_insert(\@fields, @_);
}

=item B<update>($arrayref)

Will update elements specified within the arrayref (they are all objects of type DBIx::SQLite::Simple::Table). If an additionnal argument is passed, it will act as a where clause. See SYNOPSIS.

=cut

sub update {
   my $self = shift;

   no strict 'refs';
   my $id     = ${ref($self). '::Id'};
   my @fields = @{ref($self). '::Fields'};

   $id ? return $self->_update([ $id, @fields ], $id, @_)
       : return $self->_update(\@fields, undef, @_);
}

=item B<lookupId>(%hash)

Returns the the id if the specified field/value hash.

=cut

sub lookupId {
   my $self = shift;

   no strict 'refs';
   my $id = ${ref($self). '::Id'};

   $self->_lookupId($id, @_);
}

=item B<lookupString>($field, field2 => value)

Returns the content of the specified field. See SYNOPSIS.

=cut

sub lookupString { shift->_lookupString(@_)  }

=back

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of the Artistic license.
See Copying file in the source distribution archive.

=cut

1;

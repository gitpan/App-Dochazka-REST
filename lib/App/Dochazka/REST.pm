# ************************************************************************* 
# Copyright (c) 2014, SUSE LLC
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of SUSE LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************* 

package App::Dochazka::REST;

use 5.012;
use strict;
use warnings FATAL => 'all';

use App::CELL qw( $CELL $log $meta $core $site );
use Carp;
use Data::Dumper;
use DBI;
use App::Dochazka::REST::Model::Activity;
#use App::Dochazka::REST::Model::Shared;
use File::ShareDir;
use Try::Tiny;




=head1 NAME

App::Dochazka::REST - Dochazka REST server




=head1 VERSION

Version 0.072

=cut

our $VERSION = '0.072';




=head1 SYNOPSIS

This is the top-level module of the Dochazka REST server. For a full
technical specification and explanation of what, why, and how, refer to
L<App::Dochazka::REST::Spec>.

    use App::Dochazka::REST;

    ...




=head1 DESCRIPTION

Om mane padme hum




=head1 EXPORTS

This module provides the following exports:

=over 

=item C<$REST>
App::Dochazka::REST singleton object

=back

=cut 

use Exporter qw( import );
our @EXPORT_OK = qw( $REST );

our $REST = bless { 
        dbh      => '',
    }, __PACKAGE__;




=head1 METHODS AND ROUTINES



=head2 C<reset_db>

Drop and re-create a Dochazka database. Takes database name. Do not call
when connected to an existing database. Be very, _very_, _VERY_ careful
when calling this function.

=cut

sub reset_db {
    my ( $self, $dbname ) = @_;

    my $status;
    if ( $REST->{dbh} and $REST->{dbh}->ping ) {
        $log->warn( "reset_db: already connected to DB; disconnecting first" );
        $REST->{dbh}->disconnect;
    }

    # connect to 'postgres' database
    $status = $self->connect_db_pristine( 
        dbname => 'postgres',
        dbuser => $site->DBINIT_CONNECT_USER,
        dbpass => $site->DBINIT_CONNECT_AUTH,
    );
    return $status unless $status->ok;

    $REST->{dbh}->{AutoCommit} = 1;
    $REST->{dbh}->{RaiseError} = 1;

    # drop user dochazka if it exists, otherwise ignore the error
    try {
        $REST->{dbh}->do( 'DROP DATABASE IF EXISTS "' . $dbname . '"' );    
        $REST->{dbh}->do( 'DROP USER dochazka' );
    };

    try {
        $REST->{dbh}->do( 'CREATE USER dochazka' );
        $REST->{dbh}->do( 'ALTER ROLE dochazka WITH PASSWORD \'dochazka\'' );
        $REST->{dbh}->do( 'CREATE DATABASE "' . $dbname . '"' );    
        $REST->{dbh}->do( 'GRANT ALL PRIVILEGES ON DATABASE "'.  $dbname . '" TO dochazka' );
    } catch {
        $status = $CELL->status_err( $DBI::errstr );
    };
    $REST->{dbh}->disconnect;

    # connect to dochazka database as superuser
    $status = $self->connect_db_pristine( 
        dbname => $site->DOCHAZKA_DBNAME,
        dbuser => $site->DBINIT_CONNECT_USER,
        dbpass => $site->DBINIT_CONNECT_AUTH,
    );  
    return $status unless $status->ok;

    try {
        $REST->{dbh}->do( 'CREATE EXTENSION IF NOT EXISTS btree_gist' );
    } catch {
        $status = $CELL->status_err( $DBI::errstr );
    };
    $REST->{dbh}->disconnect;

    $log->notice( 'Database ' . $dbname . ' dropped and re-created' ) if $status->ok;
    return $status;
}


=head2 init

Load site configuration, set up logging, and connect to the database.

=cut

sub init {
    my ( $self, @ARGS ) = @_;
    croak( "Unbalanced PARAMHASH" ) if @ARGS % 2;
    my %ARGS = @ARGS;
    my $status;
    $status = $self->init_no_db( %ARGS );
    return $status if $status->not_ok;
    $status = $self->connect_db( $site->DOCHAZKA_DBNAME );
    return $status;
}


=head2 init_no_db

Load site configuration and set up logging. Intended for use from the C<init>
method as well as from L<App::Dochazka::REST> unit tests that need to connect to
the pristine database using C<connect_db_pristine>. 

Takes an optional PARAMHASH which is passed to C<< $CELL->load >>. The
L<App::Dochazka::REST> distro sharedir is loaded as the first sitedir, before any
sitedir specified in the PARAMHASH is loaded. Call examples:

    my $status = $REST->init_no_db;
    my $status = $REST->init_no_db( verbose => 1 );
    my $status = $REST->init_no_db( sitedir => '/etc/fooapp' );

(The first example should be sufficient.)

=cut

sub init_no_db {
    my ( $self, @ARGS ) = @_;
    croak( "Unbalanced PARAMHASH" ) if @ARGS % 2;
    my %ARGS = @ARGS;
    $log->info( Dumper( \%ARGS ) ) if $ARGS{verbose};

    # * load site configuration
    my $status = _load_config( %ARGS );
    return $status if $status->not_ok;

    # * set up logging
    return $CELL->status_not_ok( "DOCHAZKA_APPNAME not set!" ) if not $site->DOCHAZKA_APPNAME;
    $log->init( ident => $site->DOCHAZKA_APPNAME );    
    $log->info( "Initializing " . $site->DOCHAZKA_APPNAME );

    return $CELL->status_ok;
}

sub _load_config {
    my %ARGS = @_;
    my $status;
    my $verbose = $ARGS{verbose} || 0;
    $log->debug( "Entering _load_config with verbose => $verbose" ) if $ARGS{verbose};

    # always load the App::Dochazka::REST distro sharedir
    my $target = File::ShareDir::dist_dir('App-Dochazka-REST');
    $log->debug( "About to load Dochazka-REST configuration parameters from $target" );
    $status = $CELL->load( sitedir => $target, verbose => $verbose );
    return $status if $status->not_ok;

    # load additional sitedir if provided by caller in argument list
    if ( $ARGS{sitedir} ) {
        $status = $CELL->load( sitedir => $ARGS{sitedir}, verbose => $verbose );
        return $status if $status->not_ok;
    }

    return $CELL->status_ok;
}



=head2 connect_db_pristine

Connect to a pristine database. This function should be used only for newly
created databases. Takes a PARAMHASH with 'dbname', 'dbuser', and 'dbpass'.
For username and password, DBINIT_CONNECT_USER and DBINIT_CONNECT_AUTH are
used.

=cut

sub connect_db_pristine {
    my ( $self, @ARGS ) = @_;
    $log->info( "Received " . scalar @ARGS . " arguments" );
    return $CELL->status_err( 'DOCHAZKA_BAD_PARAMHASH', args => [ 'connect_db_pristine' ] )
        if @ARGS % 2;
    my %ARGS = @ARGS;
    $log->info( Dumper( \%ARGS ) ) if $ARGS{verbose};

    my $data_source = "Dbi:Pg:dbname=$ARGS{dbname}";
    $log->debug( "dbname is $ARGS{dbname}" );
    $log->debug( "connect user is " . $ARGS{dbuser} );
    $log->debug( "Opening database connection to data_source " .
        "->$data_source<- username ->" . $ARGS{dbuser} . "<-" 
    );
    $REST->{dbh} = DBI->connect(
        $data_source, 
        $ARGS{dbuser},
        $ARGS{dbpass},
        {
            PrintError => 0,
            RaiseError => 0,
            AutoCommit => 1,
        },
    ) or return $CELL->status_err( $DBI::errstr );
    $log->notice( "Connected to " . $REST->{dbh}->{Name} . 
                  " as username " . $REST->{dbh}->{Username} );
    return $CELL->status_ok;
}


    
=head2 connect_db

Connect to a pre-initialized database and initialize site params. This is
the function that should be used in production. Takes database name. For
username and password, DOCHAZKA_DBUSER and DOCHAZKA_DBPASS are
used.

=cut

sub connect_db {
    my @ARGS = @_;
    my $dbname = $ARGS[1];
    my $data_source = "Dbi:Pg:dbname=$dbname";
    $log->info( "dbname is $dbname" );
    $log->info( "connect user is " . $site->DOCHAZKA_DBUSER );
    $log->debug( "Opening database connection to data_source " .
        "->$data_source<- username ->" .  $site->DOCHAZKA_DBPASS . "<-" 
    );
    $REST->{dbh} = DBI->connect(
        $data_source, 
        $site->DOCHAZKA_DBUSER, 
        $site->DOCHAZKA_DBPASS, 
        {
            PrintError => 0,
            RaiseError => 0,
            AutoCommit => 1,
        },
    ) or return $CELL->status_err( $DBI::errstr );

    # initialize site params:

    # 1. get EID of root employee
    my ( $eid_of_root ) = $REST->{dbh}->selectrow_array( 
                            $site->DBINIT_SELECT_EID_OF_ROOT, 
                            undef 
                                                       );
    $site->set( 'DOCHAZKA_EID_OF_ROOT', $eid_of_root );

    $log->notice( "Connected to " . $REST->{dbh}->{Name} . 
                  " as username " . $REST->{dbh}->{Username} );
    return $CELL->status_ok;
}
    


=head2 create_tables

Execute all the SQL statements contained in DBINIT_CREATE param

=cut

sub create_tables {
    my $dbh = $REST->{dbh};
    my ( $status, $eid_of_root, $counter );

    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    try {
        my $counter = 0;

        # run first round of SQL statements to set up tables and such
        foreach my $sql ( @{ $site->DBINIT_CREATE } ) {
            $counter += 1;
            $dbh->do( $sql );
        }

        # get EID of root employee that was just created, since
        # we will need it in the second round of SQL statements
        ( $eid_of_root ) = $dbh->selectrow_array( 
                                $site->DBINIT_SELECT_EID_OF_ROOT, 
                                undef 
                                                );
        $counter += 1;

        # the second round of SQL statements to make root employee immutable
        # is taken from DBINIT_MAKE_ROOT_IMMUTABLE site param

        # (replace ? with EID of root employee in all the statements
        # N.B.: we avoid the /r modifier here because we might be using Perl # 5.012)

        my @statements = map { local $_ = $_; s/\?/$eid_of_root/g; $_; } 
                         @{ $site->DBINIT_MAKE_ROOT_IMMUTABLE };

        # run the modified statements
        foreach my $sql ( @statements ) {
            $counter += 1;
            $dbh->do( $sql );
        }

        # a third round of SQL statements to insert initial set of activities
        my $sth = $dbh->prepare( $site->SQL_ACTIVITY_INSERT );
        foreach my $actdef ( @{ $site->DOCHAZKA_ACTIVITY_DEFINITIONS } ) {
            $sth->bind_param( 1, $actdef->{code} );
            $sth->bind_param( 2, $actdef->{long_desc} );
            $sth->bind_param( 3, 'dbinit' );
            $sth->execute;
            $counter += 1;
        }
        
        $log->notice( "create_tables issued $counter SQL statements" );
        $dbh->commit;
        $status = $CELL->status_ok;
    } catch {
        $dbh->rollback;
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };

    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 0;

    return $status;
}


=head2 eid_of_root

Instance method. Returns EID of the 'root' employee.

=cut

sub eid_of_root {
    return $site->DOCHAZKA_EID_OF_ROOT;
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>




=head1 BUGS

Please report any bugs or feature requests to 
C<bug-dochazka-rest at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dochazka-REST>.  The author
will be notified, and then you'll automatically be notified of progress on your
bug as he makes changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Dochazka::REST
    perldoc App::Dochazka::REST::Spec

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dochazka-REST>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dochazka-REST>

=back




=head1 ACKNOWLEDGEMENTS




=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, SUSE LLC
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

3. Neither the name of SUSE LLC nor the names of its contributors
may be used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of App::Dochazka::REST

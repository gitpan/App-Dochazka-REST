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

Version 0.080

=cut

our $VERSION = '0.080';




=head1 SYNOPSIS

This is the top-level module of the Dochazka REST server.

    use App::CELL qw( $CELL $log $meta $site );
    use App::Dochazka::REST qw( $REST );
    use Carp;

    my $status = $REST->init( sitedir => '/etc/dochazka' );
    croak( $status->text ) unless $status->ok;

Read on for documentation.



=head1 DESCRIPTION

This is C<App::Dochazka::REST>, the Perl module that implements the REST
interface, data model, and underlying database of Dochazka, the open-source
Attendance/Time Tracking (ATT) system. 

Dochazka as a whole aims to be a convenient, open-source ATT solution. Its
reference implementation runs on the Linux platform. 


=head2 Development status

Dochazka is currently a Work In Progress (WIP). Do not expect it to do
anything useful.


=head2 Dochazka architecture

There is more to Dochazka than C<App::Dochazka::REST>, of course. Dochazka REST
is the "server component" of Dochazka, consisting of a web server
(L<Plack>) and a data model (L<DATA MODEL>). Assuming
C<App::Dochazka::REST> is installed, configured, and running, in order to
actually use Dochazka, a client will be needed.

Though no client yet exists, two are planned: a command-line interface
(L<App::Dochazka::CLI>) and a web front-end (L<App::Dochazka::WebGUI>).
Stand-alone report generators and other utilities that may or may not ever
be implemented can also be thought of as clients.


=head2 REST interface

Dochazka REST implements a I<REST> interface. In practice, a client will
send HTTP(S) requests (usually C<GET> and C<POST>) to a well-known hostname
and port where a Dochazka REST instance is listening.
C<App::Dochazka::REST> will process the incoming HTTP requests and send
back HTTP responses. 

Simpler requests can be made using the GET method with the details of the
request specified in the URL itself (e.g.,
http://dochazka.example.com/employee/Dolejsi).  More complex requests need
to be encoded in JSON and handed to the server by the POST method. All
responses from the server are in JSON.



=head1 DATA MODEL

This section describes the C<App::Dochazka::REST> data model. Conceptually, 
Dochazka data can be seen to exist in the following classes of objects:

=over

=item * Policy (parameters set when database is first created)

=item * Employee (an individual employee)

=item * Privhistory (history of changes in an employee's privilege level)

=item * Schedule (a schedule)

=item * Schedhistory (history of changes in an employee's schedule)

=item * Activities (what kinds of work are recognized)

=item * Intervals ("work", "attendance", and/or "time tracked")

=item * Locks (determining whether a reporting period is locked or not)

=back

These classes are described in the following sections.


=head2 Policy

Dochazka is configurable in a number of ways. Some configuration parameters
are set once at installation time and, once set, can never be changed --
these are referred to as "site policy" parameters.  Others, referred to as
"site configuration parameters" or "site params", are set in configuration
files such as C<Dochazka_SiteConfig.pm> (see L</SITE CONFIGURATION>) and
can be changed more-or-less at will.

The key difference between site policy and site configuration is that 
site policy parameters cannot be changed, because changing them would
compromise the referential integrity of the underlying database. 

Site policy parameters are set at installation time and are stored, as a
single JSON string, in the C<SitePolicy> table. This table is rendered
effectively immutable by a trigger.

For details, see L<App::Dochazka::REST::Model::Policy>.


=head2 Employee

Dochazka is an Attendance and Time Tracking application. To simplify the
matter, "Attendance and Time" can be replaced by the word "Work". We could
also call Dochazka a "Work Tracking" application. Because "work" is usually
done by "employees", all users of Dochazka are referred to as "employees"
regardless of their actual legal status. You could even say that "employee" is
the Dochazka term for "user". 

Employees are distinguished by an internal employee ID number (EID), which is
assigned by Dochazka itself when the employee record is created. 

Other than the EID, Dochazka need not record any other employee
identification data. That said, Dochazka has three optional employee
identification fields (full name, nick, email address), which some sites
may wish to use, but these can be left blank if needed or desired by the
site. Dochazka does not verify the contents of these fields.

Dochazka doesn't care about the employee's identification information for
two principal reasons: first, "Dochazka is not an address book" (there are
other, better systems -- such as LDAP -- for that); and second, privacy.

For details, see L<App::Dochazka::REST::Model::Employee>.


=head2 Privhistory

Dochazka has four privilege levels: C<admin>, C<active>, C<inactive>, and
C<passerby>: 

=over

=item * C<admin> -- employee can view, modify, and place/remove locks on her
own attendance data as well as that of other employees; she can also
administer employee accounts and set privilege levels of other employees

=item * C<active> -- employee can view her own profile, attendance data,
modify her own unlocked attendance data, and place locks on her attendance
data

=item * C<inactive> -- employee can view her own profile and attendance data

=item * C<passerby> -- employee can view her own profile

=back

Dochazka's C<privhistory> object is used to track changes in an employee's
privilege level over time. Each time an employee's privilege level changes, 
a Dochazka administrator (i.e., an employee whose current privilege level is
'admin'), a record is inserted into the database (in the C<privhistory>
table). Ordinary employees (i.e. those whose current privilege level is
'active') can read their own privhistory.

Thus, with Dochazka it is possible not only to determine not only an employee's
current privilege level, but also to view "privilege histories" and to
determine employees' privilege levels for any date (timestamp) in the past.

For details, see L<App::Dochazka::REST::Model::Privhistory> and L<When
history changes take effect>.


=head2 Schedule

In addition to actual attendance data, Dochazka sites may need to store
schedules. Dochazka defines the term "schedule" as a series of
non-overlapping "time intervals" (or "timestamp ranges" in PostgreSQL
terminology) falling within a single week. These time intervals express the
times when the employee is "expected" or "supposed" to work (or be "at work")
during the scheduling period.

Example: employee "Barb" is on a weekly schedule. That means her
scheduling period is "weekly" and her schedule is an array of
non-overlapping time intervals, all falling within a single week.

B<In its current form, Dochazka is only capable of handling weekly schedules
only.> Some sites, such as hospitals, nuclear power plants, fire departments,
and the like, might have employees on more complicated schedules such as "one
week on, one week off", alternating day and night shifts, "on call" duty, etc.

Dochazka can still be used to track attendance of such employees, but if their
work schedule cannot be expressed as a series of non-overlapping time intervals
contained within a contiguous 168-hour period (i.e. one week), then their
Dochazka schedule should be set to NULL.

For details, see L<App::Dochazka::REST::Model::Schedule>.


=head2 Schedhistory

The C<schedhistory> table contains a historical record of changes in the
employee's schedule. This makes it possible to determine an employee's
schedule for any date (timestamp) in the past, as well as (crucially) the
employee's current schedule.

Every time an employee's schedule is to change, a Dochazka administrator
must insert a record into this table. (Employees who are not administrators
can only read their own history; they do not have write privileges.) For
more information on privileges, see L</AUTHORIZATION>.

For details, see L<App::Dochazka::REST::Model::Schedhistory>.


=head2 Activity

While on the job, employees "work" -- i.e., they engage in various activities
that are tracked using Dochazka. The C<activities> table contains definitions
of all the possible activities that may be entered in the C<intervals> table. 

The initial set of activities is defined in the site install configuration
(C<DOCHAZKA_ACTIVITY_DEFINITIONS>) and enters the database at installation
time. Additional activities can be added later (by administrators), but
activities can be deleted only if no intervals refer to them.

Each activity has a code, or short name (e.g., "WORK") -- which is the
primary way of referring to the activity -- as well as an optional long
description. Activity codes must be all upper-case.

For details, see L<App::Dochazka::REST::Model::Activity>.


=head2 Interval

Intervals are the heart of Dochazka's attendance data. For Dochazka, an
interval is an amount of time that an employee spends doing an activity.
In the database, intervals are represented using the C<tsrange> range
operator introduced in PostgreSQL 9.2.

Optionally, an interval can have a C<long_desc> (employee's description
of what she did during the interval) and a C<remark> (admin remark).

For details, see L<App::Dochazka::REST::Model::Interval>.


=head2 Lock

In Dochazka, a "lock" is a record in the "locks" table specifying that
a particular user's attendance data (i.e. activity intervals) for a 
given period (tsrange) cannot be changed. That means, for intervals in 
the locked tsrange:

=over

=item * existing intervals cannot be updated or deleted

=item * no new intervals can be inserted

=back

Employees can create locks (i.e., insert records into the locks table) on their
own EID, but they cannot delete or update those locks (or any others).
Administrators can insert, update, or delete locks at will.

How the lock is used will differ from site to site, and some sites may not
even use locking at all. The typical use case would be to lock all the
employee's attendance data within the given period as part of pre-payroll
processing. For example, the Dochazka client application may be set up to
enable reports to be generated only on fully locked periods. 

"Fully locked" means either that a single lock record has been inserted
covering the entire period, or that the entire period is covered by multiple
locks.

Any attempts (even by administrators) to enter activity intervals that 
intersect an existing lock will result in an error.

Clients can of course make it easy for the employee to lock entire blocks
of time (weeks, months, years . . .) at once, if that is deemed expedient.

For details, see L<App::Dochazka::REST::Model::Lock>.



=head1 CAVEATS


=head2 Weekly schedules only

Unfortunately, the weekly scheduling period is hard-coded at this time.
Dochazka does not care what dates are used to define the intervals -- only
that they fall within a contiguous 168-hour period. Consider the following
contrived example. If the scheduling intervals for EID 1 were defined like
this:

    "[1964-12-30 22:05, 1964-12-31 04:35)"
    "[1964-12-31 23:15, 1965-01-01 03:10)"

for Dochazka that would mean that the employee with EID 1 has a weekly schedule
of "WED/22:05-THU/04:35" and "THU/23:15-FRI/03:10", because the dates in the
ranges fall on a Wednesday (1964-12-30), a Thursday (1964-12-31), and a
Friday (1964-01-01), respectively.



=head2 When history changes take effect

The C<effective> field of the C<privhistory> and C<schedhistory> tables
contains the effective date/time of the history change. This field takes a
timestamp, and a trigger ensures that the value is evenly divisible by five
minutes (by rounding). In other words,

    '1964-06-13 14:45'

is a valid C<effective> timestamp, while

    '2014-01-01 00:00:01'

will be rounded to '2014-01-01 00:00'.



=head1 INSTALLATION

Installation is the process of creating (setting up, bootstrapping) a new
Dochazka instance, or "site" in Dochazka terminology.

It entails the following steps:

=over

=item * B<Server preparation>
Dochazka REST needs hardware (either physical or virtualized) to run on. 
The hardware will need to have a network connection, etc. Obviously, this
step is entirely beyond the scope of this document.

=item * B<Software installation>
Once the hardware is ready, the Dochazka REST software and all its
dependencies are installed on it.  This could be accomplished by
downloading and unpacking the tarball (or running C<git clone>) and
following the installation instructions, or, more expediently, by
installing a packaged version of Dochazka REST if one is available.

=item * B<PostgreSQL setup> -- 
One of Dochazka REST's principal dependencies is PostgreSQL server (version
9.2 or higher). This needs to be installed and most likely also enabled to
start automatically at boot.

=item * B<Site configuration> -- 
Before the Dochazka REST service can be started, the site administrator
will need to go over the core configuration defaults in
F<Dochazka_Config.pm> and prepare the site configuration,
F<Dochazka_SiteConfig.pm>, which will contain just those parameters that
need to be different from the defaults.

=item * B<Syslog setup> -- 
It is much easier to administer a Dochazka instance if C<syslog> is running
and configured properly to place Dochazka's log messages into a separate
file in a known location. Dochazka REST provides a C<syslog_test> script to
help the administrator complete this step.

=item * B<Database initialization> -- 
Once F<Dochazka_SiteConfig.pm> is ready, the administrator executes the
database initialization script as the PostgreSQL superuser, C<postgres>.
The script will send log messages to C<syslog> so these can be analyzed in
case the script generates an error.

=item * B<Service start> -- 
The last step is to start the Dochazka REST service using a command like
C<systemctl start dochazka.service> and, if desired, enable the service
to start automatically at boot. An examination of the C<syslog> messages
generated by Dochazka REST will tell whether the service has started
properly.

=back

The above procedure only includes the most basic steps. Sites with 
reverse proxies, firewalls, load balancers, connection pools, etc. will
need to set those up, as well.




=head1 AUTHENTICATION

=for comment
HAND WAVING

Since employees do not access the database directly, but only via the
C<App::Dochazka::REST> web server, the web server needs to tie all incoming requests
to an EID. This is done when the session is established (see L</Session
management>). In the site configuration, the administrator associates an LDAP
field with either EID or nick. When an employee initiates a session by
contacting the server, C<App::Dochazka::REST> first looks up the employee in the
LDAP database and determines her EID, either directly or via the employee's
nick. If the EID is valid, the password entered by the employee is checked
against the password stored in the LDAP database.

Alternatively, C<App::Dochazka::REST> can be configured to authenticate
employees against passwords stored in the Dochazka database.

When the REST server registers an incoming request, it first checks to see
if it is associated with an active session. If it is, the request is
processed. If it is not, the incoming request is authenticated.

Authentication consists of:

=over

=item * a check against Dochazka's own list (database) of employees

=item * an optional, additional check against an LDAP database

=back

Depending on how the REST server is configured, one of these will include a
password check. The server will send the client a session key, etc. 




=head1 REPORTING

Reporting is a core functionality of Dochazka: for most sites, the entire
point of keeping attendance records is to generate reports, at regular
(or irregular) intervals, based on those records. One obvious use case for
such reports is payroll. 

That said, the REST server and its underlying database are more-or-less
"reporting neutral". In other words, care was taken to make them as general
as possible, to enable Dochazka to be useful in many different site
and reporting scenarios.

Thus, in Dochazka a report generator is always implemented either a
separate client or as part of a client. Never as part of the server.



=head1 SITE CONFIGURATION PARAMETERS

Dochazka REST recognizes the following site configuration parameters:

...


=head1 EXPORTS

This module provides the following exports:

=over 

=item * C<$REST>
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



=head1 GLOSSARY OF TERMS

In Dochazka, some commonly-used terms have special meanings:

=over

=item * B<employee> -- 
Regardless of whether they are employees in reality, for the
purposes of Dochazka employees are the folks whose attendance/time is being
tracked.  Employees are expected to interact with Dochazka using the
following functions and commands.

=item * B<administrator> -- 
In Dochazka, administrators are employees with special powers. Certain
REST/CLI functions are available only to administrators.

=item * B<CLI client> --
CLI stands for Command-Line Interface. The CLI client is the Perl script
that is run when an employee types C<dochazka> at the bash prompt.

=item * B<REST server> --
REST stands for ... . The REST server is a collection of Perl modules 
running on a server at the site.

=item * B<site> --
In a general sense, the "site" is the company, organization, or place that
has implemented (installed, configured) Dochazka for attendance/time
tracking. In a technical sense, a site is a specific instance of the
Dochazka REST server that CLI clients connect to.

=back



=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>




=head1 BUGS

Please report any bugs or feature requests to 
C<bug-dochazka-rest at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Dochazka-REST>.  The author
will be notified, and then you'll automatically be notified of progress on your
bug as he makes changes.




=head1 SUPPORT

The full documentation comes with the distro, and can be comfortable
perused at metacpan.org:

    https://metacpan.org/pod/App::Dochazka::REST

You can also read the documentation for individual modules using the
perldoc command, e.g.:

    perldoc App::Dochazka::REST
    perldoc App::Dochazka::REST::Model::Activity

Other resources:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Dochazka-REST>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Dochazka-REST>

=back




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

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
use DBI;
use Data::Dumper;
use App::Dochazka::REST::Model::Activity;
use File::ShareDir;
use Try::Tiny;
use Web::Machine;

use parent 'App::Dochazka::REST::dbh';



=head1 NAME

App::Dochazka::REST - Dochazka REST server




=head1 VERSION

Version 0.134

=cut

our $VERSION = '0.134';


=head2 Development status

Dochazka is currently a Work In Progress (WIP). Do not expect it to do
anything useful.




=head1 SYNOPSIS

This is the top-level module of the Dochazka REST server.

    use App::CELL qw( $CELL $log $meta $site );
    use App::Dochazka::REST;
    use Carp;

    my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
    croak( $REST->{init_status}->text ) unless $REST->{init_status}->ok;

Read on for documentation.



=head1 DESCRIPTION

This is C<App::Dochazka::REST>, the Perl module that implements the REST
interface, data model, and underlying database of Dochazka, the open-source
Attendance/Time Tracking (ATT) system. 

Dochazka as a whole aims to be a convenient, open-source ATT solution. Its
reference implementation runs on the Linux platform. 


=head2 Dochazka architecture

There is more to Dochazka than C<App::Dochazka::REST>, of course. Dochazka REST
is the "server component" of Dochazka, consisting of a Plack/PSGI web server
(implemented using L<Web::Machine>) and a L<data model|"DATA MODEL">.

Once C<App::Dochazka::REST> is installed, configured, and running, a client
will be need in order to actually use Dochazka.

Though no client yet exists, two are planned: a command-line interface
(L<App::Dochazka::CLI>) and a web front-end (L<App::Dochazka::WebGUI>).
Stand-alone report generators and other utilities that may or may not ever
be implemented can also be thought of as clients.



=head1 REST INTERFACE

L<App::Dochazka::REST> attempts to present a I<REST>ful interface to potential
clients. For a description of what this means in practice, see L<...>.

In the HTTP request, the client should provide an C<Accept:> header specifying
either HTML (C<text/html>) or JSON (C<application/json>). If neither is specified,
the response body will be in HTML.

The REST interface consists of a number of resources. The resources are 
documented in the REST server itself, and can be explored using a web browser.
For example, if the URL of your Dochazka installation is
L<http://dochazka.site>, that's the place to start. The response to that
URL will show all the top-level resources. Then, if you want to explore a
resource further, you go to  L<http://dochazka.site/[RESOURCE]>.

The following top-level resources are used to create, read, update, and delete
attendance data:

=over

=item * employee

=item * privhistory

=item * schedhistory

=item * schedule

=item * activity

=item * interval

=item * lock

=back


=head2 Request-response cycle

(In order to protect user passwords from network sniffing and other nefarious
activities, the server may be set up to accept HTTPS requests only. These are
then decrypted to make HTTP requests. This document ignores this important
implementation detail. If this bothers you, you can treat 'HTTP' as an
abbreviation for 'HTTP and/or HTTPS'.)
f
Incoming HTTP requests are handled by L<App::Dochazka::REST::Resource>,
which inherits from L<Web::Machine::Resource>. The latter uses L<Plack> to
implement a PSGI-compliant stack.

L<Web::Machine> uses a "state-machine" approach to implementing the HTTP 1.1
standard. Incoming HTTP requests are processed by running them through a state
machine: the request goes in, and the response comes out. Each "cog" of the
state machine is a L<Web::Machine::Resource> method that can be overrided by a
child module. In our case, this module is L<App::Dochazka::REST::Resource>.

The behavior of the resulting web server can be characterized as follows:

=over

=item * B<UTF-8 assumed>

The server assumes all incoming requests are encoded in UTF-8, and it encodes
all of its responses in UTF-8 as well.

=item * B<Allowed methods test>

One of the first things the server looks at, when it receives a request, is 
the method. Only certain HTTP methods, such as 'GET' and 'POST', are accepted.
If this test fails, a "405 Method Not Allowed" response is sent.

=item * B<Internal and external authentication>

All incoming requests are subject to HTTP Basic Authentication. The credentials
entered by the user can be authenticated against an external database (LDAP),
and internal database (PostgreSQL 'employees' table), or both. For details, see
L<"AUTHENTICATION">. If authentication fails, a "401 Unauthorized" response is
sent. This should not be confused with the next step ("Authorization/ACL check").

In a web browser, repeated failed authentication attempts are typically
associated with repeated display of the credentials dialog (and no other
indication of what is wrong, which can be confusing to users but is probably a
good idea, because any error messages could be abused by attackers).

=item * B<Authorization/ACL check>

After the request is authenticated (i.e. associated with a known employee), the
server examines the resource being requested and compares it with the employee's
privilege level. If the privilege level is too low for the requested operation, 
a "403 Forbidden" response is sent.

=item * B<Test for resource existence>

The last test a request undergoes on its quest to become a response is the
test of resource existence. If the request is asking for a non-existent resource,
e.g. L<http://dochazka.site/employee/curent>, it cannot be fulfilled and a "404
Not Found" response will be sent.

As some readers might already have guessed, the server already knows whether 
or not the resource exists in the previous step, Authorization/ACL check. Each 
stop on the quest can only generate a single error message, however. To deal
with this quandary, the ACL check for non-existent resources is set to always
pass. This causes requests for non-existent resources to whizz right through
the ACL check, only to be caught by the Test for resource existence.

=item * B<Response generation> 

The Test for resource existence is the last test. If the request passes it,
a '200 OK' response is generated with an appropriate entity body.

=back



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
installing a packaged version of Dochazka REST if one is available
(see
L<https://build.opensuse.org/package/show/home:smithfarm/perl-App-Dochazka-REST>).

=item * B<PostgreSQL setup>

One of Dochazka REST's principal dependencies is PostgreSQL server (version
9.2 or higher). This needs to be installed (should happen automatically
when using the packaged version of L<App::Dochazka::REST>). Steps to enable
it:

    bash# chkconfig postgresql on
    bash#  systemctl start postgresql.service
    bash# su - postgres
    bash$ psql postgres
    postgres-# ALTER ROLE postgres WITH PASSWORD 'mypass';
    ALTER ROLE

At this point, we exit C<psql> and, still as the user C<postgres>, we 
edit C<pg_hba.conf>. Using our favorite editor, we change the METHOD entry
for C<local> so it looks like this:

    # TYPE  DATABASE   USER   ADDRESS     METHOD
    local   all        all                password

Then, as root, we restart the postgresql service:

    bash# systemctl restart postgresql.service

=item * B<Site configuration>

Before the Dochazka REST database can be initialized, we will need to
tell L<App::Dochazka::REST> about the PostgreSQL superuser password
that we set in the previous step. This is done via a site parameter. 
There may be other site params we will want to set, but the following
is sufficient to run the test suite. 

First, create a sitedir:

    bash# mkdir /etc/dochazka

and, second, a file therein:

    # cat << EOF > /etc/dochazka/Dochazka_SiteConfig.pm
    set( 'DBINIT_CONNECT_AUTH', 'mypass' );
    EOF
    #

(NOTE: Strictly speaking, this sitedir setup is only needed for database
initialization. During normal operation, L<App::Dochazka::REST> connects
to the database using the default user C<dochazka> and password
C<dochazka>. These are taken from the site parameters C<DOCHAZKA_DBUSER>
and C<DOCHAZKA_DBPASS>.)

=item * B<Syslog setup>

It is much easier to administer a Dochazka instance if C<syslog> is running
and configured properly to place Dochazka's log messages into a separate
file in a known location. In the future, L<App::Dochazka::REST> might
provide a C<syslog_test> script to help the administrator complete this
step.

=item * B<Database initialization>

In the future, there might be a nifty C<dochazka-dbinit> script to make
this process less painful, but for now the easiest way to initialize the
database is to clone the git repo from SourceForge and run the test suite:

    bash# cd ~/src
    bash# git clone git://git.code.sf.net/p/dochazka/code dochazka
    ...
    bash# cd dochazka
    bash# perl Build.PL
    bash# ./Build test

Assuming the previous steps were completed correctly, all the tests should
complete without errors.

=item * B<Start the server>

The last step is to start the Dochazka REST service. Maybe, in the future,
this will be possible using a command like C<systemctl start dochazka.service>.
Right now, though, an executable is run, as root, manually from the bash prompt:

    bash# dochazka-rest --host [HOST] --port 80 --access-log /var/log/dochazka-rest.log

or, as any user:

    bash$ dochazka-rest

=item * B<Take it for a spin>

Point your browser to the hostname you entered in the previous step, or to
L<http://0:5000/> if you didn't enter a hostname.

=back

The above procedure only includes the most basic steps. Sites with 
reverse proxies, firewalls, load balancers, connection pools, etc. will
need to set those up, as well.



=head1 AUTHENTICATION

Since employees do not access the database directly, but only via the
C<App::Dochazka::REST> web server, the web server needs to tie all incoming requests
to an EID. 

All incoming requests are subject to HTTP Basic Authentication. The credentials
entered by the user can be authenticated against an external database
(LDAP), and internal database (PostgreSQL 'employees' table), or both. 

This yields the following possible combinations: internal auth only, external
auth only, internal auth followed by external auth, and external auth followed
by internal auth. The desired combination can be set in the site configuration.



=head2 Current implementation

At the moment, this is accomplished via L<Web::Machine> using HTTP Basic
Authentication with a single hardcoded username/password combination
C<demo/demo>. 

This allows us to use, e.g., C<curl> like this:

    $ curl http://demo:demo@0:5000/


=head2 Possible future implementation

This is done when the session is established (see L</Session
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

=cut





=head1 METHODS



=head2 init

Load site configuration, set up logging, and connect to the database.

=cut

sub init {
    my ( $class, @ARGS ) = @_;
    croak( "Unbalanced PARAMHASH" ) if @ARGS % 2;
    my %ARGS = @ARGS;
    my $status;
    $status = $class->init_no_db( %ARGS );
    $status = $class->connect_db unless $status->not_ok;
    return bless { 
        app         => Web::Machine->new( resource => 'App::Dochazka::REST::Resource', )->to_app,
        dbh         => $class->SUPER::dbh,
        init_status => $status,
    }, __PACKAGE__;
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
    my $debug_mode = $ARGS{'debug_mode'} || 0;
    $log->init( ident => $site->DOCHAZKA_APPNAME, debug_mode => $debug_mode );
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
used. Returns status object which, on success, will contain the database
handle in the payload.

=cut

sub connect_db_pristine {
    my ( $class, @ARGS ) = @_;
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
    my $dbh;
    $dbh = DBI->connect(
        $data_source, 
        $ARGS{dbuser},
        $ARGS{dbpass},
        {
            PrintError => 0,
            RaiseError => 0,
            AutoCommit => 1,
        },
    ) or return $CELL->status_err( $dbh->errstr );
    $class->SUPER::init( $dbh );
    $log->notice( "Connected to " . $dbh->{Name} . 
                  " as username " . $dbh->{Username} );
    return $CELL->status_ok( 'OK', payload => $dbh );
}


    
=head2 connect_db

Connect to a pre-initialized database and initialize site params. This is
the function that should be used in production. Database name, username and
password are taken from DOCHAZKA_DBNAME, DOCHAZKA_DBUSER and DOCHAZKA_DBPASS,
respectively.

=cut

sub connect_db {
    my ( $self ) = @_;
    my $data_source = "Dbi:Pg:dbname=" . $site->DOCHAZKA_DBNAME;
    $log->info( "dbname is " . $site->DOCHAZKA_DBNAME );
    $log->info( "connect user is " . $site->DOCHAZKA_DBUSER );
    $log->debug( "Opening database connection to data_source " .
        "->$data_source<- username ->" .  $site->DOCHAZKA_DBPASS . "<-" 
    );
    my $dbh = DBI->connect(
        $data_source, 
        $site->DOCHAZKA_DBUSER, 
        $site->DOCHAZKA_DBPASS, 
        {
            PrintError => 0,
            RaiseError => 0,
            AutoCommit => 1,
        },
    ) or return $CELL->status_err( $DBI::errstr );
    __PACKAGE__->SUPER::init( $dbh );

    # initialize site params:

    # 1. get EID of root employee
    my ( $eid_of_root ) = $dbh->selectrow_array( 
                            $site->DBINIT_SELECT_EID_OF_ROOT, 
                            undef 
                                                       );
    $site->set( 'DOCHAZKA_EID_OF_ROOT', $eid_of_root );

    $log->notice( "Connected to " . $dbh->{Name} . 
                  " as username " . $dbh->{Username} );
    return $CELL->status_ok;
}
    


=head2 reset_db

Drop and re-create a Dochazka database. Takes database name. Do not call
when connected to an existing database. Be very, _very_, _VERY_ careful
when calling this function.

=cut

sub reset_db {
    my ( $self, $dbname ) = @_;

    my $status;

    # connect to 'postgres' database
    $status = __PACKAGE__->connect_db_pristine( 
        dbname => 'postgres',
        dbuser => $site->DBINIT_CONNECT_USER,
        dbpass => $site->DBINIT_CONNECT_AUTH,
    );
    return $status unless $status->ok;
    my $dbh = $status->payload;

    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 1;

    # drop user dochazka if it exists, otherwise ignore the error
    try {
        $dbh->do( 'DROP DATABASE IF EXISTS "' . $dbname . '"' );    
        $dbh->do( 'DROP USER dochazka' );
    };

    try {
        $dbh->do( 'CREATE USER dochazka' );
        $dbh->do( 'ALTER ROLE dochazka WITH PASSWORD \'dochazka\'' );
        $dbh->do( 'CREATE DATABASE "' . $dbname . '"' );    
        $dbh->do( 'GRANT ALL PRIVILEGES ON DATABASE "'.  $dbname . '" TO dochazka' );
    } catch {
        $status = $CELL->status_err( $DBI::errstr );
    };
    $dbh->disconnect;

    # connect to dochazka database as superuser
    $status = $self->connect_db_pristine( 
        dbname => $site->DOCHAZKA_DBNAME,
        dbuser => $site->DBINIT_CONNECT_USER,
        dbpass => $site->DBINIT_CONNECT_AUTH,
    );  
    return $status unless $status->ok;
    $dbh = $status->payload;

    try {
        $dbh->do( 'CREATE EXTENSION IF NOT EXISTS btree_gist' );
    } catch {
        $status = $CELL->status_err( $dbh->errstr );
    };
    $dbh->disconnect;

    $log->notice( 'Database ' . $dbname . ' dropped and re-created' ) if $status->ok;
    return $status;
}


=head2 create_tables

Takes a database handle, on which it executes all the SQL statements contained
in DBINIT_CREATE param.

=cut

sub create_tables {
    my ( $self, $dbh ) = @_;
    croak "Bad database handle" unless $dbh->ping;
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

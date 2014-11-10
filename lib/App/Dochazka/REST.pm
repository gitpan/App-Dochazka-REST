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
use Log::Any::Adapter;
use Params::Validate qw( :all );
use Try::Tiny;
use Web::Machine;

use parent 'App::Dochazka::REST::dbh';



=head1 NAME

App::Dochazka::REST - Dochazka REST server




=head1 VERSION

Version 0.265

=cut

our $VERSION = '0.265';


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
clients. To learn more about REST, its meaning and implications, see L<...>.

One of those implications is that clients communicate with the server using
the HTTP protocol, which is described L<...|here>.


=head2 Basic parameters

=head3 UTF-8

The server assumes all incoming requests are encoded in UTF-8, and it encodes
all of its responses in UTF-8 as well.

=head3 HTTP(S)

In order to protect user passwords from network sniffing and other nefarious
activities, the server may be set up to accept HTTPS requests only. Such a
setup may use a reverse proxy or a dedicated SSL-capable server. Since
HTTP-over-SSL is a complex topic, this document ignores it by assuming that
all client-server communications take place in plain text. If this bothers
you, you can read all occurrences of 'HTTP' in this document as meaning
'HTTP and/or HTTPS'.

=head3 Self-documenting

Another implication of REST is that the server provides "resources" and that
those resources are, to some extent at least, self-documenting.

L<App::Dochazka::REST> provides 'help' resources whose only purpose is to 
provide information about the resources available to the client at a 
particular base level. For example, the top-level help resource provides
a list of resources available at that level, some of which are lower-level
'help' resources.

For each resource, the 'help' resource provides a 'link' attribute with the
full URI of the resource and a 'description' attribute with a terse
description of what the resource is good for.

The definition of each resource includes an HTML string containing the
resource's documentation. This string can be accessed via POST request for
the C<docu> resource (provide the resource name in double quotes in the
request body).


=head2 Exploring the server

=head3 With a web browser

Only some of L<App::Dochazka::REST>'s resources (i.e, those that use the GET
method) are accessible using a web browser. That said, if we are only
interested in displaying information from the database, GET requests are all we
need and using a web browser can be convenient.  

To start exploring, fire up a standard web browser and point it to the base URI
of your L<App::Dochazka::REST> installation:

    http://dochazka.site

and entering one's credentials in the Basic Authentication dialog.


=head3 With a command-line HTTP client

To access all the resources, you will need a client that is capable of
generating POST, PUT, and DELETE requests as well as GET requests. Also, since
some of the information L<App::Dochazka::REST> provides is in the response
headers, the client needs to be capable of displaying those as well.

One such client is Daniel Stenberg's B<curl>.

In the HTTP request, the client may provide an C<Accept:> header specifying
either HTML (C<text/html>) or JSON (C<application/json>). For the convenience
of those using a web browser, HTML is the default.

Here are some examples of how to use B<curl> (or a web browser) to explore
resources. These examples assume a vanilla installation of
L<App::Dochazka::REST> with the default root password. The same commands can be
used with a production server, but keep in mind that the resources you will see
may be limited by your ACL privilege level.

=over 

=item * GET resources

The GET method is used to search for and display information. The top-level
GET resources are listed at the top-level URI, either using B<curl>

    $ curl -v -H 'Accept: application/json' http://demo:demo@dochazka.site/

Similarly, to display a list of sub-resources under the 'privhistory' top-level
resource, enter the command:

    $ curl http://demo:demo@dochazka.site/employee -H 'Accept: application/json' 

Oops - no resources are displayed because the 'demo' user has only passerby
privileges, but all the privhistory resources require at least 'active'. To
see all the available resources, we can authenticate as 'root':

    $ curl http://root:immutable@dochazka.site/employee -H 'Accept: application/json' 


=item * POST resources

With the GET method, we could only access resources for finding and displaying
information: we could not add, change, or delete information. For that we will
need to turn to some other client than the web browser -- a client like B<curl>
that is capable of generating HTTP requests with methods like POST (as well as
PUT and DELETE).

Here is an example of how we would use B<curl> to display the top-level POST
resources:

    curl -v http://root:immutable@dochazka.site -X POST -H "Content-Type: application/json"

The "Content-Type: application/json" header is necessary because the server
only accepts JSON in the POST request body -- even though in this case we 
did not send a request body, most POST requests will have one. For best
results, the request body should be a legal JSON string represented as a
sequence of bytes encoded in UTF-8.

=item * PUT resources

The PUT method is used to add new resources and update existing ones. Since
the resources are derived from the underlying database, this implies executing 
INSERT and UPDATE statements on tables in the database.

PUT resources can be explored using a B<curl> command analogous to the one
given for the POST method.

=item * DELETE resources

Any time we need to delete information -- i.e., completely wipe it from
the database, we will need to use the DELETE method. 

DELETE resources can be explored using a B<curl> command analogous to the one
given for the POST method.

Keep in mind that the data integrity constraints in the underlying PostgreSQL
database may make it difficult to delete a resource if any other resources
are linked to it. For example, an employee cannot be deleted until all
intervals, privhistory records, schedhistory records, locks, etc. linked to
that employee have been deleted. Intervals, on the other hand, can be 
deleted as long as they are not subject to a lock.

=back


=head2 Documentation of REST resources

In order to be "self-documenting", the definition of each REST resource
contains a "short" description and a "long" POD string. At each build, the
entire resource tree is walked to generate L<App::Dochazka::REST::Docs::Resources>.

Thus, besides directly accessing resources on the REST server itself, there
is also the option of perusing the documentation of all resources together in a
single POD module.


=head2 Request-response cycle

Incoming HTTP requests are handled by L<App::Dochazka::REST::Resource>,
which inherits from L<Web::Machine::Resource>. The latter uses L<Plack> to
implement a PSGI-compliant stack.

L<Web::Machine> takes a "state-machine" approach to implementing the HTTP 1.1
standard. Requests are processed by running them through a state
machine, each "cog" of which is a L<Web::Machine::Resource> method that can
be overridden by a child module. In our case, this module is
L<App::Dochazka::REST::Resource>.

The behavior of the resulting web server can be characterized as follows:

=over

=item * B<Allowed methods test>

One of the first things the server looks at, when it receives a request, is 
the method. Only certain HTTP methods, such as 'GET' and 'POST', are accepted.
If this test fails, a "405 Method Not Allowed" response is sent.

=item * B<Internal and external authentication, session management>

After the Allowed methods test, the user's credentials are authenticated
against an external database (LDAP), an internal database (PostgreSQL
'employees' table), or both. Session management techniques are utilized
to minimize external authentication queries, which impose latency. The
authentication and session management algorithms are described in,
L<"AUTHENTICATION AND SESSION MANAGEMENT">. If authentication fails, a "401
Unauthorized" response is sent. 

In a web browser, repeated failed authentication attempts are typically
associated with repeated display of the credentials dialog (and no other
indication of what is wrong, which can be confusing to users but is probably a
good idea, because any error messages could be abused by attackers).

Authentication (validation of user credentials to determine her identity)
should not be confused with authorization (determination whether the user
has sufficient privileges to do what she is trying to do). Authorization is
dealt with in the next step ("Authorization/ACL check").

=item * B<Authorization/ACL check>

After the request is authenticated (i.e. associated with a known employee), the
server examines the resource being requested and compares it with the employee's
privilege level. If the privilege level is too low for the requested operation, 
a "403 Forbidden" response is sent.

=item * B<Test for resource existence>

The next test a request undergoes on its quest to become a response is the
test of resource existence. If the request is asking for a non-existent resource,
e.g. L<http://dochazka.site/employee/curent>, it cannot be fulfilled and a "404
Not Found" response will be sent.

For GET requests, this is the last cog in the state machine: if the test
passes, a "200 OK" response is sent, along with a response body. Requests
using other methods (POST, PUT, DELETE) are subject to further processing
as described below.

=back

=head3 Additional processing (POST and PUT)

Because they are expected to have a request body, incoming POST and PUT
requests are subject to the following additional test:

=over

=item * B<malformed_request>

This test examines the request body. If it is non-existent, the test
passes. If the body exists and is valid JSON, the test passes. Otherwise,
it fails.

=item * B<known_content_type>

Test the request for the 'Content-Type' header. POST and PUT requests
should have a header that says:

    Content-Type: application/json

If this header is not present, a "415 Unsupported Media Type" response is
sent.

=back

=head3 Additional processing (POST)

=over 

=item * B<post_is_create>

This test examines the POST request and places it into one of two
categories: (1) generic request for processing, (2) a request that creates
or otherwise manipulates a resource. 

# FIXME: more verbiage needed

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

Users of Dochazka are referred to as "employees" regardless of their 
legal status -- in reality they might be independent contractors, or
students, or even household pets, but as far as Dochazka is concerned they
are employees. You could say that "employee" is the Dochazka term for "user". 

Employees are distinguished by an internal employee ID number (EID), which is
assigned by Dochazka itself when the employee record is created. For the 
convenience of humans using the system, employees are also distinguished
by a unique nickname, or 'nick'.

Other than the EID and the nick, which are required, Dochazka need not
record any other employee identification data. That said, Dochazka has
two additional employee identification fields (fullname, email), which some
sites may wish to use, but these are optional and can be left blank.
Dochazka does not verify the contents of these fields other than enforcing
a UNIQUE constraint to ensure that two or more employees cannot have the
exact same fullname or email address.

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

Lastly, check if you can connect to the C<postgres> database using the password:

    bash$ psql --username postgres postgres
    Password for user postgres: [...type 'mypass'...]
    psql (9.2.7)
    Type "help" for help.

    postgres=# \q
    bash$

=item * B<Site configuration>

Before the Dochazka REST database can be initialized, we will need to
tell L<App::Dochazka::REST> about the PostgreSQL superuser password
that we set in the previous step. This is done via a site parameter. 
There may be other site params we will want to set, but the following
is sufficient to run the test suite. 

First, create a sitedir:

    bash# mkdir /etc/dochazka-rest

and, second, a file therein:

    # cat << EOF > /etc/dochazka-rest/REST_SiteConfig.pm
    set( 'DOCHAZKA_REST_DEBUG_MODE', 1 );
    set( 'DBINIT_CONNECT_AUTH', 'mypass' );
    set( 'DOCHAZKA_REST_LOG_FILE', $ENV{'HOME'} . "/dochazka-rest.log" );
    set( 'DOCHAZKA_REST_LOG_FILE_RESET', 1);
    EOF
    #

Where 'mypass' is the PostgreSQL password you set in the 'ALTER
ROLE' command, above.

Strictly speaking, the C<DBINIT_CONNECT_AUTH> setting is only needed for
database initialization (see below), when L<App::Dochazka::REST> connects
to PostgreSQL as user 'postgres' to drop/create the database. Once the
database is created, L<App::Dochazka::REST> connects to it using the
PostgreSQL credentials set in the site parameters C<DOCHAZKA_DBUSER> and
C<DOCHAZKA_DBPASS> (by default: C<dochazka> with password C<dochazka>).

=item * B<Syslog setup>

The above site configuration includes C<DOCHAZKA_REST_LOG_FILE> so
L<App::Dochazka::REST> will write its log messages to a file in the home
directory of the user it is running as. Also, since
DOCHAZKA_REST_LOG_FILE_RESET is set to a true value, this log file will be
reset (zeroed) every time L<App::Dochazka::REST> starts. 

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

The last step is to start the Dochazka REST server. In the future, this
will be possible using a command like C<systemctl start dochazka.service>.
At the moment, however, we are still in development/testing phase and we 
start the server like this (as a normal user):

    $ cd ~/src/dochazka/App-Dochazka-REST
    $ ../dev.sh server dochazka-rest

=item * B<Take it for a spin>

Point your browser to L<http://localhost:5000/>

=back


=head1 AUTHENTICATION AND SESSION MANAGEMENT

Since employees do not access the database directly, but only via the
C<App::Dochazka::REST> web server, the web server needs to tie all incoming requests
to an EID. 

When an incoming request comes in, the headers and cookies are examined.
Requests that belong to an existing session have a cookie that looks like:

    Session ID: xdfke34irsdfslajoasdja;sldkf

while requests for a new session have a header that looks like this:

    Authorize: 

=head2 Existing session

In the former case, the HTTP request will contain a 'psgix.session' key
in its Plack environment. The value of this key is a hashref that contains
the session state.

If the session state is valid, it will contain:

=over

=item * the Employee ID, C<eid>

=item * the IP address from which the session was first originated, C<ip_addr>

=item * the date/time when the session was last seen, C<last_seen>

=back

If any of these are missing, or the difference between C<last_seen> and the
current date/time is greater than the time interval defined in the
C<DOCHAZKA_REST_SESSION_EXPIRATION_TIME>, the request is rejected with 401
Unauthorized.

=head2 New session

Requests for a new session are subject to HTTP Basic Authentication. The
credentials entered by the user can be authenticated against an external
database (LDAP), and internal database (PostgreSQL 'employees' table), or both. 

This yields the following possible combinations: internal auth only, external
auth only, internal auth followed by external auth, and external auth followed
by internal auth. The desired combination can be set in the site configuration.

If the request passes Basic Authentication, a session ID is generated and 
stored in a cookie. 




=head1 DEBUGGING

L<App::Dochazka::REST> offers the following debug facilities:

=over

=item * DOCHAZKA_DEBUG environment variable

If the C<DOCHAZKA_DEBUG> environment variable is set to a true value, the
entire 'context' will be returned in each JSON response, instead of just 
the 'entity'. For more information, see C<Resource.pm>.

=item * DOCHAZKA_REST_DEBUG_MODE site configuration parameter

If the C<DOCHAZKA_REST_DEBUG_MODE> site parameter is set to a true value,
debug messages will be logged.

=back

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
    my $self = shift;
    my %ARGS = validate( @_, { 
        sitedir => { type => SCALAR, optional => 1 },
        verbose => { type => SCALAR, optional => 1 },
        debug_mode => { type => SCALAR, optional => 1 },
    } );
    $log->info( Dumper( \%ARGS ) ) if $ARGS{verbose};

    # * load site configuration
    my $status = _load_config( %ARGS );
    return $status if $status->not_ok;

    # * set up logging
    return $CELL->status_not_ok( "DOCHAZKA_APPNAME not set!" ) if not $site->DOCHAZKA_APPNAME;
    my $debug_mode;
    if ( exists $ARGS{'debug_mode'} ) {
        $debug_mode = $ARGS{'debug_mode'};
    } else {
        $debug_mode = $site->DOCHAZKA_REST_DEBUG_MODE || 0;
    }
    unlink $site->DOCHAZKA_REST_LOG_FILE if $site->DOCHAZKA_REST_LOG_FILE_RESET;
    Log::Any::Adapter->set('File', $site->DOCHAZKA_REST_LOG_FILE );
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
    #$log->info( "connect_db_pristine: received " . scalar @ARGS . " arguments" );
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
    ) or return $CELL->status_crit( DBI->errstr );
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
    ) or return $CELL->status_crit( DBI->errstr );
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

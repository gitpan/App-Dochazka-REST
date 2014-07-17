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

package App::Dochazka::REST::Spec;

use 5.012;
use strict;
use warnings;

=pod

=encoding utf8




=head1 NAME

App::Dochazka::REST::Spec - Dochazka REST technical specification




=head1 VERSION

Version 0.072

=cut

our $VERSION = '0.072';





=head1 INTRODUCTION

This is the technical specification of C<App::Dochazka::REST>, the module that
implements the REST interface, data model, and underlying database of
Dochazka, the open-source Attendance/Time Tracking (ATT) system.
C<App::Dochazka::REST> is written in Perl. It uses PostgreSQL 9.2 for its
database backend and Plack for its web-related functions.

The specification attempts to fully explain Dochazka REST's design and
function. 

Dochazka as a whole aims to be a convenient, open-source ATT solution. Its
reference implementation runs on the Linux platform. 



=head2 Dochazka architecture

There is more to Dochazka than C<App::Dochazka::REST>, of course. Dochazka REST
is the "server component" of Dochazka, consisting of a web server, a data
model, and an underlying PostgreSQL database. In order to actually use
Dochazka, a client is needed. Several clients are planned: a command-line
interface (Dochazka CLI), a web front-end (Dochazka WWW). Stand-alone
report generators and other utilities can also be thought of as clients.



=head2 REST interface

Dochazka REST implements a I<REST> interface. A client sends HTTP(S)
requests (usually C<GET> and C<POST>) to a well-known hostname and port
where a Dochazka REST instance is listening. Dochazka REST processes the
incoming HTTP requests and sends back HTTP responses. Simpler requests
are made using the GET method with the details of the request specified in
the URL itself (e.g., http://dochazka.example.com/employee/Dolejsi).
More complex requests are encoded in JSON and handed to the server by the
POST method. All responses from the server are in JSON.



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


=head2 Employee

=head3 High-level description

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


=head3 Employees in the database

At the database level, C<App::Dochazka::REST> needs to be able to distinguish
one employee from another. This is accomplished by the EID. All the other
fields in the C<employees> table are optional. 

The C<employees> database table is defined as follows:

    CREATE TABLE employees (
        eid       serial PRIMARY KEY,
        nick      varchar(32) UNIQUE,
        fullname  varchar(96) UNIQUE,
        email     text UNIQUE,
        passhash  text,
        salt      text,
        remark    text,
        stamp     json
    )


=head4 EID

The Employee ID (EID) is Dochazka's principal means of identifying an 
employee. At the site, employees will be known by other means, like their
full name, their username, their user ID, etc. But these can and will
change from time to time. The EID should never, ever change.


=head4 nick

The C<nick> field is intended to be used for storing the employee's username.
While storing each employee's username in the Dochazka database has undeniable
advantages, it is not required - how employees are identified is a matter of
site policy, and internally Dochazka does not use the nick to identify
employees. Should the nick field have a value, however, Dochazka requires that
it be unique.


=head4 fullname, email

Dochazka does not maintain any history of changes to the C<employees> table. 

The C<full_name> and C<email> fields must also be unique if they have a
value. Dochazka does not check if the email address is valid. 

#
# FIXME: NOT IMPLEMENTED depending on how C<App::Dochazka::REST> is configured,
# these fields may be read-only for employees (changeable by admins only), or
# the employee may be allowed to maintain their own information.


=head4 passhash, salt

The passhash and salt fields are optional. See L</AUTHENTICATION> for
details.


=head4 remark, stamp

# FIXME



=head3 Employees in the Perl API

Individual employees are represented by "employee objects". All methods and
functions for manipulating these objects are contained in
L<App::Dochazka::REST::Model::Employee>. The most important methods are:

=over

=item * constructor (C<spawn>)

=item * basic accessors (C<eid>, C<fullname>, C<nick>, C<email>,
C<passhash>, C<salt>, C<remark>)

=item * privilege accessor (C<priv>)

=item * schedule accessor (C<schedule>)

=item * C<reset> (recycles an existing object by setting it to desired state)

=item * C<insert> (inserts object into database)

=item * C<update> (updates database to match the object)

=item * C<delete> (deletes record from database if nothing references it)

=item * C<load_by_eid> (loads a single employee into the object)

=item * C<load_by_nick> (loads a single employee into the object)

=back

L<App::Dochazka::REST::Model::Employee> also exports some convenience
functions:

=over

=item * C<eid_by_nick> (given a nick, returns EID)

=back

For basic C<employee> object workflow, see C<t/004-employee.t>.



=head2 Privhistory


=head3 High-level description

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

See also L<When history changes take effect>.


=head3 Privilege levels in the database

=head4 Type

The privilege levels themselves are defined in the C<privilege> enumerated
type:

    CREATE TYPE privilege AS ENUM ('passerby', 'inactive', 'active',
    'admin')


=head4 Table

Employees are associated with privilege levels using a C<privhistory>
table:

    CREATE TABLE IF NOT EXISTS privhistory (
        int_id     serial PRIMARY KEY,
        eid        integer REFERENCES employees (eid) NOT NULL,
        priv       privilege NOT NULL;
        effective  timestamp NOT NULL,
        remark     text,
        stamp      json
    );



=head4 Stored procedures

There are also two stored procedures for determining privilege levels:

=over

=item * C<priv_at_timestamp> 
Takes an EID and a timestamp; returns privilege level of that employee as
of the timestamp. If the privilege level cannot be determined for the given
timestamp, defaults to the lowest privilege level ('passerby').

=item * C<current_priv>
Wrapper for C<priv_at_timestamp>. Takes an EID and returns the current
privilege level for that employee.

=back


=head3 Privhistory in the Perl API

When an employee object is loaded (assuming the employee exists), the
employee's current privilege level and schedule are included in the employee
object. No additional object need be created for this. Privhistory objects
are created only when an employee's privilege level changes or when an
employee's privilege history is to be viewed.

In the data model, individual privhistory records are represented by
"privhistory objects". All methods and functions for manipulating these objects
are contained in L<App::Dochazka::REST::Model::Privhistory>. The most important
methods are:

=over

=item * constructor (C<spawn>)

=item * basic accessors (C<int_id>, C<eid>, C<priv>, C<effective>, C<remark>)

=item * C<reset> (recycles an existing object by setting it to desired state)

=item * C<load> (loads a single privhistory record)

=item * C<insert> (inserts object into database)

=item * C<delete> (deletes object from database)

=back

For basic C<privhistory> workflow, see C<t/005-privhistory.t>.




=head2 Schedule


=head3 High-level description

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


=head3 Schedules in the database


=head4 Table

Schedules are stored the C<schedules> table. For any given schedule, there is
always only one record in the table -- i.e., individual schedules can be used
for multiple employees. (For example, an organization might have hundreds of
employees on a single, unified schedule.) 

      CREATE TABLE IF NOT EXISTS schedules (
        sid        serial PRIMARY KEY,
        schedule   text UNIQUE NOT NULL
      );

The value of the 'schedule' field is a JSON array which looks something like this:

    [
        { low_dow:"MON", low_time:"08:00", high_dow:"MON", high_time:"12:00" ],  
        { low_dow:"MON", low_time:"12:30", high_dow:"MON", high_time:"16:30" ],  
        { low_dow:"TUE", low_time:"08:00", high_dow:"TUE", high_time:"12:00" ],  
        { low_dow:"TUE", low_time:"12:30", high_dow:"TUE", high_time:"16:30" ],
        ...
    ]   

Or, to give an example of a more convoluted schedule:

    [   
        { low_dow:"WED", low_time:"22:15", high_dow:"THU", high_time:"03:25" ], 
        { low_dow:"THU", low_time:"05:25", high_dow:"THU", high_time:"09:55" ],
        { low_dow:"SAT", low_time:"19:05", high_dow:"SUN", high_time:"24:00" ] 
    ] 

The intervals in the JSON string must be sorted and the whitespace, etc.
must be consistent in order for the UNIQUE constraint in the 'schedule'
table to work properly. However, these precautions will no longer be
necessary after PostgreSQL 9.4 comes out and the field type is changed to
'jsonb'.


=head4 Process for creating new schedules

It is important to understand how the JSON string introduced in the previous
section is assembled -- or, more generally, how a schedule is created. Essentially,
the schedule is first created in a C<schedintvls> table, with a record for each
time interval in the schedule. This table has triggers and a C<gist> index that 
enforce schedule data integrity so that only a valid schedule can be inserted.
Once the schedule has been successfully built up in C<schedintvls>, it is 
"translated" (using a stored procedure) into a single JSON string, which is
stored in the C<schedules> table. This process is described in more detail below:  

First, if the schedule already exists in the C<schedules> table, nothing
more need be done -- we can skip to L<Schedhistory>

If the schedule we need is not yet in the database, we will have to create it.
This is a three-step process: (1) build up the schedule in the C<schedintvls>
table (sometimes referred to as the "scratch schedule" table); (2) translate
the schedule to form the schedule's JSON representation; (3) insert the JSON
string into the C<schedules> table.

The C<schedintvls>, or "scratch schedule", table:

      CREATE SEQUENCE scratch_sid_seq;

      CREATE TABLE IF NOT EXISTS schedintvls (
          scratch_sid  integer NOT NULL,
          intvl        tsrange NOT NULL,
          EXCLUDE USING gist (scratch_sid WITH =, intvl WITH &&)
      );

As stated above, before the C<schedule> table is touched, a "scratch schedule"
must first be created in the C<schedintvls> table. Although this operation
changes the database, it should be seen as a "dry run". The C<gist> index and
a trigger assure that:

=over

=item * no overlapping entries are entered

=item * all the entries fall within a single 168-hour period

=item * all the times are evenly divisible by five minutes

=back

#
# FIXME: expand the trigger to check for "closed-open" C<< [ ..., ... ) >> tsrange
#

If the schedule is successfully inserted into C<schedintvls>, the next step is
to "translate", or convert, the individual intervals (expressed as tsrange
values) into the four-key hashes described in L<Schedules in the database>,
assemble the JSON string, and insert a new row in C<schedules>. 

To facilitate this conversion, a stored procedure C<translate_schedintvl> was
developed.

Successful insertion into C<schedules> will generate a Schedule ID (SID) for
the schedule, enabling it to be used to make Schedhistory objects.

At this point, the scratch schedule is deleted from the C<schedintvls> table. 


=head3 Schedules in the Perl API


=head4 C<Schedintvls> class

=over 

=item * constructor (C<spawn>)

=item * C<reset> method (recycles an existing object)

=item * basic C<scratch_sid> accessor

=item * C<intvls> accessor (arrayref containing all tsrange intervals in schedule) 

=item * C<schedule> accessor (arrayref containing "translated" intervals)

=item * C<load> method (load the object from the database and translate the tsrange intervals)

=item * C<insert> method (insert all the tsrange elements in one go)

=item * C<delete> method (delete all the tsrange elements when we're done with them)

=item * C<json> method (generate JSON string from the translated intervals)

=back

For basic workflow, see C<t/007-schedule.t>.


=head4 C<Schedule> class

=over

=item * constructor (C<spawn>)

=item * C<reset> method (recycles an existing object)

=item * basic accessors (C<sid>, C<schedule>, C<remark>)

=item * C<insert> method (inserts the schedule if it isn't in the database already)

# FIXME 
=item C<load> method (not implemented yet) 
# FIXME 

=item * C<get_json> function (get JSON string associated with a given SID)

=back

For basic workflow, see C<t/007-schedule.t>.



=head2 Schedhistory


=head3 High-level description

The C<schedhistory> table contains a historical record of changes in the
employee's schedule. This makes it possible to determine an employee's
schedule for any date (timestamp) in the past, as well as (crucially) the
employee's current schedule.

Every time an employee's schedule is to change, a Dochazka administrator
must insert a record into this table. (Employees who are not administrators
can only read their own history; they do not have write privileges.) For
more information on privileges, see L</AUTHORIZATION>.


=head3 Schedhistory in the database

=head4 Table

Once we know the SID of the schedule we would like to assign to a given
employee, it is time to insert a record into the C<schedhistory> table:

      CREATE TABLE IF NOT EXISTS schedhistory (
        int_id     serial PRIMARY KEY,
        eid        integer REFERENCES employees (eid) NOT NULL,
        sid        integer REFERENCES schedules (sid) NOT NULL,
        effective  timestamp NOT NULL,
        remark     text,
        stamp      json
      );

=head4 Stored procedures

This table also includes two stored procedures -- C<schedule_at_timestamp> and
C<current_schedule> -- which will return an employee's schedule as of a given
date/time and as of 'now', respectively. For the procedure definitions, see
C<dbinit_Config.pm>

See also L<When history changes take effect>.


=head3 Schedhistory in the Perl API

=head4 C<Schedhistory> class

=over

=item * constructor (C<spawn>)

=item * C<reset> method (recycles an existing object)

=item * basic accessors (C<int_id>, C<eid>, C<sid>, C<effective>, C<remark>)

=item * C<load> method (load schedhistory record from EID and optional timestamp)

=item * C<insert> method (straightforward)

=item * C<delete> method (straightforward) -- not tested yet # FIXME

=back

For basic workflow, see C<t/007-schedule.t>.




=head2 Activity


=head3 High-level description

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


=head3 Activities in the database 


   CREATE TABLE activities (
       aid        serial PRIMARY KEY,
       code       varchar(32) UNIQUE NOT NULL,
       long_desc  text,
       remark     text
   )

Activity codes will always be in ALL CAPS thanks to a trigger (entitled 
C<code_to_upper>) that runs the PostgreSQL C<upper> function on the code
before every INSERT and UPDATE on this table.



=head3 Activities in the Perl API

=head4 L<App::Dochazka::REST::Model::Activity>

=over

=item * constructor (C<spawn>)

=item * basic accessors (C<aid>, C<code>, C<long_desc>, C<remark>)

=item * C<reset> (recycles an existing object by setting it to desired state)

=item * C<insert> (inserts object into database)

=item * C<update> (updates database to match the object)

=item * C<delete> (deletes record from database if nothing references it)

=item * C<load_by_aid> (loads a single employee into the object)

=item * C<load_by_code> (loads a single employee into the object)

=back

L<App::Dochazka::REST::Model::Activity> also exports some convenience
functions:

=over

=item * C<aid_by_code> (given a code, returns AID)

=back

For basic C<activity> object workflow, see C<t/008-activity.t>.



=head2 Interval


=head3 High-level description

Intervals are the heart of Dochazka's attendance data. For Dochazka, an
interval is an amount of time that an employee spends doing an activity.
In the database, intervals are represented using the C<tsrange> range
operator introduced in PostgreSQL 9.2.

Optionally, an interval can have a C<long_desc> (employee's description
of what she did during the interval) and a C<remark> (admin remark).


=head3 Intervals in the database

The C<intervals> database table has the following structure:

    CREATE TABLE intervals (
       int_id      serial PRIMARY KEY,
       eid         integer REFERENCES employees (eid) NOT NULL,
       aid         integer REFERENCES activities (aid) NOT NULL,
       intvl       tsrange NOT NULL,
       long_desc   text,
       remark      text,
       EXCLUDE USING gist (eid WITH =, intvl WITH &&)
    );


=head3 Intervals in the Perl API

# FIXME: MISSING VERBIAGE



=head2 Lock


=head3 High-level description

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


=head3 Locks in the database

    CREATE TABLE locks (
        lid     serial PRIMARY KEY,
        eid     integer REFERENCES Employees (EID),
        period  tsrange NOT NULL,
        remark  text
    )

There is also a stored procedure, C<fully_locked>, that takes an EID
and a tsrange, and returns a boolean value indicating whether or not
that period is fully locked for the given employee.


=head3 Locks in the Perl API

# FIXME: MISSING VERBIAGE




=head1 EXAMPLES

=head2 History examples

=head3 Mr. Fu joins the firm

For example, Mr. Fu was hired and his first day on the job was 2014-06-04. The
C<privhistory> entry for that might be:

    int_id     1037 (automatically assigned by PostgreSQL)
    eid        135 (Mr. Fu's Dochazka EID)
    priv       'active'
    effective  '2014-06-04 00:00'

Let's say Mr. Fu's initial schedule is 09:00-17:00, Monday to Friday. To
reflect that, the C<schedintvls> table might contain the following intervals
for C<< sid = 9 >>

    '[2014-06-02 09:00, 2014-06-02 17:00)'
    '[2014-06-03 09:00, 2014-06-03 17:00)'
    '[2014-06-04 09:00, 2014-06-04 17:00)'
    '[2014-06-05 09:00, 2014-06-05 17:00)'
    '[2014-06-06 09:00, 2014-06-06 17:00)'

and the C<schedhistory> table would contain a record like this:

    sid       1037 (automatically assigned by PostgreSQL)
    eid       135 (Mr. Fu's Dochazka EID)
    sid       9
    effective '2014-06-04 00:00'

(This is a straightfoward example.)


=head3 Mr. Fu goes on night shift

A few months later, Mr. Fu gets assigned to the night shift. A new
C<schedhistory> record is added:

    int_id     1215 (automatically assigned by PostgreSQL)
    eid        135 (Mr. Fu's Dochazka EID)
    sid        17 (link to Mr. Fu's new weekly work schedule)
    effective  '2014-11-17 12:00'

And the schedule intervals for C<< sid = 17 >> could be:

    '[2014-06-02 23:00, 2014-06-03 07:00)'
    '[2014-06-03 23:00, 2014-06-04 07:00)'
    '[2014-06-04 23:00, 2014-06-05 07:00)'
    '[2014-06-05 23:00, 2014-06-06 07:00)'
    '[2014-06-06 23:00, 2014-06-07 07:00)'
    
(Remember: the date part in this case designates the day of the week)


=head3 Mr. Fu moves on

Some weeks later, Mr. Fu decides he doesn't like the night shift and
resigns.  His last day on the job is 2014-12-31. To reflect this, a
Dochazka admin adds a new record to the C<privhistory> table:

    int_id     1263 (automatically assigned by PostgreSQL)
    eid        135 (Mr. Fu's Dochazka EID)
    priv       'inactive'
    effective  '2015-01-01 00:00'

Note that Dochazka will begin enforcing the new privilege level as of 
C<effective>, and not before. However, if Dochazka's session management
is set up to use LDAP authentication, Mr. Fu's access to Dochazka may be
revoked at any time at the LDAP level, effectively shutting him out.



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

=item * Server preparation
Dochazka REST needs hardware (either physical or virtualized) to run on. 
The hardware will need to have a network connection, etc. Obviously, this
step is entirely beyond the scope of this document.

=item * Software installation
Once the hardware is ready, the Dochazka REST software and all its
dependencies are installed on it.  This could be accomplished by
downloading and unpacking the tarball (or running C<git clone>) and
following the installation instructions, or, more expediently, by
installing a packaged version of Dochazka REST if one is available.

=item * PostgreSQL setup
One of Dochazka REST's principal dependencies is PostgreSQL server (version
9.2 or higher). This needs to be installed and most likely also enabled to
start automatically at boot.

=item * Site configuration
Before the Dochazka REST service can be started, the site administrator
will need to go over the core configuration defaults in
F<Dochazka_Config.pm> and prepare the site configuration,
F<Dochazka_SiteConfig.pm>, which will contain just those parameters that
need to be different from the defaults.

=item * Syslog setup
It is much easier to administer a Dochazka instance if C<syslog> is running
and configured properly to place Dochazka's log messages into a separate
file in a known location. Dochazka REST provides a C<syslog_test> script to
help the administrator complete this step.

=item * Database initialization
Once F<Dochazka_SiteConfig.pm> is ready, the administrator executes the
database initialization script as the PostgreSQL superuser, C<postgres>.
The script will send log messages to C<syslog> so these can be analyzed in
case the script generates an error.

=item * Service start
The last step is to start the Dochazka REST service using a command like
C<systemctl start dochazka.service> -- and, if desired, enable the service
to start automatically at boot. Here again, an examination of the C<syslog>
messages generated by Dochazka REST will tell whether the service has
started properly.

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




=head1 AUTHORIZATION


After authentication, the session undergoes authorization. This entails
looking up the employee's current privilege level in the C<EmployeeHistory>
table. See L</EmployeeHistory> for details.




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


#=head2 Site policy
#
#Dochazka is configurable in a number of ways. Some configuration parameters
#are set once at installation time and, once set, can never be changed --
#these are referred to as "site policy" parameters.  Others, referred to as
#"site configuration parameters" or "site params", are set in configuration
#files such as C<Dochazka_SiteConfig.pm> (see L</SITE CONFIGURATION>) and
#can be changed more-or-less at will.
#
#The key difference between site policy and site configuration is that 
#site policy parameters cannot be changed, because changing them would
#compromise the referential integrity of the underlying database. 
#
#Site policy parameters are set at installation time and are stored, as a
#single JSON string, in the C<SitePolicy> table. This table is rendered
#effectively immutable by a trigger.
#
##FIXME: TRIGGER DEFINITION (missing in dbinit_Config.pm)
#
#
#=head3 Site policy in the database
#
#    SitePolicy
#
#    defaults   json
#
#
#=head3 Site policy parameters
#
#Dochazka implements the following site policy parameters:
#
##FIXME: WHAT OTHER POLICY PARAMETERS ARE THERE?

=cut

1;

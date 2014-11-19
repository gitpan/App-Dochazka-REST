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

# -----------------------------------
# App::Dochazka::REST
# -----------------------------------
# config/dispatch/interval_Config.pm
#
# Path dispatch configuration file for interval resources
# -----------------------------------


# DISPATCH_RESOURCES_INTERVAL
#    - value is a hash, the keys of which are resource paths
#    - the values of those keys are hashes containing resource metadata
set( 'DISPATCH_RESOURCES_INTERVAL', {

    'interval/eid/:eid/:tsrange' => 
    {
        target => {
#            GET => '_fetch_by_eid',
            GET => 'not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Interval',
        acl_profile => 'admin', 
        cli => 'interval eid $EID $TSRANGE',
        description => 'Retrieve an arbitrary employee\'s intervals over the given tsrange',
        documentation => <<'EOH',
=pod

With this resource, administrators can retrieve any employee's intervals 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.
EOH
    },
    'interval/help' =>
    { 
        target => {
            GET => '_get_default',
            POST => '_post_default',
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Interval',
        acl_profile => 'passerby', 
        cli => 'interval help',
        description => 'Display available interval resources for given HTTP method',
        documentation => <<'EOH',
=pod

Displays information on all interval resources available to the logged-in
employee, according to her privlevel.
EOH
    },
    'interval/iid' => 
    {
        target => {
            POST => '_iid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Interval',
        acl_profile => 'active', 
        cli => 'interval iid $JSON',
        description => 'Update an existing interval object via POST request (iid must be included in request body)',
        documentation => <<'EOH',
=pod

Enables existing interval objects to be updated by sending a POST request to
the REST server. Along with the properties to be modified, the request body
must include an 'iid' property, the value of which specifies the iid to be
updated.
EOH
    },
    'interval/iid/:iid' => 
    {
        target => {
            GET => '_iid',
            PUT => '_iid',
            DELETE => '_iid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Interval',
        acl_profile => {
            GET => 'active',
            PUT => 'active',
            DELETE => 'active',
        },
        cli => 'interval iid $iid [$JSON]',
        description => 'GET, PUT, or DELETE an interval object by its iid',
        documentation => <<'EOH',
=over

=item * GET

Retrieves an interval object by its iid.

=item * PUT

Updates the interval object whose iid is specified by the ':iid' URI parameter.
The fields to be updated and their new values should be sent in the request
body, e.g., like this:

    { "eid" : 34, "aid" : 1, "intvl" : '[ 2014-11-18 08:00, 2014-11-18 12:00 )' }

=item * DELETE

Deletes the interval object whose iid is specified by the ':iid' URI parameter.
As long as the interval does not overlap with a lock interval, the delete operation
will probably work as expected.

=back

ACL note: 'active' employees can update/delete only their own unlocked intervals.
EOH
    },
    'interval/new' => 
    {
        target => {
            POST => '_new',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Interval',
        acl_profile => 'active', 
        cli => 'interval new $JSON',
        description => 'Add a new attendance data interval',
        documentation => <<'EOH',
=pod

This is the resource by which employees add new attendance data to the
database. It takes a request body containing, at the very least, C<aid> and
C<intvl> properties. Additionally, it can contain C<long_desc>, while
administrators can also specify C<eid> and C<remark>.
EOH
    },
    'interval/nick/:nick/:tsrange' => 
    {
        target => {
#            GET => '_fetch_by_nick',
            GET => 'not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Interval',
        acl_profile => 'admin', 
        cli => 'interval nick $NICK $TSRANGE',
        description => 'Retrieve an arbitrary employee\'s intervals over the given tsrange',
        documentation => <<'EOH',
=pod

With this resource, administrators can retrieve any employee's intervals 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.
EOH
    },
    'interval/self/:tsrange' => 
    {
        target => {
#            GET => '_fetch_own',
            GET => 'not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Interval',
        acl_profile => 'inactive', 
        cli => 'interval self $TSRANGE',
        description => 'Retrieve one\'s own intervals over the given tsrange',
        documentation => <<'EOH',
=pod

With this resource, employees can retrieve their own attendance intervals 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.
EOH
    },

});

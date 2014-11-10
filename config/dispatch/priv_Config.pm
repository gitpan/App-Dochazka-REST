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
# config/dispatch/priv_Config.pm
#
# Path dispatch configuration file for privhistory resources
# -----------------------------------


# DISPATCH_RESOURCES_PRIV
#    - value is a hash, the keys of which are resource paths
#    - the values of those keys are hashes containing resource metadata
set( 'DISPATCH_RESOURCES_PRIV', {

    'priv/self/?:ts' => 
    { 
        target => {
            GET => '_current_priv',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'passerby', 
        cli => 'priv self [$TIMESTAMP]',
        description => 'Get the present privlevel of the currently logged-in employee, or with optional timestamp, that employee\'s privlevel as of that timestamp',
        documentation => <<'EOH',
=pod

This resource retrieves the privlevel of the caller (currently logged-in employee).

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.
EOH
    },
    'priv/eid/:eid/?:ts' => 
    { 
        target => {
            GET => '_current_priv',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'admin', 
        cli => 'priv eid $EID [$TIMESTAMP]',
        description => 'Get the present privlevel of arbitrary employee, or with optional timestamp, that employee\'s privlevel as of that timestamp',
        documentation => <<'EOH',
=pod

This resource retrieves the privlevel of an arbitrary employee specified by EID.

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.
EOH
    },
    'priv/help' =>
    { 
        target => {
            GET => '_get_default',  # _get_default is the name of a subroutine in 
                                    # the module pointed to by the 'target_module'
                                    # property, below
            POST => '_post_default',
            PUT => '_put_default',
            DELETE => '_delete_default',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'passerby', 
        cli => 'priv help',
        description => 'Display priv resources',
        documentation => <<'EOH',
=pod

This resource retrieves a listing of all resources available to the
caller (currently logged-in employee).
EOH
    },
    'priv/history/eid/:eid' =>
   { 
        target => {
            GET => '_history_eid', 
            PUT => '_history_eid',
            DELETE => '_history_eid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'admin',
        cli => 'priv history eid $EID [$JSON]',
        description => 'Retrieves entire history of privilege level changes for employee with the given EID (GET); or, with an appropriate content body, adds (PUT) or deletes (DELETE) a record to employee\'s privhistory',
        documentation => <<'EOH',
=pod

=over

=item * GET

Retrieves the "privhistory", or history of changes in
privilege level, of the employee with the given EID.

=item * PUT

Adds a record to the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=item * DELETE

Deletes a record from the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=back
EOH
    },
    'priv/history/eid/:eid/:tsrange' =>
    {
        target => {
            GET => '_history_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'admin',
        cli => 'priv history eid $EID $TSRANGE',
        description => 'Get a slice of history of privilege level changes for employee with the given EID',
        documentation => <<'EOH',
=pod

Retrieves a slice (given by the tsrange argument) of the employee's
"privhistory" (history of changes in privilege level).
EOH
    },
    'priv/history/nick/:nick' =>
    { 
        target => {
            GET => '_history_nick', 
            PUT => '_history_nick', 
            DELETE => '_history_nick',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'admin',
        cli => 'priv history nick $NICK [$JSON]',
        description => 'Retrieves entire history of privilege level changes for employee with the given nick (GET); or, with an appropriate content body, adds (PUT) or deletes (DELETE) a record to employee\'s privhistory',
        documentation => <<'EOH',
=pod

=over

=item * GET

Retrieves the "privhistory", or history of changes in
privilege level, of the employee with the given nick.

=item * PUT

Adds a record to the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=item * DELETE

Deletes a record from the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=back
EOH
    },
    'priv/history/nick/:nick/:tsrange' =>
    { 
        target => {
            GET => '_history_nick', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'admin',
        cli => 'priv history nick $NICK $TSRANGE',
        description => 'Get partial history of privilege level changes for employee with the given nick ' . 
                     '(i.e, limit to given tsrange)',
        documentation => <<'EOH',
=pod

Retrieves a slice (given by the tsrange argument) of the employee's
"privhistory" (history of changes in privilege level).
EOH
    },
    'priv/history/phid/:phid' => 
    {
        target => {
            GET => '_priv_by_phid',
            DELETE => '_priv_by_phid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'admin',
        cli => 'priv history phid $PHID',
        description => 'Retrieves (GET) or deletes (DELETE) a single privilege history record by its PHID',
        documentation => <<'EOH',
=pod

=over

=item * GET

Retrieves a privhistory record by its PHID.

=item * DELETE

Deletes a privhistory record by its PHID.

=back

(N.B.: to add a privhistory record, use "PUT priv/history/eid/:eid" or
"PUT priv/history/nick/:nick")
EOH
    },
    'priv/history/self/?:tsrange' =>
    { 
        target => {
            GET => '_history_self', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'active',
        cli => 'priv history self [$TSRANGE]',
        description => 'Retrieves privhistory of present employee, with option to limit to :tsrange',
        documentation => <<'EOH',
=pod

This resource retrieves the "privhistory", or history of changes in
privilege level, of the present employee. Optionally, the listing can be
limited to a specific tsrange such as "[2014-01-01, 2014-12-31)".
EOH
    },
    'priv/nick/:nick/?:ts' => 
    { 
        target => {
            GET => '_current_priv',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'admin', 
        cli => 'priv nick $NICK [$TIMESTAMP]',
        description => 'Get the present privlevel of arbitrary employee, or with optional timestamp, that employee\'s privlevel as of that timestamp',
        documentation => <<'EOH',
=pod

This resource retrieves the privlevel of an arbitrary employee specified by nick.

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.
EOH
    },

});

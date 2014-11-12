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

package App::Dochazka::REST::Docs::Workflow;

use 5.012;
use strict;
use warnings FATAL => 'all';


our $VERSION = 0.272;

1;
__END__


=head1 NAME

App::Dochazka::REST::Docs::Workflow - Documentation of REST workflow


=head1 DESCRIPTION

This is a POD-only module containing documentation describing standard Dochazka
workflow scenarios and the REST resources used therein.

It is intended to be used in the functional testing process.

=head1 WORKFLOW SCENARIOS

The workflow scenarios are divided into sections according to the privlevel of
the logged-in employee doing the "work" - i.e., interacting with the Dochazka
REST server.

The workflow scenarios are presented in order of increasing privilege.
Employees with higher privilege can perform all the workflow scenarios
available to those of lower privilege.


=head2 passerby

Passerby is the default privlevel. In other words, employees without any
privhistory entries will automatically be assigned this privlevel.

Passerby employees (which need not be "employees" in a legal sense) can engage
in the following workflows:

=head3 Login

If LDAP authentication is enabled and C<DOCHAZKA_LDAP_AUTOCREATE> is set, a new
passerby employee will be created whenever an as-yet unseen employee logs in
(authenticates herself to the REST server). Otherwise, a passerby employee can
log in only if an administrator has created the corresponding employee profile.

=head3 View own employee profile

Using C<GET employee/current>, any employee can view her own employee profile.
The payload is a valid employee object.

Alternatively, C<GET employee/current/priv> can be used, in which case the
employee's current privilege level and schedule are returned along with the
employee object.

=head3 Explore available resources 

Any logged-in employee is free to explore available resources. The starting
point for such exploration can be C<GET /> (i.e. a GET request for the
top-level resource). The information returned is specific to the HTTP method
used, so for PUT resources one needs to use C<PUT />, etc.

Only accessible resources are displayed. For example, a passerby employee will
not see admin resources. A few resources (e.g. C<activity/aid/:aid>), have
different ACL profiles depending on which HTTP method is used.


=head3 

=head2 active


=head2 admin




=head1 AUTHOR

Nathan Cutler C<ncutler@suse.cz>

=cut

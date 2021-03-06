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
# config/dispatch_Config.pm
#
# Path dispatch configuration file
# -----------------------------------


# DISPATCH_RESOURCE_LISTS
#    list of resource lists -- see, e.g., dispatch_Employee_Config.pm
set( 'DISPATCH_RESOURCE_LISTS', [
    [ 'DISPATCH_RESOURCES_TOP' => <<'EOH' ],
=head2 Top-level

Miscellaneous resources that don't fit under any specific category.

EOH
    [ 'DISPATCH_RESOURCES_ACTIVITY' => <<'EOH' ],
=head2 Activity

Resources related to activities.

EOH
    [ 'DISPATCH_RESOURCES_EMPLOYEE' => <<'EOH' ],
=head2 Employee

Resources related to employee profiles.

EOH
    [ 'DISPATCH_RESOURCES_PRIV' => <<'EOH' ],
=head2 Privilege

Resources related to employee privileges and privhistories.

EOH
    [ 'DISPATCH_RESOURCES_SCHEDULE' => <<'EOH' ],
=head2 Schedule

Resources related to employee schedules and schedhistories.

EOH
    [ 'DISPATCH_RESOURCES_INTERVAL' => <<'EOH' ],
=head2 Interval

Resources related to attendance intervals

EOH
    [ 'DISPATCH_RESOURCES_LOCK' => <<'EOH' ],
=head2 Lock

Resources related to lock intervals

EOH
] );

1;

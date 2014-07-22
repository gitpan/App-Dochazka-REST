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
# Dochazka-REST
# -----------------------------------
# Dochazka_Config.pm
#
# Main configuration file
# -----------------------------------


# DOCHAZKA_REST_HTML
#    what we display when someone opens us in a browser
set( 
    'DOCHAZKA_REST_HTML',
    '<html><body><h1>App::Dochazka::REST</h1><p>For documentation, ' . 
    'see <a href="https://metacpan.org/pod/App::Dochazka::REST">' . 
    'https://metacpan.org/pod/App::Dochazka::REST</a></p></body></html>'
);

# DOCHAZKA_APPNAME
#    name of application for logging purposes
set( 'DOCHAZKA_APPNAME', 'Dochazka-test' );

# DOCHAZKA_DBNAME
#    name of PostgreSQL database to use
set( 'DOCHAZKA_DBNAME', 'dochazka-test' );

# DOCHAZKA_DBUSER
#    name of PostgreSQL username (role) to connect with
set( 'DOCHAZKA_DBUSER', 'dochazka' );

# DOCHAZKA_DBPASS
#    name of PostgreSQL username (role) to connect with
set( 'DOCHAZKA_DBPASS', 'dochazka' );

# DOCHAZKA_EID_OF_ROOT
#    Employee ID of the root employee -- set in Employee.pm (do not set
#    here)
#!! DO NOT SET HERE !!

# DOCHAZKA_ACTIVITY_DEFINITIONS
#    Initial set of activity definitions - sample only - override this in
#    Dochazka_SiteConfig.pm
set( 'DOCHAZKA_ACTIVITY_DEFINITIONS', [
        { code => 'WORK', long_desc => 'Work' },
        { code => 'OVERTIME_WORK', long_desc => 'Overtime work' },
        { code => 'PAID_VACATION', long_desc => 'Paid vacation' },
        { code => 'UNPAID_LEAVE', long_desc => 'Unpaid leave' },
        { code => 'DOCTOR_APPOINTMENT', long_desc => 'Doctor appointment' },
        { code => 'CTO', long_desc => 'Compensation Time Off' },
        { code => 'SICK_DAY', long_desc => 'Discretionary sick leave' },
        { code => 'MEDICAL_LEAVE', long_desc => 'Statutory medical leave' },
    ] );   

# DOCHAZKA_ADVANCE_INTERVALS_MAX_DAYS
#     Some employees may try to fill out their attendance days, weeks, 
#     or even months in advance. This sets the maximum number of days
#     in advance that Dochazka will accept an activity interval.
set( 'DOCHAZKA_ADVANCE_INTERVALS_MAX_DAYS', 45 );


# -----------------------------------
# DO NOT EDIT ANYTHING BELOW THIS LINE
# -----------------------------------
use strict;
use warnings;

1;

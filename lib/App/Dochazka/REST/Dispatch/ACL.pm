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

# ------------------------
# ACL module
# ------------------------

package App::Dochazka::REST::Dispatch::ACL;

use strict;
use warnings;

use App::CELL qw( $CELL $log );
use Data::Dumper;
use Params::Validate qw( :all );



=head1 NAME

App::Dochazka::REST::Dispatch::ACL - ACL module





=head1 VERSION

Version 0.322

=cut

our $VERSION = '0.322';





=head1 DESCRIPTION

This module provides helper code for ACL checks.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( check_acl check_acl_context );




=head1 PACKAGE VARIABLES

The 'check_acl' routine uses a hash to look up which privlevels 
satisfy a given ACL profile.

=cut

my %acl_lookup = (
    'admin' => { 'passerby' => '', 'inactive' => '', 'active' => '', 'admin' => '' },
    'active' => { 'passerby' => '', 'inactive' => '', 'active' => '' },
    'inactive' => { 'passerby' => '', 'inactive' => '' },
    'passerby' => { 'passerby' => '', },
);




=head1 FUNCTIONS

=head2 check_acl

Compare ACL profile of a resource, C<$profile>, with the privlevel of the current
employee, C<$privlevel>. If the former is at least as high as the latter, the
function returns true, otherwise false.

=cut

sub check_acl {
    my ( $profile, $privlevel ) = validate_pos( @_,
        { type => SCALAR | UNDEF }, 
        { type => SCALAR | UNDEF }, 
    );

    my $levels = qr/^(passerby)|(inactive)|(active)|(admin)$/;

    $log->debug( "Entering " . __PACKAGE__ . "::check_acl with \$profile " . Dumper( $profile )
        . " and \$privlevel " . Dumper( $privlevel ) );

    # handle undef
    # - the ACL profile might be undefined (e.g. "/forbidden")
    return 0 unless defined $profile;
    # - the privlevel should always be defined
    die "Current employee has undefined privlevel" unless defined $privlevel;

    # check for priv validity
    die "Invalid ACL profile" unless $profile =~ $levels;
    die "Invalid employee privlevel" unless $privlevel =~ $levels;

    return 1 if exists $acl_lookup{$privlevel}->{$profile};

    return 0;
}


=head2 check_acl_context

Check ACL and compare with eid in request body. This routine is designed
for resources that have an ACL profile of 'active'. If the request body
contains an 'eid' property, it is checked against the current user's EID.  If
they are different and the current user's priv is 'active',
DOCHAZKA_FORBIDDEN_403 is returned; otherwise, an OK status is returned to
signify that the check passed.

If the request body does not contain an 'eid' property, it is added.

=cut

sub check_acl_context {
    my $context = shift;
    my $current_eid = $context->{'current'}->{'eid'};
    my $current_priv = $context->{'current_priv'};
    if ( $current_priv eq 'passerby' or $current_priv eq 'inactive' ) {
        return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
    }
    if ( $context->{'request_body'}->{'eid'} ) {
        my $desired_eid = $context->{'request_body'}->{'eid'};
        if ( $desired_eid != $current_eid ) {
            return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' ) if $current_priv eq 'active';
        }
    } else {
        $context->{'request_body'}->{'eid'} = $current_eid;
    }
    return $CELL->status_ok('DOCHAZKA_ACL_CHECK');
}

1;

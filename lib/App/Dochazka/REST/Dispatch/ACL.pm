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



=head1 NAME

App::Dochazka::REST::Dispatch::ACL - ACL module





=head1 VERSION

Version 0.298

=cut

our $VERSION = '0.298';





=head1 DESCRIPTION

This module provides helper code for ACL checks.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( check_acl check_acl_context );




=head1 FUNCTIONS

=head2 check_acl

Compare priv level of resource ($acl) with the priv level of the employee
($priv). If $priv is at least as high as the $acl, the function returns

    $CELL->status_ok( 'DISPATCH_ACL_CHECK' )

otherwise it returns:

    $CELL->status_not_ok( 'DISPATCH_ACL_CHECK' )

=cut

sub check_acl {
    my ( $acl, $priv ) = @_;

    my $pass = $CELL->status_ok( 'DISPATCH_ACL_CHECK' );
    my $fail = $CELL->status_not_ok( 'DISPATCH_ACL_CHECK' );

    if ( ! defined $acl or ! defined $priv ) {
        $log->err( "Problem with arguments in check_acl" );
        return $fail;
    }

    if ( $acl eq 'passerby' ) {
        return $pass;
    } elsif ( $acl eq 'inactive' ) {
        return $pass if $priv eq 'inactive';
        return $pass if $priv eq 'active';
        return $pass if $priv eq 'admin';
    } elsif ( $acl eq 'active' ) {
        return $pass if $priv eq 'active';
        return $pass if $priv eq 'admin';
    } elsif ( $acl eq 'admin' ) {
        return $pass if $priv eq 'admin';
    }

    return $fail;
}


=head2 check_acl_context

Check ACL and compare with eid in request body. This routine is designed
for resources that have an ACL profile of 'active'. If the request body
contains an 'eid' property, it is checked against the current user's EID.  If
they are different and the current user's priv is 'active',
DOCHAZKA_FORBIDDEN_403 is returned; otherwise, undef is returned to signify
that the check passed.

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
    return;
}

1;

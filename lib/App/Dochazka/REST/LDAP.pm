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
# LDAP module
# ------------------------

package App::Dochazka::REST::LDAP;

use 5.012;
use strict;
use warnings;

use App::CELL qw( $log $site );



=head1 NAME

App::Dochazka::REST::LDAP - LDAP module (for authentication)





=head1 VERSION

Version 0.108

=cut

our $VERSION = '0.108';





=head1 DESCRIPTION

Container for LDAP-related stuff.

=cut




=head1 METHODS


=head2 ldap_exists

Takes a nick. Returns true or false. Determines if the nick exists in the LDAP database.
Any errors in communication with the LDAP server are written to the log.

=cut

sub ldap_exists {
    my ( $nick ) = @_;
    return 0 unless $nick;
    return 0;
}


=head2 ldap_auth

Takes a nick and a password. Returns true or false. Determines if the password matches
the one stored in the LDAP database.

=cut

sub ldap_auth {
    my ( $nick, $password ) = @_;
    return 0 unless $nick;
    $password = $password || '';
    return 0;
}


1;

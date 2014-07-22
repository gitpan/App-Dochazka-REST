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
# Path dispatcher module
# ------------------------

package App::Dochazka::REST::Dispatch;

use strict;
use warnings;

use App::CELL qw( $CELL );


=head1 NAME

App::Dochazka::REST::Dispatch - path dispatch





=head1 VERSION

Version 0.084

=cut

our $VERSION = '0.084';





=head1 SYNOPSIS

In Resource.pm:

    use App::Dochazka::REST::Dispatch;

    $self->{'context'} = App::Dochazka::REST::Dispatch::get_response( $path );




=head1 DESCRIPTION

Path dispatch state machine.

=cut




=head1 METHODS


=head2 get_response

Entry point. Takes a path, returns a data structure that will be converted
into JSON and sent to the client.

=cut
 
sub get_response {
    my ( $path ) = @_;

    # ========================================================================
    # big bad state machine
    # ========================================================================

    my $r; # allocate memory for response

    # 1. "no path" or "/version"
    if ( $path eq '' or $path eq '/' or $path =~ m/^\/version/i ) {
        $r = { 
            "App::Dochazka::REST" => { 
                version => "$VERSION",
                documentation => 'http://metacpan.org/pod/App::Dochazka::REST',
            },
        };

    # 999. anything else
    } else {
        $r = { unrecognized => $path };
    }

    return $r;
}

1;
